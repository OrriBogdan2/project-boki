class_name DepthCues
extends Node3D
## Height readability (briefs/CAMERA_DEPTH.md), behind Settings "depth_cues". Purely visual: it draws a
## soft shadow disc on the ground straight under every hunter and every flying shot, at the ground's own
## height, so a body at a ledge or a shot in the air reads as high above what is below it. A hunter's
## disc fades out with height, and an airborne hunter gets a ring on the ground in its own colour (gold
## for you, blue for a teammate, red for an enemy); both are tuned in content/rules/depth_cues.json. The ground
## itself gets its share in shaders/terrain.gdshader (cliff faces darker toward their foot, a lit cliff
## lip), fed by k().

const DISC := 2.0       # m, shadow disc diameter at the feet (a hunter's body is ~0.8 m wide)
const LIFT := 0.04      # m, above the ground so the disc does not z-fight
const ABYSS_DIM := 0.55 # brightness of the abyss clouds relative to normal
const STRENGTH := 0.75  # darkest alpha at the centre of the disc
const SHOT_DISC := 0.9  # m, shadow disc diameter under a shot (they are small, so the disc is too)
const SHOT_STRENGTH := 0.55 # darkest alpha at the centre of a shot's disc (fainter than a hunter's)

const RING: Shader = preload("res://shaders/ring.gdshader")

var _match: Match
var _discs: Dictionary = {}     # Hunter -> MeshInstance3D
var _rings: Dictionary = {}     # Hunter -> MeshInstance3D, made the first time it is airborne
var _ring_mats: Dictionary = {} # "own" | "ally" | "enemy" -> ShaderMaterial
var _fade_from: float
var _fade_len: float
var _ring_rule: Dictionary
var _ring_mesh: QuadMesh
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
	var rules := Content.rules("depth_cues")
	_fade_from = float(rules["shadow"]["fade_from_m"])
	_fade_len = float(rules["shadow"]["gone_at_m"]) - _fade_from
	_ring_rule = rules["ring"]
	_ring_mesh = _disc_mesh(float(_ring_rule["diameter_m"]))
	for who: String in ["own", "ally", "enemy"]:
		var c: Array = _ring_rule[who]
		var mat := ShaderMaterial.new()
		mat.shader = RING
		mat.set_shader_parameter("color", Color(c[0], c[1], c[2], float(_ring_rule["alpha"])).linear_to_srgb())
		mat.set_shader_parameter("thickness", float(_ring_rule["thickness"]))
		_ring_mats[who] = mat

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
## Returns the ground's height there.
func _lay(disc: MeshInstance3D, p: Vector3, shown: bool) -> float:
	var y := _match.world.ground_at(p.x, p.z)
	disc.visible = shown and y > World.VOID + 1.0 and y <= p.y + 0.3
	disc.global_position = Vector3(p.x, y + LIFT, p.z)
	return y

## 1 up to fade_from_m above the ground, 0 at gone_at_m, a straight line between.
func shadow_fade(height: float) -> float:
	return 1.0 - clampf((height - _fade_from) / _fade_len, 0.0, 1.0)

## Is a ring shown for a hunter this high above the ground?
func ring_shown(height: float) -> bool:
	return height >= float(_ring_rule["min_m"]) and height <= float(_ring_rule["max_m"])

## Whose ring colour a hunter wears: you, a teammate or an enemy.
func ring_kind(h: Hunter) -> String:
	if h == _match.player:
		return "own"
	return "ally" if h.team == _match.player.team else "enemy"

## The ring under an airborne hunter on the ground at height `y` (made on first use, hidden otherwise).
func _lay_ring(h: Hunter, p: Vector3, y: float, shown: bool) -> void:
	var ring: MeshInstance3D = _rings.get(h)
	var up := shown and ring_shown(p.y - y)
	if ring == null:
		if not up:
			return
		ring = _new_disc(_ring_mesh, _ring_mats[ring_kind(h)])
		_rings[h] = ring
	ring.visible = up
	ring.global_position = Vector3(p.x, y + LIFT, p.z)

func _process(_dt: float) -> void:
	for h: Hunter in _match.hunters:
		var disc: MeshInstance3D = _discs.get(h)
		if disc == null:
			disc = _new_disc(_mesh, _mat)
			_discs[h] = disc
		var p := h.global_position
		var shown := h.visible and not h.out
		var y := _lay(disc, p, shown)
		var fade := shadow_fade(p.y - y)
		disc.set_instance_shader_parameter("fade", fade)
		disc.visible = disc.visible and fade > 0.0
		_lay_ring(h, p, y, shown and y > World.VOID + 1.0)
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
