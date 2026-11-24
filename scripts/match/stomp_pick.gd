class_name StompPick
extends RefCounted
## Which downed enemy a Hunter can stomp right now, and the one prompt for it (match.gd _update_interact).
## Only the closest enemy Wisp inside stomp reach (Life.R revive_radius, the same height gate as Life.tick_stomp),
## so a pile of downed foes asks for one stomp, not the last one in the list. A teammate's Wisp never asks: you
## revive it by standing on it (Life). The prompt is the match prompt bar's HoldPrompt ring; no world text on
## the Wisp (DECISIONS 2026-11-11). docs/COMBAT_CLARITY.md.


## The closest downed enemy `h` can stomp, or null.
static func target(m: Match, h: Hunter) -> Hunter:
	var best: Hunter = null
	var best_d := INF
	var reach: float = Life.R["revive_radius"]
	for o: Hunter in m.hunters:
		if o == h or not o.downed or o.out or o.remote or o.team == h.team:
			continue
		var d := h.flat_dist(o)
		if d > reach or absf(h.pos.y - o.pos.y) >= 1.6 or d >= best_d:
			continue
		best = o
		best_d = d
	return best


## `best` (the prompt so far), or the stomp prompt when an enemy Wisp is in reach.
static func prompt(m: Match, h: Hunter, best: Dictionary) -> Dictionary:
	var o := target(m, h)
	if o == null:
		return best
	var label := "Hold %s to stomp" % Settings.key_cap("interact")
	return {"kind": "finish", "ent": o, "label": label, "col": Color("ff8a6a")}
