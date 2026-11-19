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
	await _shiv()
	await _celeste()
	await _grimble()
	await _brall()
	print("TFB DONE, failures: %d" % fails)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Shift held `hold_s`, then let go.
func _hold_dash(m: Match, P: Hunter, hold_s: float) -> void:
	P.inp["dash_down"] = true
	P.do_dash()
	ac.step(m, hold_s, func(): P.inp["dash_down"] = true)
	P.inp["dash_down"] = false


## Joule (mage, Sparkle): the Wirerun stacks Static on a foe it crosses.
func _joule() -> void:
	var r: Array = ac.setup("mage", 5.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: MageKit = P.ak
	(r[3] as Hunter).teleport(home + Vector3(30, 0, 0))
	for before in [0, 3]:
		ac.fresh(T)
		K.sparks.clear()
		T.teleport(home + Vector3(5, 0, 0))
		P.teleport(home)
		ac.step(m, 0.2)
		P.dashes = P.max_dashes()
		if before > 0:
			K.add_spark(T, before)
		ac.aim_at(P, T.pos + Vector3(3, 0, 0))
		_hold_dash(m, P, 0.3)
		ac.step(m, 0.7)
		ok("joule: the Wirerun through a foe at %d Static leaves %d" % [before, before + 1],
				K.spark_n(T) == before + 1 and K.blowouts == 0, "stacks %d" % K.spark_n(T))
	await ac.done(m)


## Shiv (thief, Sable): a bolt flies its full range whatever the cursor; a missed empowered bolt gives no dash.
func _shiv() -> void:
	var r: Array = ac.setup("thief", 20.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: ThiefKit = P.ak
	T.teleport(home + Vector3(0, 0, 25.0))
	var rng := float(P.wpn["range"])
	for cursor_d in [2.0, 5.0]:
		ac.aim_at(P, home + Vector3(-cursor_d, 0, 0))
		ac.step(m, 0.1)
		var line := AimKit.entry(P, "aim")
		var line_len := 0.0
		if not line.is_empty():
			line_len = (line["to"] as Vector2).distance_to(line["from"] as Vector2)
		P.fire_cd = 0.0
		var fz := K.fizzles
		P.inp["fire"] = true
		m.step(DT)
		P.inp["fire"] = false
		ac.step(m, 0.6)
		var reach := _flat(K.last_bolt_end, P.pos)
		ok("shiv: cursor %.0f m away, the bolt still flies its full range" % cursor_d,
				K.fizzles == fz + 1 and absf(reach - rng) < 0.8, "%.1f m of %.1f" % [reach, rng])
		ok("shiv: cursor %.0f m away, the aim line shows the full range" % cursor_d,
				absf(line_len - rng) < 0.3, "line %.1f m" % line_len)
	# a miss: Vault, the empowered bolt flies at nothing, Shift pressed in flight: no Vault, no long dash
	P.inp["fire"] = false
	ac.step(m, 0.7)
	K.primed_t = 0.0
	P.teleport(home)
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	ac.step(m, 0.1)
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	ac.step(m, 0.52)
	P.inp["move"] = Vector2.ZERO
	ac.aim_at(P, home + Vector3(-6.0, 0, 0))
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	var primed := K.primed_hits
	P.do_dash()
	ac.step(m, 0.8)
	ok("shiv: an empowered bolt that misses gives no extra dash",
			K.primed_hits == primed and not K.chain.waiting and P.ex_cd <= 0.0 and P.dashes < 1.0 and P.roll_t <= 0.0,
			"ex_cd %.2f dashes %.2f" % [P.ex_cd, P.dashes])
	await ac.done(m)


## Celeste (rimewright, Neve): her darts bend onto the foe at the cursor only; a foe elsewhere pulls on nothing.
func _celeste() -> void:
	var r: Array = ac.setup("rimewright", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: RimewrightKit = P.ak
	var wd: Dictionary = P.wpn
	var cursor := home + Vector3(8.0, 0, 0)
	T.teleport(home + Vector3(30.0, 0, 20.0))
	ac.aim_at(P, cursor)
	ac.step(m, 0.1)
	var alone := _dart_end(m, P, K)
	T.teleport(cursor + Vector3(0, 0, 4.0))          # in front-ish, 4 m from the cursor
	ac.step(m, 0.3)
	var off_cursor := _dart_end(m, P, K)
	ok("celeste: a foe 4 m from the cursor does not pull her darts", alone.distance_to(off_cursor) < 0.3,
			"ends %.2f m apart" % alone.distance_to(off_cursor))
	T.teleport(cursor + Vector3(0, 0, 1.8))          # inside the cursor's reach: still a semi-homing dart
	ac.step(m, 0.3)
	var at_cursor := _dart_end(m, P, K)
	ok("celeste: a foe at the cursor still bends the darts in late", alone.distance_to(at_cursor) > 0.5,
			"ends %.2f m apart" % alone.distance_to(at_cursor))
	ok("celeste: the homing is weak (turn <= 8 rad/s, cursor reach <= 2.5 m, no free acquire)",
			float(wd["turn"]) <= 8.0 and float(wd["cursor_r"]) <= 2.5 and not wd.has("acquire"), str(wd["turn"]))
	await ac.done(m)


## Fires one dart and returns where it ended (its last position).
func _dart_end(m: Match, P: Hunter, K: RimewrightKit) -> Vector3:
	for d in K.darts:
		m.shots.erase(d["s"])
	K.darts.clear()
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	var dart: Dictionary = K.darts[0]["s"] if not K.darts.is_empty() else {}
	var last: Vector3 = dart.get("pos", P.pos)
	var t := 0.0
	while m.shots.has(dart) and t < 1.5:
		last = dart["pos"]
		m.step(DT)
		t += DT
	return last


## Grimble (dredge): Deep Reach hooks a foe and hauls it in; the Anchor Drop cast right after must hit it.
func _grimble() -> void:
	var r: Array = ac.setup("dredge", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: DredgeKit = P.ak
	ac.aim_at(P, T.pos)
	K.cd["rmb"] = 0.0
	K.cd["e"] = 0.0
	ac.tap(m, P)
	var t := 0.0
	while K.arrivals < 1 and t < 4.0:
		ac.step(m, 0.05)
		t += 0.05
	var gap := _flat(P.pos, T.pos)
	ac.aim_at(P, T.pos)
	var hp0 := T.hp
	P.ak.use_e()
	ac.step(m, 0.8)
	ok("grimble: hook then Anchor Drop hits the hauled foe", K.arrivals == 1 and K.anchors == 1 and hp0 - T.hp >= 20.0,
			"arrivals %d anchors %d gap %.2f took %.0f" % [K.arrivals, K.anchors, gap, hp0 - T.hp])
	await ac.done(m)


## Brall (juggernaut): the hook, then the pull with a Haul Slam, or a Slam after the pull, hits the hooked foe.
func _brall() -> void:
	var r: Array = ac.setup("juggernaut", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: JuggernautKit = P.ak
	ac.aim_at(P, T.pos)
	K.cd["e"] = 0.0
	P.ak.use_e()
	ac.step(m, 0.3)
	var hp0 := T.hp
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	ac.step(m, 0.3, func():
		P.inp["sec_hold"] = true
		ac.aim_at(P, T.pos))
	P.ak.use_e()
	var t := 0.0
	while K.warchain.arrivals < 1 and t < 3.0:
		ac.step(m, 0.02, func():
			P.inp["sec_hold"] = true
			ac.aim_at(P, T.pos))
		t += 0.02
	P.inp["sec_hold"] = false
	ac.step(m, 0.8)
	ok("brall: hook, hold RMB, E: the Haul Slam lands on the hooked foe", K.haul_slams == 1 and hp0 - T.hp >= 16.0,
			"slams %d took %.0f" % [K.haul_slams, hp0 - T.hp])
	await ac.done(m)


