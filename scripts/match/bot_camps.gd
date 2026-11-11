class_name BotCamps
extends RefCounted
## How bot squads play the early game around camps (spec EARLY_CAMPS_DROP 2.8 and 6.8, decision
## 0060; numbers in the "bots" block of content/rules/camps.json). On the drop map a bot leader with
## no human ping picks a camp: one region per bot squad, the Crown at most once. On the ground the
## squad clears its region smallest camp first until home_s, then plays the usual objectives and
## detours to a live camp close by while it is at or below the pace level. It stays together (XP
## only reaches a squadmate close to the kill), skips a camp a stronger squad is on, and leaves when
## the Blight is close or the camp is not safe for the next minute. It starts no fight with a squad
## two levels up, nor while a camp would bring its next even level. Squads with a person in them
## follow the person to camps instead. Bots earn XP the way Hunters do: nothing here pays any.
##
## Public API:
##   BotCamps.pick(m, h, picks) -> Vector3    the camp to ping from the drop map (INF: none free)
##   BotCamps.reachable(m, h, at) -> bool     the ship's run lets h's squad glide down onto `at`
##   BotCamps.goal(m, h) -> Array             [position, kind] for Bot._choose, or [] for none
##   BotCamps.hold_burst(m, h, tgt) -> bool   keep the abilities for the prize monster's kill window
##   BotCamps.fight_reach(m, h, o, reach, provoked) -> float   how far h reaches for rival o (0: leave it)
##   BotCamps.kin_leaves(m, own, o) -> bool   a bot's Boki leaves rival o alone (its Hunter would)
##   BotCamps.pace_level(t) -> int            the level a squad is asked to have at match time t

static func _rules() -> Dictionary:
	return Camps.rules()["bots"]

## The level by minute a squad is asked to keep (spec 6.2): pace_s[i] is when level i + 1 is due.
static func pace_level(t: float) -> int:
	var n := 0
	for s in _rules()["pace_s"]:
		if t >= float(s): n += 1
	return maxi(n, 1)

# ------------------------------------------------------------------ the drop map
## The ping of a bot leader with no human ping: a camp the ship's run lets it reach, in a region no
## other squad pinged, else one a single squad of people pinged. Never a region a bot squad has
## (picks: bot team -> region), so the Crown goes at most once.
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
	var bots := {}
	for t in picks:
		if int(t) != h.team: bots[picks[t]] = true
	var people := _people_in(m, h)
	for limit in [0, 1]:
		for r in order:
			if not bots.has(r) and int(people.get(r, 0)) == limit and not (r == crown and limit > 0):
				return _camp_to_ping(by_region[r])["pos"]
	return Vector3.INF

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

## Squads of people (other than h's) that pinged each region.
static func _people_in(m: Match, h: Hunter) -> Dictionary:
	var teams := {}
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

## A rim region (two sizes of camp) and the Crown ping their smallest camp; a mid region (three sizes) its middle one.
static func _camp_to_ping(camps: Array) -> Dictionary:
	var ids: Array = Camps.rules()["sizes"].map(func(s): return s["id"])
	var sorted := camps.duplicate()
	sorted.sort_custom(func(a, b): return ids.find(a["size"]) < ids.find(b["size"]))
	var distinct := {}
	for c in camps: distinct[c["size"]] = true
	return sorted[1] if distinct.size() >= 3 else sorted[0]

# ------------------------------------------------------------------ on the ground
static func goal(m: Match, h: Hunter) -> Array:
	if m.camps == null or m.biomes == null or m.skydrop == null:
		return []
	var squad := _squad(m, h.team)
	if squad.is_empty() or squad.any(func(x): return x.ctrl != "bot"):
		return []        # (a person leads their squad)
	var lead: Hunter = squad[0]
	var rivals := _rivals(m, squad)
	if not rivals.is_empty(): lead.ai["rival_t"] = m.time
	var prize := _steal(m, h)
	if prize != null:
		return [prize.pos, "steal"]
	var c := _camp_for(m, lead, squad, rivals)
	if c.is_empty():
		return []
	lead.ai["camp_t"] = m.time
	if h != lead and h.flat_dist(lead) > float(_rules()["together_r"]):
		return [lead.pos, "camp"]       # (stay together: XP only reaches a squadmate close to the kill)
	return [_spot(c, h), "camp"]

