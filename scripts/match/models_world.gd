class_name ModelsWorld
## Monsters, world props and interactable icons. Moved out of Models; callers still use the Models facade.


# ---------------------------------------------------------------- monsters
static func mob(kind: String) -> Node3D:
	if kind == "shrubling":
		return ShrublingModel.build(Color("5f9a46"))      # (Shrubling re-dresses it in its island's leaf colour)
	var md: Dictionary = Data.MOBS[kind]
	if md.get("blight", false):
		return BlightModels.build(kind)
	if md.get("boss", false) or md.get("ward", false):
		return BossModels.build(kind)
	if Flora.v2():
		return MobModels.build(kind)
	var pk := Assets.mob(kind, md["color"]) if Assets.on() else null
	if pk:
		if kind == "warden":
			# the boss: half again as big, a gold crown and a violet heart-gem
			pk.scale = Vector3.ONE * 1.5
			var gold := ModelsBase.toon(Color("f2c84a"), true, 0.5)
			var crown := Node3D.new(); crown.position = Vector3(0, 1.78, 0); pk.get_node("Body").add_child(crown)
			for i in 5:
				var a := TAU * i / 5.0
				ModelsBase.part(crown, ModelsBase.cyl(0.0, 0.07, 0.24, 6), gold, Vector3(cos(a) * 0.2, 0.12, sin(a) * 0.2))
			ModelsBase.part(crown, ModelsBase.cyl(0.24, 0.24, 0.08, 14), gold, Vector3.ZERO)
			ModelsBase.part(pk.get_node("Body"), ModelsBase.sphere(0.11, 8), ModelsBase.toon(Color("c9a0ff"), false, 1.2), Vector3(0, 1.15, -0.22))
			(pk.get_meta("mats") as Array).append(gold)
		return pk
	var root := Node3D.new()
	var mats: Array = []
	var m := ModelsBase.toon(md["color"]); mats.append(m)
	var m_dark := ModelsBase.toon(Color(md["color"]).darkened(0.5)); mats.append(m_dark)
	var m_eye := ModelsBase.toon(Color("ffe25a"), false, 1.2); mats.append(m_eye)
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	match kind:
		"skitter":
			# a scuttling beetle: domed shell with a seam, mandibles, six jointed legs on pivots
			ModelsBase.part(body, ModelsBase.sphere(0.36), m_dark, Vector3(0, 0.36, 0.02), Vector3(1.05, 0.62, 1.2))
			ModelsBase.part(body, ModelsBase.sphere(0.36), m, Vector3(0, 0.44, 0.06), Vector3(1.0, 0.62, 1.15))
			ModelsBase.part(body, ModelsBase.box(0.03, 0.05, 0.62), m_dark, Vector3(0, 0.66, 0.08), Vector3.ONE, Vector3(-0.08, 0, 0))
			ModelsBase.part(body, ModelsBase.sphere(0.2), m_dark, Vector3(0, 0.36, -0.36), Vector3(1.1, 0.8, 0.9))
			for sx in [-1.0, 1.0]:
				ModelsBase.part(body, ModelsBase.sphere(0.055, 6), m_eye, Vector3(0.1 * sx, 0.44, -0.5))
				var jaw := Node3D.new(); jaw.name = "Jaw" + ("L" if sx < 0 else "R"); jaw.position = Vector3(0.09 * sx, 0.3, -0.5); body.add_child(jaw)
				ModelsBase.part(jaw, ModelsBase.cyl(0.0, 0.035, 0.2, 5), m_dark, Vector3(0.02 * sx, 0, -0.08), Vector3.ONE, Vector3(-PI / 2, 0, -0.5 * sx))
				for i in 3:
					var lg := Node3D.new(); lg.name = "Leg%d%d" % [i, int(sx)]
					lg.position = Vector3(0.24 * sx, 0.3, -0.2 + i * 0.2); body.add_child(lg)
					ModelsBase.part(lg, ModelsBase.box(0.26, 0.05, 0.05), m_dark, Vector3(0.12 * sx, 0.03, 0), Vector3.ONE, Vector3(0, 0, 0.35 * sx))
					ModelsBase.part(lg, ModelsBase.box(0.05, 0.3, 0.05), m_dark, Vector3(0.25 * sx, -0.12, 0), Vector3.ONE, Vector3(0, 0, 0.2 * sx))
		"spitter":
			ModelsBase.part(body, ModelsBase.cyl(0.1, 0.16, 0.6), m_dark, Vector3(0, 0.3, 0))
			ModelsBase.part(body, ModelsBase.sphere(0.36), m, Vector3(0, 0.8, 0), Vector3(1.0, 0.9, 1.0), Vector3.ZERO, "Bulb")
			for i in 5:
				var a2 := TAU * i / 5.0
				ModelsBase.part(body.get_node("Bulb"), ModelsBase.sphere(0.16, 8), m_dark, Vector3(cos(a2) * 0.3, 0.12, sin(a2) * 0.3), Vector3(1.2, 0.3, 0.7), Vector3(0, -a2, 0.6))
			ModelsBase.part(body, ModelsBase.cyl(0.16, 0.2, 0.12), m_eye, Vector3(0, 0.8, -0.3), Vector3.ONE, Vector3(PI / 2, 0, 0))
			for i in 4:
				var a := float(i) / 4.0 * TAU + 0.4
				ModelsBase.part(body, ModelsBase.sphere(0.2), m, Vector3(cos(a) * 0.32, 0.08, sin(a) * 0.32), Vector3(1.4, 0.25, 0.7), Vector3(0, -a, 0))
		"bomber":
			var puff := Node3D.new(); puff.name = "Puff"; body.add_child(puff)
			ModelsBase.part(puff, ModelsBase.sphere(0.42, 16), m, Vector3(0, 0.5, 0))
			for i in 6:
				var a := TAU * i / 6.0
				ModelsBase.part(puff, ModelsBase.sphere(0.12, 8), m_dark, Vector3(cos(a) * 0.36, 0.5 + sin(a * 2.0) * 0.12, sin(a) * 0.36))
			ModelsBase.part(puff, ModelsBase.sphere(0.05, 6), m_eye, Vector3(-0.13, 0.6, -0.38))
			ModelsBase.part(puff, ModelsBase.sphere(0.05, 6), m_eye, Vector3(0.13, 0.6, -0.38))
			ModelsBase.part(puff, ModelsBase.cyl(0.03, 0.03, 0.22, 6), m_dark, Vector3(0, 0.98, 0))
			ModelsBase.part(puff, ModelsBase.sphere(0.07, 8), ModelsBase.toon(Color("ffd25a"), false, 1.4), Vector3(0, 1.11, 0))
		"glimmer":
			var gold := ModelsBase.toon(md["color"], true, 0.8); mats.append(gold)
			ModelsBase.part(body, ModelsBase.sphere(0.36, 16), gold, Vector3(0, 0.42, 0), Vector3(1, 0.9, 1.1))
			ModelsBase.part(body, ModelsBase.sphere(0.14, 10), gold, Vector3(-0.22, 0.76, 0.02), Vector3(0.6, 1.4, 0.6))
			ModelsBase.part(body, ModelsBase.sphere(0.14, 10), gold, Vector3(0.22, 0.76, 0.02), Vector3(0.6, 1.4, 0.6))
			ModelsBase.part(body, ModelsBase.sphere(0.05, 6), ModelsBase.toon(Color("2b2a33")), Vector3(-0.11, 0.5, -0.32))
			ModelsBase.part(body, ModelsBase.sphere(0.05, 6), ModelsBase.toon(Color("2b2a33")), Vector3(0.11, 0.5, -0.32))
			var pm := PrismMesh.new(); pm.size = Vector3(0.2, 0.24, 0.2)
			for i in 3:
				var a := TAU * i / 3.0
				ModelsBase.part(body, pm, ModelsBase.toon(Color("fff4c0"), false, 1.4), Vector3(cos(a) * 0.55, 0.9, sin(a) * 0.55))
		"sentinel":
			var stone := ModelsBase.toon(Color("6a7080")); mats.append(stone)
			var plinth := Assets.prop("halloween/pillar", 0.95, true, {"bright": 1.15, "cache": false}) if Assets.on() else null
			if plinth:
				# a carved stone plinth (pack model) holding the crystal
				plinth.scale = Vector3(1.45, 1.0, 1.45)
				body.add_child(plinth)
				mats.append_array(plinth.get_meta("mats"))
			else:
				ModelsBase.part(body, ModelsBase.cyl(0.42, 0.55, 0.35, 8), stone, Vector3(0, 0.18, 0))
				ModelsBase.part(body, ModelsBase.cyl(0.22, 0.32, 0.6, 8), stone, Vector3(0, 0.6, 0))
			var cr := Node3D.new(); cr.name = "Crystal"; cr.position = Vector3(0, 1.25, 0); body.add_child(cr)
			var pm := PrismMesh.new(); pm.size = Vector3(0.42, 0.5, 0.42)
			var cm := ModelsBase.toon(md["color"], false, 0.9); mats.append(cm)
			ModelsBase.part(cr, pm, cm, Vector3(0, 0.25, 0))
			ModelsBase.part(cr, pm, cm, Vector3(0, -0.25, 0), Vector3.ONE, Vector3(PI, 0, 0))
			ModelsBase.part(cr, ModelsBase.sphere(0.08, 8), m_eye, Vector3(0, 0, -0.2))
		"brute", "warden":
			# a hulking brute: barrel chest, hunched head with tusks, arms and legs on joints so it can swing
			var torso := Node3D.new(); torso.name = "Torso"; torso.position = Vector3(0, 0.62, 0); body.add_child(torso)
			ModelsBase.part(torso, ModelsBase.sphere(0.6, 14), m, Vector3(0, 0.38, 0), Vector3(1.05, 0.85, 0.85))
			ModelsBase.part(torso, ModelsBase.sphere(0.42, 12), ModelsBase.toon(Color(md["color"]).lightened(0.25)), Vector3(0, 0.28, -0.22), Vector3(1.0, 0.85, 0.6))
			ModelsBase.part(torso, ModelsBase.sphere(0.34, 10), m_dark, Vector3(-0.48, 0.66, 0.0), Vector3(1.1, 0.8, 1.0))
			ModelsBase.part(torso, ModelsBase.sphere(0.34, 10), m_dark, Vector3(0.48, 0.66, 0.0), Vector3(1.1, 0.8, 1.0))
			var hd := Node3D.new(); hd.name = "Head"; hd.position = Vector3(0, 0.82, -0.28); torso.add_child(hd)
			ModelsBase.part(hd, ModelsBase.box(0.5, 0.38, 0.42), m_dark, Vector3(0, 0.05, 0))
			ModelsBase.part(hd, ModelsBase.box(0.56, 0.1, 0.2), m_dark, Vector3(0, 0.2, -0.16), Vector3.ONE, Vector3(0.25, 0, 0))
			ModelsBase.part(hd, ModelsBase.sphere(0.055, 6), m_eye, Vector3(-0.12, 0.1, -0.22))
			ModelsBase.part(hd, ModelsBase.sphere(0.055, 6), m_eye, Vector3(0.12, 0.1, -0.22))
			var tusk := ModelsBase.toon(Color("efe6cf")); mats.append(tusk)
			ModelsBase.part(hd, ModelsBase.cyl(0.0, 0.05, 0.18, 6), tusk, Vector3(-0.15, -0.1, -0.22), Vector3.ONE, Vector3(-0.3, 0, 0.25))
			ModelsBase.part(hd, ModelsBase.cyl(0.0, 0.05, 0.18, 6), tusk, Vector3(0.15, -0.1, -0.22), Vector3.ONE, Vector3(-0.3, 0, -0.25))
			for sx in [-1.0, 1.0]:
				var arm := Node3D.new(); arm.name = "ArmL" if sx < 0 else "ArmR"
				arm.position = Vector3(0.62 * sx, 0.62, -0.02); torso.add_child(arm)
				ModelsBase.part(arm, ModelsBase.box(0.3, 0.62, 0.3), m_dark, Vector3(0.04 * sx, -0.3, 0))
				ModelsBase.part(arm, ModelsBase.sphere(0.24, 10), m, Vector3(0.05 * sx, -0.7, -0.02), Vector3(1.0, 0.9, 1.0))
				var leg := Node3D.new(); leg.name = "LegL" if sx < 0 else "LegR"
				leg.position = Vector3(0.26 * sx, 0.58, 0); body.add_child(leg)
				ModelsBase.part(leg, ModelsBase.box(0.3, 0.5, 0.34), m_dark, Vector3(0, -0.28, 0))
				ModelsBase.part(leg, ModelsBase.box(0.34, 0.12, 0.42), m_dark, Vector3(0, -0.52, -0.04))
			if kind == "warden":
				root.scale = Vector3.ONE * 1.5
				var gold := ModelsBase.toon(Color("f2c84a"), true, 0.5); mats.append(gold)
				for sx in [-1.0, 0.0, 1.0]:
					ModelsBase.part(hd, ModelsBase.cyl(0.0, 0.08, 0.3, 6), gold, Vector3(0.15 * sx, 0.42, 0.02))
				ModelsBase.part(hd, ModelsBase.box(0.56, 0.08, 0.46), gold, Vector3(0, 0.28, 0.02))
				ModelsBase.part(torso, ModelsBase.sphere(0.12, 8), ModelsBase.toon(Color("c9a0ff"), false, 1.2), Vector3(0, 0.4, -0.52))
	root.set_meta("mats", mats)
	return root

