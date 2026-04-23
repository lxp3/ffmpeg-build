#!/usr/bin/env bash

set -eu

source "$(dirname "$0")/build-common.sh"
init_build_env

# Emscripten version
EMSDK_VERSION=5.0.0
EMSDK_DIR="$BASE_DIR/emsdk"

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
download_ffmpeg_tarball
read_configure_flags

# WASM builds do not bundle native external codec/system libraries by default.
filter_external_codec_flags

# Ensure configure uses clang-style toolchain args for Emscripten
export CC=emcc
export CXX=em++
export AR=emar
export NM=emnm
export RANLIB=emranlib

OUTPUT_DIR=outputs/ffmpeg-$FFMPEG_VERSION-wasm

# WASM is always static; derive BUILD_DIR from ENABLE_SHARED if not provided
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
