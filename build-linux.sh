#!/usr/bin/env bash

set -eu

source "$(dirname "$0")/build-common.sh"

init_build_env
download_ffmpeg_tarball
read_configure_flags
apply_optional_feature_filters

set_lib_type

OUTPUT_DIR=outputs/ffmpeg-$FFMPEG_VERSION-$LIB_TYPE-$ARCH-linux-gnu

# Use explicit BUILD_DIR if provided, otherwise derive from ENABLE_SHARED
if [ -z "${BUILD_DIR:-}" ]; then
    BUILD_DIR="$BASE_DIR/build-${LIB_TYPE}-linux"
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
    )
fi

FFMPEG_CONFIGURE_FLAGS+=(
    --enable-ffmpeg
    --disable-ffprobe
)

FFMPEG_CONFIGURE_FLAGS+=(
    --extra-cflags="$(linux_extra_cflags)"
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
