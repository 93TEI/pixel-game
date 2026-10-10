#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-$PWD/tools/godot/Godot.app/Contents/MacOS/Godot}"
if [ "${1:-}" = "--model-only" ] && [ "$#" -eq 1 ]; then
    python3 tools/validate_content.py
    "$GODOT_BIN" --headless --path "$PWD" --script res://tests/test_game.gd
    "$GODOT_BIN" --headless --path "$PWD" --script res://tests/test_combat.gd
    echo 'MODEL ONLY: UI and integration checks were not run.'
    exit 0
fi
if [ "$#" -gt 0 ]; then
    echo 'Usage: sh tools/check.sh [--model-only]' >&2
    exit 2
fi
python3 tools/validate_content.py
python3 tools/verify_pokemon_assets.py
"$GODOT_BIN" --headless --path "$PWD" --editor --import --quit
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/test_game.gd
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/test_combat.gd
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/test_playable.gd
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/test_progression.gd
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/test_visuals.gd
"$GODOT_BIN" --headless --path "$PWD" --script res://tests/test_journal.gd
