class_name BlightNests
## Blight nests (docs/decisions/0061-blight-nests.md, docs/SPAWNS.md): the only place Skitters come
## from. Fixed spots picked from the match seed and the world alone, so every client places them the
## same; each holds a fixed stock. Something wakes a nest (a hunter walking up, a loud noise, a hit,
## a Warden's shriek, the tide on its clock): it pulses and hisses for warn_s, then what it holds
## climbs out. An empty nest stays empty for cooldown_s, and breaking one pays gems, a gear roll
## (content/rules/gear.json "bl_nest") and XP. Numbers: content/rules/blight_nests.json.
## The nest is a Blight body ("bl_nest") on the host: its snapshot carries spot (how close it is to
## opening, 0..1) and cone_a (the share of its stock left), so clients draw the pulse with no new
## fields; the "nest" event carries stock and the refill clock for the map (NestMap).

const POP_XP_R := 14.0

var dir: BlightDir
var m: Match
var R: Dictionary
## {pos, island, full, stock, refill_at (INF unless empty), stir_at (INF unless stirring), waker, mob}
var list: Array = []
var released := 0  # Skitters that climbed out of a nest (for checks)
var _tick_t := 0.0
var _tide_k := -1


func _init(d: BlightDir) -> void:
	dir = d
	m = d.m
	R = Content.rules("blight_nests")


func rule(k: String) -> float:
	return float(R.get(k, 0.0))


# ------------------------------------------------------------------ placement (every peer)
## Pick the spots: per island by its danger, on roomy open ground, apart from each other and clear
## of camps, exits, Warden posts, drop spots and lairs. Only the seed and the world decide.
func place() -> void:
	list.clear()
	var w := m.world
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(m.seed_val), "nests"])
	var per: Array = R.get("per_island", [1, 1, 2])
	var stock: Array = R.get("stock", [6, 7, 8])
	var gap := rule("space_m")
	for ii in w.islands.size():
		var dg := dir.island_danger(ii)
		for _n in int(per[dg]):
			var at := _spot(ii, r, gap)
			if at == Vector3.INF:
				break
			var full := int(stock[dg])
			list.append(
				{
					"pos": at,
					"island": ii,
					"full": full,
					"stock": full,
					"refill_at": INF,
					"stir_at": INF,
					"waker": at,
					"mob": null
				}
			)


func _spot(ii: int, r: RandomNumberGenerator, gap: float) -> Vector3:
	var w := m.world
	var avoid: Array = (
		w.camp_spots.map(func(c): return c["pos"]) + w.spawns + w.warden_posts.map(func(c): return c["pos"])
	)
	if m.exits:
		avoid += m.exits.list.map(func(x): return x["pos"])
	for _t in 60:
		var p := dir._rand_ground(ii, r)
		if p == Vector3.INF or w.is_void(p.x, p.z) or w.is_block(p.x, p.z) or w.in_bush(p.x, p.z):
			continue
		if not w.roomy(int(p.x), int(p.z), 30):
			continue
		if dir._near_any(p, avoid, 9.0) or dir._near_any(p, list.map(func(n): return n["pos"]), gap):
			continue
		if m.lairs and not m.lairs.lair_of(p, 6.0).is_empty():
			continue
		var q := w.free_spot_near(p, [], 1.0, 0.9, 3.0)
		return Vector3(q.x, w.ground_at(q.x, q.z), q.z)
	return Vector3.INF


## The host puts the nest bodies down.
func populate() -> void:
	for n in list:
		_grow(n)


func _grow(n: Dictionary) -> void:
	var b := dir.spawn("bl_nest", n["pos"], dir.level_here(n["pos"]))
	b.pos = n["pos"]
	b.post = n["pos"]
	b.cone_a = 1.0
	b.set_meta("nest", list.find(n))
	n["mob"] = b


func at_index(i: int) -> Dictionary:
	return list[i] if i >= 0 and i < list.size() else {}


func nest_of(b: Ent) -> Dictionary:
	return at_index(int(b.get_meta("nest", -1))) if b else {}