## Where to walk for a camp: its nearest monster still up (they chase and wander), else its centre.
static func _spot(c: Dictionary, h: Hunter) -> Vector3:
	var at: Vector3 = c["pos"]
	var bd := INF
	for mb in c["mobs"]:
		if is_instance_valid(mb) and not mb.dead and h.flat_dist(mb) < bd:
			bd = h.flat_dist(mb)
			at = mb.pos
	return at

## A team's Hunters still in the match.
static func _squad(m: Match, team: int) -> Array:
	return m.hunters.filter(func(x): return x.team == team and not x.out and not x.extracted)

## The camp this squad is after: until home_s its region's smallest live one (kept until it is gone),
## later the nearest within reach while the squad is at or below the pace level.
static func _camp_for(m: Match, lead: Hunter, squad: Array, rivals: Array) -> Dictionary:
	var R := _rules()
	var C: Camps = m.camps
	if not C.safe_for(lead.pos, float(R["safe_s"])) or _blight_near(m, lead.pos, float(R["blight_r"])):
		return {}
	var home := int(m.skydrop.picks.get(lead.team, -1))
	var live: Array = []
	if m.time < float(R["home_s"]) and home >= 0:
		var up := [Camps.State.LIVE, Camps.State.RETURNING]
		live = C.camps.filter(func(c): return c["state"] in up and c["region"] == home)
		live.sort_custom(func(a, b): return _order(lead, a) < _order(lead, b))
	if live.is_empty() and _level(squad) <= float(pace_level(m.time)):
		var near := C.nearest_live(lead.pos, float(R["detour_r"]))
		if not near.is_empty(): live = [near]
	for c in live:
		if _taken(c, squad, rivals, home) or _blight_near(m, c["pos"], float(R["blight_r"])):
			continue
		lead.ai["camp_id"] = c["id"]
		return c
	return {}

## Smallest first, then nearest; the camp the squad is already on stays first until it is gone.
static func _order(lead: Hunter, c: Dictionary) -> float:
	if c["id"] == lead.ai.get("camp_id", -1):
		return -1.0
	return float(c["size"]) * 10000.0 + lead.flat_dist(c["pos"])

## A squad's level: the mean of its Hunters still up.
static func _level(squad: Array) -> float:
	var n := 0.0
	for x in squad: n += x.lvl
	return n / maxf(1.0, squad.size())

## Hunters of other squads within rival_r of any of ours.
static func _rivals(m: Match, squad: Array) -> Array:
	var r := float(_rules()["rival_r"])
	return m.hunters.filter(func(x): return x.team != squad[0].team and not x.out and not x.extracted \
		and squad.any(func(o): return o.flat_dist(x) < r))

## A squad with more levels than ours is at the camp. Outside our own region an even squad has it too
## (the camp was theirs first; two even squads on one camp starve both).
static func _taken(c: Dictionary, squad: Array, rivals: Array, home: int) -> bool:
	var theirs := {}
	var r := float(_rules()["rival_r"])
	for x in rivals:
		if x.flat_dist(c["pos"]) < r: theirs[x.team] = int(theirs.get(x.team, 0)) + x.lvl
	var mine := 0
	for x in squad: mine += x.lvl
	if c["region"] != home: mine -= 1
	return theirs.values().any(func(v): return v > mine)

static func _blight_near(m: Match, p: Vector3, r: float) -> bool:
	return m.blight != null and m.mobs.any(func(mb): return mb is Blight and not mb.dead and mb.flat_dist(p) < r)

