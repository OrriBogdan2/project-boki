extends Node3D
## The prologue: a short animated telling of how the Skylands came to be, before your first egg.
## Five shots, each a little set far apart from the others, with a line of story under letterbox bars:
##   1. the land whole  2. the Wyrm wakes  3. the Hollowing  4. the Boki  5. hunters race for the Wyrmheart
## then the PROJECT BOKI title card. Each shot is one or two eased camera moves (a new move is a cut), its own
## light (MOODS) and its own action. Space or a click moves on; holding Esc skips it all.

signal finished

const SETS := {"whole": Vector3(0, 0, 0), "kin": Vector3(1200, 0, 0), "drop": Vector3(2400, 0, 0)}
## Light per beat: sky (top, mid, horizon), cloud sea (deep, light, glow), haze, ambient, sun colour and
## energy, stars.
const MOODS := {
	"gold": {"sky": [Color("34407e"), Color("d9946e"), Color("ffd27a")], "sea": [Color("6a4c6e"), Color("e8b48c"), Color("ffc46a")],
		"fog": Color("d29a64"), "amb": Color("f4d4a6"), "sun": Color("ffd690"), "sun_e": 1.3, "stars": 0.0},
	"fire": {"sky": [Color("240c1c"), Color("7a2626"), Color("ff6a2e")], "sea": [Color("34141e"), Color("9a3a34"), Color("ff5a1e")],
		"fog": Color("7a2e2a"), "amb": Color("c48078"), "sun": Color("ff8a56"), "sun_e": 0.9, "stars": 0.0},
	"dawn": {"sky": [Color("3e72c4"), Color("8eb8ea"), Color("ffcf96")], "sea": [Color("5a74b0"), Color("c4d6f2"), Color("ffc890")],
		"fog": Color("a8c0e6"), "amb": Color("d8e2f4"), "sun": Color("ffe8c4"), "sun_e": 1.25, "stars": 0.0},
	"deep": {"sky": [Color("0e0a2a"), Color("362a70"), Color("9466cc")], "sea": [Color("181238"), Color("5e44a0"), Color("c486ff")],
		"fog": Color("3c2c6c"), "amb": Color("8674c4"), "sun": Color("c4a4ff"), "sun_e": 0.7, "stars": 0.9},
}
const SKY_KEYS := ["top", "mid", "horizon"]
const SEA_KEYS := ["deep", "light", "glow"]
## How fast a camera move still creeps at its end, as a share of its average speed (eased, never a dead stop)
const END_CREEP := 0.25
const MANTLES_AT := 2.6        # s into THE HOLLOWING: the Hunters' selves burst out of the keep as Masks

var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var sea_mat: ShaderMaterial
var t := 0.0
var shot := -1
var shot_t := 0.0
var shots: Array = []
var rng := RandomNumberGenerator.new()
var pieces: Array = []          # the broken continent: {node, dir, fall, spin}
var gliders: Array = []
var boki: PrologueBoki          # THE MASKS' set (scripts/ui/prologue_boki.gd)
var broke := false
var rumble := 0.0                # the roar and the fall: a faint camera rumble (RUMBLE_AMP), never a shake
const RUMBLE_AMP := 0.08
var then_go := "hatch"          # where to go after: "hatch" for a new game, "title" when rewatched
# ui
var ui: CanvasLayer
var fade: ColorRect
var flash: ColorRect
var caption: Label
const CAPTION_MARGIN := 0.07      # of the width, each side: the caption wraps inside the rest
const CAPTION_LINES_PER_HEIGHT := 25.0      # the caption's font size is the window's height over this
var bar_top: ColorRect
var bar_bot: ColorRect
var card: Control
var done := false
var advancing := false          # fading out to the next shot (the camera keeps moving meanwhile)
var wyrm: Wyrm
var wyrm_paths := {}            # event -> Curve3D the Wyrm flies along in that shot
var towns: Array = []           # [island, local position] of each house and tower, to set alight
var burning := 0
var debris: Array = []          # falling rocks: {node, vel, spin}
var dust: CPUParticles3D        # the dust of the breaking land
var deep_eyes: Node3D
var heart_light: OmniLight3D
var look_mat: ShaderMaterial    # the storybook screen effect
var chapter_lbl: Label
var pips: HBoxContainer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_music("title")
	Sfx.play_ambience("home")
	rng.seed = 77
	var we := WorldEnvironment.new()
	env = Look.environment({"sun_dir": Vector3(0.3, 0.14, -0.95), "ambient_energy": 0.6, "fog_density": 0.0012,
		"fog_height": -40.0, "fog_height_density": 0.02})
	we.environment = env
	add_child(we)
	sun = Look.lights(self, Color("ffe2c4"), 1.05, Vector3(-28, 160, 0), 120.0)
	sun.shadow_opacity = 0.5
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000, 9000)
	sea.mesh = pm
	sea_mat = ShaderMaterial.new()
	sea_mat.shader = load("res://shaders/clouds.gdshader")
	sea_mat.set_shader_parameter("glow_amount", 0.8)
	sea_mat.set_shader_parameter("sun_xz", Vector2(0.3, -0.95))
	sea_mat.set_shader_parameter("scale", 0.012)
	sea.material_override = sea_mat
	sea.position = Vector3(1200, -70.0, 0)
	add_child(sea)
	cam = Camera3D.new()
	cam.fov = 48.0
	cam.far = 5000.0
	add_child(cam)
	cam.make_current()
	_set_whole()
	boki = PrologueBoki.new()
	boki.position = SETS["kin"]
	add_child(boki)
	var rise := _drift(SETS["kin"] + PrologueBoki.HUNTER_AT, Vector3(0.45, 0.1, 0.45), Arch.color(PrologueBoki.MANTLE),
		30, 0.04, 1.6, false)
	rise.lifetime = 1.6
	rise.preprocess = 0.0
	rise.emitting = false
	boki.build(rng, rise)
	_set_drop()
	_set_wyrm()
	_build_ui()
	shots = _shots()
	_next_shot()

