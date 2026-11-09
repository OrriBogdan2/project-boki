extends Node3D
## Title screen: key art you can stand in. A squad of six hunters, one of each archetype, waits on
## the broken edge of a floating island at dusk while an ash storm blows through the Skylands. Their
## Boki are with them; the lead hunter's looks up at them. Far off, behind the fog and the light
## shafts, the Wyrm turns slowly through the clouds. Embers and ash ride the wind, a glider streaks
## past now and then, and the whole scene shifts a little with the mouse (parallax).
##
## Everything is built in code from the game's own models. Detail follows the quality preset
## (Settings.q): Low drops the light shafts, most cloud banks, the far islands and most particles.
##
## Tooling: --title-cam=x,y,z,lx,ly,lz tries a framing, --title-t=<seconds> starts the animation
## part-way through (screenshots of later moments), --title-check runs tools/title_check.gd.

var cam: Camera3D
var t := 0.0
var rng := RandomNumberGenerator.new()
var low := false                 # the Low preset: the cheapest version of the scene
var fx_k := 1.0                  # particle amounts (Settings "fx")
var squad: Array = []            # {node, anim, face, st}  (st: the HunterAnim state to hold)
var boki: Array = []             # {node, base_y, kind}
var lead: Node3D
var lead_boki: Node3D
var glider: Dictionary = {}      # {node, anim, t, dur, a, b}
var glide_wait := 2.5
var wyrm: Wyrm
var shafts: Array = []           # [mesh, material, base intensity, phase]
var clouds: Array = []           # {node, speed}
var isles: Array = []            # [node, base y, phase]
var flag: Node3D
var embers: CPUParticles3D
var ash: CPUParticles3D
var mouse_k := Vector2.ZERO      # smoothed mouse position, -1..1 on both axes (parallax)
var cam_override: Array = []     # tooling: --title-cam=x,y,z,lx,ly,lz to try framings
var logo: Control
var menu_col: VBoxContainer
var stung := false

