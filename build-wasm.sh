#!/usr/bin/env bash

cd "$(dirname "$0")"
BASE_DIR=$(pwd)

# Emscripten version
EMSDK_VERSION=5.0.0
EMSDK_DIR="$BASE_DIR/emsdk"

# FFmpeg version
FFMPEG_VERSION=7.1
FFMPEG_TARBALL=ffmpeg-$FFMPEG_VERSION.tar.gz
FFMPEG_TARBALL_URL=http://ffmpeg.org/releases/$FFMPEG_TARBALL

echo "=== Setting up Emscripten ==="

# Clone emsdk if not exists
if [ ! -d "$EMSDK_DIR" ]; then
    echo "Cloning emsdk..."
    git clone https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
fi

# Install and activate emsdk
cd "$EMSDK_DIR"
echo "Installing Emscripten $EMSDK_VERSION..."
./emsdk install $EMSDK_VERSION

echo "Activating Emscripten $EMSDK_VERSION..."
./emsdk activate $EMSDK_VERSION

# # echo "Loading Emscripten environment..."
source "$EMSDK_DIR/emsdk_env.sh"


cd "$BASE_DIR"

# Verify emcc is available
if ! command -v emcc &> /dev/null; then
    echo "Error: emcc not found. Emscripten setup failed."
    exit 1
fi
echo "emcc found: $(which emcc)"

echo "=== Downloading FFmpeg ==="

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

# Ensure configure uses clang-style toolchain args for Emscripten
export CC=emcc
export CXX=em++
export AR=emar
export NM=emnm
export RANLIB=emranlib

OUTPUT_DIR=outputs/ffmpeg-$FFMPEG_VERSION-wasm

# WASM is always static; derive BUILD_DIR from ENABLE_SHARED if not provided
ENABLE_SHARED=${ENABLE_SHARED:-0}
LIB_TYPE=static
if [ -z "${BUILD_DIR:-}" ]; then
    BUILD_DIR="$BASE_DIR/build-${LIB_TYPE}-wasm"
fi
mkdir -p "$BUILD_DIR"

cd "$BUILD_DIR"
tar --strip-components=1 -xf "$BASE_DIR/$FFMPEG_TARBALL"

# WASM specific flags (WASM is always static, no programs)
WASM_CONFIGURE_FLAGS=(
    --prefix="$BASE_DIR/$OUTPUT_DIR"
    --target-os=none
    --arch=x86_32
    --enable-cross-compile
    --cc=emcc
    --cxx=em++
    --ar=emar
    --nm=emnm
    --ranlib=emranlib

    --disable-autodetect
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
    --extra-ldflags="-O3 -msimd128 -sWASM=1"
)

echo "Configuring FFmpeg for WASM..."
./configure "${WASM_CONFIGURE_FLAGS[@]}" "${FFMPEG_CONFIGURE_FLAGS[@]}" || exit 1

echo "Building WASM..."
make -j$(nproc)
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
