class_name BotCamps
extends RefCounted
## Bots level the way a player is asked to (docs/EARLY_CAMPS_DROP sections 2.8 and 6.8), under the
## same XpRules as everyone: no bot-only XP. Numbers in content/rules/camps.json "bots".
##   - The drop: a bot squad leader with no human ping picks a camp, not a spot: the hot zone at
##     HotZone.BOT_PICK if nobody else is headed there, else a rim or mid region at most one other
##     squad has pinged, never one another bot squad took (the Crown only as a last pick, once).
##   - Landed: clear the region's camps smallest first, keeping within keep_r of each other so all
##     share the XP; skip a camp a stronger squad fights on, the Blight's Wardens stand near, or
##     the Blight will have within safe_s. From farm_until_s the way-out objectives lead, and a squad
##     at or under the pace level (or one short of an even level or of 6) detours to a camp in reach.
##   - Fights by level: avoid a squad gap levels up unless it is already in a fight, press one gap
##     levels down. Steals: a bold bot near a prize monster in its kill window goes for the last hit;
##     a squad that saw a rival near holds its fire on a prize monster at hold.frac, then bursts.
##
## Public API (bot.gd and drop_squad.gd wire these):
##   BotCamps.pick(m, h) -> Vector3   the camp a bot leader pings in the planning phase (INF: none)
##   BotCamps.goal(m, h) -> Vector3   the camp (or the squadmate to regroup on) to head for (INF: none)
##   BotCamps.ring(m, region) -> String   "crown", "mid" or "rim"
##   BotCamps.leaving(m, h, mb) -> bool   mb is a camp monster of a camp this bot is leaving
##   BotCamps.reach_k(m, h, o, provoked) -> float   how far this bot reaches for rival o (0: leave them be)
##   BotCamps.steal(m, h) -> Mob   a prize monster to take the last hit on (null: none)
##   BotCamps.hold(m, h, tgt) -> bool   hold fire on this prize monster for now

const REGION := "camp_region"      # Hunter.ai key: the region this bot's squad picked to farm
const LANDED := "camp_landed"      # Hunter.ai key: the squad has checked where it came down
const FIGHT_S := 3.0               # s: a Hunter hit by a rival this recently is in a fight

static var _best: Dictionary = {}  # team -> best level, for _best_t
static var _best_t := -1.0

static func rules() -> Dictionary:
	return Camps.rules()["bots"]

# ------------------------------------------------------------------ the drop
static func pick(m: Match, h: Hunter) -> Vector3:
	if m.camps == null or m.camps.camps.is_empty() or m.biomes == null:
		return Vector3.INF
	var claims := _claims(m, h.team)
	var hot: int = m.biomes.hot.hot
	var region := -1
	if hot >= 0 and randf() < HotZone.BOT_PICK and (claims.get(hot, {}) as Dictionary).is_empty() \
			and _reach(m, h, _ping_camp(m, hot)):
		region = hot
	else:
		var open: Array = []
		var crown := -1
		for c in m.camps.camps:
			var r := int(c["region"])
			if r < 0 or r in open or not _open(claims, r) or not _reach(m, h, _ping_camp(m, r)):
				continue
			if ring(m, r) == "crown":
				crown = r
			else:
				open.append(r)
		if open.is_empty() and crown >= 0 and not _crown_taken(m):
			open.append(crown)
		if open.is_empty():
			return Vector3.INF
		region = open.pick_random()
	var c := _ping_camp(m, region)
	for o in m.hunters:
		if o.team == h.team:
			o.ai[REGION] = region
	return c["pos"]

## The camp is in gliding reach of the ship's line (a bot falling short lands somewhere else).
static func _reach(m: Match, h: Hunter, c: Dictionary) -> bool:
	var s := m.ship_of(h)
	if c.is_empty() or s.is_empty() or not s.has("a"):
		return not c.is_empty()
	var a: Vector3 = s["a"]
	var b: Vector3 = s["b"]
	var p: Vector3 = c["pos"]
	var line := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(a.x, a.z), Vector2(b.x, b.z))
	var reach := (a.y + 1.0) / DropFeel.canopy_fall * DropFeel.canopy_speed * float(rules()["reach_k"])
	return line.distance_to(Vector2(p.x, p.z)) < reach

## region -> {team: true if that squad is a bot squad} for every other squad's ping or bot pick.
static func _claims(m: Match, team: int) -> Dictionary:
	var out := {}
	for p in m.pings:
		var by = p.get("by")
		if by is Hunter and (by as Hunter).team != team:
			var r: int = m.biomes.hot.region_at(p["pos"])
			if r >= 0:
				(out.get_or_add(r, {}) as Dictionary)[(by as Hunter).team] = (by as Hunter).ctrl == "bot"
	for o in m.hunters:
		if o.team != team and o.ai.has(REGION):
			(out.get_or_add(int(o.ai[REGION]), {}) as Dictionary)[o.team] = true
	return out

