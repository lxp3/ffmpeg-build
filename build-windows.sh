#!/usr/bin/env bash

set -eu

cd "$(dirname "$0")"
BASE_DIR=$(pwd)

# Fix for non-ASCII username in temp path
export TMPDIR="$BASE_DIR/tmp"
export TEMP="$TMPDIR"
export TMP="$TMPDIR"
mkdir -p "$TMPDIR"

FFMPEG_VERSION=7.1
FFMPEG_TARBALL=ffmpeg-$FFMPEG_VERSION.tar.gz
FFMPEG_TARBALL_URL=http://ffmpeg.org/releases/$FFMPEG_TARBALL

# Download tarball if missing
if [ ! -e "$FFMPEG_TARBALL" ]; then
	echo "Downloading $FFMPEG_TARBALL..."
	curl -s -L -O "$FFMPEG_TARBALL_URL"
fi

# Args
ARCH=${ARCH:-x86_64}
ENABLE_SHARED=${ENABLE_SHARED:-0}
TOOLCHAIN=${TOOLCHAIN:-mingw}

# Read flags (remove Windows line endings, skip empty lines)
FFMPEG_CONFIGURE_FLAGS=()
while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -n "$line" ]] && FFMPEG_CONFIGURE_FLAGS+=("$line")
done < ffmpeg_configure_flags.txt

# Determine Lib Type and programs
if [ "$ENABLE_SHARED" -eq 1 ]; then
    LIB_TYPE=shared
    FFMPEG_CONFIGURE_FLAGS+=(
        --enable-shared
        --disable-static
        --enable-ffmpeg
        --enable-ffprobe
    )
else
    LIB_TYPE=static
    FFMPEG_CONFIGURE_FLAGS+=(
        --enable-static
        --disable-shared
        --disable-programs
    )
fi

if [ "$TOOLCHAIN" = "msvc" ]; then
    TOOLCHAIN_SUFFIX="msvc"
    # MSVC flags: -wd4828 to disable illegal character warnings
    EXTRA_CFLAGS="-O2 -MD -wd4828 -D_WIN32_WINNT=0x0601 -DWINVER=0x0601"
    EXTRA_LDFLAGS=""
    FFMPEG_CONFIGURE_FLAGS+=(
        --toolchain=msvc
        --target-os=win64
    )
else
    TOOLCHAIN_SUFFIX="w64-mingw32"
    # MinGW specific flags with O3 and SIMD optimizations
    EXTRA_CFLAGS="-O3 -D_WIN32_WINNT=0x0601 -DWINVER=0x0601 -msse4.2 -mavx2 -ffunction-sections -fdata-sections"
    EXTRA_LDFLAGS="-static -Wl,--gc-sections -Wl,--kill-at"
    FFMPEG_CONFIGURE_FLAGS+=(
        --target-os=mingw32
    )
fi

OUTPUT_DIR=outputs/ffmpeg-$FFMPEG_VERSION-$LIB_TYPE-$ARCH-$TOOLCHAIN_SUFFIX
mkdir -p "$OUTPUT_DIR"
ABS_OUTPUT_DIR="$BASE_DIR/$OUTPUT_DIR"

# Use explicit BUILD_DIR if provided, otherwise derive from ENABLE_SHARED
if [ -z "${BUILD_DIR:-}" ]; then
    BUILD_DIR="$BASE_DIR/build-${LIB_TYPE}-${TOOLCHAIN_SUFFIX}"
fi
mkdir -p "$BUILD_DIR"

cd "$BUILD_DIR"
tar --strip-components=1 -xf "$BASE_DIR/$FFMPEG_TARBALL"

echo "Configuring FFmpeg for Windows ($ARCH, Toolchain=$TOOLCHAIN)..."
./configure \
    "${FFMPEG_CONFIGURE_FLAGS[@]}" \
    --prefix="$ABS_OUTPUT_DIR" \
    --arch="$ARCH" \
    --enable-runtime-cpudetect \
    --extra-libs='-lpsapi -lole32 -lstrmiids -luuid -lgdi32' \
    --extra-cflags="$EXTRA_CFLAGS" \
    --extra-ldflags="$EXTRA_LDFLAGS"

# Fix awk syntax error in MSVC dependency generation
if [ "$TOOLCHAIN" = "msvc" ]; then
    echo "Applying MSVC makefile patches..."
    # Use a simpler character class [ \\ ] to handle backslashes in awk
    sed -i 's|gsub(/\\/, "/")|gsub(/[\\\\]/, "/")|g' ffbuild/common.mak
fi

echo "Building..."
make -j$(nproc)
make install

echo "Post-processing..."
if [ "$ENABLE_SHARED" -eq 1 ] && [ "$TOOLCHAIN" != "msvc" ]; then
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
