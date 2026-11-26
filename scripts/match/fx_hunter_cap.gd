class_name FxHunterCap
extends Node
## Glow-sphere effects near a Hunter (docs/COMBAT_CLARITY.md "What sits on a Hunter"): a shot's glow, a Boki's
## ability orb or an aura, drawn with shaders/glowball.gdshader, never bury a body. Within NEAR_R of a Hunter such
## a node is shrunk to at most MAX_SIZE across and drawn at NEAR_ALPHA; the node's own scale and look come back
## the frame it leaves. A smoke cloud's puffs (Models.gear_smoke: opaque grey spheres up to 2.6 m across) part
## round a Hunter instead: a puff within PUFF_CLEAR of a body, or over its box on screen, is hidden until it is
## clear. Purely visual: hit shapes, the effects' own logic and smoke's concealment (Match.in_smoke) never see it.
## Only Hunters the player is shown count (a hidden foe in smoke opens no hole). A Hunter's own parts (its merge
## form, its pins) are not capped.

const MAX_SIZE := 0.9  # m, widest a glow may be (axis-aligned, world) while within NEAR_R of a Hunter
const NEAR_R := 2.2  # m, ground distance from a Hunter's feet that counts as near
const NEAR_ALPHA := 0.45  # share of its alpha a capped glow keeps
const PUFF_CLEAR := 1.1  # m of ground between a smoke puff's edge and a Hunter's feet that it keeps
const RESCAN_S := 0.5  # s between looks at the mesh nodes that entered the match (it builds glows anywhere)
const PARAM := &"near_a"  # instance uniform in glowball.gdshader
const META := &"fhc_scale"  # a capped node's own scale, kept to put back
const META_CAPPED := &"fhc_capped"  # the scale the cap gave it
const META_ALPHA := &"fhc_alpha"  # the alpha last sent to the shader (an unchanged one is not sent again)

var _match: Match
var _glows: Array[MeshInstance3D] = []
var _fresh: Array = []  # mesh nodes that entered the match since the last look
var _scan_in := 0.0
var _held := {}  # instance id -> true: the glows now capped or dimmed (any other far one needs nothing)


func _init(m: Match) -> void:
	_match = m
	name = "FxHunterCap"


func _ready() -> void:
	_fresh = _match.find_children("*", "MeshInstance3D", true, false)
	get_tree().node_added.connect(_on_node_added)


func _process(dt: float) -> void:
	_scan_in -= dt
	if _scan_in <= 0.0:
		_scan_in = RESCAN_S
		_rescan()
	var near: Array[Vector3] = []
	var zones: Array[Rect2] = []  # the shown Hunters' screen boxes (HunterZone), for the smoke puffs
	for h: Hunter in _match.hunters:
		if not h.out and not h.unseen:
			near.append(h.pos)
			var z := HunterZone.rect_of(_match, h)
			if z.has_area():
				zones.append(z)
	for mi in _glows:
		if is_instance_valid(mi) and mi.is_visible_in_tree():
			_apply(mi, near)
	for sm: Dictionary in _match.smokes:
		var n := sm["node"] as Node3D
		if is_instance_valid(n):
			for puff in n.get_children():
				if puff is MeshInstance3D:
					_part(puff, near, zones)


## A smoke puff hides while a Hunter stands within its radius plus PUFF_CLEAR (ground distance), or while its disc
## on screen covers a Hunter's screen box (`zones`): the camera looks down at a slant, so a puff on its side of a
## Hunter hides the body from metres away on the ground.
func _part(puff: MeshInstance3D, near: Array[Vector3], zones: Array[Rect2]) -> void:
	var rad := puff.get_aabb().size.x * 0.5 * puff.global_transform.basis.get_scale().x
	var r := rad + PUFF_CLEAR
	var c := puff.global_position
	var open := false
	for p in near:
		if Vector2(c.x - p.x, c.z - p.z).length() < r:
			open = true
			break
	var cam := _match.cam
	if not open and not zones.is_empty() and cam and not cam.is_position_behind(c):
		var sc := cam.unproject_position(c)
		var sr := sc.distance_to(cam.unproject_position(c + cam.global_basis.x * rad))
		var disc := Rect2(sc - Vector2(sr, sr), Vector2(sr, sr) * 2.0)
		open = zones.any(func(z: Rect2) -> bool: return z.intersects(disc))
	puff.visible = not open


func _on_node_added(n: Node) -> void:
	if n is MeshInstance3D and _match.is_ancestor_of(n):
		_fresh.append(n)


## Adds the glows among the mesh nodes that entered since the last look; drops the freed ones.
func _rescan() -> void:
	for i in range(_glows.size() - 1, -1, -1):
		if not is_instance_valid(_glows[i]):
			_glows.remove_at(i)
	for id: int in _held.keys():
		if not is_instance_id_valid(id):
			_held.erase(id)
	for n in _fresh:
		if not is_instance_valid(n) or not n.is_inside_tree() or _glows.has(n):
			continue
		var mi := n as MeshInstance3D
		var mat := mi.material_override as ShaderMaterial
		if mat != null and mat.shader == Models.GLOW and not _in_hunter(mi):
			_glows.append(mi)
	_fresh.clear()


func _in_hunter(n: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != _match:
		if p is Hunter:
			return true
		p = p.get_parent()
	return false


func _apply(mi: MeshInstance3D, near: Array[Vector3]) -> void:
	var c := mi.global_position
	var close := false
	for p in near:
		var dx := c.x - p.x
		var dz := c.z - p.z
		if dx * dx + dz * dz < NEAR_R * NEAR_R and absf(c.y - p.y) < NEAR_R:
			close = true
			break
	var id := mi.get_instance_id()
	if not close and not _held.has(id):
		return  # (as it was left: full size, full alpha)
	if close:
		_held[id] = true
		var sz := (mi.global_transform * mi.get_aabb()).size
		var wide := maxf(sz.x, maxf(sz.y, sz.z))
		if wide > MAX_SIZE:
			if not mi.has_meta(META):
				mi.set_meta(META, mi.scale)
			mi.scale *= MAX_SIZE / wide
			mi.set_meta(META_CAPPED, mi.scale)
	elif mi.has_meta(META):
		if mi.scale.is_equal_approx(mi.get_meta(META_CAPPED)):
			mi.scale = mi.get_meta(META)
		mi.remove_meta(META)
		mi.remove_meta(META_CAPPED)
	var alpha := NEAR_ALPHA if close else 1.0
	if float(mi.get_meta(META_ALPHA, 1.0)) != alpha:
		mi.set_meta(META_ALPHA, alpha)
		mi.set_instance_shader_parameter(PARAM, alpha)
	if not close:
		_held.erase(id)
