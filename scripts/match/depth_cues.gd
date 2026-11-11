class_name DepthCues
extends Node3D
## Height readability (briefs/CAMERA_DEPTH.md), behind Settings "depth_cues". Purely visual: it draws a
## soft shadow disc on the ground straight under every hunter and every flying shot, at the ground's own
## height, so a body at a ledge or a shot in the air reads as high above what is below it. The ground
## itself gets its share in shaders/terrain.gdshader (cliff faces darker toward their foot, a lit cliff
## lip), fed by k().

const DISC := 2.0       # m, shadow disc diameter at the feet (a hunter's body is ~0.8 m wide)
const LIFT := 0.04      # m, above the ground so the disc does not z-fight
const ABYSS_DIM := 0.55 # brightness of the abyss clouds relative to normal
const STRENGTH := 0.75  # darkest alpha at the centre of the disc
const SHOT_DISC := 0.9  # m, shadow disc diameter under a shot (they are small, so the disc is too)
const SHOT_STRENGTH := 0.55 # darkest alpha at the centre of a shot's disc (fainter than a hunter's)

var _match: Match
var _discs: Dictionary = {}     # Hunter -> MeshInstance3D
var _shot_discs: Array[MeshInstance3D] = []     # grows to the most shots seen at once, then is reused
var _mat: ShaderMaterial
var _shot_mat: ShaderMaterial
var _mesh: QuadMesh
var _shot_mesh: QuadMesh

## Strength of the terrain shader's height cues: 1 when the setting is on, 0 when off.
static func k() -> float:
	return 1.0 if Settings.get_v("depth_cues") else 0.0

## Brightness of the abyss clouds (a shader multiplier): darker when the setting is on.
static func abyss_dim() -> float:
	return ABYSS_DIM if Settings.get_v("depth_cues") else 1.0

func _init(m: Match) -> void:
	_match = m
	name = "DepthCues"
	_mat = _disc_material(STRENGTH)
	_shot_mat = _disc_material(SHOT_STRENGTH)
	_mesh = _disc_mesh(DISC)
	_shot_mesh = _disc_mesh(SHOT_DISC)

func _disc_material(strength: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/blob_shadow.gdshader")
	mat.set_shader_parameter("strength", strength)
	return mat

func _disc_mesh(width: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, width)
	mesh.orientation = PlaneMesh.FACE_Y
	return mesh

func _new_disc(mesh: QuadMesh, mat: ShaderMaterial) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.mesh = mesh
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	return disc

## Lays `disc` on the ground under `p`; hidden over the void or when the body is not above the ground.
func _lay(disc: MeshInstance3D, p: Vector3, shown: bool) -> void:
	var y := _match.world.ground_at(p.x, p.z)
	disc.visible = shown and y > World.VOID + 1.0 and y <= p.y + 0.3
	disc.global_position = Vector3(p.x, y + LIFT, p.z)

func _process(_dt: float) -> void:
	for h: Hunter in _match.hunters:
		var disc: MeshInstance3D = _discs.get(h)
		if disc == null:
			disc = _new_disc(_mesh, _mat)
			_discs[h] = disc
		_lay(disc, h.global_position, h.visible and not h.out)
	var n := 0
	for s: Dictionary in _match.shots:
		var node: MeshInstance3D = s["node"]
		if node == null:
			continue
		if n == _shot_discs.size():
			_shot_discs.append(_new_disc(_shot_mesh, _shot_mat))
		_lay(_shot_discs[n], node.global_position, true)
		n += 1
	for i in range(n, _shot_discs.size()):
		_shot_discs[i].visible = false
