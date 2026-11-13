extends RefCounted
## --air-rings-check: the Hollow Crown's air rings (scripts/match/air_rings.gd, docs/AIR_RINGS.md).
## The map lays its lanes and lift rings from content/maps/hollowcrown.json; every region has a ring;
## each lane is flown both ways by a hunter on scripted keys, through every ring, onto the far island,
## held at ring speed and well inside AIR_MAX_S; a bot takes a lane on its own crossing logic and plans
## each lane as its quickest way across (BotRoute, by time); a hop into each lift ring lands you on the
## high ground it serves, and a bot sent up there gets there quickly (by the ring when that is quicker).
## Never touches the save.

const AIR_MAX_S := 25.0         # s: the longest a lane may take (no empty runs past this)
const RING_GAP_S := 3.0         # s: the longest between two rings on a lane
const FLY_LIMIT_S := 30.0       # s: a flight that hasn't landed by now failed
const LIFT_LIMIT_S := 6.0       # s: a hop into a lift ring that isn't on top by now failed
const BOT_LIFT_LIMIT_S := 7.0   # s: a bot 3 m off a lift ring not on top by now was too slow (the ring takes ~5)

var bad := 0
var bot_lifts := 0              # lift rings a bot took on its own (_bot_lift)
var m: Match
var w: World
var P: Hunter