## At most one other squad there, and no bot squad.
static func _open(claims: Dictionary, r: int) -> bool:
	var cl: Dictionary = claims.get(r, {})
	return cl.size() <= 1 and not cl.values().has(true)

static func _crown_taken(m: Match) -> bool:
	for o in m.hunters:
		if o.ai.has(REGION) and ring(m, int(o.ai[REGION])) == "crown":
			return true
	return false

## "crown" (the Heart's region), "mid" (it holds a Great Camp before the hot zone's step up) or "rim".
static func ring(m: Match, r: int) -> String:
	var W := m.world
	for ii in W.islands.size():
		if m.biomes.hot.region_of[ii] == r and String(W.islands[ii].get("role", "")) == "heart":
			return "crown"
	for c in m.camps.camps:
		if int(c["region"]) == r and _base_size(m, c) >= 2:
			return "mid"
	return "rim"

## The camp's size before the hot zone stepped it up (an index into Camps' sizes).
static func _base_size(m: Match, c: Dictionary) -> int:
	return int(c["size"]) - (1 if int(c["region"]) == m.biomes.hot.hot else 0)

## The region's camp a leader pings: its Small Camp on the rim, its Camp mid (else its smallest).
static func _ping_camp(m: Match, r: int) -> Dictionary:
	var want := String(rules()["ping_size"].get(ring(m, r), "small"))
	var best := {}
	for c in m.camps.camps:
		if int(c["region"]) != r:
			continue
		if Camps.size_def(_base_size(m, c))["id"] == want:
			return c
		if best.is_empty() or int(c["size"]) < int(best["size"]):
			best = c
	return best

# ------------------------------------------------------------------ landed
static func goal(m: Match, h: Hunter) -> Vector3:
	if m.camps == null or h.lvl >= Hunter.XP_TO.size():
		return Vector3.INF
	var B := rules()
	var c := {}
	if h.ai.has(REGION) and not h.ai.has(LANDED):
		_landed(m, h)
	if m.time < float(B["farm_until_s"]) and h.ai.has(REGION):
		c = _next_in_region(m, h, int(h.ai[REGION]))
	if c.is_empty() and _wants_camp(m, h):
		c = _camp_near(m, h)
	if c.is_empty():
		return Vector3.INF
	var p: Vector3 = c["pos"]
	# keep together so the whole squad shares the XP: the one nearer the camp waits for the one behind
	var lag := _laggard(m, h, p)
	if lag and h.flat_dist(lag) > float(B["keep_r"]):
		return lag.pos
	return p

## Down, and not in the region we picked (the glide fell short): farm the one we are in, unless
## another bot squad has it.
static func _landed(m: Match, h: Hunter) -> void:
	var here: int = m.biomes.hot.region_at(h.pos)
	var taken := false
	for o in m.hunters:
		taken = taken or (o.team != h.team and int(o.ai.get(REGION, -1)) == here)
	for o in m.hunters:
		if o.team == h.team:
			o.ai[LANDED] = true
			if here != int(h.ai[REGION]):
				if taken or here < 0: o.ai.erase(REGION)
				else: o.ai[REGION] = here

## The region's next camp: the smallest live one we may take, the nearest of those.
static func _next_in_region(m: Match, h: Hunter, r: int) -> Dictionary:
	var best := {}
	var bd := 1e9
	for c in m.camps.camps:
		if int(c["region"]) != r or not c["state"] in [Camps.State.LIVE, Camps.State.RETURNING] or not _ok(m, h, c):
			continue
		var d := int(c["size"]) * 1000.0 + h.flat_dist(c["pos"])
		if d < bd:
			bd = d
			best = c
	return best

## Safe for the next safe_s, no Blight Warden within blight_r, and no stronger squad fighting on it.
static func _ok(m: Match, h: Hunter, c: Dictionary) -> bool:
	var B := rules()
	var p: Vector3 = c["pos"]
	if not m.camps.safe_for(p, float(B["safe_s"])):
		return false
	for b in m.mobs:
		if b is Blight and not b.dead and b.mkind == "bl_warden" and b.flat_dist(p) < float(B["blight_r"]):
			return false
	var mine := best_level(m, h.team)
	for o in m.hunters:
		if o.team != h.team and not o.out and o.flat_dist(p) < float(B["fight_r"]) and best_level(m, o.team) > mine:
			return false
	return true

## At or under the pace level: a camp is worth the detour.
static func _wants_camp(m: Match, h: Hunter) -> bool:
	return best_level(m, h.team) <= XpRules.pace_level(m.time)

