class_name LookSet
extends Node3D
## The look locker's set round its turntable: the light rig and a backdrop with depth. The rig is a warm key from the
## front left that casts your shadow, a rim from behind right in your glow's colour, a cool kicker from behind left, a
## soft top light and a low fill. The backdrop is a curved wall that fades from a band of your glow down into the dark,
## a halo behind you, standing stones at three depths (the camera's soft focus blurs them), a pool of light on the
## floor, a soft shadow under your feet and motes drifting up in your glow's colour. Nothing here reads the model, so any model on the turntable is
## lit the same way. tint() follows your glow; flash() is the light's answer to a pick.
##
##   var lset := LookSet.create(centre, top)
##   lset.tint(glow)

const KEY_AT := Vector3(-1.7, 3.3, 2.4)     # m from the centre: the key light, front left and high
const RIM_AT := Vector3(1.1, 2.6, -2.2)     # the glow-coloured rim, behind right
const KICK_AT := Vector3(-1.4, 2.2, -2.0)   # the cool kicker, behind left
const RIM_ENERGY := 6.0
const KICK_ENERGY := 2.4
const FLASH_K := 2.2                        # x the rim's energy at the top of a pick's flash
const FLASH_S := 0.45                       # s the flash takes to settle back
const WALL_R := 3.6                         # m: the curved wall's radius round the centre
const WALL_H := 4.5                         # m: its height (it fades out before its top)
## The standing stones behind you: [x, z, height, radius] (m from the centre), three depths for parallax.
const STONES := [[-1.9, -1.9, 2.6, 0.22], [2.1, -2.3, 3.2, 0.26], [-0.6, -3.1, 3.8, 0.3], [1.0, -3.2, 2.2, 0.2],
	[-2.5, -2.4, 3.4, 0.28], [2.9, -1.4, 1.8, 0.18]]
const STONE_COL := Color("241d3c")
const MOTES := 28

var _rim: SpotLight3D
var _wall_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D
var _pool_mat: StandardMaterial3D
var _motes_mat: StandardMaterial3D
var _flash: Tween


## The set round a turntable at `centre` whose top (where your feet stand) is `top` m up.
static func create(centre: Vector3, top: float) -> LookSet:
	var s := LookSet.new()
	s.position = centre
	s._build_lights()
	s._build_backdrop()
	s._soft_disc(Vector3(0, top + 0.004, 0), 1.3, true, Color(0, 0, 0, 0.6))
	return s


## Your glow's colour on the rim, the wall's band, the halo, the floor's pool and the motes.
func tint(col: Color) -> void:
	_rim.light_color = col.lerp(Color.WHITE, 0.45)
	(_wall_mat.albedo_texture as GradientTexture2D).gradient.set_color(1, col.darkened(0.55))
	_halo_mat.albedo_color = Color(col, 0.18)
	_pool_mat.albedo_color = Color(col, 0.22)
	_motes_mat.albedo_color = Color(col.lerp(Color.WHITE, 0.4), 0.85)


## A pick: the rim flares and settles.
func flash() -> void:
	if _flash:
		_flash.kill()
	_rim.light_energy = RIM_ENERGY * FLASH_K
	_flash = create_tween()
	_flash.tween_property(_rim, "light_energy", RIM_ENERGY, FLASH_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _build_lights() -> void:
	add_child(_spot(KEY_AT, Color("ffe6cc"), 3.2, true))
	_rim = _spot(RIM_AT, Color.WHITE, RIM_ENERGY, false)
	add_child(_rim)
	add_child(_spot(KICK_AT, Color("9fc4ff"), KICK_ENERGY, false))
	var top := _spot(Vector3(0.1, 4.2, 0.3), Color("fff2e0"), 1.2, false)
	top.spot_angle = 18.0
	add_child(top)
	var fill := OmniLight3D.new()
	fill.light_color = Color("a8b8ff")
	fill.light_energy = 0.45
	fill.omni_range = 4.0
	fill.position = Vector3(0.6, 0.5, 1.8)
	add_child(fill)


func _spot(at: Vector3, col: Color, energy: float, shadow: bool) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.light_color = col
	s.light_energy = energy
	s.spot_range = 9.0
	s.spot_angle = 26.0
	s.shadow_enabled = shadow
	s.transform = Transform3D(Basis.looking_at(Vector3(0, 1.0, 0) - at), at)      # aimed at your chest
	return s


func _build_backdrop() -> void:
	# the wall: the inside of a cylinder (its near half culled), dark at the floor, your glow's band at chest height,
	# clear at the top so the sky still shows over it
	var cyl := CylinderMesh.new()
	cyl.top_radius = WALL_R
	cyl.bottom_radius = WALL_R
	cyl.height = WALL_H
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 48
	var tex := GradientTexture2D.new()
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 128
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	g.colors = PackedColorArray([Color(0.05, 0.04, 0.12, 0.0), Color.WHITE, Color(0.04, 0.03, 0.09, 1.0)])
	tex.gradient = g
	_wall_mat = _flat_mat(Color.WHITE)
	_wall_mat.albedo_texture = tex
	_wall_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wall_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var wall := _mesh(cyl, _wall_mat, Vector3(0, WALL_H * 0.5 - 0.05, 0))
	wall.sorting_offset = -4.0      # drawn behind the halo and the motes
	var stone_mat := Models.toon(STONE_COL)
	for st in STONES:
		var c := CylinderMesh.new()
		c.top_radius = float(st[3]) * 0.8
		c.bottom_radius = float(st[3])
		c.height = float(st[2])
		c.radial_segments = 6
		var mi := _mesh(c, stone_mat, Vector3(float(st[0]), float(st[2]) * 0.5, float(st[1])))
		mi.rotation.y = float(st[0]) * 1.7
	_halo_mat = _soft_disc(Vector3(0.2, 1.3, -1.7), 4.2, false, Color.WHITE).material_override
	_pool_mat = _soft_disc(Vector3(0, 0.03, 0), 3.4, true, Color.WHITE).material_override
	_build_motes()


func _build_motes() -> void:
	var p := CPUParticles3D.new()
	p.amount = MOTES
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(2.0, 0.2, 1.4)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 0.05, 0)
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.22
	p.scale_amount_min = 0.012
	p.scale_amount_max = 0.03
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	p.mesh = sm
	_motes_mat = _flat_mat(Color.WHITE)
	_motes_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = _motes_mat
	p.position = Vector3(0, 0.2, -1.0)
	add_child(p)


func _flat_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m


func _mesh(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	add_child(mi)
	return mi


## A round soft spot: lying flat (the pool on the floor, your shadow) or standing up facing the camera (the halo).
func _soft_disc(at: Vector3, width: float, flat: bool, col: Color) -> MeshInstance3D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	var m := _flat_mat(col)
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if not flat:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var q := QuadMesh.new()
	q.size = Vector2(width, width)
	if flat:
		q.orientation = PlaneMesh.FACE_Y
	return _mesh(q, m, at)
