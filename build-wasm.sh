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

# Install and setup Emscripten if needed
EMSDK_DIR="$BASE_DIR/emsdk"
if [ -d "$EMSDK_DIR" ]; then
    cd "$EMSDK_DIR"
    if ! command -v emcc &> /dev/null; then
        # Setup environment variables if not already set
        if [ -f "./emsdk_env.sh" ]; then
             source ./emsdk_env.sh
        fi
    fi
    cd "$BASE_DIR"
fi

if ! command -v emcc &> /dev/null; then
    echo "Error: emcc not found. Please setup Emscripten."
    exit 1
fi

# Ensure configure uses clang-style toolchain args for Emscripten
export CC=emcc
export CXX=em++
export AR=emar
export NM=emnm
export RANLIB=emranlib

OUTPUT_DIR=outputs/ffmpeg-$FFMPEG_VERSION-wasm

# Use explicit BUILD_DIR if provided, otherwise create temp directory
if [ -z "${BUILD_DIR:-}" ]; then
    BUILD_DIR=$(mktemp -d -p "$(pwd)" build.wasm.XXXXXXXX)
    CLEANUP_BUILD_DIR=1
else
    mkdir -p "$BUILD_DIR"
    CLEANUP_BUILD_DIR=0
fi

if [ "$CLEANUP_BUILD_DIR" -eq 1 ]; then
    trap 'rm -rf "$BUILD_DIR"' EXIT
fi

cd "$BUILD_DIR"
tar --strip-components=1 -xf "$BASE_DIR/$FFMPEG_TARBALL"

# WASM specific flags (WASM is always static, no programs)
WASM_CONFIGURE_FLAGS=(
    --prefix="$BASE_DIR/$OUTPUT_DIR"
    --target-os=none
    --arch=x86_32
    --enable-cross-compile
    --toolchain=clang
    --cc=emcc
    --cxx=em++
    --ar=emar
    --nm=emnm
    --ranlib=emranlib

    --disable-stripping
    --disable-inline-asm
    --disable-x86asm
    --disable-asm

    --disable-pthreads
    --disable-w32threads
    --disable-os2threads

    --enable-static
    --disable-shared
    --disable-programs

    --extra-cflags="-O3 -flto -msimd128"
    --extra-ldflags="-O3 -flto -msimd128"
)

echo "Configuring FFmpeg for WASM..."
./configure "${WASM_CONFIGURE_FLAGS[@]}" "${FFMPEG_CONFIGURE_FLAGS[@]}" || (cat ffbuild/config.log && exit 1)

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
