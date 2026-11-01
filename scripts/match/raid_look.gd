class_name RaidLook
extends RefCounted
## The expedition's light: the raid condition each match is played under (docs/TONE_AND_THREATS.md,
## "a scarier environment"). Moody and low-saturated, with colour kept for danger and for Boki:
## a low sun that throws long shadows, haze that thickens into the abyss, a cool split-toned grade,
## glow on what burns. Stylized, never gritty. Home (Look.cozy) is the warm opposite.
##
## Conditions: "dusk" (the default), "day", "fog". Pick one with opts["raid"] or --raid=<name>.
## Visual only: sight ranges and everything else in play are unchanged.

const CONDITIONS := ["dusk", "day", "fog"]

static func pick(opts: Dictionary) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--raid="):
			var r := a.substr(7)
			if r in CONDITIONS: return r
	var o := String(opts.get("raid", "dusk"))
	return o if o in CONDITIONS else "dusk"

## Applies a condition over the tier's base look (Look.environment) and key light.
static func apply(e: Environment, sun: DirectionalLight3D, fill: DirectionalLight3D, T: Dictionary, cond: String) -> void:
	var sm := e.sky.sky_material as ShaderMaterial if e.sky else null
	var full := Look.full_renderer()
	var cl: Array = T["clouds"]
	match cond:
		"day":
			# overcast daylight: flatter, a little cooler, still muted
			e.adjustment_saturation *= 0.88
			e.fog_density = 0.0022
			return
		"fog":
			if sm:
				sm.set_shader_parameter("top", Color("1a1d28"))
				sm.set_shader_parameter("mid", Color("3a3f52"))
				sm.set_shader_parameter("horizon", Color("7a7c88"))
				sm.set_shader_parameter("below", Color("2a2d3a"))
			e.fog_light_color = Color("5a6072")
			e.fog_density = 0.011
			e.fog_height = 1.0
			e.fog_height_density = 0.3
			e.fog_sun_scatter = 0.1
			e.ambient_light_color = Color("8a90a8")
			e.ambient_light_energy = 0.55
			e.adjustment_saturation *= 0.72
			e.adjustment_contrast = 1.04
			sun.light_color = Color("d8d4cc")
			sun.light_energy = 0.7
			sun.shadow_opacity = 0.55
			if fill: fill.light_energy = 0.3
			return
	# ---- dusk: the default. The sun low in the west, warm and amber; the shadow side violet-blue;
	# the drop below swallowed in a dusky haze.
	if sm:
		sm.set_shader_parameter("top", Color("090b18"))
		sm.set_shader_parameter("mid", Color("231f3c"))
		sm.set_shader_parameter("horizon", Color("c86c4c"))
		sm.set_shader_parameter("below", (cl[0] as Color).lerp(Color("120f20"), 0.5))
		sm.set_shader_parameter("sun_col", Color("ff9a5c"))
		sm.set_shader_parameter("sun_dir", Vector3(0.62, 0.07, -0.78))
		sm.set_shader_parameter("stars", 0.6)
	sun.rotation_degrees = Vector3(-34.0, -52.0, 0.0)       # low, so things throw long shadows
	sun.light_color = Color("ffb27a")
	sun.light_energy = 1.18
	sun.shadow_opacity = 0.82
	if fill:
		fill.light_color = Color("6f7fd8")
		fill.light_energy = 0.34
		fill.rotation_degrees = Vector3(-30.0, sun.rotation_degrees.y + 170.0, 0.0)
	e.ambient_light_color = Color("7e80b8")
	e.ambient_light_energy = 0.44
	e.fog_light_color = Color("3c3462")
	e.fog_light_energy = 1.0
	e.fog_density = 0.0042
	e.fog_sun_scatter = 0.3
	e.fog_height = -1.5
	e.fog_height_density = 0.2
	e.adjustment_saturation *= 0.8
	e.adjustment_contrast = 1.12
	e.glow_intensity = 0.8 if full else 0.65
	e.glow_hdr_threshold = 0.88
	if full:
		e.adjustment_color_correction = _dusk_curve()
		if bool(Settings.q("volfog")):
			# real light in the air: the low sun's rays through the haze over the islands
			e.volumetric_fog_enabled = true
			e.volumetric_fog_density = 0.008
			e.volumetric_fog_albedo = Color("d8c8c0")
			e.volumetric_fog_emission = Color("120e22")
			e.volumetric_fog_emission_energy = 1.0
			e.volumetric_fog_anisotropy = 0.55
			e.volumetric_fog_length = 48.0
			e.volumetric_fog_detail_spread = 2.0
			e.volumetric_fog_gi_inject = 0.0
			e.volumetric_fog_ambient_inject = 0.15
			sun.light_volumetric_fog_energy = 1.4

