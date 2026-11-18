extends RefCounted
## --bot-idle-check: nobody stands about after the drop. A seeded 3x3 autoplay expedition (your hunter played by its
## bot) runs MATCH_S of match time; once a hunter has landed, any IDLE_MAX stretch it spends standing still on the
## ground (not riding, dropping, downed, out, gone or channelling home) fails. Your map, opened by hand on the ship,
## is closed once you have landed (DropFeel.land). Never touches the save.

const MATCH_S := 100.0  # s of match time watched
const IDLE_MAX := 8.0  # s: the longest a landed hunter may stand still (seeds 3 and 5 measured 5.0 s at most)
const STILL_M := 0.002  # m a step: below this the hunter didn't move

var bad := 0


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 3, "tier": 0, "seed": 3, "autoplay": true})
	m.set_process(false)
	await main.get_tree().process_frame
	var last := {}
	var still := {}
	var worst := {}
	var map_checked := false
	if m.hud:
		m.hud.full_map.open()  # by hand, not the planning map (that one closes when the ship sets off)
	while m.time < MATCH_S and not m.over:
		m.step(Match.DT)
		for h in m.hunters:
			var p0: Vector3 = last.get(h.nid, h.pos)
			last[h.nid] = h.pos
			var away: bool = h.out or h.extracted or h.riding or h.dropping or h.downed or not h.has_meta("landed_t")
			var stood: bool = Vector2(h.pos.x - p0.x, h.pos.z - p0.z).length() < STILL_M and h.grounded
			still[h.nid] = float(still.get(h.nid, 0.0)) + Match.DT if stood and not away and h.base_t <= 0.0 else 0.0
			worst[h.pname] = maxf(float(worst.get(h.pname, 0.0)), float(still[h.nid]))
		if m.hud and not map_checked and m.player.has_meta("landed_t"):
			map_checked = true
			_ok(not m.hud.map_open(), "your map, opened on the ship, is closed once you land")
	for who in worst:
		_ok(float(worst[who]) <= IDLE_MAX, "%s: longest stand-still after landing %.1f s" % [who, worst[who]])
	_ok(map_checked or m.hud == null, "you landed inside the %d s watched" % int(MATCH_S))
	print("BOTIDLE DONE, failures: %d" % bad)
	main.get_tree().quit()


func _ok(cond: bool, what: String) -> void:
	print("BOTIDLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1
