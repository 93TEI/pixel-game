#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$PWD/tools/godot/Godot.app/Contents/MacOS/Godot}"
if [ "${1:-}" = "--model-only" ] && [ "$#" -eq 1 ]; then
    python3 tools/validate_content.py
    "$GODOT_BIN" --headless --path "$PWD" --script res://tests/test_game.gd
    echo 'MODEL ONLY: visual and integration checks were not run; artwork was deleted.'
    exit 0
fi
if [ "$#" -gt 0 ]; then
    echo 'Usage: sh tools/check.sh [--model-only]' >&2
    exit 2
fi
if [ ! -f assets/pixel/manifest.json ]; then
    echo 'Full checks unavailable: artwork was deleted at user request. See DESIGN_AGENT.md; use --model-only for data/model checks.' >&2
    exit 2
fi
python3 tools/validate_content.py
python3 tools/check_pixel_art.py
"$GODOT_BIN" --headless --path "$PWD" --editor --import --quit
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/test_game.gd
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/test_playable.gd
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/test_visuals.gd
