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
	m.time = 0.0
	var at := WaysOutMap.sites(m)
	ok(at[1] == H.gate and at[3] == H.site, "the Gate and the Heart ring are the Heart's own places")
	ok(at[0] != Vector3.INF and at[2] != Vector3.INF,
		"a lair and an outpost carry the quest seats (%s, %s)" % [at[0], at[2]])
	var outposts: Array = m.exits.list.filter(func(x): return x["kind"] == "outpost")
	var far: float = 0.0
	for x in outposts:
		far = maxf(far, Vector2(x["pos"].x - at[0].x, x["pos"].z - at[0].z).length())
	ok(Vector2(at[2].x - at[0].x, at[2].z - at[0].z).length() >= far - 0.01,
		"the Uplink is the outpost farthest from the Lair")
	# ---------------------------------------------------------------- 2. the ring fractions
	var sd := WaysOutHud.seats(m)
	ok(is_equal_approx(m.time, 0.0) and is_equal_approx(WaysOutMap.fraction(0, sd[0]), 0.0),
		"at 0:00 nothing is lit yet")
	m.time = 60.0
	sd = WaysOutHud.seats(m)
	ok(is_equal_approx(WaysOutMap.fraction(0, sd[0]), 60.0 / float(q["lair_open_s"])),
		"half way to the Lair: the ring is half lit")
	ok(WaysOutMap.fraction(3, sd[3]) < 0.2 and WaysOutMap.fraction(3, sd[3]) > 0.0, "the Final ring fills toward 10:00")
	m.time = float(q["lair_open_s"]) + 0.5
	sd = WaysOutHud.seats(m)
	ok(_state(m, 0) == St.OPEN and WaysOutMap.fraction(0, sd[0]) > 0.99, "the Lair just opened: full ring")
	m.time = (float(q["lair_open_s"]) + float(q["lair_shut_s"])) * 0.5
	sd = WaysOutHud.seats(m)
	ok(absf(WaysOutMap.fraction(0, sd[0]) - 0.5) < 0.01, "half way through the Lair's window: the ring is half drained")
	H.early_team = 1
	ok(WaysOutMap.fraction(1, WaysOutHud.seats(m)[1]) == 1.0, "a taken seat is a full ring (struck through)")
	H.early_team = -1
	# ---------------------------------------------------------------- 3. colours
	m.time = 30.0
	sd = WaysOutHud.seats(m)
	var locked_col := WaysOutMap.color_of(sd[0])
	m.time = float(q["lair_open_s"]) + 1.0
	var open_col := WaysOutMap.color_of(WaysOutHud.seats(m)[0])
	m.time = float(q["lair_shut_s"]) + 1.0
	var lost_col := WaysOutMap.color_of(WaysOutHud.seats(m)[0])
	ok(locked_col != open_col and open_col != lost_col and locked_col != lost_col,
		"locked, open and lost seats read in three colours")
	H.carrier = m.player
	H._force(Heart.S.CARRIED, "test")
	ok(WaysOutMap.color_of(WaysOutHud.seats(m)[1]) == Data.TEAM_COLORS[m.player.team % Data.TEAM_COLORS.size()],
		"a carried spark: the Gate wears the carrier's squad colour")
	H.carrier = null
	H.early_team = m.player.team
	ok(WaysOutMap.color_of(WaysOutHud.seats(m)[1]) != Data.TEAM_COLORS[m.player.team % Data.TEAM_COLORS.size()],
		"a taken seat is dimmed")
	H.early_team = -1
	# ---------------------------------------------------------------- 4. ways left
	m.time = 30.0
	H._force(Heart.S.CHARGING, "test")
	ok(WaysOutMap.ways_left(m) == 4, "at the start four ways out are left")
	m.time = float(q["lair_shut_s"]) + 1.0
	ok(_state(m, 0) == St.LOST and WaysOutMap.ways_left(m) == 3, "a seat the Blight took no longer counts")
	H.early_team = 1
	ok(WaysOutMap.ways_left(m) == 2, "a taken seat no longer counts")
	# ---------------------------------------------------------------- 5. nearest
	H.early_team = -1
	m.time = 30.0
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
	m.time = float(Heart.r("final_s")) + float(q["uplink_shut_s"])
	ok(WaysOutMap.ways_left(m) == 0 and WaysOutMap.line(m) == "Ways out left: 0", "none left: just the count")
	# ---------------------------------------------------------------- 7. the next ring
	H.early_team = -1
	H._force(Heart.S.WAITING, "test")
	var t0: float = Heart.r("tide_start_s")
	m.time = 10.0
	ok(is_equal_approx(Heart.next_r(m), Heart.r("tide_r0") * H.ways_scale),
		"before the tide the dashed ring is the first ring")
	m.time = t0 + 100.0
	var ahead := (100.0 + Heart.r("tide_next_s")) / Heart.r("tide_close_s")
	var want := lerpf(Heart.r("tide_r0"), Heart.r("tide_r1"), ahead) * H.ways_scale
	ok(is_equal_approx(Heart.next_r(m), want) and Heart.next_r(m) < Heart.tide_r(m),
		"mid close: the dashed ring is tide_next_s ahead and smaller")
	m.time = t0 + Heart.r("tide_close_s") + 50.0
	ok(is_equal_approx(Heart.next_r(m), Heart.r("tide_r1") * H.ways_scale),
		"once the ring holds there is no smaller one")
	# ---------------------------------------------------------------- 8. the real HUD
	m.player.out = true
	m.hud.full_map.open()
	for k in [30.0, 200.0, 400.0, 700.0]:
		m.time = k
		for i in 3:
			await main.get_tree().process_frame
	ok(true, "four moments drawn through the HUD, the minimap and the open full map")
	m.hud.full_map.close()
	m.queue_free()
	print("WAYSMAP DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)
