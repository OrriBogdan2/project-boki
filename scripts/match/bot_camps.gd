class_name BotCamps
extends RefCounted
## How bot squads play the early game on camps (docs/decisions/0048-camps-and-xp.md, numbers in the
## "bots" block of content/rules/camps.json). In the planning phase a bot squad leader with no human
## ping picks a camp: the hot zone at HotZone.BOT_PICK if no other squad has pinged it, else a rim or
## mid region (the Crown at most once a match, by one bot squad), pinging that region's Small Camp (rim)
## or Camp (mid). Two bot squads share a region only when every region already has one.
## After landing a squad clears its region's camps from the smallest to the biggest until camp_until_s,
## then hands over to the other goals; a squad whose best level is still low detours to a camp that
## has come back. A camp is left when it is no longer safe, the Blight is near, or a squad with a
## higher total level is at it.
##
## Public API:
##   BotCamps.pick(m, h) -> Vector3   the camp a leader pings (INF: the map has no camps)
##   BotCamps.goal(m, h) -> Array     [camp position, "camp"] for Bot._choose, or [] for no camp goal
##   BotCamps.camping(m) -> bool      the opening: bots pick no fight with rivals

static func rules() -> Dictionary:
	return Camps.rules()["bots"]

## "rim", "mid" or "crown": how many Great Camps a region holds.
static func ring(m: Match, region: int) -> String:
	var great := 0
	for c in m.camps.camps:
		if c["region"] == region and Camps.size_def(int(c["size"]))["id"] == "great":
			great += 1
	var need: Dictionary = rules()["ring_great"]
	if great >= int(need["crown"]):
		return "crown"
	return "mid" if great >= int(need["mid"]) else "rim"

## Region -> {team: true if that squad is bots} for the squads other than h's that have pinged it.
static func _pinged(m: Match, h: Hunter) -> Dictionary:
	var out := {}
	for p in m.pings:
		var by = p.get("by")
		if not (by is Hunter) or by.team == h.team:
			continue
		var region := m.biomes.hot.region_at(p["pos"])
		if region >= 0:
			if not out.has(region):
				out[region] = {}
			out[region][by.team] = by.ctrl == "bot"
	return out

## The camp spot a bot squad leader pings, or INF when the map has no camps.
static func pick(m: Match, h: Hunter) -> Vector3:
	if m.camps == null or m.biomes == null:
		return Vector3.INF
	var hot: HotZone = m.biomes.hot
	var pinged := _pinged(m, h)
	if hot.hot >= 0 and randf() < HotZone.BOT_PICK and not pinged.has(hot.hot):
		return hot.landing()
	var regions := {}
	for c in m.camps.camps:
		if c["region"] >= 0:
			regions[c["region"]] = true
	var crown_roll := randf() < float(rules()["crown_pick"])
	var best_rank := 99
	var best: Array = []
	for region in regions:
		var rank := _rank(m, region, pinged.get(region, {}), crown_roll)
		if rank < best_rank:
			best_rank = rank
			best = []
		if rank == best_rank:
			best.append(region)
	return _spot(m, best.pick_random()) if best_rank < 99 else Vector3.INF

## How good a region is to land in, lowest first: unpinged rim and mid regions, one with a human squad,
## the hot zone and the Crown (the Crown first when the roll says so, never with a bot squad in it),
## then the ones a bot squad already has: the surplus when squads outnumber regions.
static func _rank(m: Match, region: int, squads: Dictionary, crown_roll: bool) -> int:
	var bots := squads.values().count(true)
	if ring(m, region) == "crown":
		if bots > 0:
			return 99
		return -1 if crown_roll and squads.is_empty() else 2
	if region == m.biomes.hot.hot:
		return 2 if bots == 0 else 3 + squads.size()
	if squads.is_empty():
		return 0
	return 1 if squads.size() == 1 and bots == 0 else 3 + squads.size()

## The camp a leader pings in a region: the size the ring asks for, else its smallest.
static func _spot(m: Match, region: int) -> Vector3:
	var want := String(rules()["ping"][ring(m, region)])
	var best := Vector3.INF
	var best_size := 99
	for c in m.camps.camps:
		if c["region"] != region:
			continue
		var size_i := int(c["size"])
		if Camps.size_def(size_i)["id"] == want:
			return c["pos"]
		if size_i < best_size:
			best_size = size_i
			best = c["pos"]
	return best

## The camp this bot should walk to now, as [position, "camp"]; [] when it has none to go to.
static func goal(m: Match, h: Hunter) -> Array:
	if m.camps == null or m.biomes == null:
		return []
	var R := rules()
	var c: Dictionary
	if m.time < float(R["camp_until_s"]):
		c = _next_in_region(m, h)
	elif _best_level(m, h.team) < int(R["detour_below"]):
		c = m.camps.nearest_live(h.pos, float(R["detour_r"]))
		if not c.is_empty() and c["state"] != Camps.State.RETURNING:
			c = {}
	if c.is_empty() or not m.camps.safe_for(c["pos"], float(R["safe_s"])):
		return []
	if _blight_near(m, h) or _outgunned(m, h, c):
		return []
	return [c["pos"], "camp"]

## In the opening (until camp_until_s) bots leave rivals alone unless they start something.
static func camping(m: Match) -> bool:
	return m.time < float(rules()["camp_until_s"])

## The smallest live camp of the squad's own region (the nearest of that size).
static func _next_in_region(m: Match, h: Hunter) -> Dictionary:
	var region := int(h.ai.get("camp_region", -1))
	if region < 0:
		region = m.biomes.hot.region_at(h.pos)
		h.ai["camp_region"] = region
	var best := {}
	var best_key := 1e9
	for c in m.camps.camps:
		if c["region"] != region or c["state"] != Camps.State.LIVE:
			continue
		var key := float(c["size"]) * 1000.0 + h.flat_dist(c["pos"])
		if key < best_key:
			best_key = key
			best = c
	return best

static func _best_level(m: Match, team: int) -> int:
	var best := 0
	for o in m.hunters:
		if o.team == team and not o.out:
			best = maxi(best, o.lvl)
	return best

static func _total_level(m: Match, team: int) -> int:
	var sum := 0
	for o in m.hunters:
		if o.team == team and not o.out:
			sum += o.lvl
	return sum

static func _blight_near(m: Match, h: Hunter) -> bool:
	var r := float(rules()["blight_r"])
	for mb in m.mobs:
		if mb is Blight and not mb.dead and h.flat_dist(mb) < r:
			return true
	return false

## A squad with a higher total level than h's is at the camp.
static func _outgunned(m: Match, h: Hunter, c: Dictionary) -> bool:
	var r := float(rules()["fight_r"])
	var mine := _total_level(m, h.team)
	for o in m.hunters:
		if o.team != h.team and not o.out and o.flat_dist(c["pos"]) < r and _total_level(m, o.team) > mine:
			return true
	return false