## A live camp in detour reach we may take ({} if none).
static func _camp_near(m: Match, h: Hunter) -> Dictionary:
	var c: Dictionary = m.camps.nearest_live(h.pos, float(rules()["detour_r"]))
	return c if not c.is_empty() and _ok(m, h, c) else {}

## The squadmate on its feet furthest from p (null: none but us).
static func _laggard(m: Match, h: Hunter, p: Vector3) -> Hunter:
	var far: Hunter = null
	var fd := h.flat_dist(p)
	for o in m.hunters:
		var up: bool = not (o.out or o.downed or o.riding or o.dropping or o.extracted)
		if o != h and o.team == h.team and up and o.flat_dist(p) > fd:
			fd = o.flat_dist(p)
			far = o
	return far

static func leaving(m: Match, h: Hunter, mb: Mob) -> bool:
	if m.camps == null or not Camps.is_camp(mb) or int(mb.get_meta("camp")) >= m.camps.camps.size():
		return false
	return not _ok(m, h, m.camps.camps[int(mb.get_meta("camp"))])

## The highest level among a squad's Hunters still in the match (cached for one step of the clock).
static func best_level(m: Match, team: int) -> int:
	if m.time != _best_t:
		_best_t = m.time
		_best.clear()
		for o in m.hunters:
			if not o.out:
				_best[o.team] = maxi(int(_best.get(o.team, 1)), o.lvl)
	return int(_best.get(team, 1))

# ------------------------------------------------------------------ fights and steals
static func reach_k(m: Match, h: Hunter, o: Ent, provoked: bool) -> float:
	if provoked or not (o is Hunter):
		return 1.0
	var B := rules()
	var gap := best_level(m, o.team) - best_level(m, h.team)
	if gap >= int(B["gap"]) and not _in_fight(m, o as Hunter):
		return 0.0
	if gap <= -int(B["gap"]):
		return float(B["press_k"])
	if m.camps == null:
		return 1.0
	if m.time < float(B["farm_until_s"]):
		return 0.0      # the drop's farm: camps first, Hunters only when they start it
	if best_level(m, h.team) % 2 == 1 and not _camp_near(m, h).is_empty():
		return 0.0      # one short of an even level (or of 6): the camp first
	return 1.0

static func _in_fight(m: Match, o: Hunter) -> bool:
	for t in o.hit_by.values():
		if m.time - float(t) < FIGHT_S:
			return true
	return false

static func is_prize(mb: Ent) -> bool:
	return mb is Mob and (mb as Mob).mkind in XpRules.rules()["steal"]["prize"]

static func _in_window(mb: Ent, frac: float) -> bool:
	return mb.hp <= mb.max_hp * frac

## A bold bot within steal.r of a prize monster in its kill window that a rival squad is on tries
## the last hit, steal.chance of the time (one roll per monster).
static func steal(m: Match, h: Hunter) -> Mob:
	var S: Dictionary = rules()["steal"]
	if float(h.ai["skill"]) < float(S["bold_skill"]):
		return null
	var window := float(XpRules.rules()["steal"]["window"])
	for mb in m.mobs:
		if mb.dead or not is_prize(mb) or not _in_window(mb, window) or h.flat_dist(mb) > float(S["r"]):
			continue
		var on_it: Ent = mb.last_hit_by.owner_h if mb.last_hit_by is Kin else mb.last_hit_by
		if not (on_it is Hunter) or on_it.team == h.team:
			continue
		var rolls: Dictionary = h.ai.get_or_add("steal_rolls", {})
		if not rolls.has(mb.get_instance_id()):
			rolls[mb.get_instance_id()] = randf() < float(S["chance"])
		if rolls[mb.get_instance_id()]:
			return mb
	return null

## A squad that saw a rival within hold.seen_r in the last hold.seen_s stops at hold.frac on a prize
## monster for up to hold.max_s, then lets everything go at once (abilities ready the moment it ends).
static func hold(m: Match, h: Hunter, tgt: Ent) -> bool:
	var H: Dictionary = rules()["hold"]
	if not is_prize(tgt) or not _in_window(tgt, float(H["frac"])):
		h.ai.erase("hold_t")
		h.ai.erase("burst_done")
		return false
	var seen := -99.0
	for o in m.hunters:
		if o.team == h.team and not o.out:
			for r in m.hunters:
				if r.team != h.team and not r.out and r.flat_dist(o) < float(H["seen_r"]):
					o.ai["rival_t"] = m.time
			seen = maxf(seen, float(o.ai.get("rival_t", -99.0)))
	if m.time - seen > float(H["seen_s"]):
		return false
	var t0 := float(h.ai.get_or_add("hold_t", m.time))
	if m.time - t0 < float(H["max_s"]):
		return true
	if not h.ai.get("burst_done", false):
		h.ai["burst_done"] = true
		h.ai["abil_t"] = 0.0
	return false