const LANDMARKS := preload("res://scripts/match/landmarks.gd")
const SUN := Vector3(0.78, 0.17, -0.6)            # toward the low sun: behind the squad, off to the right
const ISLE := Vector3(2.4, 0.0, -6.8)              # the island the squad stands on
const ISLE_R := 7.4
const CAM_AT := Vector3(-0.9, 1.9, -0.9)
const CAM_LOOK := Vector3(1.25, 1.95, -9.4)
const WIND := Vector3(2.2, 0.15, 0.35)            # the storm blows left to right
## Each archetype's weapon on the title (the arch_gallery set).
const DISCORD := "https://discord.gg/nbeBaU7xt"        # the playtest server (never expires)
const WEAPONS := {"thief": "arc_bolts", "archer": "longbow", "mage": "coilcaster", "gunslinger": "quill_rifle", "juggernaut": "greatsword", "bulwark": "tower_shield", "dredge": "shotgun", "ashwick": "flamethrower", "tender": "lantern_crook", "rimewright": "hoar_fan", "dolm": "rubble_fists", "ostra": "tether_lantern"}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_music("title")
	Feedback.flush(self)                # a rating that could not be sent last time
	Sfx.play_ambience("title")          # its own slow drone, not the match wind
	rng.seed = 2026
	low = Settings.quality() == "low"
	fx_k = float(Settings.q("fx"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--title-cam="):
			cam_override = Array(a.substr(12).split(",")).map(func(x): return float(x))
		elif a.begins_with("--title-t="):
			t = float(a.substr(10))
	_sky()        # the painted splashes (TitleBackdrop) cover the screen, so the 3D island, squad and sky props are off
	cam = Camera3D.new(); cam.fov = 36.0; cam.far = 1600.0
	add_child(cam)
	cam.make_current()
	_place_cam(0.0)
	_build_ui()

# ---------------------------------------------------------------- light, sky and haze
func _sky() -> void:
	var env := WorldEnvironment.new()
	# dusk through an ash storm: a bruised sky with an ember-orange band low down, a dusty mauve haze
	# that swallows everything far away (saturation down; colour stays in the embers and the Boki)
	env.environment = Look.environment({"top": Color("16171f"), "mid": Color("3c3540"), "horizon": Color("c9714a"), "below": Color("231e26"),
		"sun_dir": SUN.normalized(), "sun_col": Color("ffb27a"), "ambient": Color("a6a0b4"), "ambient_energy": 0.55,
		"fog": Color("4f4046"), "fog_density": 0.0075 if not low else 0.0095, "fog_height": -14.0, "fog_height_density": 0.05,
		"stars": 0.08, "saturation": 0.86, "contrast": 1.1, "exposure": 1.0})
	var e := env.environment
	e.fog_sun_scatter = 0.08
	add_child(env)
	# the low sun behind them rims the squad; a cool fill from the front keeps faces readable
	var sun := Look.lights(self, Color("ffc79a"), 1.15, Vector3(-20, 128, 0), 40.0)
	sun.shadow_opacity = 0.6
	var fill: DirectionalLight3D = get_node("Fill")
	fill.light_energy = 0.42
	fill.light_color = Color("8f9cc8")
	# the sea of cloud far below, dull and storm-dark
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(3000, 3000)
	sea.mesh = pm
	var cm := ShaderMaterial.new(); cm.shader = load("res://shaders/clouds.gdshader")
	cm.set_shader_parameter("deep", Color("1c1820")); cm.set_shader_parameter("light", Color("5a4a50"))
	cm.set_shader_parameter("glow", Color("e08050")); cm.set_shader_parameter("glow_amount", 0.5)
	cm.set_shader_parameter("sun_xz", Vector2(SUN.x, SUN.z)); cm.set_shader_parameter("scale", 0.01)
	sea.material_override = cm
	sea.position = Vector3(0, -70.0, 0)
	add_child(sea)

# ---------------------------------------------------------------- the island they stand on
func _hero_isle() -> void:
	var rr := RandomNumberGenerator.new(); rr.seed = 7
	var isl := Models.float_island(rr, ISLE_R, 18.0, Color("5b6346"), Color("6a5a4e"), Color("231e28"))
	isl.position = ISLE
	add_child(isl)
	# windswept grass, dull olive, thinner on Low
	_grass(isl, rr, int((900 if not low else 320) * float(Settings.q("grass"))), ISLE_R * 0.86)
	# rocks along the broken edge, and a fallen pillar of the old world
	var rocks := [[Vector3(-3.6, 0, -4.0), 1.5], [Vector3(4.6, 0, -2.4), 1.2], [Vector3(-5.2, 0, 0.6), 1.0], [Vector3(1.3, -0.15, -5.1), 0.85],
		[Vector3(5.6, 0, 1.8), 1.4], [Vector3(-1.2, 0, 4.6), 0.8], [Vector3(3.4, 0, 4.4), 1.1]]
	for i in rocks.size():
		var rk := Flora.node("rock", "storm", i % 3, float(rocks[i][1]))
		rk.position = ISLE + (rocks[i][0] as Vector3)
		rk.rotation.y = rr.randf() * TAU
		add_child(rk)
	var pil := Flora.node("pillar", "storm", 1, 1.25)
	pil.position = ISLE + Vector3(-4.6, -0.2, -2.0)
	pil.rotation = Vector3(0.0, 0.6, 0.2)
	add_child(pil)
	var pil2 := Flora.node("pillar", "storm", 2, 1.0)
	pil2.position = ISLE + Vector3(5.2, -0.3, -1.0)
	pil2.rotation = Vector3(1.35, 1.9, 0.0)          # fallen over
	add_child(pil2)
	# a torn banner on a pole, whipping in the wind
	var pole := Models.part(self, Models.cyl(0.05, 0.07, 3.6, 8), Models.toon(Color("3e3330")), Vector3(5.6, 1.8, -11.6))
	pole.rotation.z = 0.08
	flag = Node3D.new(); flag.position = Vector3(5.68, 3.45, -11.6); add_child(flag)
	var cloth := Models.toon(Color("8a3b2e"))
	for k in 4:
		var seg := Models.part(flag, Models.box(0.42, 0.95 - k * 0.12, 0.03), cloth, Vector3(0.21 + k * 0.4, -0.45 + k * 0.03, 0))
		seg.name = "Seg%d" % k

func _grass(isl: MeshInstance3D, rr: RandomNumberGenerator, n: int, reach: float) -> void:
	var rim: Array = isl.get_meta("rim")
	var rmin := 1e9
	for p in rim: rmin = minf(rmin, (p as Vector2).length())
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = Models.grass_mesh(false)
	mm.instance_count = n
	for k in n:
		var a := rr.randf() * TAU
		var d := sqrt(rr.randf()) * minf(rmin * 0.95, reach)
		var at := ISLE + Vector3(cos(a) * d, 0.0, sin(a) * d)
		if Vector2(at.x - CAM_AT.x, at.z - CAM_AT.z).length() < 3.2:
			continue          # nothing right in front of the lens
		var sc := rr.randf_range(0.8, 1.5)
		# blades lean downwind
		var b := Basis(Vector3.UP, rr.randf() * TAU).scaled(Vector3.ONE * sc)
		b = Basis(Vector3.FORWARD, -0.25) * b
		mm.set_instance_transform(k, Transform3D(b, at))
		mm.set_instance_color(k, Color("6e7448").lerp(Color("44482e"), rr.randf()))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm
	mi.material_override = Models.grass_material(0.35)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ---------------------------------------------------------------- the squad and their Boki
## The six archetypes, the player's own in front. Slots: [pos on the island, facing, pose].
func _squad() -> void:
	var my_arch := Arch.of_save()         # your archetype (main: Arch), whatever your look says
	var order: Array = [my_arch]
	for a in ["juggernaut", "archer", "mage", "bulwark", "thief", "gunslinger"]:
		if not order.has(a): order.append(a)
	order = order.slice(0, 6)         # (the squad has six places; a newer archetype of yours takes the first)
	var to_cam := func(p: Vector3, off := 0.0) -> float:
		var d := CAM_AT - p
		return atan2(-d.x, -d.z) + off
	var out_yaw := atan2(-SUN.x, -SUN.z)        # looking out toward the light (and the Wyrm)
	# [x, z, yaw, pose, y]
	# laid out in screen terms: you and your Boki in front with open sky behind you, the others
	# spread to either side and back toward the edge, so nobody hides anybody
	# (placed from where they land on screen, about a fifth of the screen apart, nearer ones lower:
	# you front and centre, a light one at mid depth, the big heavies further back so they don't
	# wall the shot off, the archer up on a rock at the back)
	var slots: Array = [
		[0.9, -7.25, 0.0, "lead", 0.0],                                       # turned to its Boki (set in _boki)
		[5.0, -12.2, out_yaw + 0.3, "watch", 0.0],                            # back to us, facing the storm
		[3.7, -11.9, out_yaw - 0.15, "point", 0.5],                           # up on a rock, pointing at it
		[0.54, -11.68, out_yaw - 0.6, "watch", 0.0],
		[6.2, -11.0, to_cam.call(Vector3(6.2, 0, -11.0), -0.55), "ready", 0.0],
		[2.51, -8.91, to_cam.call(Vector3(2.51, 0, -8.91), 0.8), "crouch", 0.0],
	]
	var looks: Array = [
		{"race": 3, "hair": 0, "hair_v": 2, "hair_col": 0, "skin": 2, "gender": 0, "face": 4, "body": 1, "outfit": 1},
		{"race": 0, "hair": 1, "hair_v": 2, "hair_col": 5, "skin": 1, "gender": 1, "face": 0, "body": 2, "outfit": 2},
		{"race": 5, "hair": 2, "hair_v": 2, "hair_col": 3, "skin": 3, "gender": 0, "face": 6, "body": 1, "outfit": 3},
		{"race": 1, "hair": 3, "hair_v": 2, "hair_col": 6, "skin": 2, "gender": 1, "face": 8, "body": 1, "outfit": 4},
		{"race": 2, "hair": 0, "hair_v": 2, "hair_col": 10, "skin": 0, "gender": 0, "face": 7, "body": 2, "outfit": 7},
		{"race": 4, "hair": 1, "hair_v": 2, "hair_col": 7, "skin": 4, "gender": 1, "face": 3, "body": 0, "outfit": 6},
	]
	for i in order.size():
		var arch: String = order[i]
		var cls := String(HeroKit.ARCHES[arch]["cls"])
		var lk: Dictionary = looks[i]
		var weapon := String(WEAPONS[arch])
		if i == 0 and Save.d.has("look"):
			lk = Unmasked.mask_look()          # you lead the squad, as a Warden
			weapon = Arch.weapon_for(Arch.of_save(), Data.class_of_save(), String(Save.d.get("weapon", "")))
			cls = Data.class_of_save()
		var h := Models.hunter(cls, Data.TEAM_COLORS[0], weapon, "", lk, arch)
		var sl: Array = slots[i]
		var ring := h.get_node_or_null("TeamRing") as Node3D
		if ring: ring.visible = false
		h.position = ISLE + Vector3(float(sl[0]) - ISLE.x, float(sl[4]), float(sl[1]) - ISLE.z)
		h.rotation.y = float(sl[2])
		add_child(h)
		var st := {"face": h.rotation.y, "fired": 99.0, "grounded": true}
		match String(sl[3]):
			"point": st["emote"] = "here"; st["emote_t"] = 1.0
			"crouch": st["crouch"] = 1.0
		squad.append({"node": h, "anim": HunterAnim.new(h), "st": st})
		if i == 0: lead = h
	_boki()

## Each hunter's Boki: the lead's own (your partner, if you have one) at their feet looking up at
## them, the rest close to their hunters.
func _boki() -> void:
	var recs: Array = []
	var ak := Save.active_kin()
	recs.append(ak if not ak.is_empty() else {"species": "cindle", "level": 5})
	for sp in ["pebbit", "hivara", "zephyrak", "puddlet", "burrlet"]:
		recs.append({"species": sp, "level": 5})
	for i in mini(recs.size(), squad.size()):
		var spid := String(recs[i]["species"])
		if not Data.KIN.has(spid): continue
		var k := Models.kin(spid, recs[i])
		var h: Node3D = squad[i]["node"]
		var at := h.position
		var kind := String(KinPuppet.BODY.get(spid, "blob"))
		match i:
			0:
				# beside its hunter, seen side-on, turned to them with its nose up: it's looking at
				# them, and they've turned to look down at it
				var cr := Vector3(CAM_LOOK.z - CAM_AT.z, 0, CAM_AT.x - CAM_LOOK.x).normalized() * -1.0
				var tc := Vector3(CAM_AT.x - at.x, 0, CAM_AT.z - at.z).normalized()
				at += cr * 0.85 - tc * 0.25
				# three-quarters to us, half turned to its hunter: its face reads, and it's plainly
				# looking at them (side-on, a long low Boki seen from above read as lying down)
				var mid := Vector3(h.position.x, at.y, h.position.z).lerp(Vector3(CAM_AT.x, at.y, CAM_AT.z), 0.55)
				k.look_at_from_position(at, mid, Vector3.UP)
				var to_k := at - h.position
				h.rotation.y = atan2(-to_k.x, -to_k.z) - 0.35
				squad[0]["st"]["face"] = h.rotation.y
				lead_boki = k
			2:
				at += Vector3(0.8, 1.7, 0.4)       # the flyer hovers by the one on the rock
				k.rotation.y = h.rotation.y
			3:
				at += Vector3(-0.7, 1.3, 0.6)      # the sky serpent coils in the air beside the mage
				k.rotation.y = h.rotation.y + 0.8
			_:
				var side := Vector3(cos(h.rotation.y), 0, -sin(h.rotation.y))
				at += side * (0.75 if i % 2 == 0 else -0.75) + Vector3(0, 0, 0.25)
				k.rotation.y = h.rotation.y + (0.4 if i % 2 == 0 else -0.4)
		k.position = at
		if i == 0:
			k.scale *= 1.1
		add_child(k)
		var aura: CPUParticles3D = k.get_node_or_null("Aura")
		if aura: aura.emitting = not low
		boki.append({"node": k, "base_y": at.y, "kind": kind})

# ---------------------------------------------------------------- the broken Skylands beyond
func _skylands() -> void:
	var rr := RandomNumberGenerator.new(); rr.seed = 31
	# [position, radius, ruin]: near ones still green under the ash, far ones only silhouettes
	var spots: Array = [[Vector3(-26, -9, -46), 7.0, "arch"], [Vector3(30, -14, -58), 9.0, ""], [Vector3(-8, -20, -80), 6.0, ""],
		[Vector3(58, -6, -96), 12.0, "statue"], [Vector3(-60, -4, -110), 14.0, ""], [Vector3(14, -26, -130), 8.0, ""],
		[Vector3(-30, -16, -170), 16.0, "spire"], [Vector3(96, -18, -190), 18.0, ""], [Vector3(40, -30, -240), 22.0, ""],
		[Vector3(-110, -24, -230), 20.0, ""], [Vector3(150, -10, -150), 12.0, ""]]
	if low:
		spots = spots.slice(0, 6)
	for sp in spots:
		var r: float = sp[1]
		var isl := Models.float_island(rr, r, r * rr.randf_range(1.6, 2.4), Color("4e5640"), Color("5a4c46"), Color("1e1a22"))
		var root := Node3D.new()
		root.position = sp[0]
		root.rotation.y = rr.randf() * TAU
		root.add_child(isl)
		add_child(root)
		# shards that broke away in the Hollowing drift underneath
		for k in (3 if not low else 1):
			var sh := Flora.node("rock", "storm", k % 3, r * rr.randf_range(0.18, 0.32))
			sh.position = Vector3(rr.randf_range(-r, r), -r * rr.randf_range(0.8, 1.8), rr.randf_range(-r, r))
			sh.rotation = Vector3(PI, rr.randf() * TAU, rr.randf_range(-0.4, 0.4))
			root.add_child(sh)
		var ruin := String(sp[2])
		if ruin != "":
			var mi := MeshInstance3D.new()
			mi.mesh = LANDMARKS.mesh(ruin, "storm")
			mi.material_override = Flora.material("rock", true)
			mi.scale = Vector3.ONE * r * 0.13
			root.add_child(mi)
		elif r < 13.0:
			for k in rr.randi_range(1, 3):
				var tr := Flora.node("pine", "storm", k % 3, rr.randf_range(1.0, 1.6))
				var a := rr.randf() * TAU
				tr.position = Vector3(cos(a), 0, sin(a)) * r * rr.randf_range(0.1, 0.6)
				root.add_child(tr)
		isles.append([root, float((sp[0] as Vector3).y), rr.randf() * TAU])

## Long soft shafts of the low sun slanting through the storm.
func _shafts() -> void:
	var sh: Shader = load("res://shaders/light_shaft.gdshader")
	var axis := -SUN.normalized()
	for i in 6:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new(); q.size = Vector2(1, 1); q.center_offset = Vector3(0, 0.5, 0)
		mi.mesh = q
		var m := ShaderMaterial.new(); m.shader = sh
		m.set_shader_parameter("seed", rng.randf() * 10.0)
		m.set_shader_parameter("intensity", rng.randf_range(0.28, 0.5))
		m.set_shader_parameter("color", Color("ffb98a").lerp(Color("ffd8b0"), rng.randf()))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var at := Vector3(rng.randf_range(20.0, 120.0), rng.randf_range(10.0, 50.0), rng.randf_range(-260.0, -140.0))
		mi.basis = Basis(Quaternion(Vector3.UP, axis)) * Basis.from_scale(Vector3(rng.randf_range(8.0, 20.0), rng.randf_range(160.0, 260.0), 1.0))
		mi.position = at
		mi.extra_cull_margin = 300.0
		add_child(mi)
		shafts.append([mi, m, float(m.get_shader_parameter("intensity")), rng.randf() * TAU])

## Banks of storm cloud drifting through the gaps between the islands.
func _cloud_banks() -> void:
	var sh: Shader = load("res://shaders/cloud_puff.gdshader")
	var n: int = [5, 10, 16][clampi(int(Settings.q("clouds")), 0, 2)]
	for i in n:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new(); var s := rng.randf_range(18.0, 46.0); q.size = Vector2(s * 1.8, s)
		mi.mesh = q
		var m := ShaderMaterial.new(); m.shader = sh
		m.set_shader_parameter("seed", rng.randf() * 10.0)
		m.set_shader_parameter("alpha", rng.randf_range(0.35, 0.65))
		m.set_shader_parameter("lit", Color("d49a7c"))
		m.set_shader_parameter("shade", Color("3e3440"))
		m.set_shader_parameter("sun_side", Vector2(0.8, 0.3))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(rng.randf_range(-160, 200), rng.randf_range(-40, 12), rng.randf_range(-260, -40))
		add_child(mi)
		clouds.append({"node": mi, "speed": rng.randf_range(1.5, 3.5)})

## The Wyrm, far off: a dark shape turning slowly through the haze, wings beating, eyes like coals.
func _wyrm() -> void:
	wyrm = Wyrm.new()
	add_child(wyrm)
	wyrm.set_size(3.4)
	wyrm.flap_rate = 0.45
	wyrm.teleport(_wyrm_at(t), _wyrm_at(t + 0.5) - _wyrm_at(t))

func _wyrm_at(tt: float) -> Vector3:
	var a := tt * 0.045
	return Vector3(46.0 + cos(a) * 40.0, 22.0 + sin(a * 2.0) * 3.0, -235.0 + sin(a) * 22.0)     # far off: a silhouette in the haze

## Embers and ash on the wind, around the squad and in front of the camera.
func _weather() -> void:
	embers = _particles(int(140 * fx_k), Color("ffa24a"), Color("ff5a1e"), 0.035, 0.07, 6.0, Vector3(9, 4, 7), Vector3(0.3, 0.9, 0.2))
	ash = _particles(int(220 * fx_k), Color(0.75, 0.72, 0.72, 0.55), Color(0.55, 0.52, 0.55, 0.35), 0.03, 0.07, 7.0, Vector3(11, 5, 8), Vector3(0, -0.25, 0))

func _particles(n: int, c0: Color, c1: Color, s0: float, s1: float, life: float, box: Vector3, lift: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(n, 8)
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.position = Vector3(1.0, 2.2, -7.0)
	p.direction = (WIND + lift).normalized()
	p.spread = 25.0
	p.initial_velocity_min = WIND.length() * 0.7
	p.initial_velocity_max = WIND.length() * 1.3
	p.gravity = lift
	p.scale_amount_min = s0 / 0.05
	p.scale_amount_max = s1 / 0.05
	var q := QuadMesh.new(); q.size = Vector2(0.05, 0.05)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if c0.r > 0.9:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD        # embers glow
		m.disable_fog = true
	p.material_override = m
	var g := Gradient.new()
	g.set_color(0, Color(c0, 0.0)); g.set_color(1, Color(c1, 0.0))
	g.add_point(0.15, c0); g.add_point(0.7, c1)
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

## A hunter glides past on the wind every few seconds (one, re-launched: no hitches).
func _glider() -> void:
	var lk := PlayerLook.random(rng)
	var h := Models.hunter("light", Data.TEAM_COLORS[2], "smg", "", lk, "archer")
	var ring := h.get_node_or_null("TeamRing") as Node3D
	if ring: ring.visible = false
	var gl := h.get_node_or_null("Rig/Torso/Glider") as Node3D
	if gl:
		gl.visible = true
		gl.rotation.x = 0.25
	h.visible = false
	add_child(h)
	glider = {"node": h, "anim": HunterAnim.new(h), "t": -1.0, "dur": 6.5, "a": Vector3.ZERO, "b": Vector3.ZERO}

func _launch_glider() -> void:
	# across the sky behind the squad, from the left, riding the storm; near or far each time
	var near := rng.randf() < 0.5
	var z := rng.randf_range(-24.0, -18.0) if near else rng.randf_range(-48.0, -34.0)
	var y := rng.randf_range(4.0, 7.5) if near else rng.randf_range(8.0, 14.0)
	# out of the haze behind the squad, coming toward us and passing over to the left, so the wing
	# shows its full span
	glider["a"] = Vector3(rng.randf_range(20.0, 34.0), y + 6.0, z - 40.0)
	glider["b"] = Vector3(rng.randf_range(-16.0, -8.0), y - rng.randf_range(1.0, 3.0), z + 14.0)
	glider["dur"] = rng.randf_range(5.0, 7.0) if near else rng.randf_range(8.0, 10.0)
	glider["t"] = 0.0
	var h: Node3D = glider["node"]
	h.visible = true
	var d: Vector3 = (glider["b"] as Vector3) - (glider["a"] as Vector3)
	h.rotation.y = atan2(-d.x, -d.z)
	h.scale = Vector3.ONE * 1.3
	if near: Sfx.play("whoosh", null, -16.0, 0.05, 0.8)

# ---------------------------------------------------------------- the menu
func _build_ui() -> void:
	var ui := CanvasLayer.new(); add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.name = "TitleUI"
	ui.add_child(root)
	root.add_child(TitleBackdrop.new())
	# a dark wash on the left so the menu reads over the scene, and a vignette with a little
	# letterbox weight top and bottom
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.03, 0.03, 0.05, 0.86)); gr.set_color(1, Color(0.03, 0.03, 0.05, 0.0))
	gr.set_offset(0, 0.25); gr.set_offset(1, 1.0)
	gt.gradient = gr; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(1, 0); gt.width = 256; gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 760
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var vig := TextureRect.new()
	var vt := GradientTexture2D.new(); var vg := Gradient.new()
	vg.set_color(0, Color(0, 0, 0, 0.0)); vg.set_color(1, Color(0.02, 0.015, 0.03, 0.62)); vg.set_offset(0, 0.5); vg.set_offset(1, 1.0)
	vt.gradient = vg; vt.fill = GradientTexture2D.FILL_RADIAL; vt.fill_from = Vector2(0.55, 0.45); vt.fill_to = Vector2(1.1, 1.1); vt.width = 128; vt.height = 128
	vig.texture = vt; vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vig)
	# the menu column stays vertically centred and fits any window height
	var col := VBoxContainer.new()
	col.name = "Menu"
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 76; col.offset_right = 600; col.offset_top = 24; col.offset_bottom = -60
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	root.add_child(col)
	menu_col = col
	# the brand wordmark (art/brand/logo_wordmark.png, owner-approved Nov 5); TitleLogo below is the old drawn one
	var lt := TextureRect.new()
	lt.texture = load("res://art/brand/logo_wordmark.png")
	lt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	lt.custom_minimum_size = Vector2(500, 244)
	lt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo = lt
	logo.name = "Logo"
	col.add_child(logo)
	# no tagline under the logo
	var has: bool = not Save.d["roster"].is_empty()
	col.add_child(UI.spacer(12 if has else 30))     # (with a save the menu has one more row: Demo match)
	# the one big button: carry on where you left off, or start a new story
	var b1 := _menu_main(("Continue" if has else "New game"), func(): Game.goto("home" if has else "prologue"))
	col.add_child(b1)
	# no subtext under the main button
	col.add_child(UI.spacer(6 if has else 18))
	var items: Array = []
	# the Arena: every archetype's kit against dummies and a sparring bot, no save needed
	items.append(["Arena", func(): Game.start_match(Match.arena_opts()), "knock"])
	if has:
		# one click to a match made for filming: Duos with a bot squadmate who leads the drop to a boss lair
		# next to an uplink, clear weather, no Blight, the usual rivals (Match.demo_opts)
		items.append(["Demo match", func(): Game.start_match(Match.demo_opts()), "updraft"])
	if Net.available():
		items.append(["Play with friends", func(): Game.goto("lobby", {}), "bond"])
	items.append(["Save files", func(): Overlay.ctx = "title"; Overlay.open_saves(), "satchel"])
	items.append(["Settings", func(): Overlay.ctx = "title"; Overlay.open_settings(), "gear"])
	if not OS.has_feature("web"):
		items.append(["Quit", func(): RateCard.gate(Overlay.root, get_tree().quit), "close"])
	for it in items:
		col.add_child(_menu_item(String(it[0]), it[1], String(it[2])))
	var i := 0
	for ch in col.get_children():
		if ch == logo: continue
		UI.pop_in(ch, 0.9 + i * 0.07)
		i += 1
	# bottom corners: what this is, and how to drive the menu without a mouse
	var ver := UI.label("v" + Net.VERSION, 13, Color(1, 1, 1, 0.45))
	ver.autowrap_mode = TextServer.AUTOWRAP_OFF
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 28; ver.offset_top = -40; ver.offset_bottom = -18
	root.add_child(ver)
	# a small playtest chip low in the corner, clear of the splash's hero: the build and the Discord link
	var news := UI.glass(8, 6)
	news.name = "News"
	news.mouse_filter = Control.MOUSE_FILTER_STOP
	news.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	news.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	news.grow_vertical = Control.GROW_DIRECTION_BEGIN
	news.offset_right = -28; news.offset_bottom = -64
	var nv := UI.hbox(10); news.add_child(nv)
	var tag := UI.label("PLAYTEST  ·  %s" % Net.VERSION, 11, Color("e9b48a"), UI.caps)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nv.add_child(tag)
	var nb := UI.ghost("Join the Discord", func(): OS.shell_open(DISCORD), 0, "bond")
	nb.focus_mode = Control.FOCUS_NONE
	nv.add_child(nb)
	root.add_child(news)
	UI.pop_in(news, 1.4)
	var keys := UI.key_hints([["W S", "choose"], ["Enter", "select"], ["Esc", "back"]], 13)
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	keys.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	keys.offset_right = -28; keys.offset_top = -44; keys.offset_bottom = -16
	root.add_child(keys)
	b1.grab_focus()

