extends SceneTree
const Main = preload("res://scripts/main.gd")
var checks: int = 0
var failures: int = 0

func expect(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FAIL: " + description)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var main = Main.new()
    var directory = "user://playable-test-%d" % Time.get_ticks_usec()
    main.save_directory = directory
    root.add_child(main)
    main.set_physics_process(false)
    var game = main.game
    expect(game.paused and not main.session_started, "slot selector pauses field")
    expect(main.choose_slot(0) and not game.paused, "empty slot starts adventure")
    expect(FileAccess.file_exists(directory.path_join("slot_0.json")), "new adventure persists to selected test slot")
    var before = game.player
    game.move_player(Vector2.RIGHT, 1.0)
    expect(game.player.x > before.x, "trainer movement connected")
    expect(main.field.blocked(Vector2(200, 420)), "house blocks actors")
    expect(main.field.blocked(Vector2(900, 340)), "pond blocks actors")
    expect(main.field.blocked(Vector2(112, 480)), "pixel tree trunk has collision")
    expect(main.field.blocked(Vector2(160, 660)) and not main.field.blocked(Vector2(320, 660)), "fence blocks except for village gate")
    game.player = Vector2(224, 524)
    for i in 60:
        game.move_player(Vector2.UP, 1.0/60.0)
    expect(game.player.y >= 508, "walking into house stops at collision margin")
    var walker = Vector2(780, 350)
    for i in 1200:
        walker = game.approach(walker, Vector2(1100, 350), 120, 1.0/60.0)
        if walker.distance_to(Vector2(1100, 350)) < 4:
            break
    expect(walker.distance_to(Vector2(1100, 350)) < 4, "companion navigates around pond")
    # A close target across a fence must be approached through the gate, not hit through it.
    var fence_enemy = game.enemies[0]
    var original_enemy_pos: Vector2 = fence_enemy.pos
    game.player = Vector2(200, 638)
    game.companion = game.player
    fence_enemy.pos = Vector2(200, 690)
    expect(not game.clear_attack_path(game.companion, fence_enemy.pos), "fence blocks attack line")
    expect(game.clear_attack_path(Vector2(320, 638), Vector2(320, 690)), "gate permits attack line")
    game.command_attack(fence_enemy.mon.uid)
    var fence_hp = fence_enemy.mon.hp
    game.current().enabled = [false, false, false, false]
    game.basic_timer = 0
    game.tick_companion_attack(fence_enemy, .1)
    expect(fence_enemy.mon.hp == fence_hp, "ally basic attack cannot cross fence")
    var skill_id = game.current().moves[0]
    game.cast = {"skill": skill_id, "time": .01, "total": .1}
    game.tick_companion_attack(fence_enemy, .1)
    expect(game.cast.is_empty() and fence_enemy.mon.hp == fence_hp and game.current().cooldowns.get(skill_id, 0) == 0, "blocked windup cancels without damage or cooldown")
    var ally_hp = game.current().hp
    fence_enemy.attack_timer = 0
    fence_enemy.cast = {"skill": skill_id, "time": .01}
    game.tick_enemy(fence_enemy, .1)
    expect(game.current().hp == ally_hp and fence_enemy.cast.is_empty(), "enemy windup cannot cross fence")
    fence_enemy.mon.cooldowns[skill_id] = 10
    game.tick_enemy(fence_enemy, .1)
    expect(game.current().hp == ally_hp, "enemy basic attack cannot cross fence")
    var fence_tools = game.tools
    expect(not game.begin_capture() and game.tools == fence_tools, "blocked capture consumes no tool")
    var approach_start: Vector2 = game.companion
    game.tick(.1)
    expect(game.companion.distance_to(approach_start) > 0 and not main.field.blocked(game.companion), "close blocked target still triggers navigation")
    game.recall()
    game.current().enabled = [true, true, true, true]
    fence_enemy.pos = original_enemy_pos
    fence_enemy.alert = false
    fence_enemy.mon.cooldowns.clear()
    game.player = Vector2(224, 524)
    main.open_menu("party")
    game.hurt(game.current(), 1, game.companion)
    var recoil_life = main.field.actor_states[game.current().uid].life
    main._physics_process(1)
    expect(main.field.actor_states[game.current().uid].life == recoil_life, "menu freezes combat animation alongside simulation")
    var time_before = game.play_time
    game.tick(5)
    game.move_player(Vector2.RIGHT, 1)
    expect(game.play_time == time_before and game.player.y >= 508, "party menu pauses model")
    for kind in ["journal", "map", "town", "storage", "pause"]:
        main.open_menu(kind)
        expect(game.paused and main.modal_content.get_child_count() > 1, "menu renders: " + kind)
    main.close_menu()
    game.player = Vector2(640, 540)
    game.companion = Vector2(660, 540)
    main.field.update_camera()
    var enemy = game.enemies[0]
    var click = InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    click.position = (enemy.pos - Vector2(0, 22) - main.field.camera)
    main._unhandled_input(click)
    expect(game.target_id == enemy.mon.uid, "mouse coordinates select visible enemy")
    var health = enemy.mon.hp
    for i in 120:
        game.tick(1.0/60.0)
    expect(enemy.mon.hp < health, "selected companion attacks in real time")
    expect(not main.manual_save(), "manual save rejected during combat")
    click.button_index = MOUSE_BUTTON_RIGHT
    main._unhandled_input(click)
    game.tick(.2)
    expect(game.target_id.is_empty() and game.recalling, "recall survives AI retargeting")
    game.command_attack(enemy.mon.uid)
    var hp_before = game.current().hp
    var enemy_before = enemy.mon.hp
    var tools_before = game.tools
    var capture_key = InputEventKey.new()
    capture_key.keycode = KEY_F
    capture_key.pressed = true
    main._unhandled_input(capture_key)
    expect(not game.pending_capture.is_empty() and game.tools == tools_before - 1, "F initiates capture and consumes tool")
    game.tick(.5)
    expect(enemy.mon.hp == enemy_before and game.current().hp == hp_before, "capture suspends both participants' attacks")
    # Force success only here, making input/save wiring deterministic, not changing live odds.
    game.pending_capture.chance = 1.0
    var ivs = enemy.mon.ivs.duplicate()
    game.tick(.8)
    expect(game.party.size() == 2 and game.party[1].ivs == ivs, "capture adds immutable individual")
    var restored = TrailGame.new()
    expect(restored.load_game(0, directory) and restored.party.size() == 2, "capture signal writes automatic save")
    var key = InputEventKey.new()
    key.keycode = KEY_2
    key.pressed = true
    main._unhandled_input(key)
    expect(game.active == 1, "number key switches party")
    game.player = Vector2(320, 560)
    game.current().hp = 1
    main.interact()
    expect(main.modal_kind == "town" and game.paused, "E opens town services")
    # Invoke the actual heal button signal rather than a separate model-only path.
    main.modal_content.get_child(2).pressed.emit()
    expect(game.current().hp == game.max_hp(game.current()), "town heal button restores party")
    main.close_menu()
    expect(main.manual_save(), "manual save succeeds when safe")
    game.player = Vector2(1500, 320)
    main.interact()
    expect(main.modal_kind == "boss", "arena interaction opens challenge")
    main.begin_boss()
    expect(game.boss_active and not game.paused, "challenge starts battle")
    expect(main.field.blocked(Vector2(1300, 320)), "active arena confines actors")
    expect(main.field.blocked(game.player) == false, "boss starts player inside walkable arena")
    for mon in game.party:
        mon.hp = 0
    game.handle_faint()
    expect(game.in_town() and not game.boss_active and not main.field.blocked(game.player), "defeat releases arena and restores safe spawn")
    # A corrupt existing slot is never automatically replaced by a new game.
    main.session_started = false
    var bad_path = directory.path_join("slot_2.json")
    var bad = FileAccess.open(bad_path, FileAccess.WRITE)
    bad.store_string("broken-save")
    bad.close()
    expect(not main.choose_slot(2) and FileAccess.get_file_as_string(bad_path) == "broken-save", "corrupt slot remains untouched")
    main.queue_free()
    await process_frame
    for file in DirAccess.get_files_at(directory):
        DirAccess.remove_absolute(directory.path_join(file))
    DirAccess.remove_absolute(directory)
    print("PLAYABLE CHECKS: %d passed / %d total" % [checks - failures, checks])
    quit(1 if failures else 0)
