class_name TrailGame
extends RefCounted
## Deterministic game model. Rendering and input are deliberately independent.
signal notice(text: String)
signal effect(pos: Vector2, text: String, color: Color)
signal autosave_requested
signal actor_action(mon: Dictionary, action: String, origin: Vector2, toward: Vector2)
signal field_reset

const VERSION = 1
const STAT_NAMES = ["체력", "공격", "방어", "특공", "특방", "속도"]
const SLOT_COUNTS = {"D": 1, "C": 2, "B": 3, "A": 4, "S": 4}
const WORLD_SIZE = Vector2(2048, 1280)
var catalog: Dictionary
var species: Dictionary = {}
var rng = RandomNumberGenerator.new()
var party: Array = []
var storage: Array = []
var enemies: Array = []
var active: int = 0
var region: int = 0
var unlocked: int = 0
var beaten: Array = []
var seen: Array = []
var caught: Array = []
var coins: int = 180
var tools: int = 20
var potions: int = 5
var tool_grade: int = 1
var player = Vector2(224, 560)
var companion = Vector2(366, 586)
var target_id: String = ""
var recalling: bool = false
var switch_timer: float = 0
var basic_timer: float = 0
var cast: Dictionary = {}
var pending_capture: Dictionary = {}
var paused: bool = false
var ai_clock: float = 0
var play_time: float = 0
var counters = {"captures": 0, "battles": 0, "bosses": 0, "evolutions": 0}
var boss_round: int = 0
var boss_active: bool = false
var boss_telegraph: Dictionary = {}
var boss_clock: float = 0
var next_uid: int = 1
var save_slot: int = 0
var auto_save_enabled: bool = true
var collision_test: Callable
var find_step: Callable

func _init() -> void:
    catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
    for item in catalog.species:
        species[item.id] = item

func new_game(seed_value: int = 147207) -> void:
    rng.seed = seed_value
    party.clear()
    storage.clear()
    beaten.clear()
    seen.clear()
    caught.clear()
    next_uid = 1
    active = 0
    region = 0
    unlocked = 0
    coins = 180
    tools = 20
    potions = 5
    tool_grade = 1
    play_time = 0
    counters = {"captures": 0, "battles": 0, "bosses": 0, "evolutions": 0}
    party.append(make_monster("m001", 5))
    caught.append("m001")
    reset_field()

func spec(mon: Dictionary) -> Dictionary:
    return species[mon.species_id]

func make_monster(sid: String, level: int, fixed_seed: int = -1) -> Dictionary:
    var birth = RandomNumberGenerator.new()
    var roll = fixed_seed if fixed_seed >= 0 else rng.randi_range(1, 2000000000)
    birth.seed = roll
    var ivs: Array = []
    var branches: Array = []
    for i in 6:
        ivs.append(birth.randi_range(0, 31))
    for i in 4:
        branches.append(birth.randi_range(0, 1))
    var mon = {"uid": "u%08d" % next_uid, "species_id": sid, "level": clampi(level, 1, 50),
        "xp": 0, "birth_seed": roll, "ivs": ivs, "branches": branches,
        "moves": [], "enabled": [true, true, true, true], "order": [0, 1, 2, 3],
        "cooldowns": {}, "hp": 1.0, "shield": 0.0, "slow": 0.0}
    next_uid += 1
    assign_moves(mon)
    mon.hp = max_hp(mon)
    return mon

func assign_moves(mon: Dictionary) -> void:
    mon.moves = []
    for i in int(spec(mon).slots):
        mon.moves.append(spec(mon).skill_pools[i][int(mon.branches[i])])

func stats(mon: Dictionary) -> Array:
    var out: Array = []
    var base = spec(mon).base_stats
    for i in 6:
        var growth = 0.55 + float(mon.level) * 0.065
        var value = float(base[i]) * growth * (1.0 + float(mon.ivs[i]) / 310.0)
        out.append(int(round(value * (2.6 if i == 0 else 1.0))))
    return out