# ---------------------------------------------------------------- props
## A rough stone: a faceted lump, sometimes a smaller one beside it, often a cap of moss.
static func rock(rng: RandomNumberGenerator, s: float, moss := Color("6f9a4a")) -> Node3D:
	var root := Node3D.new()
	var g := Color("8d8a86").lerp(Color("6f6a73"), rng.randf())
	var m := ModelsBase.toon(g, true)
	m.set_shader_parameter("rim_amount", 0.5)
	var sm := SphereMesh.new(); sm.radius = 0.5; sm.height = 1.0; sm.radial_segments = 7; sm.rings = 4
	var ys := s * rng.randf_range(0.8, 1.3)
	ModelsBase.part(root, sm, m, Vector3(0, 0.42 * ys, 0), Vector3(s * rng.randf_range(0.9, 1.2), ys, s * rng.randf_range(0.9, 1.2)), Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2)))
	if rng.randf() < 0.6:
		ModelsBase.part(root, sm, m, Vector3(rng.randf_range(-0.35, 0.35) * s, 0.2 * s, rng.randf_range(-0.35, 0.35) * s), Vector3.ONE * s * rng.randf_range(0.4, 0.6), Vector3(0, rng.randf() * TAU, 0))
	if rng.randf() < 0.65:
		var mm := SphereMesh.new(); mm.radius = 0.5; mm.height = 0.5; mm.radial_segments = 8; mm.rings = 3; mm.is_hemisphere = true
		ModelsBase.part(root, mm, ModelsBase.toon(moss.darkened(rng.randf_range(0.0, 0.2)), false), Vector3(0, 0.78 * ys, 0), Vector3(s * 0.8, ys * 0.35, s * 0.8))
	return root

