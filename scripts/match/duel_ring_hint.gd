class_name DuelRingHint
extends RefCounted
## The first walk into the Training Grounds duel ring area: one hint naming the pad key and what it
## leads to, and a tall beam over the pad until you stand on it, so there is always a next step. Once per save.

const SAVE_KEY := "duel_ring"
const NEAR_M := 8.0           # m from the pad that counts as walking into the ring area
const STAND_M := 1.3          # m from the pad centre where interact opens the ring (Match._update_training)
const BEAM_H := 60.0          # m tall: seen from across the island
const BEAM_COL := Color("ffb0a0", 0.32)   # the pad label's colour

var m: Match
var beam: MeshInstance3D = null

## The hint for this match, or null once this save has had it.
static func make(match_node: Match) -> DuelRingHint:
	if Save.d["tutorial"].get(SAVE_KEY, false):
		return null
	var hint := DuelRingHint.new()
	hint.m = match_node
	return hint

## What the hint says: the pad key, then what the pad opens (the duel room's sparring bot; no online queue here).
static func line() -> String:
	return "Duel ring: stand on the pad and press %s to Fight a bot in the duel room." % Settings.key_cap("interact")

## Per frame while the hint is live. Returns false once it is finished (the player reached the pad).
func tick() -> bool:
	if beam == null:
		if m.player.flat_dist(m.duel_pad) > NEAR_M:
			return true
		Save.d["tutorial"][SAVE_KEY] = true
		if m.hud:
			m.hud.tip(line())
		beam = _make_beam()
	if m.player.flat_dist(m.duel_pad) < STAND_M:        # on the pad: its label says to press the key
		beam.queue_free()
		return false
	beam.position = m.duel_pad + Vector3(0, BEAM_H * 0.5, 0)
	return true

func _make_beam() -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 0.9
	cyl.height = BEAM_H
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = BEAM_COL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = mat
	n.mesh = cyl
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(n)
	return n
