class_name HubHorizon
extends RefCounted
## The five zone islands on the hub's horizon (briefs/design/GARDEN.md 10.1, step 9): low-poly
## islands floating in the void round the hub, so it promises places to go. An open zone's island
## is lit, warm and in the zone's colour; a locked one is grey in mist. Which is which is read from
## Save.d["zones"] when the hub loads, so opening a zone lights its island the next time you arrive.
## One mesh per island and one shared material per state: five draw calls in all (10.6 allows five).

## Where each island floats: [degrees round from north (east +), metres out from the hub's middle, metres
## below its ground]. The home camera looks down from the south, so at the arrival zoom the hub's north rim
## is the top of the screen and its south rim the bottom: the islands hang in the corners and at the sides,
## in the void beside the hub, where you see them the moment you arrive (garden_zones_check asserts it).
const SLOTS := [[-114.0, 16.0, 7.0], [-84.0, 18.0, 9.0], [58.0, 17.0, 5.5], [92.0, 17.5, 8.5], [118.0, 16.5, 7.5]]
const TOP_R := 3.6         # m, an island's top radius
const DEPTH := 4.5         # m, how far its rocky underside hangs
const SIDES := 7           # corners of the low-poly outline
const HILL := 1.4          # m the middle of an island's top rises, so it reads as land, not a plate
const TREES := [Vector3(-1.1, 0.6, 0.55), Vector3(1.0, -0.4, 0.6)]   # (x, z, how far up the hill) per tree
const TREE_R := 0.8        # m, a tree's foot radius
const TREE_H := 2.2        # m, its height
const TREE_DARK := 0.35    # how much darker than the island's top a tree is
const LIT_GLOW := 0.45     # how much a lit island glows (shader glow 0..1)
const LIT_WARM := 0.15     # how far a lit island's colours warm toward sunlight (0 none .. 1 all)
const MIST := 0.9          # how far a locked island's colours wash toward grey mist (0 none .. 1 all)
const WARM := Color("ffd9a0")
const MIST_GREY := Color("4f545e")
const ROCK := Color("6e6577")

static var _mats := {}      # open (bool) -> the one material that state shares

## Adds the five islands to `parent`, centred on `middle` (the hub's middle).
static func place(parent: Node3D, middle: Vector3) -> void:
	var ids := GardenZones.ids()
	for i in ids.size():
		var slot: Array = SLOTS[i % SLOTS.size()]
		var a := deg_to_rad(float(slot[0]))
		var open := GardenZones.is_open(ids[i])
		var mi := MeshInstance3D.new()
		mi.name = "Horizon_%s" % ids[i]
		mi.mesh = island_mesh(i, Color(String(GardenZones.info(ids[i])["colour"])), open)
		mi.material_override = _mat(open)
		mi.position = middle + Vector3(sin(a) * float(slot[1]), -float(slot[2]), -cos(a) * float(slot[1]))
		mi.set_meta("open", open)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)

static func _mat(open: bool) -> ShaderMaterial:
	if not _mats.has(open):
		var m := Models.vtoon()
		m.set_shader_parameter("glow", LIT_GLOW if open else 0.0)
		_mats[open] = m
	return _mats[open]

## A flat-topped island with a jagged underside, from one triangle list. `seed_i` varies the outline.
static func island_mesh(seed_i: int, colour: Color, open: bool) -> ArrayMesh:
	var top := colour.lerp(WARM, LIT_WARM) if open else colour.lerp(MIST_GREY, MIST)
	var under := ROCK if open else ROCK.lerp(MIST_GREY, MIST)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5100 + seed_i
	var rim: Array = []
	for k in SIDES:
		var a := TAU * float(k) / float(SIDES)
		var r := TOP_R * rng.randf_range(0.75, 1.0)
		rim.append(Vector3(sin(a) * r, 0, cos(a) * r))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0, -DEPTH * rng.randf_range(0.8, 1.1), 0)
	for k in SIDES:
		var p: Vector3 = rim[k]
		var q: Vector3 = rim[(k + 1) % SIDES]
		_tri(st, Vector3(0, HILL, 0), q, p, top)
		_tri(st, p, q, tip, under)
	for t in TREES:      # a couple of low-poly trees, so a speck in the void reads as land you could go to
		_cone(st, Vector3(t.x, HILL * t.z, t.y), top.darkened(TREE_DARK))
	st.generate_normals()
	return st.commit()

## A five-sided cone (a tree, or in mist a crag) standing on `foot`.
static func _cone(st: SurfaceTool, foot: Vector3, col: Color) -> void:
	var apex := foot + Vector3(0, TREE_H, 0)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var b := TAU * float(k + 1) / 5.0
		_tri(st, foot + Vector3(sin(a), 0, cos(a)) * TREE_R, foot + Vector3(sin(b), 0, cos(b)) * TREE_R, apex, col)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for v in [a, b, c]:
		st.set_color(col)
		st.add_vertex(v)