## Trees in three styles: "round" (layered leafy canopy), "pine" (tiers of needles) and
## "blossom" (pale pink canopy). Leaf colour comes from the biome; each canopy has a darker
## underside and a lighter top so it reads as a volume from above.
static func tree(rng: RandomNumberGenerator, leaf: Color, style := "round") -> Node3D:
	var root := Node3D.new()
	var bark := Color("6b4a35").lerp(Color("4e3a30"), rng.randf())
	var mt := ModelsBase.toon(bark)
	var h := rng.randf_range(1.7, 2.5)
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	ModelsBase.part(root, ModelsBase.cyl(0.09, 0.16, h * 0.62), mt, Vector3(0, h * 0.31, 0), Vector3.ONE, lean)
	for k in 3:
		var a := TAU * k / 3.0 + rng.randf()
		ModelsBase.part(root, ModelsBase.cyl(0.02, 0.08, 0.36, 6), mt, Vector3(cos(a) * 0.14, 0.08, sin(a) * 0.14), Vector3.ONE, Vector3(sin(a) * 1.1, 0, -cos(a) * 1.1))
	var top := Vector3(lean.z * h * 0.6, h * 0.62, -lean.x * h * 0.6)
	match style:
		"pine":
			var c0 := leaf.lerp(Color("2f5a3a"), 0.45)
			var tiers := 4
			for k in tiers:
				var t := float(k) / tiers
				var r := lerpf(0.85, 0.28, t)
				var shade_c := c0.lerp(c0.lightened(0.25), t)
				ModelsBase.part(root, ModelsBase.cyl(0.0, r, 0.75, 9), ModelsBase.toon(shade_c), top + Vector3(0, -0.15 + k * 0.42, 0), Vector3.ONE, Vector3(0, rng.randf() * TAU, 0))
			if leaf.v > 0.75:
				ModelsBase.part(root, ModelsBase.cyl(0.0, 0.22, 0.3, 9), ModelsBase.toon(Color("f4f8ff")), top + Vector3(0, -0.15 + tiers * 0.42 - 0.05, 0))
		_:
			var base := leaf if style != "blossom" else Color("ffb3d0").lerp(leaf, 0.15)
			var dark := ModelsBase.toon(base.lerp(Color("1f3a2a") if style != "blossom" else Color("c86a9a"), 0.35))
			var mid := ModelsBase.toon(base)
			var light := ModelsBase.toon(base.lightened(0.2).lerp(Color("fff6c0"), 0.08))
			for m2 in [dark, mid, light]:
				(m2 as ShaderMaterial).set_shader_parameter("rim_amount", 0.6)
			var blobs := rng.randi_range(4, 6)
			ModelsBase.part(root, ModelsBase.sphere(0.62, 12), dark, top + Vector3(0, 0.25, 0), Vector3(1.25, 0.8, 1.25))
			for k in blobs:
				var a := TAU * k / blobs + rng.randf_range(-0.3, 0.3)
				var rr := rng.randf_range(0.32, 0.46)
				ModelsBase.part(root, ModelsBase.sphere(rr, 10), mid, top + Vector3(cos(a) * 0.5, 0.42 + rng.randf_range(-0.1, 0.15), sin(a) * 0.5), Vector3.ONE)
			ModelsBase.part(root, ModelsBase.sphere(0.5, 12), light, top + Vector3(0.08, 0.78, -0.06), Vector3(1.0, 0.8, 1.0))
			if style == "blossom":
				for k in 6:
					ModelsBase.part(root, ModelsBase.sphere(0.06, 6), ModelsBase.toon(Color("fff0f6"), false, 0.4), top + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.5, 1.05), rng.randf_range(-0.6, 0.6)))
	return root

