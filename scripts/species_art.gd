extends RefCounted
## Optional local art. Missing files never prevent source-only gameplay.
const ROOTS = ["res://assets/pokemon/black-white/front"]
const CACHE_LIMIT = 32
var roots: Array = ROOTS.duplicate()
var cache: Dictionary = {}
var bounds: Dictionary = {}
var recent: Array[String] = []

static func valid_id(sid: String) -> bool:
    return sid.length() == 4 and sid.begins_with("m") and sid.substr(1).is_valid_int() and int(sid.substr(1)) >= 1 and int(sid.substr(1)) <= 649 and sid == "m%03d" % int(sid.substr(1))

static func optional_texture(paths: Array) -> Texture2D:
    for path in paths:
        if not FileAccess.file_exists(path):
            continue
        var image = Image.new()
        if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
            continue
        if image != null and not image.is_empty():
            return ImageTexture.create_from_image(image)
    return null

static func optional_font() -> Font:
    var path = "res://assets/fonts/Galmuri11.ttf"
    if ResourceLoader.exists(path):
        var loaded = load(path)
        if loaded is Font:
            return loaded
    return ThemeDB.fallback_font

func texture_for(sid: String) -> Texture2D:
    if not valid_id(sid):
        return null
    if cache.has(sid):
        recent.erase(sid)
        recent.append(sid)
        return cache[sid]
    var paths: Array = []
    for directory in roots:
        paths.append(String(directory).path_join(sid + ".png"))
    var texture = optional_texture(paths)
    # Do not retain missing results, so adding local artwork works without restart.
    if texture == null:
        return null
    cache[sid] = texture
    bounds[sid] = texture.get_image().get_used_rect()
    recent.append(sid)
    if recent.size() > CACHE_LIMIT:
        var oldest = recent.pop_front()
        cache.erase(oldest)
        bounds.erase(oldest)
    return texture

func foot_offset(sid: String) -> Vector2:
    if not bounds.has(sid):
        return Vector2(48, 96)
    var used: Rect2i = bounds[sid]
    return Vector2(used.position.x + used.size.x / 2.0, used.end.y).floor()

var animation_data: Dictionary = {}
var animations: Dictionary = {}
var animation_recent: Array[String] = []

func animation_for(sid: String, elapsed: float) -> Dictionary:
    if not valid_id(sid):
        return {}
    var directory = "res://assets/pokemon/black-white/decoded/"
    if animation_data.is_empty():
        if not FileAccess.file_exists(directory + "animations.json"):
            return {}
        animation_data = JSON.parse_string(FileAccess.get_file_as_string(directory + "animations.json"))
    if not animation_data.has(sid):
        return {}
    var definition: Dictionary = animation_data[sid]
    if not animations.has(sid):
        var sheet = optional_texture([directory + definition.file])
        if sheet == null:
            return {}
        var texture = AtlasTexture.new()
        texture.atlas = sheet
        animations[sid] = texture
    animation_recent.erase(sid)
    animation_recent.append(sid)
    if animation_recent.size() > 8:
        animations.erase(animation_recent.pop_front())
    var total = 0.0
    for duration in definition.durations:
        total += float(duration)
    var time = fposmod(elapsed * 1000, total)
    var index = 0
    for duration in definition.durations:
        if time < float(duration):
            break
        time -= float(duration)
        index += 1
    index = mini(index, int(definition.frames) - 1)
    var texture: AtlasTexture = animations[sid]
    texture.region = Rect2((index % 8) * definition.width, (index / 8) * definition.height, definition.width, definition.height)
    return {"texture": texture, "foot": Vector2(definition.foot[0], definition.foot[1]), "frame": index}
