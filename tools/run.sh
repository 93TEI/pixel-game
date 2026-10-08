#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ ! -f assets/pixel/trainer.png ]; then
    echo '그래픽 실행 중단: 사용자 요청으로 기존 아트를 모두 삭제했습니다. DESIGN_AGENT.md를 따르는 새 아트가 필요합니다.' >&2
    echo '데이터/모델 검사: sh tools/check.sh --model-only' >&2
    exit 2
fi
GODOT_BIN="${GODOT_BIN:-$PWD/tools/godot/Godot.app/Contents/MacOS/Godot}"
exec "$GODOT_BIN" --path "$PWD" "$@"
