class_name WispLook
extends RefCounted
## What a downed Hunter turns into: a Wisp, built from data. A look is an entry in
## content/rules/wisp_looks.json (colours, glow core, face, motes, trail, hover, pop effects), picked by
## its id in Save.d["look"]["wisp"]; a look only lists what it changes from "default". Adding a Wisp
## needs no code. HunterWisp plays it; this file only reads the data and builds the body.

const RULES_PATH := "res://content/rules/wisp_looks.json"
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform vec4 core_col : source_color = vec4(1.0);
uniform vec4 rim_col : source_color = vec4(1.0);
uniform float glow = 2.0;
uniform float alpha = 1.0;
uniform float flash = 1.0;
uniform float fade = 1.0;
uniform float flicker = 0.25;
uniform float flicker_hz = 9.0;
uniform float phase = 0.0;
void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float wave = 0.25 * sin(TIME * flicker_hz + phase) + 0.25 * sin(TIME * flicker_hz * 2.3 + phase * 1.7);
	float flick = 1.0 - flicker * (0.5 + wave);
	ALBEDO = mix(core_col.rgb, rim_col.rgb, edge) * glow * flash * flick;
	ALPHA = clamp((0.55 + 0.45 * edge) * alpha * fade, 0.0, 1.0);
}
"""

static var _rules := {}
static var _shader: Shader

## All look entries by id (the file, read once).
static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules

## The look for an id with every key filled in; an unknown id gives the default Wisp.
static func get_look(id: String) -> Dictionary:
	var looks: Dictionary = rules()["looks"]
	var base: Dictionary = looks[String(rules()["default"])]
	if id == "" or not looks.has(id):
		return base
	return _merged(base, looks[id])

static func _merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in over:
		if out.get(key) is Dictionary and over[key] is Dictionary:
			out[key] = _merged(out[key], over[key])
		else:
			out[key] = over[key]
	return out

## The id the local player wears, from their saved look.
static func equipped() -> String:
	var id := String(Save.d.get("look", {}).get("wisp", ""))
	return id if (rules()["looks"] as Dictionary).has(id) else String(rules()["default"])

## Wear a Wisp from now on. False for an id with no look.
static func equip(id: String) -> bool:
	if not (rules()["looks"] as Dictionary).has(id):
		return false
	if not Save.d.has("look"):
		Save.d["look"] = Unmasked.default_look()
	Save.d["look"]["wisp"] = id
	return true

## A colour spec from the data: "team" is the hunter's team colour, anything else a hex string.
static func colour(spec: String, team_col: Color) -> Color:
	return team_col if spec == "team" else Color(spec)

## The body of a Wisp (a Node3D at its hover point) with children Tilt/Core, Tilt/Halo, Tilt/Eyes, Trail
## and Motes. Its glow materials are in the node's meta "mats" so HunterWisp can flash and fade them.
static func build(look: Dictionary, team_col: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Wisp"
	var tilt := Node3D.new()
	tilt.name = "Tilt"
	root.add_child(tilt)
	var core: Dictionary = look["core"]
	var tint := colour(String(core["color"]), team_col)
	var mats: Array = []
	var core_mat := _glow_mat(core, tint, 1.0)
	tilt.add_child(_ball("Core", float(core["radius"]), core_mat))
	var halo: Dictionary = look["halo"]
	var halo_mat := _glow_mat(core, tint, float(halo["alpha"]))
	tilt.add_child(_ball("Halo", float(halo["radius"]), halo_mat))
	mats.append(core_mat)
	mats.append(halo_mat)
	if bool(look["eyes"]["on"]):
		tilt.add_child(_eyes(look["eyes"], float(core["radius"])))
	root.add_child(_particles("Trail", look["trail"], team_col, false))
	root.add_child(_particles("Motes", look["motes"], team_col, true))
	root.set_meta("mats", mats)
	return root

static func _glow_mat(core: Dictionary, tint: Color, alpha: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = GLOW_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("core_col", tint)
	mat.set_shader_parameter("rim_col", Color(String(core["rim"])))
	mat.set_shader_parameter("glow", float(core["glow"]))
	mat.set_shader_parameter("alpha", alpha)
	mat.set_shader_parameter("flicker", float(core["flicker"]))
	mat.set_shader_parameter("flicker_hz", float(core["flicker_hz"]))
	mat.set_shader_parameter("phase", randf() * TAU)
	return mat

static func _ball(node_name: String, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Two small dark eyes on the front (-Z, the way the hunter faces) of the core.
static func _eyes(eyes: Dictionary, core_radius: float) -> Node3D:
	var node := Node3D.new()
	node.name = "Eyes"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(String(eyes["color"]))
	var eye_size := float(eyes["size"])
	for side in [-1.0, 1.0]:
		var eye := _ball("Eye", eye_size, mat)
		eye.scale = Vector3(1.0, 1.35, 0.5)
		eye.position = Vector3(side * float(eyes["gap"]), float(eyes["height"]), -core_radius * 1.02)
		node.add_child(eye)
	return node

## Glowing specks: the trail stays where it was shed (world space) and only flows while moving; the motes
## drift up round the core all the time.
static func _particles(node_name: String, spec: Dictionary, team_col: Color, ambient: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.amount = int(spec["amount"])
	p.lifetime = float(spec["life"])
	p.local_coords = ambient
	p.emitting = ambient
	p.explosiveness = 0.0
	p.direction = Vector3.UP
	p.spread = 30.0 if ambient else 180.0
	p.gravity = Vector3(0, float(spec.get("rise", 0.0)), 0)
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.15
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2 if ambient else 0.08
	p.scale_amount_min = float(spec["size"]) * 0.6
	p.scale_amount_max = float(spec["size"])
	p.color = colour(String(spec["color"]), team_col)
	p.color_ramp = _fade_ramp()
	p.mesh = _quad()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

static func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	return g

static func _quad() -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.disable_receive_shadows = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = mat
	return q
