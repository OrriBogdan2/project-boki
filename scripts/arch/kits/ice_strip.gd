class_name IceStrip
extends RefCounted
## Claire's skate trail (docs/heroes/rimewright.md): the ice plates under her blades as ONE MultiMesh, a ring of
## instances laid in turn, not a node per plate. Each plate keeps its born time and life in the instance's custom
## data and fades in shaders/ice_strip.gdshader, so the strip costs one draw call and nothing per frame but a
## single uniform.

const SHADER: Shader = preload("res://shaders/ice_strip.gdshader")
const PLATE := Vector2(1.0, 0.7)    # m: a plate across her line and along it, before its random size
const LIFT := 0.065                 # m above the ground a plate lies (the old box's top face)

var mat := ShaderMaterial.new()
var mm := MultiMesh.new()
var node := MultiMeshInstance3D.new()
var laid := 0                       # plates laid so far (the ring's cursor)
var born := PackedFloat32Array()    # s of match time each instance was laid at (the shader has its own copy)
var last_t := -1.0e9                # match time the newest plate was laid at
var life := 3.0                     # s a plate stays (set by the first lay)

## `cap` plates at most: past that a new plate reuses the oldest.
func _init(parent: Node3D, cap: int) -> void:
	mat.shader = SHADER
	var quad := PlaneMesh.new()
	quad.size = PLATE
	quad.material = mat
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = cap
	mm.visible_instance_count = 0
	born.resize(cap)
	node.name = "IceStrip"
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

## Lays one plate at `at`, `span` times the base plate, its length along `dir` (a ground heading, x/z).
func lay(at: Vector3, span: float, dir: Vector2, now: float, plate_life: float) -> void:
	life = plate_life
	var i := laid % mm.instance_count
	var rot := Basis(Vector3.UP, atan2(-dir.x, -dir.y)).scaled(Vector3(span, 1.0, span))
	mm.set_instance_transform(i, Transform3D(rot, at + Vector3(0.0, LIFT, 0.0)))
	mm.set_instance_custom_data(i, Color(now, plate_life, randf(), 0.0))
	born[i] = now
	laid += 1
	last_t = now
	mm.visible_instance_count = mini(laid, mm.instance_count)

## Once a step: the shader's clock, only while a plate can still be showing.
func tick(now: float) -> void:
	node.visible = now - last_t < life
	if node.visible:
		mat.set_shader_parameter("now", now)

## Plates still showing at `now` (tests).
func live_count(now: float) -> int:
	var n := 0
	for i in mm.visible_instance_count:
		if now - born[i] < life:
			n += 1
	return n