## Each shot: its camera moves [from, look, to, look, seconds] (a new move is a cut), its light, the screen
## grade, and its line of story.
func _shots() -> Array:
	var W: Vector3 = SETS["whole"]
	var K: Vector3 = SETS["kin"]
	var D: Vector3 = SETS["drop"]
	var out := [
		{"chapter": "BEFORE THE FALL", "mood": "gold", "tint": Color("ffd27a"), "grade": 0.16,
			"text": "Once, the sky held one great land, Solmere,\nruled by Malgrave, the Beloved, a queen who never aged.",
			"cam": [[W + Vector3(-70, 22, 80), W + Vector3(0, 2, 0), W + Vector3(-54, 17, 62), W + Vector3(0, 3, 0), 3.4],
				[W + Vector3(-16, 8, 18), W + Vector3(0, 5.0, 0), W + Vector3(-13, 7, 14.5), W + Vector3(0, 5.6, 0), 3.4]]},
		{"chapter": "THE WAKING", "mood": "gold", "tint": Color("ff5a3a"), "grade": 0.3, "event": "wyrm",
			"text": "She was the Wyrm in human shape.\nThe night a thief reached its heart, it woke.",
			"cam": [[W + Vector3(-22, 12, 26), W + Vector3(18, 6, -30), W + Vector3(-20, 11, 23), W + Vector3(20, 10, -30), 3.0],
				[W + Vector3(12, 7, 40), W + Vector3(8, 9, -10), W + Vector3(10, 8, 42), W + Vector3(-16, 9, 10), 4.0]]},
		{"chapter": "THE HOLLOWING", "mood": "fire", "tint": Color("d0406a"), "grade": 0.34, "event": "break",
			"text": "The Hollowing broke the land into the floating Skylands,\nand the Wyrm stole our essence.\n"
				+ "In time, humans, beasts and skyfolk alike were born without faces.\nWe became a new race: the Empty.",
			"cam": [[W + Vector3(-30, 22, 46), W + Vector3(0, 0, 0), W + Vector3(-36, 28, 56), W + Vector3(0, -6, 0), 3.6],
				[W + Vector3(46, 4, 34), W + Vector3(0, -4, 0), W + Vector3(58, 10, 46), W + Vector3(0, -20, 0), 3.9]]},
		{"chapter": "THE MASKS", "mood": "dawn", "tint": Color("ffe4b0"), "grade": 0.12, "event": "kin",
			"text": "Our only salvation became the cursed fossils we had tried to destroy:\n"
				+ "Masks, each carrying the soul of a fallen Hunter of old.",
			"cam": [[K + Vector3(0.2, 2.0, 7.6), K + Vector3(0.2, 0.9, -1.2), K + Vector3(0.25, 1.7, 6.4), K + Vector3(0.3, 0.85, -1.0), 3.1],
				[K + Vector3(0.4, 0.55, 3.9), K + Vector3(0.4, 0.85, -0.3), K + Vector3(0.4, 0.55, 3.45), K + Vector3(0.4, 0.88, -0.3), 4.4]]},
		{"chapter": "THE RACE", "mood": "deep", "tint": Color("b08aff"), "grade": 0.24, "event": "drop",
			"text": "Put on a Mask, bond with a Boki, and hunt for the Wyrmheart:\n"
				+ "one wish to remake the world, or rule it.\nEvery Hunter wants it. So does Malgrave.",
			"cam": [[D + Vector3(-6, 20, 14), D + Vector3(2, 4, -30), D + Vector3(-3, 16, 2), D + Vector3(8, -10, -52), 4.0],
				[D + Vector3(-4, 14, -4), D + Vector3(14, -28, -70), D + Vector3(0, 11, -12), D + Vector3(18, -36, -82), 4.2]]},
	]
	for s in out:
		var dur := 0.0
		for mv in s["cam"]:
			dur += float(mv[4])
		s["dur"] = dur
	return out

