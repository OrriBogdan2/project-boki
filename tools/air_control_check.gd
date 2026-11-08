extends "res://tools/abyss_check.gd"
## --air-control-check (playtest 11-08 items 4-9, docs/decisions/0022): the ONE movement model (Loco).
##   item 5: WASD in the air accelerates onto what you carry, counter-steer turns a backward drift forward fast,
##           along the keys you never pass the run cap, speed over it bleeds (never clipped), knocks carry
##   item 9: glide speed over cruise bleeds back within ~2 s, faster above a hunter's carry cap (Lace lowest)
##   item 8: opening the glider adds no horizontal speed: from a long fall, a jump, a dash and standing still
##   item 4: a fresh glide press mid air-dash glides that step at the dash's speed (Lace too)
##   farm = Training Area: the same keys give the same air speeds and the same glide-open step at home and in a match
## Prints "ACHECK ok|FAIL ..." and "ACHECK DONE, failures: N".

const DT := 1.0 / 60.0

func _air(hv: Vector2, keys: Vector2, cap: float, secs: float) -> Vector2:
	for i in int(round(secs / DT)):
		hv = Loco.air_step(hv, keys, cap, DT)
	return hv

func _glide(hv: Vector2, keys: Vector2, carry: float, secs: float) -> Vector2:
	var gs := Hunter.GLIDE_SPEED
	for i in int(round(secs / DT)):
		hv = Loco.glide_step(hv, keys * gs, gs, carry, DT)
	return hv

func _numbers() -> void:
	var cap := 4.55
	var t := 0.0
	var hv := Vector2(-5.0, 0.0)
	while hv.x <= 0.0 and t < 2.0:
		hv = Loco.air_step(hv, Vector2(1, 0), cap, DT)
		t += DT
	ok(t <= 0.15, "item 5: holding W against a 5 m/s backward drift turns it forward in %.2fs (<= 0.15)" % t)
	ok(_air(Vector2(-5, 0), Vector2(1, 0), cap, 0.5).x >= cap - 0.05, "item 5: ...and reaches run speed within 0.5s")
	ok(_air(Vector2(cap, 0), Vector2(1, 0), cap, 1.0).length() <= cap + 0.01,
		"item 5: keys along your run add nothing past the cap")
	var one := Loco.air_step(Vector2(15, 0), Vector2(1, 0), cap, DT).length()
	var later := _air(Vector2(15, 0), Vector2(1, 0), cap, 1.5).length()
	ok(one > 14.6 and later < cap + 1.0,
		"item 5: 15 m/s over the cap bleeds (%.2f after a step, %.2f after 1.5s), never clipped" % [one, later])
	ok(_air(Vector2(0, 8), Vector2(1, 0), cap, DT).y > 7.6,
		"item 5: a sideways knock keeps going while you steer (not overwritten)")
	ok(_air(Vector2(4, 0), Vector2.ZERO, cap, 0.5).x > 3.0, "item 5: no keys: the jump keeps its run-up")
	var bent := _air(Vector2(cap, 0), Vector2(0, 1), cap, 0.1)
	ok(bent.y > 1.5 and bent.x > 3.0 and bent.length() <= cap + 0.01,
		"item 5: sideways keys bend the arc, no snap (%s after 0.1s)" % str(bent))
	var farm_like := _air(Vector2.ZERO, Vector2(1, 0), cap, 0.2).x
	ok(farm_like >= cap * (1.0 - exp(-6.0 * 0.2)),
		"air control at least the old farm's (exp 6/s): %.2f m/s after 0.2s" % farm_like)
	var gs := Hunter.GLIDE_SPEED
	var carry := Loco.glide_carry("")
	var g1 := _glide(Vector2(12, 0), Vector2.ZERO, carry, DT).length()
	var g2 := _glide(Vector2(12, 0), Vector2.ZERO, carry, 2.0).length()
	ok(g1 > 11.7 and g2 <= gs + 0.5,
		"item 9: glide 12 m/s, no keys: %.2f after a step, %.2f after 2s (cruise %.1f)" % [g1, g2, gs])
	var g3 := _glide(Vector2(12, 0), Vector2(1, 0), carry, 2.0).length()
	ok(g3 <= gs + 1.0, "item 9: steering along holds a little longer but still bleeds (%.2f after 2s)" % g3)
	var lace := _glide(Vector2(17, 0), Vector2(1, 0), Loco.glide_carry("archer"), 0.5).length()
	var dflt := _glide(Vector2(17, 0), Vector2(1, 0), carry, 0.5).length()
	ok(lace < dflt, "item 9: Lace carries less from Shift into the glide (%.2f vs %.2f after 0.5s)" % [lace, dflt])
	var peak := 0.0
	var start := 99.0
	var dist := 0.0
	var tk := Loco.dash_time_k("archer")
	for i in int(round(0.3 * tk / DT)):
		var k := Loco.dash_k("archer", (i + 0.5) / (0.3 * tk / DT))
		peak = maxf(peak, k)
		start = minf(start, k)
		dist += k * DT
	ok(peak < 1.0 and start < 0.6 and absf(dist - 0.3) < 0.01,
		"item 9: Lace's dash peaks lower (%.2f of before), eases in/out (%.2f), keeps its distance" % [peak, start])

