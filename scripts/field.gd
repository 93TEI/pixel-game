extends Node2D
## Playable prototype renderer. Optional local sprites; no retired art dependencies.
const SIZE = Vector2(320, 288)
const ARENA = Rect2(1408, 96, 448, 320)
const OBSTACLES = [Rect2(160, 432, 96, 64), Rect2(352, 432, 64, 64),
    Rect2(832, 288, 224, 128), Rect2(1120, 800, 160, 192), Rect2(448, 800, 96, 128)]
const SCENERY_TREES = [Vector2(112, 416), Vector2(144, 416), Vector2(112, 448), Vector2(144, 448), Vector2(112, 480), Vector2(144, 480), Vector2(496, 448), Vector2(528, 448), Vector2(496, 480), Vector2(528, 480), Vector2(144, 672), Vector2(240, 704), Vector2(400, 704), Vector2(560, 736), Vector2(736, 448), Vector2(1056, 480)]
var game: TrailGame
var camera = Vector2.ZERO
var navigation = AStarGrid2D.new()
const Art = preload("res://scripts/species_art.gd")
var species_art = Art.new()
var bw = preload("res://scripts/bw_art.gd").new()
var font = Art.optional_font()
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
    bw.setup_models(self)
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    if font is FontFile:
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
    draw_string(font, p - camera + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("293d35"))
    draw_string(font, p - camera, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
    if game == null:
        return
    draw_bw_ground()
    var scenery: Array = []
    for p in SCENERY_TREES:
        scenery.append({"pos": p, "scenery": true})
    for i in range(3, OBSTACLES.size()):
        var obstacle: Rect2 = OBSTACLES[i]
        for y in range(int(obstacle.position.y), int(obstacle.end.y), 32):
            for x in range(int(obstacle.position.x), int(obstacle.end.x), 32):
                scenery.append({"pos": Vector2(x + 16, y + 28), "scenery": true})
    label_at(Vector2(1460, 137), "E 길지기의 시험")
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
        label_at(game.boss_telegraph.pos, "주의!", Color.WHITE)
    if not game.pending_capture.is_empty():
        var enemy = game.enemy_by_id(game.pending_capture.uid)
        if not enemy.is_empty():
            label_at(enemy.pos - Vector2(0, 36), "포획 중", Color.WHITE)
    for item in effects:
        label_at(item.pos, item.text, item.color)
func repeat_original(texture: Texture2D, world_rect: Rect2) -> void:
    if texture == null:
        return
    var size = texture.get_size()
    var clip = world_rect.intersection(Rect2(camera, SIZE))
    if not clip.has_area():
        return
    var start = ((clip.position - world_rect.position) / size).floor()
    var end = ((clip.end - world_rect.position) / size).ceil()
    for y in range(int(start.y), int(end.y)):
        for x in range(int(start.x), int(end.x)):
            var tile = Rect2(world_rect.position + Vector2(x, y) * size, size)
            var visible_tile = tile.intersection(world_rect)
            draw_texture_rect_region(texture, Rect2(visible_tile.position - camera, visible_tile.size), Rect2(Vector2.ZERO, visible_tile.size))

func draw_bw_ground() -> void:
    # The layout is still the prototype map; textures/models themselves are original BW.
    draw_rect(Rect2(Vector2.ZERO, SIZE), Color.BLACK)
    repeat_original(bw.grass, Rect2(Vector2.ZERO, TrailGame.WORLD_SIZE))
    var start = Vector2i(camera / 32)
    for y in range(start.y, start.y + 11):
        for x in range(start.x, start.x + 12):
            if is_path(x, y):
                repeat_original(bw.path, Rect2(Vector2(x, y) * 32, Vector2(32, 32)))
    repeat_original(bw.water, OBSTACLES[2])
    for rect in [Rect2(128, 650, 152, 22), Rect2(360, 650, 152, 22)]:
        repeat_original(bw.fence, rect)
    repeat_original(bw.path, ARENA)
    for i in 2:
        if bw.houses.size() > i and bw.houses[i] != null:
            draw_texture(bw.houses[i], OBSTACLES[i].get_center() - camera - Vector2(64, 98))
        label_at(OBSTACLES[i].end + Vector2(-64, 16), "E 회복" if i == 0 else "E 상점", Color.WHITE, 10)

func is_path(x: int, y: int) -> bool:
    return (y >= 17 and y <= 18) or (x in [6, 7, 12, 13] and y >= 15 and y <= 17) or (x >= 9 and x <= 10 and y >= 17 and y <= 24) or (x >= 48 and x <= 50 and y >= 9 and y <= 18)

func draw_actor(actor: Dictionary) -> void:
    var p: Vector2 = (actor.pos - camera).floor()
    if actor.has("scenery"):
        if bw.tree != null:
            draw_texture(bw.tree, p - Vector2(bw.tree.get_width() / 2.0, bw.tree.get_height() - 4))
        return
    if actor.has("trainer"):
        if bw.trainer != null:
            var row = [1, 3, 0, 2][facing]
            var frame = [0, 1, 0, 2][int(animation_time * 8) % 4] if walking else 0
            draw_texture_rect_region(bw.trainer, Rect2(p - Vector2(16, 28), Vector2(32, 32)), Rect2(frame * 32, row * 32, 32, 32))
        return
    var mon: Dictionary = actor.mon
    var animated = species_art.animation_for(mon.species_id, animation_time)
    var texture = animated.get("texture", species_art.texture_for(mon.species_id))
    var pose = pose_for(mon, actor.get("enemy", {}))
    var tint = Color.WHITE
    if actor.has("ghost"):
        tint.a = clampf(actor.life / .64, 0, 1)
    if texture != null:
        # Original battle sprites retain their native pixels.
        draw_texture(texture, p - animated.get("foot", species_art.foot_offset(mon.species_id)), tint)
    else:
        label_at(actor.pos - Vector2(14, 28), game.spec(mon).name, Color("fff0c2"), 10)
    if actor.has("ghost"):
        return
    if mon.uid == game.target_id:
        label_at(actor.pos + Vector2(-12, 14), "▼", Color.WHITE)
