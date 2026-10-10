extends RefCounted
## Crops of original BW dex sheets. No generated replacement assets.
const Art = preload("res://scripts/species_art.gd")
const ROOT = "res://assets/pokemon/black-white/ui/"

static func box(file: String, region: Rect2, margin: int = 4) -> StyleBoxTexture:
    var source = Art.optional_texture([ROOT + file])
    if source == null:
        return null
    var texture = AtlasTexture.new()
    texture.atlas = source
    texture.region = region
    var style = StyleBoxTexture.new()
    style.texture = texture
    style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
    style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
    for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
        style.set_content_margin(side, margin)
    return style

static func apply(journal: Control, preview_panel: Control, info_panel: Control, heading_panel: Control) -> void:
    var background = box("dex-background.png", Rect2(0, 0, 8, 8), 6)
    if background == null:
        return
    journal.add_theme_stylebox_override("panel", background)
    var heading = box("dex-heading.png", Rect2(8, 0, 160, 23), 2)
    if heading != null:
        heading.set_texture_margin(SIDE_BOTTOM, 1)
        heading_panel.add_theme_stylebox_override("panel", heading)
    var dark = box("dex-entry.png", Rect2(0, 116, 256, 49), 4)
    if dark != null:
        for side in [SIDE_TOP, SIDE_BOTTOM]:
            dark.set_texture_margin(side, 1)
        preview_panel.add_theme_stylebox_override("panel", dark)
        info_panel.add_theme_stylebox_override("panel", dark)
        journal.species_list.add_theme_stylebox_override("panel", dark)
        journal.query.add_theme_stylebox_override("normal", dark)
        journal.query.add_theme_stylebox_override("focus", dark)
    var selected = box("dex-selected.png", Rect2(128, 1, 112, 20), 0)
    if selected != null:
        journal.species_list.add_theme_stylebox_override("selected", selected)
        journal.species_list.add_theme_stylebox_override("selected_focus", selected)
    var row = box("dex-row.png", Rect2(128, 1, 112, 20), 0)
    if row != null:
        journal.species_list.add_theme_stylebox_override("cursor", row)
