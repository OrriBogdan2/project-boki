class_name BotCamps
extends RefCounted
## How bot squads play the early game on camps (docs/decisions/0048-camps-and-xp.md, numbers in the
## "bots" block of content/rules/camps.json). In the planning phase a bot squad leader with no human
## ping picks a camp: the hot zone at HotZone.BOT_PICK if no other squad has pinged it, else a rim or
## mid region (the Crown at most once a match, by one bot squad), pinging that region's Small Camp (rim)
## or Camp (mid). Two bot squads share a region only when every region already has one.
## After landing the squad clears its region's camps together (within keep_r of its leader), smallest
## to biggest, until camp_until_s; with its region cleared, a squad no more than roam_over_pace over
## the pace level takes the nearest live camp within roam_r in a region no other bot squad holds. In
## the opening bots and their Boki start no fight with rival bots, and a squad stops short of the
## ultimate (hold_level). A camp is left when it is no longer safe, a Blight Warden is near, or a squad
## with a higher total level is at it. After the opening the other goals lead; a squad whose best
## level is under detour_below detours to a camp that has come back.
##
## Public API:
##   BotCamps.pick(m, h) -> Vector3   the camp a leader pings (INF: the map has no camps)
##   BotCamps.goal(m, h) -> Array     [camp position, "camp"] for Bot._choose, or [] for no camp goal
##   BotCamps.camping(m) -> bool      the opening: bots pick no fight with rivals
##   BotCamps.kin_leaves(m, own, f) -> bool   a bot's Boki leaves this rival or held monster alone in the opening
##   BotCamps.holds(m, h, mb) -> bool   in the opening, h leaves this camp monster (its kill would bring an ultimate)
##   BotCamps.avoids(m, h, o) -> bool   h starts no fight with o's squad (2+ levels up and not busy)
##   BotCamps.provoked(m, h, o) -> bool   rival o started a fight with h (in the opening: on purpose)

static func rules() -> Dictionary:
	return Camps.rules()["bots"]

## "crown" for the region round the Heart, else "mid" with ring_great Great Camps or more (counted
## before the hot zone sizes them up), else "rim".
static func ring(m: Match, region: int) -> String:
	if region >= 0 and region < m.world.regions.size():
		var ids: Array = m.world.regions[region].get("islands", [])
		for I in m.world.islands:
			if String(I.get("role", "")) == "heart" and String(I.get("id", "")) in ids:
				return "crown"
	var great := 0
	var hot := m.biomes.hot.hot if m.biomes else -1
	for c in m.camps.camps:
		var base := int(c["size"]) - (1 if region == hot else 0)      # (the hot zone's camps are one size up)
		if c["region"] == region and Camps.size_def(base)["id"] == "great":
			great += 1
	return "mid" if great >= int(rules()["ring_great"]) else "rim"

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
		h.ai["camp_region"] = hot.hot
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
	if best_rank >= 99:
		return Vector3.INF
	var region: int = best.pick_random()
	h.ai["camp_region"] = region
	return _spot(m, region)

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

## The camp this bot should walk to now, as [position, "camp"]; [] when it has none to go to. In the
## opening the squad clears together: everyone takes the leader's camp, and a bot more than keep_r
## from its leader walks back to them first (XP is shared within 30 m of the kill).
static func goal(m: Match, h: Hunter) -> Array:
	if m.camps == null or m.biomes == null:
		return []
	var R := rules()
	var c: Dictionary
	if m.time < float(R["camp_until_s"]):
		var lead := _lead(m, h)
		c = _next_in_region(m, lead)
		if c.is_empty() and _best_level(m, h.team) <= XpRules.pace_level(m.time) + int(R["roam_over_pace"]):
			c = _unclaimed(m, lead, float(R["roam_r"]))
		if not c.is_empty() and _best_xp(m, h.team) + _camp_xp(c) >= _hold_xp():
			return []      # (no ultimate before 2:30: a camp that would bring one is left to others)
		if lead == h and not c.is_empty() and _stuck(m, h, c):
			return []
		if not c.is_empty() and lead != h and h.flat_dist(lead) > float(R["keep_r"]):
			return [lead.pos, "camp"]
	elif _best_level(m, h.team) < int(R["detour_below"]):
		c = m.camps.nearest_live(h.pos, float(R["detour_r"]))
		if not c.is_empty() and c["state"] != Camps.State.RETURNING:
			c = {}
	if c.is_empty() or not m.camps.safe_for(c["pos"], float(R["safe_s"])):
		return []
	if _blight_near(m, c["pos"]) or _outgunned(m, h, c):
		return []
	return [c["pos"], "camp"]

