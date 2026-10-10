extends SceneTree
## Exercise real menu buttons and saves; forced boss outcomes do not measure balance.
const Main = preload("res://scripts/main.gd")
var checks = 0
var failures = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func destination_button(main, destination: int) -> Button:
    for child in main.modal_content.get_children():
        if child is Button and child.get_meta("destination", -1) == destination:
            return child
    return null

func run() -> void:
    var main = Main.new()
    var directory = "user://progression-test-%d" % Time.get_ticks_usec()
    main.save_directory = directory
    root.add_child(main)
    main.set_physics_process(false)
    expect(main.choose_slot(0), "new slot starts progression scenario")
    var game = main.game
    main.open_menu("map")
    expect(destination_button(main, 0).disabled, "current region cannot be accidentally reset by its map button")
    expect(destination_button(main, 1).disabled, "next region is locked before the first victory")
    var before = JSON.stringify(game.snapshot())
    expect(not main.travel_to(1) and not main.travel_to(-1) and not main.travel_to(9), "locked and invalid destinations are rejected")
    expect(JSON.stringify(game.snapshot()) == before, "rejected travel preserves party, inventory and progress")
    main.close_menu()

    for region in game.catalog.regions.size():
        game.player = Vector2(1500, 320)
        main.interact()
        expect(main.modal_kind == "boss", "region %d trial can be opened" % region)
        main.begin_boss()
        expect(game.boss_active and not game.paused, "region %d trial starts from menu" % region)
        main.open_menu("map")
        expect(destination_button(main, 0).disabled and not main.travel_to(0), "active trial cannot be escaped via travel")
        main.close_menu()
        # Settle only the combat outcome; production reward/unlock/save code is exercised.
        for round_index in game.boss_lineup().size():
            var enemy = game.enemies.back()
            enemy.mon.hp = 0
            game.defeat_enemy(enemy)
        expect(not game.boss_active and region in game.beaten, "region %d trial victory recorded" % region)
        var restored = TrailGame.new()
        expect(restored.load_game(0, directory) and restored.region == region and region in restored.beaten and restored.unlocked == mini(region + 1, 8), "region %d victory autosave restores unlocks" % region)
        expect(restored.party[0].ivs == game.party[0].ivs and restored.party[0].branches == game.party[0].branches, "region %d save preserves fixed individual properties" % region)
        if region == 8:
            expect(main.toast.text.contains("마지막 시험 완료"), "final victory announces rematches instead of a nonexistent next road")
            break
        main.open_menu("map")
        expect(destination_button(main, region + 1).disabled, "travel remains unavailable outside town")
        expect(not main.travel_to(region + 1), "direct callback cannot bypass town requirement")
        game.player = Vector2(224, 560)
        main.open_menu("town")
        var map_button: Button
        for child in main.modal_content.get_children():
            if child is Button and child.text.contains("다른 지역"):
                map_button = child
        expect(map_button != null, "town exposes region travel")
        map_button.pressed.emit()
        expect(main.modal_kind == "map", "town travel button opens region map")
        var next = destination_button(main, region + 1)
        expect(not next.disabled, "newly unlocked destination is selectable in town")
        var uid = game.current().uid
        next.pressed.emit()
        expect(game.region == region + 1 and game.in_town() and not game.paused and main.modal_kind.is_empty(), "destination button arrives and resumes exploration")
        expect(game.current().uid == uid and not main.field.blocked(game.player), "travel preserves companion and places trainer on walkable ground")
        expect(game.enemies.all(func(enemy): return int(game.spec(enemy.mon).region) == region + 1), "destination uses its own regional encounters")
        expect(restored.load_game(0, directory) and restored.region == region + 1, "arrival automatically saves the destination")

    game.player = Vector2(224, 560)
    expect(main.travel_to(0), "after final victory the first region can be revisited")
    game.player = Vector2(1500, 320)
    main.interact()
    var rematch: Button
    for child in main.modal_content.get_children():
        if child is Button and child.text == "다시 도전":
            rematch = child
    expect(rematch != null, "completed campaign exposes a rematch button")
    rematch.pressed.emit()
    expect(game.boss_active, "rematch starts through the real button")
    expect(game.counters.bosses == 9, "progress counts nine distinct trials")
    main.queue_free()
    await process_frame
    for file in DirAccess.get_files_at(directory):
        DirAccess.remove_absolute(directory.path_join(file))
    DirAccess.remove_absolute(directory)
    print("PROGRESSION CHECKS: %d passed / %d total (forced battle outcomes; not a campaign playthrough)" % [checks - failures, checks])
    quit(1 if failures else 0)
