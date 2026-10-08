extends Node2D
## Legacy renderer retained after art deletion. Read DESIGN_AGENT.md before visual work.
## Its old dimensions are implementation history, not the new art specification.
const SIZE = Vector2(320, 288)
const ARENA = Rect2(1408, 96, 448, 320)
const OBSTACLES = [Rect2(160, 384, 128, 112), Rect2(352, 384, 128, 112),
    Rect2(832, 288, 224, 128), Rect2(1120, 800, 160, 192), Rect2(448, 800, 96, 128)]
const SCENERY_TREES = [Vector2(112, 416), Vector2(144, 416), Vector2(112, 448), Vector2(144, 448), Vector2(112, 480), Vector2(144, 480), Vector2(496, 448), Vector2(528, 448), Vector2(496, 480), Vector2(528, 480), Vector2(144, 672), Vector2(240, 704), Vector2(400, 704), Vector2(560, 736), Vector2(736, 448), Vector2(1056, 480)]
var game: TrailGame
var camera = Vector2.ZERO
var navigation = AStarGrid2D.new()
var explorer = preload("res://assets/pixel/trainer.png")
var leafling = preload("res://assets/pixel/leafling.png")
var leafling_battle = preload("res://assets/pixel/leafling_battle.png")
var path_edges = preload("res://assets/pixel/path_edges.png")
var garden = preload("res://assets/pixel/garden.png")
var signpost = preload("res://assets/pixel/sign.png")
var meadow = preload("res://assets/pixel/meadow.png")
var pebbles = preload("res://assets/pixel/pebbles.png")
var terrain = preload("res://assets/pixel/terrain.png")
var cottage = preload("res://assets/pixel/cottage.png")
var tree = preload("res://assets/pixel/tree.png")
var bush = preload("res://assets/pixel/bush.png")
var fence = preload("res://assets/pixel/fence.png")
var flower = preload("res://assets/pixel/flower.png")
var font = preload("res://assets/fonts/Galmuri11.ttf")
var actor_motion: Dictionary = {}
var effects: Array = []
var facing: int = 0
var walking: bool = false
var animation_time: float = 0
var actor_states: Dictionary = {}
var fainting: Array = []
var impacts: Array = []
var last_player = Vector2.ZERO
var sfx = preload("res://scripts/sfx.gd").new()

func setup(model: TrailGame) -> void:
    game = model
    add_child(sfx)
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
    font.hinting = TextServer.HINTING_NONE
    font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
    navigation.region = Rect2i(0, 0, 128, 80)
    navigation.cell_size = Vector2(16, 16)
    navigation.offset = Vector2(8, 8)
    navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    navigation.update()
    for y in 80:
        for x in 128:
            navigation.set_point_solid(Vector2i(x, y), terrain_blocked(Vector2(x * 16 + 8, y * 16 + 8)))
    game.collision_test = blocked
    game.find_step = next_step
    game.effect.connect(func(p, message, color): effects.append({"pos": p, "text": message, "color": color, "life": 1.1}))
    game.actor_action.connect(on_actor_action)
    game.field_reset.connect(clear_animation)
    last_player = game.player
    update_camera()

func clear_animation() -> void:
    actor_states.clear()
    actor_motion.clear()
    fainting.clear()
    impacts.clear()
    effects.clear()
    sfx.silence()
    last_player = game.player

func direction_index(direction: Vector2) -> int:
    return (1 if direction.x > 0 else 3) if absf(direction.x) > absf(direction.y) else (0 if direction.y >= 0 else 2)

func on_actor_action(mon: Dictionary, action: String, origin: Vector2, toward: Vector2) -> void:
    if Rect2(camera, SIZE).has_point(origin):
        sfx.cue(action)
    var direction = actor_motion.get(mon.uid, {"facing": 0}).facing
    if origin.distance_to(toward) > 1:
        direction = direction_index(toward - origin)
    var duration = .64 if action == "faint" else .28 if action == "hit" else .32
    actor_states[mon.uid] = {"action": action, "life": duration, "duration": duration, "facing": direction}
    if action == "faint":
        fainting.append({"mon": mon.duplicate(true), "pos": origin, "ghost": true, "life": duration})
    elif action == "hit":
        impacts.append({"pos": origin - Vector2(0, 17), "life": .18})

