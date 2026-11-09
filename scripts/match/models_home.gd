class_name ModelsHome
## Home houses, buildings and furniture. Moved out of Models; callers still use the Models facade.


# ---------------------------------------------------------------- home
static func house() -> Node3D:
	var root := Node3D.new()
	var wall := ModelsBase.toon(Color("efe2c8")); var roof := ModelsBase.toon(Color("b4553f")); var wood := ModelsBase.toon(Color("7a5236"))
	var glass := ModelsBase.toon(Color("ffd98a"), false, 0.8)
	ModelsBase.part(root, ModelsBase.box(4.2, 2.2, 3.2), wall, Vector3(0, 1.1, 0))
	var pr := PrismMesh.new(); pr.size = Vector3(4.8, 1.6, 3.6)
	ModelsBase.part(root, pr, roof, Vector3(0, 3.0, 0))
	ModelsBase.part(root, ModelsBase.box(0.9, 1.5, 0.1), wood, Vector3(0, 0.75, 1.62))
	ModelsBase.part(root, ModelsBase.box(0.8, 0.7, 0.08), glass, Vector3(-1.3, 1.3, 1.62))
	ModelsBase.part(root, ModelsBase.box(0.8, 0.7, 0.08), glass, Vector3(1.3, 1.3, 1.62))
	ModelsBase.part(root, ModelsBase.box(0.5, 1.2, 0.5), ModelsBase.toon(Color("8a8078")), Vector3(1.3, 3.4, -0.6))
	ModelsBase.part(root, ModelsBase.box(4.4, 0.25, 3.4), wood, Vector3(0, 0.12, 0))
	return root

static func plot() -> Node3D:
	var root := Node3D.new()
	var soil := ModelsBase.toon(Color("6b4a33")); var dark := ModelsBase.toon(Color("4e3424"))
	ModelsBase.part(root, ModelsBase.box(1.7, 0.2, 1.7), soil, Vector3(0, 0.1, 0))
	for i in 3:
		ModelsBase.part(root, ModelsBase.box(1.5, 0.05, 0.14), dark, Vector3(0, 0.21, -0.5 + i * 0.5))
	# watered soil: darker and a little shiny
	var wet := ModelsBase.part(root, ModelsBase.box(1.66, 0.02, 1.66), ModelsBase.toon(Color("3a2618"), false, 0.25), Vector3(0, 0.205, 0), Vector3.ONE, Vector3.ZERO, "Wet")
	wet.visible = false
	var crop := Node3D.new(); crop.name = "Crop"; root.add_child(crop)
	return root

static func crop(stage: int, grow: int, col: Color) -> Node3D:
	var root := Node3D.new()
	var leaf := ModelsBase.toon(Color("5aa04a"))
	var k := clampf(float(stage) / float(grow), 0.0, 1.0)
	for i in 3:
		var x := -0.5 + i * 0.5
		if stage <= 0:
			ModelsBase.part(root, ModelsBase.sphere(0.06, 6), ModelsBase.toon(Color("8a6a45")), Vector3(x, 0.25, 0))
			continue
		var hgt := 0.15 + k * 0.45
		ModelsBase.part(root, ModelsBase.cyl(0.03, 0.04, hgt, 6), leaf, Vector3(x, 0.2 + hgt * 0.5, 0))
		ModelsBase.part(root, ModelsBase.sphere(0.12 + k * 0.12, 8), leaf, Vector3(x, 0.22 + hgt, 0), Vector3(1.2, 0.6, 1.2))
		if stage >= grow:
			ModelsBase.part(root, ModelsBase.sphere(0.13, 10), ModelsBase.toon(col, true, 0.25), Vector3(x + 0.08, 0.3 + hgt, 0.08))
	return root

static func cauldron() -> Node3D:
	var root := Node3D.new()
	var iron := ModelsBase.toon(Color("3a3a44"))
	ModelsBase.part(root, ModelsBase.sphere(0.6), iron, Vector3(0, 0.55, 0), Vector3(1, 0.8, 1))
	var t := TorusMesh.new(); t.inner_radius = 0.45; t.outer_radius = 0.58
	ModelsBase.part(root, t, iron, Vector3(0, 0.9, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.47, 0.47, 0.04, 20), ModelsBase.toon(Color("7fe0a0"), false, 0.6), Vector3(0, 0.9, 0))
	for i in 3:
		var a := i * TAU / 3.0
		ModelsBase.part(root, ModelsBase.cyl(0.05, 0.05, 0.4), iron, Vector3(cos(a) * 0.4, 0.15, sin(a) * 0.4))
	ModelsBase.part(root, ModelsBase.box(0.5, 0.15, 0.5), ModelsBase.toon(Color("ff9a4a"), false, 1.0), Vector3(0, 0.08, 0))
	return root

static func stall() -> Node3D:
	var root := Node3D.new()
	var wood := ModelsBase.toon(Color("8a5a35"))
	ModelsBase.part(root, ModelsBase.box(2.2, 0.9, 0.9), wood, Vector3(0, 0.45, 0))
	for x in [-1.0, 1.0]:
		ModelsBase.part(root, ModelsBase.cyl(0.06, 0.06, 2.0), wood, Vector3(x, 1.0, -0.35))
		ModelsBase.part(root, ModelsBase.cyl(0.06, 0.06, 2.0), wood, Vector3(x, 1.0, 0.35))
	for i in 4:
		ModelsBase.part(root, ModelsBase.box(0.56, 0.08, 1.2), ModelsBase.toon(Color("e0607e") if i % 2 == 0 else Color("f3eee2")), Vector3(-0.84 + i * 0.56, 2.05, 0), Vector3.ONE, Vector3(0.25, 0, 0))
	for i in 3:
		ModelsBase.part(root, ModelsBase.sphere(0.14), ModelsBase.toon([Color("ff6a4a"), Color("5ab8f0"), Color("f2c84a")][i]), Vector3(-0.6 + i * 0.6, 1.0, 0))
	return root

