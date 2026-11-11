class_name ZoneLook
extends RefCounted
## What makes a garden zone its own place (briefs/design/GARDEN.md 10.7 step 7, data: the "look" of a zone
## in content/rules/garden_zones.json): its own island and plaything list, kept on Save.d["zones"][id]["layout"]
## (HomeLayout.of hands it out while you are in that zone), a sky that stays at one hour, and the moss
## scattered over its ground. A zone without a look is Bramblebank's island, the layout at Save.d["layout"].

const RANGE_X := 12.0         # m east and west of the landing the moss clumps may lie
const RANGE_Z := 9.0          # m north and south of it
const MOSS_R := 0.11          # m, a moss tuft's radius
const MOSS_FLAT := 0.5        # of its radius: tufts are low
const MOSS_GLOW := 0.7        # toon-shader glow of the moss (0 flat, 1 lit from within)
const MOTE_LIFE := 5.0        # s a drifting mote lives
const MOTE_RISE := 0.12       # m/s the motes drift up
const MOTE_AREA := 1.6        # m, half-width of the square a mote emitter fills

static var _tidy: Dictionary = {}    # the zone layout already tidied this session (by reference)

static func look(id: String) -> Dictionary:
	return GardenZones.info(id).get("look", {})

## The sky clock a zone stays at (day_t), or the real clock for a zone that has none.
static func sky_t(id: String, day_t: float) -> float:
	return float(look(id).get("sky_t", day_t))

## The island you are standing on when `d` is your save and the zone you are in has its own, else {}.
static func layout_of(d: Dictionary) -> Dictionary:
	var id := GardenZones.here
	if id == "" or not is_same(d, Save.d) or look(id).is_empty():
		return {}
	var zone: Dictionary = Save.d["zones"].get_or_add(id, {"open": false})
	if not zone.has("layout"):
		zone["layout"] = _make(look(id))
	if not is_same(_tidy, zone["layout"]):
		HomeLayout.ensure({"layout": zone["layout"]})
		_tidy = zone["layout"]
	return zone["layout"]

## Puts `lay` back as the island you are on (an undo). False when that is not a zone's own island.
static func store(d: Dictionary, lay: Dictionary) -> bool:
	if layout_of(d).is_empty():
		return false
	Save.d["zones"][GardenZones.here]["layout"] = lay
	return true

## A new zone island: a farm-start shape of its own, with the pieces listed in its look around the landing.
static func _make(spec: Dictionary) -> Dictionary:
	var lay := HomeLayout.fresh()
	lay["seed"] = int(spec["seed"])
	lay["fs"] = 1
	lay["fb"] = 1
	lay["made"] = true
	lay["sk"] = HomeLayout.fs_scale(int(spec["seed"]))
	lay["theme"] = String(spec["theme"])
	lay["themes"] = [String(spec["theme"])]
	for p in spec["deco"]:
		var x := int(HomeLayout.LANDING.x) + int(p[1])
		var z := int(HomeLayout.LANDING.z) + int(p[2])
		(lay["deco"] as Array).append({"u": HomeLayout._next_uid(lay), "id": String(p[0]), "x": x, "z": z, "r": 0})
	return lay

## The zone's moss (tufts in a few clumps on free ground, one MultiMesh and one material) and its mote emitters.
static func dress(h) -> void:
	var moss: Dictionary = look(GardenZones.here).get("moss", {})
	if moss.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(look(GardenZones.here)["seed"])
	var clumps: Array = []
	for i in 400:
		if clumps.size() >= int(moss["clumps"]):
			break
		var c := HomeLayout.LANDING + Vector3(rng.randf_range(-RANGE_X, RANGE_X), 0, rng.randf_range(-RANGE_Z, RANGE_Z))
		if _free(h.world, c):
			clumps.append(c)
	if clumps.is_empty():
		return
	var tufts: Array = []
	for i in 600:
		if tufts.size() >= int(moss["count"]):
			break
		var at: Vector3 = clumps[i % clumps.size()] + Vector3(rng.randf_range(-2.2, 2.2), 0, rng.randf_range(-2.2, 2.2))
		if _free(h.world, at):
			var turn := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.4))
			tufts.append(Transform3D(turn, at))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Models.sphere(MOSS_R, 8)
	mm.instance_count = tufts.size()
	for i in tufts.size():
		mm.set_instance_transform(i, tufts[i].scaled_local(Vector3(1, MOSS_FLAT, 1)))
	var mi := MultiMeshInstance3D.new()
	mi.name = "LanternMoss"
	mi.multimesh = mm
	mi.material_override = Models.toon(Color("4fb8a0"), false, MOSS_GLOW)
	h.add_child(mi)
	for i in mini(int(moss["motes"]), clumps.size()):
		h.add_child(_motes(clumps[i], i))

static func _free(w: World, p: Vector3) -> bool:
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
	p.material_override = Models.toon(Color("b8fff0"), false, 1.0)
	return p
