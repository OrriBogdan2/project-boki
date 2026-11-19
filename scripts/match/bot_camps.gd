class_name BotCamps
extends RefCounted
## How bot squads play the early game around camps (spec EARLY_CAMPS_DROP 2.8, 6.8; numbers in the
## "bots" block of content/rules/camps.json). On the drop map a bot leader with no human ping picks a
## camp's region, never one another squad pinged while a free one is left, and the Crown at most
## once. After landing the squad clears its region's camps smallest first until 2:30, then goes
## back to the usual objectives; later a squad whose best Hunter is under level 5 detours to a camp
## within reach. Squads with a person in them follow the person instead.
##
## Public API:
##   BotCamps.pick(m, h, picks) -> Vector3   the camp to ping from the drop map (INF: none free)
##   BotCamps.goal(m, h) -> Array            [position, "camp"] for Bot._choose, or [] for none

static func _rules() -> Dictionary:
	return Camps.rules()["bots"]

# ------------------------------------------------------------------ the drop map
## The ping of a bot leader with no human ping: a camp the ship's run lets it reach, in a region no other
## squad pinged (picks maps team -> region for the bot squads that pinged). With every region taken, one
## other squad may share.
static func pick(m: Match, h: Hunter, picks: Dictionary) -> Vector3:
	if m.camps == null or m.biomes == null:
		return Vector3.INF
	var by_region := {}
	for c in m.camps.list():
		if int(c["region"]) >= 0 and reachable(m, h, c["pos"]):
			if not by_region.has(c["region"]): by_region[c["region"]] = []
			by_region[c["region"]].append(c)
	var crown := _crown_region(m)
	var order: Array = by_region.keys().filter(func(r): return r != crown)
	order.shuffle()
	if by_region.has(crown):
		if randf() < float(_rules()["crown_pick"]): order.push_front(crown)
		else: order.append(crown)
	var squads := _squads_in(m, h, picks)
	for limit in [0, 1]:
		for r in order:
			if squads.get(r, 0) <= limit and not (r == crown and squads.get(r, 0) > 0):
				return _camp_to_ping(by_region[r])["pos"]
	return Vector3.INF

## Squads (other than h's) that pinged each region: bot leaders' picks and people's pings.
## Can a squad jump from its ship and glide down onto `at`? It leaves as the ship passes nearest, but no
## later than the end of the ride, and the glide only goes so far once the launch's dive is over.
static func reachable(m: Match, h: Hunter, at: Vector3) -> bool:
	var s := m.ship_of(h)
	if s.is_empty() or not s.has("a"):
		return true
	var a: Vector3 = s["a"]
	var ab := Vector2(s["b"].x - a.x, s["b"].z - a.z)
	var k := Vector2(at.x - a.x, at.z - a.z).dot(ab) / ab.length_squared()
	k = minf(clampf(k, 0.04, 0.97), float(s["ride"]) / float(s["dur"]))
	var from := a.lerp(s["b"], k)
	var open_y := DropFeel.ship_height - DropFeel.dive_fall * DropFeel.lock_s      # (the locked dive first)
	var glide := open_y / DropFeel.canopy_fall * DropFeel.canopy_speed
	return Vector2(at.x - from.x, at.z - from.z).length() <= glide * float(_rules()["glide_k"])

static func _squads_in(m: Match, h: Hunter, picks: Dictionary) -> Dictionary:
	var teams := {}
	for t in picks:
		if int(t) != h.team: teams[t] = picks[t]
	for p in m.pings:
		var by = p.get("by")
		if by is Hunter and by.ctrl != "bot" and by.team != h.team:
			teams[by.team] = m.biomes.hot.region_at(p["pos"])
	var out := {}
	for t in teams:
		out[teams[t]] = out.get(teams[t], 0) + 1
	return out

