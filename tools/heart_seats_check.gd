extends RefCounted
## --heart-seats-check: the Heart's two seats out (docs/decisions/0051-limited-ways-out.md, scripts/match/heart.gd).
##   1. the early seat: the Gate takes the carrier's squad within gate_take_r (a downed mate too), not a mate
##      farther off; minor pay; the state order ASLEEP > CHARGING > READY > CARRIED > WAITING > FINAL > DONE.
##   2. the final seat: the ring fills for a squad alone, a standing rival stalls it, an empty ring drains, full
##      takes that squad's Hunters in the ring with major pay and the islands fall end_after_final_s later.
##   3. the last squad standing: FINAL at once, filling rush_k faster.
##   4. Net: the host's "ht" events through JSON into a client game mirror the state and take its own Hunters.
## Every run asserts no edge was refused. Never touches the save.

var bad := 0
var rl: Dictionary

func ok(cond: bool, what: String) -> void:
	print("SEATS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## Steps the match with no monsters about (they spawn all match and would shove the Hunters out of the ring).
func _run(m: Match, secs: float) -> void:
	for i in int(secs / Match.DT):
		if i % 30 == 0:
			_calm(m)
		m.step(Match.DT)

func _calm(m: Match) -> void:
	for mb in m.mobs:
		if mb is Blight:
			(mb as Blight).burrow()
		else:
			mb.dead = true
			mb.visible = false

func _match(main: Node, seed_v: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": seed_v, "no_drop": true,
		"heart": true, "god": true})
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle"
	_calm(m)
	return m

func _put(m: Match, h: Hunter, p: Vector3) -> void:
	h.teleport(m.world.free_spot_near(p, [], 1.0, 0.45, 6.0))
	h.vel = Vector3.ZERO

## Into the Heart ring, k-th spot round it.
func _ring(m: Match, h: Hunter, k: int) -> void:
	var a := TAU * k / 6.0
	h.teleport(m.world.free_spot_near(m.heart.site + Vector3(cos(a), 0, sin(a)) * 2.5, [], 1.0, 0.45, 1.5))
	h.vel = Vector3.ZERO

func _squad(m: Match, team: int) -> Array:
	return m.hunters.filter(func(h): return h.team == team)

## Somewhere on solid ground well away from the Heart, its ring and its Gate.
func _far(m: Match, h: Hunter) -> void:
	var p := m.world.random_ground()
	while p.distance_to(m.heart.site) < 30.0 or p.distance_to(m.heart.gate) < 20.0:
		p = m.world.random_ground()
	h.teleport(p)
	h.vel = Vector3.ZERO

## Runs a match's clock to this session time.
func _to(m: Match, t: float) -> void:
	m.time = t - m.sess_t0
	m.step(Match.DT)