## Ready to wake: standing (on the host), something in it, not cooling, not already stirring.
func ready(n: Dictionary) -> bool:
	if dir.host and (n["mob"] == null or (n["mob"] as Blight).dead):
		return false
	return int(n["stock"]) > 0 and n["refill_at"] == INF and n["stir_at"] == INF


func cooling(n: Dictionary) -> bool:
	return n["refill_at"] != INF


# ------------------------------------------------------------------ waking (host)
## Stir a nest: it pulses and hisses for warn_s, then what it holds climbs out toward `at`.
func wake(n: Dictionary, at: Vector3) -> void:
	if not dir.host or not ready(n):
		return
	n["stir_at"] = m.time + rule("warn_s")
	n["waker"] = at
	_cue(n)
	_send(n)


func _cue(n: Dictionary) -> void:
	m.sfx("v_skitter", n["pos"], -4.0, 0.42)
	m.sfx("thump", n["pos"], -10.0, 0.6)
	m.fx.ring(n["pos"], 2.2, BlightModels.EMBER, rule("warn_s"))
	m.blight_ping(n["pos"])


func on_noise(at: Vector3, loud: float) -> void:
	if loud < 12.0:
		return  # footsteps and dashes don't carry to a nest; shots, blasts and chests do
	for n in list:
		if ready(n) and Vector2(at.x - n["pos"].x, at.z - n["pos"].z).length() < loud * rule("noise_k"):
			wake(n, at)


## A Warden shrieked: nests near it give up what they hold. It never makes Skitters of its own.
func on_shriek(from: Vector3, toward: Vector3) -> void:
	for n in list:
		if ready(n) and Vector2(from.x - n["pos"].x, from.z - n["pos"].z).length() < rule("shriek_r"):
			wake(n, toward)


func on_hurt(b: Blight, by: Ent) -> void:
	var n := nest_of(b)
	if not n.is_empty():
		wake(n, by.pos if by else b.pos)


## Broken: gems and the gear roll come from Match.on_mob_dead; XP to the breaking squad close by.
## It stays empty for the cooldown, so the ground round it is quiet.
func on_popped(b: Blight, by: Ent) -> void:
	var n := nest_of(b)
	if n.is_empty() or not dir.host:
		return
	n["stock"] = 0
	n["stir_at"] = INF
	if not cooling(n):
		n["refill_at"] = m.time + rule("cooldown_s")
	var credit: Ent = by.owner_h if by is Kin and (by as Kin).owner_h else by
	if credit is Hunter:
		for h in m.hunters:
			if h.team == (credit as Hunter).team and not h.out and h.flat_dist(b) < POP_XP_R:
				h.gain_xp(rule("pop_xp"))
		if m.player and (credit as Hunter).team == m.player.team:
			m.add_feed("Nest broken · quiet for %d:00" % int(rule("cooldown_s") / 60.0))
	m.fx.ring(b.pos, 3.0, BlightModels.EMBER_HOT, 0.6)
	_send(n)


## An idle Skitter far from everyone goes home: back into its nest's stock unless that's cooling.
func home(s: Blight) -> void:
	var n := nest_of(s)
	if not n.is_empty() and not cooling(n) and n["mob"] != null and not (n["mob"] as Blight).dead:
		n["stock"] = mini(int(n["full"]), int(n["stock"]) + 1)
		_send(n)


func tick(dt: float) -> void:
	for n in list:
		var b: Blight = n["mob"]
		if b and not b.dead:
			b.spot = (
				0.0
				if n["stir_at"] == INF
				else clampf(1.0 - (float(n["stir_at"]) - m.time) / maxf(0.1, rule("warn_s")), 0.0, 1.0)
			)
			b.cone_a = float(n["stock"]) / maxf(1.0, float(n["full"]))
	_tick_t -= dt
	if _tick_t > 0.0:
		return
	_tick_t = 0.25
	for n in list:
		if n["stir_at"] != INF and m.time >= float(n["stir_at"]):
			_release(n)
		elif cooling(n) and m.time >= float(n["refill_at"]):
			_refill(n)
		elif ready(n):
			for h in m.hunters:
				if _wakes(n, h):
					wake(n, h.pos)
					break
	_tide()