## A hunter `up` metres over a ground spot, moving `v`, keys off.
func _air_at(up: float, v: Vector3) -> void:
	_reset(w.random_ground() + Vector3(0, up, 0), v)
	h.inp["glide_press_only"] = true
	h.inp["glide_btn"] = false
	m.step(Match.DT)

## Opens the glider with a fresh Space press and returns [h-speed before, after the step it opened, opened].
func _press_glide() -> Array:
	var before := Vector2(h.vel.x, h.vel.z).length()
	h.inp["glide"] = true
	h.inp["jump"] = true
	m.step(Match.DT)
	h.inp["jump"] = false
	return [before, Vector2(h.vel.x, h.vel.z).length(), h.gliding]

func _match_items() -> void:
	_air_at(30.0, Vector3(3, -11, 0))
	var r := _press_glide()
	ok(r[2] and absf(r[1] - r[0]) < 0.1, "item 8: glide from a long fall: h-speed %.2f -> %.2f" % [r[0], r[1]])
	for i in 18: m.step(Match.DT)
	ok(h.vel.y > -HunterMove.glide_pull_vy - 0.2 and Vector2(h.vel.x, h.vel.z).length() <= r[0] + 0.05,
		"item 8: the fall is absorbed (v %.2f after 0.3s), not turned into speed (h %.2f)"
		% [h.vel.y, Vector2(h.vel.x, h.vel.z).length()])
	_air_at(2.0, Vector3(4.5, 2.0, 0))
	r = _press_glide()
	ok(r[2] and absf(r[1] - r[0]) < 0.1, "item 8: glide from a jump: h-speed %.2f -> %.2f" % [r[0], r[1]])
	_air_at(6.0, Vector3.ZERO)
	r = _press_glide()
	ok(r[2] and absf(r[1] - r[0]) < 0.1, "item 8: glide standing still in the air: h-speed %.2f -> %.2f" % [r[0], r[1]])
	for arch in ["", "archer"]:
		if arch == "": h.set_arch("")
		else: h.reclass(Arch.weight(arch), arch)
		_air_at(6.0, Vector3.ZERO)
		h.dash_with({"speed": 19.0, "time": 0.3, "dir": Vector2(1, 0)})
		m.step(Match.DT)
		m.step(Match.DT)
		r = _press_glide()
		ok(r[2] and h.roll_t <= 0.0 and absf(r[1] - r[0]) < 0.1,
			"items 4/8 (%s): a press 2 steps into an air dash glides that step at its speed (%.2f -> %.2f)"
			% [h.arch if h.arch != "" else "default", r[0], r[1]])
	h.set_arch("")
	var fsm := Loco.machine()
	ok(not fsm.go(Loco.S.GLIDING) and fsm.refused == 1 and fsm.is_in(Loco.S.GROUNDED),
		"FSM: no glide straight off the ground")
	ok(fsm.go(Loco.S.AIRBORNE) and fsm.go(Loco.S.GLIDING) and fsm.go(Loco.S.KNOCKED),
		"FSM: airborne, then the glider, then a knock (%s)" % " ".join(fsm.history))
	_air_at(6.0, Vector3.ZERO)
	_press_glide()
	h.dash_with({"speed": 19.0, "time": 0.3, "dir": Vector2(1, 0)})
	m.step(Match.DT)
	ok(h.roll_t > 0.0 and not h.gliding and h.loco.is_in(Loco.S.DASHING), "FSM: a dash from a glide folds the glider")
	_air_at(8.0, Vector3(-4, 0, 0))
	h.inp["move"] = Vector2(1, 0)
	var t := 0.0
	while h.vel.x <= 0.0 and t < 1.0:
		m.step(Match.DT)
		t += Match.DT
	ok(t <= 0.2, "item 6: falling backward, holding W carries you forward in %.2fs" % t)

