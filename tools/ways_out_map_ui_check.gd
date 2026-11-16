extends RefCounted
## --ways-out-map-ui-check: the Ways Out seats on the maps (scripts/ui/ways_out_map.gd, spec section 9).
##   1. four seat sites from 0:00: the Heart Gate, the Heart, a lair, the outpost farther from it; none without a Heart
##   2. each badge's ring: a locked seat fills to its opening, an open one with a shut time drains, the rest are full
##   3. the state colours differ (locked, open, lost) and an in-use seat wears its squad's colour
##   4. "Ways out left" counts locked, open and in use seats, not taken or lost ones
##   5. the nearest seat follows your living squad, skips seats that are gone, and falls back to where you fell
##   6. the line shows only for the dead and the watching, and says the count and the nearest seat
##   7. the dashed next Blight ring: the first ring before the tide, then where it will be tide_next_s on
##   8. the real HUD and the full map draw all of it (frames run with the Hud on, map open, player dead)
##   9. pins from afar in the play view (WaysOutPins): a seat off screen points at it, none on screen, none for
##      taken or lost seats or locked ones past reach, the locked Heart ring waits for the Gate; the Blight's bar;
##      only the Sealed Lair's own fight puts its seat in use
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("WAYSMAP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _state(m: Match, i: int) -> int:
	return int(WaysOutHud.seats(m)[i]["st"])

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9,
		"seed": 7401, "no_drop": true, "heart": true, "god": true})
	for o in m.hunters:
		o.ctrl = "idle"
	var H: Heart = m.heart
	var q: Dictionary = Heart.rules()["quest"]
	var St := WaysOutHud.St
	# ---------------------------------------------------------------- 1. the sites
	m.time = 0.0 - m.sess_t0
	var at := WaysOutMap.sites(m)
	ok(at[1] == H.gate and at[3] == H.site, "the Gate and the Heart ring are the Heart's own places")
	ok(at[0] != Vector3.INF and at[2] != Vector3.INF,
		"a lair and an outpost carry the quest seats (%s, %s)" % [at[0], at[2]])
	var qs: QuestSeats = m.exits.seats
	ok(at[0] == qs.lair.ref["c"] and at[2] == qs.uplink.ref["pos"],
		"the Lair and Uplink badges stand on the seeded Sealed Lair and Uplink (%s, %s)" % [at[0], at[2]])
	var outposts: Array = m.exits.list.filter(func(x): return x["kind"] == "outpost")
	var far: float = 0.0
	for x in outposts:
		far = maxf(far, Vector2(x["pos"].x - at[0].x, x["pos"].z - at[0].z).length())
	ok(Vector2(at[2].x - at[0].x, at[2].z - at[0].z).length() >= far - 0.01,
		"the Uplink is the outpost farthest from the Lair")
	# ---------------------------------------------------------------- 2. the ring fractions
	var sd := WaysOutHud.seats(m)
	ok(is_equal_approx(m.sess_time(), 0.0) and is_equal_approx(WaysOutMap.fraction(0, sd[0]), 0.0),
		"at 0:00 nothing is lit yet")
	m.time = 60.0 - m.sess_t0
	sd = WaysOutHud.seats(m)
	ok(is_equal_approx(WaysOutMap.fraction(0, sd[0]), 60.0 / float(q["lair_open_s"])),
		"half way to the Lair: the ring is half lit")
	ok(WaysOutMap.fraction(3, sd[3]) < 0.2 and WaysOutMap.fraction(3, sd[3]) > 0.0, "the Final ring fills toward 10:00")
	m.time = float(q["lair_open_s"]) + 0.5 - m.sess_t0
	sd = WaysOutHud.seats(m)
	ok(_state(m, 0) == St.OPEN and WaysOutMap.fraction(0, sd[0]) > 0.99, "the Lair just opened: full ring")
	m.time = (float(q["lair_open_s"]) + float(q["lair_shut_s"])) * 0.5 - m.sess_t0
	sd = WaysOutHud.seats(m)
	ok(absf(WaysOutMap.fraction(0, sd[0]) - 0.5) < 0.01, "half way through the Lair's window: the ring is half drained")
	H.early_team = 1
	ok(WaysOutMap.fraction(1, WaysOutHud.seats(m)[1]) == 1.0, "a taken seat is a full ring (struck through)")
	H.early_team = -1
	# ---------------------------------------------------------------- 3. colours
	m.time = 30.0 - m.sess_t0
	sd = WaysOutHud.seats(m)
	var locked_col := WaysOutMap.color_of(sd[0])
	m.time = float(q["lair_open_s"]) + 1.0 - m.sess_t0
	var open_col := WaysOutMap.color_of(WaysOutHud.seats(m)[0])
	m.time = float(q["lair_shut_s"]) + 1.0 - m.sess_t0
	var lost_col := WaysOutMap.color_of(WaysOutHud.seats(m)[0])
	ok(locked_col != open_col and open_col != lost_col and locked_col != lost_col,
		"locked, open and lost seats read in three colours")
	H.carrier = m.player
	H._force(Heart.S.CARRIED, "test")
	ok(WaysOutMap.color_of(WaysOutHud.seats(m)[1]) == SideColor.ally(),
		"a carried spark: the Gate wears the carrier's squad colour")
	H.carrier = null
	H.early_team = m.player.team
	ok(WaysOutMap.color_of(WaysOutHud.seats(m)[1]) != SideColor.ally(),
		"a taken seat is dimmed")
	H.early_team = -1
	# ---------------------------------------------------------------- 4. ways left
	m.time = 30.0 - m.sess_t0
	H._force(Heart.S.CHARGING, "test")
	ok(WaysOutMap.ways_left(m) == 4, "at the start four ways out are left")
	m.time = float(q["lair_shut_s"]) + 1.0 - m.sess_t0
	ok(_state(m, 0) == St.LOST and WaysOutMap.ways_left(m) == 3, "a seat the Blight took no longer counts")
	H.early_team = 1
	ok(WaysOutMap.ways_left(m) == 2, "a taken seat no longer counts")
	# ---------------------------------------------------------------- 5. nearest
	H.early_team = -1
	m.time = 30.0 - m.sess_t0
	var mine: Array = m.hunters.filter(func(h): return h.team == m.player.team)
	for h in mine:
		h.teleport(m.world.free_spot_near(H.gate + Vector3(3, 0, 3), [], 1.0, 0.45, 6.0))
	var near := WaysOutMap.nearest(m, m.player.team)
	ok(near["i"] == 1, "a squad standing at the Gate is nearest the Heart Gate (got %d)" % near["i"])
	H.early_team = 1
	near = WaysOutMap.nearest(m, m.player.team)
	ok(near["i"] != 1 and near["i"] >= 0, "once the Gate is taken the next seat is named (got %d)" % near["i"])
	H.early_team = -1
	var mate: Hunter = mine.filter(func(h): return h != m.player)[0]
	var spot := m.world.free_spot_near(at[2], [], 1.0, 0.45, 6.0)
	mate.teleport(spot)
	m.player.out = true
	near = WaysOutMap.nearest(m, m.player.team)
	ok(near["i"] == 2, "the dead player's living mate decides: nearest the Uplink (got %d)" % near["i"])
	mate.out = true
	near = WaysOutMap.nearest(m, m.player.team)
	ok(near["i"] >= 0, "with the whole squad down it falls back to where you fell")
	# ---------------------------------------------------------------- 6. the line
	m.player.out = false
	mate.out = false
	ok(WaysOutMap.line(m) == "", "no line while you play")
	m.player.out = true
	var txt := WaysOutMap.line(m)
	ok(txt.begins_with("Ways out left: %d" % WaysOutMap.ways_left(m)) and txt.contains("nearest"),
		"dead: the count and the nearest seat (%s)" % txt)
	m.player.out = false
	m.player.extracted = true
	ok(WaysOutMap.line(m).begins_with("Ways out left"), "out through a seat and watching: the line shows too")
	m.player.extracted = false
	m.player.out = true
	H.early_team = 1
	H._force(Heart.S.DONE, "test")
	m.time = float(Heart.r("final_s")) + float(q["uplink_shut_s"]) - m.sess_t0
	ok(WaysOutMap.ways_left(m) == 0 and WaysOutMap.line(m) == "Ways out left: 0", "none left: just the count")
	# ---------------------------------------------------------------- 7. the next ring
	H.early_team = -1
	H._force(Heart.S.WAITING, "test")
	var t0: float = Heart.r("tide_start_s")
	m.time = 10.0 - m.sess_t0
	ok(is_equal_approx(Heart.next_r(m), Heart.r("tide_r0") * H.ways_scale),
		"before the tide the dashed ring is the first ring")
	m.time = t0 + 100.0 - m.sess_t0
	var ahead := (100.0 + Heart.r("tide_next_s")) / Heart.r("tide_close_s")
	var want := lerpf(Heart.r("tide_r0"), Heart.r("tide_r1"), ahead) * H.ways_scale
	ok(is_equal_approx(Heart.next_r(m), want) and Heart.next_r(m) < Heart.tide_r(m),
		"mid close: the dashed ring is tide_next_s ahead and smaller")
	m.time = t0 + Heart.r("tide_close_s") + 50.0 - m.sess_t0
	ok(is_equal_approx(Heart.next_r(m), Heart.r("tide_r1") * H.ways_scale),
		"once the ring holds there is no smaller one")
	# ---------------------------------------------------------------- 9. pins from afar
	await _pins(main, m, at)
	# ---------------------------------------------------------------- 8. the real HUD
	m.player.out = true
	m.hud.full_map.open()
	for k in [30.0, 200.0, 400.0, 700.0]:
		m.time = k - m.sess_t0
		for i in 3:
			await main.get_tree().process_frame
	ok(true, "four moments drawn through the HUD, the minimap and the open full map")
	m.hud.full_map.close()
	m.queue_free()
	print("WAYSMAP DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

## A spot `d` m from `at` on ground and inside the tide ring, from the first bearing (degrees from north, clockwise)
## that has one; Vector3.INF when none does.
func _stand(m: Match, at: Vector3, d: float, first := 90.0) -> Vector3:
	for k in 12:
		var a := deg_to_rad(first + 30.0 * k)
		var p := m.world.free_spot_near(at - Vector3(sin(a), 0, -cos(a)) * d, [], 1.0, 0.45, 2.0)
		var off := absf(Vector2(p.x - at.x, p.z - at.z).length() - d)
		if not m.world.is_void(p.x, p.z) and off < 2.5 and Heart.tide_out(m, p) <= 0.0:
			return p
	return Vector3.INF

## How well a pin's screen direction points from `spot` at the ground `at` (1 = dead on; the camera faces north).
func _aim(spot: Vector3, at: Vector3, dir: Vector2) -> float:
	return dir.dot(Vector2(at.x - spot.x, at.z - spot.z).normalized())

func _put(m: Match, spot: Vector3) -> void:
	m.player.teleport(spot)
	m.cam.snap(spot)

func _pins(main: Node, m: Match, at: Array[Vector3]) -> void:
	var H: Heart = m.heart
	var q: Dictionary = Heart.rules()["quest"]
	var sz: Vector2 = m.hud.c.size
	m.player.out = false
	m.player.extracted = false
	H.early_team = -1
	H.charge = Heart.r("charge_s")
	H._force(Heart.S.READY, "test")
	m.time = float(q["lair_open_s"]) + 10.0 - m.sess_t0
	var other: Array = m.lairs.list.filter(func(L): return not L.get("seat", false))
	if not other.is_empty():
		other[0]["sealed_in"] = [m.player]
		var lair_st := int(WaysOutHud.seats(m)[0]["st"])
		ok(lair_st == WaysOutHud.St.OPEN, "a fight in another lair leaves the Sealed Lair open")
		other[0]["sealed_in"] = []
	m.time = float(q["uplink_open_s"]) + 10.0 - m.sess_t0
	var sd := WaysOutHud.seats(m)
	var spot := _stand(m, at[2], 40.0)
	ok(spot != Vector3.INF, "a spot 40 m from the Uplink inside the ring")
	_put(m, spot)
	var dir := WaysOutPins.seat_dir(m, sz, 2, sd, at[2])
	ok(dir != Vector2.ZERO and _aim(spot, at[2], dir) > 0.7,
		"the open Uplink 40 m off gets a pin pointing at it (%s, aim %.2f)" % [dir, _aim(spot, at[2], dir)])
	var close := _stand(m, at[2] + Vector3(0, 0, 3.0), 6.0, 90.0)
	_put(m, close)
	ok(WaysOutPins.seat_dir(m, sz, 2, sd, at[2]) == Vector2.ZERO, "6 m off and on screen: no pin, its beam reads")
	var far := _stand(m, at[2], WaysOutPins.REACH_M + 15.0)
	if far != Vector3.INF:
		_put(m, far)
		ok(WaysOutPins.seat_dir(m, sz, 2, sd, at[2]) != Vector2.ZERO, "past REACH_M an open seat still has its pin")
		m.time = float(q["uplink_open_s"]) - 20.0 - m.sess_t0
		var locked := WaysOutHud.seats(m)
		ok(WaysOutPins.seat_dir(m, sz, 2, locked, at[2]) == Vector2.ZERO, "past REACH_M a locked one has none")
		m.time = float(q["uplink_open_s"]) + 10.0 - m.sess_t0
		sd = WaysOutHud.seats(m)
	_put(m, spot)
	var up: QuestSeat = m.exits.seats.uplink
	up._force(QuestSeat.S.TAKEN, "test", 1)
	sd = WaysOutHud.seats(m)
	ok(int(sd[2]["st"]) == WaysOutHud.St.TAKEN and WaysOutPins.seat_dir(m, sz, 2, sd, at[2]) == Vector2.ZERO,
		"a taken seat gets no pin")
	up._force(QuestSeat.S.OPEN, "test")
	m.time = float(q["uplink_shut_s"]) + 5.0 - m.sess_t0
	sd = WaysOutHud.seats(m)
	ok(int(sd[2]["st"]) == WaysOutHud.St.LOST and WaysOutPins.seat_dir(m, sz, 2, sd, at[2]) == Vector2.ZERO,
		"a lost seat gets no pin")
	m.time = float(q["uplink_open_s"]) + 10.0 - m.sess_t0
	var hs := _stand(m, at[3], 50.0)
	_put(m, hs)
	sd = WaysOutHud.seats(m)
	var gate_pin := WaysOutPins.seat_dir(m, sz, 1, sd, at[1])
	ok(gate_pin != Vector2.ZERO and WaysOutPins.seat_dir(m, sz, 3, sd, at[3]) == Vector2.ZERO,
		"the Gate open, the Heart ring locked: one Heart pin, the Gate's")
	H.early_team = 1
	H._force(Heart.S.WAITING, "test")
	sd = WaysOutHud.seats(m)
	gate_pin = WaysOutPins.seat_dir(m, sz, 1, sd, at[1])
	ok(gate_pin == Vector2.ZERO and WaysOutPins.seat_dir(m, sz, 3, sd, at[3]) != Vector2.ZERO,
		"the Gate used: its pin goes, the ring's (locked, counting down) shows")
	# the Blight's wall
	var rim := Heart.r("tide_r1") * H.ways_scale + 20.0      # (a big map: the ring stays wider)
	if m.player.flat_dist(H.site) < rim:
		var fp := _stand(m, H.site, rim)
		if fp != Vector3.INF:
			_put(m, fp)
	var R := Heart.tide_r(m)
	var inside := m.player.flat_dist(H.site)
	var gap := WaysOutPins.wall_gap(m)
	ok(is_equal_approx(gap, R - inside), "the wall's gap is the ring less the player's distance from the Heart")
	m.time = _tide_at(inside + 40.0, H) - m.sess_t0
	var wd := WaysOutPins.wall_dir(m, sz)
	var out := m.player.pos - H.site
	ok(wd != Vector2.ZERO and wd.dot(Vector2(out.x, out.z).normalized()) > 0.7,
		"the wall 40 m off: a bar on the edge toward it (%s)" % wd)
	m.time = _tide_at(inside + WaysOutPins.WALL_M + 10.0, H) - m.sess_t0
	ok(WaysOutPins.wall_dir(m, sz) == Vector2.ZERO, "the wall past WALL_M: no bar")
	m.time = _tide_at(inside - 5.0, H) - m.sess_t0
	ok(WaysOutPins.wall_gap(m) < 0.0 and WaysOutPins.wall_dir(m, sz) == Vector2.ZERO, "out past the ring: no bar")
	m.time = _tide_at(inside + 40.0, H) - m.sess_t0
	for i in 3:
		await main.get_tree().process_frame
	ok(true, "pins drawn through the HUD with the player in the match")
	H.early_team = -1

## The session second at which the tide ring has radius `r` (the close is linear).
func _tide_at(r: float, H: Heart) -> float:
	var f := (Heart.r("tide_r0") - r / H.ways_scale) / (Heart.r("tide_r0") - Heart.r("tide_r1"))
	return Heart.r("tide_start_s") + Heart.r("tide_close_s") * f
