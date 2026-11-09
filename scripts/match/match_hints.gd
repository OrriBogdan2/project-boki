class_name MatchHints
extends RefCounted
## The match's one-time hints (FirstTimeHint, content/rules/hints.json "match"): the moves and rules the
## tutorial no longer stops for, each told in one toast the first time it matters (in the air over the
## void, a skill point, a chest key in hand, an idle outpost close by...). Match owns one and ticks it.

const COL := Color("8fe3c7")
## Hints the tutorial match leaves for a real one (its outpost opens by itself and the course is short).
const REAL_ONLY := ["crouch", "uplink", "defend", "goexit"]

var m: Match
var _poll_t := 0.0
var _void_t := 0.0
var _fight_t := -1.0      # s since a foe came close (-1: none close)
var _last := ""           # the line of the hint shown last, while it may still be on screen

func _init(match_node: Match) -> void:
	m = match_node

func tick(dt: float) -> void:
	var p: Hunter = m.player
	if m.hud == null or p == null or p.out or p.extracted or p.dropping or p.downed:
		return
	var r := FirstTimeHint.rules()
	var over_void: bool = not p.grounded and not p.gliding and m.world.is_void(p.pos.x, p.pos.z)
	_void_t = _void_t + dt if over_void else 0.0
	if not _fight_on(p, float(r["near_m"]) * 1.5):
		_fight_t = -1.0
	else:
		_fight_t = maxf(_fight_t + dt, 0.0)
	_poll_t -= dt
	if _poll_t > 0.0:
		return
	_poll_t = float(r["poll_s"])
	if _hint_up() or (_fight_t >= 0.0 and _fight_t < float(r["fight_quiet_s"])):
		return      # one line on screen at a time, and none in the first seconds of a fight
	for id in FirstTimeHint.ids("match"):
		if FirstTimeHint.seen(id) or (m.tut != null and id in REAL_ONLY):
			continue
		if _due(String(id), p, r):
			FirstTimeHint.show(id, _say)
			return      # one at a time

func _say(line: String) -> void:
	_last = line
	m.hud.toast(line, COL)

func _due(id: String, p: Hunter, r: Dictionary) -> bool:
	match id:
		"exdash": return _void_t >= float(r["void_s"])
		"crouch": return m.time >= float(r["crouch_s"]) and p.grounded and not p.crouch
		"pickup": return m.wpicks.any(func(wp): return p.pos.distance_to(wp["pos"]) < float(r["near_m"]))
		"orders": return p.kin != null and p.kin.state == "active" and KinCommand.is_away(p, p.kin)
		"rank": return p.ak != null and p.level_ups > 0 and p.skill_pts > 0
		"utility":
			var has := p.ak != null or (p.runner != null and p.runner.has_slot("utility"))
			return has and int(p.used.get("utility", 0)) == 0 and _fight_t >= 0.0
		"key": return p.chest_keys > 0
		"uplink": return _outpost(p, "idle", float(r["outpost_m"]))
		"defend": return _outpost(p, "charging", float(r["outpost_m"]))
		"goexit": return m.time >= float(r["goexit_s"]) and not _outpost(p, "", float(r["sight_m"]))
	return false

## The last hint is still on the lane, or something waits behind it (a hint never stacks on another).
func _hint_up() -> bool:
	if _last == "":
		return false
	_last = _last if m.hud.msgs.waiting() > 0 or m.hud.msgs.texts().any(func(t): return t.contains(_last)) else ""
	return _last != ""

## A foe is close or has picked you out.
func _fight_on(p: Hunter, dist: float) -> bool:
	return m.mobs.any(func(mb): return not mb.dead and (p.flat_dist(mb) < dist or mb.tgt == p))

## An outpost of the given state is within `dist` ("" = any); an idle one counts once it can be started,
## a charging one only if it is yours.
func _outpost(p: Hunter, state: String, dist: float) -> bool:
	if m.exits == null:
		return false
	for x in m.exits.of_kind("outpost"):
		if p.flat_dist(x["pos"]) >= dist or (state != "" and x["state"] != state):
			continue
		if state == "idle" and not m.exits.startable(x):
			continue
		if state != "charging" or int(x["team"]) == p.team:
			return true
	return false