## The same keys in the air at home and in a match (a fresh save's hero both places): vx every 0.1s holding D
## from a 3 m/s backward drift, and the step a fresh glide press opens the glider.
func _parity(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var pk := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(pk)
	Save.d["active"] = pk["uid"]
	Save.d["tutorial"]["home"] = true
	Save.d["tutorial"]["day1_done"] = true
	Econ.ensure()
	var arch := String(Save.d.get("arch", ""))
	var hm = load("res://scripts/home/home.gd").new()
	main.add_child(hm)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	hm.set_process(false)
	hm.ppos = Vector3(hm.ppos.x, 0, hm.ppos.z)
	hm.py = hm._ground_h(hm.ppos.x, hm.ppos.z) + 6.0
	hm.pvy = 0.0
	hm.pvel = Vector3(-3, 0, 0)
	hm.gliding = false
	hm.dash_t = 0.0
	var farm := []
	var farm_open := -1
	_press(Vector2(1, 0))
	for i in 36:
		if i == 18: Input.action_press("glide")
		hm._move_player(DT)
		if hm.gliding and farm_open < 0: farm_open = i
		if i % 6 == 5: farm.append(hm.pvel.x)
		await main.get_tree().process_frame
	Input.action_release("glide")
	_press(Vector2.ZERO)
	hm.queue_free()
	h.set_arch(arch)
	_air_at(6.0, Vector3(-3, 0, 0))
	h.vel = Vector3(-3, 0, 0)
	var game := []
	var game_open := -1
	h.inp["move"] = Vector2(1, 0)
	for i in 36:
		h.inp["glide"] = i >= 18
		h.inp["glide_btn"] = i >= 18
		m.step(Match.DT)
		if h.gliding and game_open < 0: game_open = i
		if i % 6 == 5: game.append(h.vel.x)
	var same := farm.size() == game.size()
	for i in mini(farm.size(), game.size()):
		same = same and absf(float(farm[i]) - float(game[i])) < 0.05
	var fmt := func(a: Array) -> String: return " ".join(a.map(func(x): return "%.2f" % x))
	ok(same,
		"farm = Training Area: air vx every 0.1s holding D from a 3 m/s backward drift (farm %s | match %s)"
		% [fmt.call(farm), fmt.call(game)])
	ok(farm_open == 18 and game_open == 18,
		"farm = Training Area: a fresh glide press opens it that step (farm %d, match %d)" % [farm_open, game_open])

func run(main: Node) -> void:
	_numbers()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	w = m.world
	h = m.hunters[0]
	h.set_arch("")
	for o in m.hunters:
		o.ctrl = "idle"
		if o != h: o.teleport(w.random_ground())
	h.ctrl = "local"
	m.opts["god"] = true
	_match_items()
	await _parity(main)
	m.queue_free()
	print("ACHECK DONE, failures: ", bad)
	main.get_tree().quit()
