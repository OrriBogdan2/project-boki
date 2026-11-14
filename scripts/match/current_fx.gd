class_name CurrentFx
extends Node3D
## The air currents' look (World.winds, World.updrafts): a wind road is a MultiMesh of dart-shaped streak
## cards flowing along it plus a ring at each end, so it reads from the ground and in a glide where it
## starts, where it ends and which way it pushes; an updraft is a soft column with climbing streaks.
## While the local player rides one, that current's look strengthens (and a road's streaks flow the way
## the glider is going). The streak count follows the preset's fx amount, so Low draws fewer.

const STREAK_SHADER := preload("res://shaders/wind.gdshader")
const UPDRAFT_SHADER := preload("res://shaders/updraft.gdshader")
const STREAKS_PER_M := 0.8      # cards per metre of road at fx 1.0
const MIN_STREAKS := 6
const MAX_STREAKS := 48
const LANE := Vector2(1.1, 1.5)     # m: how far a card strays above/below and beside the road's axis
const SPEEDS := Vector2(10.0, 14.0)     # m/s: a card's slide (a glider on the road is carried at 14)
const RING_R := 1.9      # m: the same as the road's catch radius (World.wind_at)
const FADE_IN := 4.0     # 1/s: how fast a current's look strengthens when you enter it (and eases off)
const PLAIN_AIR := Color(1.0, 0.95, 0.75, 0.35)     # an updraft's own tint (a lair's or a boss's is passed in)

var rider: Hunter = null
var _road_mats: Array[ShaderMaterial] = []
var _road_rings: Array[ShaderMaterial] = []
var _road_boost: Array[float] = []
var _column_mats: Array[ShaderMaterial] = []
var _column_boost: Array[float] = []
var _world: World

## Builds a node per current in the world's data. fx is the preset's particle/streak amount (0..1).
func build(w: World, fx: float) -> void:
	_world = w
	for i in w.winds.size():
		_add_road(i, w.winds[i], fx)
	for i in w.updrafts.size():
		var u: Dictionary = w.updrafts[i]
		var c: Vector3 = u["pos"]
		var col := updraft_visual(float(u["r"]), c.y - 6.0, float(u["top"]), PLAIN_AIR, fx)
		col.name = "Column%d" % i
		col.position = Vector3(c.x, 0.0, c.z)
		add_child(col)
		_column_mats.append(col.get_node("Column").material_override)
		_column_boost.append(0.0)

