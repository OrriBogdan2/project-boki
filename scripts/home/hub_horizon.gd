class_name HubHorizon
extends RefCounted
## The five zone islands floating in the hub's sky (briefs/design/GARDEN.md 10.1, step 9): cheap
## low-poly silhouettes, one mesh and one material each, so five draw calls in all. An open zone's
## island is lit in the zone's colour; a locked one is misty (its colours washed toward the sky).
## Which is which comes from Save.d["zones"] (GardenZones.is_open). Nothing here is saved or ticked.

const RING_R := 62.0       # m from the hub's middle to each island
const ARC := 2.4           # rad of sky the five spread over, centred on the view's far side (north, -z)
const RISE := 9.0          # m an island floats above the hub's ground, plus RISE_STEP for each odd one
const RISE_STEP := 5.0
const TOP_R := 9.0         # m, an island's top radius
const DEPTH := 8.0         # m, how far its rocky underside hangs
const SIDES := 7           # corners of the low-poly outline
const MIST := 0.7          # how far a locked island's colours wash toward the sky (0 none .. 1 all)
const SKY := Color("8a96c8")
const ROCK := Color("6e6577")

## Adds the five islands to `parent`, centred on `middle` (the hub's middle).
static func place(parent: Node3D, middle: Vector3) -> void:
	var ids := GardenZones.ids()
	for i in ids.size():
		var a := PI + (float(i) / float(ids.size() - 1) - 0.5) * ARC
		var at := middle + Vector3(sin(a), 0, -cos(a)) * RING_R
		at.y = RISE + RISE_STEP * float(i % 2)
		var open := GardenZones.is_open(ids[i])
		var mi := MeshInstance3D.new()
		mi.name = "Horizon_%s" % ids[i]
		mi.mesh = island_mesh(i, Color(String(GardenZones.info(ids[i])["colour"])), open)
		mi.material_override = _mat(open)
		mi.position = at
		mi.set_meta("open", open)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)

static func _mat(open: bool) -> ShaderMaterial:
	var m := Models.toon(Color.WHITE, false, 0.35 if open else 0.0)
	m.set_shader_parameter("use_vertex_color", true)
	return m

## A flat-topped island with a jagged underside, from one triangle list. `seed_i` varies the outline.
static func island_mesh(seed_i: int, colour: Color, open: bool) -> ArrayMesh:
	var top := colour if open else colour.lerp(SKY, MIST)
	var under := ROCK if open else ROCK.lerp(SKY, MIST)
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
		_tri(st, Vector3.ZERO, q, p, top)
		_tri(st, p, q, tip, under)
	st.generate_normals()
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col); st.add_vertex(a)
	st.set_color(col); st.add_vertex(b)
	st.set_color(col); st.add_vertex(c)
