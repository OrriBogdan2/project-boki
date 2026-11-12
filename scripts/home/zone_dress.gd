class_name ZoneDress
extends RefCounted
## What a built zone (ZoneLayout) puts on its ground besides the layout's own things: the shallows
## (one translucent sheet over the channel the tiles say, if it has one) and a scatter: Flora crystal
## stacks, reeds, pebbles, mushrooms (they glow on a gloom island), ferns and flowers, the plain
## slabs of KINDS_BOX (stepped stone terraces, glowing cracks) and lantern moss with a few drifting mote emitters.
## The scatter is MultiMesh, one batch per kind and shape, and every instance of a kind shares one
## cached Flora material (no per-prop materials), so a zone's whole scatter costs about a dozen draw calls.
## Purely visual: nothing here blocks or is walked into. Data: the zone's "build" in
## content/rules/garden_zones.json (shallow = a tile rect, scatter = how many of each kind it has).

const SHEET_Y := 0.03          # m above the ground: the water sheet
const SHEET_COLOUR := Color(0.36, 0.78, 0.86, 0.55)
const KEEP_OUT := 2.2          # m round the landing, the pad and a zone's stump that scatter stays away from
const BEAM_AMOUNT := 20        # particles of the portal's beam (40 in a match, where it also marks the exit from afar)
const TRIES := 40              # spots tried per prop before giving up on it
const SHAPES := 1              # Flora shapes used per kind (one batch each)
const KINDS_FLORA := ["crystal", "reed", "pebble", "mushroom", "fern", "flower"]
const SHORE := ["crystal", "reed"]     # kinds that crowd the shallows' edge
## Slab kinds, one unit box scaled per instance and lit by Flora's shared rock material (the box has no
## vertex colours, so each instance's colour is its whole colour; alpha 0 glows day and night). size: m
## (x, y, z) at scale 1; steps: slabs per prop, each shrunk by STEP_IN and set on the one under it;
## clear: m of free ground the prop needs.
const KINDS_BOX := {
	"terrace": {"size": Vector3(1.7, 0.12, 1.4), "steps": 2, "clear": 1.0, "colour": Color("a08c7c")},
	"crack": {"size": Vector3(1.4, 0.03, 0.12), "steps": 1, "clear": 0.4, "colour": Color(1.0, 0.36, 0.1, 0.0)},
}
const STEP_IN := 0.6           # a terrace's upper slab, as a fraction of the one under it
const MOSS_RANGE := Vector2(12.0, 9.0)   # m east-west and north-south of the landing the moss clumps may lie
const MOSS_SPREAD := 2.2       # m a tuft may lie from its clump's centre
const MOSS_R := 0.11           # m, a moss tuft's radius
const MOSS_FLAT := 0.5         # of its radius: tufts are low
const MOSS_GLOW := 0.7         # toon-shader glow of the moss (0 flat, 1 lit from within)
const MOSS_COLOUR := Color("4fb8a0")
const MOTE_COLOUR := Color("b8fff0")
const MOTE_LIFE := 5.0         # s a drifting mote lives
const MOTE_RISE := 0.12        # m/s the motes drift up
const MOTE_AREA := 1.6         # m, half-width of the square a mote emitter fills

## The expedition portal in a home (hub and every zone): its beam stays lit but thinner, and the extraction
## circle (a dim outer ring and its fill, which only a match's exit uses) is freed, so the pad reads as
## one lit ring you step on.
static func calm_pad(portal: Node3D) -> void:
	var beam := portal.get_node("Beam") as CPUParticles3D
	beam.amount = BEAM_AMOUNT
	beam.emitting = true
	portal.get_node("Zone").queue_free()
	portal.get_node("ZoneFill").queue_free()

## The far landmarks' motes (22 each, simulated and out of the home camera's frame) are freed in a built
## zone; the landmark rocks stay.
static func quiet_landmarks(h) -> void:
	for lm in h.world.find_children("Landmark_*", "Node3D", true, false):
		for p in lm.find_children("*", "CPUParticles3D", true, false):
			p.queue_free()

