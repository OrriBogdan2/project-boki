class_name FxHunterCap
extends Node
## Glow-sphere effects near a Hunter (docs/COMBAT_CLARITY.md "What sits on a Hunter"): a shot's glow, a Boki's
## ability orb or an aura, drawn with shaders/glowball.gdshader, never bury a body. Within NEAR_R of a Hunter such
## a node is shrunk to at most MAX_SIZE across and drawn at NEAR_ALPHA; the node's own scale and look come back
## the frame it leaves. Purely visual: hit shapes and the effects' own logic never see it. A Hunter's own parts
## (its merge form, its pins) are not capped.

const MAX_SIZE := 0.9      # m, widest a glow may be (axis-aligned, world) while within NEAR_R of a Hunter
const NEAR_R := 2.2        # m, ground distance from a Hunter's feet that counts as near
const NEAR_ALPHA := 0.45   # share of its alpha a capped glow keeps
const RESCAN_S := 0.5      # s between searches for new glow nodes (the match builds them anywhere)
const PARAM := &"near_a"   # instance uniform in glowball.gdshader
const META := &"fhc_scale"  # a capped node's own scale, kept to put back
const META_CAPPED := &"fhc_capped"  # the scale the cap gave it

var _match: Match
var _glows: Array[MeshInstance3D] = []
var _scan_in := 0.0


func _init(m: Match) -> void:
	_match = m
	name = "FxHunterCap"


func _process(dt: float) -> void:
	_scan_in -= dt
	if _scan_in <= 0.0:
		_scan_in = RESCAN_S
		_rescan()
	var near: Array[Vector3] = []
	for h: Hunter in _match.hunters:
		if not h.out:
			near.append(h.pos)
	for mi in _glows:
		if is_instance_valid(mi) and mi.is_visible_in_tree():
			_apply(mi, near)


func _rescan() -> void:
	_glows.clear()
	for n in _match.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mat := mi.material_override as ShaderMaterial
		if mat != null and mat.shader == Models.GLOW and not _in_hunter(mi):
			_glows.append(mi)


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
		if Vector2(c.x - p.x, c.z - p.z).length() < NEAR_R and absf(c.y - p.y) < NEAR_R:
			close = true
			break
	if close:
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
	mi.set_instance_shader_parameter(PARAM, NEAR_ALPHA if close else 1.0)
