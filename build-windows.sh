#!/usr/bin/env bash

set -eu

cd $(dirname $0)
BASE_DIR=$(pwd)

FFMPEG_VERSION=7.1
FFMPEG_TARBALL=ffmpeg-$FFMPEG_VERSION.tar.gz
FFMPEG_TARBALL_URL=http://ffmpeg.org/releases/$FFMPEG_TARBALL

# Download tarball if missing
if [ ! -e $FFMPEG_TARBALL ]; then
	echo "Downloading $FFMPEG_TARBALL..."
	curl -s -L -O $FFMPEG_TARBALL_URL
fi

# Args
ARCH=${ARCH:-x86_64}
ENABLE_SHARED=${ENABLE_SHARED:-0}

# Read flags
mapfile -t FFMPEG_CONFIGURE_FLAGS < ffmpeg_configure_flags.txt

# Determine Lib Type
if [ "$ENABLE_SHARED" -eq 1 ]; then
    LIB_TYPE=shared
    FFMPEG_CONFIGURE_FLAGS+=( --enable-shared --disable-static )
else
    LIB_TYPE=static
    FFMPEG_CONFIGURE_FLAGS+=( --enable-static --disable-shared )
fi

OUTPUT_DIR=outputs/ffmpeg-$FFMPEG_VERSION-$LIB_TYPE-$ARCH-w64-mingw32
mkdir -p "$OUTPUT_DIR"
ABS_OUTPUT_DIR="$BASE_DIR/$OUTPUT_DIR"

BUILD_DIR=$(mktemp -d -p . build.windows.XXXXXXXX)
trap 'rm -rf $BUILD_DIR' EXIT

cd $BUILD_DIR
tar --strip-components=1 -xf ../$FFMPEG_TARBALL

# Windows specific flags with O3 and SIMD optimizations
EXTRA_CFLAGS="-O3 -D_WIN32_WINNT=0x0601 -DWINVER=0x0601 -msse4.2 -mavx2 -ffunction-sections -fdata-sections"
EXTRA_LDFLAGS="-static -Wl,--gc-sections -Wl,--kill-at"

echo "Configuring FFmpeg for Windows ($ARCH)..."
./configure \
    "${FFMPEG_CONFIGURE_FLAGS[@]}" \
    --prefix="$ABS_OUTPUT_DIR" \
    --arch=$ARCH \
    --target-os=mingw32 \
    --enable-runtime-cpudetect \
    --extra-libs='-lpsapi -lole32 -lstrmiids -luuid -lgdi32' \
    --extra-cflags="$EXTRA_CFLAGS" \
    --extra-ldflags="$EXTRA_LDFLAGS"

echo "Building..."
make -j$(nproc)
make install

echo "Post-processing..."
if [ "$ENABLE_SHARED" -eq 1 ]; then
    cd "$ABS_OUTPUT_DIR/bin"
    for dll in *.dll; do
        [ -e "$dll" ] || continue
        base=$(basename "$dll" .dll)
        echo "Processing $dll..."
        if command -v gendef >/dev/null; then
            gendef "$dll" > /dev/null
            dlltool --kill-at --input-def "$base.def" --output-lib "$base.lib" --machine i386:x86-64
        else
            echo "Warning: gendef not found. Skipping .lib generation."
        fi
    done
fi

cd "$BASE_DIR"
TAR_NAME="${OUTPUT_DIR}.tar.gz"
echo "Packaging to $TAR_NAME ..."
tar czf "$TAR_NAME" -C outputs "$(basename "$OUTPUT_DIR")"

echo "Windows build complete. Output: $OUTPUT_DIR"
