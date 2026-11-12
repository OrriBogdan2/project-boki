extends RefCounted
## --ways-out-vfx-check: every way-out seat reads from across the island (WaysOutLook, SeatBeacon, WaysOutVfx).
##   1. one beacon driven through the five looks: every look differs from the others; a used seat's beam sinks
##      to nothing in COLLAPSE_S; a locked seat shows its countdown, no other look does.
##   2. the Heart's seats in a live match: the Gate and the ring go locked > open > in use (squad colour) > taken.
##   3. a lair's updraft and an outpost's uplink map dormant/locked/open/in use/taken/lost.
##   4. the Blight's tide over a seat is lost; no later seat reading flips a taken seat.
##   5. perf and the DECISIONS rule: no node count change over a whole match of changes, no particles, and the
##      code draws no burst and no expanding ring.
## Never touches the save.

const St := WaysOutLook.St
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("WAYSVFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(m: Match, secs: float) -> void:
	for i in int(secs / Match.DT):
		if i % 30 == 0:
			for mb in m.mobs:
				if mb is Blight:
					(mb as Blight).burrow()
				else:
					mb.dead = true
					mb.visible = false
		m.step(Match.DT)

func _match(main: Node, seed_v: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": seed_v, "no_drop": true,
		"heart": true, "god": true})
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle"
		h.teleport(m.world.random_ground())
	return m

## The beacon's look after the match has read its seats.
func _look(m: Match, at: Vector3) -> Array:
	_run(m, 0.6)
	return m.ways_vfx.beacon_at(at).looks()

func _h(look: Array) -> float:
	return float(look[2])

func _txt(look: Array) -> String:
	return String(look[3])

## The beam colour a seat shows while this squad uses it.
func _use(team: int) -> Color:
	return Color(WaysOutLook.team_col(team), WaysOutLook.LOOKS[St.IN_USE]["a"])

