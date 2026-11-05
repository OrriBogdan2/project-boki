class_name DropClouds
extends MultiMeshInstance3D
## The clouds you fall past: soft puffs scattered through the sky over the island, a
## static MultiMesh (one draw call, nothing to do per frame) that the camera falls through. The shader
## faces them to the camera and thins them as it arrives. The count follows the quality's fx.

static var COUNT: int = int(DropData.rules["look"]["puffs"])
const SPREAD := 1.05               # of the map's width each way from its middle
const BELOW := 0.30                # share of the cloud deck's height the puffs reach under it
const ABOVE := 0.55                # ...and above it
const R_MIN := 26.0                # m
const R_MAX := 60.0

## Built for the sky over `m`, hidden until the player is up there.
func _init(m: Match) -> void:
	name = "DropClouds"
	var fx_k := float(Settings.q("fx"))
	var n := maxi(8, int(COUNT * fx_k))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	mm.mesh = q
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = 107
	var mid := Vector3(m.world.w * 0.5, 0.0, m.world.h * 0.5)
	var cloud_y := float(DropData.rules["look"]["cloud_y"])
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * m.world.w * SPREAD
		var y := cloud_y * rng.randf_range(1.0 - BELOW, 1.0 + ABOVE)
		var r := rng.randf_range(R_MIN, R_MAX)
		var at := mid + Vector3(cos(a) * d, y, sin(a) * d)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * r), at))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.35, 0.75), 0.0, 0.0))
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/drop_puff.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-2000, -200, -2000), Vector3(4000, 1200, 4000))
	visible = false
