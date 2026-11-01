class_name RaidLook
extends RefCounted
## The expedition's light: the raid condition each match is played under (docs/TONE_AND_THREATS.md,
## "a scarier environment"). Moody and low-saturated, with colour kept for danger and for Boki:
## a low sun that throws long shadows, haze that thickens into the abyss, a cool split-toned grade,
## glow on what burns. Stylized, never gritty. Home (Look.cozy) is the warm opposite.
##
## Conditions, rolled per match from the match seed (roll()):
##   clear  a clear evening: the low amber sun the game has always had (the demo look, unchanged)
##   dusk   the sun gone under the islands: deep violet, ember horizon, sight a little shorter
##   night  moonlight: dark and blue, sight much shorter, light gives you away, the Blight is bolder
##   ash    an ash storm: warm grey haze, wind-blown ash and embers, sight shorter
##   fog    a fog bank: grey and close, sight much shorter
## "day" (flat overcast daylight) is still there to force, but never rolled.
## Force one with opts["raid"] or --raid=<name>. Arena, training, the tutorial and the duel room
## stay clear. Sight (SIGHT), the Blight (BLIGHT) and the look all follow the condition.

const CONDITIONS := ["clear", "dusk", "night", "ash", "fog"]
const FORCED_ONLY := ["day"]
const ALIASES := {"ash_storm": "ash", "storm": "ash", "ashstorm": "ash", "clear_day": "clear", "evening": "clear"}
## How often each comes up: mostly clear, the scary ones now and then.
const WEIGHTS := {"clear": 0.42, "dusk": 0.18, "night": 0.14, "ash": 0.12, "fog": 0.14}
## Sight range as a share of the usual (Match.VIEW_RANGE). Revealed targets (muzzle flashes, a
## Warden's light) are seen at full range whatever the condition.
const SIGHT := {"clear": 1.0, "day": 1.0, "dusk": 0.85, "night": 0.6, "ash": 0.72, "fog": 0.62}
## How much bolder and more numerous the Blight is (BlightDir).
const BLIGHT := {"clear": 1.0, "day": 1.0, "dusk": 1.12, "night": 1.4, "ash": 1.25, "fog": 1.2}
## Outside-of-sight darkening (the vis shader's "dark" multiplier; 0.42 is the usual).
const VIS_DARK := {"clear": 0.42, "day": 0.42, "dusk": 0.38, "night": 0.29, "ash": 0.36, "fog": 0.34}
const NAMES := {"clear": "Clear evening", "day": "Overcast day", "dusk": "Dusk", "night": "Night", "ash": "Ash storm", "fog": "Fog"}
const BLURBS := {
	"clear": "Good light. You see far, and so does everything else.",
	"day": "Flat daylight.",
	"dusk": "The light is going. Sight is a little shorter and the Blight stirs earlier.",
	"night": "Dark. You see much less, and shooting lights you up. The Blight hunts bolder.",
	"ash": "Wind-blown ash cuts your sight. The Blight is restless.",
	"fog": "A fog bank. You won't see them until they're close, and they won't see you.",
}
const COLORS := {"clear": Color("ffc48a"), "day": Color("dfe6f0"), "dusk": Color("d58ad8"), "night": Color("8aa6ff"), "ash": Color("e09a6a"), "fog": Color("b8c0cc")}

static func norm(r: String) -> String:
	r = r.to_lower()
	r = String(ALIASES.get(r, r))
	return r if r in CONDITIONS or r in FORCED_ONLY else ""

## The condition rolled for a match seed (its own RNG, so the match's other rolls don't move).
static func roll(seed_val: int) -> String:
	var g := RandomNumberGenerator.new()
	g.seed = int(seed_val) * 7919 + 0x5A1D
	var x := g.randf()
	for c in CONDITIONS:
		x -= float(WEIGHTS[c])
		if x <= 0.0:
			return c
	return "clear"

## Whether a match with these options rolls a condition at all (only real expeditions do).
static func rolls(opts: Dictionary) -> bool:
	for k in ["tutorial", "training", "duel", "arena", "sandbox"]:
		if opts.get(k, false):
			return false
	if not opts.get("big", true):
		return false
	# screenshot tooling keeps the clear look unless a condition is asked for
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			return false
	return true

