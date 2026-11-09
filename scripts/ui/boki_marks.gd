class_name BokiMarks
extends RefCounted
## Who a Boki belongs to and what it is doing, in a busy fight, in the one colour rule (SideColor):
##   - your own Boki, whenever it is out, has a thin tether to you (its ring is in your colour, SideRings)
##   - a teammate's Boki, while that teammate is down, has a tether to them and a small icon over it:
##     defending them, pulling them up, hanging back hurt, or down itself
## Enemies' Boki get neither: their rings already say whose they are.

const TETHER_W := 2.0          # px
const TETHER_A := 0.55         # alpha of a tether
const DASH_PX := 10.0          # px: tether dash length (dashes read as "belongs to", not as a beam)
const ICON_UP := 1.5           # m over the Boki's feet
const ICON_S := 7.0            # Icons size (half width, px)
const NEAR := 1.6              # m: closer than this to its Hunter, no tether (it is plainly theirs)
const DEFEND_R := 3.0          # m: a foe this close to the downed Hunter is what the Boki is defending against

## Draws every tether and status icon on the HUD canvas.
static func draw(c: Control, m: Match) -> void:
	for k in m.kins:
		if not tethers(m, k) or not k.visible:
			continue
		var h: Hunter = k.owner_h
		var col := SideColor.of(m, h)
		if k.flat_dist(h) > NEAR:
			_tether(c, m.cam, h.position, k.position, col)
		if h.downed and h != m.player:
			_status(c, m, k, col)

## Whether `k` gets a tether to its Hunter: your own Boki while it is out, a teammate's while they are down.
static func tethers(m: Match, k: Kin) -> bool:
	var p: Hunter = m.player
	var h: Hunter = k.owner_h
	if p == null or h == null or k.dead or h.out or h.team != p.team:
		return false
	if h != p and not h.downed:
		return false
	return not (k.state in ["shoulder", "fused", "bench", "away"])

## What a teammate's Boki is doing while its Hunter is down: an Icons id ("" when nothing to show).
static func status(k: Kin) -> String:
	if k.state == "downed":
		return "knock"
	if k.state == "reviving":
		return "heart"
	if k.target != null and is_instance_valid(k.target) and k.target is Hunter and k.owner_h != null \
			and (k.target as Hunter).flat_dist(k.owner_h) < DEFEND_R:
		return "fortify"
	if k.hp < k.max_hp * k.brain.retreat_frac():
		return "dash"
	return ""

static func _tether(c: Control, cam: Camera3D, from: Vector3, to: Vector3, col: Color) -> void:
	var a3 := from + Vector3(0, 0.15, 0)
	var b3 := to + Vector3(0, 0.15, 0)
	if cam.is_position_behind(a3) or cam.is_position_behind(b3):
		return
	c.draw_dashed_line(cam.unproject_position(a3), cam.unproject_position(b3), Color(col, TETHER_A), TETHER_W,
		DASH_PX, true, true)

static func _status(c: Control, m: Match, k: Kin, col: Color) -> void:
	var id := status(k)
	var at3 := k.position + Vector3(0, ICON_UP, 0)
	if id == "" or m.cam.is_position_behind(at3):
		return
	var at := m.cam.unproject_position(at3)
	c.draw_circle(at, ICON_S + 5.0, Color(0.03, 0.04, 0.07, 0.8))
	c.draw_arc(at, ICON_S + 5.0, 0.0, TAU, 24, col, 2.0, true)
	Icons.draw(c, id, at, ICON_S, col.lerp(Color.WHITE, 0.35))
