class_name GroundsLanes
extends RefCounted
## The Movement Fields' markings (the "lanes" and "scatter" of the map's "grounds" block): distance ticks
## along the long dash lanes, so a dash or glide can be measured, and a scatter of pebbles on the open field
## for a sense of speed. Each is one MultiMesh with one shared material, no collision, no shadows.

const TICK_EVERY := 5.0  # [m] a small tick
const LABEL_EVERY := 25.0  # [m] a big tick with a distance label
const TICK_LEN := 6.4  # [m] across the lane (a lane is 7 m wide)
const TICK_SMALL := 0.18  # [m] a small tick's thickness
const TICK_BIG := 0.4  # [m] a big tick's thickness
const LIFT := 0.04  # [m] above the ground, so the tick doesn't z-fight it
const PEBBLE_R := 0.22  # [m]
const PEBBLE_FLAT := 0.5  # a pebble's height as a share of its width

static var _tick_mat: StandardMaterial3D = null
static var _pebble_mat: StandardMaterial3D = null


## Adds the ticks and the pebbles of this "grounds" block to the match.
static func build(m: Match, g: Dictionary) -> void:
	var xforms: Array = []
	var big: Array = []
	for lane in g.get("lanes", []):
		_ticks(m, lane, xforms, big)
	if not xforms.is_empty():
		_multimesh(m, _tick_mesh(), _tick_material(), xforms, big)
	var sc: Dictionary = g.get("scatter", {})
	if not sc.is_empty():
		_pebbles(m, sc["rect"], int(sc["n"]))


static func _tick_material() -> StandardMaterial3D:
	if _tick_mat == null:
		_tick_mat = StandardMaterial3D.new()
		_tick_mat.albedo_color = Color("e9dfc4")
		_tick_mat.vertex_color_use_as_albedo = true
		_tick_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _tick_mat


static func _tick_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(TICK_LEN, 0.02, 1.0)
	return mesh


## One tick every TICK_EVERY along a lane [x0, z0, x1, z1], across it; a label at each big one.
static func _ticks(m: Match, lane: Array, xforms: Array, big: Array) -> void:
	var a := Vector2(float(lane[0]), float(lane[1]))
	var b := Vector2(float(lane[2]), float(lane[3]))
	var dir := (b - a).normalized()
	var across := Basis(Vector3.UP, atan2(dir.x, dir.y))
	var steps := int((b - a).length() / TICK_EVERY)
	for i in range(1, steps + 1):
		var d := TICK_EVERY * i
		var p := a + dir * d
		var is_big := is_zero_approx(fmod(d, LABEL_EVERY))
		var at := Vector3(p.x, m.world.ground_at(p.x, p.y) + LIFT, p.y)
		xforms.append(Transform3D(across * Basis.from_scale(Vector3(1, 1, TICK_BIG if is_big else TICK_SMALL)), at))
		big.append(is_big)
		if is_big:
			var lb := Grounds.label("%d m" % int(d), Color("e9dfc4"), 1.4)
			lb.position = at + Vector3(0, 1.4, 0)
			m.add_child(lb)


static func _multimesh(m: Match, mesh: Mesh, mat: Material, xforms: Array, big: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, Color.WHITE if (big.size() > i and big[i]) else Color(1, 1, 1, 0.7))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(mi)


## n pebbles on the open ground inside `rect` [x0, z0, x1, z1] (level ground only, never on a cliff block).
static func _pebbles(m: Match, rect: Array, n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	var xforms: Array = []
	for _i in n:
		var x := rng.randf_range(float(rect[0]), float(rect[2]))
		var z := rng.randf_range(float(rect[1]), float(rect[3]))
		var ground := m.world.ground_at(x, z)
		if m.world.is_void(x, z) or ground > World.STEP:
			continue
		var s := rng.randf_range(0.6, 1.4)
		var turned := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * PEBBLE_FLAT, s))
		xforms.append(Transform3D(turned, Vector3(x, ground, z)))
	if _pebble_mat == null:
		_pebble_mat = StandardMaterial3D.new()
		_pebble_mat.albedo_color = Color("8f8a7c")
	var mesh := SphereMesh.new()
	mesh.radius = PEBBLE_R
	mesh.height = PEBBLE_R * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	_multimesh(m, mesh, _pebble_mat, xforms, [])