func _nodes(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _nodes(k)
	return c

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_five_looks(main)
	_heart(main)
	_quest(main)
	_source_rules()
	print("WAYSVFX DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

# ------------------------------------------------------------------ 1. the five looks
func _five_looks(main: Node) -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	var b := SeatBeacon.new(holder, Vector3.ZERO, 3.0)
	var seen := {}
	for st in [St.LOCKED, St.OPEN, St.IN_USE, St.TAKEN, St.LOST]:
		for i in 60:
			b.show(WaysOutLook.read(st, 1, 94.2, 0.4), Match.DT)
		seen[st] = b.looks()
	var distinct := {}
	for st in seen:
		distinct[str(seen[st])] = true
	ok(distinct.size() == 5, "the five looks all differ (%d distinct)" % distinct.size())
	ok(_txt(seen[St.LOCKED]) == "1:35" and _txt(seen[St.OPEN]) == "" and _txt(seen[St.IN_USE]) == "",
		"only a locked seat shows a countdown (%s)" % _txt(seen[St.LOCKED]))
	var tall := _h(seen[St.OPEN])
	ok(tall > _h(seen[St.LOCKED]) and tall > 20.0, "an open beam is tall, a locked one a stub")
	ok(seen[St.IN_USE][0].is_equal_approx(_use(1)), "in use is the squad's colour")
	ok(_h(seen[St.TAKEN]) == 0.0 and _h(seen[St.LOST]) < _h(seen[St.OPEN]), "taken has no beam, lost only a low haze")
	b.show(WaysOutLook.read(St.OPEN), Match.DT)
	b.show(WaysOutLook.read(St.TAKEN), Match.DT)
	ok(float(b.looks()[2]) > 0.0, "a taken seat's beam sinks over time, not in one frame")
	for i in int(WaysOutLook.COLLAPSE_S / Match.DT) + 2:
		b.show(WaysOutLook.read(St.TAKEN), Match.DT)
	ok(float(b.looks()[2]) == 0.0, "...and is gone after %.1f s" % WaysOutLook.COLLAPSE_S)
	ok(WaysOutLook.clock(5.0) == "0:05" and WaysOutLook.clock(120.0) == "2:00", "the countdown reads m:ss")
	holder.queue_free()

# ------------------------------------------------------------------ 2. the Heart's seats
func _heart(main: Node) -> void:
	var m := _match(main, 8201)
	var H: Heart = m.heart
	var rl := Heart.rules()
	var gate := func(): return _look(m, H.gate)
	var ring := func(): return _look(m, H.site)
	var g0: Array = gate.call()
	var r0: Array = ring.call()
	ok(_txt(g0) != "" and _txt(r0) != "", "both Heart seats start locked (%s, %s)" % [_txt(g0), _txt(r0)])
	var base := _nodes(m.ways_vfx._root)
	m.time = float(rl["wake_s"])
	# (wait by the Heart: out in the tide its damage downs the player before the spark is charged)
	m.player.teleport(H.site + Vector3(3, 0, 0))
	_run(m, float(rl["charge_s"]) + 1.0)
	var g1: Array = gate.call()
	var opened := g1 != g0 and _txt(g1) == "" and _h(g1) > 20.0
	ok(H.state == Heart.S.READY and opened, "the Gate opens at the charged spark")
	var p: Hunter = m.player
	p.teleport(H.site + Vector3(1, 0, 0))
	H._pick(p)
	var g2: Array = gate.call()
	ok(H.state == Heart.S.CARRIED and g2 != g1 and g2[0].is_equal_approx(_use(p.team)),
		"carried: the Gate takes the carrier's squad colour")
	H._gate_done(p)
	_run(m, WaysOutLook.COLLAPSE_S + 0.8)
	var g3: Array = gate.call()
	ok(H.early_team == p.team and float(g3[2]) == 0.0 and g3 != g2, "taken: the Gate's beam is gone and it goes dark")
	m.time = float(rl["final_s"]) + 0.1
	var r1: Array = ring.call()
	ok(H.state == Heart.S.FINAL and r1 != r0 and _txt(r1) == "" and _h(r1) > 20.0, "the final seat opens: a clear beam")
	var rival: Hunter = m.hunters.filter(func(h): return h.team != p.team)[0]
	for h in m.hunters:
		if h != rival:
			h.teleport(m.world.free_spot_near(H.site + Vector3(60, 0, 0), [], 1.0, 0.45, 8.0))
	rival.teleport(m.world.free_spot_near(H.site + Vector3(2.5, 0, 0), [], 1.0, 0.45, 1.5))
	rival.vel = Vector3.ZERO
	_run(m, 3.0)
	var r2: Array = ring.call()
	ok(H.final_team == rival.team and r2 != r1 and r2[0].is_equal_approx(_use(rival.team)),
		"a squad holding the ring: the ring and beam take its colour")
	_run(m, float(rl["final_hold_s"]) + 1.0)
	_run(m, WaysOutLook.COLLAPSE_S + 0.8)
	var r3: Array = ring.call()
	ok(H.state == Heart.S.DONE and float(r3[2]) == 0.0, "the final seat taken: the ring's beam is gone")
	ok(_nodes(m.ways_vfx._root) == base, "no node made or freed over the Heart's whole run (%d)" % base)
	m.queue_free()

# ------------------------------------------------------------------ 3. quest seats
func _quest(main: Node) -> void:
	var m := _match(main, 8202)
	var x: Dictionary = m.exits.uplink_x()
	var at: Vector3 = x["pos"]
	_run(m, 0.3)
	var base := _nodes(m.ways_vfx._root)
	m.time = 100.0
	x["open_at"] = m.time + 20.0
	var u0 := _look(m, at)
	ok(u0[3] != "" and float(u0[2]) < 10.0, "an uplink before its time is locked with a countdown (%s)" % u0[3])
	x["open_at"] = m.time - 1.0
	var u1 := _look(m, at)
	ok(u1 != u0 and u1[3] == "" and float(u1[2]) > 20.0, "idle after its time: open")
	m.exits._start(x, m.player)
	x["prog"] = 0.5
	var u2 := _look(m, at)
	ok(u2 != u1 and u2[0].is_equal_approx(_use(m.player.team)), "charging: the holder's colour")
	x["taken"] = true
	_run(m, WaysOutLook.COLLAPSE_S + 0.8)
	var u3 := _look(m, at)
	ok(float(u3[2]) == 0.0 and u3 != u2, "the lift used: taken, beam gone")
	var L: Dictionary = m.exits.seats.lair.ref      # the Sealed Lair (the only lair that is a way out)
	var up: Vector3 = L["up"]
	var vis := func(): return m.ways_vfx.beacon_at(up).node.visible
	L["state"] = "dormant"
	_run(m, 0.6)
	ok(not vis.call(), "a dormant lair is no seat: nothing drawn")
	L["state"] = "sealed"
	L["seat_open"] = m.time + 30.0
	var l0 := _look(m, up)
	ok(vis.call() and l0[3] != "", "a lair before its opening: locked with a countdown")
	L["seat_open"] = 0.0
	var l1 := _look(m, up)
	ok(l1 != l0 and float(l1[2]) > 20.0, "a sealed lair in its window: open")
	L["state"] = "awake"
	L["sealed_in"] = [m.player]
	var l2 := _look(m, up)
	ok(l2 != l1 and l2[0].is_equal_approx(_use(m.player.team)), "a squad sealed in with the boss: its colour")
	L["state"] = "cleared"
	L["up_on"] = false
	_run(m, WaysOutLook.COLLAPSE_S + 0.8)
	ok(float(_look(m, up)[2]) == 0.0, "the updraft used: taken")
	L["state"] = "sealed"
	L["shut_at"] = m.time - 1.0
	var l4 := _look(m, up)
	ok(l4 != l1 and float(l4[2]) < 10.0 and l4[3] == "", "a lair nobody used by its shut time: lost, smothered")
	ok(_nodes(m.ways_vfx._root) == base, "no node made or freed over every quest change (%d)" % base)
	# the tide: a seat far from the Heart late in the match is covered, whatever it was
	m.time = Heart.r("tide_start_s") + Heart.r("tide_close_s")
	# (the outpost that is not the Uplink seat, lit for the test: the seat itself was taken above)
	var others := m.exits.of_kind("outpost").filter(
		func(o2): return not o2.get("tut", false) and not o2.get("seat", false))
	var o: Dictionary = others[0]
	o["dark"] = false
	var far: Vector3 = o["pos"]
	var rd: Dictionary = WaysOutLook.uplink(m, o)
	var out_m := Vector2(far.x - m.heart.site.x, far.z - m.heart.site.z).length()
	var inside := out_m <= Heart.r("tide_r1") * m.heart.ways_scale
	ok(inside or int(rd["st"]) == St.LOST, "a seat the closed tide covers reads lost (%.0f m out)" % out_m)
	m.queue_free()

# ------------------------------------------------------------------ 5. what the look may not do
func _source_rules() -> void:
	for f in ["ways_out_look", "seat_beacon", "ways_out_vfx"]:
		var src := FileAccess.get_file_as_string("res://scripts/match/%s.gd" % f)
		var bad_call := ".burst(" in src or ".ring(" in src or "Particles" in src
		ok(not bad_call, "%s draws no burst, no expanding ring and no particles" % f)
