class_name PropGlb
extends RefCounted
## Our own world props as 3D models (docs/art/PROPS_3D.md): art/props/<id>/<id>.glb, made with Meshy
## image-to-3D from the approved concepts and cleaned up in Blender. Each part the game animates is its own
## node with its pivot where it moves: the jump pad's Top (from its bottom), the gust fan's Blades (spin about
## local Z, the fan's front), the updraft vent's Grate and Glow, the chest's Lid (hinged at the back) and Lock.
## Drawn with the toon shader on the prop's own texture. The "<id>_glow" surfaces glow and, given a tint,
## take it (the texture's light and shade times the tint). null when the file is missing or with --prim-art,
## so callers keep their primitive model.
const PATH := "res://art/props/%s/%s.glb"
const GLOW := 0.45  # the glow part's emission (as the primitive pad's plate)
const GLOW_GAIN := 1.35  # the glow parts' texture is pale (mean light 0.65 to 0.8): bring the tint back up
static var _scenes := {}
static var _mats := {}


static func build(id: String, tint := Color(0, 0, 0, 0)) -> Node3D:
	if not Assets.on():
		return null
	if not _scenes.has(id):
		var path := PATH % [id, id]
		_scenes[id] = load(path) if ResourceLoader.exists(path) else null
	if _scenes[id] == null:
		return null
	var root := (_scenes[id] as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, _material(mi.mesh.surface_get_material(s) as BaseMaterial3D, id, tint))
	return root


## One shared material per source surface and tint, so every pad batches.
static func _material(src: BaseMaterial3D, id: String, tint: Color) -> ShaderMaterial:
	var glow := String(src.resource_name) == id + "_glow"
	var key := "%s|%s|%s" % [id, src.resource_name, tint.to_html() if glow else ""]
	if not _mats.has(key):
		var m := Models.toon(Color.WHITE, not glow, GLOW if glow else 0.0)
		m.set_shader_parameter("use_tex", true)
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		if glow and tint.a > 0.0:
			m.set_shader_parameter("albedo", tint * GLOW_GAIN)
			m.set_shader_parameter("tex_sat", 0.0)
		_mats[key] = m
	return _mats[key]
