#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$PWD/tools/godot/Godot.app/Contents/MacOS/Godot}"
if [ ! -f .godot/global_script_class_cache.cfg ]; then
    "$GODOT_BIN" --headless --path "$PWD" --editor --import --quit
fi
if [ "${1:-}" = "--dex" ]; then
    shift
    exec "$GODOT_BIN" --path "$PWD" "$@" -- --dex
fi
exec "$GODOT_BIN" --path "$PWD" "$@"
