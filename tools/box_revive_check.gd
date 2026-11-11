extends RefCounted
## --box-revive-check: box revives and revive beacons (docs/decisions/0018, owner items 101 / 101b).
##  1. A box revive takes BoxRevive.time_for (7.5 s the first time, from content/rules/revive.json);
##     the teammate comes back at the box with their Boki; the box hums while it's channelled.
##  2. While channelling a hit does Hunter.CONSUME_VULN times the damage (the tonic's multiplier) and
##     breaks it; holding on does nothing until interact is let go and held again.
##  3. Walking breaks it; fire is held off while channelling.
##  4. The second box revive of the same Hunter is slower (the diminishing curve).
##  5. A beacon brings back every dead teammate at once; while it's lit every player is told
##     (toast + map/world marker state) and its hum carries beacon_hear_m; "bcn" events from another
##     game light it, put it out and use it.
##  6. A bot walks to a dead teammate's box and brings them back with the new timing; with the soul
##     gone it lights a beacon instead.
## Never touches the save.

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("RVCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(sec: float) -> void:
	var t := 0.0
	while t < sec:
		m.step(Match.DT)
		t += Match.DT

func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(at)
	h.vel = Vector3.ZERO

func _calm(h: Hunter) -> void:
	h.inv_t = 0.0
	h.armor = 0.0
	h.shield = 0.0
	h.kin_shield = 0.0
	h.hp = h.max_hp

## Open, flat ground with room round it, away from the beacons.
func _roomy() -> Vector3:
	for k in 3000:
		var g := m.world.random_ground()
		var flat := true
		for dx in range(-8, 9, 2):
			for dz in range(-8, 9, 2):
				if m.world.is_void(g.x + dx, g.z + dz) or absf(m.world.ground_at(g.x + dx, g.z + dz) - g.y) > 0.3:
					flat = false
		if flat and m.beacons.all(func(bc): return g.distance_to(bc["pos"]) > 12.0):
			return g
	return m.world.random_ground()

## Holds interact at a box until the owner is back or the time runs out; returns the seconds taken.
func _channel(C: Hunter, B: Hunter, cap: float) -> float:
	C.inp["interact"] = true
	var t0 := m.time
	while B.out and m.time - t0 < cap:
		_run(Match.DT)
	C.inp["interact"] = false
	_run(Match.DT * 2.0)
	return m.time - t0

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for k in m.kins.filter(func(x): return x.team == -1):
		k.queue_free()
		m.kins.erase(k)
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.lives = 1
	var mine: Array = m.hunters.filter(func(x): return x.team == m.player.team)
	var foe: Hunter = m.hunters.filter(func(x): return x.team != m.player.team)[0]
	var A: Hunter = mine[0]
	var B: Hunter = mine[1]
	var C: Hunter = mine[2]
	var home := _roomy()
	for h in m.hunters:
		if h.team != A.team: _spot(h, m.world.random_ground())
	_spot(foe, home + Vector3(30, 0, 0))
	_spot(A, home + Vector3(-6, 0, 0))
	_spot(C, home)
	ok(m.beacons.size() >= 3, "several beacons on the map (%d)" % m.beacons.size())
	_box_revive(B, C)
	_hits(B, C, foe)
	_moves(B, C)
	_beacon(A, B, C, foe)
	_bot(B, C, home)
	print("BOX REVIVE CHECK DONE, failures: ", bad)
	main.get_tree().quit()

func _box_revive(B: Hunter, C: Hunter) -> void:
	var home := C.pos
	_spot(B, home + Vector3(3, 0, 0))
	m.eliminate(B, null, "finished")
	var bx := Life.box_of(m, B)
	ok(B.out and not bx.is_empty() and Life.soul_here(m, bx), "a fallen teammate leaves a box with their soul in it")
	ok(absf(float(BoxRevive.rules()["box_revive_s"]) - 7.5) < 0.01 and absf(BoxRevive.time_for(B) - 7.5) < 0.01,
		"a box revive is a 7.5 s channel the first time (%.2fs)" % BoxRevive.time_for(B))
	var ring: Node = (bx["node"] as Node).get_node_or_null("OwnerRing")
	ok(ring != null and Life.owner_col(m, bx) == m.mate_col(B), "an ally box wears its owner's squad colour")
	_spot(C, bx["pos"] + Vector3(0.4, 0, 0))
	var t0 := m.time
	C.inp["interact"] = true
	_run(BoxRevive.time_for(B) * 0.5)
	var hum := String(bx.get("hum_key", ""))
	ok(C.box_reviving() and hum != "" and Sfx.loop_on(hum), "mid-channel: kneeling over the box, and it hums")
	var prog := float(bx.get("rev_prog", 0.0))
	ok(absf(prog - 0.5) < 0.05, "the progress ring reads half way (%.2f)" % prog)
	C.inp["fire"] = true
	_run(Match.DT)
	ok(not C.inp["fire"] and C.box_reviving(), "no firing while channelling, and the channel goes on")
	_channel(C, B, 10.0)
	var took := m.time - t0 - Match.DT * 2.0
	ok(not B.out and absf(took - 7.5) < 0.15, "the teammate is back after %.2fs (want 7.5s)" % took)
	ok(B.pos.distance_to(bx["pos"]) < 3.0, "back at their box (%.1fm away)" % B.pos.distance_to(bx["pos"]))
	var k: Kin = B.kin
	ok(k != null and not k.dead and k.state == "active" and k.flat_dist(B) < 3.0, "their Boki is back at their side")
	ok(not Sfx.loop_on(hum), "the hum stops once it's done")

func _hits(B: Hunter, C: Hunter, foe: Hunter) -> void:
	var second := BoxRevive.time_for(B)
	ok(absf(second - 7.5 / 0.75) < 0.05, "the second box revive of a Hunter is slower (%.2fs)" % second)
	_calm(C)
	var h0 := C.hp
	C.hurt(10.0, foe, {"src": "abil"})
	var plain := h0 - C.hp
	_spot(B, C.pos + Vector3(2.5, 0, 0))
	m.eliminate(B, null, "finished")
	var bx := Life.box_of(m, B)
	_spot(C, bx["pos"] + Vector3(0.4, 0, 0))
	_calm(C)
	C.inp["interact"] = true
	_run(1.5)
	ok(C.box_reviving() and C.box_t > 1.0, "channelling again")
	var h1 := C.hp
	C.hurt(10.0, foe, {"src": "abil"})
	var while_rev := h1 - C.hp
	ok(plain > 0.0 and absf(while_rev / plain - Hunter.CONSUME_VULN) < 0.02,
		"a hit while channelling does %.2fx (the tonic's %.2fx)" % [while_rev / maxf(plain, 0.001),
		Hunter.CONSUME_VULN])
	_run(Match.DT)
	ok(C.box_t == 0.0 and B.out, "and the hit breaks the channel")
	_run(1.0)
	ok(C.box_t == 0.0 and not C.box_reviving(), "holding on does nothing until interact is pressed again")
	C.inp["interact"] = false
	_run(Match.DT * 2.0)
	var need := BoxRevive.time_for(B)
	var took := _channel(C, B, 15.0) - Match.DT * 2.0
	ok(not B.out and absf(took - need) < 0.15,
		"pressed again it starts over and takes the full %.1fs (%.2fs)" % [need, took])

func _moves(B: Hunter, C: Hunter) -> void:
	_spot(B, C.pos + Vector3(2.5, 0, 0))
	m.eliminate(B, null, "finished")
	var bx := Life.box_of(m, B)
	_spot(C, bx["pos"] + Vector3(0.4, 0, 0))
	C.inp["interact"] = true
	_run(1.0)
	ok(C.box_reviving(), "channelling a third time")
	C.inp["move"] = Vector2(1, 0)
	_run(Match.DT * 2.0)
	ok(C.box_t == 0.0 and not C.box_reviving() and B.out, "walking breaks the channel")
	C.inp["move"] = Vector2.ZERO
	C.inp["interact"] = false
	_run(Match.DT * 2.0)

func _beacon(A: Hunter, B: Hunter, C: Hunter, foe: Hunter) -> void:
	m.eliminate(C, null, "finished")
	ok(B.out and C.out and not A.out, "two of the squad are dead")
	var bc: Dictionary = m.beacons[0]
	var i := 0
	var key := "beacon0"
	# another game's Hunter lights it, then steps off: the notice comes and goes here too
	Beacons.net_in(m, ["bcn", i, foe.team, "lit"])
	ok(bc["lit"] and Beacons.lit(m).has(bc) and Sfx.loop_on(key), "a \"bcn\" lit event lights it here, hum and all")
	Beacons.net_in(m, ["bcn", i, foe.team, "out"])
	ok(not bc["lit"] and not Sfx.loop_on(key), "and \"out\" puts it out")
	# every player is told: a teammate's view and a rival's
	for viewer in [A, foe]:
		m.player = viewer
		m.hud.msgs.clear()
		_spot(A, bc["pos"])
		_run(Match.DT * 2.0)
		var told: bool = m.hud.msgs.texts().any(func(t): return t.contains("eacon"))
		var side := "ally" if viewer.team == A.team else "rival"
		ok(bc["lit"] and told, "%s (%s) gets the beacon notice" % [viewer.pname, side])
		_spot(A, bc["pos"] + Vector3(12, 0, 0))
		_run(Match.DT * 2.0)
	m.player = A
	ok(not bc["lit"], "stepping off puts it out")
	_spot(A, bc["pos"])
	_run(Match.DT * 3.0)
	var reach := float(Sfx.loops.get(key, {}).get("reach", 0.0))
	ok(Sfx.loop_on(key) and absf(reach - float(BoxRevive.rules()["beacon_hear_m"])) < 0.1,
		"while it's lit its hum carries %.0fm" % reach)
	ok(m.pings.any(func(p): return p["pos"] == bc["pos"]), "and it's marked on everyone's map")
	var t0 := m.time
	while (B.out or C.out) and m.time - t0 < Beacons.time_s() + 2.0:
		_run(Match.DT)
	var took := m.time - t0
	ok(not B.out and not C.out and absf(took - Beacons.time_s()) < 0.3,
		"the beacon brings back both dead teammates at once after %.1fs (want %.1fs)" % [took, Beacons.time_s()])
	ok(bc["used"] and not bc["lit"] and not Sfx.loop_on(key), "single use, and quiet again")
	ok(B.sick_t > 0.0 and C.sick_t > 0.0, "with resurrection sickness")
	# a "used" event from another game brings back the dead Hunters this game owns
	var bc2: Dictionary = m.beacons[1]
	m.eliminate(B, null, "finished")
	Beacons.net_in(m, ["bcn", 1, B.team, "used"])
	ok(not B.out and bc2["used"], "a \"used\" event brings back this game's dead teammates")

func _bot(B: Hunter, C: Hunter, home: Vector3) -> void:
	for h in m.hunters:
		if h.team != B.team:
			var far := m.world.random_ground()
			for k in 200:
				if far.distance_to(home) > 70.0: break
				far = m.world.random_ground()
			_spot(h, far)
	_calm(C)
	_spot(B, home)
	_spot(C, home + Vector3(6, 0, 2))
	_run(0.5)
	m.eliminate(B, null, "finished")
	C.ctrl = "bot"
	C.ai = m.bot_brain.new_mind(m.rng, 0.6, m.bot_cfg)
	var t0 := m.time
	while B.out and m.time - t0 < 30.0:
		_run(Match.DT)
	ok(not B.out, "a bot walks to the box and brings its teammate back (%.1fs incl. the walk)" % (m.time - t0))
	# the soul has left the box: the bot heads for a beacon instead
	var unused: Array = m.beacons.filter(func(bc): return not bc["used"])
	_spot(C, unused[0]["pos"] + Vector3(8, 0, 0))
	_spot(B, C.pos)
	_run(0.3)
	m.eliminate(B, null, "finished")
	Life.box_of(m, B)["soul_until"] = 0.0
	t0 = m.time
	while B.out and m.time - t0 < 40.0:
		_run(Match.DT)
	C.ctrl = "idle"
	ok(not B.out and B.sick_t > 0.0,
		"with the soul gone a bot lights a beacon instead (%.1fs incl. the walk)" % (m.time - t0))
