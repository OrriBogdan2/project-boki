class_name SideRings
extends RefCounted
## The rings under every Hunter and their Boki follow the one colour rule (SideColor): you, your squad,
## everyone else. A Boki's ring takes the colour of whoever it rides with now (a stolen one: its thief), and
## its glow shell takes it too, so a summoned Boki reads as yours, an ally's or a rival's, never as a wild one.
## The material only changes when the colour does (a new viewer, a team change), never per frame.

const YOU_A := 0.95        # alpha of your own ring: the brightest thing under any body
const OTHER_A := 0.75      # alpha of everyone else's
const BOKI_A := 0.85       # alpha of a Boki's ring

## Every frame, on every Hunter: their ground ring in the right side colour.
static func tick(h: Hunter) -> void:
	if h.model == null or h.m == null:
		return
	var col := SideColor.of(h.m, h)
	var you: bool = h.m.get("player") == h
	_paint(h.model.get_node_or_null("TeamRing") as MeshInstance3D, Color(col, YOU_A if you else OTHER_A))

## Every frame, on every Boki that rides with a Hunter: its ring and its glow shell in that Hunter's side colour.
static func kin(k: Kin) -> void:
	if k.owner_h == null or k.m == null:
		return
	var col := SideColor.of(k.m, k)
	_paint(k.ring, Color(col, BOKI_A))
	var shell := k.model.get_node_or_null("Body/Shell") as MeshInstance3D if k.model else null
	if shell and shell.get_meta("side_col", Color.BLACK) != col:
		(shell.material_override as ShaderMaterial).set_shader_parameter("color", col)
		shell.set_meta("side_col", col)

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