## The squad's leader (the drop leader while they are in, else the first squadmate still in).
static func _lead(m: Match, h: Hunter) -> Hunter:
	var l: Hunter = m.skydrop.leader(h.team) if m.skydrop else null
	if l != null and not l.out and not l.downed:
		return l
	for o in m.hunters:
		if o.team == h.team and not o.out and not o.downed:
			return o
	return h

## In the opening (until camp_until_s) bots leave rivals alone unless they start something.
static func camping(m: Match) -> bool:
	return m.time < float(rules()["camp_until_s"])

## In the opening a bot's Boki picks no rival Hunter either, unless that rival provoked the bot, and
## no camp monster its squad holds back from (holds).
static func kin_leaves(m: Match, own: Hunter, f: Ent) -> bool:
	if own == null or own.ctrl != "bot" or not camping(m):
		return false
	if f is Mob:
		return holds(m, own, f)
	return f is Hunter and not provoked(m, own, f)

## In the opening a bot squad holds back from a camp monster whose kill would bring someone near
## hold_level (the ultimate) before camp_until_s, even one on them: camp monsters keep to their camp.
static func holds(m: Match, h: Hunter, mb: Mob) -> bool:
	if not camping(m) or not mb.has_meta("camp"):
		return false
	return _best_xp(m, h.team) + XpRules.kill_xp(mb) >= _hold_xp()

## The XP at which a squad stops taking camp kills: hold_margin short of hold_level (a kill already on
## its way still lands).
static func _hold_xp() -> float:
	return float(Hunter.XP_TO[int(rules()["hold_level"]) - 1]) - float(rules()["hold_margin"])

## Spec 6.8: a bot does not start a fight with a squad avoid_gap or more levels above its own, unless
## that squad is busy with someone else.
static func avoids(m: Match, h: Hunter, o: Hunter) -> bool:
	if _best_level(m, o.team) - _best_level(m, h.team) < int(rules()["avoid_gap"]):
		return false
	var busy = o.ai.get("tgt")
	return not (busy is Hunter and busy.team != h.team)

## The rival o (or its Boki) hit h last. In the opening a rival bot's stray hit (a shot or a Boki
## meant for a monster) does not count: only one that is going for h, so camps do not turn into brawls.
static func provoked(m: Match, h: Hunter, o: Hunter) -> bool:
	var by = h.last_hit_by
	if by == null or (by != o and by != o.kin and by != o.kin2):
		return false
	if not camping(m) or o.ctrl != "bot":
		return true
	return o.ai.get("tgt") == h or (by is Kin and (by as Kin).target == h)

## The smallest live camp of the squad's region (the nearest of that size to its leader). The region
## is the one the leader pinged; a squad whose glide fell short takes the region it landed in instead,
## if no other bot squad has that one.
static func _next_in_region(m: Match, lead: Hunter) -> Dictionary:
	var region := _region(m, lead)
	var best := {}
	var best_key := 1e9
	for c in m.camps.camps:
		if c["region"] != region or c["state"] != Camps.State.LIVE or _skipped(lead, c):
			continue
		var key := float(c["size"]) * 1000.0 + lead.flat_dist(c["pos"])
		if key < best_key:
			best_key = key
			best = c
	return best

