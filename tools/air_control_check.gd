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
	_every_shift()
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

## A ground tile with LANE m of flat, open ground east of it (no wall to stop a run, a dash or a glide).
const LANE := 26
func _open_lane() -> Vector3:
	for z in range(4, w.h - 4):
		for x in range(4, w.w - LANE - 4):
			var lv := w.level[w.idx(x, z)]
			var clear := true
			for i in LANE:
				var j := w.idx(x + i, z)
				clear = clear and w.kind[j] == World.T_GROUND and w.level[j] == lv
				clear = clear and not w.is_block(x + i + 0.5, z + 0.5)
				if not clear: break
			if clear:
				return Vector3(x + 0.5, lv * World.LEVEL, z + 0.5)
	return Vector3.INF

## Items 6/7: one chain holding D: run, Shift, jump out of it, a glide press, let go, land. The h-speed never
## drops more than 30% in one step (no sudden stop), never jumps up except as a dash starts (no spike),
## and the step after touchdown you are still moving.
func _chain() -> void:
	var at := _open_lane()
	if at == Vector3.INF:
		ok(false, "items 6/7: no open lane on this map to run the chain on")
		return
	_reset(at, Vector3.ZERO)
	h.inp["glide_press_only"] = true
	h.inp["move"] = Vector2(1, 0)
	var trace := []
	var worst_drop := 0.0
	var worst_gain := 0.0
	var land := [-1.0, -1.0]
	var prev := 0.0
	var was_air := false
	for i in 150:
		h.inp["dash"] = i == 30
		h.inp["jump"] = i == 44 or i == 56
		h.inp["glide"] = i >= 56 and i < 90
		m.step(Match.DT)
		var hs := Vector2(h.vel.x, h.vel.z).length()
		var dashing := h.roll_t > 0.0 or (h.ak != null and h.ak.in_dash())
		if i > 0 and not (dashing and hs > prev):
			worst_gain = maxf(worst_gain, hs - prev)
		if i > 0 and prev > 0.5:
			worst_drop = maxf(worst_drop, (prev - hs) / prev)
		if was_air and h.grounded and land[0] < 0.0 and i > 60:
			land = [prev, hs]
		was_air = not h.grounded
		prev = hs
		if i % 10 == 9: trace.append("%s %.1f" % [h.loco.state_name().left(4), hs])
	h.inp["move"] = Vector2.ZERO
	h.inp["glide"] = false
	print("ACHECK note chain h-speed every 1/6 s: %s" % ", ".join(trace))
	# (the worst is the jump out of the dash: it keeps Loco.dash_jump_keep, 0.75, plus that step's air drag)
	ok(worst_drop <= 0.3, "item 7: run > dash > jump > glide > land never loses over 30%% in a step (worst %d%%)"
		% int(100.0 * worst_drop))
	ok(worst_gain <= 2.0,
		"item 7: and never gains over 2 m/s in a step outside a dash's start (worst %.2f)" % worst_gain)
	ok(land[0] > 0.0 and land[1] >= land[0] * 0.9, "item 6: the step after touchdown you keep moving (%.2f -> %.2f m/s)"
		% [land[0], land[1]])

## Item 4 for every Hunter's own Shift: a fresh glide press 2 steps into an air Shift opens the glider that step,
## and 0.1 s later the glide still carries the speed it started with (no stop when the kit's dash winds down).
## A Shift whose kit keeps it (its own move, not a plain dash) is FLAGGED, not silently excepted.
func _every_shift() -> void:
	var cls0 := h.cls
	for arch in Arch.ORDER:
		h.reclass(Arch.weight(arch), arch)
		_air_at(6.0, Vector3(0, Hunter.JUMP_V, 0))      # rising, high up (no wall in reach): any kit air Shift goes
		h.dashes = h.max_dashes()
		h.inp["move"] = Vector2(1, 0)
		h.inp["dash"] = true
		m.step(Match.DT)
		m.step(Match.DT)
		var fired := h.roll_t > 0.0 or (h.ak != null and h.ak.in_dash())
		var r := _press_glide()
		for i in 6: m.step(Match.DT)
		var later := Vector2(h.vel.x, h.vel.z).length()
		h.inp["move"] = Vector2.ZERO
		h.inp["glide"] = false
		if not fired:
			print("ACHECK note item 4 (%s): no Shift move running 2 steps after the press: nothing to cancel" % arch)
		elif not r[2]:
			print("ACHECK FLAG item 4 (%s): Shift in the air at %.1f m/s is the kit's own move (%s): no glide cancel"
				% [arch, r[0], h.move_kind])
		else:
			ok(absf(r[1] - r[0]) < 0.1 and later >= minf(r[0], Hunter.GLIDE_SPEED) * 0.75,
				"item 4 (%s): Shift then a glide press: glides that step, h-speed %.2f -> %.2f, %.2f after 0.1s"
				% [arch, r[0], r[1], later])
	h.reclass(cls0, "")

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
	# the same Shift dash (Lace's eased one) at home and in a match: the same speed every 0.05 s
	Save.d["arch"] = "archer"
	hm.gliding = false
	hm.py = hm._ground_h(hm.ppos.x, hm.ppos.z) + 6.0
	hm.pvy = 0.0
	hm.start_dash(Vector2(1, 0), 16.0, 0.3)
	var farm_dash := []
	for i in 30:
		hm._move_player(DT)
		if i % 3 == 2: farm_dash.append(hm.pvel.x)
	Save.d["arch"] = arch
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
	h.reclass(Arch.weight("archer"), "archer")
	_air_at(6.0, Vector3.ZERO)
	h.inp["move"] = Vector2.ZERO
	h.inp["glide"] = false
	h.inp["glide_btn"] = false
	h.dash_with({"speed": 16.0, "time": 0.3, "dir": Vector2(1, 0)})
	var game_dash := []
	for i in 30:
		m.step(Match.DT)
		if i % 3 == 2: game_dash.append(h.vel.x)
	h.set_arch(arch)
	ok(_same(farm_dash, game_dash), "farm = Training Area: Lace's dash vx every 0.05s (farm %s | match %s)"
		% [_fmt(farm_dash), _fmt(game_dash)])
	var same := _same(farm, game)
	ok(same,
		"farm = Training Area: air vx every 0.1s holding D from a 3 m/s backward drift (farm %s | match %s)"
		% [_fmt(farm), _fmt(game)])
	ok(farm_open == 18 and game_open == 18,
		"farm = Training Area: a fresh glide press opens it that step (farm %d, match %d)" % [farm_open, game_open])

func _same(a: Array, b: Array) -> bool:
	var same := a.size() == b.size()
	for i in mini(a.size(), b.size()):
		same = same and absf(float(a[i]) - float(b[i])) < 0.05
	return same

func _fmt(a: Array) -> String:
	return " ".join(a.map(func(x): return "%.2f" % x))

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
	_chain()
	await _parity(main)
	m.queue_free()
	print("ACHECK DONE, failures: ", bad)
	main.get_tree().quit()