func pose_for(mon: Dictionary, enemy: Dictionary = {}) -> Dictionary:
    var motion = actor_motion.get(mon.uid, {"facing": 0, "moving": false})
    if actor_states.has(mon.uid):
        var state = actor_states[mon.uid]
        var frame = clampi(int((1.0 - state.life / state.duration) * 4), 0, 3)
        # Instant basic damage shows the contact pose immediately, then recovery.
        if state.action == "attack":
            frame = [2, 2, 3, 0][frame]
        return {"state": state.action, "facing": state.facing, "frame": frame}
    var casting = game.cast if mon.uid == game.current().uid else enemy.get("cast", {})
    if not casting.is_empty():
        var toward = game.enemy_by_id(game.target_id).get("pos", game.companion) if enemy.is_empty() else game.companion
        var origin = game.companion if enemy.is_empty() else enemy.pos
        return {"state": "cast", "facing": direction_index(toward - origin), "frame": int(animation_time * 10) % 4}
    return {"state": "walk", "facing": motion.facing, "frame": int(animation_time * 8) % 4 if motion.moving else 0}

func terrain_blocked(p: Vector2) -> bool:
    if p.x < 48 or p.y < 48 or p.x > 2000 or p.y > 1232:
        return true
    for obstacle in OBSTACLES:
        if obstacle.grow(12).has_point(p):
            return true
    for trunk in SCENERY_TREES:
        if Rect2(trunk - Vector2(12, 6), Vector2(24, 16)).has_point(p):
            return true
    if Rect2(128, 650, 152, 22).has_point(p) or Rect2(360, 650, 152, 22).has_point(p):
        return true
    return false

func blocked(p: Vector2) -> bool:
    return terrain_blocked(p) or (game.boss_active and not ARENA.grow(-16).has_point(p))

func next_step(origin: Vector2, goal: Vector2) -> Vector2:
    if game.boss_active:
        return goal.clamp(ARENA.position + Vector2(20, 20), ARENA.end - Vector2(20, 20))
    # Most paths are short and clear. Search only when the direct segment is blocked.
    var distance = origin.distance_to(goal)
    var clear = true
    for i in range(1, int(distance / 8) + 2):
        if blocked(origin.lerp(goal, minf(1, i * 8.0 / maxf(distance, 1)))):
            clear = false
            break
    if clear:
        return goal
    var start = Vector2i(origin / 16)
    var end = Vector2i(goal / 16).clamp(Vector2i(3, 3), Vector2i(124, 76))
    if navigation.is_point_solid(start):
        return origin
    if navigation.is_point_solid(end):
        var nearest = end
        var best = INF
        for y in range(-4, 5):
            for x in range(-4, 5):
                var cell = end + Vector2i(x, y)
                if navigation.is_in_boundsv(cell) and not navigation.is_point_solid(cell):
                    var d = (Vector2(cell) * 16 + Vector2(8, 8)).distance_squared_to(goal)
                    if d < best:
                        best = d
                        nearest = cell
        end = nearest
    if navigation.is_point_solid(end):
        return origin
    var path = navigation.get_point_path(start, end)
    return path[1] if path.size() > 1 else origin

func update_camera() -> void:
    camera = (game.player - Vector2(160, 208)).clamp(Vector2.ZERO, TrailGame.WORLD_SIZE - SIZE).floor()

func advance(dt: float, direction: Vector2) -> void:
    walking = game.player.distance_to(last_player) > .1
    last_player = game.player
    if walking:
        if absf(direction.x) > absf(direction.y):
            facing = 1 if direction.x > 0 else 3
        else:
            facing = 0 if direction.y > 0 else 2
    var actors = [{"id": game.current().uid, "pos": game.companion}]
    for enemy in game.enemies:
        actors.append({"id": enemy.mon.uid, "pos": enemy.pos})
    var live_ids = {}
    for actor in actors:
        live_ids[actor.id] = true
        var last = actor_motion.get(actor.id, {"pos": actor.pos, "facing": 0, "moving": false})
        var movement: Vector2 = actor.pos - last.pos
        if movement.length() > .1:
            last.facing = (1 if movement.x > 0 else 3) if absf(movement.x) > absf(movement.y) else (0 if movement.y > 0 else 2)
        last.moving = movement.length() > .1
        last.pos = actor.pos
        actor_motion[actor.id] = last
    for id in actor_motion.keys():
        if not live_ids.has(id):
            actor_motion.erase(id)
    animation_time += dt
    for id in actor_states.keys():
        actor_states[id].life -= dt
        if actor_states[id].life <= 0:
            actor_states.erase(id)
    for ghost in fainting:
        ghost.life -= dt
    fainting = fainting.filter(func(item): return item.life > 0)
    for impact in impacts:
        impact.life -= dt
    impacts = impacts.filter(func(item): return item.life > 0)
    for item in effects:
        item.life -= dt
        item.pos.y -= 18 * dt
    effects = effects.filter(func(item): return item.life > 0)
    update_camera()
    queue_redraw()