func max_hp(mon: Dictionary) -> float:
    return float(stats(mon)[0])

func appraisal(mon: Dictionary) -> int:
    var total = 0
    for iv in mon.ivs:
        total += int(iv)
    return int(round(total / 186.0 * 100.0))

func current() -> Dictionary:
    return party[active] if not party.is_empty() else {}

func reset_field() -> void:
    player = Vector2(224, 560)
    companion = player + Vector2(40, 24)
    target_id = ""
    cast = {}
    pending_capture = {}
    switch_timer = 0
    basic_timer = 0
    boss_active = false
    boss_telegraph = {}
    boss_clock = 0
    recalling = false
    enemies.clear()
    var candidates = region_species()
    # Minimal pixel prototype: first-field encounters use the newly authored Leafling.
    if region == 0:
        candidates = ["m001"]
    for i in 14:
        var sid = candidates[i % candidates.size()]
        var level = int(catalog.regions[region].level_min) + rng.randi_range(0, 3)
        var p = Vector2(660 + (i % 5) * 215, 520 + (i / 5) * 220)
        spawn_enemy(sid, level, p, false)
    field_reset.emit()

func region_species() -> Array:
    var result: Array = []
    for s in catalog.species:
        if int(s.region) == region:
            result.append(s.id)
    return result

func spawn_enemy(sid: String, level: int, p: Vector2, is_boss: bool) -> Dictionary:
    var mon = make_monster(sid, level)
    if is_boss:
        mon.hp = max_hp(mon) * (2.2 if catalog.regions[region].boss_kind == "wild" else 1.4)
    var enemy = {"mon": mon, "pos": p, "home": p, "boss": is_boss,
        "max_hp": mon.hp, "attack_timer": rng.randf_range(.4, 1.2), "cast": {},
        "alert": is_boss, "walk": Vector2.ZERO}
    enemies.append(enemy)
    if not sid in seen:
        seen.append(sid)
    return enemy

func enemy_by_id(uid: String) -> Dictionary:
    for enemy in enemies:
        if enemy.mon.uid == uid and enemy.mon.hp > 0:
            return enemy
    return {}

func command_attack(uid: String) -> void:
    if current().is_empty() or current().hp <= 0:
        return
    var enemy = enemy_by_id(uid)
    if not enemy.is_empty():
        target_id = uid
        recalling = false
        enemy.alert = true

func recall() -> void:
    recalling = true
    target_id = ""
    cast.clear()
    notice.emit("동료가 돌아옵니다.")

func switch_to(index: int, forced: bool = false) -> bool:
    if index < 0 or index >= party.size() or index == active or party[index].hp <= 0:
        return false
    if switch_timer > 0 and not forced:
        notice.emit("교체 준비 중 · %.1f초" % switch_timer)
        return false
    active = index
    cast = {}
    basic_timer = 0.5
    companion = player + Vector2(30, 20)
    switch_timer = 3.0
    notice.emit("%s, 함께 가자!" % spec(current()).name)
    return true

func move_player(direction: Vector2, dt: float) -> void:
    if paused:
        return
    var wanted = player + direction.limit_length() * 132 * dt
    player = move_clear(player, wanted)
    player = player.clamp(Vector2(48, 48), WORLD_SIZE - Vector2(48, 48))

func move_clear(origin: Vector2, destination: Vector2) -> Vector2:
    if not collision_test.is_valid():
        return destination
    if not collision_test.call(destination):
        return destination
    var x_only = Vector2(destination.x, origin.y)
    if not collision_test.call(x_only):
        return x_only
    var y_only = Vector2(origin.x, destination.y)
    if not collision_test.call(y_only):
        return y_only
    return origin

