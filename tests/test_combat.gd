extends SceneTree
const Game = preload("res://scripts/game.gd")
var checks = 0
var failures = 0

func expect(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FAIL: " + label)

func fixture():
    var game = Game.new()
    game.auto_save_enabled = false
    game.new_game(426)
    game.enemies.clear()
    game.player = Vector2(700, 600)
    game.companion = Vector2(720, 600)
    var enemy = game.spawn_enemy("m001", 5, Vector2(780, 600), false)
    game.command_attack(enemy.mon.uid)
    return game

func _initialize() -> void:
    var game = fixture()
    var enemy = game.enemies[0]
    var skill = game.catalog.skills[game.current().moves[0]]
    var health = enemy.mon.hp
    game.tick_companion_attack(enemy, .01)
    expect(enemy.mon.hp < health and not game.cast.is_empty(), "ally basic attack and windup start together")
    expect(game.current().cooldowns.get(skill.id, 0) == 0, "starting windup does not spend cooldown")
    game.basic_timer = 0
    health = enemy.mon.hp
    game.tick_companion_attack(enemy, .01)
    expect(enemy.mon.hp < health and not game.cast.is_empty(), "ally basic attack continues during windup")
    game.basic_timer = 10
    game.tick_companion_attack(enemy, 1)
    expect(game.cast.is_empty() and game.current().cooldowns.get(skill.id, 0) == skill.cooldown, "completed skill starts its cooldown")

    game = fixture()
    enemy = game.enemies[0]
    health = game.current().hp
    enemy.attack_timer = 0
    game.tick_enemy(enemy, .01)
    expect(game.current().hp < health and not enemy.cast.is_empty(), "enemy basic attack and windup start together")
    enemy.attack_timer = 0
    health = game.current().hp
    game.tick_enemy(enemy, .01)
    expect(game.current().hp < health and not enemy.cast.is_empty(), "enemy basic attack continues during windup")

    game = fixture()
    enemy = game.enemies[0]
    game.basic_timer = 10
    game.tick_companion_attack(enemy, .01)
    var initial_cast = game.cast.duplicate()
    game.command_attack(enemy.mon.uid)
    expect(game.cast == initial_cast, "reselecting same target preserves windup")
    var other = game.spawn_enemy("m004", 5, Vector2(775, 605), false)
    game.command_attack(other.mon.uid)
    expect(game.cast.is_empty(), "changing target cancels old windup")
    expect(game.current().cooldowns.is_empty(), "retarget cancellation spends no cooldown")

    game = fixture()
    enemy = game.enemies[0]
    skill = game.catalog.skills[enemy.mon.moves[0]]
    enemy.pos = game.companion + Vector2(float(skill.range) + 25, 0)
    enemy.cast = {"skill": skill.id, "time": .01}
    health = game.current().hp
    game.tick_enemy(enemy, .02)
    expect(enemy.cast.is_empty() and game.current().hp == health, "enemy short skill cancels outside its actual range")
    expect(enemy.mon.cooldowns.get(skill.id, 0) == 0, "enemy canceled skill spends no cooldown")
    var long_skill = game.catalog.skills["m001_s3_0"]
    enemy.pos = game.companion + Vector2(132, 0)
    enemy.cast = {"skill": long_skill.id, "time": .01}
    game.tick_enemy(enemy, .02)
    expect(game.current().hp < health and enemy.mon.cooldowns.get(long_skill.id, 0) > 0, "enemy long skill uses its own range plus shared grace")

    game = fixture()
    enemy = game.enemies[0]
    enemy.mon.hp = 1
    game.cast = {"skill": game.current().moves[0], "time": .01, "total": .3}
    game.tick_companion_attack(enemy, .02)
    expect(game.counters.battles == 1 and game.cast.is_empty(), "lethal basic attack grants rewards once and clears windup")
    expect(game.current().cooldowns.is_empty(), "lethal basic does not spend canceled skill cooldown")

    game = fixture()
    enemy = game.enemies[0]
    game.current().hp = 1
    enemy.attack_timer = 0
    enemy.cast = {"skill": enemy.mon.moves[0], "time": .01}
    var hits: Array = []
    var ally_uid: String = game.current().uid
    game.actor_action.connect(func(mon, action, _origin, _toward):
        if mon.uid == ally_uid and action == "faint":
            hits.append(action))
    game.tick_enemy(enemy, .02)
    expect(hits.size() == 1 and enemy.mon.cooldowns.is_empty(), "enemy does not cast again onto a just-fainted companion")

    game = fixture()
    enemy = game.enemies[0]
    expect(game.begin_capture(), "capture begins with a valid target")
    health = enemy.mon.hp
    var ally_health = game.current().hp
    game.tick(.1)
    expect(enemy.mon.hp == health and game.current().hp == ally_health, "capture still suppresses both participants after independent basics")
    game = fixture()
    expect(game.start_boss(), "first trainer challenge starts")
    for sid in ["m504", "m506", "m509"]:
        enemy = game.enemies.back()
        expect(enemy.boss and enemy.mon.species_id == sid and enemy.mon.level == 6, "authored first boss round: " + sid)
        expect(is_equal_approx(enemy.max_hp, game.max_hp(enemy.mon) * 1.15), "intro boss health scaling: " + sid)
        enemy.mon.hp = 0
        game.defeat_enemy(enemy)
    expect(not game.boss_active and 0 in game.beaten and game.unlocked == 1, "all three authored rounds unlock next region")
    expect(game.counters.bosses == 1, "trainer victory counted only once")
    game.region = 1
    expect(game.boss_lineup() == [game.catalog.regions[1].boss_species] and game.boss_hp_multiplier() == 2.2, "later wild boss keeps its existing defaults")
    print("COMBAT CHECKS: %d passed / %d total" % [checks - failures, checks])
    quit(1 if failures else 0)
