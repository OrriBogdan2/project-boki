class_name BotCamps
extends RefCounted
## Bots level on camps (docs/CAMPS.md): a bot with nothing else to do walks to the nearest standing
## camp it is strong enough for (Camps.want_level: Small Camps at level 1, Camps at 2, Great Camps
## at 4), so a bot grows through the same camps a player does and takes the big ones later.


## Where the bot should farm next, or Vector3.INF when no standing camp suits its level.
static func goal(m: Match, h: Hunter) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for cp in m.camps.live():
		if m.camps.want_level(cp) > h.lvl:
			continue
		var d := h.flat_dist(cp["pos"])
		if d < best_d:
			best_d = d
			best = cp["pos"]
	return best