static func pick(opts: Dictionary, seed_val := 0) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--raid="):
			var r := norm(a.substr(7))
			if r != "": return r
		if a.begins_with("--raid-demo="):
			var r2 := norm(a.substr(12))
			if r2 != "": return r2
	if opts.has("raid"):
		var o := norm(String(opts["raid"]))
		if o != "": return o
	return roll(seed_val) if rolls(opts) else "clear"

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
			if full and bool(Settings.q("volfog")):
				e.volumetric_fog_enabled = true
				e.volumetric_fog_density = 0.012
				e.volumetric_fog_albedo = Color("c8ccd4")
				e.volumetric_fog_length = 40.0
				e.volumetric_fog_gi_inject = 0.0
				e.volumetric_fog_ambient_inject = 0.35
			return
		"night":
			_night(e, sun, fill, sm, cl, full)
			return
	# ---- clear: the default (an evening with a clear sky). The sun low in the west, warm and amber;
	# the shadow side violet-blue; the drop below swallowed in a dusky haze. This is the look the
	# game has always had: dusk and the ash storm build on it below.
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

	match cond:
		"dusk": _dusk(e, sun, fill, sm, full)
		"ash": _ash(e, sun, fill, sm, full)

## Dusk: the clear evening an hour later. The sun is under the islands, the sky deep violet with an
## ember rim, the light low and red, the haze heavier.
static func _dusk(e: Environment, sun: DirectionalLight3D, fill: DirectionalLight3D, sm: ShaderMaterial, full: bool) -> void:
	if sm:
		sm.set_shader_parameter("top", Color("06060f"))
		sm.set_shader_parameter("mid", Color("1a1430"))
		sm.set_shader_parameter("horizon", Color("8a3a3a"))
		sm.set_shader_parameter("sun_col", Color("ff6a3c"))
		sm.set_shader_parameter("sun_dir", Vector3(0.66, 0.015, -0.75))
		sm.set_shader_parameter("stars", 0.9)
	sun.rotation_degrees = Vector3(-22.0, -58.0, 0.0)
	sun.light_color = Color("ff8a5a")
	sun.light_energy = 0.82
	sun.shadow_opacity = 0.86
	if fill:
		fill.light_color = Color("5a5ec8")
		fill.light_energy = 0.36
	e.ambient_light_color = Color("6a5c9c")
	e.ambient_light_energy = 0.4
	e.fog_light_color = Color("2c2048")
	e.fog_density = 0.0058
	e.adjustment_saturation *= 0.88
	e.glow_intensity *= 1.15

## Night: moonlight. Cold blue key, very low ambient, the haze dark; everything that glows (Boki,
## embers, the Blight's cracks, a Warden's lamp) carries the frame.
static func _night(e: Environment, sun: DirectionalLight3D, fill: DirectionalLight3D, sm: ShaderMaterial, cl: Array, full: bool) -> void:
	if sm:
		sm.set_shader_parameter("top", Color("020309"))
		sm.set_shader_parameter("mid", Color("0a0f22"))
		sm.set_shader_parameter("horizon", Color("1e2a4a"))
		sm.set_shader_parameter("below", (cl[0] as Color).lerp(Color("04050c"), 0.8))
		sm.set_shader_parameter("sun_col", Color("b8c8ff"))
		sm.set_shader_parameter("sun_dir", Vector3(-0.4, 0.35, -0.85))
		sm.set_shader_parameter("stars", 1.6)
	sun.rotation_degrees = Vector3(-48.0, 30.0, 0.0)
	sun.light_color = Color("b4c0e8")
	sun.light_energy = 0.4
	sun.shadow_opacity = 0.7
	if fill:
		fill.light_color = Color("3a3a80")
		fill.light_energy = 0.18
		fill.rotation_degrees = Vector3(-30.0, sun.rotation_degrees.y + 170.0, 0.0)
	e.ambient_light_color = Color("4c5678")
	e.ambient_light_energy = 0.32
	e.fog_light_color = Color("0c1430")
	e.fog_light_energy = 1.0
	e.fog_density = 0.007
	e.fog_sun_scatter = 0.05
	e.fog_height = -1.0
	e.fog_height_density = 0.25
	e.adjustment_saturation *= 0.62
	e.adjustment_contrast = 1.14
	e.tonemap_exposure *= 1.12
	e.glow_intensity = 1.0 if full else 0.85
	e.glow_hdr_threshold = 0.7

## Ash storm: the clear evening choked with wind-blown ash. Warm grey haze, a dim orange sun
## through it, flatter shadows. (The blowing ash and embers themselves: storm_fx.)
static func _ash(e: Environment, sun: DirectionalLight3D, fill: DirectionalLight3D, sm: ShaderMaterial, full: bool) -> void:
	if sm:
		sm.set_shader_parameter("top", Color("2a2220"))
		sm.set_shader_parameter("mid", Color("5a4438"))
		sm.set_shader_parameter("horizon", Color("a0684a"))
		sm.set_shader_parameter("below", Color("2a201c"))
		sm.set_shader_parameter("sun_col", Color("ff8a4a"))
		sm.set_shader_parameter("stars", 0.0)
	sun.light_color = Color("ffa070")
	sun.light_energy = 0.8
	sun.shadow_opacity = 0.6
	if fill:
		fill.light_color = Color("8a6a6a")
		fill.light_energy = 0.3
	e.ambient_light_color = Color("a08878")
	e.ambient_light_energy = 0.5
	e.fog_light_color = Color("6a5040")
	e.fog_density = 0.0105
	e.fog_sun_scatter = 0.35
	e.fog_height = 0.5
	e.fog_height_density = 0.28
	e.adjustment_saturation *= 0.7
	e.adjustment_contrast = 1.05
	if full and e.volumetric_fog_enabled:
		e.volumetric_fog_density = 0.014
		e.volumetric_fog_albedo = Color("c8a890")

