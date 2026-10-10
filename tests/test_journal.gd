extends SceneTree
const Main = preload("res://scripts/main.gd")
const Art = preload("res://scripts/species_art.gd")
var checks = 0
var failures = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var main = Main.new()
    root.add_child(main)
    main.set_physics_process(false)
    var journal = main.journal
    var before = JSON.stringify(main.game.snapshot())
    main.open_menu("journal")
    expect(journal.visible and main.game.paused and not main.modal.visible, "journal opens and pauses without requiring a save slot")
    expect(journal.matches.size() == 649, "default journal includes all 649 species")
    expect(journal.filtered_species("", 0).size() == main.game.catalog.regions[0].allocation and journal.filtered_species("", 8).size() == main.game.catalog.regions[8].allocation, "region filter follows catalog allocations")
    expect(journal.filtered_species(" M200 ", -1).size() == 1, "ID search trims whitespace and ignores case")
    expect(journal.filtered_species("이상해", -1).size() == 3, "concept search finds evolution family")
    journal.query.text = "not-found-anywhere"
    journal.refresh()
    expect(journal.matches.is_empty() and journal.preview.texture == null and journal.evolution.get_child_count() == 0, "empty search clears stale detail and art")
    journal.jump_to("m200")
    expect(journal.selected_id == "m200" and journal.matches.size() == 649 and journal.title.text.contains("무우마"), "jump clears filters and selects actual species")
    journal.jump_to("m001")
    journal.evolution.get_child(1).pressed.emit()
    expect(journal.selected_id == "m002" and journal.title.text.contains("이상해풀"), "evolution button opens the relative without evolving an individual")
    expect(JSON.stringify(main.game.snapshot()) == before, "browsing is read-only and does not change collection or saves")
    # The original 96px sprites and branching families must fit the 320x288 UI.
    journal.jump_to("m133")
    for i in 6:
        await process_frame
    expect(journal.get_rect().end.x <= 320 and journal.get_rect().end.y <= 288, "journal stays within the native viewport with a branching family")
    expect(journal.evolution.get_child_count() == 9, "Eevee shows its seven BW evolutions plus the prototype level label")
    expect(journal.evolution.size.x <= journal.detail_scroll.size.x, "branch buttons wrap inside the details column")
    journal.detail_scroll.scroll_vertical = 10000
    for i in 3:
        await process_frame
    var last_relative = journal.evolution.get_child(7)
    expect(journal.detail_scroll.get_global_rect().encloses(last_relative.get_global_rect()), "last branch is reachable by scrolling the details")
    journal.jump_to("m495")
    expect(journal.detail_scroll.scroll_vertical == 0, "selecting another species resets the detail scroll")
    main.show_notice("긴 안내 문구가 화면 아래로 잘리지 않아야 합니다. 이동하고 가까이 다가가서 포켓몬을 포획하세요.\n저장 상태와 동료의 체력도 확인하세요.")
    for i in 4:
        await process_frame
    expect(main.toast_panel.get_rect().end.y <= 288 and main.toast_panel.get_rect().end.x <= 320, "wrapped notices grow upward within the viewport")
    var key = InputEventKey.new()
    key.keycode = KEY_J
    key.pressed = true
    main._unhandled_input(key)
    expect(journal.visible, "typing J while searching does not toggle the journal")
    key.keycode = KEY_ESCAPE
    main._unhandled_input(key)
    expect(not journal.visible and main.modal_kind == "slots" and main.game.paused, "closing pre-game journal restores slot screen")
    main.open_menu("journal")
    journal.query.grab_focus()
    await process_frame
    root.push_input(key)
    expect(not journal.visible and main.modal_kind == "slots", "real Escape input closes journal while search owns focus")
    var diversity = {}
    for enemy in main.game.enemies:
        diversity[enemy.mon.species_id] = true
        expect(int(main.game.spec(enemy.mon).stage) == 0, "ordinary early encounters are unevolved species")
    expect(diversity.size() == 6, "first field contains six regional families")

    # Isolated pixel fixtures exercise the real decoder/cache without user assets.
    var directory = "user://art-test-%d" % Time.get_ticks_usec()
    DirAccess.make_dir_recursive_absolute(directory)
    var fixture = Image.create(8, 8, false, Image.FORMAT_RGBA8)
    fixture.fill(Color.TRANSPARENT)
    fixture.fill_rect(Rect2i(2, 2, 4, 5), Color.WHITE)
    for i in range(1, 41):
        fixture.save_png(directory.path_join("m%03d.png" % i))
    var art = Art.new()
    art.roots = [directory]
    expect(art.texture_for("../m001") == null and art.texture_for("m650") == null and art.texture_for("m-01") == null, "invalid identifiers never become file paths")
    expect(art.texture_for("m001") != null and art.foot_offset("m001") == Vector2(4, 7), "native sprite anchors use opaque bounds")
    var first = art.texture_for("m001")
    expect(art.texture_for("m001") == first, "repeated draws reuse the decoded texture")
    for i in range(2, 41):
        art.texture_for("m%03d" % i)
    expect(art.cache.size() == 32 and art.recent.size() == 32 and not art.cache.has("m001"), "LRU cache is bounded across catalog browsing")
    expect(art.texture_for("m200") == null, "missing art is optional")
    fixture.save_png(directory.path_join("m200.png"))
    expect(art.texture_for("m200") != null, "adding missing art is detected without restarting")
    journal.art = Art.new()
    journal.art.roots = [directory.path_join("absent")]
    journal.jump_to("m001")
    expect(journal.missing.visible and journal.preview.texture == null and journal.title.text.contains("이상해씨"), "missing art keeps usable species details")
    var local_art = Art.new()
    if local_art.texture_for("m001") != null:
        var loaded = 0
        for definition in main.game.catalog.species:
            var texture = local_art.texture_for(definition.id)
            if texture != null and texture.get_size() == Vector2(96, 96):
                loaded += 1
        expect(loaded == 649, "all 649 original PNGs decode at native size")
        print("LOCAL SPRITE CHECKS: %d / 649 loaded (not aesthetic approval)" % loaded)
    else:
        print("LOCAL SPRITE CHECKS: skipped; source-only checkout has no artwork")
    main.queue_free()
    await process_frame
    for file in DirAccess.get_files_at(directory):
        DirAccess.remove_absolute(directory.path_join(file))
    DirAccess.remove_absolute(directory)
    print("JOURNAL CHECKS: %d passed / %d total" % [checks - failures, checks])
    quit(1 if failures else 0)