# ---------------------------------------------------------------- sets
## The world whole: one great landmass of fitted-together islands, with towns on it and the Crown at its heart.
func _set_whole() -> void:
	var o: Vector3 = SETS["whole"]
	var offs := [Vector2(0, 0), Vector2(15, 4), Vector2(-14, 6), Vector2(4, -15), Vector2(-8, -13), Vector2(10, 16),
		Vector2(-6, 17), Vector2(20, -10), Vector2(-21, -6)]
	for i in offs.size():
		var r := 9.5 if i == 0 else rng.randf_range(7.5, 9.0)
		var isl := Scenery.island(rng, r, true, false)
		var at := o + Vector3(offs[i].x, 0, offs[i].y)
		isl.position = at
		isl.rotation.y = rng.randf() * TAU
		add_child(isl)
		# old towns: houses round the edge, a stone tower on each isle but the Crown's
		for k in 2:
			var a := rng.randf() * TAU
			var hs := Models.house()
			hs.scale = Vector3.ONE * 0.55
			hs.position = Vector3(cos(a), 0, sin(a)) * r * (0.72 if i == 0 else 0.45)
			hs.rotation.y = rng.randf() * TAU
			isl.add_child(hs)
			towns.append([isl, hs.position + Vector3(0, 1.4, 0)])
		if i == 0:
			towns.append([isl, _crown(isl)])
		else:
			var stone := Models.toon(Color("c9c0b0"))
			var tw := Models.part(isl, Models.cyl(0.8, 1.0, 4.0, 8), stone, Vector3(rng.randf_range(-3, 3), 2.0, rng.randf_range(-3, 3)))
			Models.part(isl, Models.cyl(0.0, 1.1, 1.4, 8), Models.toon(Color("c9604a")), tw.position + Vector3(0, 2.7, 0))
			towns.append([isl, tw.position + Vector3(0, 3.2, 0)])
		var dir := Vector3(offs[i].x, 0, offs[i].y).normalized() if i > 0 else Vector3.ZERO
		pieces.append({"node": isl, "base": at, "dir": dir, "fall": rng.randf_range(4.0, 30.0) * (0.3 if i == 0 else 1.0),
			"spin": rng.randf_range(-0.25, 0.25), "drift": rng.randf_range(6.0, 16.0)})
	dust = _drift(o + Vector3(0, -2, 0), Vector3(40, 10, 40), Color(0.42, 0.32, 0.32, 0.25), 50, 6.0, -0.6, false)
	dust.emitting = false
	dust.visible = false

## The Crown: the sovereign's keep at the heart of the land, roofed in gold. Returns where it burns.
func _crown(isl: Node3D) -> Vector3:
	var stone := Models.toon(Color("e2d8c6"))
	var gold := Models.toon(Color("f2b64a"), true, 0.3)
	Models.part(isl, Models.cyl(2.0, 2.5, 5.0, 12), stone, Vector3(0, 2.5, 0))
	Models.part(isl, Models.cyl(1.2, 1.5, 3.4, 12), stone, Vector3(0, 6.7, 0))
	Models.part(isl, Models.cyl(0.0, 1.6, 2.6, 12), gold, Vector3(0, 9.7, 0))
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		var at := Vector3(cos(a), 0, sin(a)) * 2.6
		Models.part(isl, Models.cyl(0.45, 0.55, 6.0, 8), stone, at + Vector3(0, 3.0, 0))
		Models.part(isl, Models.cyl(0.0, 0.7, 1.4, 8), gold, at + Vector3(0, 6.7, 0))
	return Vector3(0, 8.0, 0)

