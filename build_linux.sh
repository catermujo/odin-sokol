#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

sh "$SCRIPT_DIR/build_static.sh"
sh "$SCRIPT_DIR/build.sh"
