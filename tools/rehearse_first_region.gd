extends SceneTree
## Seeded bot using real terrain, damage and capture odds. Not a human playthrough.
const Main = preload("res://scripts/main.gd")
const STEP = 1.0 / 60.0
var main
var game
var frames = 0
var report = {"scenario": "automated first-region rehearsal with terrain; real combat and capture odds", "seed": 426, "events": [], "success": false}
var directory: String

func _initialize() -> void:
    call_deferred("run")

func record(event: String) -> void:
    report.events.append({"event": event, "seconds": snappedf(game.play_time, .1), "party": game.party.map(func(mon): return {"species": mon.species_id, "level": mon.level, "hp": snappedf(mon.hp, .1)}), "tools": game.tools, "potions": game.potions})

func step(direction = Vector2.ZERO) -> void:
    game.move_player(direction, STEP)
    game.tick(STEP)
    main.field.advance(STEP, direction)
    frames += 1
    if frames % 300 == 0:
        await process_frame

func walk(goal: Vector2, seconds: int = 30) -> bool:
    game.recall()
    for i in seconds * 60:
        if game.player.distance_to(goal) < 6:
            return true
        var waypoint = main.field.next_step(game.player, goal)
        await step(game.player.direction_to(waypoint))
    record("movement timeout toward %s" % goal)
    return false

func rest() -> bool:
    if not await walk(Vector2(224, 560)):
        return false
    main.interact()
    if main.modal_kind != "town":
        return false
    main.modal_content.get_child(2).pressed.emit()
    main.close_menu()
    record("town recovery")
    return true

func target(enemy: Dictionary) -> void:
    var click = InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    click.position = enemy.pos - Vector2(0, 22) - main.field.camera
    main._unhandled_input(click)

func encounter(enemy: Dictionary, recruit: bool) -> bool:
    var approach_point: Vector2 = enemy.pos
    var best_distance = INF
    for i in 16:
        var point: Vector2 = enemy.pos + Vector2.from_angle(i * TAU / 16) * 65
        if main.field.blocked(point) or not game.clear_attack_path(point, enemy.pos):
            continue
        var distance: float = game.player.distance_squared_to(point)
        if distance < best_distance:
            approach_point = point
            best_distance = distance
    if not await walk(approach_point):
        return false
    target(enemy)
    var previous = game.counters.captures
    for i in 60 * 60:
        if game.in_town():
            record("party defeated during encounter")
            return false
        if enemy.mon.hp <= 0 or game.counters.captures > previous:
            record("capture" if game.counters.captures > previous else "wild victory")
            return true
        if recruit and enemy.mon.hp < enemy.max_hp * .65 and game.pending_capture.is_empty() and game.tools > 0:
            var capture = InputEventKey.new()
            capture.keycode = KEY_F
            capture.pressed = true
            main._unhandled_input(capture)
        await step()
    record("encounter timeout")
    return false

func run() -> void:
    main = Main.new()
    directory = "user://rehearsal-%d" % Time.get_ticks_usec()
    main.save_directory = directory
    root.add_child(main)
    main.set_physics_process(false)
    main.choose_slot(0)
    game = main.game
    game.new_game(report.seed)
    main.save_progress()
    record("new adventure")
    var attempts = 0
    while attempts < 35:
        var trained = game.party.size() >= 3 and game.party.all(func(mon): return mon.level >= 6)
        if trained:
            break
        var candidates = game.enemies.filter(func(enemy): return not enemy.boss and enemy.mon.hp > 0)
        if candidates.is_empty():
            if not await rest():
                await finish("could not return to town")
                return
            game.reset_field()
            candidates = game.enemies.duplicate()
        candidates.sort_custom(func(a, b): return game.player.distance_to(a.pos) < game.player.distance_to(b.pos))
        if not await encounter(candidates[0], game.party.size() < 3):
            await finish("encounter or movement failed")
            return
        attempts += 1
        if game.current().hp < game.max_hp(game.current()) * .5:
            if not await rest():
                await finish("recovery failed")
                return
    if not await rest():
        await finish("pre-trial recovery failed")
        return
    record("trained party")
    if game.party.size() < 3:
        await finish("recruitment did not succeed within budget")
        return
    if not await walk(Vector2(1500, 320)):
        await finish("could not reach trial")
        return
    main.interact()
    main.begin_boss()
    record("trial started")
    for i in 180 * 60:
        if 0 in game.beaten:
            break
        if not game.boss_active:
            await finish("trial lost")
            return
        if game.current().hp < game.max_hp(game.current()) * .45:
            game.use_potion(game.active)
        await step()
    if not 0 in game.beaten:
        await finish("trial timeout")
        return
    record("trial won")
    if not await rest():
        await finish("post-trial return failed")
        return
    main.open_menu("map")
    for child in main.modal_content.get_children():
        if child is Button and child.get_meta("destination", -1) == 1:
            child.pressed.emit()
            break
    var restored = TrailGame.new()
    report.success = game.region == 1 and restored.load_game(0, directory) and restored.region == 1 and restored.caught == game.caught
    record("next region and saved collection restored")
    await finish("complete" if report.success else "arrival save mismatch")

func finish(reason: String) -> void:
    report.reason = reason
    report.simulated_seconds = snappedf(game.play_time, .1)
    report.battles = game.counters.battles
    report.captures = game.counters.captures
    report.region = game.region
    var output = JSON.stringify(report, "  ")
    var args = OS.get_cmdline_user_args()
    if not args.is_empty():
        var file = FileAccess.open(args[0], FileAccess.WRITE)
        if file != null:
            file.store_string(output + "\n")
            file.close()
    print(output)
    main.queue_free()
    await process_frame
    for file in DirAccess.get_files_at(directory):
        DirAccess.remove_absolute(directory.path_join(file))
    DirAccess.remove_absolute(directory)
    quit(0 if report.success else 1)