## The drop: hunters gliding down over the wild isles toward the Heart, glowing far below.
func _set_drop() -> void:
	var o: Vector3 = SETS["drop"]
	var heart := Scenery.island(rng, 13.0, true, true)
	heart.position = o + Vector3(14, -30, -70)
	add_child(heart)
	Scenery.heart(heart, 13.0)
	heart_light = OmniLight3D.new()
	heart_light.light_color = Color("c48aff")
	heart_light.omni_range = 40.0
	heart_light.light_energy = 2.0
	heart_light.position = heart.position + Vector3(0, 6, 0)
	add_child(heart_light)
	for i in 9:
		var isl := Scenery.island(rng, rng.randf_range(4.0, 9.0), true, rng.randf() < 0.4)
		isl.position = o + Vector3(rng.randf_range(-60, 70), rng.randf_range(-40, -24), rng.randf_range(-130, -25))
		add_child(isl)
	for i in 5:
		var cl: String = ["light", "medium", "heavy"][i % 3]
		var col: Color = Data.TEAM_COLORS[(i % (Data.TEAM_COLORS.size() - 1)) + 1]
		var h := Models.hunter(cl, col, Data.CLASSES[cl]["weapon"], "", PlayerLook.random(rng))
		(h.get_node("TeamRing") as Node3D).visible = false
		(h.get_node("Rig/Torso/Glider") as Node3D).visible = true
		h.position = o + Vector3(-4.0 + i * 2.0, 12.0, rng.randf_range(-8, -4))      # spread out, fanning apart
		h.scale *= 1.3
		add_child(h)
		var v := Vector3((i - 2) * 0.3 + rng.randf_range(0.1, 0.5), -2.2, -rng.randf_range(4.5, 6.5))
		h.rotation.y = atan2(-v.x, -v.z)
		gliders.append({"node": h, "anim": HunterAnim.new(h), "vel": v, "start": h.position, "delay": i * 0.7})

## The Wyrm and the paths it flies in its shots.
func _set_wyrm() -> void:
	wyrm = Wyrm.new()
	add_child(wyrm)
	wyrm.set_size(1.8)
	wyrm.visible = false
	# its fire as a stream of small hot flames rather than a few big balls
	wyrm.breath.amount = 260
	wyrm.breath.scale_amount_min = 0.7
	wyrm.breath.scale_amount_max = 1.6
	wyrm.breath.mesh = _blob(0.45, false)
	var W: Vector3 = SETS["whole"]
	# rises out of the clouds behind the Crown, dives low over the towns breathing fire, climbs away
	wyrm_paths["wyrm"] = _curve([W + Vector3(30, -45, -60), W + Vector3(28, -12, -50), W + Vector3(22, 16, -38),
		W + Vector3(8, 10, -8), W + Vector3(-10, 9, 10), W + Vector3(-34, 22, 22), W + Vector3(-70, 40, 30)])
	# a pair of embers far down in the clouds, for the last shot
	var D: Vector3 = SETS["drop"]
	deep_eyes = Node3D.new()
	deep_eyes.position = D + Vector3(-50, -66, -140)
	deep_eyes.scale = Vector3(3, 0.03, 3)
	deep_eyes.visible = false
	add_child(deep_eyes)
	deep_eyes.look_at(D + Vector3(0, 11, -12))      # toward the last shot's camera
	var eye_mat := Models.toon(Color("ff7a1e"), false, 1.5)
	var pupil_mat := Models.toon(Color("1a0806"), false)
	for sx in [-1.0, 1.0]:
		Models.part(deep_eyes, Models.sphere(1.3, 12), eye_mat, Vector3(sx * 2.6, 0, 0), Vector3(1.4, 0.6, 0.3))
		Models.part(deep_eyes, Models.box(0.4, 1.3, 0.1), pupil_mat, Vector3(sx * 2.6, 0, -0.45))

func _curve(pts: Array) -> Curve3D:
	var c := Curve3D.new()
	for i in pts.size():
		var p: Vector3 = pts[i]
		var tin := Vector3.ZERO; var tout := Vector3.ZERO
		if i > 0 and i < pts.size() - 1:
			var tan := ((pts[i + 1] as Vector3) - (pts[i - 1] as Vector3)) * 0.25
			tin = -tan; tout = tan
		c.add_point(p, tin, tout)
	return c

## Flames and a smoke column on a node (a burning house or tower).
func _fire(parent: Node3D, at: Vector3, size := 1.0) -> void:
	var f := CPUParticles3D.new()
	f.amount = 26; f.lifetime = 0.8
	f.position = at
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; f.emission_sphere_radius = 0.5 * size
	f.direction = Vector3.UP; f.spread = 18.0
	f.initial_velocity_min = 1.5 * size; f.initial_velocity_max = 3.5 * size
	f.gravity = Vector3(0, 2.0, 0)
	f.scale_amount_min = 0.6 * size; f.scale_amount_max = 1.3 * size
	var fg := Gradient.new(); fg.set_color(0, Color(1, 0.9, 0.5, 1)); fg.set_color(1, Color(0.8, 0.15, 0.05, 0))
	f.color_ramp = fg
	f.mesh = _blob(0.35, true)
	parent.add_child(f)
	var sm := CPUParticles3D.new()
	sm.amount = 22; sm.lifetime = 4.0
	sm.position = at + Vector3(0, 0.8, 0)
	sm.direction = Vector3(0.25, 1, 0); sm.spread = 12.0
	sm.initial_velocity_min = 2.0; sm.initial_velocity_max = 3.5
	sm.gravity = Vector3(0.6, 0.4, 0)
	sm.scale_amount_min = 1.2 * size; sm.scale_amount_max = 2.6 * size
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.4)); sc.add_point(Vector2(1, 2.2))
	sm.scale_amount_curve = sc
	var sg := Gradient.new(); sg.set_color(0, Color(0.25, 0.2, 0.22, 0.75)); sg.set_color(1, Color(0.35, 0.32, 0.38, 0.0))
	sm.color_ramp = sg
	sm.mesh = _blob(0.6, false)
	parent.add_child(sm)