## Called once the zone's world is built; does nothing outside a built zone.
static func place(h) -> void:
	if ZoneLayout.live.is_empty():
		return
	for br in h.bridges.values():
		for part in ["node", "sign", "label"]:
			if br.has(part):                  # a retired side isle has no sign or label (base_mode)
				br[part].visible = false      # the side isles' bridge stubs and signs belong to Bramblebank
	var B: Dictionary = GardenZones.info(h.zone)["build"]
	var shallow := Rect2()
	if B.has("shallow"):
		var r: Array = B["shallow"]
		shallow = Rect2(r[0], r[1], r[2] - r[0] + 1, r[3] - r[1] + 1)
		_sheet(h, shallow)
	quiet_landmarks(h)
	_scatter(h, B["scatter"], shallow)
	if B.has("moss"):
		_moss(h, B["moss"], int(B["seed"]))

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
	var stump := BaseShove.spot()
	if not stump.is_empty():
		keep.append(Vector3(stump[0], 0.0, stump[1]))
	for kind in KINDS_FLORA:
		var by: Array = [[], []]
		for i in int(S.get(kind, 0)):
			var at := _spot(h, rng, kind, S, shallow, keep, 0.3)
			if at == Vector3.INF:
				continue
			var s := rng.randf_range(0.7, 1.3)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s))
			by[rng.randi_range(0, SHAPES - 1)].append(Transform3D(b, at))
		for v in SHAPES:
			batch(h, Flora.mesh(kind, style, v), Flora.material(kind, kind == "crystal"), by[v], "%s_%d" % [kind, v],
				Color.WHITE)
	for kind in KINDS_BOX:
		var K: Dictionary = KINDS_BOX[kind]
		var list: Array = []
		for i in int(S.get(kind, 0)):
			var at := _spot(h, rng, kind, S, shallow, keep, float(K["clear"]))
			if at == Vector3.INF:
				continue
			var dims: Vector3 = K["size"] * rng.randf_range(0.75, 1.25)
			var b := Basis(Vector3.UP, rng.randf() * TAU)
			for step in int(K["steps"]):
				at.y += dims.y * 0.5
				list.append(Transform3D(b.scaled(dims), at))
				at.y += dims.y * 0.5
				dims *= Vector3(STEP_IN, 1.0, STEP_IN)
		batch(h, BoxMesh.new(), Flora.material("rock", false), list, kind, K["colour"])

## A free spot on dry ground, `clear` m round, for one prop: crystals and reeds crowd the shallows' edge,
## the rest go anywhere.
static func _spot(h, rng: RandomNumberGenerator, kind: String, S: Dictionary, shallow: Rect2, keep: Array,
		clear: float) -> Vector3:
	var c := Vector2(HomeLayout.LANDING.x, HomeLayout.LANDING.z)
	for t in TRIES:
		var p := c + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-12.0, 12.0))
		if kind in SHORE:
			var edge := shallow.grow(float(S["shore"]))
			p = Vector2(rng.randf_range(edge.position.x, edge.end.x), rng.randf_range(edge.position.y, edge.end.y))
			if kind == "crystal" and shallow.has_point(p):
				continue
		if h.world.is_void(p.x, p.y) or h.world.occupy(p.x, p.y, clear, 0.0, false) != 0.0:
			continue
		if keep.any(func(k): return Vector2(k.x, k.z).distance_to(p) < KEEP_OUT):
			continue
		return Vector3(p.x, h.world.ground_at(p.x, p.y), p.y)
	return Vector3.INF

## One MultiMesh of `mesh` under `parent` (no shadows), one draw for the whole list; the home's ponds use it too.
static func batch(parent: Node, mesh: Mesh, mat: Material, list: Array, label: String, tint: Color) -> void:
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
		mm.set_instance_color(i, tint)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = label
	parent.add_child(mi)

## Lantern moss (GARDEN.md 10.2, Hushwood): tufts gathered in a few clumps on free ground, one MultiMesh on one
## glowing material, and a mote emitter over each of the first clumps.
static func _moss(h, M: Dictionary, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var clumps: Array = []
	for i in TRIES * int(M["clumps"]):
		if clumps.size() >= int(M["clumps"]):
			break
		var c := HomeLayout.LANDING + Vector3(rng.randf_range(-MOSS_RANGE.x, MOSS_RANGE.x), 0,
			rng.randf_range(-MOSS_RANGE.y, MOSS_RANGE.y))
		if _moss_free(h.world, c):
			clumps.append(c)
	if clumps.is_empty():
		return
	var tufts: Array = []
	for i in TRIES * int(M["count"]) / 6:
		if tufts.size() >= int(M["count"]):
			break
		var at: Vector3 = clumps[i % clumps.size()] + Vector3(rng.randf_range(-MOSS_SPREAD, MOSS_SPREAD), 0,
			rng.randf_range(-MOSS_SPREAD, MOSS_SPREAD))
		if _moss_free(h.world, at):
			at.y = h.world.ground_at(at.x, at.z)
			var s := rng.randf_range(0.6, 1.4)
			tufts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * MOSS_FLAT, s)), at))
	batch(h, Models.sphere(MOSS_R, 8), Models.toon(MOSS_COLOUR, false, MOSS_GLOW), tufts, "LanternMoss", Color.WHITE)
	for i in mini(int(M["motes"]), clumps.size()):
		h.add_child(_motes(clumps[i], i))

static func _moss_free(w: World, p: Vector3) -> bool:
	return not w.is_void(p.x, p.z) and w.occupy(p.x, p.z, 0.4, 0.0, true) == 0.0

static func _motes(at: Vector3, n: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "MossMotes%d" % n
	p.position = at + Vector3(0, 0.3, 0)
	p.amount = 8
	p.lifetime = MOTE_LIFE
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(MOTE_AREA, 0.1, MOTE_AREA)
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = MOTE_RISE
	p.initial_velocity_max = MOTE_RISE * 2.0
	p.gravity = Vector3.ZERO
	p.mesh = Models.sphere(0.03, 6)
	p.material_override = Models.toon(MOTE_COLOUR, false, 1.0)
	return p
