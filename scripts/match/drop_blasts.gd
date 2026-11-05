class_name DropBlasts
extends MultiMeshInstance3D
## The drop's two beats, the glider's snap and the landing's dust ring (owner item 107): a pool in one
## MultiMesh, so a whole lobby coming down is one draw call and no node churn. shaders/drop_blast.gdshader.

const SIZE := 14                   # at most this many at once: the oldest gives way
const SNAP_R := 6.0                # m
const SNAP_S := 0.42               # s
const LAND_R := 9.5                # m
const LAND_S := 0.85               # s

static var HIDDEN := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0))

var live: Array = []               # {i, t, dur, kind, seed}
var _next := 0

func _init() -> void:
	name = "DropBlasts"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	mm.mesh = q
	mm.instance_count = SIZE
	for i in SIZE:
		mm.set_instance_transform(i, HIDDEN)
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/drop_blast.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-2000, -200, -2000), Vector3(4000, 800, 4000))
	visible = false

## The glider's crack of air at `at`.
func snap(at: Vector3, col: Color, scale_k := 1.0) -> void:
	_add(at, SNAP_R * scale_k, SNAP_S, 0.0, col)

## The dust ring on the ground at `at`.
func land(at: Vector3, col: Color) -> void:
	_add(at + Vector3(0, 0.12, 0), LAND_R, LAND_S, 1.0, col)

func _add(at: Vector3, radius: float, dur: float, kind: float, col: Color) -> void:
	var i := _next
	_next = (_next + 1) % SIZE
	for b in live:
		if int(b["i"]) == i:
			live.erase(b)
			break
	var seed_v := randf()
	live.append({"i": i, "t": 0.0, "dur": dur, "kind": kind, "seed": seed_v})
	multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * radius), at))
	multimesh.set_instance_color(i, col)
	multimesh.set_instance_custom_data(i, Color(0.0, kind, seed_v, 0.0))
	visible = true

func _process(delta: float) -> void:
	for b in live.duplicate():
		b["t"] = float(b["t"]) + delta
		var i := int(b["i"])
		if float(b["t"]) >= float(b["dur"]):
			multimesh.set_instance_transform(i, HIDDEN)
			live.erase(b)
		else:
			multimesh.set_instance_custom_data(i, Color(float(b["t"]) / float(b["dur"]), float(b["kind"]), float(b["seed"]), 0.0))
	if live.is_empty():
		visible = false