func approach(origin: Vector2, goal: Vector2, speed: float, dt: float) -> Vector2:
    var destination = goal
    if find_step.is_valid():
        destination = find_step.call(origin, goal)
    return move_clear(origin, origin.move_toward(destination, speed * dt))

func clear_attack_path(origin: Vector2, destination: Vector2) -> bool:
    if not collision_test.is_valid():
        return true
    var steps = maxi(1, int(ceil(origin.distance_to(destination) / 4.0)))
    for i in range(steps + 1):
        if collision_test.call(origin.lerp(destination, float(i) / steps)):
            return false
    return true

func tick(dt: float) -> void:
    if paused or party.is_empty():
        return
    play_time += dt
    switch_timer = maxf(0, switch_timer - dt)
    basic_timer = maxf(0, basic_timer - dt)
    for mon in party:
        tick_mon(mon, dt)
    if not pending_capture.is_empty():
        pending_capture.time -= dt
        if pending_capture.time <= 0:
            finish_capture()
    if current().hp <= 0:
        handle_faint()
        if current().hp <= 0:
            return
    var target = enemy_by_id(target_id)
    if target.is_empty():
        target_id = ""
        cast.clear()
        companion = approach(companion, player + Vector2(32, 22), 115, dt)
    else:
        var distance = companion.distance_to(target.pos)
        if (distance > 68 or not clear_attack_path(companion, target.pos)) and cast.is_empty():
            companion = approach(companion, target.pos, 120 * (0.65 if current().slow > 0 else 1.0), dt)
        if pending_capture.is_empty():
            tick_companion_attack(target, dt)
    if companion.distance_to(player) > 410 and not boss_active:
        companion = player + Vector2(26, 20)
        target_id = ""
        cast.clear()
    ai_clock -= dt
    if ai_clock <= 0:
        ai_clock = .1
        update_ai()
    for enemy in enemies:
        if (boss_active and not enemy.boss) or enemy.mon.hp <= 0 or enemy.pos.distance_to(player) > 560:
            continue
        tick_mon(enemy.mon, dt)
        if enemy.alert:
            tick_enemy(enemy, dt)
        else:
            enemy.pos = move_clear(enemy.pos, enemy.pos + enemy.walk * dt)
    if boss_active:
        tick_boss(dt)
    if current().hp <= 0:
        handle_faint()

func tick_mon(mon: Dictionary, dt: float) -> void:
    for key in mon.cooldowns.keys():
        mon.cooldowns[key] = maxf(0, float(mon.cooldowns[key]) - dt)
    mon.slow = maxf(0, float(mon.slow) - dt)

func update_ai() -> void:
    for enemy in enemies:
        if (boss_active and not enemy.boss) or enemy.mon.hp <= 0 or enemy.pos.distance_to(player) > 500:
            continue
        if enemy.alert and not recalling and target_id.is_empty() and pending_capture.is_empty():
            command_attack(enemy.mon.uid)
        if not enemy.alert:
            if rng.randf() < .08:
                var goal = enemy.home + Vector2(rng.randf_range(-55, 55), rng.randf_range(-55, 55))
                enemy.walk = enemy.pos.direction_to(goal) * 12
            if enemy.pos.distance_to(enemy.home) > 75:
                enemy.walk = enemy.pos.direction_to(enemy.home) * 14
        if enemy.alert and not enemy.boss and enemy.pos.distance_to(enemy.home) > 300:
            enemy.alert = false
            enemy.pos = enemy.home
            enemy.mon.hp = enemy.max_hp
            enemy.cast = {}
            if target_id == enemy.mon.uid:
                recall()

