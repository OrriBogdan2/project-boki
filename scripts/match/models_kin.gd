class_name ModelsKin
## Kin bodies and the home nest props. Moved out of Models; callers still use the Models facade.


# ---------------------------------------------------------------- kin
static var AURA: Shader = preload("res://shaders/kin_aura.gdshader")

static func aura_mat(c: Color, strength := 0.6) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = AURA
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("strength", strength)
	return m

## The glow a hunter wears while a kin is fused onto them as armor.
static func kin_shell(c: Color) -> Node3D:
	var root := Node3D.new()
	var mi := ModelsBase.part(root, ModelsBase.capsule(0.62, 2.0), aura_mat(c, 0.75), Vector3(0, 1.0, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := ModelsBase.part(root, ModelsBase.flat_quad(2.6), ModelsBase.ring_mat(Color(c, 0.9), 0.1), Vector3(0, 0.06, 0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

## A kin. Every species has its own body shape, tail, feet and ears (from its "look" in
## content/kin), a rim of light in its glow colour, a soft aura shell and a few drifting particles,
## so you can tell them apart at a glance and see them against busy ground.
static func kin(species: String, rec := {}) -> Node3D:
	var sp: Dictionary = Data.KIN[species]
	var look: Dictionary = sp.get("look", {})
	var shimmer: bool = rec.get("shimmer", false)
	var ghost: bool = rec.get("ghost", false)       # brought back by the Soul Shrine: pale and glowing
	# a shimmer wears its species' own alternate palette (Shiny.palette, hand-picked in content/kin)
	var glow_c: Color = Shiny.col(species, rec, "glow") if (shimmer or ghost) else sp.get("glow", sp["color"])
	var body_c: Color = Shiny.col(species, rec, "color")
	var root := Node3D.new()
	var mats: Array = []
	var m_body := ModelsBase.toon(body_c); mats.append(m_body)
	m_body.set_shader_parameter("rim_color", glow_c)
	m_body.set_shader_parameter("rim_amount", 2.2 if ghost else 1.4)
	var m_belly := ModelsBase.toon(Shiny.col(species, rec, "belly")); mats.append(m_belly)
	m_belly.set_shader_parameter("rim_color", glow_c)
	var m_dark := ModelsBase.toon(((Shiny.palette(species)["color"] if shimmer else sp["color"]) as Color).darkened(0.3)); mats.append(m_dark)
	var m_glow := ModelsBase.toon(glow_c, false, 0.7); mats.append(m_glow)
	var m_eye := ModelsBase.toon(Color.WHITE, false); mats.append(m_eye)
	m_eye.set_shader_parameter("use_vertex_color", true)
	m_eye.set_shader_parameter("gloss", 0.9)
	m_eye.set_shader_parameter("sss", 0.0)
	m_eye.set_shader_parameter("rim_amount", 0.25)
	m_eye.set_meta("iris", Unique.iris(rec, glow_c.lerp(sp["color"], 0.35).darkened(0.08)))     # its own eye colour (Unique)
	var m_white := ModelsBase.toon(Color.WHITE, false, 0.6)
	var m_blush := ModelsBase.toon(Color("ff9aa8"), false, 0.2)
	# Body moves the kin around (hops, lunges, tumbles); Flex inside it squashes and stretches (KinPuppet)
	var body_root := Node3D.new(); body_root.name = "Body"; root.add_child(body_root)
	var body := Node3D.new(); body.name = "Flex"; body_root.add_child(body)
	var built := KinModels.build(species, body, {"body": m_body, "belly": m_belly, "dark": m_dark, "glow": m_glow, "eye": m_eye, "white": m_white,
		"wing_col": Shiny.palette(species).get("wing", (Shiny.col(species, rec, "belly") as Color).lerp(glow_c, 0.3)) if shimmer else sp.get("wing", (sp["belly"] as Color).lerp(glow_c, 0.3))}, mats)
	if built.is_empty():
		var shape := String(look.get("body", "round"))
		var head_y := 0.44      # where the eyes sit
		var top_y := 0.68       # where ears sit
		var front_z := -0.28
		match shape:
			"drop":
				# a water drop: round below, tapering to a curl on top
				ModelsBase.part(body, ModelsBase.sphere(0.34), m_body, Vector3(0, 0.32, 0), Vector3(1.0, 0.88, 1.0))
				ModelsBase.part(body, ModelsBase.cyl(0.02, 0.24, 0.34), m_body, Vector3(0, 0.66, 0.04), Vector3.ONE, Vector3(0.25, 0, 0))
				ModelsBase.part(body, ModelsBase.sphere(0.05, 8), m_body, Vector3(0, 0.84, 0.12))
				ModelsBase.part(body, ModelsBase.sphere(0.24), m_belly, Vector3(0, 0.28, -0.14), Vector3(1.0, 0.95, 0.7))
				top_y = 0.6
			"burr":
				# a round burr of leaves with little thorns all over its back
				ModelsBase.part(body, ModelsBase.sphere(0.33), m_body, Vector3(0, 0.33, 0), Vector3(1.05, 0.95, 1.0))
				ModelsBase.part(body, ModelsBase.sphere(0.23), m_belly, Vector3(0, 0.29, -0.15), Vector3(1.0, 0.95, 0.7))
				for i in 9:
					var a := float(i) / 9.0 * TAU
					var up := 0.35 + 0.18 * float(i % 3)
					var dir := Vector3(cos(a) * 0.9, up, sin(a) * 0.9 + 0.35).normalized()
					if dir.z < -0.2: continue
					var sp_n := ModelsBase.part(body, ModelsBase.cyl(0.0, 0.05, 0.16, 6), m_dark, Vector3(0, 0.36, 0.02) + dir * 0.3)
					sp_n.basis = Basis(Quaternion(Vector3.UP, dir))
			"pear":
				# a pear: a wide bottom and a narrower head, always a little jittery
				ModelsBase.part(body, ModelsBase.sphere(0.33), m_body, Vector3(0, 0.3, 0), Vector3(1.05, 0.85, 1.0))
				ModelsBase.part(body, ModelsBase.sphere(0.25), m_body, Vector3(0, 0.56, -0.02))
				ModelsBase.part(body, ModelsBase.sphere(0.22), m_belly, Vector3(0, 0.26, -0.15), Vector3(1.0, 0.9, 0.7))
				head_y = 0.58; top_y = 0.78; front_z = -0.22
			"boulder":
				# a chunky rock: a wide body with stone plates on its back and a heavy brow
				ModelsBase.part(body, ModelsBase.sphere(0.36), m_body, Vector3(0, 0.33, 0), Vector3(1.18, 0.86, 1.08))
				ModelsBase.part(body, ModelsBase.sphere(0.24), m_belly, Vector3(0, 0.27, -0.17), Vector3(1.1, 0.9, 0.65))
				for i in 3:
					ModelsBase.part(body, ModelsBase.box(0.3 - i * 0.06, 0.08, 0.2), m_dark, Vector3(0, 0.6 - i * 0.12, 0.12 + i * 0.12), Vector3.ONE, Vector3(-0.5 - i * 0.3, 0, 0))
				ModelsBase.part(body, ModelsBase.box(0.4, 0.07, 0.12), m_dark, Vector3(0, 0.53, -0.26), Vector3.ONE, Vector3(0.35, 0, 0))
				head_y = 0.42
			"cloud":
				# a puff of cloud that floats, with no feet at all
				for pf in [[Vector3(0, 0.42, 0), 0.3], [Vector3(-0.2, 0.38, 0.08), 0.2], [Vector3(0.2, 0.38, 0.08), 0.2], [Vector3(0, 0.6, 0.06), 0.2], [Vector3(0, 0.34, 0.22), 0.18]]:
					ModelsBase.part(body, ModelsBase.sphere(pf[1]), m_body, pf[0])
				ModelsBase.part(body, ModelsBase.sphere(0.2), m_belly, Vector3(0, 0.38, -0.14), Vector3(1.0, 0.9, 0.6))
				head_y = 0.48; top_y = 0.72
			_:
				ModelsBase.part(body, ModelsBase.sphere(0.34), m_body, Vector3(0, 0.34, 0), Vector3(1.05, 0.92, 1.0))
				ModelsBase.part(body, ModelsBase.sphere(0.24), m_belly, Vector3(0, 0.3, -0.14), Vector3(1.0, 0.95, 0.7))
		# face: big eyes with a catch light, and rosy cheeks
		for sx in [-1.0, 1.0]:
			var sd := "L" if sx < 0.0 else "R"
			ModelsBase.part(body, ModelsBase.eye_mesh(0.068, m_eye.get_meta("iris")), m_eye, Vector3(0.12 * sx, head_y, front_z), Vector3(1, 1.15, 1), Vector3.ZERO, "Eye" + sd)
			ModelsBase.part(body, ModelsBase.sphere(0.024, 6), m_white, Vector3(0.12 * sx + 0.025, head_y + 0.035, front_z - 0.05), Vector3.ONE, Vector3.ZERO, "Shine" + sd)
			ModelsBase.part(body, ModelsBase.sphere(0.04, 6), m_blush, Vector3(0.2 * sx, head_y - 0.08, front_z + 0.05), Vector3(1, 0.5, 0.4))
		# feet
		match String(look.get("feet", "paws")):
			"stumps":
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						ModelsBase.part(body, ModelsBase.cyl(0.08, 0.1, 0.14, 8), m_dark, Vector3(0.2 * sx, 0.06, 0.12 * sz))
			"none":
				body.position.y = 0.12
			_:
				for sx in [-1.0, 1.0]:
					ModelsBase.part(body, ModelsBase.sphere(0.08, 8), m_body, Vector3(0.2 * sx, 0.06, -0.08), Vector3(1, 0.6, 1.2))
		# tail, on its own pivot so it can wag
		var flex := body
		var tail_n := Node3D.new(); tail_n.name = "Tail"; flex.add_child(tail_n)
		body = tail_n
		match String(look.get("tail", "nub")):
			"flame":
				ModelsBase.part(body, ModelsBase.cyl(0.0, 0.11, 0.3, 8), m_glow, Vector3(0, 0.36, 0.38), Vector3.ONE, Vector3(-1.0, 0, 0))
				ModelsBase.part(body, ModelsBase.cyl(0.0, 0.06, 0.2, 8), ModelsBase.toon(Color("fff0a0"), false, 0.9), Vector3(0, 0.42, 0.46), Vector3.ONE, Vector3(-0.8, 0, 0))
			"fish":
				ModelsBase.part(body, ModelsBase.box(0.02, 0.24, 0.22), m_belly, Vector3(0, 0.3, 0.42), Vector3.ONE, Vector3(0.3, 0, 0))
				ModelsBase.part(body, ModelsBase.sphere(0.09, 8), m_body, Vector3(0, 0.26, 0.32))
			"sprout":
				ModelsBase.part(body, ModelsBase.cyl(0.015, 0.02, 0.22, 6), ModelsBase.toon(Color("5a8a3a")), Vector3(0, 0.4, 0.36), Vector3.ONE, Vector3(-0.6, 0, 0))
				ModelsBase.part(body, ModelsBase.sphere(0.08, 8), ModelsBase.toon(Color("8fd16a")), Vector3(0, 0.5, 0.44), Vector3(1.4, 0.3, 0.8))
			"zig":
				for i in 3:
					ModelsBase.part(body, ModelsBase.box(0.05, 0.16, 0.05), m_glow, Vector3(0.05 * (1 if i % 2 == 0 else -1), 0.3 + i * 0.1, 0.34 + i * 0.05), Vector3.ONE, Vector3(-0.6, 0, 0.6 * (1 if i % 2 == 0 else -1)))
			"stub":
				ModelsBase.part(body, ModelsBase.sphere(0.09, 8), m_dark, Vector3(0, 0.22, 0.36))
			"wisp":
				for i in 3:
					ModelsBase.part(body, ModelsBase.sphere(0.07 - i * 0.015, 8), m_glow, Vector3(0, 0.36 + i * 0.05, 0.36 + i * 0.12), Vector3.ONE, Vector3.ZERO, "Wisp%d" % i)
			_:
				ModelsBase.part(body, ModelsBase.sphere(0.1, 8), m_body, Vector3(0, 0.26, 0.32))
		body = flex
		_repivot(tail_n, Vector3(0, 0.3, 0.3))
		var ears_n := Node3D.new(); ears_n.name = "Ears"; flex.add_child(ears_n)
		body = ears_n
		match String(sp["ears"]):
			"flame":
				var m_f := ModelsBase.toon(Color("ffb347"), true, 0.5); mats.append(m_f)
				ModelsBase.part(body, ModelsBase.cyl(0.0, 0.12, 0.3), m_f, Vector3(0, top_y + 0.06, 0.02))
				ModelsBase.part(body, ModelsBase.cyl(0.0, 0.08, 0.22), m_f, Vector3(-0.13, top_y, 0.04), Vector3.ONE, Vector3(0, 0, 0.4))
				ModelsBase.part(body, ModelsBase.cyl(0.0, 0.08, 0.22), m_f, Vector3(0.13, top_y, 0.04), Vector3.ONE, Vector3(0, 0, -0.4))
			"fin":
				ModelsBase.part(body, ModelsBase.sphere(0.14), m_belly, Vector3(0, top_y - 0.02, 0.06), Vector3(0.35, 1.1, 1.3))
				ModelsBase.part(body, ModelsBase.sphere(0.1), m_body, Vector3(-0.3, 0.3, 0.05), Vector3(0.4, 0.8, 1.2))
				ModelsBase.part(body, ModelsBase.sphere(0.1), m_body, Vector3(0.3, 0.3, 0.05), Vector3(0.4, 0.8, 1.2))
			"leaf":
				var m_l := ModelsBase.toon(Color("3e8f3a")); mats.append(m_l)
				ModelsBase.part(body, ModelsBase.sphere(0.14), m_l, Vector3(-0.14, top_y, 0), Vector3(0.5, 1.2, 0.25), Vector3(0, 0, 0.5))
				ModelsBase.part(body, ModelsBase.sphere(0.14), m_l, Vector3(0.14, top_y, 0), Vector3(0.5, 1.2, 0.25), Vector3(0, 0, -0.5))
			"bolt":
				var m_b := ModelsBase.toon(Color("fff27a"), true, 0.4); mats.append(m_b)
				ModelsBase.part(body, ModelsBase.box(0.06, 0.26, 0.06), m_b, Vector3(-0.14, top_y + 0.04, 0), Vector3.ONE, Vector3(0, 0, 0.5))
				ModelsBase.part(body, ModelsBase.box(0.06, 0.26, 0.06), m_b, Vector3(0.14, top_y + 0.04, 0), Vector3.ONE, Vector3(0, 0, -0.5))
				ModelsBase.part(body, ModelsBase.box(0.05, 0.16, 0.05), m_b, Vector3(-0.22, top_y + 0.18, 0), Vector3.ONE, Vector3(0, 0, -0.4))
				ModelsBase.part(body, ModelsBase.box(0.05, 0.16, 0.05), m_b, Vector3(0.22, top_y + 0.18, 0), Vector3.ONE, Vector3(0, 0, 0.4))
			"horn":
				var m_h := ModelsBase.toon(Color("e8e0cc")); mats.append(m_h)
				ModelsBase.part(body, ModelsBase.cyl(0.0, 0.07, 0.2), m_h, Vector3(-0.15, top_y - 0.02, -0.05), Vector3.ONE, Vector3(-0.2, 0, 0.35))
				ModelsBase.part(body, ModelsBase.cyl(0.0, 0.07, 0.2), m_h, Vector3(0.15, top_y - 0.02, -0.05), Vector3.ONE, Vector3(-0.2, 0, -0.35))
			"wisp":
				var m_w := ModelsBase.toon(Color("efe8ff"), false, 0.8); mats.append(m_w)
				for i in 3:
					var a := float(i) / 3.0 * TAU
					ModelsBase.part(body, ModelsBase.sphere(0.06, 8), m_w, Vector3(cos(a) * 0.3, top_y + 0.04 + sin(a * 2.0) * 0.04, sin(a) * 0.3), Vector3.ONE, Vector3.ZERO, "Orb%d" % i)
		body = flex
		_repivot(ears_n, Vector3(0, top_y - 0.06, 0))
	# the aura shell: an outline of light in its glow colour, brightest at the silhouette
	var shell := ModelsBase.part(body_root, ModelsBase.sphere(0.4, 18), aura_mat(glow_c, 0.0), Vector3(0, 0.4, 0.02), Vector3(1.12, 1.15, 1.1), Vector3.ZERO, "Shell")
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.visible = false
	# a few particles that say what it is: embers, bubbles, leaves, sparks, grit, wind
	var pt := CPUParticles3D.new()
	pt.name = "Aura"
	pt.amount = 7
	pt.lifetime = 1.1
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pt.emission_sphere_radius = 0.38
	pt.position = Vector3(0, 0.4, 0)
	pt.mesh = ModelsBase.sphere(0.035, 4)
	pt.scale_amount_min = 0.6; pt.scale_amount_max = 1.4
	pt.color = glow_c
	pt.local_coords = false
	pt.direction = Vector3.UP
	pt.spread = 30.0
	pt.initial_velocity_min = 0.3; pt.initial_velocity_max = 0.8
	pt.gravity = Vector3(0, 0.6, 0)
	match String(look.get("aura", "")):
		"bubbles": pt.gravity = Vector3(0, 0.9, 0); pt.mesh = ModelsBase.sphere(0.045, 6)
		"leaves": pt.gravity = Vector3(0, -0.5, 0); pt.initial_velocity_min = 0.5; pt.spread = 120.0; pt.mesh = ModelsBase.box(0.07, 0.01, 0.04)
		"sparks": pt.gravity = Vector3.ZERO; pt.spread = 180.0; pt.initial_velocity_min = 0.8; pt.initial_velocity_max = 1.6; pt.lifetime = 0.5; pt.mesh = ModelsBase.box(0.02, 0.09, 0.02)
		"pebbles": pt.gravity = Vector3(0, -2.0, 0); pt.mesh = ModelsBase.box(0.05, 0.05, 0.05); pt.amount = 4
		"wind": pt.gravity = Vector3.ZERO; pt.spread = 180.0; pt.initial_velocity_min = 0.6; pt.initial_velocity_max = 1.0; pt.mesh = ModelsBase.sphere(0.025, 4)
		"drips": pt.gravity = Vector3(0, -1.6, 0); pt.initial_velocity_min = 0.0; pt.initial_velocity_max = 0.2; pt.mesh = ModelsBase.sphere(0.03, 6); pt.scale_amount_min = 0.8
		"prism":
			var pp := PrismMesh.new(); pp.size = Vector3(0.05, 0.08, 0.02)
			pt.mesh = pp; pt.gravity = Vector3(0, 0.3, 0); pt.spread = 180.0; pt.initial_velocity_min = 0.2; pt.initial_velocity_max = 0.5; pt.angular_velocity_min = -180.0; pt.angular_velocity_max = 180.0
		"spores": pt.gravity = Vector3(0, 0.15, 0); pt.spread = 180.0; pt.initial_velocity_min = 0.05; pt.initial_velocity_max = 0.25; pt.lifetime = 2.2; pt.mesh = ModelsBase.sphere(0.022, 4); pt.amount = 10
		"rings":
			var tr := TorusMesh.new(); tr.inner_radius = 0.06; tr.outer_radius = 0.075; tr.rings = 12; tr.ring_segments = 3
			pt.mesh = tr; pt.gravity = Vector3.ZERO; pt.direction = Vector3(0, 0.4, -1); pt.spread = 25.0; pt.initial_velocity_min = 0.5; pt.initial_velocity_max = 0.8; pt.amount = 4
			pt.scale_amount_min = 1.0; pt.scale_amount_max = 2.6
		"moondust": pt.gravity = Vector3(0, -0.15, 0); pt.spread = 180.0; pt.initial_velocity_min = 0.05; pt.initial_velocity_max = 0.2; pt.lifetime = 1.8; pt.mesh = ModelsBase.sphere(0.02, 4); pt.amount = 9
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.vertex_color_use_as_albedo = true
	pm.albedo_color = Color(1, 1, 1, 0.9)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pt.material_override = pm
	pt.emitting = false
	root.add_child(pt)
	root.set_meta("mats", mats)
	for mm in ModelsBake.collect_mats(body_root):
		(mm as ShaderMaterial).set_shader_parameter("paint", 0.015)
		if (mm as ShaderMaterial).get_shader_parameter("glow") == 0.0 and not (mm as ShaderMaterial).get_shader_parameter("use_vertex_color"):
			ModelsBake.painted(mm, 0, 0.24, 0.26, 0.22)
	ModelsBake.painted(m_dark, 2, 0.2, 0.2, 0.2)
	ModelsBake.bake_part_y(body_root)
	Evo.dress(root, rec)
	if shimmer:
		# a shimmer sparkles a little, all the time
		for i in 3:
			var a := TAU * i / 3.0
			ModelsBase.part(body, ModelsBase.sphere(0.035, 6), ModelsBase.toon(Color("fff6c0"), false, 1.6), Vector3(cos(a) * 0.42, 0.62 + i * 0.08, sin(a) * 0.42), Vector3.ONE, Vector3.ZERO, "Spark%d" % i)
	var acc: String = rec.get("acc", "")
	if acc != "" and Data.ACCS.has(acc):
		accessory(body, acc, Goods.wear_col(rec))
	PrizeBoard.dress(body, rec)      # a rosette for each Cup Ribbon (garden games)
	var pup: Node = KinPuppet.new(); pup.set("species", species)
	root.add_child(pup)
	if int(rec.get("level", 1)) < 4 and (rec.get("forms", []) as Array).is_empty() and not rec.is_empty():
		# hatchlings are small
		root.set_meta("evo_scale", 0.82)
		root.scale = Vector3.ONE * 0.82
	Unique.dress(root, rec)          # this kin's own: size, palette shift, coat marks, proportions, shapes
	Mutations.dress(root, rec)       # rare mutations: size, palette, extra parts
	ShadowPolicy.boki(root)      # the body casts, the bits don't (item 94)
	return root

## Moves a group's pivot to `at` without moving what's in it.
static func _repivot(n: Node3D, at: Vector3) -> void:
	n.position = at
	for ch in n.get_children():
		(ch as Node3D).position -= at

## Something a kin wears, on its body at head height, in colour c (its own, or a dye's).
static func accessory(body: Node3D, id: String, c: Color) -> void:
	var m := ModelsBase.toon(c)
	match id:
		"bell":
			ModelsBase.part(body, ModelsBase.sphere(0.07, 10), ModelsBase.toon(c, true, 0.4), Vector3(0, 0.2, -0.33))
			ModelsBase.part(body, ModelsBase.cyl(0.2, 0.2, 0.04, 16), ModelsBase.toon(Color("d9604a")), Vector3(0, 0.25, -0.02), Vector3(1.05, 1, 1.05))
		"bow":
			for sx in [-1.0, 1.0]:
				ModelsBase.part(body, ModelsBase.sphere(0.09, 8), m, Vector3(0.1 * sx + 0.16, 0.66, -0.06), Vector3(1.2, 0.7, 0.5), Vector3(0, 0, 0.5 * sx))
			ModelsBase.part(body, ModelsBase.sphere(0.04, 6), m, Vector3(0.16, 0.66, -0.07))
		"leafhat":
			ModelsBase.part(body, ModelsBase.sphere(0.2, 10), m, Vector3(0, 0.66, 0), Vector3(1.3, 0.25, 1.3))
			ModelsBase.part(body, ModelsBase.cyl(0.01, 0.015, 0.14, 6), ModelsBase.toon(Color("6b4a33")), Vector3(0, 0.76, 0))
		"scarf":
			ModelsBase.part(body, ModelsBase.cyl(0.29, 0.31, 0.09, 16), m, Vector3(0, 0.24, -0.02))
			ModelsBase.part(body, ModelsBase.box(0.09, 0.2, 0.04), m, Vector3(0.12, 0.13, -0.29), Vector3.ONE, Vector3(0.2, 0, 0.2))
		"crown":
			for i in 7:
				var a := TAU * i / 7.0
				ModelsBase.part(body, ModelsBase.sphere(0.05, 6), ModelsBase.toon(Color("ffd0e8") if i % 2 == 0 else Color("fff27a"), false, 0.3), Vector3(cos(a) * 0.2, 0.68, sin(a) * 0.2))
		"goggles":
			ModelsBase.part(body, ModelsBase.cyl(0.3, 0.3, 0.05, 16), ModelsBase.toon(Color("4e3424")), Vector3(0, 0.53, 0), Vector3(1.0, 1, 1.0), Vector3(0.25, 0, 0))
			for sx in [-1.0, 1.0]:
				ModelsBase.part(body, ModelsBase.cyl(0.07, 0.07, 0.05, 12), ModelsBase.toon(Color("9af0ff"), false, 0.5), Vector3(0.11 * sx, 0.58, -0.27), Vector3.ONE, Vector3(PI / 2 + 0.25, 0, 0))
		"cape":
			ModelsBase.part(body, ModelsBase.box(0.42, 0.36, 0.03), m, Vector3(0, 0.3, 0.3), Vector3.ONE, Vector3(-0.35, 0, 0))
			ModelsBase.part(body, ModelsBase.cyl(0.2, 0.2, 0.04, 14), m, Vector3(0, 0.46, 0.05))
		"tophat":
			ModelsBase.part(body, ModelsBase.cyl(0.17, 0.17, 0.03, 14), m, Vector3(0, 0.68, 0))
			ModelsBase.part(body, ModelsBase.cyl(0.11, 0.11, 0.2, 14), m, Vector3(0, 0.79, 0))
			ModelsBase.part(body, ModelsBase.cyl(0.113, 0.113, 0.04, 14), ModelsBase.toon(Color("d9604a")), Vector3(0, 0.72, 0))
		_:
			BokiWear.build(body, id, c)

## An air ring: fly through it for a burst of speed.
static func air_ring() -> Node3D:
	var root := Node3D.new()
	var t := TorusMesh.new(); t.inner_radius = 1.2; t.outer_radius = 1.42; t.rings = 28; t.ring_segments = 8
	var ring := ModelsBase.part(root, t, ModelsBase.toon(Color("5ad0f0"), true, 0.45), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0), "Ring")
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := ModelsBase.part(root, ModelsBase.cyl(1.2, 1.2, 0.02, 24), ModelsBase.glow_mat(Color(0.55, 0.9, 1.0, 0.12)), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0), "Disc")
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

## The training yard: a straw dummy on a post, a mat and a couple of hoops.
static func training_yard() -> Node3D:
	var root := Node3D.new()
	var wood := ModelsBase.toon(Color("8b6d52")); var straw := ModelsBase.toon(Color("e2c47a")); var mat := ModelsBase.toon(Color("c9604a"))
	ModelsBase.part(root, ModelsBase.cyl(0.07, 0.08, 1.3, 8), wood, Vector3(1.0, 0.65, -0.6))
	var dummy := Node3D.new(); dummy.name = "Dummy"; dummy.position = Vector3(1.0, 0.0, -0.6); root.add_child(dummy)
	ModelsBase.part(dummy, ModelsBase.sphere(0.28, 12), straw, Vector3(0, 0.95, 0), Vector3(1, 1.3, 1))
	ModelsBase.part(dummy, ModelsBase.sphere(0.16, 10), straw, Vector3(0, 1.45, 0))
	ModelsBase.part(dummy, ModelsBase.box(0.7, 0.08, 0.08), wood, Vector3(0, 1.1, 0))
	# a sparring mat painted like a target
	ModelsBase.part(root, ModelsBase.cyl(0.78, 0.8, 0.05, 24), ModelsBase.toon(Color("e9dcc0")), Vector3(0, 0.025, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.62, 0.62, 0.02, 24), mat, Vector3(0, 0.055, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.44, 0.44, 0.02, 24), ModelsBase.toon(Color("e9dcc0"), false), Vector3(0, 0.065, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.22, 0.22, 0.02, 20), mat, Vector3(0, 0.075, 0))
	var ring_m := ModelsBase.toon(Color("f2c84a"))
	for i in 2:
		var t := TorusMesh.new(); t.inner_radius = 0.26; t.outer_radius = 0.32
		ModelsBase.part(root, t, ring_m, Vector3(-1.1 - i * 0.6, 0.34, 0.3 - i * 0.2), Vector3.ONE, Vector3(PI / 2, 0.3, 0))
		ModelsBase.part(root, ModelsBase.cyl(0.025, 0.025, 0.34, 6), wood, Vector3(-1.1 - i * 0.6, 0.0, 0.3 - i * 0.2))
	return root

## The Nesting Nook at home: a flower arbor over a big straw nest with two cushions, where two kin
## who are close can leave an egg. (The egg itself sits in the middle, from nest_egg().)
static func nesting_nook() -> Node3D:
	var root := Node3D.new()
	var wood := ModelsBase.toon(Color("8a6a45")); var straw := ModelsBase.toon(Color("d8b46a")); var straw_d := ModelsBase.toon(Color("b08a48"))
	var pink := ModelsBase.toon(Color("ff9ab8"), false, 0.15); var leaf := ModelsBase.toon(Color("6aa64a"))
	# a stepping-stone floor
	for i in 7:
		var a := TAU * i / 7.0
		ModelsBase.part(root, ModelsBase.cyl(0.24, 0.26, 0.06, 8), ModelsBase.toon(Color("cfc8bb")), Vector3(cos(a) * 1.45, 0.03, sin(a) * 1.45))
	# the nest: a thick ring of straw with a few loose stalks
	var t := TorusMesh.new(); t.inner_radius = 0.42; t.outer_radius = 0.82; t.rings = 18; t.ring_segments = 8
	ModelsBase.part(root, t, straw, Vector3(0, 0.16, 0), Vector3(1.0, 0.7, 1.0))
	for i in 10:
		var a := TAU * i / 10.0 + 0.2
		ModelsBase.part(root, ModelsBase.box(0.03, 0.03, 0.4), straw_d, Vector3(cos(a) * 0.66, 0.3, sin(a) * 0.66), Vector3.ONE, Vector3(0.3, -a, 0.2))
	# two cushions for the pair, either side
	for sx in [-1.0, 1.0]:
		ModelsBase.part(root, ModelsBase.sphere(0.3, 14), ModelsBase.toon(Color("f2c84a") if sx < 0 else Color("8ab4ff")), Vector3(1.2 * sx, 0.12, 0.55), Vector3(1.0, 0.35, 1.0))
	# the arbor: two posts and an arch of vine and flowers behind the nest
	for sx in [-1.0, 1.0]:
		ModelsBase.part(root, ModelsBase.cyl(0.06, 0.07, 1.9, 8), wood, Vector3(1.05 * sx, 0.95, -0.7))
	var arch := TorusMesh.new(); arch.inner_radius = 0.98; arch.outer_radius = 1.12; arch.rings = 24; arch.ring_segments = 6
	var ar := ModelsBase.part(root, arch, leaf, Vector3(0, 1.9, -0.7), Vector3.ONE, Vector3(PI / 2, 0, 0))
	ar.scale = Vector3(1.0, 1.0, 0.75)
	for i in 11:
		var a := PI * i / 10.0
		ModelsBase.part(root, ModelsBase.sphere(0.09, 8), pink if i % 2 == 0 else ModelsBase.toon(Color("fff3a8"), false, 0.15), Vector3(cos(a) * 1.05, 1.9 + sin(a) * 0.78, -0.7))
	# a heart sign hanging from the top of the arch
	var heart := Node3D.new(); heart.name = "Heart"; heart.position = Vector3(0, 2.25, -0.66); root.add_child(heart)
	ModelsBase.part(heart, ModelsBase.sphere(0.13, 12), ModelsBase.toon(Color("ff5a7a"), false, 0.35), Vector3(-0.08, 0.04, 0))
	ModelsBase.part(heart, ModelsBase.sphere(0.13, 12), ModelsBase.toon(Color("ff5a7a"), false, 0.35), Vector3(0.08, 0.04, 0))
	ModelsBase.part(heart, ModelsBase.cyl(0.0, 0.19, 0.24, 4), ModelsBase.toon(Color("ff5a7a"), false, 0.35), Vector3(0, -0.1, 0), Vector3(1.0, 1.0, 0.45), Vector3(PI, PI / 4, 0))
	PropAnim.on(heart, 0.0, 0.05, 2.0)
	return root

## An egg in a straw nest, for kin you raise from an egg at home.
static func nest_egg(c: Color, spot: Color) -> Node3D:
	var root := Node3D.new()
	ModelsBase.part(root, ModelsBase.cyl(0.42, 0.34, 0.16, 16), ModelsBase.toon(Color("c9a46a")), Vector3(0, 0.08, 0))
	var shell := Node3D.new(); shell.name = "Shell"; root.add_child(shell)
	ModelsBase.part(shell, ModelsBase.sphere(0.26, 16), ModelsBase.toon(c.lightened(0.15)), Vector3(0, 0.36, 0), Vector3(0.92, 1.25, 0.92))
	var rng := RandomNumberGenerator.new(); rng.seed = int(c.r * 1000 + spot.g * 100)
	for i in 6:
		var a := rng.randf() * TAU; var y := rng.randf_range(0.2, 0.55)
		ModelsBase.part(shell, ModelsBase.sphere(0.05, 8), ModelsBase.toon(spot), Vector3(cos(a) * 0.22, y, sin(a) * 0.22), Vector3(1, 1, 0.5))
	return root

## The Incubator beside the Nesting Nook: a clay brazier with a copper hood on a round stone hearth,
## and eight straw cradles in an arc in front of it ("C0".."C7", each with an "Egg" anchor, a ring
## of six ember pebbles "P0".."P5" that light as its egg warms, and a "Lock" grate shown while that
## cradle isn't bought yet). Beside it, a little shelf ("Shelf", slots "S0".."S5") for eggs waiting
## for a free cradle. "Embers" glow in the brazier; "Glow" is its light.
static func incubator() -> Node3D:
	var root := Node3D.new()
	var stone := ModelsBase.toon(Color("b9b0a2")); var stone_d := ModelsBase.toon(Color("8f877b"))
	var clay := ModelsBase.toon(Color("b4583a")); var clay_d := ModelsBase.toon(Color("7e3a26"))
	var iron := ModelsBase.toon(Color("3a3236")); var copper := ModelsBase.toon(Color("c8774a"), true, 0.1)
	var wood := ModelsBase.toon(Color("8a6a45")); var wood_d := ModelsBase.toon(Color("6a4e32"))
	var straw := ModelsBase.toon(Color("d8b46a"))
	var pebble := ModelsBase.toon(Color("4a3a36"))
	# the hearth: a low round of fitted stones
	ModelsBase.part(root, ModelsBase.cyl(1.02, 1.08, 0.12, 22), stone_d, Vector3(0, 0.06, 0.05))
	ModelsBase.part(root, ModelsBase.cyl(0.94, 0.98, 0.06, 22), stone, Vector3(0, 0.15, 0.05))
	# the brazier at the back: a clay bowl on three stubby feet, glowing coals inside
	var bz := Vector3(0, 0, -0.38)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		ModelsBase.part(root, ModelsBase.cyl(0.05, 0.07, 0.2, 8), clay_d, bz + Vector3(cos(a) * 0.24, 0.27, sin(a) * 0.24))
	ModelsBase.part(root, ModelsBase.cyl(0.4, 0.24, 0.3, 16), clay, bz + Vector3(0, 0.48, 0))
	var lip := TorusMesh.new(); lip.inner_radius = 0.35; lip.outer_radius = 0.44; lip.rings = 20; lip.ring_segments = 8
	ModelsBase.part(root, lip, clay_d, bz + Vector3(0, 0.63, 0), Vector3(1.0, 0.6, 1.0))
	var embers := Node3D.new(); embers.name = "Embers"; embers.position = bz; root.add_child(embers)
	var rng := RandomNumberGenerator.new(); rng.seed = 41
	for i in 9:
		var a := rng.randf() * TAU; var r := rng.randf_range(0.04, 0.28)
		ModelsBase.part(embers, ModelsBase.sphere(rng.randf_range(0.06, 0.09), 8), ModelsBase.toon(Color("ff8a3a").lerp(Color("ffd06a"), rng.randf()), false, 1.4), Vector3(cos(a) * r, 0.62, sin(a) * r), Vector3(1, 0.6, 1))
	# the hood: three iron posts and a copper cap with a little chimney
	for i in 3:
		var a := TAU * i / 3.0 + PI * 0.5
		ModelsBase.part(root, ModelsBase.cyl(0.025, 0.03, 1.35, 6), iron, bz + Vector3(cos(a) * 0.46, 0.85, sin(a) * 0.46), Vector3.ONE, Vector3(sin(a) * 0.08, 0, -cos(a) * 0.08))
	ModelsBase.part(root, ModelsBase.cyl(0.1, 0.5, 0.28, 14), copper, bz + Vector3(0, 1.62, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.08, 0.1, 0.2, 10), copper, bz + Vector3(0, 1.84, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.13, 0.11, 0.05, 10), iron, bz + Vector3(0, 1.95, 0))
	var glow := OmniLight3D.new(); glow.name = "Glow"
	glow.light_color = Color("ffa04a"); glow.light_energy = 0.0; glow.omni_range = 2.6; glow.position = bz + Vector3(0, 0.9, 0.5)
	root.add_child(glow)
	# the cradles: an arc of eight round the front of the hearth, each with ember pebbles in front
	for i in 8:
		var a := PI * (0.04 + 0.92 * float(i) / 7.0)
		var c := Node3D.new(); c.name = "C%d" % i
		c.position = Vector3(-cos(a) * 0.74, 0.18, 0.02 + sin(a) * 0.62)
		root.add_child(c)
		ModelsBase.part(c, ModelsBase.cyl(0.14, 0.16, 0.1, 12), stone, Vector3(0, 0.05, 0))
		var tr := TorusMesh.new(); tr.inner_radius = 0.06; tr.outer_radius = 0.14; tr.rings = 14; tr.ring_segments = 7
		ModelsBase.part(c, tr, straw, Vector3(0, 0.13, 0), Vector3(1.0, 0.6, 1.0), Vector3.ZERO, "Nest")
		for j in 6:
			var b := PI * (0.18 + 0.64 * float(j) / 5.0)
			ModelsBase.part(c, ModelsBase.sphere(0.028, 6), pebble, Vector3(cos(b) * 0.17, 0.02, sin(b) * 0.17), Vector3(1.2, 0.7, 1.2), Vector3.ZERO, "P%d" % j)
		var egg := Node3D.new(); egg.name = "Egg"; egg.position = Vector3(0, 0.08, 0); c.add_child(egg)
		var lock := Node3D.new(); lock.name = "Lock"; c.add_child(lock)
		for k in 3:
			ModelsBase.part(lock, ModelsBase.box(0.24, 0.02, 0.025), iron, Vector3(0, 0.12, -0.07 + k * 0.07))
		lock.visible = false
	# the shelf for eggs waiting their turn, behind and to one side: two planks, three eggs a plank
	var shelf := Node3D.new(); shelf.name = "Shelf"; shelf.position = Vector3(0.95, 0, -0.95); shelf.rotation.y = -0.35; root.add_child(shelf)
	for sx in [-1.0, 1.0]:
		ModelsBase.part(shelf, ModelsBase.box(0.06, 0.95, 0.06), wood_d, Vector3(sx * 0.36, 0.47, -0.1))
		ModelsBase.part(shelf, ModelsBase.box(0.06, 0.95, 0.06), wood_d, Vector3(sx * 0.36, 0.47, 0.1))
	for y in [0.3, 0.7]:
		ModelsBase.part(shelf, ModelsBase.box(0.82, 0.05, 0.28), wood, Vector3(0, y, 0))
		for j in 3:
			var x := -0.24 + j * 0.24
			var straw_ring := TorusMesh.new(); straw_ring.inner_radius = 0.045; straw_ring.outer_radius = 0.09; straw_ring.rings = 10; straw_ring.ring_segments = 6
			ModelsBase.part(shelf, straw_ring, straw, Vector3(x, y + 0.04, 0), Vector3(1.0, 0.6, 1.0))
			var mk := Marker3D.new(); mk.name = "S%d" % ((0 if y < 0.5 else 3) + j); mk.position = Vector3(x, y + 0.03, 0)
			shelf.add_child(mk)
	return root

## A small gold Rare Egg for the incubator's shelf and cradle, spotted in the colour of the kin inside.
static func rare_egg_small(spot: Color, s := 1.0) -> Node3D:
	var root := Node3D.new()
	var shell := Node3D.new(); shell.name = "Shell"; root.add_child(shell)
	var gold := ModelsBase.toon(Color("ffd36a"), true, 0.35)
	ModelsBase.part(shell, ModelsBase.sphere(0.26 * s, 16), gold, Vector3(0, 0.3 * s, 0), Vector3(0.9, 1.22, 0.9))
	var rng := RandomNumberGenerator.new(); rng.seed = int(spot.r * 991 + spot.g * 113 + spot.b * 7)
	var sm := ModelsBase.toon(spot, false, 1.0)
	for i in 7:
		var a := rng.randf() * TAU; var y := rng.randf_range(0.16, 0.5)
		ModelsBase.part(shell, ModelsBase.sphere(0.045 * s, 8), sm, Vector3(cos(a) * 0.215 * s, y * s, sin(a) * 0.215 * s), Vector3(1, 1, 0.5))
	return root
