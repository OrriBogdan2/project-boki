extends RefCounted
## --sparkle-dash-check: on Sparkle Shift is only ever her Wirerun. Spent, a press
## on the ground, in the air or buffered during the run does nothing (no class dodge, no air tumble); for
## every archetype that owns its dash no class dodge ever fires on Shift. The Wirerun hands no momentum
## on: 0.3 s after it ends she is at run speed (at most the glider's cruise, if one opened) with dash,
## jump and glide held, and the exit never tops exit_cap x run. The streak builds (dash.ramp) and the
## Storm Rod's hold slows her by rmb.self_slow, ramping in over rmb.slow_in. Prints SDCHECK lines.

var main: Node
var ac: RefCounted
var fails := 0
var n := 0
var dodges: Array = []          # [hunter, ability id] of every "dodge" slot use (CombatBus)
const DT := 1.0 / 60.0

func ok(name_: String, cond: bool, info := "") -> void:
	n += 1
	print("SDCHECK %-64s %s  %s" % [name_, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func _used(h, id: String, slot: String) -> void:
	if slot == "dodge": dodges.append([h, id])

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _speed(P: Hunter) -> float:
	return Vector2(P.vel.x, P.vel.z).length()

## Holds these keys for a step.
func _keys(P: Hunter, keys: Dictionary) -> void:
	for k in keys:
		P.inp[k] = keys[k]

func run(main_node: Node) -> void:
	main = main_node
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main_node
	CombatBus.ability_used.connect(_used)
	await _every_kit()
	await _sparkle()
	print("SDCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Every archetype with its own dash: Shift spent or not, on the ground or in the air, never runs the class dodge.
func _every_kit() -> void:
	for arch in Arch.ids():
		var r: Array = ac.setup(String(arch), 6.0, "", false)
		var m: Match = r[0]
		var P: Hunter = r[1]
		var home: Vector3 = r[4]
		if P.ak == null or P.ak.dash_def().is_empty():
			await ac.done(m)
			continue
		var cls_id := String(P.dodge_def.id) if P.dodge_def else "dash"
		dodges.clear()
		ac.step(m, 0.2)
		for spent in [true, false]:
			for air in [false, true]:
				P.teleport(home)
				P.vel = Vector3.ZERO
				ac.step(m, 0.3)
				P.roll_t = 0.0
				P.dashes = 0.0 if spent else P.max_dashes()
				P.ex_cd = 0.0
				if air:
					P.pos.y = home.y + 3.0
					P.grounded = false
				P.inp["aim"] = home + Vector3(8, 0.9, 0)
				P.inp["dash_down"] = true
				P.do_dash()
				ac.step(m, 0.3, func(): P.inp["dash_down"] = true)
				P.inp["dash_down"] = false
				ac.step(m, 1.5)
		var bad := dodges.filter(func(d): return d[0] == P and String(d[1]) == cls_id)
		ok("%s: Shift never runs the class dodge (%s), spent or not, ground or air" % [arch, cls_id], bad.is_empty(),
				"%d class dodges of %d dodge uses" % [bad.size(), dodges.size()])
		await ac.done(m)

func _sparkle() -> void:
	var r: Array = ac.setup("mage", 14.0, "", false)     # (a long strip: the full run is 11.5 m plus its ease)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	(r[2] as Hunter).teleport(home + Vector3(6, 0, -9))     # the dummy off the run line: she'd plough it along
	var K: MageKit = P.ak
	var dd: Dictionary = K.dash_def()
	var run := P.base_speed
	P.inp["aim"] = home + Vector3(8, 0.9, 0)
	ac.step(m, 0.2)
	# 1. spent on the ground: nothing moves, no cooldown of a long dash starts
	P.dashes = 0.0
	P.ex_cd = 0.0
	dodges.clear()
	P.inp["dash_down"] = true
	P.do_dash()
	ac.step(m, 0.5, func(): P.inp["dash_down"] = true)
	P.inp["dash_down"] = false
	ok("spent, ground: Shift is denied (no roll, no tumble cooldown, no hold)",
			P.roll_t <= 0.0 and P.ex_cd <= 0.0 and K.wire.is_empty() and dodges.is_empty()
			and _flat(P.pos, home) < 0.05,
			"roll %.2f ex_cd %.2f moved %.2f" % [P.roll_t, P.ex_cd, _flat(P.pos, home)])
	ok("spent: the HUD gets no long-dash segment", not K.has_long_dash())
	# 2. spent in the air: the same
	P.teleport(home)
	ac.step(m, 0.2)
	P.pos.y = home.y + 3.0
	P.grounded = false
	P.vel = Vector3.ZERO
	P.dashes = 0.0
	P.inp["dash_down"] = true
	P.do_dash()
	m.step(DT)
	P.inp["dash_down"] = false
	ok("spent, air: Shift is denied (no air tumble)",
			P.roll_t <= 0.0 and P.ex_cd <= 0.0 and K.wire.is_empty() and dodges.is_empty(),
			"roll %.2f ex_cd %.2f" % [P.roll_t, P.ex_cd])
	ac.step(m, 1.5)
	# 3. with a charge: the hold starts, the release runs; a second Shift pressed during the run does nothing after it
	P.teleport(home)
	P.vel = Vector3.ZERO
	ac.step(m, 0.3)
	P.dashes = P.max_dashes()
	dodges.clear()
	P.inp["dash_down"] = true
	P.do_dash()
	ok("charged: Shift starts the Wirerun hold", not K.wire.is_empty() and P.dashes < 1.0)
	ac.step(m, 0.3, func(): P.inp["dash_down"] = true)
	P.inp["dash_down"] = false
	ac.step(m, 0.1)
	var v0 := P.roll_speed
	ok("released: the streak runs and its start builds (first step under full speed)",
			P.roll_t > 0.0 and K.run_t > 0.0 and v0 < K.run_full - 0.5, "%.1f of %.1f m/s" % [v0, K.run_full])
	P.inp["dash"] = true            # Shift again, mid-run: buffered by the dash buffer
	P.do_dash()
	P.inp["dash"] = false
	ac.step(m, 0.2)
	ok("the streak reaches full speed", absf(P.roll_speed - K.run_full) < 0.01 or P.roll_t <= 0.0,
			"%.1f m/s" % P.roll_speed)
	var t_end := 0.0
	var pk := {"top": 0.0}        # (a lambda copies a float it captures: a dictionary it shares)
	var st := 0.0
	while st < 3.0 and P.roll_t > 0.0:
		m.step(DT)
		st += DT
	t_end = st
	var far_roll := _flat(P.pos, home)
	ac.step(m, 0.3, func(): pk["top"] = maxf(float(pk["top"]), _speed(P)))
	var top := float(pk["top"])
	var far := _flat(P.pos, home)
	ok("a Shift buffered during the run fires nothing after it (one dodge use, no second roll, still spent)",
			P.roll_t <= 0.0 and dodges.size() == 1 and P.dashes < 1.0 and K.wire.is_empty(),
			"dodge uses %d dashes %.2f" % [dodges.size(), P.dashes])
	ok("a 0.3 s hold's streak runs about %.1f m" % K.wire_len(0.3), absf(far_roll - K.wire_len(0.3)) < 0.6,
			"%.1f m" % far_roll)
	ok("...and its exit coasts under 1 m more", far - far_roll < 1.0 and far >= far_roll, "stopped at %.1f m" % far)
	ok("no carry: 0.3 s after the run ends she is at run speed or under (nobody moving)", _speed(P) <= run + 0.05,
			"%.2f vs run %.2f, peak after %.2f" % [_speed(P), run, top])
	var cap := run * float(dd["exit_cap"])
	ok("the exit never tops exit_cap x run", top <= cap + 0.05, "%.2f vs cap %.2f" % [top, cap])
	ac.step(m, 1.0)
	# 4. dash + jump + glide held through a full hold: the run, the jump out of it and the glider all start
	# from run speed
	var cruise := maxf(run, Hunter.GLIDE_SPEED * (1.0 + P.gear_stat("glide_speed")))
	for air in [false, true]:
		P.teleport(home)
		P.vel = Vector3.ZERO
		ac.step(m, 0.3)
		P.dashes = P.max_dashes()
		P.glide_cd = 0.0
		if air:
			P.pos.y = home.y + 4.0
			P.grounded = false
		P.inp["move"] = Vector2(1, 0)
		P.inp["aim"] = P.pos + Vector3(8, 0.9, 0)
		P.inp["dash_down"] = true
		P.do_dash()
		var full_t := float(dd["hold"]) + 0.05
		ac.step(m, full_t, func(): _keys(P, {"dash_down": true, "move": Vector2(1, 0)}))
		P.inp["dash_down"] = false
		var ran := false
		var ended := -1.0
		var tt := 0.0
		var flip := false
		var peak := 0.0
		var at03 := -1.0
		while tt < 4.0 and (ended < 0.0 or tt - ended < 0.32):
			P.inp["move"] = Vector2(1, 0)
			P.inp["jump"] = true
			flip = not flip
			P.inp["glide"] = flip
			m.step(DT)
			tt += DT
			if P.roll_t > 0.0: ran = true
			if ran and ended < 0.0 and P.roll_t <= 0.0:
				ended = tt
			if ended >= 0.0:
				peak = maxf(peak, _speed(P))
				if at03 < 0.0 and tt - ended >= 0.3: at03 = _speed(P)
		P.inp["jump"] = false
		P.inp["glide"] = false
		P.inp["move"] = Vector2.ZERO
		var where := "air" if air else "ground"
		ok("%s Wirerun with dash+jump+glide held: 0.3 s after it ends, speed <= run speed (glider cruise at most)"
				% where, ran and at03 >= 0.0 and at03 <= cruise + 0.05,
				"%.2f vs %.2f (run %.2f) gliding %s" % [at03, cruise, run, P.gliding])
		ok("%s: no handoff boost after it (peak <= exit_cap x run)" % where, peak <= run * float(dd["exit_cap"]) + 0.05,
				"peak %.2f" % peak)
		ok("%s: the glider took no handoff" % where, P._handoff.is_empty())
		ac.step(m, 1.5)
	# 5. a full hold covers its full length despite the build
	P.teleport(home)
	P.vel = Vector3.ZERO
	ac.step(m, 0.3)
	P.dashes = P.max_dashes()
	P.inp["aim"] = home + Vector3(8, 0.9, 0)
	P.inp["dash_down"] = true
	P.do_dash()
	ac.step(m, float(dd["hold"]) + 0.05, func(): P.inp["dash_down"] = true)
	P.inp["dash_down"] = false
	m.step(DT)
	st = 0.0
	while st < 3.0 and P.roll_t > 0.0:
		m.step(DT)
		st += DT
	far_roll = _flat(P.pos, home)
	ac.step(m, 1.0)
	var full_len := float(dd["dist"][1])
	ok("a full hold's streak covers %.1f m despite the build" % full_len, absf(far_roll - full_len) < 0.6,
			"%.1f m" % far_roll)
	ok("...and she stops within 1 m past it", _flat(P.pos, home) - far_roll < 1.0,
			"stopped at %.1f m" % _flat(P.pos, home))
	ac.step(m, 1.0)
	# 6. Storm Rod: the hold slows her by self_slow, ramping in over slow_in
	var rd: Dictionary = K.rmb_def()
	P.teleport(home)
	ac.step(m, 0.3)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	P.inp["move"] = Vector2(1, 0)
	ac.step(m, 1.0, func(): P.inp["move"] = Vector2(1, 0))
	var walk := _speed(P)
	P.inp["sec_hold"] = true
	K.press_rmb()
	m.step(DT)
	var k0 := K.move_k()
	ac.step(m, float(rd["slow_in"]) + 0.2, func(): _keys(P, {"sec_hold": true, "move": Vector2(1, 0)}))
	var slowed := _speed(P)
	var want := 1.0 - float(rd["self_slow"])
	ok("Storm Rod: the slow ramps in (near full pace at the press)", k0 > 0.95, "move_k %.2f" % k0)
	ok("Storm Rod held: she walks at %d%% of her pace" % int(round(want * 100.0)),
			absf(K.move_k() - want) < 0.001 and absf(slowed / walk - want) < 0.03,
			"%.2f -> %.2f m/s (%.0f%%)" % [walk, slowed, slowed / walk * 100.0])
	P.inp["sec_hold"] = false
	P.inp["move"] = Vector2.ZERO
	ac.step(m, 1.0)
	ok("Storm Rod thrown: her pace is back", K.move_k() >= 0.999)
	await ac.done(m)
