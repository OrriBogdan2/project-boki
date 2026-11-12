class_name TrainLamp
extends Node3D
## The engine's approach, readable before it arrives: a halo round the headlight, a soft beam ahead
## of it and a short fading trail behind the last car. All of it follows the engine's heat (how near
## its full speed it is); shared materials, no particles.

const HALO_R := 0.9           # m
const BEAM_LEN := 14.0        # m, ahead of the lamp
const BEAM_R := 1.5           # m, at the far end
const TRAIL_N := 6
const TRAIL_STEP := 1.7       # m of track between trail blobs
const TRAIL_LEN := 0.9        # m, a blob's half length along the track (it tapers down the trail)

var train: SkyTrain = null
var halo_mat: ShaderMaterial = null
var beam_mat: ShaderMaterial = null
var trail_mat: ShaderMaterial = null
var trail: MultiMesh = null
var trail_node: MultiMeshInstance3D = null

func setup(sky_train: SkyTrain, engine: Node3D, lamp_at: Vector3) -> void:
	train = sky_train
	name = "TrainLamp"
	engine.add_child(self)
	position = lamp_at
	halo_mat = Models.glow_mat(Color(1.0, 0.92, 0.65, 0.0))
	beam_mat = Models.glow_mat(Color(1.0, 0.9, 0.62, 0.0))
	trail_mat = Models.glow_mat(Color(1.0, 0.7, 0.4, 0.0))
	Models.part(self, Models.sphere(HALO_R, 12), halo_mat).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ahead := Vector3(0, -0.05, -BEAM_LEN * 0.5)
	var cone := Models.part(self, Models.cyl(BEAM_R, 0.08, BEAM_LEN, 12), beam_mat, ahead)
	cone.rotation.x = -PI * 0.5
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail = MultiMesh.new()
	trail.transform_format = MultiMesh.TRANSFORM_3D
	trail.mesh = Models.sphere(1.0, 10)
	trail.instance_count = TRAIL_N
	trail_node = MultiMeshInstance3D.new()
	trail_node.multimesh = trail
	trail_node.material_override = trail_mat
	trail_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_node.top_level = true
	trail_node.custom_aabb = AABB(Vector3(-400, -20, -400), Vector3(800, 40, 800))
	add_child(trail_node)

## heat: 0 standing .. 1 at full speed.
func tick(heat: float, moving: bool) -> void:
	halo_mat.set_shader_parameter("color", Color(1.0, 0.92, 0.65, 0.25 + 0.35 * heat))
	beam_mat.set_shader_parameter("color", Color(1.0, 0.9, 0.62, 0.05 + 0.3 * heat))
	trail_node.visible = moving
	if not moving:
		return
	trail_mat.set_shader_parameter("color", Color(1.0, 0.7, 0.4, 0.15 + 0.35 * heat))
	trail_node.global_transform = Transform3D.IDENTITY
	var tail := train.head_s - (train.cars_n - 1) * SkyTrain.CAR_GAP - SkyTrain.CAR_LEN * 0.5 - 0.6
	for i in TRAIL_N:
		var s := tail - i * TRAIL_STEP
		var p := train.world.train_at(s) + Vector3(0, 0.1, 0)
		var f := train.world.train_at(s + 0.5) - train.world.train_at(s - 0.5)
		var shrink := 1.0 - float(i) / (TRAIL_N + 1)
		var b := Basis.looking_at(f.normalized(), Vector3.UP) if f.length() > 0.001 else Basis.IDENTITY
		trail.set_instance_transform(i, Transform3D(b.scaled(Vector3(0.45, 0.3, TRAIL_LEN) * shrink), p))
