#!/usr/bin/env bash

set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 <sdk-prefix> <platform> [toolchain] [static|shared]" >&2
    exit 2
fi

sdk_prefix="$1"
platform="$2"
toolchain="${3:-}"
lib_type="${4:-static}"
cmake_dir="$sdk_prefix/lib/cmake/FFmpeg"

third_party_libs=""
system_libs=""
framework_libs=""
lib_ext=".a"
ffmpeg_lib_prefix="lib"
imported_type="STATIC"

mkdir -p "$cmake_dir"

if [ "$lib_type" = "shared" ]; then
    imported_type="SHARED"
elif [ "$lib_type" = "static" ]; then
    case "$platform:$toolchain" in
        linux:*)
            third_party_libs="mp3lame;opus;vorbisenc;vorbis;ogg;speex;ssl;crypto"
            system_libs="m;pthread;dl;rt;atomic"
            ;;
        macos:*)
            third_party_libs="mp3lame;opus;vorbisenc;vorbis;ogg;speex;ssl;crypto"
            framework_libs="CoreFoundation;Security;AudioToolbox;CoreAudio;VideoToolbox;CoreMedia;CoreVideo;AVFoundation;AppKit;Foundation"
            system_libs="m;pthread;z;bz2;iconv"
            ;;
        windows:mingw)
            third_party_libs="mp3lame;opus;vorbisenc;vorbis;ogg;speex;ssl;crypto"
            system_libs="ws2_32;bcrypt;crypt32;user32;advapi32;ole32;strmiids;uuid;gdi32;psapi"
            ;;
        windows:msvc)
            lib_ext=".lib"
            ffmpeg_lib_prefix="lib"
            system_libs="ws2_32;bcrypt;crypt32;user32;advapi32;ole32;strmiids;uuid;gdi32;psapi"
            ;;
    esac
else
    echo "Unsupported lib_type: $lib_type. Expected static or shared." >&2
    exit 2
fi

if [ "$platform:$toolchain" = "windows:msvc" ]; then
    lib_ext=".lib"
    ffmpeg_lib_prefix="lib"
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
set(_ffmpeg_frameworks "$framework_libs")

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
            if(EXISTS "\${FFmpeg_LIBRARY_DIR}/\${_ffmpeg_library_prefix}\${_ffmpeg_lib}\${_ffmpeg_library_suffix}")
                set(_ffmpeg_static_location "\${FFmpeg_LIBRARY_DIR}/\${_ffmpeg_library_prefix}\${_ffmpeg_lib}\${_ffmpeg_library_suffix}")
            elseif(EXISTS "\${FFmpeg_LIBRARY_DIR}/\${_ffmpeg_lib}\${_ffmpeg_library_suffix}")
                set(_ffmpeg_static_location "\${FFmpeg_LIBRARY_DIR}/\${_ffmpeg_lib}\${_ffmpeg_library_suffix}")
            else()
                set(_ffmpeg_static_location "\${FFmpeg_LIBRARY_DIR}/\${_ffmpeg_library_prefix}\${_ffmpeg_lib}\${_ffmpeg_library_suffix}")
            endif()
            set_target_properties(ffmpeg::\${_ffmpeg_lib} PROPERTIES IMPORTED_LOCATION "\${_ffmpeg_static_location}")
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
    set(_ffmpeg_framework_options "")
    foreach(_ffmpeg_framework IN LISTS _ffmpeg_frameworks)
        list(APPEND _ffmpeg_framework_options "LINKER:-framework,\${_ffmpeg_framework}")
    endforeach()
    set_target_properties(ffmpeg::ffmpeg PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "\${FFmpeg_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "ffmpeg::avdevice;ffmpeg::avfilter;ffmpeg::avformat;ffmpeg::avcodec;ffmpeg::swscale;ffmpeg::swresample;ffmpeg::avutil;\${_ffmpeg_third_party_libs};\${_ffmpeg_system_libs}"
        INTERFACE_LINK_OPTIONS "\${_ffmpeg_framework_options}"
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
unset(_ffmpeg_frameworks)
unset(_ffmpeg_framework_options)
unset(_ffmpeg_framework)
unset(_ffmpeg_implib)
unset(_ffmpeg_implib_path)
unset(_ffmpeg_location)
unset(_ffmpeg_location_path)
unset(_ffmpeg_static_location)
EOF