func tick_companion_attack(target: Dictionary, dt: float) -> void:
    var mon = current()
    if not clear_attack_path(companion, target.pos):
        cast.clear()
        return
    if not cast.is_empty():
        var skill = catalog.skills[cast.skill]
        if companion.distance_to(target.pos) > float(skill.range) + 18:
            cast.clear()
            return
        cast.time -= dt
        if cast.time <= 0:
            apply_skill(mon, target.mon, skill, target.pos)
            mon.cooldowns[skill.id] = skill.cooldown
            cast.clear()
            if target.mon.hp <= 0:
                defeat_enemy(target)
        return
    for slot in mon.order:
        var i = int(slot)
        if i >= mon.moves.size() or not mon.enabled[i]:
            continue
        var skill = catalog.skills[mon.moves[i]]
        if float(mon.cooldowns.get(skill.id, 0)) > 0 or companion.distance_to(target.pos) > float(skill.range):
            continue
        if skill.effect == "heal" and mon.hp > max_hp(mon) * .8:
            continue
        if skill.effect == "shield" and mon.shield > 0:
            continue
        cast = {"skill": skill.id, "time": skill.windup, "total": skill.windup}
        return
    if basic_timer <= 0 and companion.distance_to(target.pos) <= 78:
        var damage = damage_for(mon, target.mon, 9, false)
        actor_action.emit(mon, "attack", companion, target.pos)
        hurt(target.mon, damage, target.pos)
        basic_timer = 1.15
        if target.mon.hp <= 0:
            defeat_enemy(target)

func damage_for(attacker: Dictionary, defender: Dictionary, power: float, special: bool) -> int:
    var attack_stats = stats(attacker)
    var defend_stats = stats(defender)
    var a = float(attack_stats[3 if special else 1])
    var d = float(defend_stats[4 if special else 2])
    var bonus = element_multiplier(spec(attacker).element, spec(defender).element)
    return maxi(1, int(round(power * a / maxf(10, d) * bonus)))

func element_multiplier(a: String, d: String) -> float:
    var strengths = {"nature": "water", "water": "flame", "flame": "nature", "stone": "wind",
        "wind": "shade", "shade": "star", "star": "metal", "metal": "frost", "frost": "stone"}
    if strengths.get(a) == d:
        return 1.35
    if strengths.get(d) == a:
        return .8
    return 1.0

func apply_skill(attacker: Dictionary, defender: Dictionary, skill: Dictionary, p: Vector2) -> void:
    var origin = companion
    for enemy in enemies:
        if enemy.mon.uid == attacker.uid:
            origin = enemy.pos
            break
    actor_action.emit(attacker, "attack", origin, p)
    match skill.effect:
        "heal":
            var amount = float(skill.power) * 1.8
            attacker.hp = minf(max_hp(attacker), attacker.hp + amount)
            effect.emit(companion, "+%d" % amount, Color("a9dc8f"))
        "shield":
            attacker.shield = float(skill.power) * 1.5
            effect.emit(companion, "보호", Color("c9dbe4"))
        _:
            hurt(defender, damage_for(attacker, defender, float(skill.power), true), p)
            if skill.effect == "slow":
                defender.slow = 3.0
    effect.emit(p + Vector2(0, -24), skill.name, Color(skill.color))

func hurt(mon: Dictionary, amount: float, p: Vector2) -> void:
    var absorbed = minf(float(mon.shield), amount)
    mon.shield -= absorbed
    mon.hp = maxf(0, mon.hp - (amount - absorbed))
    if amount > absorbed:
        actor_action.emit(mon, "faint" if mon.hp <= 0 else "hit", p, p)
    effect.emit(p - Vector2(0, 34), "%d" % (amount - absorbed), Color("705040"))

