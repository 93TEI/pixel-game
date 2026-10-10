extends SceneTree
## GUI-only visual smoke check. Writes isolated test saves and preview screenshots.
func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    DirAccess.make_dir_recursive_absolute("res://tests/artifacts")
    var ignore = FileAccess.open("res://tests/artifacts/.gdignore", FileAccess.WRITE)
    ignore.close()
    var main = load("res://scripts/main.gd").new()
    var directory = "user://preview-%d" % Time.get_ticks_usec()
    main.save_directory = directory
    root.add_child(main)
    main.set_physics_process(false)
    for i in 8:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/artifacts/bw2010-slots.png")
    main.choose_slot(0)
    main.field.advance(0, Vector2.ZERO)
    main.refresh_hud()
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/artifacts/bw2010-town.png")
    main.game.player = Vector2(760, 550)
    main.game.companion = Vector2(720, 540)
    main.game.command_attack(main.game.enemies[0].mon.uid)
    main.field.advance(.1, Vector2.RIGHT)
    main.refresh_hud()
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/artifacts/bw2010-field.png")
    main.open_menu("journal")
    main.journal.jump_to("m495")
    for i in 4:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/artifacts/bw2010-journal.png")
    main.journal.jump_to("m133")
    for i in 6:
        await process_frame
    main.journal.detail_scroll.scroll_vertical = 10000
    for i in 3:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/artifacts/bw2010-journal-branches.png")
    main.journal.query.text = "없는검색결과"
    main.journal.refresh()
    for i in 4:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/artifacts/bw2010-journal-empty.png")
    main.open_menu("party")
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/artifacts/bw2010-party.png")
    main.game.player = Vector2(224, 560)
    main.game.unlocked = 1
    main.game.beaten = [0]
    main.open_menu("map")
    for i in 4:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/artifacts/bw2010-travel.png")
    main.queue_free()
    await process_frame
    for file in DirAccess.get_files_at(directory):
        DirAccess.remove_absolute(directory.path_join(file))
    DirAccess.remove_absolute(directory)
    print("PREVIEW: slots, town, field, journal, branches, empty search, party, travel captured in tests/artifacts/")
    quit()