## The menu's item labels in order (the main button first): read by --title-check.
func menu_labels() -> Array:
	var out: Array = []
	if menu_col == null:
		return out
	for ch in menu_col.get_children():
		if ch is Button: out.append(String((ch as Button).text))
	return out

## W and S move through the menu as well as the arrow keys and a gamepad's d-pad.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := (event as InputEventKey).physical_keycode
	if k != KEY_W and k != KEY_S:
		return
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return
	var nxt := f.find_prev_valid_focus() if k == KEY_W else f.find_next_valid_focus()
	if nxt:
		nxt.grab_focus()
		get_viewport().set_input_as_handled()

func _spaced() -> FontVariation:
	var f := FontVariation.new()
	f.base_font = UI.body
	f.variation_opentype = {"wght": 600}
	f.spacing_glyph = 2
	return f

## "Pip · level 4 · 12 expeditions" under Continue, so you know which save this is.
func _resume_line() -> String:
	var k := Save.active_kin()
	var bits: Array = []
	bits.append(String(Save.d.get("name", "Hunter")))
	if not k.is_empty():
		bits.append("%s, level %d" % [String(k.get("name", "")), int(k.get("level", 1))])
	var n := int(Save.d.get("matches", 0))
	bits.append("%d expedition%s" % [n, "" if n == 1 else "s"] if n > 0 else "no expeditions yet")
	return "  ·  ".join(bits)