func tick_enemy(enemy: Dictionary, dt: float) -> void:
    if not pending_capture.is_empty() and pending_capture.uid == enemy.mon.uid:
        return
    var dist = enemy.pos.distance_to(companion)
    var path_clear = clear_attack_path(enemy.pos, companion)
    if dist > 65 or not path_clear:
        enemy.pos = approach(enemy.pos, companion, (70 if enemy.boss else 62) * (.65 if enemy.mon.slow > 0 else 1.0), dt)
    dist = enemy.pos.distance_to(companion)
    enemy.attack_timer -= dt
    if not clear_attack_path(enemy.pos, companion):
        enemy.cast = {}
        return
    if not enemy.cast.is_empty():
        enemy.cast.time -= dt
        if dist > 125:
            enemy.cast = {}
        elif enemy.cast.time <= 0:
            var skill = catalog.skills[enemy.cast.skill]
            apply_skill(enemy.mon, current(), skill, companion)
            enemy.mon.cooldowns[skill.id] = skill.cooldown
            enemy.cast = {}
        return
    for mid in enemy.mon.moves:
        var skill = catalog.skills[mid]
        if enemy.mon.cooldowns.get(mid, 0) <= 0 and dist <= float(skill.range) and skill.effect in ["damage", "slow"]:
            enemy.cast = {"skill": mid, "time": float(skill.windup) + .35}
            return
    if dist <= 80 and enemy.attack_timer <= 0:
        actor_action.emit(enemy.mon, "attack", enemy.pos, companion)
        hurt(current(), damage_for(enemy.mon, current(), 7 if not enemy.boss else 10, false), companion)
        enemy.attack_timer = 1.5

func defeat_enemy(enemy: Dictionary) -> void:
    target_id = ""
    cast.clear()
    counters.battles += 1
    coins += 8 + int(enemy.mon.level) * 2
    award_xp(15 + int(enemy.mon.level) * 7)
    if enemy.boss:
        boss_round += 1
        if catalog.regions[region].boss_kind == "trainer" and boss_round < 3:
            var pool = region_species()
            var sid = pool[(boss_round * 5) % pool.size()]
            spawn_enemy(sid, int(catalog.regions[region].boss_level), Vector2(1600, 245), true)
            notice.emit("보스의 다음 동료가 출전합니다 · %d/3" % (boss_round + 1))
        else:
            boss_active = false
            boss_telegraph = {}
            if not region in beaten:
                beaten.append(region)
                counters.bosses += 1
            unlocked = mini(8, maxi(unlocked, region + 1))
            coins += 100 + region * 35
            tools += 5
            notice.emit("%s 격파! 새로운 길이 열렸습니다." % catalog.regions[region].boss_name)
            request_autosave()

func award_xp(amount: int) -> void:
    for index in party.size():
        var mon = party[index]
        if mon.hp <= 0:
            continue
        mon.xp += int(amount * (1.0 if index == active else .7))
        while mon.level < 50 and mon.xp >= xp_needed(mon):
            mon.xp -= xp_needed(mon)
            mon.level += 1
            mon.hp = minf(max_hp(mon), mon.hp + 18)
            maybe_evolve(mon)
            notice.emit("%s · 레벨 %d" % [spec(mon).name, mon.level])

func xp_needed(mon: Dictionary) -> int:
    return 35 + int(mon.level) * 18

func maybe_evolve(mon: Dictionary) -> bool:
    var definition = spec(mon)
    if definition.evolves_to == "" or mon.level < definition.evolution_level:
        return false
    var old_name = definition.name
    var old_max = max_hp(mon)
    var cooldowns_by_slot: Array = []
    for mid in mon.moves:
        cooldowns_by_slot.append(mon.cooldowns.get(mid, 0))
    mon.species_id = definition.evolves_to
    assign_moves(mon)
    mon.cooldowns = {}
    for i in cooldowns_by_slot.size():
        mon.cooldowns[mon.moves[i]] = cooldowns_by_slot[i]
    mon.hp = max_hp(mon) * mon.hp / old_max
    if not mon.species_id in caught:
        caught.append(mon.species_id)
    counters.evolutions += 1
    notice.emit("%s → %s · 진화!" % [old_name, spec(mon).name])
    return true

