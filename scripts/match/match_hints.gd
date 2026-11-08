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

func _init(match_node: Match) -> void:
	m = match_node

func tick(dt: float) -> void:
	var p: Hunter = m.player
	if m.hud == null or p == null or p.out or p.extracted or p.dropping or p.downed:
		return
	var r := FirstTimeHint.rules()
	var over_void: bool = not p.grounded and not p.gliding and m.world.is_void(p.pos.x, p.pos.z)
	_void_t = _void_t + dt if over_void else 0.0
	_poll_t -= dt
	if _poll_t > 0.0:
		return
	_poll_t = float(r["poll_s"])
	for id in FirstTimeHint.ids("match"):
		if FirstTimeHint.seen(id) or (m.tut != null and id in REAL_ONLY):
			continue
		if _due(String(id), p, r):
			FirstTimeHint.show(id, func(line): m.hud.toast(line, COL))
			return      # one at a time

func _due(id: String, p: Hunter, r: Dictionary) -> bool:
	match id:
		"exdash": return _void_t >= float(r["void_s"])
		"crouch": return m.time >= float(r["crouch_s"]) and p.grounded and not p.crouch
		"pickup": return m.wpicks.any(func(wp): return p.pos.distance_to(wp["pos"]) < float(r["near_m"]))
		"orders": return p.kin != null and p.kin.state == "active" and KinCommand.is_away(p, p.kin)
		"rank": return p.ak != null and p.level_ups > 0 and p.skill_pts > 0
		"utility":
			var has := p.ak != null or (p.runner != null and p.runner.has_slot("utility"))
			return has and int(p.used.get("utility", 0)) == 0 and _foe_near(p, float(r["near_m"]) * 1.5)
		"key": return p.chest_keys > 0
		"uplink": return _outpost(p, "idle", float(r["outpost_m"]))
		"defend": return _outpost(p, "charging", float(r["outpost_m"]))
		"goexit": return m.time >= float(r["goexit_s"])
	return false

func _foe_near(p: Hunter, dist: float) -> bool:
	return m.mobs.any(func(mb): return not mb.dead and p.flat_dist(mb) < dist)

func _outpost(p: Hunter, state: String, dist: float) -> bool:
	if m.exits == null:
		return false
	for x in m.exits.of_kind("outpost"):
		if x["state"] == state and p.flat_dist(x["pos"]) < dist:
			return state != "charging" or int(x["team"]) == p.team
	return false
