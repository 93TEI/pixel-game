extends SceneTree
const Game = preload("res://scripts/game.gd")
var failures: int = 0
var checks: int = 0

func expect(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FAIL: " + label)

func fresh() -> RefCounted:
    var game = Game.new()
    game.auto_save_enabled = false
    game.new_game(426)
    return game

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var g = fresh()
    expect(g.party.size() == 1 and g.enemies.size() == 14, "initial party and field")
    var a = g.make_monster("m001", 8, 919)
    var b = g.make_monster("m001", 8, 919)
    expect(a.ivs == b.ivs and a.branches == b.branches and a.moves == b.moves, "seed fixes roll")
    expect(a.uid != b.uid, "individual IDs remain distinct")
    var original_ivs = a.ivs.duplicate()
    var original_branches = a.branches.duplicate()
    a.level = 16
    a.cooldowns[a.moves[0]] = 2.5
    expect(g.maybe_evolve(a), "evolves at threshold")
    expect(a.species_id == "m002" and a.ivs == original_ivs and a.branches == original_branches, "evolution retains IVs and branches")
    expect(a.moves.size() == 2 and a.cooldowns[a.moves[0]] == 2.5, "evolution expands moves without cooldown reset")
    var save = g.snapshot()
    expect(g.validate_snapshot(save), "fresh snapshot validates")
    expect(g.validate_snapshot(JSON.parse_string(JSON.stringify(save))), "JSON numeric roundtrip validates")
    var malformed = save.duplicate(true)
    malformed.version = 1
    expect(not g.validate_snapshot(malformed), "legacy original-species save cannot silently become Pokemon")
    malformed = save.duplicate(true)
    malformed.party[0].species_id = "not-a-species"
    expect(not g.validate_snapshot(malformed), "unknown species rejected")
    malformed = save.duplicate(true)
    malformed.party[0].ivs[0] = 32
    expect(not g.validate_snapshot(malformed), "invalid IV rejected")
    malformed = save.duplicate(true)
    malformed.party[0].moves[0] = "unknown-move"
    expect(not g.validate_snapshot(malformed), "invalid move rejected")
    malformed = save.duplicate(true)
    malformed.party[0].order = [0,0,0,0]
    expect(not g.validate_snapshot(malformed), "invalid priority rejected")
    var restored = fresh()
    expect(restored.restore(save), "restore accepted")
    expect(restored.party[0].ivs == g.party[0].ivs and restored.party[0].moves == g.party[0].moves, "save does not reroll")
    var e = g.enemies[0]
    g.command_attack(e.mon.uid)
    g.player = e.pos - Vector2(20, 0)
    var healthy = g.capture_chance(e)
    e.mon.hp = 1
    expect(g.capture_chance(e) > healthy, "weakening increases capture chance")
    var tool_count = g.tools
    expect(g.begin_capture() and g.tools == tool_count - 1, "capture consumes exactly one tool")
    expect(not g.begin_capture() and g.tools == tool_count - 1, "duplicate capture blocked")
    g.pending_capture.chance = 1.0
    var captured_iv = e.mon.ivs.duplicate()
    expect(g.finish_capture() and g.party.size() == 2, "capture success adds party member")
    expect(g.party[1].ivs == captured_iv, "capture keeps generated IVs")
    g.current().cooldowns[g.current().moves[0]] = 4.0
    expect(g.switch_to(1), "switch to living reserve")
    expect(not g.switch_to(0), "switch cooldown enforced")
    var before_time = g.play_time
    var before_switch = g.switch_timer
    g.paused = true
    g.tick(3.5)
    expect(g.play_time == before_time and g.switch_timer == before_switch, "pause freezes simulation")
    g.paused = false
    g.tick(1.0)
    expect(g.party[0].cooldowns[g.party[0].moves[0]] == 3.0, "reserve cooldown continues")
    while g.party.size() < 6:
        g.party.append(g.make_monster("m004", 5))
    e = g.enemies[0]
    g.player = e.pos
    g.command_attack(e.mon.uid)
    expect(g.begin_capture(), "capture with full party starts")
    g.pending_capture.chance = 1.0
    expect(g.finish_capture() and g.party.size() == 6 and g.storage.size() == 1, "full party capture goes to storage")
    var c = g.coins
    for mon in g.party:
        mon.hp = 0
    g.handle_faint()
    expect(g.current().hp > 0 and g.in_town() and g.coins == int(c*.95), "defeat heals and returns to town")
    expect(not g.travel(1), "locked region inaccessible")
    g.unlocked = 1
    expect(g.travel(1) and g.region == 1, "unlocked region travel")
    expect(g.start_boss(), "boss starts")
    var boss = g.enemies.back()
    expect(g.capture_chance(boss) == 0, "boss cannot be captured")
    boss.mon.hp = 0
    g.defeat_enemy(boss)
    expect(1 in g.beaten and g.unlocked == 2 and not g.boss_active, "wild boss opens next region")
    var combat = fresh()
    e = combat.enemies[0]
    combat.player = e.pos
    combat.companion = e.pos + Vector2(-20,0)
    combat.command_attack(e.mon.uid)
    var initial_health = e.mon.hp
    for i in 120:
        combat.tick(1.0/60.0)
    expect(e.mon.hp < initial_health, "real-time skills/basic attacks cause damage")
    # All writes use an isolated user-data test directory, never player slots.
    var directory = "user://test-saves-%d" % Time.get_ticks_usec()
    g = fresh()
    var save_error = g.save_game(0, directory)
    if save_error != OK:
        print("Save error code: ", save_error)
    expect(save_error == OK, "atomic save writes successfully")
    var saved_ivs = g.party[0].ivs.duplicate()
    g.coins = 777
    expect(g.save_game(0, directory) == OK, "second save preserves last-good backup")
    restored = fresh()
    expect(restored.load_game(0, directory) and restored.coins == 777 and restored.party[0].ivs == saved_ivs, "disk roundtrip retains roll")
    var path = directory.path_join("slot_0.json")
    var corrupt = FileAccess.open(path, FileAccess.WRITE)
    corrupt.store_string("{broken")
    corrupt.close()
    expect(restored.load_game(0, directory) and restored.coins == 180, "corrupt current restores previous normal backup")
    for suffix in ["", ".bak", ".tmp"]:
        if FileAccess.file_exists(path + suffix):
            DirAccess.remove_absolute(path + suffix)
    DirAccess.remove_absolute(directory)
    print("MODEL CHECKS: %d passed / %d total" % [checks-failures, checks])
    quit(1 if failures else 0)