static func _crown_region(m: Match) -> int:
	for ii in m.world.islands.size():
		if String(m.world.islands[ii].get("role", "")) == "heart":
			return m.biomes.hot.region_of[ii]
	return -1

static func _size_i(c: Dictionary) -> int:
	var sizes: Array = Camps.rules()["sizes"]
	return sizes.map(func(s): return s["id"]).find(c["size"])

## A rim region (two small camps) and the Crown ping their smallest camp; a mid region (three sizes) its middle one.
static func _camp_to_ping(camps: Array) -> Dictionary:
	var sorted := camps.duplicate()
	sorted.sort_custom(func(a, b): return _size_i(a) < _size_i(b))
	var distinct := {}
	for c in camps: distinct[c["size"]] = true
	return sorted[1] if distinct.size() >= 3 else sorted[0]

# ------------------------------------------------------------------ on the ground
static func goal(m: Match, h: Hunter) -> Array:
	if m.camps == null or m.biomes == null:
		return []
	if m.hunters.any(func(x): return x.team == h.team and x.ctrl != "bot" and not x.out):
		return []        # (a person leads their squad)
	var lead: Hunter = m.hunters.filter(func(x): return x.team == h.team and not x.out and not x.extracted)[0]
	var c := _camp_for(m, lead)
	if c.is_empty():
		return []
	if h != lead and h.flat_dist(lead) > float(_rules()["together_r"]):
		return [lead.pos, "camp"]       # (stay together: XP only reaches a squadmate close to the kill)
	return [c["pos"], "camp"]

## The camp this squad is after: before the cut-off its region's smallest live one (kept until it is
## gone), later the nearest within reach while the squad's best Hunter is under the pace level.
static func _camp_for(m: Match, lead: Hunter) -> Dictionary:
	var R := _rules()
	var C: Camps = m.camps
	if not C.safe_for(lead.pos, float(R["safe_s"])) or _blight_near(m, lead, float(R["blight_r"])):
		return {}
	if m.time >= float(R["stop_s"]):
		var best := 0
		for x in m.hunters:
			if x.team == lead.team and not x.out: best = maxi(best, x.lvl)
		return C.nearest_live(lead.pos, float(R["detour_r"])) if best < int(R["detour_lvl"]) else {}
	var mine := _total_level(m, lead.team)
	var live := C.camps.filter(func(c): return c["state"] in [Camps.State.LIVE, Camps.State.RETURNING] \
		and c["region"] == _home(m, lead) and not _outgunned(m, c["pos"], lead.team, mine))
	if live.is_empty():
		return {}
	var held: Variant = lead.ai.get("camp_id", -1)
	for c in live:
		if c["id"] == held: return c
	live.sort_custom(func(a, b): return _order(lead, a) < _order(lead, b))
	lead.ai["camp_id"] = live[0]["id"]
	return live[0]

## The region a squad clears: the one its leader pinged (the landing can fall a little over a border), else where it is.
static func _home(m: Match, lead: Hunter) -> int:
	return int(m.skydrop.picks.get(lead.team, m.biomes.hot.region_at(lead.pos)))

## Smallest first, then nearest.
static func _order(lead: Hunter, c: Dictionary) -> float:
	return float(c["size"]) * 10000.0 + lead.flat_dist(c["pos"])

static func _total_level(m: Match, team: int) -> int:
	var n := 0
	for x in m.hunters:
		if x.team == team and not x.out: n += x.lvl
	return n

## A squad with more total levels than ours is at the camp.
static func _outgunned(m: Match, at: Vector3, team: int, mine: int) -> bool:
	for x in m.hunters:
		var near: bool = x.flat_dist(at) < float(_rules()["rival_r"])
		if x.team != team and not x.out and near and _total_level(m, x.team) > mine:
			return true
	return false

static func _blight_near(m: Match, h: Hunter, r: float) -> bool:
	return m.blight != null and m.mobs.any(func(mb): return mb is Blight and not mb.dead and h.flat_dist(mb) < r)
