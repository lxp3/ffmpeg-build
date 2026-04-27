#!/usr/bin/env bash

set -eu

source "$(dirname "$0")/build-common.sh"

init_build_env
download_ffmpeg_tarball
read_configure_flags
apply_optional_feature_filters

set_lib_type

OUTPUT_DIR=outputs/ffmpeg-$FFMPEG_VERSION-$LIB_TYPE-$ARCH-macos

if [ -z "${BUILD_DIR:-}" ]; then
    BUILD_DIR="$BASE_DIR/build-${LIB_TYPE}-macos"
fi
mkdir -p "$BUILD_DIR"

if [ "$LIB_TYPE" = "shared" ]; then
    FFMPEG_CONFIGURE_FLAGS+=(
        --enable-shared
        --disable-static
    )
else
    FFMPEG_CONFIGURE_FLAGS+=(
        --enable-static
        --disable-shared
        --pkg-config-flags=--static
    )
fi

FFMPEG_CONFIGURE_FLAGS+=(
    --enable-ffmpeg
    --disable-ffprobe
)

FFMPEG_CONFIGURE_FLAGS+=(
    --target-os=darwin
    --arch="$ARCH"
    --extra-cflags="$(macos_extra_cflags)"
)

cd "$BUILD_DIR"
tar --strip-components=1 -xf "$BASE_DIR/$FFMPEG_TARBALL"

FFMPEG_CONFIGURE_FLAGS+=(
    --prefix="$BASE_DIR/$OUTPUT_DIR"
)

echo "Configuring FFmpeg for macOS ($ARCH)..."
./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || (cat ffbuild/config.log && exit 1)

echo "Building..."
make -j"$(sysctl -n hw.ncpu)"
make install

cd "$BASE_DIR"
TAR_NAME="${OUTPUT_DIR}.tar.gz"
echo "Packaging to $TAR_NAME ..."
tar czf "$TAR_NAME" -C outputs "$(basename "$OUTPUT_DIR")"

echo "macOS build complete. Output: $OUTPUT_DIR"
