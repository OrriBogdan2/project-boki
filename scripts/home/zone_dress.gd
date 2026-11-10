class_name ZoneDress
extends RefCounted
## What a built zone (ZoneLayout) puts on its ground besides the layout's own things: the shallows
## (one translucent sheet over the channel the tiles say) and a scatter of crystal stacks, reeds and
## pebbles. The scatter is MultiMesh, one batch per kind and shape, and every instance shares the one
## cached Flora material of its kind (no per-prop materials), so a zone's whole scatter costs about a
## dozen draw calls. Purely visual: nothing here blocks or is walked into. Data: the zone's "build" in
## content/rules/garden_zones.json (shallow = a tile rect, scatter = how many of each).

const SHEET_Y := 0.03          # m above the ground: the water sheet
const SHEET_COLOUR := Color(0.36, 0.78, 0.86, 0.55)
const KEEP_OUT := 2.2          # m round the landing and the pad that scatter stays away from
const TRIES := 40              # spots tried per prop before giving up on it
const SHAPES := 1              # Flora shapes used per kind (one batch each)

## Called once the zone's world is built; does nothing outside a built zone.
static func place(h) -> void:
	if ZoneLayout.live.is_empty():
		return
	for br in h.bridges.values():
		for part in ["node", "sign", "label"]:
			br[part].visible = false          # the side isles' bridge stubs and signs belong to Bramblebank
	var B: Dictionary = GardenZones.info(h.zone)["build"]
	var r: Array = B["shallow"]
	_sheet(h, Rect2(r[0], r[1], r[2] - r[0] + 1, r[3] - r[1] + 1))
	_scatter(h, B["scatter"], Rect2(r[0], r[1], r[2] - r[0] + 1, r[3] - r[1] + 1))

static func _sheet(h, tiles: Rect2) -> void:
	var m := MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3(tiles.size.x, 0.02, tiles.size.y)
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SHEET_COLOUR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.name = "Shallows"
	m.position = Vector3(tiles.position.x + tiles.size.x * 0.5, SHEET_Y, tiles.position.y + tiles.size.y * 0.5)
	h.add_child(m)

static func _scatter(h, S: Dictionary, shallow: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(S["seed"])
	var style: String = h.world.style_at(h.world.idx(int(HomeLayout.LANDING.x), int(HomeLayout.LANDING.z)))
	var keep: Array = [HomeLayout.LANDING]
	if h.hway != null:
		keep.append(h.hway.node.position)
	for kind in ["crystal", "reed", "pebble"]:
		var by: Array = [[], []]
		for i in int(S[kind]):
			var at := _spot(h, rng, kind, S, shallow, keep)
			if at == Vector3.INF:
				continue
			var s := rng.randf_range(0.7, 1.3)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s))
			by[rng.randi_range(0, SHAPES - 1)].append(Transform3D(b, at))
		for v in SHAPES:
			_batch(h, Flora.mesh(kind, style, v), Flora.material(kind, kind == "crystal"), by[v], "%s_%d" % [kind, v])

## A free spot on dry ground for one prop: crystals and reeds crowd the shallows' edge, pebbles go anywhere.
static func _spot(h, rng: RandomNumberGenerator, kind: String, S: Dictionary, shallow: Rect2, keep: Array) -> Vector3:
	var c := Vector2(HomeLayout.LANDING.x, HomeLayout.LANDING.z)
	for t in TRIES:
		var p := c + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-12.0, 12.0))
		if kind != "pebble":
			var edge := shallow.grow(float(S["shore"]))
			p = Vector2(rng.randf_range(edge.position.x, edge.end.x), rng.randf_range(edge.position.y, edge.end.y))
			if kind == "crystal" and shallow.has_point(p):
				continue
		if h.world.is_void(p.x, p.y) or h.world.occupy(p.x, p.y, 0.3, 0.0, false) != 0.0:
			continue
		if keep.any(func(k): return Vector2(k.x, k.z).distance_to(p) < KEEP_OUT):
			continue
		return Vector3(p.x, h.world.ground_at(p.x, p.y), p.y)
	return Vector3.INF

static func _batch(h, mesh: Mesh, mat: Material, list: Array, label: String) -> void:
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
		mm.set_instance_color(i, Color.WHITE)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = label
	h.add_child(mi)
