extends RefCounted
## --boki-carry-check: carry two in, one extra out (DECISIONS 2026-11-11) on the Boki box (BokiCarry, KinPair).
## The second Boki's row (portrait, health, passive, the swap key's cap with a cooling ring) and the carry-out row
## (the claimed Boki, an empty outline while you scan, STOLEN once a rival looted it) appear only while used; equal
## passives of the lead and the second count once; no hunter holds more than wisp_max wisps; every row fits the
## screen and none overlaps the next. At 1280x720 and on an ultrawide the same rows fit (run with --resolution).
## With --shots-dir=<dir> (real renderer) it saves the HUD as <dir>/<WxH>_NN_<state>.png. Prints PASS/FAIL.

const DT := 1.0 / 60.0

var main: Node
var m: Match
var bad := 0
var n := 0
var dir := ""

func ok(cond: bool, what: String) -> void:
	print("BOKICARRY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Game.god = false
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if dir != "" and fade != null:
		await fade.reveal(0.01)
	await _rows()
	print("BOKICARRY %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters:
			h.render(DT, 1.0)
		t += DT

func _drawn() -> void:
	m.hud.visible = true
	await m.hud.panels.draw
	await m.hud.panels.draw

func _kinds() -> Array:
	return BokiCarry.shown.map(func(r): return "%s:%s" % [r["kind"], r["state"]])

## Every row inside the screen, none over another, the right edge on the box's.
func _fits(what: String) -> void:
	var sz: Vector2 = m.hud.get_viewport().get_visible_rect().size
	var good := true
	for i in BokiCarry.shown.size():
		var r: Rect2 = BokiCarry.shown[i]["rect"]
		good = good and r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= sz.x and r.end.y <= sz.y
		for j in i:
			good = good and not r.intersects(BokiCarry.shown[j]["rect"])
	ok(good, "%s: %d rows fit %dx%d, none overlapping" % [what, BokiCarry.shown.size(), int(sz.x), int(sz.y)])

func _rows() -> void:
	var p: Hunter = m.player
	var foes: Array = m.hunters.filter(func(h: Hunter): return h.team != p.team and h.kin != null)
	_frames(0.3)
	await _drawn()
	ok(BokiCarry.shown.is_empty() and p.kin2 == null, "one Boki and nothing claimed: no second row, no carry-out row")
	# ---------------------------------------------------------------- the second Boki
	var k2 := m.give_kin(p, Save.new_kin("puddlet"))
	_frames(0.1)
	await _drawn()
	ok(p.kin2 == k2 and _kinds() == ["second:ready"], "a second Boki: one row, swap ready (%s)" % [_kinds()])
	ok(BokiCarry.shown[0]["key"] == Settings.key_cap("swap_kin") and Settings.key_cap("swap_kin") != "?",
		"...it shows the swap key's cap (%s)" % Settings.key_cap("swap_kin"))
	await _shot("second")
	var lead_before: Kin = p.kin
	p.swap_kin()
	_frames(0.5)
	await _drawn()
	ok(p.kin == k2 and p.kin2 == lead_before and _kinds() == ["second:wait"],
		"the swap trades lead and second, the key's ring cools (%s)" % [_kinds()])
	var row: Dictionary = BokiCarry.rows(p)[0]
	ok(float(row["cool"]) > 0.0 and float(row["cool"]) < 1.0, "...the ring is part-filled (%.2f)" % float(row["cool"]))
	await _shot("cooling")
	_frames(float(Content.rules("kin_ai")["swap_cooldown"]) + 0.1)
	ok(BokiCarry.rows(p)[0]["state"] == "ready", "...ready again after the cooldown")
	p.kin2.hp = p.kin2.max_hp * 0.4
	ok(absf(float(BokiCarry.rows(p)[0]["hp"]) - 0.4) < 0.01, "the row's health follows the benched Boki (0.4)")
	# ---------------------------------------------------------------- passives count once
	var lead: Kin = p.kin
	lead.state = "shoulder"
	lead.settle = 1.0
	lead.cmd = "return"
	lead.ks.carry_passives = [{"stat": "move_speed", "amount": 0.1}, {"stat": "armor", "amount": 0.2}]
	p.kin2.ks.carry_passives = [{"stat": "move_speed", "amount": 0.15}, {"stat": "regen", "amount": 3.0}]
	var ps := KinPair.passives(p)
	var once := is_equal_approx(float(ps.get("move_speed", 0.0)), 0.15)
	ok(p.kin_carry_on() and once and float(ps.get("armor", 0.0)) == 0.2 and float(ps.get("regen", 0.0)) == 3.0,
			"equal passives count once (the stronger), the others add (%s)" % [ps])
	# ---------------------------------------------------------------- the carry-out slot
	p.set_meta("cap", {"phase": "hold", "hold": 0.1})
	await _drawn()
	ok(_kinds() == ["second:ready", "carry:empty"], "scanning a Boki: the empty outline (%s)" % [_kinds()])
	await _shot("carry_empty")
	p.set_meta("cap", {})
	var rec := Save.new_kin("cindle", "Ember", 12)
	p.caught.append(rec)
	await _drawn()
	ok(_kinds() == ["second:ready", "carry:claimed"] and not Capture.room(p),
			"a claimed Boki: its row, the slot is full (%s)" % [_kinds()])
	await _shot("carry_claimed")
	_fits("second + carry-out")
	# ---------------------------------------------------------------- wisp cap
	ok(KinPair.wisps(p) == 3 and KinPair.room_for_stolen(p), "two own + carry-out = 3 wisps: one more may be stolen")
	var thief_prey: Kin = foes[0].kin
	m.knock(foes[0], p, {})
	_frames(0.1)
	ok(KinSteal.grab(thief_prey, p), "a rival's wisp is grabbed")
	var prey2: Kin = foes[0].kin2 if foes[0].kin2 != null else null
	ok(KinPair.wisps(p) == 4 and not KinPair.room_for_stolen(p), "four wisps: no room for a fifth")
	_frames(0.1)
	await _drawn()
	_fits("second + carry-out + a stolen wisp")
	await _shot("all_rows")
	ok(prey2 == null, "(the rival carried one Boki)")
	# ---------------------------------------------------------------- STOLEN
	p.caught = []
	var box := {"owner": p, "team": p.team, "pos": p.pos, "gems": 0, "seeds": {}, "caught": [rec], "belt": [],
		"soul_until": 0.0, "prog": {}, "node": null, "empty": false, "gear": [], "pack": []}
	var thief: Hunter = foes[0]
	thief.caught = []
	Life.take_item(m, thief, box, {"key": "caught", "i": 0})
	await _drawn()
	ok(thief.caught.size() == 1 and BokiCarry.rows(p).filter(func(r): return r["state"] == "stolen").size() == 1,
		"a rival loots your capsule: the carry-out row says STOLEN (%s)" % [_kinds()])
	await _shot("stolen")
	ok(KinPair.wisps(p) == 3, "...and it no longer counts against your wisps")

## The HUD as it is (real renderer only).
func _shot(what: String) -> void:
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 3:
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	n += 1
	img.save_png(dir.path_join("%dx%d_%02d_%s.png" % [img.get_width(), img.get_height(), n, what]))
