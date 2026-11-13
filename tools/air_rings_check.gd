extends RefCounted
## --air-rings-check: the Hollow Crown's air rings (scripts/match/air_rings.gd, docs/AIR_RINGS.md).
## The map lays its lanes and lift rings from content/maps/hollowcrown.json; every region has a ring;
## each lane is flown both ways by a hunter on scripted keys, through every ring, onto the far island,
## held at ring speed and well inside AIR_MAX_S; a bot takes a lane on its own crossing logic and plans
## each lane as its quickest way across (BotRoute, by time); a hop into each lift ring lands you on the
## high ground it serves, and a bot sent up there gets there quickly (by the ring when that is quicker).
## Hand-over (docs/AIR_RINGS.md "Hand-over"): a ring's exit speed goes into the glide, a dash and a wall kick by
## their own rules only (glide drag, Hunter.do_dash, WallMoves), the glider opened by a ring stays a press-only
## glider (Match gives the player glide_press_only). Never touches the save.

const AIR_MAX_S := 25.0         # s: the longest a lane may take (no empty runs past this)
const RING_GAP_S := 3.0         # s: the longest between two rings on a lane
const FLY_LIMIT_S := 30.0       # s: a flight that hasn't landed by now failed
const LIFT_LIMIT_S := 6.0       # s: a hop into a lift ring that isn't on top by now failed
const BOT_LIFT_LIMIT_S := 7.0   # s: a bot 3 m off a lift ring not on top by now was too slow (the ring takes ~5)
const HAND_S := 2.0             # s after the hold ends: the throw has bled back toward cruise (dashglide_2s_speed)
const HAND_SPEED := 6.5         # m/s, that row's bound
const HAND_1S_SPEED := 9.0      # m/s: a dash's speed one second into the glide it hands over to (dashglide_1s_speed)
const ALOFT := 25.0             # m up: the air rows start here over a flat spot (a high glide sinks ~3.5 m/s)
const WALL_UPS := 20            # terraces: the kick row's wall, far taller than any hop or mantle

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
	_handover()
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

# ---------------------------------------------------------------- hand-over
## A ring's exit speed hands into glide, dash and wall kick by their ordinary rules; nothing of the ring's own
## rides along past its hold. The throw is AirRings._boost on a ring stood where P is (lane -1: no lane height).
func _handover() -> void:
	var spot := _spot(12.0)
	var kit_was := P.arch
	P.unlock_all()      # (a point in the dash slot, or the press is gated: Hunter._gate)
	P.set_arch("")      # the class moves: core physics (a kit's own air dash is its combo check's job)
	_hand_glide(spot)
	_hand_dash(spot, "class")
	P.set_arch(kit_was)
	if kit_was != "":
		_hand_dash(spot, kit_was)      # the kit's path: DashFlow routes the presses round its dash
	P.set_arch("")
	_hand_kick(spot)
	P.set_arch(kit_was)

func _hv() -> Vector2:
	return Vector2(P.vel.x, P.vel.z)

func _held() -> bool:
	return m.air_rings._slip.has(P)

## A flat open spot (clear and level `r` m all round), the way --move-feel-check finds its own.
func _spot(r: float) -> Vector3:
	for k in 3000:
		var g: Vector3 = w.random_ground()
		var good := not w.is_void(g.x, g.z) and not w.is_block(g.x, g.z)
		for i in 16:
			var a := TAU * i / 16.0
			for d in [r * 0.33, r * 0.66, r]:
				var x: float = g.x + cos(a) * d
				var z: float = g.z + sin(a) * d
				if w.is_void(x, z) or w.is_block(x, z) or absf(w.ground_at(x, z) - g.y) > 0.01:
					good = false
		if good:
			return Vector3(floor(g.x) + 0.5, g.y, floor(g.z) + 0.5)
	return w.random_ground()

## P in the air `up` m over `spot`, falling with the glider shut, keys `dir`, the player's press-only glide.
func _aloft(spot: Vector3, up: float, dir: Vector2) -> void:
	_reset(P, spot + Vector3.UP * up)
	P.grounded = false
	P.air_t = 0.5
	P.last_gy = spot.y
	for f in ["roll_t", "ex_cd", "glide_cd", "wall_touch_t", "knock_t", "stun_t"]:
		P.set(f, 0.0)
	P.kb_t = -9.0
	P.dashes = P.max_dashes()
	P.air_dashed = false
	P.wall_hit_v = Vector2.ZERO
	P.wall_moves.land()
	P.inp["glide_press_only"] = true
	P.inp["move"] = dir
	m.step(Match.DT)

