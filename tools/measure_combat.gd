extends SceneTree
## Reproducible stationary combat sample; not a human playthrough or balance approval.
const Game = preload("res://scripts/game.gd")
const STEP = 1.0 / 60.0

func _initialize() -> void:
    var reference = Game.new()
    reference.new_game(1)
    var starter: String = reference.current().species_id
    var encounters: Array = reference.catalog.regions[0].wild_species
    var report = {"scenario": "model-only, no terrain; stationary trainer; party/wild/first boss IVs=15, later boss IVs seeded; 20 seeds", "content_id": reference.catalog.content_id, "starter": starter, "wild": [], "boss": {}, "parties": {}}
    for sid in encounters:
        var samples: Array = []
        for seed_value in range(1, 21):
            var game = setup(seed_value, 5, [starter])
            var enemy = game.spawn_enemy(sid, 2 + seed_value % 4, game.companion + Vector2(60, 0), false)
            average_roll(game, enemy.mon)
            enemy.max_hp = enemy.mon.hp
            game.command_attack(enemy.mon.uid)
            samples.append(simulate(game, 60, false))
        report.wild.append({"species": sid, "summary": summarize(samples)})
    for profile in ["three_no_items", "three_with_potions", "six_no_items", "three_recall_potions"]:
        var bosses: Array = []
        for seed_value in range(1, 21):
            var members = [starter, encounters[0], encounters[1]]
            if profile == "six_no_items":
                members.append_array(encounters.slice(2, 5))
            report.parties[profile] = members
            var game = setup(seed_value, 6, members)
            game.player = Vector2(1560, 300)
            game.companion = Vector2(1560, 245)
            game.start_boss()
            average_roll(game, game.enemies.back().mon)
            game.enemies.back().mon.hp *= game.boss_hp_multiplier()
            game.enemies.back().max_hp = game.enemies.back().mon.hp
            bosses.append(simulate(game, 180, true, "potions" in profile, "recall" in profile))
        report.boss[profile] = summarize(bosses)
    var output = JSON.stringify(report, "  ")
    var args = OS.get_cmdline_user_args()
    if not args.is_empty():
        var file = FileAccess.open(args[0], FileAccess.WRITE)
        if file == null:
            push_error("Cannot write report: " + args[0])
            quit(1)
            return
        file.store_string(output + "\n")
        file.close()
    print(output)
    quit()

func average_roll(game, mon: Dictionary) -> void:
    mon.ivs = [15, 15, 15, 15, 15, 15]
    mon.hp = game.max_hp(mon)

func setup(seed_value: int, level: int, members: Array):
    var game = Game.new()
    game.auto_save_enabled = false
    game.new_game(seed_value)
    game.enemies.clear()
    game.party.clear()
    for sid in members:
        var mon = game.make_monster(sid, level, seed_value)
        average_roll(game, mon)
        game.party.append(mon)
    game.player = Vector2(700, 600)
    game.companion = Vector2(720, 600)
    return game

func simulate(game, limit: int, boss: bool, use_potions: bool = false, dodge: bool = false) -> Dictionary:
    var elapsed = 0.0
    var starting_potions: int = game.potions
    while elapsed < limit:
        if dodge:
            if not game.boss_telegraph.is_empty() and not game.recalling:
                game.recall()
            elif game.boss_telegraph.is_empty() and game.recalling:
                for enemy in game.enemies:
                    if enemy.boss and enemy.mon.hp > 0:
                        game.command_attack(enemy.mon.uid)
                        break
        if use_potions and game.current().hp < game.max_hp(game.current()) * .45:
            game.use_potion(game.active)
        game.tick(STEP)
        elapsed += STEP
        if (boss and 0 in game.beaten) or (not boss and game.counters.battles > 0):
            return {"result": "win", "seconds": elapsed, "potions": starting_potions - game.potions}
        if game.in_town():
            return {"result": "loss", "seconds": elapsed, "potions": starting_potions - game.potions}
    return {"result": "timeout", "seconds": elapsed, "potions": starting_potions - game.potions}

func summarize(samples: Array) -> Dictionary:
    var result = {"wins": 0, "losses": 0, "timeouts": 0, "mean_seconds": 0.0, "min_seconds": INF, "max_seconds": 0.0, "mean_potions": 0.0}
    for sample in samples:
        result[{"win": "wins", "loss": "losses", "timeout": "timeouts"}[sample.result]] += 1
        result.mean_seconds += sample.seconds / samples.size()
        result.mean_potions += float(sample.potions) / samples.size()
        result.min_seconds = minf(result.min_seconds, sample.seconds)
        result.max_seconds = maxf(result.max_seconds, sample.seconds)
    return result