func capture_chance(enemy: Dictionary) -> float:
    if enemy.is_empty() or enemy.boss or enemy.mon.hp <= 0:
        return 0
    var health_factor = 1.0 - float(enemy.mon.hp) / float(enemy.max_hp)
    return clampf(float(spec(enemy.mon).catch_rate) * (.2 + .8 * health_factor) * (1.0 + .35 * (tool_grade - 1)), .05, .95)

func begin_capture() -> bool:
    if paused or not pending_capture.is_empty():
        return false
    var enemy = enemy_by_id(target_id)
    if enemy.is_empty() or enemy.boss:
        notice.emit("살아 있는 야생 몬스터를 먼저 지정하세요.")
        return false
    if player.distance_to(enemy.pos) > 220:
        notice.emit("포획하려면 조금 더 가까이 다가가세요.")
        return false
    if not clear_attack_path(player, enemy.pos):
        notice.emit("사이에 장애물이 있습니다. 돌아서 가까이 다가가세요.")
        return false
    if tools <= 0:
        notice.emit("포획 도구가 없습니다. 마을 상점을 찾아가세요.")
        return false
    tools -= 1
    cast.clear()
    pending_capture = {"uid": enemy.mon.uid, "chance": capture_chance(enemy), "time": 1.2}
    effect.emit(enemy.pos, "인연 맺는 중…", Color("f5d884"))
    return true

func finish_capture() -> bool:
    if pending_capture.is_empty():
        return false
    var request = pending_capture.duplicate()
    pending_capture.clear()
    var enemy = enemy_by_id(request.uid)
    if enemy.is_empty():
        notice.emit("대상이 사라져 포획하지 못했습니다.")
        return false
    if rng.randf() > float(request.chance):
        enemy.alert = true
        notice.emit("아쉽게 빠져나왔습니다. 더 약화시키면 확률이 올라갑니다.")
        return false
    var mon = enemy.mon.duplicate(true)
    mon.hp = max_hp(mon)
    mon.shield = 0
    mon.slow = 0
    if party.size() < 6:
        party.append(mon)
    else:
        storage.append(mon)
    enemies.erase(enemy)
    target_id = ""
    if not mon.species_id in caught:
        caught.append(mon.species_id)
    counters.captures += 1
    notice.emit("%s와 인연을 맺었습니다!%s" % [spec(mon).name, " 보관함으로 이동했습니다." if party.size() == 6 and storage.has(mon) else ""])
    request_autosave()
    return true

func handle_faint() -> void:
    cast.clear()
    target_id = ""
    for i in party.size():
        if party[i].hp > 0:
            switch_to(i, true)
            return
    coins = int(coins * .95)
    heal_all()
    active = 0
    reset_field()
    notice.emit("모두 지쳤습니다. 마을에서 회복했습니다 · 소지금 5% 사용")
    request_autosave()

func heal_all() -> void:
    for mon in party:
        mon.hp = max_hp(mon)
        mon.cooldowns.clear()
        mon.shield = 0
        mon.slow = 0

func use_potion(index: int) -> bool:
    if index < 0 or index >= party.size() or potions <= 0:
        return false
    var mon = party[index]
    if mon.hp <= 0 or mon.hp >= max_hp(mon):
        return false
    potions -= 1
    mon.hp = minf(max_hp(mon), mon.hp + max_hp(mon) * .45)
    notice.emit("%s의 체력을 회복했습니다." % spec(mon).name)
    return true

func in_town() -> bool:
    return player.x < 560 and not boss_active

func travel(destination: int) -> bool:
    if destination < 0 or destination > unlocked or not in_town():
        return false
    region = destination
    heal_all()
    reset_field()
    notice.emit("%s에 도착했습니다." % catalog.regions[region].town)
    request_autosave()
    return true