func _throw(dir: Vector2) -> void:
	var at: Vector3 = P.pos + Vector3.UP * AirRings.BODY_Y
	m.air_rings._boost(P, {"pos": at, "dir": dir, "lift": false, "lane": -1, "cd": {}})

## Steps `n` times with the keys `dir`, glide held if `glide`.
func _go(dir: Vector2, glide: bool, n: int) -> void:
	for i in n:
		P.inp["move"] = dir
		P.inp["glide"] = glide
		m.step(Match.DT)

## Glide: the ring opens a shut glider and holds ring speed for `hold`, then the glide's own drag takes the speed
## back toward cruise (the dash-into-glide bounds), never over Loco.glide_max; a fresh press takes the glider
## back from the ring and letting go then shuts it, and the hold goes with it (glide_press_only).
func _hand_glide(spot: Vector3) -> void:
	var dir := Vector2(1, 0)
	var hold := AirRings.r("hold")
	var ring := AirRings.r("speed")
	_aloft(spot, ALOFT, dir)
	ok(not P.gliding, "hand-over glide: the glider is shut before the ring (press-only, nothing pressed)")
	_throw(dir)
	m.step(Match.DT)
	ok(P.gliding and P.auto_glide, "hand-over glide: the ring opens the shut glider (auto, until a fresh press)")
	var peak := 0.0
	var late := 0.0
	_go(dir, false, int(round((hold - 0.1) / Match.DT)) - 1)
	late = _hv().length()
	ok(late >= ring - 0.5, "hand-over glide: at ring speed through the hold (%.1f m/s at %.1f s)" % [late, hold - 0.1])
	var t := hold - 0.1
	while t < hold + HAND_S - Match.DT * 0.5:
		_go(dir, false, 1)
		t += Match.DT
		peak = maxf(peak, _hv().length())
	var after := _hv().length()
	ok(P.gliding and not P.grounded, "hand-over glide: still gliding %.1f s after the hold" % HAND_S)
	ok(not _held(), "hand-over glide: the hold is over (%.1f s)" % t)
	ok(after <= HAND_SPEED,
		"hand-over glide: glide drag took the throw back to %.1f m/s %.0f s after the hold (bound %.1f)"
		% [after, HAND_S, HAND_SPEED])
	ok(peak <= Loco.glide_max + 0.01, "hand-over glide: never over the glide's max %.1f m/s (%.1f)"
		% [Loco.glide_max, peak])
	# a fresh press takes the glider back from the ring; let go and it shuts, hold and all
	_aloft(spot, ALOFT, dir)
	_throw(dir)
	_go(dir, false, 6)
	P.inp["jump"] = true
	_go(dir, true, 1)
	P.inp["jump"] = false
	_go(dir, true, 3)
	ok(P.gliding and not P.auto_glide and _held(),
		"hand-over glide: a fresh press takes the glider back, still held at ring speed (%.1f m/s)" % _hv().length())
	_go(dir, false, 2)
	ok(not P.gliding and not _held(),
		"hand-over glide: let go of the press and the glider shuts and the hold drops (press only)")