func ok(cond: bool, what: String) -> void:
	print("AIRRINGS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true})
	m.set_process(false)
	w = m.world
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		if h != P:
			_park(h)
	if P.kin:
		(P.kin as Kin).stow()
	P.ctrl = "local"
	_layout()
	_hint()
	for i in m.air_rings.lanes.size():
		_fly(i, false)
		_fly(i, true)
	_bot()
	_routes()
	for rg in m.air_rings.list:
		if rg["lift"]:
			_lift(rg)
			_bot_lift(rg)
	ok(bot_lifts >= 2, "bots take lift rings by themselves (%d)" % bot_lifts)
	print("AIRRINGS DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _park(h: Hunter) -> void:
	h.teleport(Vector3(-500, 50, -500))
	h.out = true

func _reset(h: Hunter, at: Vector3) -> void:
	h.out = false
	h.downed = false
	h.teleport(at)
	h.vel = Vector3.ZERO
	h.grounded = true
	h.gliding = false
	h.auto_glide = false
	h.glide_fuel = 1.0
	h.glide_cd = 0.0
	h.inp["move"] = Vector2.ZERO
	h.inp["jump"] = false
	h.inp["glide"] = false
	for rg in m.air_rings.list:
		rg["cd"].clear()

## The first-time hint: once per save, only airborne, never after the player flew a ring this match.
func _hint() -> void:
	var rg: Dictionary = m.air_rings.list[0]
	var seen: Dictionary = Save.d["tutorial"]
	var key: String = Settings.key_cap("glide")
	var at: Vector3 = rg["pos"] + Vector3(0, 3, 0)
	_reset(P, at)
	m.hud.msgs.clear()
	m.air_rings._tip()
	ok(not seen.get("rings", false) and m.hud.msgs.count() == 0, "no hint while standing on the ground")
	P.grounded = false
	P.add_stat("rings")
	m.air_rings._tip()
	ok(not seen.get("rings", false) and m.hud.msgs.count() == 0, "no hint after a ring flown this match")
	P.stats["rings"] = 0
	P.teleport(Vector3(-400, 50, -400))
	m.air_rings._tip()
	ok(not seen.get("rings", false), "no hint with no ring in view")
	P.teleport(at)
	m.air_rings._tip()
	var texts: Array[String] = m.hud.msgs.texts()
	ok(seen.get("rings", false) and texts.size() == 1 and texts[0].contains(key) and not texts[0].contains("\n"),
		"airborne with a ring in view: one line naming the glide key %s (%s)" % [key, texts])
	m.hud.msgs.clear()
	m.air_rings._tip()
	ok(m.hud.msgs.count() == 0, "shown once per save")
	_reset(P, at)
	P.grounded = true
	seen.erase("rings")


## The map data made it into the world: lanes with rings, a way back for bots, a lift ring per updraft.
func _layout() -> void:
	var L := World.load_layout("hollowcrown")
	var lanes := (L["glides"] as Array).filter(func(G): return G is Dictionary and G.get("rings", false))
	var lifts := (L["updrafts"] as Array).filter(func(U): return U.get("ring", false))
	var air: AirRings = m.air_rings
	ok(air.lanes.size() == lanes.size() and lanes.size() >= 6, "every air lane is laid (%d)" % lanes.size())
	var n_lift := air.list.filter(func(rg): return rg["lift"]).size()
	ok(n_lift == lifts.size() and n_lift >= 5, "a lift ring over every ringed updraft (%d)" % n_lift)
	ok(air.list.all(func(rg): return rg["node"].is_inside_tree()), "every ring is in the world")
	for G in lanes:
		var back := w.links.filter(func(lk): return _joins(lk, String(G["b"]), String(G["a"])))
		ok(not back.is_empty(), "lane %s -> %s has a way back for bots" % [G["a"], G["b"]])
	var served := {}
	for G in lanes:
		served[G["a"]] = true
		served[G["b"]] = true
	for U in lifts:
		for R in L["regions"]:
			if R["id"] == U["region"]:
				served[R["islands"][0]] = true
	for R in L["regions"]:
		var has := (R["islands"] as Array).any(func(i): return served.has(i))
		ok(has, "region %s has an air ring (a lane end or a lift)" % R["id"])

func _joins(lk: Dictionary, from: String, to: String) -> bool:
	return lk.get("glide", false) and w.islands[lk["from"]]["id"] == from and w.islands[lk["to"]]["id"] == to

## The lane's ring entries, ordered from `from` along the lane.
func _rings_of(lane: int, from: Vector3) -> Array:
	var out := m.air_rings.list.filter(func(rg): return int(rg["lane"]) == lane)
	out.sort_custom(func(a, b): return from.distance_to(a["pos"]) < from.distance_to(b["pos"]))
	return out

## Fly a lane on keys: run off the take-off, jump, glide toward the landing; count rings on the way.
func _fly(lane: int, backward: bool) -> void:
	var ln: Dictionary = m.air_rings.lanes[lane]
	var up := Vector3.UP * AirRings.r("up")
	var take: Vector3 = (ln["b"] if backward else ln["a"]) - up
	var land: Vector3 = (ln["a"] if backward else ln["b"]) - up
	var rings := _rings_of(lane, take)
	var to_island := w.island_of(land.x, land.z)
	var way := "back" if backward else "out"
	var label := "lane %d %s (%.0f m)" % [lane, way, Vector2(land.x - take.x, land.z - take.z).length()]
	_reset(P, take)
	var dir := Vector2(land.x - take.x, land.z - take.z).normalized()
	var hit_t: Array = []
	var closest: Array = []
	closest.resize(rings.size())
	closest.fill(INF)
	var held := 0.0
	var t := 0.0
	var landed := false
	while t < FLY_LIMIT_S:
		var ahead := P.pos + Vector3(dir.x, 0, dir.y) * 1.2
		P.inp["move"] = dir
		P.inp["jump"] = P.grounded and hit_t.is_empty() and w.is_void(ahead.x, ahead.z)
		P.inp["glide"] = not P.grounded and (P.gliding or P.vel.y < 1.0)
		var n0: int = m.air_rings.n
		m.step(Match.DT)
		t += Match.DT
		for i in rings.size():
			closest[i] = minf(closest[i], (P.pos + Vector3.UP * AirRings.BODY_Y).distance_to(rings[i]["pos"]))
		if m.air_rings.n > n0:
			hit_t.append(t)
			held = 0.0
		elif not hit_t.is_empty() and held >= 0.0 and P.gliding:
			held += Match.DT
			if held > AirRings.r("hold") * 0.7:
				var speed := Vector2(P.vel.x, P.vel.z).length()
				var fast := speed >= AirRings.r("speed") - 0.5
				ok(fast, "%s: still at ring speed late in the hold (%.1f m/s)" % [label, speed])
				held = -1.0
		if P.grounded and w.island_of(P.pos.x, P.pos.z) == to_island:
			landed = true
			break
	var misses := ", ".join(closest.map(func(d): return "%.1f" % d))
	var all_hit := hit_t.size() == rings.size()
	ok(all_hit, "%s: through every ring (%d of %d; closest m: %s)" % [label, hit_t.size(), rings.size(), misses])
	ok(landed, "%s: lands on %s (%.1f s)" % [label, w.islands[to_island]["id"], t])
	ok(t <= AIR_MAX_S, "%s: crossed in %.1f s (limit %d)" % [label, t, AIR_MAX_S])
	var worst := 0.0
	for i in range(1, hit_t.size()):
		worst = maxf(worst, float(hit_t[i]) - float(hit_t[i - 1]))
	ok(worst <= RING_GAP_S, "%s: at most %.1f s between rings (%.1f)" % [label, RING_GAP_S, worst])

## A bot on its own crossing logic takes the longest lane and flies its rings.
func _bot() -> void:
	var longest := -1
	var best := 0.0
	for i in m.air_rings.lanes.size():
		var ln: Dictionary = m.air_rings.lanes[i]
		var d := Vector2(ln["b"].x - ln["a"].x, ln["b"].z - ln["a"].z).length()
		if d > best:
			best = d
			longest = i
	var ln: Dictionary = m.air_rings.lanes[longest]
	var take: Vector3 = ln["a"] - Vector3.UP * AirRings.r("up")
	var link: Dictionary = {}
	for lk in w.links:
		if lk.get("glide", false) and Vector2(lk["take"].x - take.x, lk["take"].z - take.z).length() < 1.0:
			link = lk
	ok(not link.is_empty(), "the longest lane is a bot route")
	if link.is_empty():
		return
	var B: Hunter = null
	for h in m.hunters:
		if h != P:
			B = h
	_park(P)
	_reset(B, take)
	B.ctrl = "bot"
	B.ai["cross"] = link
	B.ai["cross_t"] = 14.0
	B.ai["tgt"] = null
	var n0: int = m.air_rings.n
	var t := 0.0
	while t < 20.0 and not (t > 1.0 and B.grounded and w.island_of(B.pos.x, B.pos.z) == int(link["to"])):
		B.ai["think"] = 1.0
		m.step(Match.DT)
		t += Match.DT
	var rings := _rings_of(longest, take).size()
	var flown: int = m.air_rings.n - n0
	ok(flown >= rings, "a bot flies the %.0f m lane through its rings (%d of %d)" % [best, flown, rings])
	ok(w.island_of(B.pos.x, B.pos.z) == int(link["to"]), "the bot lands across in %.1f s" % t)
	B.ctrl = "idle"
	_park(B)

## Hop into a lift ring: up the updraft, then steer onto the ground of the level it serves.
func _lift(rg: Dictionary) -> void:
	var c: Vector3 = rg["pos"]
	var foot := Vector3(c.x, w.ground_at(c.x, c.z), c.z)
	var top_y: float = rg["top"]
	var target: Vector3 = rg["onto"]
	var label := "lift at (%.0f, %.0f) to %.1f m" % [c.x, c.z, top_y]
	ok(target != Vector3.INF, "%s: has high ground beside it" % label)
	if target == Vector3.INF:
		return
	_reset(P, foot)
	var t := 0.0
	var peak := foot.y
	while t < LIFT_LIMIT_S:
		var high := P.pos.y > top_y + 0.4
		P.inp["jump"] = t < 0.05
		P.inp["move"] = Vector2(target.x - P.pos.x, target.z - P.pos.z).normalized() if high else Vector2.ZERO
		P.inp["glide"] = not P.grounded
		m.step(Match.DT)
		t += Match.DT
		peak = maxf(peak, P.pos.y)
		if t > 0.5 and P.grounded:
			break
	ok(peak >= top_y + 0.8, "%s: carries you above the top (%.1f m)" % [label, peak])
	var on_top := P.grounded and P.pos.y >= top_y - 0.05
	ok(on_top, "%s: lands on the high ground in %.1f s (at %.1f m)" % [label, t, P.pos.y])

## Standing at a lane's take-off, the quickest way to the far island (by time) is the lane.
func _routes() -> void:
	for lk in w.links:
		if not lk.get("rings", false):
			continue
		var hop := BotRoute.plan(w, lk["take"], int(lk["from"]), int(lk["to"]))
		var what := "a bot at the lane %d>%d's take-off plans the lane (%.1f s)" % [int(lk["from"]), int(lk["to"]),
			BotRoute.hop_s(lk)]
		ok(hop.get("rings", false) and hop["take"] == lk["take"], what)

## A bot 3 m off a lift ring's foot (on the far side from the high ground), sent up to it, gets there in
## time: by the ring, or on foot when the stairs are the quicker way.
func _bot_lift(rg: Dictionary) -> void:
	var c: Vector3 = rg["pos"]
	var onto: Vector3 = rg["onto"]
	if onto == Vector3.INF:
		return
	var away := (Vector3(c.x, 0, c.z) - Vector3(onto.x, 0, onto.z)).normalized()
	var start := Vector3(c.x, 0, c.z) + away * 3.0
	start.y = w.ground_at(start.x, start.z)
	var B: Hunter = m.hunters.filter(func(h): return h != P)[0]
	_park(P)
	_reset(B, start)
	B.ctrl = "bot"
	B.ai["tgt"] = null
	B.ai.erase("lift_plan")
	B.ai.erase("lift_ban")
	var top_y: float = rg["top"]
	var n0: int = m.air_rings.n
	var t := 0.0
	while t < BOT_LIFT_LIMIT_S and not (B.grounded and B.pos.y >= top_y - 0.05):
		B.ai["think"] = 1.0
		B.ai["goal"] = onto
		B.ai["goal_kind"] = "loot"
		m.step(Match.DT)
		t += Match.DT
	var took := m.air_rings.n > n0
	bot_lifts += 1 if took else 0
	var way := "by the ring" if took else "on foot, the quicker way"
	var what := "a bot below the lift at (%.0f, %.0f) stands on the %.1f m high ground" % [c.x, c.z, top_y]
	ok(B.grounded and B.pos.y >= top_y - 0.05, "%s in %.1f s (%s)" % [what, t, way])
	B.ctrl = "idle"
	_park(B)