static func fence(length: float) -> Node3D:
	var root := Node3D.new()
	var wood := ModelsBase.toon(Color("a07a52"))
	var posts := maxi(2, int(length / 1.0) + 1)
	for i in posts:
		var x := -length * 0.5 + length * float(i) / float(posts - 1)
		ModelsBase.part(root, ModelsBase.box(0.12, 0.7, 0.12), wood, Vector3(x, 0.35, 0))
	ModelsBase.part(root, ModelsBase.box(length, 0.08, 0.06), wood, Vector3(0, 0.5, 0))
	ModelsBase.part(root, ModelsBase.box(length, 0.08, 0.06), wood, Vector3(0, 0.25, 0))
	return root

static func lamp() -> Node3D:
	var root := Node3D.new()
	var iron := ModelsBase.toon(Color("3a3a44"))
	ModelsBase.part(root, ModelsBase.cyl(0.06, 0.08, 1.9), iron, Vector3(0, 0.95, 0))
	ModelsBase.part(root, ModelsBase.box(0.3, 0.06, 0.3), iron, Vector3(0, 1.95, 0))
	ModelsBase.part(root, ModelsBase.box(0.22, 0.28, 0.22), ModelsBase.toon(Color("ffd98a"), false, 1.4), Vector3(0, 2.12, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.0, 0.2, 0.18), iron, Vector3(0, 2.34, 0))
	var l := OmniLight3D.new()
	l.light_color = Color("ffd9a8"); l.light_energy = 0.55; l.omni_range = 4.0
	l.position = Vector3(0, 2.1, 0)
	root.add_child(l)
	return root

static func pond(rx: float, rz: float) -> Node3D:
	var root := Node3D.new()
	var rim := ModelsBase.toon(Color("8d8a86"))
	ModelsBase.part(root, ModelsBase.cyl(1.0, 1.0, 0.06, 28), ModelsBase.toon(Color("3d78a8"), false, 0.12), Vector3(0, 0.03, 0), Vector3(rx, 1, rz))
	for i in 14:
		var a := TAU * i / 14.0
		ModelsBase.part(root, ModelsBase.sphere(0.2, 6), rim, Vector3(cos(a) * rx, 0.06, sin(a) * rz), Vector3(1.2, 0.6, 1.0))
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		ModelsBase.part(root, ModelsBase.cyl(0.18, 0.18, 0.02, 10), ModelsBase.toon(Color("5fae4f"), false), Vector3(cos(a) * rx * 0.5, 0.08, sin(a) * rz * 0.45))
	return root

static func flower_bed(rng: RandomNumberGenerator, n := 7) -> Node3D:
	var root := Node3D.new()
	var cols := [Color("ff8fb0"), Color("ffd35a"), Color("b48cf2"), Color("ff7a5a"), Color("ffffff")]
	for i in n:
		var p := Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.35, 0.35))
		ModelsBase.part(root, ModelsBase.cyl(0.02, 0.02, 0.3, 4), ModelsBase.toon(Color("4f8a3e"), false), p + Vector3(0, 0.15, 0))
		ModelsBase.part(root, ModelsBase.sphere(0.08, 6), ModelsBase.toon(cols[rng.randi_range(0, cols.size() - 1)], false, 0.2), p + Vector3(0, 0.32, 0))
	return root

static func kin_bed(c: Color) -> Node3D:
	var root := Node3D.new()
	ModelsBase.part(root, ModelsBase.cyl(0.42, 0.46, 0.14, 16), ModelsBase.toon(c.darkened(0.25)), Vector3(0, 0.07, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.32, 0.32, 0.06, 16), ModelsBase.toon(c.lightened(0.25)), Vector3(0, 0.14, 0))
	return root

static func signpost(text_lines: Array) -> Node3D:
	var root := Node3D.new()
	var wood := ModelsBase.toon(Color("8a5a35"))
	ModelsBase.part(root, ModelsBase.box(0.12, 1.4, 0.12), wood, Vector3(0, 0.7, 0))
	ModelsBase.part(root, ModelsBase.box(1.1, 0.4, 0.08), ModelsBase.toon(Color("c49a6a")), Vector3(0, 1.25, 0.05))
	var l := Label3D.new()
	l.text = "\n".join(text_lines)
	l.font = load("res://fonts/LilitaOne-Regular.ttf")
	l.font_size = 40; l.pixel_size = 0.005; l.modulate = Color("3a2a1a"); l.outline_size = 0
	l.position = Vector3(0, 1.25, 0.1)
	root.add_child(l)
	return root

