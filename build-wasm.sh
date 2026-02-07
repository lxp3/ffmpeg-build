#!/usr/bin/env bash

set -eu

cd "$(dirname "$0")"
BASE_DIR=$(pwd)

# Read version
FFMPEG_VERSION=7.1
FFMPEG_TARBALL=ffmpeg-$FFMPEG_VERSION.tar.gz
FFMPEG_TARBALL_URL=http://ffmpeg.org/releases/$FFMPEG_TARBALL

# Download tarball if missing
if [ ! -e "$FFMPEG_TARBALL" ]; then
	echo "Downloading $FFMPEG_TARBALL..."
	curl -s -L -O "$FFMPEG_TARBALL_URL"
fi

# Read flags (remove any Windows line endings)
FFMPEG_CONFIGURE_FLAGS=()
while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -n "$line" ]] && FFMPEG_CONFIGURE_FLAGS+=("$line")
done < ffmpeg_configure_flags.txt

# Check for emcc in PATH (GitHub Actions will have it set up)
if ! command -v emcc &> /dev/null; then
    # Try local emsdk as fallback
    EMSDK_DIR="$BASE_DIR/emsdk"
    if [ -d "$EMSDK_DIR" ] && [ -f "$EMSDK_DIR/emsdk_env.sh" ]; then
        # shellcheck source=/dev/null
        source "$EMSDK_DIR/emsdk_env.sh"
    fi
fi

if ! command -v emcc &> /dev/null; then
    echo "Error: emcc not found. Please setup Emscripten."
    exit 1
fi

OUTPUT_DIR=outputs/ffmpeg-$FFMPEG_VERSION-wasm

# Use explicit BUILD_DIR if provided, otherwise use default
BUILD_DIR=${BUILD_DIR:-build-static-wasm}
mkdir -p "$BUILD_DIR"

cd "$BUILD_DIR"
tar --strip-components=1 -xf "$BASE_DIR/$FFMPEG_TARBALL"

# WASM specific flags (WASM is always static, no programs)
# Key points:
# - NM must be set to llvm-nm (emscripten's nm wrapper has issues)
# - Use --enable-small to reduce binary size
# - STANDALONE_WASM=1 for standalone WASM module
WASM_CONFIGURE_FLAGS=(
    --prefix="$BASE_DIR/$OUTPUT_DIR"
    --target-os=none
    --arch=x86_32
    --enable-cross-compile
    --cc=emcc
    --cxx=em++
    --ar=emar
    --ranlib=emranlib
    --nm="llvm-nm"

    --disable-stripping
    --disable-inline-asm
    --disable-x86asm
    --disable-asm
    --disable-runtime-cpudetect

    --disable-pthreads
    --disable-w32threads
    --disable-os2threads

    --enable-static
    --disable-shared
    --disable-programs

    --extra-cflags="-O3 -msimd128"
    --extra-ldflags="-O3 -msimd128 -sWASM=1 -sALLOW_MEMORY_GROWTH=1"
)

echo "Configuring FFmpeg for WASM..."
./configure "${WASM_CONFIGURE_FLAGS[@]}" "${FFMPEG_CONFIGURE_FLAGS[@]}" || (cat ffbuild/config.log && exit 1)

echo "Building WASM..."
make -j"$(nproc)"
make install

cd "$BASE_DIR"
TAR_NAME="${OUTPUT_DIR}.tar.gz"
echo "Packaging to $TAR_NAME ..."
tar czf "$TAR_NAME" -C outputs "$(basename "$OUTPUT_DIR")"

# Only chown if running as root
if [ "$(id -u)" -eq 0 ]; then
    chown "$(stat -c '%u:%g' "$BASE_DIR")" "$TAR_NAME"
    chown "$(stat -c '%u:%g' "$BASE_DIR")" -R "$OUTPUT_DIR"
fi

echo "WASM build completed successfully. Output is in $OUTPUT_DIR"