## With its own region cleared, the nearest live camp within r in a region no other bot squad holds.
static func _unclaimed(m: Match, lead: Hunter, r: float) -> Dictionary:
	var best := {}
	var bd := r
	for c in m.camps.camps:
		if c["state"] != Camps.State.LIVE or lead.flat_dist(c["pos"]) > bd or _skipped(lead, c):
			continue
		if _claimed(m, lead.team, int(c["region"])):
			continue
		bd = lead.flat_dist(c["pos"])
		best = c
	return best

## Another bot squad with someone still in holds this region (one that has stopped taking camps, holds,
## leaves it to others).
static func _claimed(m: Match, team: int, region: int) -> bool:
	for o in m.hunters:
		if o.team != team and o.ctrl == "bot" and not o.out and int(o.ai.get("camp_region", -1)) == region \
				and _best_xp(m, o.team) < _hold_xp():
			return true
	return false

## The leader walking to camp c has not come stuck_m closer in stuck_s (no way there on foot): the camp
## is struck off, and the squad takes the region it stands in as its own.
static func _stuck(m: Match, lead: Hunter, c: Dictionary) -> bool:
	var R := rules()
	var d := lead.flat_dist(c["pos"])
	var p: Dictionary = lead.ai.get("camp_prog", {})
	var walking := String(lead.ai.get("goal_kind", "")) == "camp"
	if p.get("id", -1) != c["id"] or not walking or d < float(p["d"]) - float(R["stuck_m"]):
		lead.ai["camp_prog"] = {"id": c["id"], "d": d, "t": m.time}
		return false
	if m.time - float(p["t"]) < float(R["stuck_s"]):
		return false
	var skip: Dictionary = lead.ai.get("camp_skip", {})
	skip[c["id"]] = true
	lead.ai["camp_skip"] = skip
	var here := m.biomes.hot.region_at(lead.pos)
	if here >= 0:
		lead.ai["camp_region"] = here
	lead.ai.erase("camp_prog")
	return true

static func _skipped(lead: Hunter, c: Dictionary) -> bool:
	return (lead.ai.get("camp_skip", {}) as Dictionary).has(c["id"])

static func _region(m: Match, lead: Hunter) -> int:
	if lead.ai.has("camp_region") and lead.ai.get("camp_landed", false):
		return int(lead.ai["camp_region"])
	if lead.riding or not lead.grounded:
		return int(lead.ai.get("camp_region", -1))
	var here := m.biomes.hot.region_at(lead.pos)
	if here >= 0 and (not _claimed(m, lead.team, here) or not lead.ai.has("camp_region")):
		lead.ai["camp_region"] = here
	lead.ai["camp_landed"] = true
	return int(lead.ai.get("camp_region", here))

static func _best_level(m: Match, team: int) -> int:
	var best := 0
	for o in m.hunters:
		if o.team == team and not o.out:
			best = maxi(best, o.lvl)
	return best

static func _best_xp(m: Match, team: int) -> float:
	var best := 0.0
	for o in m.hunters:
		if o.team == team and not o.out:
			best = maxf(best, o.xp)
	return best

## The XP still alive in camp c.
static func _camp_xp(c: Dictionary) -> float:
	var xp := 0.0
	for mb in c["mobs"]:
		if is_instance_valid(mb) and not mb.dead:
			xp += XpRules.kill_xp(mb)
	return xp

static func _total_level(m: Match, team: int) -> int:
	var sum := 0
	for o in m.hunters:
		if o.team == team and not o.out:
			sum += o.lvl
	return sum

## A Blight Warden (the sentry whose shriek calls every Blight nearby) stands within blight_r of p.
static func _blight_near(m: Match, p: Vector3) -> bool:
	var r := float(rules()["blight_r"])
	for mb in m.mobs:
		if mb is Blight and not mb.dead and mb.mkind == "bl_warden" and mb.flat_dist(p) < r:
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