## Meshes for grass tufts and tall grass: a handful of tapered, slightly bent blades. UV.y runs
## from root (0) to tip (1) for the grass shader's colour and sway.
static var _grass_meshes := {}
static func grass_mesh(tall: bool) -> ArrayMesh:
	var key := "tall" if tall else "short"
	if _grass_meshes.has(key):
		return _grass_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new(); r.seed = 77 if tall else 33
	var blades := 11 if tall else 8
	for b in blades:
		var a := r.randf() * TAU
		var dist := r.randf_range(0.0, 0.34 if tall else 0.17)
		var base := Vector3(cos(a) * dist, 0, sin(a) * dist)
		var hgt := r.randf_range(0.65, 1.05) if tall else r.randf_range(0.13, 0.3)
		var wid := r.randf_range(0.06, 0.09) if tall else r.randf_range(0.03, 0.045)
		# blades lean out from the middle of the tuft, so a tuft reads as a fan, not a post
		var face := a + PI * 0.5 + r.randf_range(-0.5, 0.5)
		var side := Vector3(cos(face), 0, sin(face))
		var bend := Vector3(cos(a), 0, sin(a)) * hgt * r.randf_range(0.2, 0.45)
		var out_n := Vector3(cos(a), 1.6, sin(a)).normalized()
		var segs := 3 if tall else 2
		for k in segs:
			var t0 := float(k) / segs; var t1 := float(k + 1) / segs
			var w0 := wid * (1.0 - t0 * 0.92); var w1 := wid * (1.0 - t1 * 0.92)
			var p0 := base + Vector3(0, hgt * t0, 0) + bend * t0 * t0
			var p1 := base + Vector3(0, hgt * t1, 0) + bend * t1 * t1
			var v := [p0 - side * w0, p0 + side * w0, p1 + side * w1, p1 - side * w1]
			var uv := [Vector2(0, t0), Vector2(1, t0), Vector2(1, t1), Vector2(0, t1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(out_n)
				st.set_uv(uv[idx])
				st.add_vertex(v[idx])
	var m := st.commit()
	_grass_meshes[key] = m
	return m

## A tiny flower: three petals around a dot, on a short stem (coloured per instance).
static func flower_mesh() -> ArrayMesh:
	if _grass_meshes.has("flower"):
		return _grass_meshes["flower"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := 0.2
	for k in 5:
		var a := TAU * k / 5.0
		var c := Vector3(0, top, 0)
		var p1 := c + Vector3(cos(a - 0.45), 0.02, sin(a - 0.45)) * 0.07
		var p2 := c + Vector3(cos(a), 0.03, sin(a)) * 0.11
		var p3 := c + Vector3(cos(a + 0.45), 0.02, sin(a + 0.45)) * 0.07
		for v in [c, p1, p2, c, p2, p3]:
			st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(v)
	var m := st.commit()
	_grass_meshes["flower"] = m
	return m

static var GRASS: Shader = preload("res://shaders/grass.gdshader")
static func grass_material(sway: float, flower := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GRASS
	m.set_shader_parameter("sway", sway)
	if flower:
		m.set_shader_parameter("tip_tint", Color(1.0, 1.0, 1.0))
	return m

const CHEST_COL := [Color("8a5a35"), Color("f2c84a")]    # (wood, trim) of the primitive chest

## The chest (there is one kind, and it is locked: see KeyChest): the sculpted model, the imported
## one (its lid on a hinge), or the primitive one.
static func chest() -> Node3D:
	if Flora.v2():
		return PropSculpt.chest()
	var pk := _pack_chest()
	return pk if pk else chest_prim()

static func _pack_chest() -> Node3D:
	var id := "dungeon/chest"
	var base := Assets.part(id, "chest")
	var lidp := Assets.part(id, "chest_lid")
	if base.is_empty() or lidp.is_empty():
		return null
	var m := Assets.material("dungeon", {"rim": 0.3, "bright": 1.12})
	var root := Node3D.new()
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	var sc := 0.62
	# the model's lock faces +z and its hinge is at the back (-z); turned round inside Body so the
	# hinge is at +z like the primitive chest, then Body faces the lock to the camera
	var turn := Node3D.new(); turn.rotation.y = PI; turn.scale = Vector3.ONE * sc; body.add_child(turn)
	ModelsBase.part(turn, base[0], m, (base[1] as Transform3D).origin)
	var lid := Node3D.new(); lid.name = "Lid"
	lid.set_meta("hinged", true)
	var hinge: Vector3 = (lidp[1] as Transform3D).origin
	lid.position = Vector3(-hinge.x, hinge.y, -hinge.z) * sc
	lid.scale = Vector3.ONE * sc
	body.add_child(lid)
	ModelsBase.part(lid, lidp[0], m, Vector3.ZERO, Vector3.ONE, Vector3(0, PI, 0))
	body.rotation.y = PI
	var beam := ModelsBase.part(root, ModelsBase.cyl(0.16, 0.3, 6.0, 10), ModelsBase.glow_mat(Color(CHEST_COL[1], 0.22)), Vector3(0, 3.0, 0), Vector3.ONE, Vector3.ZERO, "Beacon")
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("mats", [m, m])
	return root

## The chest built from primitives (also the base of a deathbox).
static func chest_prim() -> Node3D:
	var root := Node3D.new()
	var mw := ModelsBase.toon(CHEST_COL[0]); var mg := ModelsBase.toon(CHEST_COL[1], true, 0.5)
	var m_seam := ModelsBase.toon(Color(CHEST_COL[0]).darkened(0.35), false)
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	# the box: planks, metal corners and a lock plate
	ModelsBase.part(body, ModelsBase.box(0.8, 0.42, 0.55), mw, Vector3(0, 0.21, 0))
	for k in 2:
		ModelsBase.part(body, ModelsBase.box(0.81, 0.015, 0.56), m_seam, Vector3(0, 0.14 + k * 0.14, 0))
	for x in [-0.36, 0.36]:
		for z in [-0.25, 0.25]:
			ModelsBase.part(body, ModelsBase.box(0.1, 0.44, 0.1), mg, Vector3(x, 0.22, z))
	ModelsBase.part(body, ModelsBase.box(0.84, 0.05, 0.59), mg, Vector3(0, 0.03, 0))
	# the lid hinges at the back; a rounded top with two straps
	var lid := Node3D.new(); lid.name = "Lid"; lid.position = Vector3(0, 0.42, 0.27); body.add_child(lid)
	lid.set_meta("hinged", true)
	ModelsBase.part(lid, ModelsBase.cyl(0.28, 0.28, 0.8, 14), mw, Vector3(0, 0.0, -0.27), Vector3(0.6, 1.0, 1.0), Vector3(0, 0, PI / 2))
	for x in [-0.27, 0.27]:
		ModelsBase.part(lid, ModelsBase.cyl(0.29, 0.29, 0.07, 14), mg, Vector3(x, 0.0, -0.27), Vector3(0.6, 1.0, 1.0), Vector3(0, 0, PI / 2))
	ModelsBase.part(lid, ModelsBase.cyl(0.29, 0.29, 0.04, 14), mg, Vector3(-0.4, 0.0, -0.27), Vector3(0.6, 1.0, 1.0), Vector3(0, 0, PI / 2))
	ModelsBase.part(lid, ModelsBase.cyl(0.29, 0.29, 0.04, 14), mg, Vector3(0.4, 0.0, -0.27), Vector3(0.6, 1.0, 1.0), Vector3(0, 0, PI / 2))
	ModelsBase.part(body, ModelsBase.box(0.16, 0.2, 0.05), mg, Vector3(0, 0.4, -0.29))
	ModelsBase.part(body, ModelsBase.sphere(0.035, 6), ModelsBase.toon(Color("2b2a33"), false), Vector3(0, 0.38, -0.32))
	body.scale = Vector3.ONE * 1.18
	body.rotation.y = PI   # lock facing the camera
	# a light pillar you can see from other islands
	var beam := ModelsBase.part(root, ModelsBase.cyl(0.16, 0.3, 6.0, 10), ModelsBase.glow_mat(Color(CHEST_COL[1], 0.22)), Vector3(0, 3.0, 0), Vector3.ONE, Vector3.ZERO, "Beacon")
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("mats", [mw, mg])
	return root

## A dead hunter's deathbox: a squat crate with a glow in its value colour.
static func deathbox(col: Color) -> Node3D:
	var root := PropSculpt.chest() if Flora.v2() else chest_prim()
	var own := root.get_node_or_null("Beacon")
	if own:
		root.remove_child(own); own.free()      # a deathbox glows in its value colour, not a chest's
	var g := Node3D.new(); g.name = "Glow"; root.add_child(g)
	var beam := ModelsBase.part(g, ModelsBase.cyl(0.12, 0.24, 5.0, 10), ModelsBase.glow_mat(Color(col, 0.3)), Vector3(0, 2.5, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := MeshInstance3D.new(); ring.mesh = ModelsBase.flat_quad(1.6)
	ring.material_override = ModelsBase.ring_mat(col, 0.1); ring.position.y = 0.04
	g.add_child(ring)
	# the soul: a little wisp bobbing over the box while a teammate can still bring them back
	var soul := Node3D.new(); soul.name = "Soul"; soul.position = Vector3(0, 1.3, 0); root.add_child(soul)
	ModelsBase.part(soul, ModelsBase.sphere(0.16, 10), ModelsBase.glow_mat(Color(0.85, 1.0, 0.95, 0.9)), Vector3.ZERO)
	ModelsBase.part(soul, ModelsBase.sphere(0.28, 10), ModelsBase.glow_mat(Color(0.6, 1.0, 0.85, 0.25)), Vector3.ZERO)
	PropAnim.on(soul, 1.4, 0.12)
	((root.get_meta("mats") as Array)[0] as ShaderMaterial).set_shader_parameter("albedo", Color("5a5560"))
	((root.get_meta("mats") as Array)[1] as ShaderMaterial).set_shader_parameter("albedo", col.darkened(0.2))
	return root

# ------------------------------------------------------------------ world legend: interactable icons
## Everything you can use out in the world (not loot, not breakables) wears a small floating badge
## with a symbol, in one colour per kind, so it reads at a glance from the match camera:
## shrines (blessing, teal), chest keys (brass), eggs (warm gold), revive beacons (mint). Loot is
## gold / rarity coloured with a pillar and a ground pool; breakables are matte with no glow; decor stays low-contrast.
const ICON_COLS := {"bless": Color("5fd0b0"), "ckey": Color("f2c84a"), "egg": Color("ffc04a"),
	"revive": Color("6ae8a0")}
static var _icon_tex := {}

## Is the point (x, y) (-1..1, y up) inside the white symbol for this kind?
static func _icon_sym(kind: String, x: float, y: float) -> bool:
	match kind:
		"bless":     # a four-point sparkle
			return pow(absf(x), 0.5) + pow(absf(y + 0.02), 0.5) < 0.86
		"ckey":
			var d := Vector2(x, y - 0.24).length()
			if d < 0.27 and d > 0.12: return true
			if absf(x) < 0.075 and y < 0.0 and y > -0.6: return true
			if x > 0.0 and x < 0.26 and ((y > -0.58 and y < -0.47) or (y > -0.38 and y < -0.28)): return true
			return false
		"egg":
			var ry := 0.5 if y > -0.08 else 0.4
			var rx := 0.36 - 0.1 * clampf((y + 0.08) / 0.5, 0.0, 1.0)
			return pow(x / rx, 2.0) + pow((y + 0.08) / ry, 2.0) < 1.0
		"revive":   # a plus
			return (absf(x) < 0.15 and absf(y) < 0.48) or (absf(y) < 0.15 and absf(x) < 0.48)
	return false

static func icon_texture(kind: String) -> ImageTexture:
	if _icon_tex.has(kind):
		return _icon_tex[kind]
	var N := 96
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var col: Color = ICON_COLS.get(kind, Color.WHITE)
	var dark := col.darkened(0.7).lerp(Color("1a1626"), 0.4)
	for py in N:
		for px in N:
			var acc := Color(0, 0, 0, 0)
			for sy in 2:
				for sx in 2:
					var x := ((px + 0.25 + sx * 0.5) / N) * 2.0 - 1.0
					var y := 1.0 - ((py + 0.25 + sy * 0.5) / N) * 2.0
					# a diamond-ish rounded badge: a dark rim, the colour inside lighter at the top
					var r := pow(pow(absf(x), 1.6) + pow(absf(y), 1.6), 1.0 / 1.6)
					var c := Color(0, 0, 0, 0)
					if r < 0.97:
						c = dark
					if r < 0.84:
						c = col.lerp(col.lightened(0.35), clampf(y * 0.5 + 0.5, 0.0, 1.0))
						var sym := _icon_sym(kind, x / 0.78, y / 0.78)
						# a dark edge round the symbol so it pops on the colour
						var edge := false
						if not sym:
							for o in [Vector2(0.06, 0), Vector2(-0.06, 0), Vector2(0, 0.06), Vector2(0, -0.06)]:
								if _icon_sym(kind, (x + o.x) / 0.78, (y + o.y) / 0.78): edge = true; break
						if sym: c = Color("fffdf6")
						elif edge: c = dark.lerp(col, 0.25)
					acc += c * 0.25
			img.set_pixel(px, py, acc)
	var tex := ImageTexture.create_from_image(img)
	_icon_tex[kind] = tex
	return tex

## A floating badge for an interactable: a billboard that bobs gently above it. Named "Icon".
static func icon_badge(kind: String, height: float, size := 0.8) -> Node3D:
	var holder := Node3D.new(); holder.name = "Icon"; holder.position = Vector3(0, height, 0)
	var sp := Sprite3D.new()
	sp.texture = icon_texture(kind)
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.double_sided = true
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.pixel_size = size / 96.0
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(sp)
	PropAnim.on(holder, 0.0, 0.07, 2.2)
	return holder

## A revive beacon: a stone pylon with a green crystal. Stand on it with a dead teammate waiting
## and it brings them back.
static func revive_beacon() -> Node3D:
	var root := Node3D.new()
	var stone := ModelsBase.toon(Color("8f9aa0"))
	var glow := Color("8fffc0")
	ModelsBase.part(root, ModelsBase.cyl(1.2, 1.3, 0.16, 8), stone, Vector3(0, 0.08, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.9, 0.96, 0.12, 8), ModelsBase.toon(Color("b8c2c6")), Vector3(0, 0.22, 0))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		ModelsBase.part(root, ModelsBase.box(0.22, 1.5, 0.22), stone, Vector3(cos(a) * 1.0, 0.75, sin(a) * 1.0), Vector3.ONE, Vector3(0, -a, 0))
		ModelsBase.part(root, ModelsBase.box(0.05, 0.9, 0.02), ModelsBase.toon(glow, false, 0.9), Vector3(cos(a) * 0.88, 0.85, sin(a) * 0.88), Vector3.ONE, Vector3(0, -a, 0))
	var g := Node3D.new(); g.name = "Glow"; root.add_child(g)
	var cr := Node3D.new(); cr.position = Vector3(0, 1.7, 0); g.add_child(cr)
	var pm := PrismMesh.new(); pm.size = Vector3(0.5, 0.7, 0.5)
	var cm := ModelsBase.toon(glow.darkened(0.1), true, 0.7)
	ModelsBase.part(cr, pm, cm, Vector3(0, 0.35, 0))
	ModelsBase.part(cr, pm, cm, Vector3(0, -0.35, 0), Vector3.ONE, Vector3(PI, 0, 0))
	PropAnim.on(cr, 0.7, 0.1)
	var beam := ModelsBase.part(g, ModelsBase.cyl(0.2, 0.4, 12.0, 10), ModelsBase.glow_mat(Color(glow, 0.2)), Vector3(0, 6.0, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := MeshInstance3D.new(); ring.name = "Ring"; ring.mesh = ModelsBase.flat_quad(4.6)
	ring.material_override = ModelsBase.ring_mat(glow, 0.05); ring.position.y = 0.3
	g.add_child(ring)
	g.add_child(icon_badge("revive", 2.75))
	return root

static func shrine() -> Node3D:
	var root := Node3D.new()
	var stone := ModelsBase.toon(Color("a9a39a"))
	var stone_l := ModelsBase.toon(Color("cfc8bb"))
	var moss := ModelsBase.toon(Color("7fa65a"), false)
	var glow := Color("8fe3c8")
	# a two-step hexagonal dais with a carved, glowing inlay
	if Flora.v2():
		# (cut stones laid in two rings, a glowing inlay, a carved round altar)
		ExitModels._stone_ring(root, 1.15, 0.2, 9, Color("a39d92"), 0.62)
		ExitModels._stone_ring(root, 0.84, 0.36, 7, Color("bdb6a8"), 0.0)
		ModelsBase.part(root, ModelsBase.cyl(0.52, 0.52, 0.025, 24), ModelsBase.toon(glow, false, 0.8), Vector3(0, 0.37, 0))
		ModelsBase.part(root, ModelsBase.lathe(ModelsBase.smooth_curve(PackedVector2Array([Vector2(0, 0), Vector2(0.42, 0), Vector2(0.4, 0.06), Vector2(0.33, 0.1), Vector2(0.31, 0.2), Vector2(0.38, 0.25), Vector2(0.36, 0.29), Vector2(0, 0.29)]), 2), 22, "shrine_altar"), stone, Vector3(0, 0.36, 0))
	else:
		ModelsBase.part(root, ModelsBase.cyl(1.05, 1.15, 0.18, 6), stone, Vector3(0, 0.09, 0))
		ModelsBase.part(root, ModelsBase.cyl(0.78, 0.86, 0.18, 6), stone_l, Vector3(0, 0.27, 0))
		ModelsBase.part(root, ModelsBase.cyl(0.5, 0.5, 0.02, 6), ModelsBase.toon(glow, false, 0.8), Vector3(0, 0.37, 0))
		ModelsBase.part(root, ModelsBase.cyl(0.35, 0.42, 0.22, 6), stone, Vector3(0, 0.47, 0))
	# three leaning standing stones with moss on top
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var at := Vector3(cos(a) * 0.98, 0.0, sin(a) * 0.98)
		var tilt := Vector3(sin(a) * 0.12, -a, -cos(a) * 0.12)
		ModelsBase.part(root, ModelsBase.box(0.26, 1.0 - i * 0.12, 0.2), stone, at + Vector3(0, 0.5 - i * 0.06, 0), Vector3.ONE, tilt)
		ModelsBase.part(root, ModelsBase.box(0.28, 0.06, 0.22), moss, at + Vector3(0, 1.0 - i * 0.12, 0), Vector3.ONE, tilt)
		ModelsBase.part(root, ModelsBase.box(0.04, 0.3, 0.01), ModelsBase.toon(glow, false, 0.9), at + Vector3(0, 0.55, 0) - Vector3(cos(a), 0, sin(a)) * 0.105, Vector3.ONE, tilt)
	# the healing crystal floats and turns above the dais
	var cr := Node3D.new(); cr.name = "Crystal"; cr.position = Vector3(0, 1.45, 0); root.add_child(cr)
	var pm := PrismMesh.new(); pm.size = Vector3(0.42, 0.62, 0.42)
	var cm := ModelsBase.toon(glow.darkened(0.15), true, 0.55)
	if Flora.v2():
		cm.set_shader_parameter("gloss", 0.7)
		ModelsBase.part(cr, ModelsBase.crystal(0.22, 0.8, 6), cm, Vector3(0, 0.12, 0))
		ModelsBase.part(cr, ModelsBase.crystal(0.22, 0.36, 6), cm, Vector3(0, -0.36, 0), Vector3.ONE, Vector3(PI, 0, 0))
		for i in 3:
			var a2 := TAU * i / 3.0
			ModelsBase.part(cr, ModelsBase.crystal(0.07, 0.24, 5), cm, Vector3(cos(a2) * 0.45, -0.1, sin(a2) * 0.45), Vector3.ONE, Vector3(0.3, a2, 0.25))
	else:
		ModelsBase.part(cr, pm, cm, Vector3(0, 0.31, 0))
		ModelsBase.part(cr, pm, cm, Vector3(0, -0.31, 0), Vector3.ONE, Vector3(PI, 0, 0))
		for i in 3:
			var a2 := TAU * i / 3.0
			ModelsBase.part(cr, pm, cm, Vector3(cos(a2) * 0.42, -0.1, sin(a2) * 0.42), Vector3.ONE * 0.3)
	PropAnim.on(cr, 0.9, 0.08)
	cr.add_child(icon_badge("bless", 1.05))     # hidden with the crystal once the shrine is used
	var base := MeshInstance3D.new(); base.name = "Ring"; base.mesh = ModelsBase.flat_quad(3.0)
	base.material_override = ModelsBase.ring_mat(glow, 0.06); base.position.y = 0.04
	root.add_child(base)
	Flora.paint_set_piece(root)
	return root

static func nest() -> Node3D:
	var root := Node3D.new()
	var twig := ModelsBase.toon(Color("8a6a45"))
	var t := TorusMesh.new(); t.inner_radius = 0.55; t.outer_radius = 0.95; t.rings = 16; t.ring_segments = 6
	ModelsBase.part(root, t, twig, Vector3(0, 0.15, 0), Vector3(1, 0.7, 1))
	ModelsBase.part(root, ModelsBase.cyl(0.6, 0.6, 0.06, 14), ModelsBase.toon(Color("c9a77a")), Vector3(0, 0.1, 0))
	var cols := [Color("ffe8c4"), Color("cfe8ff"), Color("ffd0dc")]
	for i in 3:
		var a := TAU * i / 3.0
		ModelsBase.part(root, ModelsBase.sphere(0.16, 10), ModelsBase.toon(cols[i]), Vector3(cos(a) * 0.25, 0.28, sin(a) * 0.25), Vector3(1, 1.25, 1))
	return root

const EXTRACT_R := 2.6
static func portal(c: Color) -> Node3D:
	var root := Node3D.new()
	var t := TorusMesh.new(); t.inner_radius = 0.95; t.outer_radius = 1.2; t.rings = 24; t.ring_segments = 8
	var mr := ModelsBase.toon(Color("6a6f80"), true)
	var ring := ModelsBase.part(root, t, mr, Vector3(0, 1.25, 0), Vector3.ONE, Vector3(PI / 2, 0, 0), "Ring")
	# runes around the ring that light up, and a pair of stone feet
	for i in 8:
		var a := TAU * i / 8.0
		ModelsBase.part(ring, ModelsBase.box(0.12, 0.3, 0.14), ModelsBase.toon(c, false, 0.9), Vector3(cos(a) * 1.08, 0.0, sin(a) * 1.08), Vector3.ONE, Vector3(0, -a, 0))
	for sx in [-1.0, 1.0]:
		ModelsBase.part(root, ModelsBase.box(0.42, 0.34, 0.5), ModelsBase.toon(Color("585c6a")), Vector3(0.95 * sx, 0.17, 0))
		ModelsBase.part(root, ModelsBase.box(0.3, 0.06, 0.38), ModelsBase.toon(Color("7fa65a"), false), Vector3(0.95 * sx, 0.36, 0))
	var disc := ModelsBase.part(root, ModelsBase.cyl(1.0, 1.0, 0.02, 24), ModelsBase.glow_mat(c), Vector3(0, 1.25, 0), Vector3.ONE, Vector3(PI / 2, 0, 0), "Disc")
	disc.visible = false
	var base := MeshInstance3D.new(); base.name = "Base"; base.mesh = ModelsBase.flat_quad(3.2)
	base.material_override = ModelsBase.ring_mat(c, 0.1); base.position.y = 0.05; root.add_child(base)
	# the extraction circle: dim until you stand in it, then it fills around as you extract
	var zone := MeshInstance3D.new(); zone.name = "Zone"; zone.mesh = ModelsBase.flat_quad(EXTRACT_R * 2.0)
	zone.material_override = ModelsBase.ring_mat(Color(c, 0.35), 0.035); zone.position.y = 0.06; root.add_child(zone)
	var zf := MeshInstance3D.new(); zf.name = "ZoneFill"; zf.mesh = ModelsBase.flat_quad(EXTRACT_R * 2.0)
	var zm := ModelsBase.ring_mat(Color(c.lightened(0.35), 0.95), 0.07)
	zm.set_shader_parameter("arc", 0.0)
	zf.material_override = zm; zf.position.y = 0.07; root.add_child(zf)
	var beam := CPUParticles3D.new(); beam.name = "Beam"
	beam.amount = 40; beam.lifetime = 1.6; beam.emitting = false
	var bm := SphereMesh.new(); bm.radius = 0.07; bm.height = 0.14; bm.radial_segments = 6; bm.rings = 3
	var pmat := StandardMaterial3D.new(); pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pmat.albedo_color = c.lightened(0.3)
	bm.material = pmat
	beam.mesh = bm
	beam.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	beam.emission_ring_axis = Vector3.UP; beam.emission_ring_radius = 1.1; beam.emission_ring_inner_radius = 0.6; beam.emission_ring_height = 0.1
	beam.direction = Vector3.UP; beam.spread = 8.0; beam.gravity = Vector3(0, 2.5, 0)
	beam.initial_velocity_min = 1.0; beam.initial_velocity_max = 2.5
	beam.position = Vector3(0, 0.1, 0)
	root.add_child(beam)
	return root

static func jump_pad(c: Color) -> Node3D:
	var root := Node3D.new()
	ModelsBase.part(root, ModelsBase.cyl(0.7, 0.8, 0.14, 20), ModelsBase.toon(Color("3f4456")), Vector3(0, 0.07, 0))
	var top := ModelsBase.part(root, ModelsBase.cyl(0.55, 0.55, 0.02, 20), ModelsBase.toon(c.darkened(0.25), false, 0.45), Vector3(0, 0.15, 0), Vector3.ONE, Vector3.ZERO, "Top")
	for i in 3:
		ModelsBase.part(root, ModelsBase.box(0.3, 0.03, 0.08), ModelsBase.toon(Color("e8fff6"), false, 0.6), Vector3(0, 0.18, 0.2 - i * 0.2), Vector3.ONE, Vector3(0, 0, 0), "Chev%d" % i)
	return root

static func gem() -> Node3D:
	var root := Node3D.new()
	var p := PrismMesh.new(); p.size = Vector3(0.28, 0.3, 0.28)
	var m := ModelsBase.toon(Color("7ef0d0"), false, 0.7)
	ModelsBase.part(root, p, m, Vector3(0, 0.15, 0))
	ModelsBase.part(root, p, m, Vector3(0, -0.15, 0), Vector3.ONE, Vector3(PI, 0, 0))
	return root

static func armor_shard() -> Node3D:
	var root := Node3D.new()
	var pm := PrismMesh.new(); pm.size = Vector3(0.22, 0.34, 0.08)
	var m := ModelsBase.toon(Color("7ac8ff"), false, 0.8)
	ModelsBase.part(root, pm, m, Vector3(0, 0.2, 0))
	ModelsBase.part(root, pm, m, Vector3(0, 0.05, 0), Vector3(0.7, 0.7, 1), Vector3(PI, 0, 0))
	return root

static func tonic() -> Node3D:
	var root := Node3D.new()
	ModelsBase.part(root, ModelsBase.sphere(0.16, 12), ModelsBase.toon(Color("8ff0a0"), false, 0.6), Vector3(0, 0.16, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.05, 0.06, 0.14, 8), ModelsBase.toon(Color("e6f2ea")), Vector3(0, 0.34, 0))
	ModelsBase.part(root, ModelsBase.cyl(0.065, 0.065, 0.05, 8), ModelsBase.toon(Color("8b6d52")), Vector3(0, 0.43, 0))
	return root

static func seed_bag(c: Color) -> Node3D:
	var root := Node3D.new()
	ModelsBase.part(root, ModelsBase.sphere(0.2), ModelsBase.toon(Color("c8a26a")), Vector3(0, 0.2, 0), Vector3(1, 1.1, 1))
	ModelsBase.part(root, ModelsBase.sphere(0.09), ModelsBase.toon(c, false, 0.4), Vector3(0, 0.42, 0))
	return root