## Specks drifting in a set's air (the Sundering's dust, the Mask rising): `box` half-extents in m, `radius` the
## speck radius in m, `rise` m/s² up (negative sinks), `glow` adds light instead of covering.
func _drift(at: Vector3, box: Vector3, col: Color, n: int, radius: float, rise: float, glow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = Vector3(0.3, 1, 0.15)
	p.spread = 50.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0.3, rise, 0.1)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.set_color(1, Color(col, 0.0))
	g.add_point(0.3, col)
	g.add_point(0.7, col)
	p.color_ramp = g
	p.mesh = _blob(radius, glow)
	add_child(p)
	return p

func _blob(r: float, glow: bool) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2.0; m.radial_segments = 8; m.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow: mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.material = mat
	return m

## Lights the scene with mood `a`, or k of the way from `a` to `b`.
func _mood(a: String, b := "", k := 0.0) -> void:
	var m: Dictionary = MOODS[a]
	var n: Dictionary = MOODS[b if b != "" else a]
	var sm := env.sky.sky_material as ShaderMaterial
	for i in 3:
		sm.set_shader_parameter(SKY_KEYS[i], (m["sky"][i] as Color).lerp(n["sky"][i], k))
		sea_mat.set_shader_parameter(SEA_KEYS[i], (m["sea"][i] as Color).lerp(n["sea"][i], k))
	sm.set_shader_parameter("sun_col", (m["sun"] as Color).lerp(n["sun"], k))
	sm.set_shader_parameter("stars", lerpf(float(m["stars"]), float(n["stars"]), k))
	env.fog_light_color = (m["fog"] as Color).lerp(n["fog"], k)
	env.ambient_light_color = (m["amb"] as Color).lerp(n["amb"], k)
	sun.light_color = (m["sun"] as Color).lerp(n["sun"], k)
	sun.light_energy = lerpf(float(m["sun_e"]), float(n["sun_e"]), k)

## The land whole burning: k from its golden evening (0) to the red of the Sundering (1).
func _burn(k: float) -> void:
	_mood("gold", "fire", k)

func _wyrm_along(ev: String, k: float) -> void:
	var c: Curve3D = wyrm_paths[ev]
	wyrm.global_position = c.sample_baked(c.get_baked_length() * clampf(k, 0.0, 1.0), true)

# ---------------------------------------------------------------- ui
func _build_ui() -> void:
	# the storybook look over the 3D (ink lines, paint bands, a grade per scene, paper grain)
	var sl := CanvasLayer.new(); sl.layer = 4; add_child(sl)
	var lr := ColorRect.new(); lr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	look_mat = ShaderMaterial.new(); look_mat.shader = load("res://shaders/storybook.gdshader")
	look_mat.set_shader_parameter("tint", Color("ffd27a")); look_mat.set_shader_parameter("tint_amount", 0.22)
	lr.material = look_mat
	sl.add_child(lr)
	ui = CanvasLayer.new(); ui.layer = 5; add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	flash = ColorRect.new(); flash.color = Color(1, 0.95, 0.85, 0.0)      # under the letterbox bars: they stay black
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	# letterbox bars that slide in
	bar_top = ColorRect.new(); bar_top.color = Color(0.02, 0.02, 0.04)
	bar_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); bar_top.offset_bottom = 0.0
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_top)
	bar_bot = ColorRect.new(); bar_bot.color = Color(0.02, 0.02, 0.04)
	bar_bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); bar_bot.offset_top = 0.0
	bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_bot)
	var tw := create_tween().set_parallel()
	tw.tween_property(bar_top, "offset_bottom", 78.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bar_bot, "offset_top", -128.0, 1.2).set_trans(Tween.TRANS_SINE)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.anchor_left = CAPTION_MARGIN
	caption.anchor_right = 1.0 - CAPTION_MARGIN
	caption.offset_left = 0.0
	caption.offset_right = 0.0
	caption.offset_bottom = -12.0
	caption.offset_top = -12.0
	caption.grow_vertical = Control.GROW_DIRECTION_BEGIN      # a long caption wraps and grows upward
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	caption.add_theme_font_override("font", UI.big)
	caption.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.9))
	caption.add_theme_constant_override("outline_size", 6)
	get_viewport().size_changed.connect(_fit_caption)
	_fit_caption()
	caption.add_theme_color_override("font_color", Color("ffe6c8"))
	caption.add_theme_constant_override("line_spacing", 4)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(caption)
	chapter_lbl = Label.new()
	chapter_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	chapter_lbl.offset_top = 26.0; chapter_lbl.offset_bottom = 60.0
	chapter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_lbl.add_theme_font_override("font", UI.big)
	chapter_lbl.add_theme_font_size_override("font_size", 20)
	chapter_lbl.add_theme_color_override("font_color", Color("f2c46a"))
	chapter_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chapter_lbl)
	fade = ColorRect.new(); fade.color = Color(0.02, 0.02, 0.04, 1.0)
	var wm := ShaderMaterial.new(); wm.shader = load("res://shaders/ink_wipe.gdshader")
	fade.material = wm          # scenes change with a ragged ink wipe, not a plain fade
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	# top bar: how far through the story you are, and a hold-to-skip so a stray key never skips it
	var skip := HoldSkip.new()
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -196; skip.offset_right = -24; skip.offset_top = 17; skip.offset_bottom = 61
	skip.skipped.connect(_finish)
	root.add_child(skip)
	pips = HBoxContainer.new()
	pips.add_theme_constant_override("separation", 8)
	pips.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	pips.position = Vector2(30, 33)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pips)
	# bottom corner: how to move on
	var hint := UI.key_hints([["Space", "next"]], 12, Color(1, 1, 1, 0.5))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -24; hint.offset_top = -40; hint.offset_bottom = -16
	root.add_child(hint)