## Wakes the Heart and charges its Heartspark.
func _charged(m: Match) -> void:
	_to(m, float(rl["wake_s"]))
	_run(m, float(rl["charge_s"]) + 0.5)

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	rl = Heart.rules()
	_early(main)
	_final(main)
	_rush(main)
	_net(main)
	print("SEATS DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

# ------------------------------------------------------------------ 1. the early seat and the state order
func _early(main: Node) -> void:
	var m := _match(main, 8101)
	var H: Heart = m.heart
	for h in m.hunters:
		_far(m, h)
	_charged(m)
	var p: Hunter = m.player
	var mates := _squad(m, p.team)
	var near: Hunter = mates[1] if mates[0] == p else mates[0]
	_put(m, p, H.site + Vector3(1, 0, 0))
	H._pick(p)
	ok(H.carrier == p, "(setup) the player carries the Heartspark")
	_put(m, p, H.gate)
	_put(m, near, H.gate + Vector3(float(rl["gate_take_r"]) - 2.5, 0, 0))
	m.knock(near, null, {})
	var gems0 := p.gems
	H._gate_done(p)
	ok(p.extracted and String(m.result.get("how", "")) == Heart.HOW_EARLY, "the carrier leaves by the Gate")
	ok(near.extracted, "a downed squadmate %.1f m from the Gate leaves too" % near.flat_dist(H.gate))
	ok(p.gems == gems0 + int(rl["reward"]["minor"]["gems"]), "minor pay")
	ok(H.state == Heart.S.WAITING and H.early_team == p.team, "the early seat is used: WAITING")
	var m2 := _match(main, 8102)
	var H2: Heart = m2.heart
	for h in m2.hunters:
		_far(m2, h)
	_charged(m2)
	var p2: Hunter = m2.player
	var mates2 := _squad(m2, p2.team)
	var far2: Hunter = mates2[1] if mates2[0] == p2 else mates2[0]
	_put(m2, p2, H2.site + Vector3(1, 0, 0))
	H2._pick(p2)
	_put(m2, p2, H2.gate)
	_put(m2, far2, H2.gate + Vector3(float(rl["gate_take_r"]) + 4.0, 0, 0))
	H2._gate_done(p2)
	ok(p2.extracted and not far2.extracted, "a squadmate past %.0f m stays in the match" % float(rl["gate_take_r"]))
	m2.queue_free()
	# the rest of the order on the first match: WAITING > FINAL at final_s > DONE when the ring fills
	var rival: Hunter = m.hunters.filter(func(h): return h.team != p.team)[0]
	_to(m, float(rl["final_s"]) + 0.1)
	ok(H.state == Heart.S.FINAL, "the Heart opens at %.0f s" % float(rl["final_s"]))
	_ring(m, rival, 0)
	_run(m, float(rl["final_hold_s"]) + 1.0)
	ok(H.state == Heart.S.DONE and rival.extracted, "a lone Hunter fills the ring: DONE")
	var order := H.trail.map(func(l): return String(l).split(" ", false)[1])
	var want := ["ASLEEP>CHARGING", "CHARGING>READY", "READY>CARRIED", "CARRIED>WAITING", "WAITING>FINAL", "FINAL>DONE"]
	ok(order == want, "state order %s" % ", ".join(order))
	ok(not H.go(Heart.S.CHARGING, "test") and H.state == Heart.S.DONE and H.refused == 1,
		"an edge the table lacks is refused, not applied")
	m.queue_free()

# ------------------------------------------------------------------ 2. the final seat
func _final(main: Node) -> void:
	var m := _match(main, 8103)
	var H: Heart = m.heart
	for h in m.hunters:
		_far(m, h)
	_charged(m)
	_to(m, float(rl["final_s"]) + 0.1)
	ok(H.state == Heart.S.FINAL, "at %.0f s the final seat opens" % float(rl["final_s"]))
	ok(H.spark_live() and H.early_team < 0, "an unused early seat stays open in FINAL")
	var a: Array = _squad(m, 0)
	var b: Array = _squad(m, 1)
	for h in a:
		_ring(m, h, a.find(h))
	ok(a.all(func(h): return H.in_ring(h)), "(setup) the squad stands in the ring")
	_run(m, 3.0)
	var two := H.final_prog
	ok(H.final_team == 0 and two > 0.0, "a squad alone in the ring fills it (%.0f%% in 3 s)" % (two * 100.0))
	var one_rate := 3.0 / float(rl["final_hold_s"])
	ok(two > one_rate * 1.2, "two of them fill it faster than one (Exits.crew_rate)")
	_ring(m, b[0], 2)
	ok(H.in_ring(b[0]), "(setup) a rival steps in")
	for i in 8:      # (held in place: the squad's Boki knock a rival about)
		_ring(m, b[0], 2)
		_run(m, 0.25)
	ok(absf(H.final_prog - two) < 0.01, "a standing rival in the ring stalls it")
	m.knock(b[0], null, {})
	_ring(m, b[0], 2)
	_run(m, 1.0)
	ok(H.final_prog > two, "a downed rival doesn't")
	_far(m, b[0])
	for h in a:
		_far(m, h)
	var held := H.final_prog
	_run(m, 1.0)
	ok(H.final_prog < held and H.final_team == 0, "an empty ring drains")
	for h in a:
		_ring(m, h, a.find(h))
	_run(m, float(rl["final_hold_s"]) * (1.0 - H.final_prog) / Exits.crew_rate(2) - 0.5)
	m.knock(a[1], null, {})
	_run(m, 2.0)
	ok(H.state == Heart.S.DONE, "full: the final seat fires")
	ok(a.all(func(h): return h.extracted), "the squad in the ring leaves, the downed one too")
	ok(not b[0].extracted and not b[1].extracted, "the rival squad stays")
	ok(String(m.result.get("how", "")) == Heart.HOW_FINAL or m.player.team != 0, "...by the Heart ring")
	var after := float(rl["end_after_final_s"])
	ok(m.length <= m.time + after + 0.01, "the islands fall %.0f s later" % after)
	ok(H.refused == 0, "no refused edges")
	m.queue_free()

# ------------------------------------------------------------------ 3. the last squad standing
func _rush(main: Node) -> void:
	var m := _match(main, 8104)
	var H: Heart = m.heart
	for h in m.hunters:
		_far(m, h)
	_to(m, 30.0)
	ok(H.state == Heart.S.ASLEEP, "(setup) early in the match the Heart sleeps")
	for h in m.hunters:
		if h.team != 0:
			h.out = true
	m._check_last()
	ok(H.state == Heart.S.FINAL and H.rush, "the last squad: the final seat opens at once")
	var a: Array = _squad(m, 0)
	_ring(m, a[0], 0)
	_run(m, 2.0)
	var want := 2.0 / float(rl["final_hold_s"]) * float(rl["rush_k"])
	ok(absf(H.final_prog - want) < 0.05, "...and fills %.0fx faster (%.2f)" % [float(rl["rush_k"]), H.final_prog])
	ok(H.refused == 0, "no refused edges")
	m.queue_free()

# ------------------------------------------------------------------ 4. Net round trip
func _net(main: Node) -> void:
	var host := _match(main, 8105)
	var cli := _match(main, 8105)
	var H: Heart = host.heart
	var C: Heart = cli.heart
	cli.net_on = true
	cli.is_host = false
	host.net_on = true
	Net.out_events.clear()
	for mm in [host, cli]:
		for h in mm.hunters:
			_far(mm, h)
	_charged(host)
	cli.time = host.time
	var p: Hunter = host.player
	_put(host, p, H.site + Vector3(1, 0, 0))
	H._pick(p)
	_put(host, p, H.gate)
	var cp: Hunter = cli.ents_by_id.get(p.nid, null) as Hunter
	ok(cp != null, "(setup) the client has the same Hunter")
	_put(cli, cp, C.gate)
	H._gate_done(p)
	var evs: Array = Net.out_events.filter(func(e): return e[0] == "ht")
	ok(evs.any(func(e): return e[1] == "take" and e[2] == Heart.HOW_EARLY), "the host sends the seat it fired")
	for e in evs:
		C.net_in(JSON.parse_string(JSON.stringify(e)))
	ok(C.state == Heart.S.WAITING and C.early_team == p.team, "the client mirrors WAITING and the squad")
	ok(cp.extracted and String(cli.result.get("how", "")) == Heart.HOW_EARLY, "the client takes its own Hunter")
	ok(C.charge == H.charge and C.spark_pos.is_equal_approx(H.spark_pos), "charge and spark place match")
	var sent := Net.out_events.size()
	C.act("pick", cp)
	ok(Net.out_events.size() == sent + 1 and Net.out_events[-1][1] == "pick", "a client asks the host to pick")
	for mm in [host, cli]:
		mm.net_on = false
		mm.queue_free()
	Net.out_events.clear()