func _menu_main(text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb)
	b.theme_type_variation = "MenuMain"
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 300
	b.mouse_entered.connect(func(): if not b.has_focus(): b.grab_focus())
	return b

func _menu_item(text: String, cb: Callable, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "MenuItem"
	if icon != "": UI.set_icon(b, icon, 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 300
	b.pressed.connect(func(): Sfx.play("click"); cb.call())
	# pointing at an item focuses it, so mouse and keyboard always agree on which one is lit
	b.mouse_entered.connect(func(): if not b.has_focus(): b.grab_focus())
	b.focus_entered.connect(func():
		Sfx.play("hover", null, -12.0, 0.05)
		b.add_theme_stylebox_override("normal", b.get_theme_stylebox("hover", "MenuItem"))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.queue_redraw())
	b.focus_exited.connect(func():
		b.remove_theme_stylebox_override("normal")
		b.remove_theme_color_override("font_color")
		b.queue_redraw())
	return b

# ---------------------------------------------------------------- per frame
func _place_cam(delta: float) -> void:
	if cam_override.size() == 6:
		cam.position = Vector3(cam_override[0], cam_override[1], cam_override[2])
		cam.look_at(Vector3(cam_override[3], cam_override[4], cam_override[5]), Vector3.UP)
		return
	# the mouse: smoothed, so the scene glides rather than jitters
	var vs := get_viewport().get_visible_rect().size
	var mp := get_viewport().get_mouse_position()
	var m := Vector2.ZERO
	if vs.x > 1.0 and vs.y > 1.0 and Rect2(Vector2.ZERO, vs).has_point(mp):
		m = Vector2(mp.x / vs.x - 0.5, mp.y / vs.y - 0.5) * 2.0
	mouse_k = mouse_k.lerp(m, 1.0 - exp(-2.2 * delta)) if delta > 0.0 else m
	# a slow drift along the cliff, and the mouse shifts the eye a little: near things move more
	# than far ones, so the layers slide past each other
	var drift := Vector3(sin(t * 0.05) * 0.35, sin(t * 0.083) * 0.08, cos(t * 0.05) * 0.2)
	var right := Vector3(0.95, 0, 0.3).normalized()
	cam.position = CAM_AT + drift + right * (-mouse_k.x * 0.28) + Vector3(0, mouse_k.y * 0.12, 0)
	cam.look_at(CAM_LOOK + right * (mouse_k.x * 0.35) + Vector3(0, -mouse_k.y * 0.2, 0) + drift * 0.4, Vector3.UP)

func _process(delta: float) -> void:
	t += delta
	_place_cam(delta)
	if not stung and t > 0.7:
		# the logo lands with a low horn under the music
		stung = true
		Sfx.play("horn", null, -15.0, 0.0, 0.62)
	# the banner whips in the wind, each strip a beat behind the one before
	if flag:
		for k in 4:
			var s := flag.get_node_or_null("Seg%d" % k) as Node3D
			if s:
				s.rotation = Vector3(sin(t * 6.0 - k * 0.9) * 0.15, sin(t * 4.5 - k * 0.8) * (0.25 + k * 0.12), 0)
	for isl in isles:
		var n: Node3D = isl[0]
		n.position.y = float(isl[1]) + sin(t * 0.25 + float(isl[2])) * 0.8
	for c in clouds:
		var n: Node3D = c["node"]
		n.position.x += float(c["speed"]) * delta
		if n.position.x > 220.0:
			n.position.x = -180.0
	for shf in shafts:
		(shf[1] as ShaderMaterial).set_shader_parameter("intensity", float(shf[2]) * (0.7 + 0.3 * sin(t * 0.25 + float(shf[3]))))
	if wyrm:
		wyrm.position = _wyrm_at(t)
	# the squad: breathing, shifting weight, hair and cloth in the wind
	for s in squad:
		(s["anim"] as HunterAnim).update(delta, s["st"])
	for i in boki.size():
		var b: Dictionary = boki[i]
		var k: Node3D = b["node"]
		var body := k.get_node_or_null("Body") as Node3D
		if body == null: continue
		if i == 0:
			# your Boki, looking up at you: nose raised, a slow tilt of the head now and then
			body.rotation.x = 0.14 + sin(t * 0.6) * 0.03       # (more than this tips a long body over)
			body.rotation.z = sin(t * 0.37) * 0.06
		elif String(b["kind"]) in ["flyer", "serpent"]:
			k.position.y = float(b["base_y"]) + sin(t * 1.3 + i) * 0.12
	# the glider: off for a few seconds, then across the sky
	var h: Node3D = glider.get("node", null)
	if h:
		if float(glider["t"]) < 0.0:
			glide_wait -= delta
			if glide_wait <= 0.0:
				_launch_glider()
		else:
			glider["t"] = float(glider["t"]) + delta
			var k2: float = float(glider["t"]) / float(glider["dur"])
			var a: Vector3 = glider["a"]; var bb: Vector3 = glider["b"]
			h.position = a.lerp(bb, k2) + Vector3(0, sin(k2 * PI * 2.0) * 0.8, 0)
			(glider["anim"] as HunterAnim).update(delta, {"gliding": true, "grounded": false, "vel": (bb - a) / float(glider["dur"]), "face": h.rotation.y})
			if k2 >= 1.0:
				glider["t"] = -1.0
				h.visible = false
				glide_wait = rng.randf_range(4.0, 8.0)

## The game's name: "PROJECT" set small and wide over a big carved "BOKI" in pale bone, its lower half
## warmed like metal near a fire, a faint ember glow that breathes underneath, a slow sheen that
## crosses the letters every few seconds and a few embers lifting off it. It settles in on open.
class TitleLogo extends Control:
	var tt := 0.0
	const WORD := "BOKI"
	const PRE := "PROJECT"
	const FS := 146
	var bands: Array = []         # clipped strips, each a shade warmer: a vertical gradient on the face
	var sheen: Control
	var motes: Array = []
	func _init() -> void:
		custom_minimum_size = Vector2(500, 196)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# the face warms toward the bottom, like bone lit by a fire below: strips of the word, each
		# clipped to its own band and a shade warmer than the one above
		for i in 8:
			var bd := _Clip.new(); bd.clip_contents = true; bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var c := Color("efe5d4").lerp(Color("c99a6c"), pow(float(i + 1) / 8.0, 1.3))
			bd.draw.connect(func(): _word(bd, c, -bd.position))
			add_child(bd)
			bands.append(bd)
		sheen = _Clip.new(); sheen.clip_contents = true; sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheen.draw.connect(func(): _word(sheen, Color(1.0, 0.97, 0.9, 0.55), -sheen.position))
		add_child(sheen)
		for i in 7:
			motes.append(Vector3(randf(), randf(), randf_range(0.6, 1.4)))
	func base() -> Vector2:
		return Vector2(2, size.y - 30)
	func _word(on: CanvasItem, c: Color, off: Vector2) -> void:
		on.draw_string(UI.big, base() + off, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, c)
	func _process(delta: float) -> void:
		tt += delta
		var w := UI.big.get_string_size(WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
		var b := base()
		var top := b.y - FS * 0.42
		var step := FS * 0.6 / bands.size()
		for i in bands.size():
			var bd: Control = bands[i]
			bd.position = Vector2(0, top + i * step)
			bd.size = Vector2(w + 8, step + (FS * 0.3 if i == bands.size() - 1 else 0.5))
			bd.queue_redraw()
		# the sheen: a narrow band that sweeps across every 7 seconds
		var cyc := fmod(tt, 7.0) / 1.6
		sheen.visible = cyc < 1.0
		sheen.position = Vector2(lerpf(-60.0, w + 20.0, clampf(cyc, 0.0, 1.0)), b.y - FS * 0.85)
		sheen.size = Vector2(26, FS)
		sheen.queue_redraw()
		for i in motes.size():
			var m: Vector3 = motes[i]
			m.y -= delta * 0.12 * m.z
			if m.y < 0.0:
				m = Vector3(randf(), 1.0, randf_range(0.6, 1.4))
			motes[i] = m
		queue_redraw()
	func _draw() -> void:
		var f: Font = UI.big
		var intro := clampf(tt / 1.1, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - intro, 3.0)
		modulate.a = e
		var b := base() + Vector2(0, (1.0 - e) * 10.0)
		var w := f.get_string_size(WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
		# "PROJECT", small and spaced, with a hairline either side
		var pf := FontVariation.new(); pf.base_font = UI.body; pf.variation_opentype = {"wght": 700}; pf.spacing_glyph = int(lerpf(18.0, 12.0, e))
		var pw := pf.get_string_size(PRE, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var py := b.y - FS * 0.78
		var px := 4.0 + (w - pw) * 0.5
		draw_string(pf, Vector2(px, py), PRE, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("d8c8b2"))
		draw_line(Vector2(6, py - 7), Vector2(px - 14, py - 7), Color(0.85, 0.78, 0.7, 0.4), 1.5, true)
		draw_line(Vector2(px + pw + 4, py - 7), Vector2(w, py - 7), Color(0.85, 0.78, 0.7, 0.4), 1.5, true)
		# the ember glow underneath, breathing
		var br := 0.75 + 0.25 * sin(tt * 1.3)
		draw_string_outline(f, b, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, 44, Color(1.0, 0.42, 0.15, 0.07 * br))
		draw_string_outline(f, b, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, 22, Color(1.0, 0.5, 0.2, 0.12 * br))
		# a carved edge: a deep shadow below, the ink outline, then the pale face
		for i in range(5, 0, -1):
			draw_string_outline(f, b + Vector2(0, i * 1.3), WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, 12, Color("1a1214"))
		draw_string_outline(f, b, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, 10, Color("150f12"))
		draw_string(f, b, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color("efe5d4"))
		# embers lifting off the letters
		for m in motes:
			var mp := Vector2(8.0 + m.x * w, b.y - FS * 0.2 - (1.0 - m.y) * FS * 0.9)
			var a := sin(m.y * PI) * 0.8
			draw_circle(mp, 1.6 * m.z, Color(1.0, 0.6, 0.25, a))
	class _Clip extends Control:
		pass