func world_from_screen(p: Vector2) -> Vector2:
    return p + camera

func label_at(p: Vector2, text: String, color = Color("fff0c2"), size: int = 12) -> void:
    draw_string(font, p - camera + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("f8f8e8"))
    draw_string(font, p - camera, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
    if game == null:
        return
    var start = Vector2i(camera / 32)
    for y in range(start.y, start.y + 11):
        for x in range(start.x, start.x + 12):
            var p = Vector2(x * 32, y * 32)
            var variant = posmod(x * 7 + y * 13, 9)
            variant = variant if variant < 3 else 0
            draw_texture_rect_region(terrain, Rect2(p - camera, Vector2(32, 32)), Rect2(variant * 32, 0, 32, 32))
            if is_path(x, y):
                draw_texture_rect_region(terrain, Rect2(p - camera, Vector2(32, 32)), Rect2((3 + posmod(x + y, 2)) * 32, 0, 32, 32))
                var neighbors = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
                for side in 4:
                    if not is_path(x + neighbors[side].x, y + neighbors[side].y):
                        draw_texture_rect_region(path_edges, Rect2(p - camera, Vector2(32, 32)), Rect2(side * 32, 0, 32, 32))
            elif posmod(x * 17 + y * 3, 31) == 0:
                draw_texture(flower, p + Vector2(8, 8) - camera)
            if not is_path(x, y) and meadow_at(x, y):
                var phase = int(animation_time * 2 + x * .5) % 4
                draw_texture_rect_region(meadow, Rect2(p - camera, Vector2(32, 32)), Rect2(phase * 32, 0, 32, 32))
    for p in [Vector2(586, 503), Vector2(758, 489), Vector2(799, 434), Vector2(724, 642), Vector2(1050, 535), Vector2(127, 528)]:
        draw_texture(pebbles, p - camera)
    draw_rect(Rect2(ARENA.position - camera, ARENA.size), Color("a3a878"))
    draw_rect(Rect2(ARENA.position - camera, ARENA.size), Color("b89050") if not game.boss_active else Color("c47a51"), false, 2)
    var scenery: Array = []
    for i in OBSTACLES.size():
        var r: Rect2 = OBSTACLES[i]
        if i < 2:
            scenery.append({"pos": Vector2(r.position.x + 64, r.end.y), "texture": cottage, "offset": Vector2(64, 128)})
        elif i == 2:
            draw_rect(Rect2(r.position - camera, r.size), Color("305838"))
            draw_rect(Rect2(r.position + Vector2(3, 3) - camera, r.size - Vector2(6, 6)), Color("b89050"))
            for wy in range(int(r.position.y) + 8, int(r.end.y) - 8, 16):
                for wx in range(int(r.position.x) + 8, int(r.end.x) - 8, 16):
                    var frame = 5 + int(animation_time * 2 + wx / 16) % 3
                    draw_texture_rect_region(terrain, Rect2(Vector2(wx, wy) - camera, Vector2(16, 16)), Rect2(frame * 32, 0, 16, 16))
            for j in 7:
                var p = r.position + Vector2(j * 31, 0)
                draw_texture(bush, p - Vector2(8, 24) - camera)
        else:
            for ty in range(int(r.position.y), int(r.end.y), 48):
                for tx in range(int(r.position.x), int(r.end.x), 48):
                    scenery.append({"pos": Vector2(tx + 16, ty + 40), "texture": tree, "offset": Vector2(16, 56)})
    # Village hedges/fences sit outside the open walking lane.
    for x in range(128, 512, 32):
        if x in [288, 320]:
            continue
        scenery.append({"pos": Vector2(x, 664), "texture": fence, "offset": Vector2(0, 20)})
    for p in SCENERY_TREES:
        scenery.append({"pos": p, "texture": tree, "offset": Vector2(16, 56)})
    for x in range(96, 576, 32):
        scenery.append({"pos": Vector2(x + 16, 360), "texture": tree, "offset": Vector2(16, 56)})
    for p in [Vector2(168, 496), Vector2(256, 496), Vector2(360, 496), Vector2(448, 496)]:
        draw_texture(garden, p - camera)
    for p in [Vector2(180, 612), Vector2(218, 600), Vector2(420, 610), Vector2(458, 605)]:
        draw_texture(flower, p - camera)
    # Physical signposts, kept out of the walking lane.
    for p in [Vector2(132, 476), Vector2(486, 476)]:
        scenery.append({"pos": p, "texture": signpost, "offset": Vector2(16, 28)})
    label_at(Vector2(1480, 137), "E 길지기의 시험")
    var actors: Array = [{"pos": game.player, "trainer": true}, {"pos": game.companion, "mon": game.current(), "ally": true}]
    actors.append_array(scenery)
    actors.append_array(fainting)
    for enemy in game.enemies:
        if enemy.mon.hp > 0:
            actors.append({"pos": enemy.pos, "mon": enemy.mon, "enemy": enemy})
    actors.sort_custom(func(a, b): return a.pos.y < b.pos.y)
    for actor in actors:
        if Rect2(camera - Vector2(80, 80), SIZE + Vector2(160, 160)).has_point(actor.pos):
            draw_actor(actor)
    if not game.boss_telegraph.is_empty():
        var b = game.boss_telegraph
        draw_arc(b.pos - camera, b.radius, 0, TAU, 32, Color("ed8058"), 3)
    if not game.pending_capture.is_empty():
        var enemy = game.enemy_by_id(game.pending_capture.uid)
        if not enemy.is_empty():
            draw_arc(enemy.pos - camera - Vector2(0, 20), 32, -PI / 2, TAU * (1 - game.pending_capture.time / 1.2) - PI / 2, 32, Color("ffe6a0"), 3)
    for item in effects:
        label_at(item.pos, item.text, item.color)
    for impact in impacts:
        var p: Vector2 = (impact.pos - camera).floor()
        var spread = int((.18 - impact.life) * 30) + 3
        for delta in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
            draw_rect(Rect2(p + delta * spread, Vector2(2, 2)), Color("fff0d0"))

func is_path(x: int, y: int) -> bool:
    return (y >= 17 and y <= 18) or (x in [6, 7, 12, 13] and y >= 15 and y <= 17) or (x >= 9 and x <= 10 and y >= 17 and y <= 24) or (x >= 48 and x <= 50 and y >= 9 and y <= 18)

func meadow_at(x: int, y: int) -> bool:
    # Authored habitat islands; keep the road and navigation destinations readable.
    for patch in [Vector2(21, 15), Vector2(28, 16), Vector2(24, 21), Vector2(34, 22), Vector2(40, 15), Vector2(22, 30)]:
        var delta = Vector2(x, y) - patch
        if delta.x * delta.x / 9.0 + delta.y * delta.y / 2.5 < 1.0:
            return true
    return false

func draw_actor(actor: Dictionary) -> void:
    var p: Vector2 = (actor.pos - camera).floor()
    if actor.has("texture"):
        draw_texture(actor.texture, p - actor.offset)
        return

    if actor.has("trainer"):
        var frame = int(animation_time * 8) % 4 if walking else 0
        draw_texture_rect_region(explorer, Rect2(p - Vector2(16, 30), Vector2(32, 32)), Rect2(frame * 32, facing * 32, 32, 32))
        return
    var mon: Dictionary = actor.mon
    var definition = game.spec(mon)
    if mon.species_id == "m001":
        var pose = pose_for(mon, actor.get("enemy", {}))
        var sheet = leafling
        var row: int = pose.facing
        if pose.state != "walk":
            sheet = leafling_battle
            row += ["attack", "cast", "hit", "faint"].find(pose.state) * 4
        draw_texture_rect_region(sheet, Rect2(p - Vector2(16, 30), Vector2(32, 32)), Rect2(pose.frame * 32, row * 32, 32, 32))
    else:
        # Keep saved species identity; never disguise another species as Leafling.
        draw_rect(Rect2(p - Vector2(12, 24), Vector2(24, 24)), Color("b89050"))
        label_at(actor.pos - Vector2(10, 10), "?", Color("293d35"))
    if actor.has("ghost"):
        return
    if mon.uid == game.target_id:
        var tint = Color("f4e3b2") if actor.has("ally") else Color("e8ac61")
        for side in [-1, 1]:
            draw_rect(Rect2(p + Vector2(side * 18, -17), Vector2(2, 10)), tint)
            draw_rect(Rect2(p + Vector2(side * 18 - (4 if side == 1 else 0), -17), Vector2(6, 2)), tint)
    var maximum = actor.enemy.max_hp if actor.has("enemy") else game.max_hp(mon)
    if mon.uid == game.target_id or mon.hp < maximum:
        draw_rect(Rect2(p + Vector2(-18, 7), Vector2(36, 5)), Color("293d35"))
        draw_rect(Rect2(p + Vector2(-17, 8), Vector2(floor(34 * mon.hp / maximum), 2)), Color("e8ac61") if actor.has("enemy") else Color("98b85b"))