## One dot per scene: done ones filled, the current one long and bright.
func _draw_pips() -> void:
	if not pips:
		return
	for ch in pips.get_children():
		ch.queue_free()
	for i in shots.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(22 if i == shot else 8, 8)
		d.color = UI.ACCENT if i == shot else (Color(1, 0.9, 0.75, 0.7) if i < shot else Color(1, 1, 1, 0.18))
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(d)

func _next_shot() -> void:
	shot += 1
	shot_t = 0.0
	if shot >= shots.size():
		_title_card()
		return
	advancing = false
	var s: Dictionary = shots[shot]
	_enter(String(s.get("event", "")), String(s["mood"]))
	_draw_pips()
	caption.text = String(s["text"])
	caption.modulate.a = 1.0
	caption.visible_ratio = 0.0
	# the chapter name, spaced out, then the line types itself in
	chapter_lbl.text = "  ".join(String(s.get("chapter", "")).split(""))
	chapter_lbl.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(chapter_lbl, "modulate:a", 1.0, 0.8).set_delay(0.3)
	var type_s := maxf(1.2, caption.text.length() * 0.03)
	tw.parallel().tween_property(caption, "visible_ratio", 1.0, type_s).set_delay(0.6)
	if look_mat:
		var gt := create_tween().set_parallel()
		var tint: Color = look_mat.get_shader_parameter("tint")
		var grade := float(look_mat.get_shader_parameter("tint_amount"))
		gt.tween_method(func(c: Color): look_mat.set_shader_parameter("tint", c), tint, s.get("tint", Color("ffd27a")), 1.0)
		gt.tween_method(func(v: float): look_mat.set_shader_parameter("tint_amount", v), grade, float(s.get("grade", 0.25)), 1.0)
	Sfx.play("whoosh", null, -14.0, 0.05, 0.8)

## Sets the stage for a shot behind the wipe: its light, its specks, the Wyrm in or out.
## The caption's text size follows the window's height, so it wraps to a few lines at any size.
func _fit_caption() -> void:
	var px := int(get_viewport().get_visible_rect().size.y / CAPTION_LINES_PER_HEIGHT)
	caption.add_theme_font_size_override("font_size", clampi(px, 15, 40))

func _enter(ev: String, mood: String) -> void:
	_mood(mood)
	wyrm.visible = ev in ["wyrm", "break"]
	match ev:
		"wyrm":
			var c: Curve3D = wyrm_paths["wyrm"]
			wyrm.teleport(c.sample_baked(0.0), c.sample_baked(1.0) - c.sample_baked(0.0))
		"break":
			_burn(0.6)
			dust.visible = true
			dust.restart()

## Fade out and on to the next shot.
func _advance() -> void:
	if done or advancing or shot >= shots.size():
		return
	advancing = true      # don't trigger twice; the camera keeps gliding while it fades
	var tw := create_tween()
	tw.tween_property(caption, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(chapter_lbl, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(fade, "color:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_next_shot)

func _title_card() -> void:
	caption.text = ""
	chapter_lbl.text = ""
	card = Control.new(); card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.get_child(0).add_child(card)
	var col := VBoxContainer.new(); col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	# the brand wordmark (art/brand/logo_wordmark.png); no subtitle (OWNER_REVIEW item 156)
	var big := TextureRect.new()
	big.texture = load("res://art/brand/logo_wordmark.png")
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big.custom_minimum_size = Vector2(800, 390)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(big)
	card.modulate.a = 0.0
	big.pivot_offset = Vector2(400, 195)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.75, 0.6)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 1.0)
	Sfx.play("bond", null, -4.0, 0.0, 0.9)
	tw.tween_interval(2.6)
	tw.tween_callback(_finish)

func _finish() -> void:
	if done:
		return
	done = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func():
		finished.emit()
		Save.d["tutorial"]["prologue"] = true
		# the hatch screen still tells its own three lines: the storm, the shrine, the eggs
		Game.goto(then_go))