## The wind-blown ash (and a few live embers) that stream past the camera in an ash storm, and the
## drifting murk of a fog bank. Follows the camera's focus; null for the other conditions.
static func storm_fx(cond: String) -> Node3D:
	if cond != "ash" and cond != "fog":
		return null
	var root := Node3D.new()
	root.name = "RaidFx"
	var lite := Settings.quality() == "low"
	if cond == "ash":
		root.add_child(_streak(Color(0.66, 0.6, 0.55, 0.6), 340 if not lite else 140, 0.085, 1.6, false))
		root.add_child(_streak(Color(1.0, 0.55, 0.22, 0.9), 26 if not lite else 12, 0.035, 2.2, true))
	else:
		root.add_child(_puffs(Color(0.72, 0.75, 0.8, 0.12), 34 if not lite else 16))
	return root

static func _streak(col: Color, n: int, size: float, life: float, glow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22.0, 5.0, 16.0)
	p.direction = Vector3(1.0, -0.15, 0.35)
	p.spread = 12.0
	p.gravity = Vector3(0, -0.4, 0)
	p.initial_velocity_min = 9.0
	p.initial_velocity_max = 15.0
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(size * 6.0, size)
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mt.vertex_color_use_as_albedo = true
	mt.albedo_color = col
	if glow:
		mt.emission_enabled = true
		mt.emission = Color(col.r, col.g, col.b)
		mt.emission_energy_multiplier = 2.5
	q.material = mt
	p.mesh = q
	p.color = col
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	p.color_ramp = g
	p.position = Vector3(-6.0, 3.0, -2.0)
	return p

static func _puffs(col: Color, n: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(24.0, 1.5, 18.0)
	p.direction = Vector3(1.0, 0.0, 0.2)
	p.spread = 20.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.local_coords = false
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mt.vertex_color_use_as_albedo = true
	var gt := GradientTexture2D.new()
	var gg := Gradient.new()
	gg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gt.gradient = gg; gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64; gt.height = 64
	mt.albedo_texture = gt
	q.material = mt
	p.mesh = q
	p.color = col
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	p.color_ramp = g
	p.position = Vector3(0, 1.2, 0)
	return p

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
	# (the clear evening keeps exactly the look it always had: the code below once called it "dusk")
	var warm := cond in ["clear", "dusk", "ash"]
	var shaft_col := {"clear": Color("ffaa70"), "dusk": Color("ff7a58"), "ash": Color("ffb080"), "night": Color("9ab0ff"), "fog": Color("c8ccd8")}.get(cond, Color("c8ccd8")) as Color
	var shaft_k := {"clear": 1.9, "dusk": 1.5, "ash": 2.3, "night": 0.9, "fog": 0.6}.get(cond, 0.6) as float
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
			if cond == "clear":
				sm.set_shader_parameter("deep", deep.lerp(Color("100c1e"), 0.5))
				sm.set_shader_parameter("light", light.lerp(Color("6a4a6a"), 0.45))
			elif cond == "dusk":
				sm.set_shader_parameter("deep", deep.lerp(Color("08060f"), 0.65))
				sm.set_shader_parameter("light", light.lerp(Color("5a2e44"), 0.55))
			elif cond == "night":
				sm.set_shader_parameter("deep", deep.lerp(Color("02030a"), 0.8))
				sm.set_shader_parameter("light", light.lerp(Color("1e2a4a"), 0.7))
			elif cond == "ash":
				sm.set_shader_parameter("deep", deep.lerp(Color("1e1612"), 0.7))
				sm.set_shader_parameter("light", light.lerp(Color("7a5a46"), 0.65))
			else:
				sm.set_shader_parameter("deep", deep.lerp(Color("2a2d3a"), 0.6))
				sm.set_shader_parameter("light", light.lerp(Color("6a6e7c"), 0.6))
		elif path.ends_with("cloud_layer.gdshader") and warm:
			sm.set_shader_parameter("rim", Color("ff9a60") if cond != "dusk" else Color("ff6a4a"))
			var lit: Color = sm.get_shader_parameter("lit")
			if lit != null: sm.set_shader_parameter("lit", lit.lerp(Color("c8a0b0"), 0.35))
