class_name ShrublingModel
extends RefCounted
## The Shrubling's body. Disguised, it is four tufts of the very same tall-grass mesh and material
## the map's grass patches use (Models.grass_mesh / grass_material, tinted with the island's leaf
## colour), scattered over one tile exactly as World lays out a grass tile, so it is another clump
## of grass. The tells: it twitches every few seconds, and two small eyes glint in the blades when
## a hunter is close. Revealed, the tufts bunch into a leafy ball on two stubby legs with big eyes.

const TUFTS := 6          # four are the disguise, two more appear when it is up
const EYES_R := 0.075

static func build(col: Color) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Models.grass_mesh(true)
	mm.instance_count = TUFTS
	var r := RandomNumberGenerator.new(); r.seed = int(col.r * 977.0 + col.g * 331.0 + col.b * 59.0) + 5
	var layouts: Array = []
	for k in TUFTS:
		var hidden := k >= 4
		# spread: where a grass tile would put them; bunched: a ball round the middle
		var sp := Vector3(r.randf_range(-0.4, 0.4), 0.0, r.randf_range(-0.4, 0.4)) if not hidden else Vector3.ZERO
		var sc := r.randf_range(0.85, 1.2)
		var ya := r.randf() * TAU
		var a := TAU * k / float(TUFTS)
		var bunch := Vector3(cos(a) * 0.17, 0.2, sin(a) * 0.17)
		layouts.append({"sp": sp, "sc": sc, "ya": ya, "bunch": bunch, "hidden": hidden, "col": col.darkened(r.randf_range(0.0, 0.18))})
		mm.set_instance_color(k, layouts[k]["col"])
	var mi := MultiMeshInstance3D.new(); mi.name = "Tufts"; mi.multimesh = mm
	mi.material_override = Models.grass_material(0.16)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	var mats: Array = []
	# eyes: white with a dark pupil, on the front (-z)
	var eyes := Node3D.new(); eyes.name = "Eyes"; eyes.position = Vector3(0, 0.5, -0.3); body.add_child(eyes)
	var white := Models.toon(Color("fff8e0"), false, 0.9)
	var pupil := Models.toon(Color("1a1410"), false, 0.0)
	mats.append(white)
	for sx in [-1.0, 1.0]:
		Models.part(eyes, Models.sphere(EYES_R, 8), white, Vector3(sx * 0.13, 0, 0))
		Models.part(eyes, Models.sphere(EYES_R * 0.5, 6), pupil, Vector3(sx * 0.13, -0.005, -EYES_R * 0.7))
	# legs: two stubby roots that swing when it runs
	var wood := Models.toon(Color("6b4a2e"))
	mats.append(wood)
	for sd in ["L", "R"]:
		var pivot := Node3D.new(); pivot.name = "Leg" + sd
		pivot.position = Vector3((-0.15 if sd == "L" else 0.15), 0.22, 0.0)
		body.add_child(pivot)
		Models.part(pivot, Models.cyl(0.05, 0.075, 0.26, 7), wood, Vector3(0, -0.1, 0))
		Models.part(pivot, Models.sphere(0.08, 6), wood, Vector3(0, -0.22, -0.04), Vector3(1.0, 0.6, 1.4))
	root.set_meta("tufts", mm)
	root.set_meta("layouts", layouts)
	root.set_meta("mats", mats)
	return root

## Re-dresses the tufts in `col` (the leaf colour of the island it hides on), keeping each tuft's shade.
static func recolour(model: Node3D, col: Color) -> void:
	if model == null or not model.has_meta("tufts"):
		return
	var mm: MultiMesh = model.get_meta("tufts")
	var r := RandomNumberGenerator.new(); r.seed = int(col.r * 977.0 + col.g * 331.0 + col.b * 59.0) + 5
	for k in mm.instance_count:
		mm.set_instance_color(k, col.darkened(r.randf_range(0.0, 0.18)))

## Poses it: k 0 = disguised grass, 1 = up on its legs; t is the run clock, twitch 0..1 a shiver
## through the blades, eyes whether the tell-tale eyes show while it is still disguised.
static func pose(model: Node3D, k: float, t: float, speed: float, twitch: float, eyes: bool) -> void:
	var mm: MultiMesh = model.get_meta("tufts")
	var layouts: Array = model.get_meta("layouts")
	var body := model.get_node("Body") as Node3D
	for i in layouts.size():
		var L: Dictionary = layouts[i]
		var up := k
		var hidden: bool = L["hidden"]
		var p: Vector3 = (L["sp"] as Vector3).lerp(L["bunch"], up)
		var sc: float = float(L["sc"]) * lerpf(1.0, 1.25, up)
		if hidden:
			sc *= up
		# the twitch: the whole tuft leans and shivers for a moment
		var ang := float(L["ya"]) + sin(t * 40.0 + i) * 0.25 * twitch
		var b := Basis(Vector3.UP, ang).scaled(Vector3(sc, sc * lerpf(1.0, 0.8, up), sc))
		b = Basis(Vector3(1, 0, 0), sin(t * 33.0 + i * 2.0) * 0.22 * twitch) * b
		mm.set_instance_transform(i, Transform3D(b, p + Vector3(0, absf(sin(t * 9.0)) * 0.09 * up * clampf(speed / 6.0, 0.0, 1.0), 0)))
	var legs_on := k > 0.25
	for sd in ["LegL", "LegR"]:
		var lg := body.get_node(sd) as Node3D
		lg.visible = legs_on
		var ph := t * 9.0 + (0.0 if sd == "LegL" else PI)
		lg.rotation.x = sin(ph) * 0.9 * clampf(speed / 4.0, 0.0, 1.0)
		lg.scale = Vector3.ONE * clampf(k * 1.2, 0.01, 1.0)
	var ey := body.get_node("Eyes") as Node3D
	ey.visible = k > 0.5 or eyes
	ey.scale = Vector3.ONE * (1.0 if k > 0.5 else 0.55)
	ey.position.y = lerpf(0.34, 0.52, k)
