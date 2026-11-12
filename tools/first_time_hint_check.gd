extends RefCounted
## --first-time-hint-check: the sight wedge's first-time line (VisionHint, said by Match._tips).
##   1. a rival hidden only by the wedge (behind you, in range, clear line) counts; one in front or in the near
##      circle does not (you see it)
##   2. a fast swing of the aim counts, a slow turn does not
##   3. through Match._tips: shown once on the hint lane, remembered in the save, never with tips off or in the
##      tutorial course; the line is short and plain (no key names)

const SIDE_M := 8.0        # m: where the probe rival stands (outside the near circle, inside the view range)
const NEAR_M := 1.5        # m: inside the near circle (NEAR_SENSE 2.0)
const LINE_MAX := 52       # characters: one line on the hint lane
const TURN_TEST := VisionHint.TURN_DEG + 20.0      # degrees: the probe turn, a little over the hint's

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("FTHINT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Settings.v["tips"] = true
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 5101, "no_drop": true, "raid": "clear"})
	m.set_process(false)
	for h in m.hunters: h.ctrl = "idle"
	var rival: Hunter = m.hunters.filter(func(h): return h.team != m.player.team)[0]
	var a := _open_angle(m)
	ok(a != INF, "found open ground in front of and behind the player")
	if a != INF:
		_hidden(m, rival, a)
		_turns(m)
		_said(m, rival, a)
	m.queue_free()
	print("FTHINT DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

## An aim angle with open ground at SIDE_M ahead and behind and at NEAR_M behind, in clear line; INF if none.
func _open_angle(m: Match) -> float:
	for i in 32:
		var a := TAU * i / 32.0
		if _spot(m, a, SIDE_M) != Vector3.INF and _spot(m, a + PI, SIDE_M) != Vector3.INF \
				and _spot(m, a + PI, NEAR_M) != Vector3.INF:
			return a
	return INF

func _spot(m: Match, b: float, d: float) -> Vector3:
	var P := m.player
	var q := P.pos + Vector3(cos(b), 0, sin(b)) * d
	if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z) or m.world.in_bush(q.x, q.z) or m.in_smoke(q):
		return Vector3.INF
	q.y = m.world.ground_at(q.x, q.z)
	if absf(q.y - P.pos.y) > 0.5 or not m.world.los(P.pos, q, P.pos.y + 1.1):
		return Vector3.INF
	return q

func _place(m: Match, rival: Hunter, a: float, b: float, d: float) -> void:
	m.player.inp["aim"] = m.player.pos + Vector3(cos(a), 0, sin(a)) * 6.0
	rival.pos = _spot(m, b, d)
	rival.crouch = false
	rival.unseen = not m.can_see(m.player.team, rival)

func _hidden(m: Match, rival: Hunter, a: float) -> void:
	_place(m, rival, a, a + PI, SIDE_M)
	var behind := "a rival %.0f m behind you, in the open, is hidden by the wedge" % SIDE_M
	ok(rival.unseen and VisionHint.hidden_rival(m), behind)
	_place(m, rival, a, a, SIDE_M)
	ok(not rival.unseen and not VisionHint.hidden_rival(m), "the same rival in front of you is seen: no hint")
	_place(m, rival, a, a + PI, NEAR_M)
	var near := "one %.1f m behind you is in the near circle: no hint" % NEAR_M
	ok(not rival.unseen and not VisionHint.hidden_rival(m), near)

func _turns(m: Match) -> void:
	var swing := _turn_due(m, VisionHint.TURN_S * 0.5)
	var slow := _turn_due(m, VisionHint.TURN_S * 4.0)
	var fast := "a %.0f degree aim swing in %.1fs sweeps the dim area: hint" % [TURN_TEST, VisionHint.TURN_S * 0.5]
	ok(swing, fast)
	ok(not slow, "the same turn over %.1fs does not" % (VisionHint.TURN_S * 4.0))

## Whether a turn of TURN_TEST degrees spread over `over` seconds (frames of Match.DT) makes the hint due.
func _turn_due(m: Match, over: float) -> bool:
	var vh := VisionHint.new()
	var P := m.player
	var n := int(over / Match.DT)
	var total := deg_to_rad(TURN_TEST)
	var hit := false
	for i in n + 1:
		var b := total * i / n
		P.inp["aim"] = P.pos + Vector3(cos(b), 0, sin(b)) * 6.0
		m.time += Match.DT
		hit = vh._turned(P.aim_dir(), m.time) or hit
	return hit

func _said(m: Match, rival: Hunter, a: float) -> void:
	var seen: Dictionary = Save.d["tutorial"]
	_place(m, rival, a, a + PI, SIDE_M)
	m.vision_hint = VisionHint.new()
	m._tip_t = VisionHint.AFTER_S + 1.0
	m.opts["tutorial"] = true
	m._tips()
	ok(not _on_lane(m) and not seen.has(VisionHint.KEY), "the tutorial course never shows it")
	m.opts.erase("tutorial")
	Settings.v["tips"] = false
	m._tips()
	ok(not _on_lane(m) and not seen.has(VisionHint.KEY), "with tips off it never shows")
	Settings.v["tips"] = true
	m._tips()
	var shown := _on_lane(m) and bool(seen.get(VisionHint.KEY, false))
	ok(shown, "with a rival hidden behind you it shows on the hint lane")
	m.hud.msgs.clear()
	m._tips()
	ok(not _on_lane(m), "and only once")
	var back: Dictionary = JSON.parse_string(JSON.stringify(Save.d))
	ok(bool(back["tutorial"].get(VisionHint.KEY, false)), "the save remembers it")
	var txt := VisionHint.TEXT
	var plain := txt.length() <= LINE_MAX and not txt.contains("%") and not txt.contains("[")
	ok(plain, "one short plain line ('%s')" % txt)

func _on_lane(m: Match) -> bool:
	return m.hud.msgs.texts().has(VisionHint.TEXT)