static var _dusk_tex: GradientTexture1D
## The desktop tone curve (Look._tone_curve) split-toned for dusk: shadows lean blue-violet, the
## mids stay neutral, highlights warm toward the low sun.
static func _dusk_curve() -> GradientTexture1D:
	if _dusk_tex == null:
		var g := Gradient.new()
		var offs := PackedFloat32Array(); var cols := PackedColorArray()
		for i in 33:
			var x := float(i) / 32.0
			var y := pow(x, 1.45)
			var sh := (1.0 - smoothstep(0.0, 0.45, x)) * 0.03     # shadows
			var hi := smoothstep(0.55, 1.0, x) * 0.035            # highlights
			offs.append(x)
			cols.append(Color(clampf(y - sh * 0.6 + hi, 0, 1), clampf(y - sh * 0.2 + hi * 0.35, 0, 1), clampf(y + sh - hi * 0.6, 0, 1)))
		g.offsets = offs; g.colors = cols
		_dusk_tex = GradientTexture1D.new()
		_dusk_tex.gradient = g
		_dusk_tex.width = 256
	return _dusk_tex

## The air and the abyss under the condition (run once the world is built, under the loading
## screen): the sun shafts slanting into the void take the low sun's colour and grow stronger at
## dusk, the cloud sea darkens toward the haze, the drifting cloud layers catch an amber rim.
static func tune_world(w: Node, cond: String) -> void:
	if w == null or cond == "day":
		return
	var shaft_col := Color("ffaa70") if cond == "dusk" else Color("c8ccd8")
	var shaft_k := 1.9 if cond == "dusk" else 0.6
	for n in w.find_children("*", "MeshInstance3D", true, false):
		var sm := (n as MeshInstance3D).material_override as ShaderMaterial
		if sm == null or sm.shader == null:
			continue
		var path := sm.shader.resource_path
		if path.ends_with("light_shaft.gdshader"):
			sm.set_shader_parameter("color", shaft_col)
			sm.set_shader_parameter("intensity", float(sm.get_shader_parameter("intensity")) * shaft_k)
		elif path.ends_with("clouds.gdshader"):
			var deep: Color = sm.get_shader_parameter("deep") if sm.get_shader_parameter("deep") != null else Color(0.1, 0.1, 0.2)
			var light: Color = sm.get_shader_parameter("light") if sm.get_shader_parameter("light") != null else Color(0.3, 0.3, 0.5)
			if cond == "dusk":
				sm.set_shader_parameter("deep", deep.lerp(Color("100c1e"), 0.5))
				sm.set_shader_parameter("light", light.lerp(Color("6a4a6a"), 0.45))
			else:
				sm.set_shader_parameter("deep", deep.lerp(Color("2a2d3a"), 0.6))
				sm.set_shader_parameter("light", light.lerp(Color("6a6e7c"), 0.6))
		elif path.ends_with("cloud_layer.gdshader") and cond == "dusk":
			sm.set_shader_parameter("rim", Color("ff9a60"))
			var lit: Color = sm.get_shader_parameter("lit")
			if lit != null: sm.set_shader_parameter("lit", lit.lerp(Color("c8a0b0"), 0.35))
