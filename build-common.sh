#!/usr/bin/env bash

set -eu

readonly BUILD_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

normalize_arch() {
    local raw_arch="$1"
    local normalized_arch

    normalized_arch="$(printf '%s' "$raw_arch" | tr '[:upper:]' '[:lower:]')"

    case "$normalized_arch" in
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
        Darwin)
            printf '%s\n' "macos"
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

macos_extra_cflags() {
    case "$ARCH" in
        x86_64)
            printf '%s\n' "-O3 -fPIC -msse4.2 -mavx2 -ffunction-sections -fdata-sections"
            ;;
        aarch64)
            printf '%s\n' "-O3 -fPIC -ffunction-sections -fdata-sections"
            ;;
    esac
}

copy_existing_static_libs() {
    local source_dir="$1"
    local dest_dir="$2"
    shift 2

    local lib_name
    for lib_name in "$@"; do
        if [ -f "$source_dir/$lib_name" ]; then
            cp "$source_dir/$lib_name" "$dest_dir/"
        fi
    done
}

rewrite_pkgconfig_prefixes() {
    local sdk_prefix="$1"
    local pc_file

    if [ ! -d "$sdk_prefix/lib/pkgconfig" ]; then
        return 0
    fi

    for pc_file in "$sdk_prefix"/lib/pkgconfig/*.pc; do
        [ -f "$pc_file" ] || continue
        perl -0pi -e 's|^prefix=.*$|prefix=\${pcfiledir}/../..|mg; s|^exec_prefix=.*$|exec_prefix=\${prefix}|mg; s|^libdir=.*$|libdir=\${prefix}/lib|mg; s|^includedir=.*$|includedir=\${prefix}/include|mg' "$pc_file"
    done
}

generate_ffmpeg_cmake_config() {
    local sdk_prefix="$1"
    local platform="$2"
    local toolchain="${3:-}"
    local lib_type="${4:-static}"
    local cmake_dir="$sdk_prefix/lib/cmake/FFmpeg"
    local third_party_libs=""
    local system_libs=""
    local lib_ext=".a"
    local ffmpeg_lib_prefix="lib"
    local imported_type="STATIC"

    mkdir -p "$cmake_dir"

    if [ "$lib_type" = "shared" ]; then
        imported_type="SHARED"
        third_party_libs=""
        system_libs=""
    else
        case "$platform:$toolchain" in
            linux:*)
                third_party_libs="mp3lame;opus;vorbisenc;vorbis;ogg;speex;ssl;crypto"
                system_libs="m;pthread;dl;rt;atomic"
                ;;
            macos:*)
                third_party_libs="mp3lame;opus;vorbisenc;vorbis;ogg;speex;ssl;crypto"
                system_libs="-framework;CoreFoundation;-framework;Security;-framework;AudioToolbox;-framework;CoreAudio;-framework;VideoToolbox;-framework;CoreMedia;-framework;CoreVideo;-framework;AVFoundation;-framework;AppKit;-framework;Foundation;m;pthread;z;bz2;iconv"
                ;;
            windows:mingw)
                third_party_libs="mp3lame;opus;vorbisenc;vorbis;ogg;speex;ssl;crypto"
                system_libs="ws2_32;bcrypt;crypt32;user32;advapi32;ole32;strmiids;uuid;gdi32;psapi"
                ;;
            windows:msvc)
                lib_ext=".lib"
                ffmpeg_lib_prefix=""
                third_party_libs=""
                system_libs="ws2_32;bcrypt;crypt32;user32;advapi32;ole32;strmiids;uuid;gdi32;psapi"
                ;;
        esac
    fi

    if [ "$platform:$toolchain" = "windows:msvc" ]; then
        lib_ext=".lib"
        ffmpeg_lib_prefix=""
    fi

    cat > "$cmake_dir/FFmpegConfig.cmake" <<EOF
include_guard(GLOBAL)

get_filename_component(_ffmpeg_config_dir "\${CMAKE_CURRENT_LIST_FILE}" PATH)
get_filename_component(_ffmpeg_prefix "\${_ffmpeg_config_dir}/../../.." ABSOLUTE)

set(FFmpeg_FOUND TRUE)
set(FFmpeg_ROOT "\${_ffmpeg_prefix}")
set(FFmpeg_INCLUDE_DIR "\${_ffmpeg_prefix}/include")
set(FFmpeg_LIBRARY_DIR "\${_ffmpeg_prefix}/lib")
set(FFmpeg_BINARY_DIR "\${_ffmpeg_prefix}/bin")

set(_ffmpeg_library_suffix "$lib_ext")
set(_ffmpeg_library_prefix "$ffmpeg_lib_prefix")
set(_ffmpeg_imported_type "$imported_type")
set(_ffmpeg_package_platform "$platform")
set(_ffmpeg_package_toolchain "$toolchain")
set(_ffmpeg_components
    avdevice
    avfilter
    avformat
    avcodec
    swscale
    swresample
    avutil
)
set(_ffmpeg_third_party_names "$third_party_libs")
set(_ffmpeg_system_libs "$system_libs")

foreach(_ffmpeg_lib IN LISTS _ffmpeg_components)
    if(NOT TARGET ffmpeg::\${_ffmpeg_lib})
        add_library(ffmpeg::\${_ffmpeg_lib} \${_ffmpeg_imported_type} IMPORTED)
        set_target_properties(ffmpeg::\${_ffmpeg_lib} PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "\${FFmpeg_INCLUDE_DIR}"
        )
        if(_ffmpeg_imported_type STREQUAL "SHARED" AND WIN32)
            file(GLOB _ffmpeg_implib
                "\${FFmpeg_LIBRARY_DIR}/lib\${_ffmpeg_lib}.dll.a"
                "\${FFmpeg_LIBRARY_DIR}/\${_ffmpeg_lib}.lib"
                "\${FFmpeg_BINARY_DIR}/\${_ffmpeg_lib}.lib"
                "\${FFmpeg_BINARY_DIR}/\${_ffmpeg_lib}-*.lib"
            )
            file(GLOB _ffmpeg_location
                "\${FFmpeg_BINARY_DIR}/\${_ffmpeg_lib}-*.dll"
                "\${FFmpeg_BINARY_DIR}/\${_ffmpeg_lib}.dll"
            )
            if(_ffmpeg_implib)
                list(GET _ffmpeg_implib 0 _ffmpeg_implib_path)
                set_target_properties(ffmpeg::\${_ffmpeg_lib} PROPERTIES IMPORTED_IMPLIB "\${_ffmpeg_implib_path}")
            endif()
            if(_ffmpeg_location)
                list(GET _ffmpeg_location 0 _ffmpeg_location_path)
                set_target_properties(ffmpeg::\${_ffmpeg_lib} PROPERTIES IMPORTED_LOCATION "\${_ffmpeg_location_path}")
            endif()
        elseif(_ffmpeg_imported_type STREQUAL "SHARED" AND APPLE)
            set_target_properties(ffmpeg::\${_ffmpeg_lib} PROPERTIES
                IMPORTED_LOCATION "\${FFmpeg_LIBRARY_DIR}/lib\${_ffmpeg_lib}.dylib"
            )
        elseif(_ffmpeg_imported_type STREQUAL "SHARED")
            file(GLOB _ffmpeg_location "\${FFmpeg_LIBRARY_DIR}/lib\${_ffmpeg_lib}.so*")
            if(_ffmpeg_location)
                list(GET _ffmpeg_location 0 _ffmpeg_location_path)
                set_target_properties(ffmpeg::\${_ffmpeg_lib} PROPERTIES IMPORTED_LOCATION "\${_ffmpeg_location_path}")
            endif()
        else()
            set_target_properties(ffmpeg::\${_ffmpeg_lib} PROPERTIES
                IMPORTED_LOCATION "\${FFmpeg_LIBRARY_DIR}/\${_ffmpeg_library_prefix}\${_ffmpeg_lib}\${_ffmpeg_library_suffix}"
            )
        endif()
    endif()
endforeach()

set(_ffmpeg_third_party_libs "")
foreach(_ffmpeg_dep IN LISTS _ffmpeg_third_party_names)
    if(EXISTS "\${FFmpeg_LIBRARY_DIR}/lib\${_ffmpeg_dep}\${_ffmpeg_library_suffix}")
        list(APPEND _ffmpeg_third_party_libs "\${FFmpeg_LIBRARY_DIR}/lib\${_ffmpeg_dep}\${_ffmpeg_library_suffix}")
    elseif(EXISTS "\${FFmpeg_LIBRARY_DIR}/\${_ffmpeg_dep}\${_ffmpeg_library_suffix}")
        list(APPEND _ffmpeg_third_party_libs "\${FFmpeg_LIBRARY_DIR}/\${_ffmpeg_dep}\${_ffmpeg_library_suffix}")
    endif()
endforeach()

if(NOT TARGET ffmpeg::ffmpeg)
    add_library(ffmpeg::ffmpeg INTERFACE IMPORTED)
    set_target_properties(ffmpeg::ffmpeg PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "\${FFmpeg_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "ffmpeg::avdevice;ffmpeg::avfilter;ffmpeg::avformat;ffmpeg::avcodec;ffmpeg::swscale;ffmpeg::swresample;ffmpeg::avutil;\${_ffmpeg_third_party_libs};\${_ffmpeg_system_libs}"
    )
endif()

unset(_ffmpeg_config_dir)
unset(_ffmpeg_prefix)
unset(_ffmpeg_library_suffix)
unset(_ffmpeg_library_prefix)
unset(_ffmpeg_imported_type)
unset(_ffmpeg_package_platform)
unset(_ffmpeg_package_toolchain)
unset(_ffmpeg_components)
unset(_ffmpeg_third_party_names)
unset(_ffmpeg_third_party_libs)
unset(_ffmpeg_system_libs)
unset(_ffmpeg_implib)
unset(_ffmpeg_implib_path)
unset(_ffmpeg_location)
unset(_ffmpeg_location_path)
EOF
}

package_shared_sdk() {
    local sdk_prefix="$1"
    local platform="$2"
    local toolchain="${3:-}"

    echo "Packaging shared SDK metadata..."
    rewrite_pkgconfig_prefixes "$sdk_prefix"
    generate_ffmpeg_cmake_config "$sdk_prefix" "$platform" "$toolchain" shared
}

package_static_sdk() {
    local sdk_prefix="$1"
    local platform="$2"
    local toolchain="${3:-}"
    local deps_prefix="${DEPS_PREFIX:-}"

    echo "Packaging static SDK metadata and third-party libraries..."

    case "$platform" in
        linux)
            deps_prefix="${deps_prefix:-/opt/ffmpeg-deps}"
            if [ -d "$deps_prefix/lib" ]; then
                copy_existing_static_libs "$deps_prefix/lib" "$sdk_prefix/lib" \
                    libmp3lame.a libopus.a libvorbis.a libvorbisenc.a libogg.a libspeex.a libssl.a libcrypto.a
            else
                echo "Warning: dependency prefix not found: $deps_prefix"
            fi
            ;;
        macos)
            copy_existing_static_libs "$(brew --prefix)/lib" "$sdk_prefix/lib" \
                libmp3lame.a libopus.a libvorbis.a libvorbisenc.a libogg.a libspeex.a
            copy_existing_static_libs "$(brew --prefix openssl@3)/lib" "$sdk_prefix/lib" \
                libssl.a libcrypto.a
            ;;
        windows)
            if [ "$toolchain" = "mingw" ]; then
                local mingw_lib_dir="${MINGW_PREFIX:-/mingw64}/lib"
                copy_existing_static_libs "$mingw_lib_dir" "$sdk_prefix/lib" \
                    libmp3lame.a libopus.a libvorbis.a libvorbisenc.a libogg.a libspeex.a libssl.a libcrypto.a
            fi
            ;;
    esac

    rewrite_pkgconfig_prefixes "$sdk_prefix"
    generate_ffmpeg_cmake_config "$sdk_prefix" "$platform" "$toolchain" static
}
