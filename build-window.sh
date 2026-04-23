#!/usr/bin/env bash

set -eu

source "$(dirname "$0")/build-common.sh"

init_build_env

# Fix for non-ASCII username in temp path
export TMPDIR="$BASE_DIR/tmp"
export TEMP="$TMPDIR"
export TMP="$TMPDIR"
mkdir -p "$TMPDIR"

download_ffmpeg_tarball

TOOLCHAIN=${TOOLCHAIN:-mingw}

read_configure_flags
apply_optional_feature_filters

# Determine Lib Type
set_lib_type
if [ "$ENABLE_SHARED" -eq 1 ]; then
    FFMPEG_CONFIGURE_FLAGS+=(--enable-shared --disable-static)
else
    FFMPEG_CONFIGURE_FLAGS+=(--enable-static --disable-shared)
fi

# Programs: always enable ffmpeg, disable ffprobe
FFMPEG_CONFIGURE_FLAGS+=(
    --enable-ffmpeg
    --disable-ffprobe
)

if [ "$TOOLCHAIN" = "msvc" ]; then
    if [ "$ARCH" != "x86_64" ]; then
        echo "MSVC builds currently support ARCH=x86_64 only." >&2
        exit 1
    fi
    TOOLCHAIN_SUFFIX="msvc"
    filter_external_codec_flags
    # Force MSVC tools to avoid confusion with MinGW tools in MSYS2 path
    export CC="cl"
    export CXX="cl"
    export AR="lib"
    export NM="dumpbin -symbols"
    export RANLIB="true"
    # MSVC flags: -wd4828 to disable illegal character warnings
    EXTRA_CFLAGS="-O2 -MD -wd4828 -D_WIN32_WINNT=0x0601 -DWINVER=0x0601"
    EXTRA_LDFLAGS=""
    FFMPEG_CONFIGURE_FLAGS+=(
        --toolchain=msvc
        --target-os=win64
    )
else
    case "$ARCH" in
        x86_64)
            TOOLCHAIN_SUFFIX="w64-mingw32"
            EXTRA_CFLAGS="-O3 -D_WIN32_WINNT=0x0601 -DWINVER=0x0601 -msse4.2 -mavx2 -ffunction-sections -fdata-sections"
            DLLTOOL_MACHINE="i386:x86-64"
            ;;
        aarch64)
            TOOLCHAIN_SUFFIX="w64-mingw32"
            EXTRA_CFLAGS="-O3 -D_WIN32_WINNT=0x0601 -DWINVER=0x0601 -ffunction-sections -fdata-sections"
            DLLTOOL_MACHINE=""
            ;;
    esac
    EXTRA_LDFLAGS="-Wl,--gc-sections -Wl,--kill-at"
    FFMPEG_CONFIGURE_FLAGS+=(
        --target-os=mingw32
    )
    if [ "$ENABLE_SHARED" -eq 0 ]; then
        EXTRA_LDFLAGS="-static $EXTRA_LDFLAGS"
        FFMPEG_CONFIGURE_FLAGS+=(
            --pkg-config-flags=--static
        )
    fi
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
    
sed -i 's/#define CC_IDENT.*/#define CC_IDENT "MSVC"/' config.h
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
            if [ -n "$DLLTOOL_MACHINE" ]; then
                dlltool --kill-at --input-def "$base.def" --output-lib "$base.lib" --machine "$DLLTOOL_MACHINE"
            else
                echo "Warning: dlltool machine mapping is not configured for ARCH=$ARCH. Skipping .lib generation."
            fi
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
