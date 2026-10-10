extends PanelContainer
## Read-only catalog UI: searching or inspecting never changes collection or saves.
signal closed
const Art = preload("res://scripts/species_art.gd")
const DexTheme = preload("res://scripts/bw_dex_theme.gd")
var game: TrailGame
var art = Art.new()
var selected_id = "m495"
var matches: Array = []
var query: LineEdit
var region_filter: OptionButton
var species_list: ItemList
var preview: TextureRect
var title: Label
var detail: RichTextLabel
var evolution: HFlowContainer
var detail_scroll: ScrollContainer
var count: Label
var missing: Label

func setup(model: TrailGame, shared_art: RefCounted = null) -> void:
    game = model
    if shared_art != null:
        art = shared_art
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    custom_minimum_size = Vector2(312, 280)
    size = custom_minimum_size
    var panel = get_theme_stylebox("panel").duplicate()
    for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
        panel.set_content_margin(side, 6)
    add_theme_stylebox_override("panel", panel)
    var column = VBoxContainer.new()
    column.add_theme_constant_override("separation", 5)
    add_child(column)
    var heading_panel = PanelContainer.new()
    column.add_child(heading_panel)
    var heading = HBoxContainer.new()
    heading_panel.add_child(heading)
    count = Label.new()
    count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(count)
    var back = Button.new()
    back.text = "닫기"
    back.pressed.connect(func(): closed.emit())
    heading.add_child(back)
    var filters = HBoxContainer.new()
    column.add_child(filters)
    query = LineEdit.new()
    query.placeholder_text = "이름 / 번호 / 특징"
    query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    query.custom_minimum_size.x = 140
    filters.add_child(query)
    region_filter = OptionButton.new()
    region_filter.add_item("모든 지역", -1)
    for region in game.catalog.regions:
        region_filter.add_item(region.town, int(region.index))
    filters.add_child(region_filter)
    var body = HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(body)
    species_list = ItemList.new()
    species_list.clip_contents = true
    species_list.custom_minimum_size = Vector2(104, 0)
    species_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    species_list.add_theme_font_size_override("font_size", 11)
    body.add_child(species_list)
    species_list.resized.connect(species_list.ensure_current_is_visible)
    detail_scroll = ScrollContainer.new()
    detail_scroll.custom_minimum_size.x = 174
    detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(detail_scroll)
    var info = VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail_scroll.add_child(info)
    title = Label.new()
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.add_theme_font_size_override("font_size", 12)
    info.add_child(title)
    var preview_panel = PanelContainer.new()
    info.add_child(preview_panel)
    preview = TextureRect.new()
    preview.custom_minimum_size = Vector2(64, 64)
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    preview_panel.add_child(preview)
    missing = Label.new()
    missing.text = "이미지 없음"
    missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    missing.add_theme_font_size_override("font_size", 10)
    info.add_child(missing)
    detail = RichTextLabel.new()
    var info_panel = PanelContainer.new()
    info.add_child(info_panel)
    detail.custom_minimum_size.y = 84
    detail.fit_content = true
    detail.scroll_active = false
    detail.add_theme_font_size_override("normal_font_size", 10)
    info_panel.add_child(detail)
    evolution = HFlowContainer.new()
    info.add_child(evolution)
    query.text_changed.connect(func(_value): refresh())
    region_filter.item_selected.connect(func(_index): refresh())
    species_list.item_selected.connect(func(index): select_species(matches[index].id))
    DexTheme.apply(self, preview_panel, info_panel, heading_panel)
    refresh()

func filtered_species(search: String, region: int) -> Array:
    var result: Array = []
    var needle = search.strip_edges().to_lower()
    for definition in game.catalog.species:
        if region >= 0 and int(definition.region) != region:
            continue
        var haystack = "%s %03d %s %s %s" % [definition.id, int(definition.dex), definition.name, definition.family, definition.concept]
        if needle.is_empty() or needle in haystack.to_lower():
            result.append(definition)
    return result

func refresh() -> void:
    matches = filtered_species(query.text, region_filter.selected - 1)
    species_list.clear()
    count.text = "도감 %d/%d" % [matches.size(), game.catalog.species.size()]
    var selected_index = 0
    for i in matches.size():
        var definition = matches[i]
        species_list.add_item("%s %03d %s" % ["●" if definition.id in game.caught else "○", int(definition.dex), definition.name])
        species_list.set_item_tooltip(i, "%s · %s" % [definition.name, "포획함" if definition.id in game.caught else "미포획"])
        if definition.id == selected_id:
            selected_index = i
    if matches.is_empty():
        selected_id = ""
        title.text = "검색 결과 없음"
        preview.texture = null
        missing.hide()
        detail.text = "검색어나 지역을 바꿔 보세요."
        clear_evolution()
        return
    species_list.select(selected_index)
    select_species(matches[selected_index].id)

func clear_evolution() -> void:
    for child in evolution.get_children():
        evolution.remove_child(child)
        child.queue_free()

func select_species(sid: String) -> void:
    if not game.species.has(sid):
        return
    selected_id = sid
    detail_scroll.scroll_vertical = 0
    var definition: Dictionary = game.species[sid]
    title.text = "%03d %s · %s" % [int(definition.dex), definition.name, definition.rank]
    preview.texture = art.texture_for(sid)
    if preview.texture != null:
        preview.custom_minimum_size = preview.texture.get_size()
    missing.visible = preview.texture == null
    detail.text = "%s · 기술 %d칸\n체력 %d / 공격 %d / 방어 %d\n특공 %d / 특방 %d / 속도 %d\n\n%s\n\n%s" % [game.catalog.regions[int(definition.region)].town, int(definition.slots), int(definition.base_stats[0]), int(definition.base_stats[1]), int(definition.base_stats[2]), int(definition.base_stats[3]), int(definition.base_stats[4]), int(definition.base_stats[5]), definition.concept, definition.ecology]
    detail.scroll_to_line(0)
    clear_evolution()
    for relative in game.catalog.species:
        if relative.family != definition.family:
            continue
        var button = Button.new()
        button.text = str(int(relative.dex))
        button.tooltip_text = relative.name
        button.disabled = relative.id == sid
        button.add_theme_font_size_override("font_size", 10)
        var relative_id: String = relative.id
        button.pressed.connect(func(): jump_to(relative_id))
        evolution.add_child(button)
    if not String(definition.evolves_to).is_empty():
        var level = Label.new()
        level.text = "Lv.%d 진화" % int(definition.evolution_level)
        level.add_theme_font_size_override("font_size", 10)
        evolution.add_child(level)

func jump_to(sid: String) -> void:
    selected_id = sid
    query.set_text("")
    region_filter.select(0)
    refresh()
    species_list.ensure_current_is_visible()
