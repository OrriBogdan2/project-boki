extends RefCounted
## --tester-feedback-check: the 11-19 tester notes, one block per note (docs/heroes: mage, thief, rimewright, dredge).
## Prints TFB PASS/FAIL lines and a DONE line.

const DT := 1.0 / 60.0

var main: Node
var ac: RefCounted
var fails := 0


func ok(what: String, cond: bool, info := "") -> void:
	print("TFB %-72s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	Save.no_write = true
	main = main_node
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main_node
	await _joule()
	await _joule_mash()
	await _shiv()
	await _celeste()
	await _grimble()
	await _brall()
	print("TFB DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Shift held `hold_s`, then let go.
func _hold_dash(m: Match, p_v: Hunter, hold_s: float) -> void:
	p_v.inp["dash_down"] = true
	p_v.do_dash()
	ac.step(m, hold_s, func(): p_v.inp["dash_down"] = true)
	p_v.inp["dash_down"] = false


## Joule (mage, Sparkle): the Wirerun stacks Static on a foe it crosses.
func _joule() -> void:
	var r: Array = ac.setup("mage", 5.0, "", true)
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	var k_v: MageKit = p_v.ak
	(r[3] as Hunter).teleport(home + Vector3(30, 0, 0))
	for before in [0, 3]:
		ac.fresh(t_v)
		k_v.sparks.clear()
		t_v.teleport(home + Vector3(5, 0, 0))
		p_v.teleport(home)
		ac.step(m, 0.2)
		p_v.dashes = p_v.max_dashes()
		if before > 0:
			k_v.add_spark(t_v, before)
		ac.aim_at(p_v, t_v.pos + Vector3(3, 0, 0))
		_hold_dash(m, p_v, 0.3)
		ac.step(m, 0.7)
		ok(
			"joule: the Wirerun through a foe at %d Static leaves %d" % [before, before + 1],
			k_v.spark_n(t_v) == before + 1 and k_v.blowouts == 0,
			"stacks %d" % k_v.spark_n(t_v)
		)
	await ac.done(m)


## Joule: Shift mashed during the streak with no charge back is dropped (no 4 m plain dash after it);
## with the charge back (a reset in the run) it plays a full second Wirerun.
func _joule_mash() -> void:
	for reset in [false, true]:
		var r: Array = ac.setup("mage", 40.0, "", true)
		var m: Match = r[0]
		var p_v: Hunter = r[1]
		var home: Vector3 = r[4]
		var k_v: MageKit = p_v.ak
		(r[2] as Hunter).teleport(home + Vector3(0, 0, 40))
		(r[3] as Hunter).teleport(home + Vector3(0, 0, -40))
		p_v.teleport(home)
		ac.step(m, 0.3)
		p_v.dashes = p_v.max_dashes()
		ac.aim_at(p_v, home + Vector3(20, 0, 0))
		p_v.inp["dash_down"] = true
		p_v.do_dash()
		m.step(DT)
		p_v.inp["dash_down"] = false
		ac.step(m, 0.05)
		if reset:
			k_v.grant_reset()
		p_v.inp["dash"] = true
		p_v.inp["dash_down"] = true
		m.step(DT)
		p_v.inp["dash"] = false
		ac.step(m, 0.1)
		p_v.inp["dash_down"] = false
		ac.step(m, 1.2)
		var went := _flat(p_v.pos, home)
		if reset:
			ok(
				"joule: Shift in the streak after a reset plays a full second Wirerun",
				k_v.run_n == 2 and went > 14.0,
				"runs %d went %.1f m" % [k_v.run_n, went]
			)
		else:
			ok(
				"joule: Shift mashed in the streak with no charge plays no tiny dash after it",
				k_v.run_n == 1 and p_v.ex_cd <= 0.0 and k_v.last_dash_kind == "wire" and went < 7.5,
				"runs %d ex_cd %.1f went %.1f m" % [k_v.run_n, p_v.ex_cd, went]
			)
		await ac.done(m)


## Shiv (thief, Sable): a bolt flies its full range whatever the cursor; a missed empowered bolt gives no dash.
func _shiv() -> void:
	var r: Array = ac.setup("thief", 20.0)
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	var k_v: ThiefKit = p_v.ak
	t_v.teleport(home + Vector3(0, 0, 25.0))
	var rng := float(p_v.wpn["range"])
	for cursor_d in [2.0, 5.0]:
		ac.aim_at(p_v, home + Vector3(-cursor_d, 0, 0))
		ac.step(m, 0.1)
		var line := AimKit.entry(p_v, "aim")
		var line_len := 0.0
		if not line.is_empty():
			line_len = (line["to"] as Vector2).distance_to(line["from"] as Vector2)
		p_v.fire_cd = 0.0
		var fz := k_v.fizzles
		p_v.inp["fire"] = true
		m.step(DT)
		p_v.inp["fire"] = false
		ac.step(m, 0.6)
		var reach := _flat(k_v.last_bolt_end, p_v.pos)
		ok(
			"shiv: cursor %.0f m away, the bolt still flies its full range" % cursor_d,
			k_v.fizzles == fz + 1 and absf(reach - rng) < 0.8,
			"%.1f m of %.1f" % [reach, rng]
		)
		ok(
			"shiv: cursor %.0f m away, the aim line shows the full range" % cursor_d,
			absf(line_len - rng) < 0.3,
			"line %.1f m" % line_len
		)
	# a miss: Vault, the empowered bolt flies at nothing, Shift pressed in flight: no Vault, no long dash
	p_v.inp["fire"] = false
	ac.step(m, 0.7)
	k_v.primed_t = 0.0
	p_v.teleport(home)
	p_v.dashes = p_v.max_dashes()
	p_v.ex_cd = 0.0
	ac.step(m, 0.1)
	p_v.inp["move"] = Vector2(0, 1)
	p_v.do_dash()
	ac.step(m, 0.52)
	p_v.inp["move"] = Vector2.ZERO
	ac.aim_at(p_v, home + Vector3(-6.0, 0, 0))
	p_v.fire_cd = 0.0
	p_v.inp["fire"] = true
	m.step(DT)
	p_v.inp["fire"] = false
	var primed := k_v.primed_hits
	p_v.do_dash()
	ac.step(m, 0.8)
	ok(
		"shiv: an empowered bolt that misses gives no extra dash",
		(
			k_v.primed_hits == primed
			and not k_v.chain.waiting
			and p_v.ex_cd <= 0.0
			and p_v.dashes < 1.0
			and p_v.roll_t <= 0.0
		),
		"ex_cd %.2f dashes %.2f" % [p_v.ex_cd, p_v.dashes]
	)
	await ac.done(m)


## Celeste (rimewright, Neve): her darts bend onto the foe at the cursor only; a foe elsewhere pulls on nothing.
func _celeste() -> void:
	var r: Array = ac.setup("rimewright", 8.0)
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	var k_v: RimewrightKit = p_v.ak
	var wd: Dictionary = p_v.wpn
	var cursor := home + Vector3(8.0, 0, 0)
	t_v.teleport(home + Vector3(30.0, 0, 20.0))
	ac.aim_at(p_v, cursor)
	ac.step(m, 0.1)
	var alone := _dart_end(m, p_v, k_v)
	t_v.teleport(cursor + Vector3(0, 0, 4.0))  # in front-ish, 4 m from the cursor
	ac.step(m, 0.3)
	var off_cursor := _dart_end(m, p_v, k_v)
	ok(
		"celeste: a foe 4 m from the cursor does not pull her darts",
		alone.distance_to(off_cursor) < 0.3,
		"ends %.2f m apart" % alone.distance_to(off_cursor)
	)
	t_v.teleport(cursor + Vector3(0, 0, 1.8))  # inside the cursor's reach: still a semi-homing dart
	ac.step(m, 0.3)
	var at_cursor := _dart_end(m, p_v, k_v)
	ok(
		"celeste: a foe at the cursor still bends the darts in late",
		alone.distance_to(at_cursor) > 0.5,
		"ends %.2f m apart" % alone.distance_to(at_cursor)
	)
	ok(
		"celeste: the homing is weak (turn <= 8 rad/s, cursor reach <= 2.5 m, no free acquire)",
		float(wd["turn"]) <= 8.0 and float(wd["cursor_r"]) <= 2.5 and not wd.has("acquire"),
		str(wd["turn"])
	)
	await ac.done(m)


## Fires one dart and returns where it ended (its last position).
func _dart_end(m: Match, p_v: Hunter, k_v: RimewrightKit) -> Vector3:
	for d in k_v.darts:
		m.shots.erase(d["s"])
	k_v.darts.clear()
	p_v.fire_cd = 0.0
	p_v.inp["fire"] = true
	m.step(DT)
	p_v.inp["fire"] = false
	var dart: Dictionary = k_v.darts[0]["s"] if not k_v.darts.is_empty() else {}
	var last: Vector3 = dart.get("pos", p_v.pos)
	var t := 0.0
	while m.shots.has(dart) and t < 1.5:
		last = dart["pos"]
		m.step(DT)
		t += DT
	return last


## Grimble (dredge): Deep Reach hooks a foe and reels it in; the Anchor Drop lands on it whether E is pressed
## during the reel (it waits for the arrival, planted) or after it, and with a move key held.
func _grimble() -> void:
	for c in [["mid-reel E", false, false], ["mid-reel E, strafing", false, true], ["E after, strafing", true, true]]:
		var late: bool = c[1]
		var strafe: bool = c[2]
		var r: Array = ac.setup("dredge", 9.0)
		var m: Match = r[0]
		var p_v: Hunter = r[1]
		var t_v: Hunter = r[2]
		var k_v: DredgeKit = p_v.ak
		ac.aim_at(p_v, t_v.pos)
		k_v.cd["rmb"] = 0.0
		k_v.cd["e"] = 0.0
		ac.tap(m, p_v)
		var hp0 := t_v.hp
		var pressed := false
		var waited := true
		var t := 0.0
		while t < 4.0 and k_v.anchors < 1:
			if strafe:
				p_v.inp["move"] = Vector2(0, 1)
			if not pressed and (k_v.arrivals > 0 if late else (not k_v.pull.is_empty() and t > 0.6)):
				pressed = true
				if late:
					ac.aim_at(p_v, t_v.pos)
				p_v.ak.use_e()
				waited = late or (k_v.anchors == 0 and k_v.wind <= 0.0)
			m.step(DT)
			t += DT
		p_v.inp["move"] = Vector2.ZERO
		ac.step(m, 0.6)
		ok(
			"grimble: hook, %s: the Anchor Drop hits the hauled foe" % c[0],
			waited and k_v.arrivals == 1 and k_v.anchors == 1 and hp0 - t_v.hp >= 25.0,
			"arrivals %d anchors %d took %.0f" % [k_v.arrivals, k_v.anchors, hp0 - t_v.hp]
		)
		await ac.done(m)


## Brall (juggernaut): the hook, then the pull with a Haul Slam, or a Slam after the pull, hits the hooked foe.
func _brall() -> void:
	var r: Array = ac.setup("juggernaut", 8.0)
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var k_v: JuggernautKit = p_v.ak
	ac.aim_at(p_v, t_v.pos)
	k_v.cd["e"] = 0.0
	p_v.ak.use_e()
	ac.step(m, 0.3)
	var hp0 := t_v.hp
	k_v.ch_rmb = 1.0
	k_v.cd["rmb"] = 0.0
	p_v.inp["sec_hold"] = true
	p_v.ak.press_rmb()
	ac.step(
		m,
		0.3,
		func():
			p_v.inp["sec_hold"] = true
			ac.aim_at(p_v, t_v.pos)
	)
	p_v.ak.use_e()
	var t := 0.0
	while k_v.warchain.arrivals < 1 and t < 3.0:
		ac.step(
			m,
			0.02,
			func():
				p_v.inp["sec_hold"] = true
				ac.aim_at(p_v, t_v.pos)
		)
		t += 0.02
	p_v.inp["sec_hold"] = false
	ac.step(m, 0.8)
	ok(
		"brall: hook, hold RMB, E: the Haul Slam lands on the hooked foe",
		k_v.haul_slams == 1 and hp0 - t_v.hp >= 16.0,
		"slams %d took %.0f" % [k_v.haul_slams, hp0 - t_v.hp]
	)
	await ac.done(m)
