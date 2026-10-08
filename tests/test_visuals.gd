extends SceneTree
## Verify event/pose wiring and cleanup; this is not an art-quality score.
var checks = 0
var failures = 0

func expect(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(description)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game = TrailGame.new()
    game.new_game(426)
    game.auto_save_enabled = false
    var field = load("res://scripts/field.gd").new()
    root.add_child(field)
    field.setup(game)
    var enemy = game.enemies[0]
    game.companion = Vector2(680, 550)
    enemy.pos = Vector2(730, 550)
    game.player = Vector2(660, 580)
    game.command_attack(enemy.mon.uid)
    game.current().enabled = [false, false, false, false]
    game.tick_companion_attack(enemy, .01)
    expect(field.pose_for(game.current()).state == "attack", "actual basic attack starts contact/recovery pose")
    expect(field.pose_for(enemy.mon, enemy).state == "hit", "actual damage starts target recoil")
    expect(field.pose_for(game.current()).facing == 1, "attack faces target even while stationary")
    field.advance(.4, Vector2.ZERO)
    expect(field.pose_for(game.current()).state == "walk" and field.impacts.is_empty(), "one-shot effects expire")
    game.cast = {"skill": game.current().moves[0], "time": .3, "total": .3}
    expect(field.pose_for(game.current()).state == "cast", "windup uses separate anticipation pose")
    game.recall()
    expect(field.pose_for(game.current()).state == "walk", "recall cancels cast pose immediately")
    enemy.mon.shield = 100
    game.hurt(enemy.mon, 1, enemy.pos)
    expect(not field.actor_states.has(enemy.mon.uid), "fully absorbed hit does not show bodily recoil")
    enemy.mon.shield = 0
    game.hurt(enemy.mon, enemy.mon.hp + 1, enemy.pos)
    expect(field.fainting.size() == 1 and field.pose_for(enemy.mon, enemy).state == "faint", "lethal damage preserves a brief faint pose")
    field.advance(.7, Vector2.ZERO)
    expect(field.fainting.is_empty() and not field.actor_states.has(enemy.mon.uid), "fainted visual cleans up without respawning enemy")
    game.hurt(game.current(), 1, game.companion)
    game.party.append(game.make_monster("m001", 5))
    game.switch_to(1, true)
    expect(field.pose_for(game.current()).state == "walk", "switch does not transfer old companion recoil")
    game.reset_field()
    expect(field.actor_states.is_empty() and field.effects.is_empty() and field.fainting.is_empty(), "field reset clears transient visuals")
    field.advance(.1, Vector2.RIGHT)
    expect(not field.walking, "blocked trainer cannot walk in place from key input alone")
    expect(field.sfx.sounds.size() == 3 and field.sfx.sounds.hit.get_length() > .08, "three local synthesized cues are available")
    field.sfx.toggle()
    field.sfx.cue("hit")
    expect(not field.sfx.enabled and not field.sfx.voices[0].playing, "sound toggle stops and suppresses cues")
    field.queue_free()
    await process_frame
    print("VISUAL WIRING CHECKS: %d passed / %d total (not an aesthetic assessment)" % [checks - failures, checks])
    quit(1 if failures else 0)