func _wakes(n: Dictionary, h: Hunter) -> bool:
	var p: Vector3 = n["pos"]
	if not h.targetable() or h.out or h.extracted or absf(h.pos.y - p.y) > 3.0 or h.flat_dist(p) > rule("wake_r"):
		return false
	return m.world.los(p, h.pos, p.y + 0.7)


## The tide (Heart): on its clock, each squad out past the ring stirs the nearest stocked nest.
func _tide() -> void:
	if m.heart == null or rule("tide_s") <= 0.0:
		return
	var k := int(m.time / rule("tide_s"))
	if k == _tide_k:
		return
	_tide_k = k
	var sq := dir._squads()
	for team in sq:
		var anchor: Hunter = sq[team][0]
		if Heart.tide_out(m, anchor.pos) <= 0.0 or dir.squad_time(team) < BlightDir.GRACE:
			continue
		var best := {}
		var bd := rule("tide_r")
		for n in list:
			var d: float = anchor.flat_dist(n["pos"])
			if ready(n) and d < bd:
				bd = d
				best = n
		if not best.is_empty():
			wake(best, anchor.pos)


## Out they come, on fixed spots round the nest: as many as it holds, within the area cap.
func _release(n: Dictionary) -> void:
	n["stir_at"] = INF
	if n["mob"] == null or (n["mob"] as Blight).dead:
		_send(n)
		return
	var p: Vector3 = n["pos"]
	var near := 0
	for b in m.mobs:
		if b is Blight and not b.dead and b.mkind == "bl_skitter" and b.flat_dist(p) < rule("area_r"):
			near += 1
	var k := mini(int(n["stock"]), mini(int(rule("area_cap")) - near, dir.cap() - dir.skitters_alive()))
	var i := list.find(n)
	var l := dir.level_here(p)
	for j in maxi(0, k):
		var a := TAU * float(j) / float(k) + float(i) * 0.7
		var q := p + Vector3(cos(a), 0, sin(a)) * 1.5
		if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z):
			q = p
		var s := dir.spawn("bl_skitter", Vector3(q.x, m.world.ground_at(q.x, q.z), q.z), l)
		s.set_meta("nest", i)
		s.hear(n["waker"], 20.0)
		released += 1
	if k > 0:
		n["stock"] = int(n["stock"]) - k
		m.fx.dust(p, 14)
		m.sfx("v_skitter", p, -6.0, 0.55)
	if int(n["stock"]) <= 0:
		n["refill_at"] = m.time + rule("cooldown_s")
	_send(n)


func _refill(n: Dictionary) -> void:
	n["refill_at"] = INF
	n["stock"] = int(n["full"])
	if n["mob"] == null or (n["mob"] as Blight).dead:
		_grow(n)
	_send(n)


# ------------------------------------------------------------------ net
func _send(n: Dictionary) -> void:
	if m.net_on and dir.host:
		var left := float(n["refill_at"]) - m.time if cooling(n) else -1.0
		m.net_event(["nest", list.find(n), int(n["stock"]), snappedf(left, 0.1), 1 if n["stir_at"] != INF else 0])


## A client hears a nest change (Match._net_ev "nest").
func net(x: Array) -> void:
	var n := at_index(int(x[1]))
	if n.is_empty():
		return
	n["stock"] = int(x[2])
	n["refill_at"] = m.time + float(x[3]) if float(x[3]) >= 0.0 else INF
	var stir := int(x[4]) == 1
	if stir and n["stir_at"] == INF:
		_cue(n)
	n["stir_at"] = m.time + rule("warn_s") if stir else INF


## Seconds until a cooling nest fills again (0 when it isn't cooling).
func refill_left(n: Dictionary) -> float:
	return maxf(0.0, float(n["refill_at"]) - m.time) if cooling(n) else 0.0

# ------------------------------------------------------------------ the demo (--blight-demo=nest)
var _d := {}

