extends SceneTree
## GUI-only visual smoke check. Writes isolated test saves and preview screenshots.
func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var main = load("res://scripts/main.gd").new()
    var directory = "user://preview-%d" % Time.get_ticks_usec()
    main.save_directory = directory
    root.add_child(main)
    main.set_physics_process(false)
    for i in 8:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/private/tmp/monster-trail-slots.png")
    main.choose_slot(0)
    main.field.advance(0, Vector2.ZERO)
    main.refresh_hud()
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/private/tmp/monster-trail-town.png")
    main.game.player = Vector2(760, 550)
    main.game.companion = Vector2(720, 540)
    main.game.command_attack(main.game.enemies[0].mon.uid)
    main.field.advance(.1, Vector2.RIGHT)
    main.refresh_hud()
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/private/tmp/monster-trail-field.png")
    main.open_menu("party")
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/private/tmp/monster-trail-party.png")
    main.queue_free()
    await process_frame
    for file in DirAccess.get_files_at(directory):
        DirAccess.remove_absolute(directory.path_join(file))
    DirAccess.remove_absolute(directory)
    print("PREVIEW: slot, town, field, party screenshots written to /private/tmp/monster-trail-*.png")
    quit()
