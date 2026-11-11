class_name BotRetreat
extends RefCounted
## Backing off from a fight that is going badly, as a good player does instead of trading to the death
## (docs/BOTS_HUMAN_1111.md): low on health against a rival who isn't nearly finished, the bot steps
## away (toward its squad when that is away from the rival), dashes clear, keeps shooting when it has a
## line, and once out of reach drinks (BotBelt). Harder bots notice it more often. A bot that has
## backed off for MAX_T and is still caught turns and fights.

const AT := 0.35                 # health fraction that starts a retreat
const WIN_AT := 0.25             # ...unless the rival is under this: finish them instead
const MAX_T := 5.0               # s a retreat lasts before a cornered bot fights again
const GAP := 8.0                 # s before the same bot weighs backing off again
const RUN := 10.0                # m: how far ahead the spot it backs off to is
const HIT_BACK := 1.5            # s: a rival who hit us this recently gets shot back while we back off

## Where to back off to this step (INF: stand and fight). Rolls once per bad moment, by skill.
static func spot(m: Match, h: Hunter, tgt: Hunter) -> Vector3:
	var a := h.ai
	if on(m, h):
		return _away(m, h, tgt)
	if h.hp >= h.max_hp * AT or tgt.hp < tgt.max_hp * WIN_AT or m.time < float(a.get("rt_next", -1.0)):
		return Vector3.INF
	a["rt_next"] = m.time + MAX_T + GAP
	if randf() > 0.3 + 0.7 * float(a["skill"]):
		return Vector3.INF            # (easier bots often fight on)
	a["rt_until"] = m.time + MAX_T
	a["rt_from"] = tgt
	return _away(m, h, tgt)

## Backing off right now (ends early once topped up, a medkit or tonic on the way).
static func on(m: Match, h: Hunter) -> bool:
	var a := h.ai
	if m.time >= float(a.get("rt_until", -1.0)):
		return false
	if h.hp > h.max_hp * (AT + 0.2):
		a["rt_until"] = -1.0
		return false
	return true

## Out of the rival's reach but still backing off: keep going (and drink, BotBelt) rather than turn
## round into them. INF when not backing off.
static func calm_spot(m: Match, h: Hunter) -> Vector3:
	var f = h.ai.get("rt_from")
	if not on(m, h) or not (f is Hunter) or not is_instance_valid(f):
		return Vector3.INF
	return _away(m, h, f)

## While backing off, only whoever is hitting us right now is worth turning on.
static func skips(m: Match, h: Hunter, o: Hunter) -> bool:
	return on(m, h) and not (h.last_hit_by == o and m.time - h.hurt_at < HIT_BACK)

## A spot RUN metres away from the rival, leaning toward the squad's lead when it lies that way, on
## open ground (turning off the straight line when that is void or rock).
static func _away(m: Match, h: Hunter, tgt: Hunter) -> Vector3:
	var away := -h.dir_to(tgt)
	var l := BotSquad.lead(m, h)
	if l and l != h and h.flat_dist(l) > 3.0 and h.dir_to(l).dot(away) > 0.0:
		away = (away + h.dir_to(l) * 0.7).normalized()
	for k in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
		var d := away.rotated(k)
		var q := h.pos + Vector3(d.x, 0, d.y) * RUN
		if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z):
			return Vector3(q.x, m.world.ground_at(q.x, q.z), q.z)
	return Vector3.INF