## Dash: pressed inside the hold the dash starts at its own speed and folds the glider, so the hold drops with it;
## as the dash ends the ring-opened glider comes back the same step (auto glide, as off a pad) at the dash's own
## velocity, and the glide's drag has it under the dash-into-glide bound a second on. Nothing re-applies ring speed.
func _hand_dash(spot: Vector3, who: String) -> void:
	var dir := Vector2(1, 0)
	var ring := AirRings.r("speed")
	_aloft(spot, ALOFT, dir)
	_throw(dir)
	_go(dir, false, 18)       # 0.3 s into the hold
	var pre := _hv().length()
	P.inp["dash"] = true
	_go(dir, false, 1)
	P.inp["dash"] = false
	var rolling := P.roll_t > 0.0
	if who != "class" and not rolling:
		ok(true, "hand-over dash (%s): n/a, the kit's air press is not a plain dash" % who)
		return
	ok(rolling, "hand-over dash (%s): a dash pressed inside the hold (%.1f m/s) starts" % [who, pre])
	ok(not P.gliding, "hand-over dash (%s): the dash folds the glider" % who)
	ok(not _held(), "hand-over dash (%s): and the ring's hold drops with it" % who)
	if who == "class":
		var ds := _hv().length()
		ok(absf(ds - P.roll_speed) < 0.1,
			"hand-over dash (%s): at the dash's own speed %.1f m/s, not the ring's %.1f" % [who, ds, ring])
	var dash_end := -1
	var reopen := -1
	var open_v := 0.0
	var v1 := 0.0
	for i in 150:
		var was_rolling := P.roll_t > 0.0
		_go(dir, false, 1)
		if dash_end < 0 and was_rolling and P.roll_t <= 0.0:
			dash_end = i
		if dash_end >= 0 and reopen < 0 and P.gliding:
			reopen = i - dash_end + 1
			open_v = _hv().length()
		if reopen >= 0 and i - (dash_end + reopen - 1) == 60:
			v1 = _hv().length()
	ok(dash_end >= 0, "hand-over dash (%s): the dash ends in the air" % who)
	ok(reopen == 1,
		"hand-over dash (%s): the ring-opened glider is back the step the dash ends (%d frames)" % [who, reopen])
	if who == "class":
		# (decision 0061: a dash hands over at run speed, in the air too, so the glider reopens there)
		ok(open_v <= maxf(P.run_speed, P.base_speed) + 0.1,
			"hand-over dash (%s): reopens at the dash's run-speed hand-over %.1f m/s (run %.1f, dash %.1f)"
			% [who, open_v, maxf(P.run_speed, P.base_speed), P.roll_speed])
	ok(v1 > 0.0 and v1 <= HAND_1S_SPEED,
		"hand-over dash (%s): a second on, glide drag has it at %.1f m/s (bound %.1f), no hold re-applied"
		% [who, v1, HAND_1S_SPEED])
	ok(not _held(), "hand-over dash (%s): no ring hold after the dash" % who)

## Wall kick: thrown head-on into a tall wall the stop eats the throw (no bounce head-on, WallMoves); a jump there
## kicks by the kick's own numbers: keys into the wall rise KICK_RISE, keys away push off at KICK_PUSH (the along-wall
## share is nil head-on), the glider shut for the rise and the hold gone.
func _hand_kick(spot: Vector3) -> void:
	var dir := Vector2(1, 0)
	var sx := int(floor(spot.x))
	var sz := int(floor(spot.z))
	for dz in range(-6, 7):
		for dx in range(9, 12):
			w.level[w.idx(sx + dx, sz + dz)] = int(round(spot.y / World.LEVEL)) + WALL_UPS
	for away in [false, true]:
		var keys := -dir if away else dir
		_aloft(spot + Vector3(-2.0, 0, 0), 3.0, dir)
		P.last_gy = spot.y + 2.5      # off a ledge 2.5 m up: the hop's climb cap is measured from the take-off
		_throw(dir)
		var n := 0
		while P.wall_touch_t <= 0.0 and not P.grounded and n < 90:
			_go(dir, false, 1)
			n += 1
		var label := "hand-over kick (keys %s)" % ("away" if away else "into")
		ok(P.wall_touch_t > 0.0 and not P.grounded,
			"%s: the throw meets the wall in the air (%.2f s, %.1f m up)" % [label, n * Match.DT, P.pos.y - spot.y])
		ok(P.wall_moves.bounce_t <= 0.0 and _hv().x > -2.0 and not _held(),
			"%s: head-on no bounce, the wall's own nudge off it (%.1f m/s), the hold over, not a ring throw back"
			% [label, _hv().x])
		var kicks0 := int(P.stats.get("wall_kicks", 0))
		var vy0 := maxf(P.vel.y, 0.0)
		P.inp["jump"] = true
		P.inp["move"] = keys
		P.inp["glide"] = false
		m.step(Match.DT)
		P.inp["jump"] = false
		ok(int(P.stats.get("wall_kicks", 0)) == kicks0 + 1, "%s: the press kicks" % label)
		if away:
			ok(absf(_hv().length() - WallMoves.KICK_PUSH) < 0.3,
				"%s: pushes off at the kick's %.1f m/s (%.1f): the ring's speed does not carry"
				% [label, WallMoves.KICK_PUSH, _hv().length()])
		else:
			var vy_kick := sqrt(2.0 * Hunter.H_GRAV * (vy0 * vy0 / (2.0 * Hunter.H_GRAV) + WallMoves.KICK_RISE))
			var vy_step := vy_kick - Hunter.H_GRAV * Match.DT      # one step of gravity on
			ok(absf(P.vel.y - vy_step) < 0.3,
				"%s: jumps at the kick's %.1f m/s (%.1f, a step on): KICK_RISE %.1f m, nothing of the ring's"
				% [label, vy_step, P.vel.y, WallMoves.KICK_RISE])
		_go(keys, false, 1)
		ok(not P.gliding and not _held(), "%s: glider shut for the rise and the hold gone" % label)
