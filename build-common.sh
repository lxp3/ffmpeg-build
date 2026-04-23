#!/usr/bin/env bash

set -eu

readonly BUILD_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

normalize_arch() {
    local raw_arch="$1"

    case "${raw_arch,,}" in
        x86_64|amd64)
            printf '%s\n' "x86_64"
            ;;
        aarch64|arm64)
            printf '%s\n' "aarch64"
            ;;
        *)
            printf 'Unsupported architecture: %s. Supported: x86_64, aarch64\n' "$raw_arch" >&2
            return 1
            ;;
    esac
}

detect_host_arch() {
    local raw_arch

    if [ -n "${PROCESSOR_ARCHITECTURE:-}" ]; then
        raw_arch="$PROCESSOR_ARCHITECTURE"
    else
        raw_arch="$(uname -m)"
    fi

    normalize_arch "$raw_arch"
}

resolve_arch() {
    if [ -n "${ARCH:-}" ]; then
        normalize_arch "$ARCH"
    else
        detect_host_arch
    fi
}

resolve_target_os() {
    if [ -n "${TARGET_OS:-}" ]; then
        printf '%s\n' "$TARGET_OS"
        return 0
    fi

    case "$(uname -s)" in
        Linux)
            printf '%s\n' "linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            printf '%s\n' "windows"
            ;;
        *)
            printf 'Unable to infer TARGET_OS from host OS. Set TARGET_OS explicitly.\n' >&2
            return 1
            ;;
    esac
}

init_build_env() {
    cd "$BUILD_COMMON_DIR"

    BASE_DIR="$(pwd)"
    readonly BASE_DIR

    FFMPEG_VERSION="${FFMPEG_VERSION:-7.1}"
    readonly FFMPEG_VERSION

    FFMPEG_TARBALL="ffmpeg-$FFMPEG_VERSION.tar.gz"
    readonly FFMPEG_TARBALL

    FFMPEG_TARBALL_URL="${FFMPEG_TARBALL_URL:-http://ffmpeg.org/releases/$FFMPEG_TARBALL}"
    readonly FFMPEG_TARBALL_URL

    ARCH="$(resolve_arch)"
    export ARCH

    ENABLE_SHARED="${ENABLE_SHARED:-0}"
    export ENABLE_SHARED

    ENABLE_EXTERNAL_CODECS="${ENABLE_EXTERNAL_CODECS:-1}"
    export ENABLE_EXTERNAL_CODECS
}

download_ffmpeg_tarball() {
    if [ ! -e "$FFMPEG_TARBALL" ]; then
        echo "Downloading $FFMPEG_TARBALL..."
        curl -s -L -O "$FFMPEG_TARBALL_URL"
    fi
}

read_configure_flags() {
    FFMPEG_CONFIGURE_FLAGS=()
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        [ -n "$line" ] && FFMPEG_CONFIGURE_FLAGS+=("$line")
    done < "$BASE_DIR/ffmpeg_configure_flags.txt"
}

filter_external_codec_flags() {
    local filtered_flags=()
    local flag

    for flag in "${FFMPEG_CONFIGURE_FLAGS[@]}"; do
        case "$flag" in
            --enable-libmp3lame|--enable-libopus|--enable-libvorbis|--enable-libspeex|--enable-openssl|\
            --enable-encoder=libmp3lame|--enable-encoder=libopus|--enable-encoder=libvorbis|--enable-encoder=libspeex)
                ;;
            *)
                filtered_flags+=("$flag")
                ;;
        esac
    done

    FFMPEG_CONFIGURE_FLAGS=("${filtered_flags[@]}")
}

apply_optional_feature_filters() {
    if [ "$ENABLE_EXTERNAL_CODECS" -eq 0 ]; then
        filter_external_codec_flags
    fi
}

set_lib_type() {
    if [ "$ENABLE_SHARED" -eq 1 ]; then
        LIB_TYPE="shared"
    else
        LIB_TYPE="static"
    fi
    export LIB_TYPE
}

linux_extra_cflags() {
    case "$ARCH" in
        x86_64)
            printf '%s\n' "-O3 -fPIC -msse4.2 -mavx2 -ffunction-sections -fdata-sections"
            ;;
        aarch64)
            printf '%s\n' "-O3 -fPIC -ffunction-sections -fdata-sections"
            ;;
    esac
}