# ------------------------------------------------------------------ fights
## How far bot h reaches for rival Hunter o, from the reach Bot would use (spec 6.8). Before home_s
## (the opening, when the XP is camps) none at all. Later none for a squad fight.gap or more levels
## above ours, unless it was hurt in the last busy_s (it is already in a fight), and none while our
## squad is on a camp one short of an even level or the ultimate; press_k times further for a squad
## fight.gap or more below. A rival that hit h is always fought, but in the opening only if it was
## aiming at h: a splash or a chain meant for a camp monster starts no fight.
static func fight_reach(m: Match, h: Hunter, o: Hunter, reach: float, provoked: bool) -> float:
	var mine := _squad(m, h.team)
	if m.camps == null or mine.is_empty():
		return reach
	var opening: bool = m.time < float(_rules()["home_s"])
	if provoked and not (opening and _stray(h)):
		return reach
	if opening:
		return 0.0
	var F: Dictionary = _rules()["fight"]
	var theirs := _squad(m, o.team)
	var gap := _level(theirs) - _level(mine)
	if gap >= float(F["gap"]) and not theirs.any(func(x): return m.time - x.hurt_at < float(F["busy_s"])):
		return 0.0
	var next := int(_level(mine)) + 1
	var on_camp: bool = m.time - float(mine[0].ai.get("camp_t", -INF)) < float(F["camp_s"])
	if on_camp and (next % 2 == 0 or next == int(Hunter.ULT_AT[0])):
		return 0.0
	return reach * (float(F["press_k"]) if gap <= -float(F["gap"]) else 1.0)

## The last hit on h came from something aiming elsewhere: a Boki or a bot after another target.
static func _stray(h: Hunter) -> bool:
	var by = h.last_hit_by
	if by is Kin:
		return (by as Kin).target != h
	return by is Hunter and (by as Hunter).ctrl == "bot" and (by as Hunter).ai.get("tgt") != h

## A bot's Boki leaves rival o alone when its Hunter would not reach for o (fight_reach is 0). Without
## this the Boki, which likes a Hunter target, started the fights its Hunter avoids.
static func kin_leaves(m: Match, own: Hunter, o: Hunter) -> bool:
	if own.ctrl != "bot":
		return false
	return fight_reach(m, own, o, 1.0, own.last_hit_by == o or own.last_hit_by == o.kin) <= 0.0

# ------------------------------------------------------------------ steals
## A camp's prize monster: its Brute or Camp Chief (spec 6.6).
static func is_prize(e: Ent) -> bool:
	return e is Mob and Camps.is_camp(e) and (e.has_meta("chief") or e.mkind == "brute")

## The prize monster a bold bot goes to last-hit: one within steal.r in its kill window. Each bot
## makes up its mind once per monster.
static func _steal(m: Match, h: Hunter) -> Mob:
	var S: Dictionary = _rules()["steal"]
	if float(h.ai.get("skill", 0.5)) < float(S["bold"]):
		return null
	for c in m.camps.camps:
		if c["state"] == Camps.State.SPENT or h.flat_dist(c["pos"]) > 2.0 * float(S["r"]):
			continue
		for mb in c["mobs"]:
			if not is_instance_valid(mb) or mb.dead or not is_prize(mb): continue
			if mb.hp > mb.max_hp * float(S["hp"]) or h.flat_dist(mb) > float(S["r"]): continue
			var tries: Dictionary = h.ai.get_or_add("steal", {})
			if not tries.has(mb.get_instance_id()): tries[mb.get_instance_id()] = randf() < float(S["try"])
			if tries[mb.get_instance_id()]: return mb
	return null

## A squad that saw a rival close by in the last seen_s keeps its abilities while its prize monster
## is between hold_hp and the kill window, to spend them inside the window (spec 6.6, the reel).
static func hold_burst(m: Match, h: Hunter, tgt: Ent) -> bool:
	if not is_prize(tgt):
		return false
	var S: Dictionary = _rules()["steal"]
	if tgt.hp > tgt.max_hp * float(S["hold_hp"]) or tgt.hp <= tgt.max_hp * float(S["hp"]):
		return false
	for x in m.hunters:
		if x.team == h.team and m.time - float(x.ai.get("rival_t", -INF)) <= float(S["seen_s"]): return true
	return false
