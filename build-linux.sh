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

# Default settings (x86_64 only)
ARCH=x86_64
ENABLE_SHARED=${ENABLE_SHARED:-0}

if [ "$ENABLE_SHARED" -eq 1 ]; then
    LIB_TYPE=shared
else
    LIB_TYPE=static
fi

OUTPUT_DIR=outputs/ffmpeg-$FFMPEG_VERSION-$LIB_TYPE-$ARCH-linux-gnu

# Use explicit BUILD_DIR if provided, otherwise derive from ENABLE_SHARED
if [ -z "${BUILD_DIR:-}" ]; then
    BUILD_DIR="$BASE_DIR/build-${LIB_TYPE}-linux"
fi
mkdir -p "$BUILD_DIR"

# Programs control: static = no exe, shared = with exe
if [ "$LIB_TYPE" = "shared" ]; then
    FFMPEG_CONFIGURE_FLAGS+=(
        --enable-shared
        --disable-static
        --enable-ffmpeg
        --enable-ffprobe
    )
else
    FFMPEG_CONFIGURE_FLAGS+=(
        --enable-static
        --disable-shared
        --disable-programs
    )
fi

# x86_64 optimizations
FFMPEG_CONFIGURE_FLAGS+=(
    --extra-cflags="-O3 -fPIC -msse4.2 -mavx2 -ffunction-sections -fdata-sections"
    --extra-ldflags="-Wl,--gc-sections"
)

cd "$BUILD_DIR"
tar --strip-components=1 -xf "$BASE_DIR/$FFMPEG_TARBALL"

FFMPEG_CONFIGURE_FLAGS+=(
    --prefix="$BASE_DIR/$OUTPUT_DIR"
)

echo "Configuring FFmpeg..."
./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || (cat ffbuild/config.log && exit 1)

echo "Building..."
make -j$(nproc)
make install

if [ "$LIB_TYPE" = "shared" ]; then
    echo "Post-processing shared libraries..."
    LIB_DIR="$BASE_DIR/$OUTPUT_DIR/lib"
    cd "$LIB_DIR"

    # Remove symlinks, keep real files
    for link in *.so *.so.[0-9]*; do
        if [ -L "$link" ]; then
            rm -f "$link"
        fi
    done

    # Fix SONAME and dependencies
    if command -v patchelf > /dev/null; then
        for so_file in *.so.*.*.*; do
            if [ -f "$so_file" ] && [ ! -L "$so_file" ]; then
                echo "  Processing $so_file..."
                patchelf --set-soname "$so_file" "$so_file"

                for dep in $(patchelf --print-needed "$so_file"); do
                    case $dep in
                        libav*|libsw*|libpostproc*)
                            prefix=$(echo "$dep" | cut -d. -f1)
                            actual_dep=$(ls ${prefix}.so.*.*.* 2>/dev/null | head -n 1)
                            if [ -n "$actual_dep" ] && [ "$dep" != "$actual_dep" ]; then
                                patchelf --replace-needed "$dep" "$actual_dep" "$so_file"
                            fi
                            ;;
                    esac
                done
                patchelf --set-rpath '$ORIGIN' "$so_file"
            fi
        done
    else
        echo "Warning: patchelf not found. SONAME/Dependencies not updated."
    fi
fi

cd "$BASE_DIR"
TAR_NAME="${OUTPUT_DIR}.tar.gz"
echo "Packaging to $TAR_NAME ..."
tar czf "$TAR_NAME" -C outputs "$(basename "$OUTPUT_DIR")"

# Only chown if running as root
if [ "$(id -u)" -eq 0 ]; then
    chown "$(stat -c '%u:%g' "$BASE_DIR")" "$TAR_NAME"
    chown "$(stat -c '%u:%g' "$BASE_DIR")" -R "$OUTPUT_DIR"
fi

echo "Linux build complete. Output: $OUTPUT_DIR"
