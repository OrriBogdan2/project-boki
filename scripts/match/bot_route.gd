class_name BotRoute
extends RefCounted
## How a bot gets somewhere its legs alone won't take it quickly (docs/AIR_RINGS.md, "Bots"):
## - to another island: the quickest chain of jump pads, glides, ringed lanes, wind roads and bridges, by
##   travel time (a ringed lane flies at the ring speed), not by the number of hops;
## - up to high ground on its own island: a lift ring, when the walk round by the stairs is much longer
##   or there is no walk at all.

const WALK_MS := 5.0        # m/s: a run on foot (and over a bridge)
const PAD_MS := 10.0        # m/s: a jump pad's arc from take-off to landing [est]
const WIND_MS := 14.0       # m/s: what a wind road carries you at (Hunter's wind push)
const HOP_S := 2.0          # s: run-up, jump and landing on every hop, so a tie goes to fewer hops
const LIFT_RISE := 2.5      # m: only a goal this far above the bot is worth a lift ring
const LIFT_UP_S := 4.5      # s: hop in to standing on top (--air-rings-check measures about 4.5)
const LIFT_GAIN := 0.7      # a lift is taken when its way takes under this share of the walk's time
const LIFT_S := 7.0         # s: a lift not over by now failed
const LIFT_BAN_S := 20.0    # s: a lift that failed is skipped this long

## The first pad or link on the quickest way from island `here` to island `there`, or {} if none.
## A pad has "pos"; a link has "take" (cross it the way Bot's crossing logic does). Planned once per
## trip (from where the bot stood): re-planning as it walked swapped hops under it and it turned back.
static func next_hop(m: Match, h: Hunter, here: int, there: int) -> Dictionary:
	var rt: Dictionary = h.ai.get("route", {})
	if int(rt.get("here", -1)) == here and int(rt.get("there", -1)) == there:
		return rt["hop"]
	var hop := plan(m.world, h.pos, here, there)
	h.ai["route"] = {"here": here, "there": there, "hop": hop}
	return hop

## Dijkstra over the island graph: each island is reached at the landing of the hop into it, and a hop
## costs the run to its take-off plus its flight. Returns the first hop of the quickest way.
static func plan(w: World, from: Vector3, here: int, there: int) -> Dictionary:
	var best := {here: 0.0}
	var at := {here: from}
	var first := {here: {}}
	var done := {}
	while true:
		var cur := -1
		for k in best:
			if not done.has(k) and (cur < 0 or float(best[k]) < float(best[cur])):
				cur = k
		if cur < 0 or cur == there:
			break
		done[cur] = true
		for hops in [w.pads, w.links]:
			for hp in hops:
				var to := int(hp["to"])
				if int(hp["from"]) != cur or done.has(to):
					continue
				var t := float(best[cur]) + _flat(at[cur], take_of(hp)) / WALK_MS + hop_s(hp)
				if t < float(best.get(to, INF)):
					best[to] = t
					at[to] = hp["land"]
					first[to] = hp if cur == here else first[cur]
	return first.get(there, {})

static func take_of(hp: Dictionary) -> Vector3:
	return hp["pos"] if hp.has("pos") else hp["take"]

## Seconds a hop takes from its take-off to its landing.
static func hop_s(hp: Dictionary) -> float:
	var speed := WALK_MS
	if hp.has("pos"):
		speed = PAD_MS
	elif hp.get("rings", false):
		speed = AirRings.r("speed")
	elif hp.get("wind", false):
		speed = WIND_MS
	elif hp.get("glide", false):
		speed = Hunter.GLIDE_SPEED
	return _flat(take_of(hp), hp["land"]) / speed + HOP_S

## Where to walk to ride a lift ring up to `goal` (the ring's foot), or INF to walk there as usual.
## `walk_m` gives the metres of the walk to the goal (0 when there is no walk); it runs only when a
## ring could serve. Chosen once per goal (like a hop); keeps the ring in h.ai["lift"] for fly_lift.
static func lift_aim(m: Match, h: Hunter, goal: Vector3, walk_m: Callable) -> Vector3:
	var L: Dictionary = h.ai.get("lift", {})
	if L.get("go", false):
		return L["ring"]["pos"]
	var gt := Vector2i(floori(goal.x), floori(goal.z))
	var choice: Dictionary = h.ai.get("lift_plan", {})
	if choice.get("goal") != gt:
		choice = {"goal": gt, "ring": _lift_for(m, h, goal, walk_m)}
		h.ai["lift_plan"] = choice
	var rg: Dictionary = choice["ring"]
	if rg.is_empty():
		h.ai.erase("lift")
		return Vector3.INF
	if not is_same(L.get("ring"), rg):
		h.ai["lift"] = {"ring": rg}
	return rg["pos"]

static func _lift_for(m: Match, h: Hunter, goal: Vector3, walk_m: Callable) -> Dictionary:
	if m.air_rings == null or goal.y < h.pos.y + LIFT_RISE:
		return {}
	var here := m.world.island_of(h.pos.x, h.pos.z)
	var bans: Dictionary = h.ai.get("lift_ban", {})
	var best := {}
	var best_s := INF
	for rg in m.air_rings.list:
		var foot: Vector3 = rg["pos"]
		if not rg["lift"] or rg["onto"] == Vector3.INF or float(rg["top"]) < goal.y - 0.5 \
				or m.world.island_of(foot.x, foot.z) != here or float(bans.get(foot, -1.0)) > m.time:
			continue
		var s := (_flat(h.pos, foot) + _flat(rg["onto"], goal)) / WALK_MS + LIFT_UP_S
		if s < best_s:
			best = rg
			best_s = s
	if best.is_empty():
		return best
	var walk: float = walk_m.call()
	return best if walk <= 0.0 or best_s < walk / WALK_MS * LIFT_GAIN else {}

## Riding the lift ring lift_aim chose: at its foot hop in, keep the glider open and hold still on the
## way up until over the top, then steer onto it. True while it holds the bot's keys this step.
static func fly_lift(m: Match, h: Hunter, inp: Dictionary) -> bool:
	var L: Dictionary = h.ai.get("lift", {})
	if L.is_empty():
		return false
	var rg: Dictionary = L["ring"]
	var foot: Vector3 = rg["pos"]
	if not L.get("go", false):
		if not h.grounded or _flat(h.pos, foot) > 0.8:
			return false
		L["go"] = true
		L["t"] = m.time
		inp["move"] = Vector2.ZERO
		inp["jump"] = true
		return true
	var up_s := m.time - float(L["t"])
	if (h.grounded and up_s > 0.3) or up_s > LIFT_S:
		if not h.grounded or h.pos.y < float(rg["top"]) - 0.3:
			var bans: Dictionary = h.ai.get("lift_ban", {})
			bans[foot] = m.time + LIFT_BAN_S
			h.ai["lift_ban"] = bans
		h.ai.erase("lift")
		h.ai.erase("lift_plan")
		return false
	var onto: Vector3 = rg["onto"]
	var high := h.pos.y > float(rg["top"]) + 0.4
	inp["jump"] = false
	inp["glide"] = not h.grounded
	inp["move"] = Vector2(onto.x - h.pos.x, onto.z - h.pos.z).normalized() if high else Vector2.ZERO
	inp["aim"] = Vector3(onto.x, h.pos.y + 0.9, onto.z)
	inp["aim_y"] = h.pos.y
	return true

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()
