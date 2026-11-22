class_name BreakFx
extends Node3D
## The look of things breaking, all from pools made once (no node is made per hit): debris chunks in
## the material's colours, a white flash over a struck prop, the ground ring and the swelling glow of a
## lit powder keg, and the scorch left by a blast.

const DEBRIS_POOL := 8
const RING_POOL := 4
const SCORCH_POOL := 6
const SCORCH_FADE := 14.0        # seconds a scorch mark takes to fade out
const DEBRIS_LIFE := 0.7         # seconds a chunk flies
const DEBRIS_SIZE := 0.1         # metres, a chunk's edge
const FLASH_ALPHA := 0.7         # how white a struck prop goes

var _debris: Array[CPUParticles3D] = []
var _ramps := {}                  # material name -> colour ramp the chunks pick from
var _next_debris := 0
var _rings: Array[MeshInstance3D] = []
var _globes: Array[MeshInstance3D] = []
var _scorch: Array[MeshInstance3D] = []
var _next_scorch := 0
var _flash_mat: StandardMaterial3D

func _init(debris_rules: Dictionary) -> void:
	name = "BreakFx"
	_build_flash()
	for mat_name in debris_rules:
		var ramp := Gradient.new()
		ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		var colors: Array = debris_rules[mat_name]["colors"]
		ramp.offsets = PackedFloat32Array()
		ramp.colors = PackedColorArray()
		for i in colors.size():
			ramp.add_point(float(i) / colors.size(), Color(String(colors[i])))
		_ramps[mat_name] = ramp
	for i in DEBRIS_POOL:
		_debris.append(_make_debris())
	for i in RING_POOL:
		_rings.append(_make_ring())
		_globes.append(_make_globe())
	for i in SCORCH_POOL:
		_scorch.append(_make_scorch())

## Chunks of `mat_name` burst out of `at`; `power` scales how many and how fast (a blast throws more).
func shatter(at: Vector3, mat_name: String, chunks: int, power := 1.0) -> void:
	var p := _debris[_next_debris]
	_next_debris = (_next_debris + 1) % DEBRIS_POOL
	p.global_position = at
	p.amount = maxi(4, int(round(chunks * power)))
	p.color_initial_ramp = _ramps[mat_name]
	p.initial_velocity_min = 2.5 * power
	p.initial_velocity_max = 6.0 * power
	p.restart()
	p.emitting = true

## A white flash over every mesh of a prop (a struck keg), on or off.
func flash_prop(prop: Node3D, on: bool) -> void:
	for mi in prop.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = _flash_mat if on else null

## Takes a ground ring and a glow for a keg at `at`; returns them for fuse_step and release.
func arm(at: Vector3, radius: float, col: Color) -> Array:
	var ring := _free_of(_rings)
	var globe := _free_of(_globes)
	ring.mesh = Models.flat_quad(radius * 2.0)
	(ring.material_override as ShaderMaterial).set_shader_parameter("color", Color(col, 0.9))
	ring.global_position = at + Vector3(0, 0.07, 0)
	ring.visible = true
	globe.global_position = at + Vector3(0, 0.45, 0)
	globe.visible = true
	(globe.material_override as ShaderMaterial).set_shader_parameter("color", Color(col, 0.0))
	return [ring, globe]

## The fuse at `progress` 0..1: the ring fills toward the edge and the glow swells and brightens.
func fuse_step(parts: Array, progress: float, col: Color) -> void:
	var ring: MeshInstance3D = parts[0]
	var globe: MeshInstance3D = parts[1]
	(ring.material_override as ShaderMaterial).set_shader_parameter("progress", progress)
	globe.scale = Vector3.ONE * lerpf(0.7, 2.4, progress)
	(globe.material_override as ShaderMaterial).set_shader_parameter("color", Color(col, 0.35 + 0.65 * progress))

## Gives a ring and glow back to the pool.
func release(parts: Array) -> void:
	for mi in parts:
		(mi as MeshInstance3D).visible = false

## A dark scorch on the ground under a blast, `radius` wide, fading over SCORCH_FADE seconds.
func scorch(at: Vector3, radius: float) -> void:
	var mi := _scorch[_next_scorch]
	_next_scorch = (_next_scorch + 1) % SCORCH_POOL
	var mat := mi.material_override as StandardMaterial3D
	if mi.has_meta("fade"):
		(mi.get_meta("fade") as Tween).kill()
	mat.albedo_color = Color(1, 1, 1, 1)
	mi.scale = Vector3.ONE * radius
	mi.rotation.y = randf() * TAU
	mi.global_position = at + Vector3(0, 0.05, 0)
	mi.visible = true
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, SCORCH_FADE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.hide)
	mi.set_meta("fade", tw)

func _free_of(pool: Array[MeshInstance3D]) -> MeshInstance3D:
	for mi in pool:
		if not mi.visible:
			return mi
	return pool[0]

func _build_flash() -> void:
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1, 0.96, 0.85, FLASH_ALPHA)

func _make_debris() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(DEBRIS_SIZE, DEBRIS_SIZE * 0.6, DEBRIS_SIZE * 1.4)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	box.material = mat
	p.mesh = box
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.lifetime = DEBRIS_LIFE
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, -16, 0)
	p.angle_max = 360.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.local_coords = false
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(0.7, 1))
	shrink.add_point(Vector2(1, 0))
	p.scale_amount_curve = shrink
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _make_ring() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/telegraph.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi

func _make_globe() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Models.sphere(0.5, 10)
	mi.material_override = Models.glow_mat(Color.WHITE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi

func _make_scorch() -> MeshInstance3D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var g := Gradient.new()
	var soot := Color(0.05, 0.03, 0.03)
	g.colors = PackedColorArray([Color(soot, 0.85), Color(soot, 0.55), Color(soot, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	tex.gradient = g
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = Models.flat_quad(2.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi
