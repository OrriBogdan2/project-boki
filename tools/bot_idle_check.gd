extends RefCounted
## --bot-idle-check: nobody stands about after the drop. A seeded 3x3 autoplay expedition (your hunter played by its
## bot) runs MATCH_S of match time; once a hunter has landed, any IDLE_MAX stretch it spends standing still on the
## ground (not riding, dropping, downed, out, gone or channelling home) fails. Your map, opened by hand on the ship,
## is closed once you have landed (DropFeel.land). Then once more with your hunter left standing where it lands (the
## map out, say): your squadmates waiting beside you keep stepping about, none stands still over IDLE_MAX (they held
## the spot they walked up to: 14.4 s frozen, again and again). Never touches the save.

const MATCH_S := 100.0  # s of match time watched
const IDLE_MAX := 8.0  # s: the longest a landed hunter may stand still (seeds 3 and 5 measured 5.0 s at most)
const STAND_S := 110.0  # s of match time in the run where you stand (the ride runs out with you on board at ~45 s)
const STILL_M := 0.002  # m a step: below this the hunter didn't move

var bad := 0


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	await _expedition(main, true)
	await _expedition(main, false)
	print("BOTIDLE DONE, failures: %d" % bad)
	main.get_tree().quit()


## autoplay: your hunter played by its bot, everyone watched; else your hunter stands and only your squadmates are.
func _expedition(main: Node, autoplay: bool) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 3, "tier": 0, "seed": 3, "autoplay": autoplay})
	m.set_process(false)
	await main.get_tree().process_frame
	var last := {}
	var still := {}
	var worst := {}
	var map_checked := false
	if m.hud and autoplay:
		m.hud.full_map.open()  # by hand, not the planning map (that one closes when the ship sets off)
	var watch_s := MATCH_S if autoplay else STAND_S
	while m.time < watch_s and not m.over:
		m.step(Match.DT)
		for h in m.hunters:
			if not autoplay and (h == m.player or h.team != m.player.team):
				continue
			var p0: Vector3 = last.get(h.nid, h.pos)
			last[h.nid] = h.pos
			var away: bool = h.out or h.extracted or h.riding or h.dropping or h.downed or not h.has_meta("landed_t")
			var stood: bool = Vector2(h.pos.x - p0.x, h.pos.z - p0.z).length() < STILL_M and h.grounded
			still[h.nid] = float(still.get(h.nid, 0.0)) + Match.DT if stood and not away and h.base_t <= 0.0 else 0.0
			worst[h.pname] = maxf(float(worst.get(h.pname, 0.0)), float(still[h.nid]))
		if m.hud and autoplay and not map_checked and m.player.has_meta("landed_t"):
			map_checked = true
			_ok(not m.hud.map_open(), "your map, opened on the ship, is closed once you land")
	var tag := "" if autoplay else " (beside you standing)"
	for who in worst:
		_ok(float(worst[who]) <= IDLE_MAX, "%s: longest stand-still after landing %.1f s%s" % [who, worst[who], tag])
	_ok(worst.size() > 0, "someone was watched%s" % tag)
	if autoplay:
		_ok(map_checked or m.hud == null, "you landed inside the %d s watched" % int(MATCH_S))
	m.queue_free()
	await main.get_tree().process_frame


func _ok(cond: bool, what: String) -> void:
	print("BOTIDLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1