# ---------------------------------------------------------------- home buildings
static func building(id: String) -> Node3D:
	if id in ["armory", "shrine"]:
		return EconModels.building(id)
	var root := Node3D.new()
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	var wood := ModelsBase.toon(Color("7a5236")); var stone := ModelsBase.toon(Color("9a948c")); var dark := ModelsBase.toon(Color("4a4550"))
	var glass := ModelsBase.toon(Color("ffd98a"), false, 0.8)
	match id:
		"workshop":
			ModelsBase.part(body, ModelsBase.box(3.0, 1.9, 2.4), ModelsBase.toon(Color("d9c3a0")), Vector3(0, 0.95, -0.1))
			var pr := PrismMesh.new(); pr.size = Vector3(3.5, 1.2, 2.8)
			ModelsBase.part(body, pr, ModelsBase.toon(Color("4f6a8a")), Vector3(0, 2.5, -0.1))
			ModelsBase.part(body, ModelsBase.box(1.3, 1.3, 0.08), dark, Vector3(-0.5, 0.65, 1.12))
			ModelsBase.part(body, ModelsBase.box(0.6, 0.5, 0.08), glass, Vector3(0.85, 1.2, 1.12))
			ModelsBase.part(body, ModelsBase.box(0.4, 1.4, 0.4), stone, Vector3(1.1, 2.7, -0.6))
			# anvil and a glider hung up to dry
			ModelsBase.part(body, ModelsBase.box(0.5, 0.35, 0.3), dark, Vector3(1.0, 0.18, 1.6))
			ModelsBase.part(body, ModelsBase.box(0.7, 0.12, 0.3), dark, Vector3(1.0, 0.42, 1.6))
			ModelsBase.part(body, ModelsBase.box(1.6, 0.04, 0.5), ModelsBase.toon(Color("f3eee2")), Vector3(-0.3, 1.75, 1.2), Vector3.ONE, Vector3(-0.4, 0, 0))
			ModelsBase.part(body, ModelsBase.box(0.3, 0.05, 0.52), ModelsBase.toon(Color("ff9a4a")), Vector3(-0.95, 1.76, 1.2), Vector3.ONE, Vector3(-0.4, 0, 0))
		"board":
			# a little guild house with a big notice board out front and pennants on the roof
			ModelsBase.part(body, ModelsBase.box(2.6, 1.6, 1.6), ModelsBase.toon(Color("e8d2b0")), Vector3(0, 0.8, -0.2))
			var pr0 := PrismMesh.new(); pr0.size = Vector3(3.0, 1.1, 2.0)
			ModelsBase.part(body, pr0, ModelsBase.toon(Color("b84a3a")), Vector3(0, 2.15, -0.2))
			ModelsBase.part(body, ModelsBase.box(0.8, 1.2, 0.08), dark, Vector3(-0.6, 0.6, 0.62))
			ModelsBase.part(body, ModelsBase.box(1.3, 0.9, 0.08), wood, Vector3(0.65, 1.05, 0.66))
			for k in 4:
				var pc: Color = [Color("fff6c0"), Color("cfeaff"), Color("ffd6e0"), Color("e0ffd6")][k]
				ModelsBase.part(body, ModelsBase.box(0.26, 0.3, 0.02), ModelsBase.toon(pc, false), Vector3(0.38 + (k % 2) * 0.55, 1.22 - (k / 2) * 0.38, 0.71), Vector3.ONE, Vector3(0, 0, randf_range(-0.12, 0.12)))
			ModelsBase.part(body, ModelsBase.cyl(0.03, 0.03, 1.0, 6), wood, Vector3(0.65, 0.3, 0.66))
			for k in 5:
				ModelsBase.part(body, PrismMesh.new(), ModelsBase.toon([Color("ffd23f"), Color("5ab0f0"), Color("e0607e"), Color("8fd16a"), Color("b48cf2")][k], false), Vector3(-1.2 + k * 0.6, 2.75 - absf(k - 2) * 0.12, -0.2), Vector3(0.22, 0.28, 0.04), Vector3(PI, 0, 0))
			ModelsBase.part(body, ModelsBase.sphere(0.16, 10), ModelsBase.toon(Color("ffd23f"), false, 0.8), Vector3(0, 2.85, -0.2))
		"ransom":
			# Old Pell's Ransom House: a crooked dark-wood shop with a hanging lantern, a kin-shaped
			# sign, and little hutches out front where lost kin wait
			var plum := ModelsBase.toon(Color("5a3f5e")); var trim := ModelsBase.toon(Color("c9a46a"))
			ModelsBase.part(body, ModelsBase.box(2.6, 1.7, 1.7), ModelsBase.toon(Color("6e5a4a")), Vector3(0, 0.85, -0.2))
			var pr1 := PrismMesh.new(); pr1.size = Vector3(3.0, 1.2, 2.1)
			ModelsBase.part(body, pr1, plum, Vector3(0, 2.3, -0.2), Vector3.ONE, Vector3(0, 0, 0.04))
			ModelsBase.part(body, ModelsBase.box(0.8, 1.2, 0.08), dark, Vector3(0.6, 0.6, 0.66))
			ModelsBase.part(body, ModelsBase.box(0.5, 0.45, 0.08), ModelsBase.toon(Color("ffd58a"), false, 0.8), Vector3(-0.6, 1.15, 0.66))
			ModelsBase.part(body, ModelsBase.box(2.8, 0.08, 0.5), trim, Vector3(0, 1.72, 0.6))
			# the sign: a round kin face on a post
			ModelsBase.part(body, ModelsBase.cyl(0.03, 0.03, 0.7, 6), wood, Vector3(-1.45, 1.4, 0.75), Vector3.ONE, Vector3(0, 0, PI / 2))
			ModelsBase.part(body, ModelsBase.cyl(0.3, 0.3, 0.06, 18), trim, Vector3(-1.75, 1.05, 0.75), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(body, ModelsBase.sphere(0.16, 12), ModelsBase.toon(Color("ff9a5a")), Vector3(-1.75, 1.05, 0.8), Vector3(1, 1, 0.4))
			for sx in [-1.0, 1.0]:
				ModelsBase.part(body, ModelsBase.cyl(0.0, 0.06, 0.12, 6), ModelsBase.toon(Color("ff9a5a")), Vector3(-1.75 + 0.09 * sx, 1.22, 0.8))
			# lantern
			ModelsBase.part(body, ModelsBase.cyl(0.01, 0.01, 0.3, 4), dark, Vector3(1.3, 1.6, 0.85))
			ModelsBase.part(body, ModelsBase.sphere(0.11, 10), ModelsBase.toon(Color("ffd25a"), false, 1.2), Vector3(1.3, 1.4, 0.85), Vector3.ONE, Vector3.ZERO, "Lamp")
			# hutches
			for k in 2:
				var hx := -0.5 + k * 1.1
				ModelsBase.part(body, ModelsBase.box(0.6, 0.45, 0.45), wood, Vector3(hx, 0.22, 1.2))
				for b in 3:
					ModelsBase.part(body, ModelsBase.box(0.03, 0.4, 0.03), dark, Vector3(hx - 0.2 + b * 0.2, 0.22, 1.43))
				ModelsBase.part(body, ModelsBase.sphere(0.12, 10), ModelsBase.toon([Color("4aa8e8"), Color("b9a6f5")][k]), Vector3(hx, 0.16, 1.22))
		"cottage", "cottage2":
			var wall := Color("f3dcc4") if id == "cottage" else Color("dfe8cf")
			var roof := Color("5a9ab8") if id == "cottage" else Color("c28a3a")
			ModelsBase.part(body, ModelsBase.box(2.6, 1.5, 2.0), ModelsBase.toon(wall), Vector3(0, 0.75, 0))
			var pr := PrismMesh.new(); pr.size = Vector3(3.0, 1.3, 2.4)
			ModelsBase.part(body, pr, ModelsBase.toon(roof), Vector3(0, 2.15, 0))
			ModelsBase.part(body, ModelsBase.cyl(0.38, 0.38, 0.08, 16), wood, Vector3(0, 0.38, 1.02), Vector3(1, 1, 1), Vector3(PI / 2, 0, 0))
			ModelsBase.part(body, ModelsBase.cyl(0.25, 0.25, 0.06, 12), glass, Vector3(0.85, 1.0, 1.02), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(body, ModelsBase.cyl(0.25, 0.25, 0.06, 12), glass, Vector3(-0.85, 1.0, 1.02), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(body, ModelsBase.box(0.7, 0.16, 0.2), wood, Vector3(0.85, 0.66, 1.1))
			for i in 3:
				ModelsBase.part(body, ModelsBase.sphere(0.08, 6), ModelsBase.toon([Color("ff8fb0"), Color("ffd35a"), Color("b48cf2")][i], false, 0.2), Vector3(0.62 + i * 0.22, 0.8, 1.12))
			ModelsBase.part(body, ModelsBase.sphere(0.2, 8), ModelsBase.toon(Color("ffb3c6"), false, 0.5), Vector3(0, 2.9, 0))
		"greenhouse":
			var frame := ModelsBase.toon(Color("f0f0ea"))
			var pane := ModelsBase.glow_mat(Color(0.7, 0.95, 1.0, 0.22))
			ModelsBase.part(body, ModelsBase.box(3.6, 0.2, 2.8), stone, Vector3(0, 0.1, 0))
			ModelsBase.part(body, ModelsBase.box(3.4, 1.6, 2.6), pane, Vector3(0, 1.0, 0))
			var pr := PrismMesh.new(); pr.size = Vector3(3.5, 1.0, 2.7)
			ModelsBase.part(body, pr, pane, Vector3(0, 2.3, 0))
			for x in [-1.7, -0.57, 0.57, 1.7]:
				ModelsBase.part(body, ModelsBase.box(0.08, 1.7, 0.08), frame, Vector3(x, 1.0, 1.3))
				ModelsBase.part(body, ModelsBase.box(0.08, 1.7, 0.08), frame, Vector3(x, 1.0, -1.3))
			ModelsBase.part(body, ModelsBase.box(3.5, 0.08, 0.08), frame, Vector3(0, 1.8, 1.3))
			ModelsBase.part(body, ModelsBase.box(3.5, 0.08, 0.08), frame, Vector3(0, 1.8, -1.3))
			ModelsBase.part(body, ModelsBase.box(3.5, 0.08, 0.08), frame, Vector3(0, 2.8, 0))
			for i in 6:
				var px := -1.2 + (i % 3) * 1.2; var pz := -0.6 + (i / 3) * 1.2
				ModelsBase.part(body, ModelsBase.cyl(0.2, 0.16, 0.3, 8), ModelsBase.toon(Color("b4553f")), Vector3(px, 0.35, pz))
				ModelsBase.part(body, ModelsBase.sphere(0.3, 8), ModelsBase.toon(Color("5aa04a")), Vector3(px, 0.75, pz), Vector3(1, 1.2, 1))
		"dojo":
			for side in [[Vector3(0, 0, -1.6), 0.0], [Vector3(0, 0, 1.6), 0.0], [Vector3(-1.9, 0, 0), PI / 2], [Vector3(1.9, 0, 0), PI / 2]]:
				var f := fence(3.2 if side[1] == 0.0 else 3.2)
				f.position = side[0]; f.rotation.y = side[1]
				body.add_child(f)
			ModelsBase.part(body, ModelsBase.box(3.6, 0.04, 3.0), ModelsBase.toon(Color("c9a77a")), Vector3(0, 0.02, 0))
			for x in [-0.9, 0.9]:
				ModelsBase.part(body, ModelsBase.cyl(0.07, 0.07, 1.3), wood, Vector3(x, 0.65, -0.3))
				ModelsBase.part(body, ModelsBase.capsule(0.28, 0.8), ModelsBase.toon(Color("d8b98a")), Vector3(x, 1.05, -0.3))
				ModelsBase.part(body, ModelsBase.cyl(0.2, 0.2, 0.04, 14), ModelsBase.toon(Color("e0607e")), Vector3(x, 1.15, -0.02), Vector3.ONE, Vector3(PI / 2, 0, 0))
				ModelsBase.part(body, ModelsBase.cyl(0.08, 0.08, 0.05, 10), ModelsBase.toon(Color("f3eee2")), Vector3(x, 1.15, 0.01), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(body, ModelsBase.box(1.4, 0.12, 0.4), wood, Vector3(0, 0.4, 1.1))
			ModelsBase.part(body, ModelsBase.box(0.1, 0.4, 0.3), wood, Vector3(-0.6, 0.2, 1.1))
			ModelsBase.part(body, ModelsBase.box(0.1, 0.4, 0.3), wood, Vector3(0.6, 0.2, 1.1))
		"vault":
			ModelsBase.part(body, ModelsBase.box(3.0, 2.0, 2.2), stone, Vector3(0, 1.0, 0))
			ModelsBase.part(body, ModelsBase.box(3.3, 0.3, 2.5), ModelsBase.toon(Color("7a746c")), Vector3(0, 2.15, 0))
			ModelsBase.part(body, ModelsBase.cyl(0.7, 0.7, 0.12, 24), ModelsBase.toon(Color("6a6f7a")), Vector3(0, 0.95, 1.1), Vector3.ONE, Vector3(PI / 2, 0, 0))
			var t := TorusMesh.new(); t.inner_radius = 0.5; t.outer_radius = 0.66
			ModelsBase.part(body, t, ModelsBase.toon(Color("f2c84a"), true, 0.3), Vector3(0, 0.95, 1.17), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(body, ModelsBase.box(0.5, 0.08, 0.08), ModelsBase.toon(Color("f2c84a")), Vector3(0, 0.95, 1.2))
			var g := ModelsWorld.gem(); g.position = Vector3(0, 2.75, 0); g.scale = Vector3.ONE * 1.8; g.name = "Gem"; body.add_child(g)
		"hall":
			ModelsBase.part(body, ModelsBase.box(3.2, 0.3, 2.6), ModelsBase.toon(Color("e8e2d6")), Vector3(0, 0.15, 0))
			ModelsBase.part(body, ModelsBase.box(3.0, 0.2, 2.4), ModelsBase.toon(Color("d8d0c0")), Vector3(0, 0.38, 0))
			for x in [-1.2, -0.4, 0.4, 1.2]:
				for z in [-0.9, 0.9]:
					ModelsBase.part(body, ModelsBase.cyl(0.15, 0.17, 1.8, 10), ModelsBase.toon(Color("f3eee2")), Vector3(x, 1.38, z))
			ModelsBase.part(body, ModelsBase.box(3.2, 0.25, 2.6), ModelsBase.toon(Color("e8e2d6")), Vector3(0, 2.38, 0))
			var pr := PrismMesh.new(); pr.size = Vector3(3.4, 0.7, 2.8)
			ModelsBase.part(body, pr, ModelsBase.toon(Color("b4553f")), Vector3(0, 2.85, 0))
			var gold := ModelsBase.toon(Color("f2c84a"), true, 0.4)
			ModelsBase.part(body, ModelsBase.cyl(0.16, 0.08, 0.2, 10), gold, Vector3(0, 0.6, 0))
			ModelsBase.part(body, ModelsBase.cyl(0.25, 0.12, 0.35, 12), gold, Vector3(0, 0.88, 0))
			ModelsBase.part(body, ModelsBase.sphere(0.09, 8), gold, Vector3(0.26, 0.95, 0))
			ModelsBase.part(body, ModelsBase.sphere(0.09, 8), gold, Vector3(-0.26, 0.95, 0))
	return root

## An empty building site: corner stakes, a rope line, a stack of planks and a sign.
static func lot(w: float, d: float, title: String, price: String) -> Node3D:
	var root := Node3D.new()
	var wood := ModelsBase.toon(Color("a07a52"))
	var rope := ModelsBase.toon(Color("e8d8b0"), false)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		ModelsBase.part(root, ModelsBase.box(0.1, 0.5, 0.1), wood, Vector3(c.x * w * 0.5, 0.25, c.y * d * 0.5))
	ModelsBase.part(root, ModelsBase.box(w, 0.03, 0.03), rope, Vector3(0, 0.42, -d * 0.5))
	ModelsBase.part(root, ModelsBase.box(w, 0.03, 0.03), rope, Vector3(0, 0.42, d * 0.5))
	ModelsBase.part(root, ModelsBase.box(0.03, 0.03, d), rope, Vector3(-w * 0.5, 0.42, 0))
	ModelsBase.part(root, ModelsBase.box(0.03, 0.03, d), rope, Vector3(w * 0.5, 0.42, 0))
	for i in 3:
		ModelsBase.part(root, ModelsBase.box(1.2, 0.1, 0.24), ModelsBase.toon(Color("b08a5c").darkened(i * 0.08)), Vector3(-w * 0.18, 0.06 + i * 0.11, -d * 0.15 + i * 0.03), Vector3.ONE, Vector3(0, i * 0.15, 0))
	ModelsBase.part(root, ModelsBase.box(0.5, 0.4, 0.5), ModelsBase.toon(Color("8d8a86")), Vector3(w * 0.22, 0.2, -d * 0.2))
	var s := signpost([title, price])
	s.position = Vector3(0, 0, d * 0.5 + 0.35)
	s.name = "Sign"
	root.add_child(s)
	return root

## One plank of a bridge, roughly a tile deep and two tiles wide.
static func plank(rng: RandomNumberGenerator, width: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ModelsBase.box(width, 0.14, 0.42)
	mi.material_override = ModelsBase.toon(Color("a07a52").lerp(Color("7a5a3c"), rng.randf()))
	mi.rotation.y = rng.randf_range(-0.04, 0.04)
	return mi


## The ferry stop at home: a post with a bell and a sign, and a short jetty.
static func ferry_post() -> Node3D:
	var root := Node3D.new()
	var wood := ModelsBase.toon(Color("7a5236"))
	ModelsBase.part(root, ModelsBase.box(0.16, 2.2, 0.16), wood, Vector3(0, 1.1, 0))
	ModelsBase.part(root, ModelsBase.box(0.9, 0.1, 0.1), wood, Vector3(0.38, 2.1, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.06, 0.18, 0.26, 12), ModelsBase.toon(Color("f2c84a"), true, 0.3), Vector3(0.7, 1.86, 0))
	ModelsBase.part(root, ModelsBase.box(1.2, 0.36, 0.08), ModelsBase.toon(Color("c49a6a")), Vector3(0, 1.3, 0.1))
	var l := Label3D.new(); l.text = "Ferry"; l.font = load("res://fonts/LilitaOne-Regular.ttf")
	l.font_size = 48; l.pixel_size = 0.005; l.modulate = Color("3a2a1a"); l.outline_size = 0; l.position = Vector3(0, 1.3, 0.15)
	root.add_child(l)
	for i in 3:
		ModelsBase.part(root, ModelsBase.box(1.4, 0.08, 0.36), wood, Vector3(0, 0.04, -0.6 - i * 0.38))
	return root


## Guild landmarks.
static func lighthouse(col: Color) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	var white := ModelsBase.toon(Color("f3eee2")); var red := ModelsBase.toon(Color("c0443a"))
	ModelsBase.part(body, ModelsBase.cyl(1.3, 1.5, 0.5, 18), ModelsBase.toon(Color("8d8a86")), Vector3(0, 0.25, 0))
	for i in 4:
		ModelsBase.part(body, ModelsBase.cyl(0.95 - i * 0.12, 1.05 - i * 0.12, 1.4, 16), white if i % 2 == 0 else red, Vector3(0, 1.2 + i * 1.4, 0))
	ModelsBase.part(body, ModelsBase.cyl(0.7, 0.7, 0.9, 12), ModelsBase.toon(col, false, 1.4), Vector3(0, 6.6, 0))
	ModelsBase.part(body, ModelsBase.cyl(0.0, 0.9, 0.8, 12), red, Vector3(0, 7.45, 0))
	var l := OmniLight3D.new(); l.light_color = col; l.light_energy = 1.4; l.omni_range = 9.0; l.position = Vector3(0, 6.6, 0)
	body.add_child(l)
	return root

static func banner(col: Color) -> Node3D:
	var root := Node3D.new()
	ModelsBase.part(root, ModelsBase.cyl(0.06, 0.06, 3.2, 8), ModelsBase.toon(Color("5a4636")), Vector3(0, 1.6, 0))
	ModelsBase.part(root, ModelsBase.box(0.7, 1.1, 0.04), ModelsBase.toon(col), Vector3(0.38, 2.5, 0), Vector3.ONE, Vector3.ZERO, "Flag")
	ModelsBase.part(root, ModelsBase.sphere(0.09, 8), ModelsBase.toon(Color("f2c84a"), true, 0.4), Vector3(0, 3.25, 0))
	return root

static func notice_board() -> Node3D:
	var root := Node3D.new()
	var wood := ModelsBase.toon(Color("7a5236"))
	for x in [-1.0, 1.0]:
		ModelsBase.part(root, ModelsBase.box(0.14, 2.0, 0.14), wood, Vector3(x, 1.0, 0))
	ModelsBase.part(root, ModelsBase.box(2.3, 1.3, 0.1), ModelsBase.toon(Color("c49a6a")), Vector3(0, 1.35, 0))
	ModelsBase.part(root, ModelsBase.box(2.5, 0.14, 0.3), wood, Vector3(0, 2.05, 0))
	var cols := [Color("f3eee2"), Color("ffe08a"), Color("cfe8ff"), Color("ffd0dc")]
	for i in 5:
		ModelsBase.part(root, ModelsBase.box(0.42, 0.5, 0.02), ModelsBase.toon(cols[i % 4]), Vector3(-0.8 + i * 0.4, 1.35 + (0.12 if i % 2 else -0.1), 0.07), Vector3.ONE, Vector3(0, 0, (i - 2) * 0.06))
	return root

static func fountain() -> Node3D:
	var root := Node3D.new()
	var stone := ModelsBase.toon(Color("b8b2a8"))
	ModelsBase.part(root, ModelsBase.cyl(1.8, 1.9, 0.5, 24), stone, Vector3(0, 0.25, 0))
	ModelsBase.part(root, ModelsBase.cyl(1.55, 1.55, 0.06, 24), ModelsBase.toon(Color("3d78a8"), false, 0.15), Vector3(0, 0.48, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.3, 0.4, 1.3, 12), stone, Vector3(0, 1.0, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.7, 0.5, 0.2, 16), stone, Vector3(0, 1.7, 0))
	var sp := CPUParticles3D.new(); sp.name = "Spray"
	sp.amount = 40; sp.lifetime = 0.9
	var m := SphereMesh.new(); m.radius = 0.05; m.height = 0.1; m.radial_segments = 6; m.rings = 3
	var pm := StandardMaterial3D.new(); pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pm.albedo_color = Color(0.75, 0.9, 1.0, 0.8); pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = pm; sp.mesh = m
	sp.direction = Vector3.UP; sp.spread = 18.0; sp.initial_velocity_min = 2.5; sp.initial_velocity_max = 3.4
	sp.gravity = Vector3(0, -9, 0); sp.position = Vector3(0, 1.8, 0)
	root.add_child(sp)
	return root


## Furniture for building interiors, built at the origin of its footprint's first tile and
## spanning size[0] x size[1] tiles along +x / +z.
static func furniture(id: String) -> Node3D:
	var root := Node3D.new()
	var wood := ModelsBase.toon(Color("8a5a3a")); var dark := ModelsBase.toon(Color("5e3c26")); var light := ModelsBase.toon(Color("c99a6a"))
	var cloth := ModelsBase.toon(Color("d9604a")); var cream := ModelsBase.toon(Color("f1e6cf")); var leaf := ModelsBase.toon(Color("4f9a4a")); var pot := ModelsBase.toon(Color("c0663e"))
	var metal := ModelsBase.toon(Color("3d3f4a"))
	match id:
		"bed":
			ModelsBase.part(root, ModelsBase.box(1.8, 0.35, 2.8), wood, Vector3(1.0, 0.25, 1.5))
			ModelsBase.part(root, ModelsBase.box(1.7, 0.18, 2.5), cream, Vector3(1.0, 0.5, 1.55))
			ModelsBase.part(root, ModelsBase.box(1.72, 0.12, 1.6), cloth, Vector3(1.0, 0.62, 2.0))
			ModelsBase.part(root, ModelsBase.box(0.9, 0.16, 0.45), ModelsBase.toon(Color("fffaf0")), Vector3(1.0, 0.66, 0.5))
			ModelsBase.part(root, ModelsBase.box(1.9, 0.9, 0.12), dark, Vector3(1.0, 0.55, 0.12))
		"kin_bed":
			ModelsBase.part(root, ModelsBase.cyl(0.42, 0.36, 0.22, 16), ModelsBase.toon(Color("c9a46a")), Vector3(0.5, 0.11, 0.5))
			ModelsBase.part(root, ModelsBase.cyl(0.32, 0.32, 0.06, 16), ModelsBase.toon(Color("e8b0c0")), Vector3(0.5, 0.2, 0.5))
		"table":
			ModelsBase.part(root, ModelsBase.box(1.8, 0.1, 0.9), light, Vector3(1.0, 0.72, 0.5))
			for p in [Vector3(0.2, 0.36, 0.15), Vector3(1.8, 0.36, 0.15), Vector3(0.2, 0.36, 0.85), Vector3(1.8, 0.36, 0.85)]:
				ModelsBase.part(root, ModelsBase.box(0.1, 0.72, 0.1), wood, p)
			ModelsBase.part(root, ModelsBase.cyl(0.1, 0.08, 0.14, 10), ModelsBase.toon(Color("e0e8f0")), Vector3(0.6, 0.84, 0.5))
		"chair":
			ModelsBase.part(root, ModelsBase.box(0.55, 0.08, 0.55), light, Vector3(0.5, 0.45, 0.5))
			ModelsBase.part(root, ModelsBase.box(0.55, 0.55, 0.08), wood, Vector3(0.5, 0.72, 0.25))
			for p in [Vector3(0.28, 0.22, 0.28), Vector3(0.72, 0.22, 0.28), Vector3(0.28, 0.22, 0.72), Vector3(0.72, 0.22, 0.72)]:
				ModelsBase.part(root, ModelsBase.box(0.07, 0.45, 0.07), wood, p)
		"stool":
			ModelsBase.part(root, ModelsBase.cyl(0.25, 0.25, 0.08, 12), light, Vector3(0.5, 0.45, 0.5))
			ModelsBase.part(root, ModelsBase.cyl(0.06, 0.1, 0.42, 8), wood, Vector3(0.5, 0.21, 0.5))
		"rug":
			ModelsBase.part(root, ModelsBase.box(2.9, 0.03, 1.9), ModelsBase.toon(Color("6a4c8c"), false), Vector3(1.5, 0.015, 1.0))
			ModelsBase.part(root, ModelsBase.box(2.5, 0.035, 1.5), ModelsBase.toon(Color("e0b25a"), false), Vector3(1.5, 0.02, 1.0))
			ModelsBase.part(root, ModelsBase.box(2.1, 0.04, 1.1), ModelsBase.toon(Color("6a4c8c"), false), Vector3(1.5, 0.025, 1.0))
		"rug_round":
			ModelsBase.part(root, ModelsBase.cyl(0.95, 0.95, 0.03, 28), ModelsBase.toon(Color("3f7a8c"), false), Vector3(1.0, 0.015, 1.0))
			ModelsBase.part(root, ModelsBase.cyl(0.6, 0.6, 0.035, 28), ModelsBase.toon(Color("f2e8d2"), false), Vector3(1.0, 0.02, 1.0))
		"lamp":
			ModelsBase.part(root, ModelsBase.cyl(0.18, 0.22, 0.06, 12), metal, Vector3(0.5, 0.03, 0.5))
			ModelsBase.part(root, ModelsBase.cyl(0.03, 0.03, 1.4, 8), metal, Vector3(0.5, 0.72, 0.5))
			ModelsBase.part(root, ModelsBase.cyl(0.16, 0.28, 0.32, 14), ModelsBase.toon(Color("ffe9b8"), false, 0.8), Vector3(0.5, 1.45, 0.5))
			var ol := OmniLight3D.new(); ol.light_color = Color("ffd9a0"); ol.light_energy = 1.4; ol.omni_range = 4.5
			ol.position = Vector3(0.5, 1.4, 0.5); root.add_child(ol)
		"plant":
			ModelsBase.part(root, ModelsBase.cyl(0.2, 0.15, 0.3, 12), pot, Vector3(0.5, 0.15, 0.5))
			ModelsBase.part(root, ModelsBase.sphere(0.28), leaf, Vector3(0.5, 0.48, 0.5), Vector3(1, 0.9, 1))
		"big_plant":
			ModelsBase.part(root, ModelsBase.cyl(0.26, 0.2, 0.4, 12), pot, Vector3(0.5, 0.2, 0.5))
			ModelsBase.part(root, ModelsBase.cyl(0.04, 0.05, 0.7, 6), dark, Vector3(0.5, 0.7, 0.5))
			for i in 4:
				var a := TAU * i / 4.0
				ModelsBase.part(root, ModelsBase.sphere(0.26), leaf, Vector3(0.5 + cos(a) * 0.18, 1.1 + (i % 2) * 0.12, 0.5 + sin(a) * 0.18))
		"shelf":
			ModelsBase.part(root, ModelsBase.box(1.8, 1.8, 0.45), wood, Vector3(1.0, 0.9, 0.3))
			for row in 3:
				for b in 7:
					ModelsBase.part(root, ModelsBase.box(0.17, 0.42, 0.3), ModelsBase.toon([Color("c0443a"), Color("3f6a9c"), Color("d9b04a"), Color("4f8a5a")][(row + b) % 4]), Vector3(0.35 + b * 0.22, 0.42 + row * 0.55, 0.38))
		"chest":
			ModelsBase.part(root, ModelsBase.box(0.8, 0.5, 0.55), wood, Vector3(0.5, 0.25, 0.5))
			ModelsBase.part(root, ModelsBase.box(0.84, 0.1, 0.6), dark, Vector3(0.5, 0.52, 0.5))
			ModelsBase.part(root, ModelsBase.box(0.12, 0.14, 0.04), ModelsBase.toon(Color("e0b84a"), false, 0.3), Vector3(0.5, 0.4, 0.78))
		"stove":
			ModelsBase.part(root, ModelsBase.box(0.85, 0.85, 0.75), metal, Vector3(0.5, 0.42, 0.45))
			ModelsBase.part(root, ModelsBase.box(0.5, 0.3, 0.05), ModelsBase.toon(Color("ff8a3a"), false, 0.9), Vector3(0.5, 0.35, 0.84))
			ModelsBase.part(root, ModelsBase.cyl(0.08, 0.08, 0.8, 8), metal, Vector3(0.5, 1.2, 0.3))
		"fireplace":
			ModelsBase.part(root, ModelsBase.box(1.9, 1.2, 0.6), ModelsBase.toon(Color("9a8f86")), Vector3(1.0, 0.6, 0.35))
			ModelsBase.part(root, ModelsBase.box(1.0, 0.6, 0.3), ModelsBase.toon(Color("2a2024")), Vector3(1.0, 0.35, 0.55))
			ModelsBase.part(root, ModelsBase.sphere(0.22), ModelsBase.toon(Color("ff9a3a"), false, 1.0), Vector3(1.0, 0.25, 0.6), Vector3(1.4, 0.8, 1))
			var fl := OmniLight3D.new(); fl.light_color = Color("ffb070"); fl.light_energy = 1.6; fl.omni_range = 5.0
			fl.position = Vector3(1.0, 0.5, 0.9); root.add_child(fl)
		"wardrobe":
			ModelsBase.part(root, ModelsBase.box(1.8, 2.0, 0.6), wood, Vector3(1.0, 1.0, 0.35))
			ModelsBase.part(root, ModelsBase.box(0.04, 1.8, 0.02), dark, Vector3(1.0, 1.0, 0.66))
			for x in [0.85, 1.15]:
				ModelsBase.part(root, ModelsBase.sphere(0.04), ModelsBase.toon(Color("e0b84a")), Vector3(x, 1.0, 0.68))
		"fishbowl":
			ModelsBase.part(root, ModelsBase.box(0.6, 0.6, 0.6), wood, Vector3(0.5, 0.3, 0.5))
			ModelsBase.part(root, ModelsBase.sphere(0.28), ModelsBase.toon(Color(0.6, 0.85, 1.0), false, 0.3), Vector3(0.5, 0.86, 0.5))
			ModelsBase.part(root, ModelsBase.sphere(0.06), ModelsBase.toon(Color("ff8a3a")), Vector3(0.55, 0.84, 0.5), Vector3(1.4, 1, 1))
		"easel":
			ModelsBase.part(root, ModelsBase.box(0.06, 1.4, 0.06), wood, Vector3(0.3, 0.7, 0.55), Vector3.ONE, Vector3(0.12, 0, 0.1))
			ModelsBase.part(root, ModelsBase.box(0.06, 1.4, 0.06), wood, Vector3(0.7, 0.7, 0.55), Vector3.ONE, Vector3(0.12, 0, -0.1))
			ModelsBase.part(root, ModelsBase.box(0.8, 0.6, 0.04), ModelsBase.toon(Color("f6efe0")), Vector3(0.5, 1.05, 0.45), Vector3.ONE, Vector3(-0.12, 0, 0))
			ModelsBase.part(root, ModelsBase.sphere(0.14), ModelsBase.toon(Color("f2a24a")), Vector3(0.45, 1.08, 0.42), Vector3(1, 1, 0.2))
			ModelsBase.part(root, ModelsBase.box(0.6, 0.12, 0.02), ModelsBase.toon(Color("5aa04a")), Vector3(0.5, 0.86, 0.43))
		"trophy":
			ModelsBase.part(root, ModelsBase.box(0.6, 0.7, 0.6), dark, Vector3(0.5, 0.35, 0.5))
			ModelsBase.part(root, ModelsBase.cyl(0.18, 0.08, 0.3, 12), ModelsBase.toon(Color("f2c84a"), false, 0.5), Vector3(0.5, 0.95, 0.5))
			ModelsBase.part(root, ModelsBase.cyl(0.1, 0.12, 0.08, 10), ModelsBase.toon(Color("f2c84a"), false, 0.5), Vector3(0.5, 0.74, 0.5))
		"cushion":
			ModelsBase.part(root, ModelsBase.cyl(0.38, 0.4, 0.16, 16), ModelsBase.toon(Color("e07a9a")), Vector3(0.5, 0.08, 0.5))
		"toy_ball":
			ModelsBase.part(root, ModelsBase.sphere(0.18), ModelsBase.toon(Color("ff6a5a")), Vector3(0.5, 0.18, 0.5))
			ModelsBase.part(root, ModelsBase.cyl(0.185, 0.185, 0.04, 16), ModelsBase.toon(Color("fff0d8")), Vector3(0.5, 0.18, 0.5), Vector3.ONE, Vector3(0, 0, PI / 2))
	return root