func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	# Esc is held to skip (see HoldSkip); Space or a click moves on to the next scene
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event.is_action_pressed("jump") or click:
		if shot < shots.size() and shot_t > 0.8 and not advancing:
			_advance()

# ---------------------------------------------------------------- the show
func _process(delta: float) -> void:
	t += delta
	shot_t += delta
	if look_mat:
		look_mat.set_shader_parameter("time_s", t)
	if shot >= 0 and shot < shots.size():
		var s: Dictionary = shots[shot]
		_camera(s["cam"], delta)
		_events(String(s.get("event", "")), shot_t, delta)
		if shot_t >= float(s["dur"]) and not advancing:
			_advance()
	for d in debris.duplicate():
		var n: Node3D = d["node"]
		d["vel"] += Vector3(0, -9.0, 0) * delta
		n.position += (d["vel"] as Vector3) * delta
		n.rotation += (d["spin"] as Vector3) * delta
		if n.position.y < -90.0:
			n.queue_free()
			debris.erase(d)
	flash.color.a = maxf(0.0, flash.color.a - delta * 1.6)

## Places the camera on the move playing now (past the last one it keeps creeping while the wipe covers it),
## with a slow breathing sway like a held camera, and a faint rumble.
func _camera(moves: Array, delta: float) -> void:
	var i := 0
	var into := shot_t
	while i < moves.size() - 1 and into >= float(moves[i][4]):
		into -= float(moves[i][4])
		i += 1
	var mv: Array = moves[i]
	var e := _glide(into / float(mv[4]))
	var pos: Vector3 = (mv[0] as Vector3).lerp(mv[2], e)
	var look: Vector3 = (mv[1] as Vector3).lerp(mv[3], e)
	var sway := Vector3(sin(t * 0.83) + 0.5 * sin(t * 1.9), 0.6 * sin(t * 1.21 + 2.0), 0.0)
	look += sway * pos.distance_to(look) * 0.003
	if rumble > 0.0:
		# a slow low sway, not a shake: tiny, and scaled by the Screen shake setting (0 = still)
		var amp := rumble * RUMBLE_AMP * float(Settings.get_v("screen_shake"))
		pos += Vector3(sin(t * 9.0), 0.6 * sin(t * 7.0 + 1.0), 0.0) * amp
		rumble = maxf(0.0, rumble - delta * 1.2)
	cam.position = pos
	cam.look_at(look, Vector3.UP)

## How far along a move the camera is at k (0..1 of its time): eased in and out, but never to a dead stop,
## and still creeping past the end.
static func _glide(k: float) -> float:
	if k > 1.0:
		return 1.0 + (k - 1.0) * END_CREEP
	return lerpf(k, k * k * (3.0 - 2.0 * k), 1.0 - END_CREEP)

func _events(ev: String, st: float, delta: float) -> void:
	match ev:
		"wyrm":
			_waking(st, delta)
		"break":
			_sundering(st, delta)
		"kin":
			boki.play(st, delta)
		"drop":
			_race(st, delta)

## The Wyrm rises behind the Crown, roars (the sky reddens, the frame rumbles) and sweeps the towns with fire.
func _waking(st: float, delta: float) -> void:
	var dur: float = shots[shot]["dur"]
	_wyrm_along("wyrm", st / (dur + 0.6))
	if st > 2.4 and not wyrm.has_meta("roared"):
		wyrm.set_meta("roared", true)
		wyrm.roar()
		rumble = 0.9
		Sfx.play("v_warden", null, 2.0, 0.0, 0.55)
		Sfx.play("boom", null, -6.0, 0.0, 0.35)
		create_tween().tween_method(_burn, 0.0, 0.6, 2.5)
	wyrm.breath.emitting = st > 3.3 and st < 5.8
	if wyrm.breath.emitting and burning < towns.size() and randf() < delta * 6.0:
		var tn: Array = towns[burning]
		_fire(tn[0], tn[1], 1.3)
		burning += 1
		rumble = maxf(rumble, 0.25)
		Sfx.play("boom", null, -14.0, 0.1, 1.4)