func start_boss() -> bool:
    if boss_active:
        return false
    if region in beaten and not 8 in beaten:
        notice.emit("이미 길을 열었습니다. 다음 지역을 탐험하세요.")
        return false
    boss_active = true
    boss_round = 0
    boss_clock = 3.0
    target_id = ""
    var sid = catalog.regions[region].boss_species
    if region == 0:
        sid = "m013"
    var enemy = spawn_enemy(sid, int(catalog.regions[region].boss_level), Vector2(1600, 245), true)
    command_attack(enemy.mon.uid)
    notice.emit("%s · 도전 시작" % catalog.regions[region].boss_name)
    return true

func tick_boss(dt: float) -> void:
    boss_clock -= dt
    if not boss_telegraph.is_empty():
        boss_telegraph.time -= dt
        if boss_telegraph.time <= 0:
            if companion.distance_to(boss_telegraph.pos) < boss_telegraph.radius:
                hurt(current(), 22 + region * 5, companion)
            effect.emit(boss_telegraph.pos, "지면 파동", Color("efb978"))
            boss_telegraph.clear()
    elif boss_clock <= 0:
        boss_clock = 6.0
        boss_telegraph = {"pos": companion, "radius": 64.0, "time": 1.6}

func trade_storage(stored_index: int, party_index: int) -> bool:
    if not in_town() or stored_index < 0 or stored_index >= storage.size():
        return false
    if party.size() < 6:
        party.append(storage.pop_at(stored_index))
    elif party_index >= 0 and party_index < party.size():
        var old = party[party_index]
        party[party_index] = storage[stored_index]
        storage[stored_index] = old
    else:
        return false
    cast.clear()
    target_id = ""
    request_autosave()
    return true

func buy(kind: String) -> bool:
    var price = 15 if kind == "tool" else 25
    if not in_town() or coins < price:
        return false
    coins -= price
    if kind == "tool":
        tools += 1
    else:
        potions += 1
    request_autosave()
    return true

func request_autosave() -> void:
    if auto_save_enabled:
        autosave_requested.emit()

func snapshot() -> Dictionary:
    return {"version": VERSION, "party": party.duplicate(true), "storage": storage.duplicate(true),
        "active": active, "region": region, "unlocked": unlocked, "beaten": beaten.duplicate(),
        "seen": seen.duplicate(), "caught": caught.duplicate(), "coins": coins, "tools": tools,
        "potions": potions, "tool_grade": tool_grade, "play_time": play_time,
        "counters": counters.duplicate(), "next_uid": next_uid, "rng_state": str(rng.state)}

func validate_snapshot(data: Variant) -> bool:
    if not data is Dictionary or data.get("version", -1) != VERSION:
        return false
    for key in ["party", "storage", "beaten", "seen", "caught"]:
        if not data.get(key) is Array:
            return false
    if data.party.is_empty() or data.party.size() > 6 or data.storage.size() > 20000:
        return false
    if int(data.get("active", -1)) < 0 or int(data.active) >= data.party.size():
        return false
    if int(data.get("region", -1)) < 0 or int(data.region) > 8 or int(data.get("unlocked", -1)) < int(data.region) or int(data.unlocked) > 8:
        return false
    for key in ["coins", "tools", "potions", "play_time", "next_uid"]:
        if not data.has(key) or not (data[key] is float or data[key] is int) or float(data[key]) < 0:
            return false
    if not data.get("counters") is Dictionary or not data.get("rng_state") is String:
        return false
    for key in ["captures", "battles", "bosses", "evolutions"]:
        if not data.counters.has(key):
            return false
    var ids: Dictionary = {}
    for mon in data.party + data.storage:
        if not mon is Dictionary or not species.has(mon.get("species_id", "")):
            return false
        if not mon.get("uid") is String or ids.has(mon.uid):
            return false
        ids[mon.uid] = true
        for key in ["ivs", "branches", "moves", "enabled", "order"]:
            if not mon.get(key) is Array:
                return false
        if mon.ivs.size() != 6 or mon.branches.size() != 4 or mon.enabled.size() != 4 or mon.order.size() != 4:
            return false
        for iv in mon.ivs:
            if not (iv is float or iv is int) or iv < 0 or iv > 31:
                return false
        for branch in mon.branches:
            if branch != 0 and branch != 1:
                return false
        var order = mon.order.duplicate()
        order.sort()
        # JSON stores numbers as floats; array equality is type-sensitive.
        for i in 4:
            if not (order[i] is int or order[i] is float) or order[i] != i:
                return false
        if int(mon.get("level", 0)) < 1 or int(mon.level) > 50 or not mon.get("cooldowns") is Dictionary:
            return false
        for key in ["hp", "xp", "shield", "slow", "birth_seed"]:
            if not mon.has(key) or not (mon[key] is float or mon[key] is int) or not is_finite(float(mon[key])) or mon[key] < 0:
                return false
        if mon.moves.size() != int(species[mon.species_id].slots):
            return false
        for i in mon.moves.size():
            if mon.moves[i] != species[mon.species_id].skill_pools[i][int(mon.branches[i])]:
                return false
    for sid in data.caught + data.seen:
        if not species.has(sid):
            return false
    for b in data.beaten:
        if not (b is int or b is float) or b < 0 or b > 8:
            return false
    return true

