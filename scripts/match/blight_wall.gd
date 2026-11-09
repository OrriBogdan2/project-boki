class_name BlightWall
extends RefCounted
## The tide ring in the world (docs/decisions/0023): the wall of Blight closing on the Heart. One
## open cylinder, scaled to Heart.tide_r every frame, that reads from far off; the shader is unshaded
## and alpha-only, so the low preset pays for it like a ring on the ground. Presets with Settings
## q("fx") above RICH_FX add drifting bands and a patch of embers rising off the stretch of wall
## nearest the local player (a handful of CPU particles, scaled by the same fx knob as Fx).

const SHADER := preload("res://shaders/blight_wall.gdshader")
const BASE_Y := -30.0          # m below the Heart's ground: the wall's foot, under every island lip
const TOP_Y := 60.0            # m above it
const SEGMENTS := 72
const RICH_FX := 0.5           # presets above this fx get the bands and the embers
const EMBERS := 150            # ember count at fx 1.0
const EMBER_HALF_LEN := 28.0   # m of wall each side of the nearest point that the embers rise from
const COL := Color(0.72, 0.14, 0.36)

var wall: MeshInstance3D
var embers: CPUParticles3D
var _mat := ShaderMaterial.new()

func _init(parent: Node3D) -> void:
	var rich := float(Settings.q("fx")) > RICH_FX
	_mat.shader = SHADER
	_mat.set_shader_parameter("rich", 1.0 if rich else 0.0)
	_mat.set_shader_parameter("ground", -BASE_Y / (TOP_Y - BASE_Y))
	wall = MeshInstance3D.new()
	wall.name = "BlightWall"
	wall.mesh = _cylinder()
	wall.material_override = _mat
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.visible = false
	parent.add_child(wall)
	if rich:
		embers = _embers()
		parent.add_child(embers)

## Each frame: the ring's radius (0 = no ring yet) round the Heart, and where the local player is.
func update(site: Vector3, radius: float, viewer: Vector3) -> void:
	wall.visible = radius > 0.0
	if not wall.visible:
		return
	wall.position = Vector3(site.x, site.y + BASE_Y, site.z)
	wall.scale = Vector3(radius, TOP_Y - BASE_Y, radius)
	_mat.set_shader_parameter("ring_m", TAU * radius)
	if embers == null:
		return
	var out := Vector2(viewer.x - site.x, viewer.z - site.z)
	embers.emitting = out.length() > 1.0
	if not embers.emitting:
		return
	out = out.normalized()
	embers.position = site + Vector3(out.x * radius, 6.0, out.y * radius)
	embers.rotation.y = atan2(-out.x, -out.y)    # local x along the wall

## An open tube of radius 1 and height 1; UV.x once round, UV.y 0 foot .. 1 top.
static func _cylinder() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in SEGMENTS + 1:
		var a := TAU * i / SEGMENTS
		var u := float(i) / SEGMENTS
		verts.append(Vector3(cos(a), 0.0, sin(a)))
		uvs.append(Vector2(u, 0.0))
		verts.append(Vector3(cos(a), 1.0, sin(a)))
		uvs.append(Vector2(u, 1.0))
	for i in SEGMENTS:
		var b := i * 2
		idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-1, 0, -1), Vector3(2, 1, 2))
	return mesh

static func _embers() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "BlightEmbers"
	p.amount = maxi(int(EMBERS * float(Settings.q("fx"))), 8)
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(EMBER_HALF_LEN, 0.5, 0.5)
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 6.0
	p.scale_amount_max = 14.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	p.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.disable_fog = true
	p.material_override = mat
	var g := Gradient.new()
	g.set_color(0, Color(COL, 0.0))
	g.set_color(1, Color(COL, 0.0))
	g.add_point(0.2, Color(1.0, 0.45, 0.55, 0.9))
	g.add_point(0.7, Color(COL, 0.6))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
