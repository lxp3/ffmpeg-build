#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/build-common.sh"

TARGET_OS="$(resolve_target_os)"
export TARGET_OS

case "$TARGET_OS" in
    linux)
        exec "$SCRIPT_DIR/build-linux.sh"
        ;;
    windows)
        exec "$SCRIPT_DIR/build-window.sh"
        ;;
    *)
        echo "Unsupported TARGET_OS=$TARGET_OS. Supported: linux, windows" >&2
        exit 1
        ;;
esac