## The Wyrm circles while the land splits: a flash and a jolt, the isles drift apart and sink, rocks tumble.
func _sundering(st: float, delta: float) -> void:
	wyrm.breath.emitting = false
	var ang := 5.3 - st * 0.42      # rad: from the far side of the land, round away from both camera moves
	var W: Vector3 = SETS["whole"]
	wyrm.global_position = W + Vector3(cos(ang) * 26.0, 8.0 + sin(st * 0.8) * 2.0, sin(ang) * 26.0)
	if burning < towns.size():
		for i in range(burning, towns.size()):
			_fire(towns[i][0], towns[i][1], 1.2)
		burning = towns.size()
	if st > 1.4 and randf() < delta * 16.0 and debris.size() < 80:
		_rock()
	if st > 1.4 and not broke:
		broke = true
		flash.color.a = 0.85
		rumble = 1.4
		Sfx.play("boom", null, 0.0, 0.0, 0.6)
		Sfx.play("boom", null, -4.0, 0.0, 0.45)
		Sfx.play("v_warden", null, 0.0, 0.0, 0.5)
		create_tween().tween_method(_burn, 0.6, 1.0, 1.5)
	if st > MANTLES_AT and not dust.has_meta("scattered"):
		dust.set_meta("scattered", true)
		_scatter_mantles()
	if broke:
		# the pieces drift apart, tilt and sink into the clouds
		var k := clampf((st - 1.4) / 6.0, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 2.0)
		for p in pieces:
			var n: Node3D = p["node"]
			var sink := Vector3(0, -float(p["fall"]) * k * k, 0)
			n.position = (p["base"] as Vector3) + (p["dir"] as Vector3) * float(p["drift"]) * e + sink
			n.rotation.z = float(p["spin"]) * e
			n.rotation.x = float(p["spin"]) * 0.6 * e
		if randf() < delta * 3.0 and st < 6.0:
			flash.color.a = maxf(flash.color.a, 0.3)
			rumble = maxf(rumble, 0.35)

## The fallen Hunters' selves scattering as Masks: a light of each Mask's colour bursts out of the Crown and
## flies off over the breaking isles.
func _scatter_mantles() -> void:
	var from: Vector3 = (pieces[0]["node"] as Node3D).position + Vector3(0, 10, 0)
	var ids := Arch.ids()
	for i in ids.size():
		var a := float(i) / ids.size() * TAU + rng.randf_range(-0.2, 0.2)
		var reach := rng.randf_range(28, 42)
		var to := from + Vector3(cos(a) * reach, rng.randf_range(-8, 2), sin(a) * reach)
		var col := Arch.color(String(ids[i]))
		var orb := Models.part(self, Models.sphere(1.3, 12), Models.toon(col, false, 0.5), from)
		var tw := create_tween()
		tw.tween_property(orb, "position", to, 3.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(orb, "scale", Vector3.ONE * 0.4, 3.2)
	Sfx.play("ult", null, -6.0, 0.0, 0.7)

## A rock breaking off an isle's edge and tumbling away; one in three falls close past the camera.
func _rock() -> void:
	var at: Vector3
	if rng.randf() < 0.33:
		var ahead := cam.global_position - cam.global_basis.z * rng.randf_range(9.0, 18.0)
		at = ahead + cam.global_basis.x * rng.randf_range(-7, 7) + Vector3(0, 7, 0)
	else:
		var p: Dictionary = pieces[rng.randi_range(0, pieces.size() - 1)]
		at = (p["node"] as Node3D).position + Vector3(rng.randf_range(-9, 9), rng.randf_range(-3, 1), rng.randf_range(-9, 9))
	var dims := Vector3(rng.randf_range(0.5, 1.6), rng.randf_range(0.5, 1.4), rng.randf_range(0.5, 1.6))
	var rock := Models.part(self, Models.box(dims.x, dims.y, dims.z), Models.toon(Color("6b5246")), at)
	var vel := Vector3(rng.randf_range(-3, 3), rng.randf_range(-1, 3), rng.randf_range(-3, 3))
	var spin := Vector3(rng.randf_range(-3, 3), rng.randf_range(-3, 3), rng.randf_range(-3, 3))
	debris.append({"node": rock, "vel": vel, "spin": spin})

## Gliders dive toward the Heart's glow; at the end two embers open far down in the clouds.
func _race(st: float, delta: float) -> void:
	heart_light.light_energy = 2.0 + 0.6 * sin(st * 2.2)
	deep_eyes.visible = st > 5.2
	deep_eyes.scale.y = lerpf(deep_eyes.scale.y, 3.0 if st > 5.4 else 0.03, minf(1.0, delta * 3.0))
	for g in gliders:
		var tt: float = st - float(g["delay"])
		var h: Node3D = g["node"]
		h.visible = tt >= 0.0
		if tt < 0.0:
			continue
		h.position = (g["start"] as Vector3) + (g["vel"] as Vector3) * tt
		(g["anim"] as HunterAnim).update(delta, {"gliding": true, "grounded": false, "vel": g["vel"], "face": h.rotation.y})
