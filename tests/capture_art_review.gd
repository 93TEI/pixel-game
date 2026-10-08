extends SceneTree
## Real renderer/real combat entry points, deterministic poses, no player saves.
var main
var output = "res://art-studies/visual-review-2026-10-07"

func _initialize() -> void:
    call_deferred("run")

func capture(name: String) -> void:
    main.field.queue_redraw()
    main.refresh_hud()
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    main = load("res://scripts/main.gd").new()
    root.add_child(main)
    main.set_physics_process(false)
    main.set_process(false)
    main.game.auto_save_enabled = false
    main.game.new_game(426)
    main.session_started = true
    main.close_menu()
    main.toast_panel.hide()
    main.field.advance(0, Vector2.ZERO)
    await capture("town")
    # Compare at the earlier camera offset as well, so framing alone cannot explain improvement.
    main.field.camera = (main.game.player - Vector2(160, 192)).floor()
    await capture("town-same-camera")
    var before = Image.load_from_file("res://art-studies/gold-before-polish-2026-10-07/town.png")
    var after = Image.load_from_file(output.path_join("town-same-camera.png"))
    if before != null and after != null:
        before.convert(Image.FORMAT_RGBA8)
        after.convert(Image.FORMAT_RGBA8)
        var comparison = Image.create(640, 234, false, Image.FORMAT_RGBA8)
        # Same camera, same crop. Exclude the old temporary onboarding toast.
        comparison.blit_rect(before, Rect2i(0, 0, 320, 234), Vector2i.ZERO)
        comparison.blit_rect(after, Rect2i(0, 0, 320, 234), Vector2i(320, 0))
        comparison.save_png(output.path_join("comparison.png"))
    var game = main.game
    var enemy = game.enemies[0]
    game.enemies = [enemy]
    game.player = Vector2(736, 566)
    game.companion = Vector2(702, 535)
    enemy.pos = Vector2(751, 535)
    game.command_attack(enemy.mon.uid)
    main.field.advance(0, Vector2.ZERO)
    game.cast = {"skill": game.current().moves[0], "time": .3, "total": .3}
    main.field.animation_time = .2
    await capture("cast")
    game.cast.clear()
    game.current().enabled = [false, false, false, false]
    game.tick_companion_attack(enemy, .01)
    main.field.advance(.04, Vector2.ZERO)
    await capture("attack-hit")
    main.field.advance(.4, Vector2.ZERO)
    game.hurt(enemy.mon, enemy.mon.hp + 1, enemy.pos)
    main.field.advance(.46, Vector2.ZERO)
    await capture("faint")
    # Scripted visual reel, not a balance/playtime claim. Uses actual game attack/hurt methods.
    DirAccess.make_dir_recursive_absolute(output.path_join("motion"))
    game.reset_field()
    enemy = game.enemies[0]
    game.enemies = [enemy]
    game.player = Vector2(736, 566)
    game.companion = Vector2(702, 535)
    enemy.pos = Vector2(751, 535)
    main.field.sfx.enabled = false
    main.field.advance(0, Vector2.ZERO)
    for i in 120:
        var direction = Vector2.ZERO
        if i < 24:
            direction = Vector2.RIGHT if i < 12 else Vector2.LEFT
            game.move_player(direction, 1.0 / 30)
        if i == 24:
            game.command_attack(enemy.mon.uid)
            game.cast = {"skill": game.current().moves[0], "time": .3, "total": .3}
        if i == 45:
            game.cast.clear()
            game.current().enabled = [false, false, false, false]
            game.tick_companion_attack(enemy, .01)
        if i == 75:
            game.hurt(enemy.mon, enemy.mon.hp + 1, enemy.pos)
        main.field.advance(1.0 / 30, direction)
        await capture("motion/%03d" % i)
    main.queue_free()
    await process_frame
    print("ART REVIEW: town / same-camera / cast / attack-hit / faint in ", output)
    quit()
