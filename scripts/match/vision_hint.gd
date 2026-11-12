class_name VisionHint
extends RefCounted
## The first-time line about the sight wedge (docs/specs/VISION_LOOK.md): the screen outside your sight goes dim
## and blue, which can look broken. The first time a rival is hidden only because it stands outside the wedge, or
## the player swings the aim fast enough that the dim area sweeps across the screen, Match._tips says it once
## per save (Save.d["tutorial"][KEY]), in the usual hint lane, and never with tips off or in the tutorial course.

const KEY := "vision"
const TEXT := "You only see enemies in front of you and near you"
const AFTER_S := 7.0       # s of the match before it can show: after the first move hint has gone
const TURN_DEG := 120.0    # degrees the aim swings within TURN_S: the dim area visibly sweeps across the screen
const TURN_S := 0.6        # s

var _from := Vector2.ZERO  # the aim at the start of the current turn window
var _from_t := 0.0         # match time that window started

## True when the hint should show this frame.
func due(m: Match) -> bool:
	var p := m.player
	return _turned(p.aim_dir(), m.time) or hidden_rival(m)

func _turned(aim: Vector2, now: float) -> bool:
	if _from == Vector2.ZERO or now - _from_t > TURN_S:
		_from = aim
		_from_t = now
		return false
	return absf(_from.angle_to(aim)) > deg_to_rad(TURN_DEG)

## A rival the player would see if they faced it: in range, clear line, not in grass or smoke, but outside the wedge.
static func hidden_rival(m: Match) -> bool:
	var p := m.player
	var aim := p.aim_dir()
	for h: Hunter in m.hunters:
		if h.team == p.team or not h.unseen or h.out or h.downed:
			continue
		var rel := Vector2(h.pos.x - p.pos.x, h.pos.z - p.pos.z)
		if rel.length() > m.view_range(h.crouch) or rel.normalized().dot(aim) >= Match.VIEW_COS:
			continue
		if m.world.in_bush(h.pos.x, h.pos.z) or m.in_smoke(h.pos):
			continue
		if m.world.los(p.pos, h.pos, p.pos.y + 1.1):
			return true
	return false
