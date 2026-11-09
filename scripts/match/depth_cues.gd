class_name DepthCues
extends Node3D
## Height readability (briefs/CAMERA_DEPTH.md), behind Settings "depth_cues". Purely visual: it draws a
## soft shadow disc on the ground straight under every hunter, at the ground's own height, so a body at
## a ledge or in the air reads as high above what is below it. The ground itself gets its share in
## shaders/terrain.gdshader (cliff faces darker toward their foot, a warm lip on a terrace step, a cold rim and
## violet haze on an abyss edge: docs/EDGE_READ.md), fed by k().

const DISC := 2.0       # m, shadow disc diameter at the feet (a hunter's body is ~0.8 m wide)
const LIFT := 0.04      # m, above the ground so the disc does not z-fight
const STRENGTH := 0.75  # darkest alpha at the centre of the disc

var _match: Match
var _discs: Dictionary = {}     # Hunter -> MeshInstance3D
var _mat: ShaderMaterial
var _mesh: QuadMesh

## Strength of the terrain shader's height cues: 1 when the setting is on, 0 when off.
static func k() -> float:
	return 1.0 if Settings.get_v("depth_cues") else 0.0

func _init(m: Match) -> void:
	_match = m
	name = "DepthCues"
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/blob_shadow.gdshader")
	_mat.set_shader_parameter("strength", STRENGTH)
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(DISC, DISC)
	_mesh.orientation = PlaneMesh.FACE_Y

func _process(_dt: float) -> void:
	for h: Hunter in _match.hunters:
		var disc: MeshInstance3D = _discs.get(h)
		if disc == null:
			disc = MeshInstance3D.new()
			disc.mesh = _mesh
			disc.material_override = _mat
			disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(disc)
			_discs[h] = disc
		var p := h.global_position
		var y := _match.world.ground_at(p.x, p.z)
		disc.visible = h.visible and not h.out and y > World.VOID + 1.0 and y <= p.y + 0.3
		disc.global_position = Vector3(p.x, y + LIFT, p.z)