func _add_road(i: int, wd: Dictionary, fx: float) -> void:
	var a: Vector3 = wd["a"]
	var d: Vector3 = wd["b"] - a
	var span := d.length()
	var fwd := d / span
	var side := fwd.cross(Vector3.UP).normalized()
	var road := Node3D.new()
	road.name = "Road%d" % i
	road.transform = Transform3D(Basis(fwd, side.cross(fwd), side), a)     # x along the road, so (span, 0, 0) is b
	add_child(road)
	var mat := ShaderMaterial.new()
	mat.shader = STREAK_SHADER
	mat.set_shader_parameter("road_len", span)
	var n := clampi(roundi(span * STREAKS_PER_M * fx), MIN_STREAKS, MAX_STREAKS)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (i + 1)
	for k in n:
		var lane := Vector3(0.0, rng.randf_range(-LANE.x, LANE.x), rng.randf_range(-LANE.y, LANE.y))
		mm.set_instance_transform(k, Transform3D(Basis(), lane))
		var speed := rng.randf_range(SPEEDS.x, SPEEDS.y)
		mm.set_instance_custom_data(k, Color((k + rng.randf()) / n, speed, rng.randf_range(0.7, 1.3), 0.0))
	var streaks := MultiMeshInstance3D.new()
	streaks.name = "Streaks"
	streaks.multimesh = mm
	streaks.material_override = mat
	streaks.custom_aabb = AABB(Vector3(-3, -3, -3), Vector3(span + 6.0, 6, 6))     # (the shader moves the cards)
	streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	road.add_child(streaks)
	var ring_mat := Models.glow_mat(Color(0.75, 0.95, 1.0, 0.45))
	var ring := TorusMesh.new()
	ring.inner_radius = RING_R - 0.12
	ring.outer_radius = RING_R
	ring.rings = 24
	ring.ring_segments = 6
	for end in 2:
		var mi := MeshInstance3D.new()
		mi.name = "Ring%d" % end
		mi.mesh = ring
		mi.material_override = ring_mat
		var axis_x := Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)     # (the torus stands on its y axis)
		mi.transform = Transform3D(axis_x, Vector3(span * end, 0, 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		road.add_child(mi)
	_road_mats.append(mat)
	_road_rings.append(ring_mat)
	_road_boost.append(0.0)

## A column of rising air (the updraft shader, plus motes climbing it), from y0 up to y1 in the node's
## own space. Island-edge updrafts and a lair's escape updraft both use it. fx scales the motes.
static func updraft_visual(r: float, y0: float, y1: float, tint := PLAIN_AIR, fx := 1.0) -> Node3D:
	var root := Node3D.new()
	var hgt: float = y1 - y0
	var col := MeshInstance3D.new()
	var cm := Models.plain_cyl(r, r * 1.15, hgt, 18)
	cm.cap_top = false
	cm.cap_bottom = false
	col.mesh = cm
	var mat := ShaderMaterial.new()
	mat.shader = UPDRAFT_SHADER
	mat.set_shader_parameter("tiles", hgt / 4.0)
	if tint != PLAIN_AIR:
		mat.set_shader_parameter("color", Color(tint, 0.85))
		mat.set_shader_parameter("speed", 1.1)
	col.material_override = mat
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	col.position = Vector3(0, y0 + hgt * 0.5, 0)
	col.name = "Column"
	root.add_child(col)
	var p := CPUParticles3D.new()
	p.amount = maxi(4, roundi(18.0 * fx))
	p.lifetime = 1.6
	p.preprocess = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r * 0.8
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3.ZERO
	p.mesh = Models.sphere(0.06, 4)
	p.material_override = Models.glow_mat(Color(1.0, 0.96, 0.8, 0.8) if tint == PLAIN_AIR else Color(tint, 0.85))
	p.position = Vector3(0, y0 + 3.0, 0)
	root.add_child(p)
	return root

func _process(dt: float) -> void:
	if rider == null:
		var mt := _world.get_parent() as Match
		if mt == null or mt.player == null:
			return
		rider = mt.player
	var wi := -1
	var ci := -1
	if rider.in_current and rider.gliding:
		var wd := _world.wind_at(rider.pos)
		if not wd.is_empty():
			wi = int(wd["i"])
			var along: Vector3 = wd["dir"]
			var with_road := rider.vel.x * along.x + rider.vel.z * along.z
			_road_mats[wi].set_shader_parameter("flow", -1.0 if with_road < 0.0 else 1.0)
		ci = _world.updrafts.find(_world.updraft_at(rider.pos))
	_ease(_road_boost, wi, dt, _road_mats, _road_rings)
	_ease(_column_boost, ci, dt, _column_mats)

## Eases each current's boost toward 1 for the one being ridden (idx) and 0 for the rest, writing it to the shaders.
func _ease(boosts: Array[float], idx: int, dt: float, mats: Array[ShaderMaterial],
		rings: Array[ShaderMaterial] = []) -> void:
	for i in boosts.size():
		var want := 1.0 if i == idx else 0.0
		if boosts[i] == want:
			continue
		boosts[i] = move_toward(boosts[i], want, FADE_IN * dt)
		mats[i].set_shader_parameter("boost", boosts[i])
		if not rings.is_empty():
			rings[i].set_shader_parameter("color", Color(0.75, 0.95, 1.0, 0.45 + 0.4 * boosts[i]))
		if want == 0.0 and boosts[i] == 0.0 and not rings.is_empty():
			mats[i].set_shader_parameter("flow", 1.0)
