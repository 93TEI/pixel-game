extends RefCounted
## Sources are exclusively the original Black/White (2010) archive. No other-edition fallback.
const Art = preload("res://scripts/species_art.gd")
const ROOT = "res://assets/pokemon/source/bw/"
const DECODED = "res://assets/pokemon/black-white/decoded/"
var trainer = Art.optional_texture([DECODED + "trainer.png"])
var grass = Art.optional_texture([ROOT + "environment/sourceimages/summer/grass01ax.png"])
var path = Art.optional_texture([ROOT + "environment/sourceimages/summer/michi01b.png"])
var tree = Art.optional_texture([ROOT + "environment/sourceimages/summer/ki02ax.png"])
var water = Art.optional_texture([ROOT + "environment/sourceimages/ike01.png"])
var fence = Art.optional_texture([ROOT + "environment/sourceimages/saku01a.png"])
var party = Art.optional_texture([ROOT + "party.png"])
var houses: Array = []

func crop(texture: Texture2D, region: Rect2) -> AtlasTexture:
    var atlas = AtlasTexture.new()
    atlas.atlas = texture
    atlas.region = region
    return atlas

func panel_texture() -> Texture2D:
    return crop(party, Rect2(2, 2, 256, 192)) if party != null else null

func button_texture(pressed: bool) -> Texture2D:
    return crop(party, Rect2(134 if pressed else 6, 202, 124, 44)) if party != null else null

func setup_models(parent: Node) -> void:
    for number in [1, 2]:
        var filename = DECODED + "house-%d.json" % number
        if not FileAccess.file_exists(filename):
            houses.append(null)
            continue
        var data = JSON.parse_string(FileAccess.get_file_as_string(filename))
        var viewport = SubViewport.new()
        viewport.size = Vector2i(128, 128)
        viewport.transparent_bg = true
        viewport.own_world_3d = true
        viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
        parent.add_child(viewport)
        var camera = Camera3D.new()
        camera.projection = Camera3D.PROJECTION_ORTHOGONAL
        camera.size = 128
        viewport.add_child(camera)
        camera.look_at_from_position(Vector3(0, 150, 210), Vector3(0, 28, 0))
        for material_name in data.groups:
            var points = PackedVector3Array()
            var uvs = PackedVector2Array()
            for vertex in data.groups[material_name]:
                points.append(Vector3(vertex[0], vertex[1], vertex[2]))
                uvs.append(Vector2(vertex[3], vertex[4]))
            var arrays = []
            arrays.resize(Mesh.ARRAY_MAX)
            arrays[Mesh.ARRAY_VERTEX] = points
            arrays[Mesh.ARRAY_TEX_UV] = uvs
            var mesh = ArrayMesh.new()
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            var material = StandardMaterial3D.new()
            material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            material.cull_mode = BaseMaterial3D.CULL_DISABLED
            material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
            material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
            material.albedo_texture = Art.optional_texture([ROOT + "houses/Nuvema Town House %d/%s.png" % [number, material_name]])
            mesh.surface_set_material(0, material)
            var instance = MeshInstance3D.new()
            instance.mesh = mesh
            viewport.add_child(instance)
        houses.append(viewport.get_texture())