## A recorded beat for the decision's MP4: walk up to a nest, it stirs, its Skitters climb out, you
## clear them and break it (gems, XP, the feed line), then walk round it while it stays quiet.
func demo() -> void:
	var P := m.player
	P.hp = P.max_hp
	if _d.is_empty() and not _demo_setup(P):
		return
	var n: Dictionary = _d["n"]
	var nest: Blight = n["mob"]
	var t := m.time - float(_d["t0"])
	P.inp["move"] = Vector2.ZERO
	P.inp["fire"] = false
	var tgt: Blight = null
	for b in m.mobs:
		if b is Blight and not b.dead and b.mkind == "bl_skitter":
			b.cd = maxf(b.cd, 1.0)          # (they swarm and circle, but hold the bite for the shot)
			if b.flat_dist(P) < 3.0:
				var back := -b.dir_to(P) * (3.0 - b.flat_dist(P))
				b.pos += Vector3(back.x, 0, back.y)
			if tgt == null or P.flat_dist(b) < P.flat_dist(tgt):
				tgt = b
	match String(_d["ph"]):
		"walk":
			var to := Vector3(n["pos"]) - P.pos
			P.inp["move"] = Vector2(to.x, to.z).normalized()
			P.inp["aim"] = Vector3(n["pos"]) + Vector3(0, 0.5, 0)
			if n["stir_at"] != INF or t > 8.0:
				_d["ph"] = "fight"
		"fight":
			P.inp["aim"] = (tgt.pos if tgt else Vector3(n["pos"])) + Vector3(0, 0.5, 0)
			if tgt:
				P.inp["fire"] = true
				if tgt != _d.get("tgt"):
					_d["tgt"] = tgt; _d["tgt_t"] = m.time
				elif m.time - float(_d["tgt_t"]) > 0.9:
					tgt.hurt(9999.0, P, {})      # (a backstop so the clip keeps time with any kit)
			elif int(n["stock"]) <= 0 and n["stir_at"] == INF:
				_d["ph"] = "pop"; _d["pop_t"] = m.time
		"pop":
			P.inp["aim"] = Vector3(n["pos"]) + Vector3(0, 0.5, 0)
			P.inp["fire"] = true
			if nest and not nest.dead and m.time - float(_d["pop_t"]) > 2.5:
				nest.hurt(9999.0, P, {})
			if nest == null or nest.dead:
				_d["ph"] = "quiet"; _d["q_t"] = m.time
		"quiet":
			var a := (m.time - float(_d["q_t"])) * 0.5
			var goal := Vector3(n["pos"]) + Vector3(cos(a), 0, sin(a)) * 5.0
			var to2 := goal - P.pos
			P.inp["move"] = Vector2(to2.x, to2.z).normalized() if to2.length() > 0.6 else Vector2.ZERO
			P.inp["aim"] = Vector3(n["pos"]) + Vector3(0, 0.5, 0)

func _demo_setup(P: Hunter) -> bool:
	Settings.v["tips"] = false
	if m.hud:
		m.hud.guide_hidden = true
	var best := {}
	var stand := Vector3.INF
	var bd := INF
	for n in list:
		if n["mob"] == null or (n["mob"] as Blight).dead:
			continue
		for k in 12:
			var a := TAU * k / 12.0
			var q := m.world.free_spot_near(Vector3(n["pos"]) + Vector3(cos(a), 0, sin(a)) * 13.0, [n["pos"]], 1.0, 0.45, 1.5)
			var d := P.flat_dist(n["pos"])
			if absf(q.y - n["pos"].y) < 1.0 and m.world.los(n["pos"], q, n["pos"].y + 0.7) and d < bd:
				bd = d; best = n; stand = q
				break
	if best.is_empty():
		return false
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
	for b in m.mobs:
		if b.flat_dist(best["pos"]) < 40.0 and not (b is Blight and b.mkind == "bl_nest"):
			if b is Blight:
				(b as Blight).burrow()
			else:
				b.dead = true; b.visible = false
	P.teleport(stand)
	_d = {"t0": m.time, "n": best, "ph": "walk"}
	return true