func restore(data: Dictionary) -> bool:
    if not validate_snapshot(data):
        return false
    party = data.party.duplicate(true)
    storage = data.storage.duplicate(true)
    for mon in party + storage:
        for key in ["level", "xp", "birth_seed"]:
            mon[key] = int(mon[key])
        for key in ["ivs", "branches", "order"]:
            for i in mon[key].size():
                mon[key][i] = int(mon[key][i])
    active = int(data.active)
    region = int(data.region)
    unlocked = int(data.unlocked)
    beaten = data.beaten.duplicate()
    for i in beaten.size():
        beaten[i] = int(beaten[i])
    seen = data.seen.duplicate()
    caught = data.caught.duplicate()
    coins = int(data.coins)
    tools = int(data.tools)
    potions = int(data.potions)
    tool_grade = clampi(int(data.get("tool_grade", 1)), 1, 3)
    play_time = float(data.play_time)
    counters = data.counters.duplicate()
    next_uid = int(data.next_uid)
    rng.state = data.rng_state.to_int()
    heal_all()
    reset_field()
    return true

func save_game(slot: int = -1, directory: String = "user://saves") -> Error:
    if slot < 0:
        slot = save_slot
    if slot < 0 or slot > 2:
        return ERR_INVALID_PARAMETER
    DirAccess.make_dir_recursive_absolute(directory)
    var path = directory.path_join("slot_%d.json" % slot)
    var temporary = path + ".tmp"
    var file = FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(snapshot()))
    file.flush()
    var write_error = file.get_error()
    file.close()
    if write_error != OK:
        return write_error
    if not validate_snapshot(JSON.parse_string(FileAccess.get_file_as_string(temporary))):
        return ERR_FILE_CORRUPT
    if FileAccess.file_exists(path) and validate_snapshot(JSON.parse_string(FileAccess.get_file_as_string(path))):
        var backup_error = DirAccess.copy_absolute(path, path + ".bak")
        if backup_error != OK:
            return backup_error
    return DirAccess.rename_absolute(temporary, path)

func load_game(slot: int = 0, directory: String = "user://saves") -> bool:
    if slot < 0 or slot > 2:
        return false
    var path = directory.path_join("slot_%d.json" % slot)
    for candidate in [path, path + ".bak"]:
        if not FileAccess.file_exists(candidate):
            continue
        var parser = JSON.new()
        if parser.parse(FileAccess.get_file_as_string(candidate)) != OK:
            continue
        var data = parser.data
        if validate_snapshot(data) and restore(data):
            save_slot = slot
            if candidate.ends_with(".bak"):
                notice.emit("최근 정상 백업으로 저장을 복원했습니다.")
            return true
    return false
