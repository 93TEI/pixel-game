Visual materials are excluded from this repository (시각 자료는 이 저장소에서 제외했습니다).

# Pixel Game

A native Godot real-time Pokémon fan prototype with the 649-species roster available
in Pokémon Black/White (2010). The earlier assistant-created artwork has been deleted.

This repository contains gameplay source, a 649-species catalog, tests,
and development tools. Agent instructions, implementation/design notes, all other
Markdown documents, visual references, artwork, previews, and fonts are local-only
and managed through `.gitignore`.

Local assets use Black/White front/back sprites and battle GIFs from
[PokéAPI sprites](https://github.com/PokeAPI/sprites), plus locally sourced BW trainer
frames, environment textures, house models and party UI sheets. Crystal, Red/Blue
and Black 2/White 2 assets are not used. Missing local art does not prevent startup;
the field then has limited visual feedback and species names in place of sprites.
Real-time combat, move slots, regional encounters and automatic evolution are
prototype adaptations; this is not a recreation of the original campaign.
Branching/non-level evolutions currently use simplified automatic progression.
The field plays the original battle sprite animations; these are not directional
overworld movement animations. The map layout and UI composition remain prototype
adaptations, and do not match the original BW screens. The full campaign and distinct
regional maps are unfinished.
No game executable release is provided.

## Run

Use an existing Godot 4.7.2 executable (not bundled):

```sh
GODOT_BIN=/path/to/godot sh tools/run.sh
GODOT_BIN=/path/to/godot sh tools/run.sh --dex
```

WASD moves, left click commands an attack, right click recalls, F captures,
1–6 switches companions, E interacts, Tab opens the party, J opens the journal,
and Escape pauses/closes menus. The journal is also available before choosing a save.

The optional sprite/data downloader uses pinned public source revisions and no paid services:

```sh
python3 tools/fetch_pokemon.py
```

`tools/import_bw_assets.py` decodes GIFs and locally available BW trainer/model
sources using Pillow. It requires the separate source files under
`assets/pokemon/source/bw/`; the sprite downloader does not supply those files.

Graphics, source archives, hashes and provenance remain local in `assets/pokemon/`
and are gitignored. Sprites are displayed at their original pixel size; none of the
discarded artwork is used. Browsing the journal does not modify collection or saves.
BW saves use a separate app data directory and `pokemon-bw2010-saves` subdirectory;
older prototype saves are preserved and are not converted into different species.

## Validation

Python 3 and Godot 4.7.2 are required. The engine is not bundled.
Point `GODOT_BIN` at your existing Godot executable:

```sh
GODOT_BIN=/path/to/godot sh tools/check.sh --model-only
GODOT_BIN=/path/to/godot sh tools/check.sh
```

The full check runs catalog, model, combat regression, playable integration, combat effect wiring,
and journal/cache tests, including layout and scrolling at the 320×288 native size.
Local sprite decoding is checked when artwork is present.
Checks also run without images/fonts. These checks do not establish aesthetic
approval or completion of the campaign or a full playthrough.

For reproducible first-region combat samples (20 seeds per scenario):

```sh
/path/to/godot --headless --path . --script res://tools/measure_combat.gd
```

This reports ordinary encounters and first-boss results with three or six companions,
including potion and recall strategies. It runs the game model without terrain or
human input; it is a balance measurement, not a full playthrough.

## License

Source code and tooling use the [MIT license](LICENSE).
Pokémon graphics, characters and branding are third-party material and are not
covered by this project's MIT license. Asset download availability is not a grant
of redistribution rights; no asset-inclusive release is provided.
