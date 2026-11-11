class_name SideRings
extends RefCounted
## The rings under every Hunter and their Boki follow the one colour rule (SideColor): you, your squad,
## everyone else. A Boki's ring takes its Hunter's colour, so a squad's Boki read as theirs in a crowd.
## Other Hunters' bodies take the same colour as a thin edge on their silhouette (hero_toon side_rim), so
## who's who reads off the body in a crowd, not only off the ring under it.
## The materials only change when the colour does (a new viewer, a team change, a new model), never per frame.

const YOU_A := 0.95        # alpha of your own ring: the brightest thing under any body
const OTHER_A := 0.75      # alpha of everyone else's
const BOKI_A := 0.85       # alpha of a Boki's ring
const EDGE_A := 0.9        # strength of the side edge on other Hunters' bodies (none on yours)

## Every frame, on every Hunter: their ground ring and their Boki's in the right side colour.
static func tick(h: Hunter) -> void:
	if h.model == null or h.m == null:
		return
	var col := SideColor.of(h.m, h)
	var you: bool = h.m.get("player") == h
	_paint(h.model.get_node_or_null("TeamRing") as MeshInstance3D, Color(col, YOU_A if you else OTHER_A))
	_edge(h, Color(col, 0.0 if you else EDGE_A))
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

## The side edge a body shows now (transparent when none), for checks.
static func edge_of(h: Hunter) -> Color:
	return h.model.get_meta("side_rim", Color.TRANSPARENT) if h.model else Color.TRANSPARENT

static func _edge(h: Hunter, col: Color) -> void:
	if h.model.get_meta("side_rim", Color.TRANSPARENT) == col and h.model.get_meta("side_rim_n", -1) == h.mats.size():
		return
	for mt in h.mats:
		mt.set_shader_parameter("side_rim", col)
	h.model.set_meta("side_rim", col)
	h.model.set_meta("side_rim_n", h.mats.size())
