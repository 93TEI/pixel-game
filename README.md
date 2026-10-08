Visual materials are excluded from this repository (시각 자료는 이 저장소에서 제외했습니다).

# Pixel Game

A work-in-progress native Godot single-player monster RPG, developed under the
working title **Monster Trail · 새봄의 기록**.

This repository contains gameplay source, a 200-species design catalog, tests,
and development tools. Agent instructions, implementation/design notes, all other
Markdown documents, visual references, artwork, previews, and fonts are local-only
and managed through `.gitignore`.

The game is **not currently playable from this repository**: runtime visual assets
are not included. No game executable release is provided.

## Model validation

Python 3 and Godot 4.7.2 are required. The engine is not bundled.
Point `GODOT_BIN` at your existing Godot executable:

```sh
GODOT_BIN=/path/to/godot sh tools/check.sh --model-only
```

Validated on 2026-10-08: catalog checks passed; **36/36 model checks passed**.
This does not validate graphics, integration, or a full playthrough.

## License

Source code and tooling use the [MIT license](LICENSE).
