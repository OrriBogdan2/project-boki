class_name SideRings
extends RefCounted
## The rings under every Hunter and their Boki follow the one colour rule (SideColor): you, your squad,
## everyone else. A Boki's ring takes its Hunter's colour, so a squad's Boki read as theirs in a crowd.
## The material only changes when the colour does (a new viewer, a team change), never per frame.

const YOU_A := 0.95        # alpha of your own ring: the brightest thing under any body
const OTHER_A := 0.75      # alpha of everyone else's
const BOKI_A := 0.85       # alpha of a Boki's ring

## Every frame, on every Hunter: their ground ring and their Boki's in the right side colour.
static func tick(h: Hunter) -> void:
	if h.model == null or h.m == null:
		return
	var col := SideColor.of(h.m, h)
	var you: bool = h.m.get("player") == h
	_paint(h.model.get_node_or_null("TeamRing") as MeshInstance3D, Color(col, YOU_A if you else OTHER_A))
	for k in [h.kin, h.kin2]:
		if k != null and is_instance_valid(k):
			_paint((k as Kin).ring, Color(col, BOKI_A))

## The colour a ring shows now (black when it has none), for checks.
static func shown(ring: MeshInstance3D) -> Color:
	return ring.get_meta("side_col", Color.BLACK) if ring else Color.BLACK

static func _paint(ring: MeshInstance3D, col: Color) -> void:
	if ring == null or ring.get_meta("side_col", Color.BLACK) == col:
		return
	var mat := ring.material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("color", col)
	ring.set_meta("side_col", col)
