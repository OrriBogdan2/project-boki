extends "res://tools/pin_bjorn_owner_check.gd"
## --lace-playtest-check: the owner's 11-08 playtest on Lace (items 18, 19, 20 and the two "ALSO" notes), on the
## training strip of --archer-combo-check. 18: the Heavy Shot's needle rides the bow's nock point and the shot
## leaves the bow toward the cursor, the bar runs bow -> cursor. RMB leaves nothing behind (no spent arrow,
## stake or scorch). 19: Starpiercer's first arrow leaves the frame X is pressed, from the bow, the cast look
## alongside; the next presses loose at once after the recover. 20: the perfect window is tuning.json's
## (0.35 s), the rim glow is on her body and bow only inside it, a perfect release pulses it. E: a foe slowed
## by the Hail Wall keeps y velocity 0, stays grounded and takes no squash, hold or knock for the whole slow.
## Prints AKCHECK lines like --archetype-check.

func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("lace_playtest_check", self)
	await lace()
	print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func lace() -> void:
	var r := setup("archer", 7.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: ArcherKit = P.ak
	P.equip("longbow", 0)
	step(m, 0.3)
	_heavy_on_the_bow(m, P, T, K, home)
	_heavy_leaves_nothing(m, P, T, T2, K, home, lv)
	_ult_on_press(m, P, T, K, home)
	_perfect_window(m, P, T, K)
	_slow_no_bounce(m, P, T, K, home)
	await done(m)

## The shot our kit skinned most recently, or {}.
func _last_shot(m: Match, P: Hunter, kind: String) -> Dictionary:
	for i in range(m.shots.size() - 1, -1, -1):
		var sh: Dictionary = m.shots[i]
		if sh["by"] == P and String((sh["x"] as Dictionary).get("pin", "")) == kind:
			return sh
	return {}

# ------------------------------------------------------------------ 18: the Heavy Shot on the bow
func _heavy_on_the_bow(m: Match, P: Hunter, T: Hunter, K: ArcherKit, home: Vector3) -> void:
	fresh(T)
	T.teleport(home + Vector3(7.0, 0, 0))
	K.cd["rmb"] = 0.0
	var hold := rmb_at.bind(P, T.pos)
	P.inp["sec_hold"] = true
	K.press_rmb()
	step(m, 0.5, hold)
	var n := K.needle
	var nock := HeroVfx.of(m).anchor_pos(P, "nock")
	var bow := K.draw.bow_at()
	var want_len := float(Tuning.of("lace")["needle_len_m"]) * float(P.cdat.get("scale", 1.0))
	ok("18 needle: nocked on the bow's nock point while the Heavy Shot winds up",
		n.visible and n.eye.distance_to(nock) < 0.01 and absf(n.eye.distance_to(n.tip) - want_len) < 0.02,
		"eye %s nock %s len %.2f" % [str(n.eye), str(nock), n.eye.distance_to(n.tip)])
	var bar := AimKit.entry(P, "rmb_bar")
	ok("18 bar: the Heavy Shot's bar starts at the bow and runs toward the cursor",
		AimKit.shown(P, "rmb_bar")
			and (bar.get("from", Vector2.ZERO) as Vector2).distance_to(Vector2(bow.x, bow.z)) < 0.05,
		"from %s bow %s" % [str(bar.get("from")), str(bow)])
	step(m, 0.7, hold)
	bow = K.draw.bow_at()
	P.inp["sec_hold"] = false
	m.step(DT)
	var sh := _last_shot(m, P, "heavy")
	var v: Vector2 = sh.get("vel", Vector2.ZERO)
	var start: Vector3 = (sh.get("pos", Vector3(999, 0, 999)) as Vector3) - Vector3(v.x, 0, v.y) * DT
	var to_cursor := Vector2(T.pos.x - bow.x, T.pos.z - bow.z).normalized()
	ok("18 shot: the Heavy Shot leaves the bow's nock point (not the body) and flies bow -> cursor",
		not sh.is_empty() and start.distance_to(bow) < 0.15 and v.normalized().distance_to(to_cursor) < 0.03,
		"start %s bow %s dir off %.3f" % [str(start), str(bow),
			v.normalized().distance_to(to_cursor) if not sh.is_empty() else 9.0])
	ok("18 model: the bow anchor is a point on her body at bow height, not her feet",
		bow.y > P.pos.y + 0.6 and bow.y < P.pos.y + 1.8
			and Vector2(bow.x - P.pos.x, bow.z - P.pos.z).length() < 1.2, str(bow - P.pos))
	step(m, 1.5)

# ------------------------------------------------------------------ RMB leaves nothing behind
func _heavy_leaves_nothing(m: Match, P: Hunter, T: Hunter, T2: Hunter, K: ArcherKit, home: Vector3, lv: int) -> void:
	# a miss into open ground, then a wall pin: no spent arrow, no stake, no scorch and no lingering look either way
	fresh(T)
	fresh(T2)
	T.teleport(home + Vector3(-9.0, 0, 9.0))
	T2.teleport(home + Vector3(-9.0, 0, -9.0))
	var V := HeroVfx.of(m)
	var shown := func() -> int:
		var c := 0
		for e in K.fx.spent:
			if (e["node"] as Node3D).visible: c += 1
		return c
	var lingering := func() -> int:
		var c := 0
		for e in V.live:
			if (e["node"] as Node3D).visible and float(e.get("dur", 0.0)) > 0.6: c += 1
		return c
	var spent0: int = shown.call()
	var live0: int = lingering.call()
	K.cd["rmb"] = 0.0
	var far := home + Vector3(10.0, 0, 0)
	P.inp["sec_hold"] = true
	K.press_rmb()
	step(m, 1.2, rmb_at.bind(P, far))
	P.inp["sec_hold"] = false
	step(m, 1.2)
	ok("RMB miss: the Heavy Shot that lands on open ground leaves no arrow, prop or decal",
		shown.call() == spent0 and lingering.call() == live0
			and not K.fx.live.values().any(func(e): return e["kind"] == "heavy"),
		"spent %d -> %d lingering %d -> %d" % [spent0, shown.call(), live0, lingering.call()])
	var moves: Dictionary = HeroVfx.data("archer")["moves"]
	var decal := ""
	for mv in ["heavy_go", "heavy_hit", "heavy_pin"]:
		for layer in (moves[mv] as Dictionary).get("fx", []):
			var life: Variant = layer.get("life", 0.0)
			if String(layer["p"]) in ["scorch", "thread"] or (life is float and float(life) > 0.6):
				decal = "%s %s" % [mv, layer["p"]]
	ok("RMB data: none of the Heavy Shot's looks is a decal or a lingering mesh (over 0.6 s; the trail rides the shot)",
		decal == "", decal)
	# the wall pin
	fresh(T)
	T.teleport(home + Vector3(7.0, 0, 0))
	_wall_at(m, T.pos, lv, 2)
	K.cd["rmb"] = 0.0
	var pins0 := K.pins
	P.inp["sec_hold"] = true
	K.press_rmb()
	step(m, 1.2, rmb_at.bind(P, T.pos))
	P.inp["sec_hold"] = false
	step(m, 1.2)
	ok("RMB wall pin: the pin lands and leaves nothing standing in the wall",
		K.pins == pins0 + 1 and shown.call() == spent0 and lingering.call() == live0,
		"pins +%d spent %d -> %d lingering %d -> %d" % [K.pins - pins0, spent0, shown.call(), live0, lingering.call()])
	_clear_wall(m, T.pos, lv, 2)
	step(m, 0.5)

# ------------------------------------------------------------------ 19: the ult fires on press
func _ult_on_press(m: Match, P: Hunter, T: Hunter, K: ArcherKit, home: Vector3) -> void:
	fresh(T)
	T.teleport(home + Vector3(7.0, 0, 0))
	aim_at(P, T.pos)
	step(m, 0.3)
	P.lvl = 6
	K.cd["x"] = 0.0
	var V := HeroVfx.of(m)
	var cast0 := int(V.plays.get("ult_cast", 0))
	var bow := K.draw.bow_at()
	var fired0 := K.ult.fired
	HunterKeys.ult_pressed(P)
	var flying := m.shots.filter(func(sh): return sh["by"] == P and String(sh["x"].get("ab", "")) == "ultimate")
	var to_cursor := Vector2(T.pos.x - bow.x, T.pos.z - bow.z).normalized()
	ok("19 ult: the first arrow leaves the same frame X is pressed, before any step",
		K.ult.fired == fired0 + 1 and flying.size() == 1, "fired +%d shots %d" % [K.ult.fired - fired0, flying.size()])
	ok("19 ult: it leaves the bow's nock point toward the cursor",
		flying.size() == 1 and (flying[0]["pos"] as Vector3).distance_to(bow) < 0.01
			and (flying[0]["vel"] as Vector2).normalized().distance_to(to_cursor) < 0.02,
		"at %s bow %s" % [str(flying[0]["pos"]) if flying.size() == 1 else "-", str(bow)])
	ok("19 ult: the cast's look comes with the shot (played in the same frame, not before it)",
		int(V.plays.get("ult_cast", 0)) == cast0 + 1 and K.anim_id == "pin_ult_loose",
		"cast %d anim %s" % [int(V.plays.get("ult_cast", 0)) - cast0, K.anim_id])
	var pressed_at := m.time
	# the next press goes the instant the recover is up: hold fire and time the second arrow
	var t := 0.0
	while K.ult.fired == fired0 + 1 and t < 2.0:
		P.inp["fire"] = true
		aim_at(P, T.pos)
		m.step(DT)
		t += DT
	P.inp["fire"] = false
	var recover := float(K.d["x"]["recover"])
	ok("19 ult: the next arrow goes the instant the recover is up (no nock), %.1f s on" % recover,
		K.ult.fired == fired0 + 2 and absf((m.time - pressed_at) - recover) < 0.04, "%.2f s" % (m.time - pressed_at))
	ok("19 data: no nock time left in the data", not (K.d["x"] as Dictionary).has("nock"))
	K.ult.end()
	step(m, 0.5)

# ------------------------------------------------------------------ 20: the perfect window
func _perfect_window(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	var lace: Dictionary = Tuning.of("lace")
	var pt := K.draw.perfect_t()
	ok("20 window: the perfect window is tuning.json lace.perfect_window_s, about 0.2 s longer than 0.15",
		is_equal_approx(pt, float(lace["perfect_window_s"])) and pt >= 0.3 and pt <= 0.45, "%.2f s" % pt)
	var s1 := K.draw.stage_t().x
	var body: ShaderMaterial = null
	for mt in P.mats:
		if mt is ShaderMaterial:
			body = mt
			break
	var rim0 = body.get_shader_parameter("rim_amount") if body else null
	var col0 = body.get_shader_parameter("rim_color") if body else null
	var drawing := func():
		P.inp["fire"] = true
		aim_at(P, T.pos)
	ready_bow(P)
	K.draw.quick = false
	step(m, s1 - 0.1, drawing)
	ok("20 glow: before the stage comes up nothing glows", not K.draw.glow_on and body != null
		and body.get_shader_parameter("rim_amount") == rim0, "glow %s" % K.draw.glow_on)
	step(m, 0.2, drawing)
	var rim_on = body.get_shader_parameter("rim_amount") if body else null
	var col_on: Color = body.get_shader_parameter("rim_color") if body else Color.BLACK
	ok("20 glow: inside the window her body and bow carry the gold rim glow",
		K.draw.glow_on and is_equal_approx(float(rim_on), float(lace["perfect_glow_rim"]))
			and col_on.is_equal_approx(Color(String(lace["perfect_glow_col"]))),
		"glow %s rim %s col %s" % [K.draw.glow_on, str(rim_on), str(col_on)])
	step(m, pt + 0.05, drawing)
	ok("20 glow: past the window the glow is off and every material is back as it was",
		not K.draw.glow_on and body.get_shader_parameter("rim_amount") == rim0
			and body.get_shader_parameter("rim_color") == col0,
		"glow %s rim %s" % [K.draw.glow_on, str(body.get_shader_parameter("rim_amount"))])
	P.inp["fire"] = false
	step(m, 1.0)
	# a perfect release: the payoff pulse, stronger than the window's glow, then off
	ready_bow(P)
	K.draw.quick = false
	var pf0 := K.perfects
	step(m, s1 + 0.1, drawing)
	P.inp["fire"] = false
	m.step(DT)
	var rim_pay = body.get_shader_parameter("rim_amount") if body else null
	ok("20 payoff: a perfect release pulses the rim harder (a distinct flash)",
		K.perfects == pf0 + 1 and K.draw.payoff_t > 0.0
			and is_equal_approx(float(rim_pay), float(lace["perfect_payoff_rim"])),
		"perfects +%d payoff_t %.2f rim %s" % [K.perfects - pf0, K.draw.payoff_t, str(rim_pay)])
	step(m, float(lace["perfect_payoff_s"]) + 0.05)
	ok("20 payoff: the pulse is over and the materials are back",
		K.draw.payoff_t <= 0.0 and not K.draw.glow_on and body.get_shader_parameter("rim_amount") == rim0,
		"payoff_t %.2f" % K.draw.payoff_t)
	step(m, 1.0)

# ------------------------------------------------------------------ E: the slow takes speed, nothing else
func _slow_no_bounce(m: Match, P: Hunter, T: Hunter, K: ArcherKit, home: Vector3) -> void:
	fresh(T)
	T.teleport(home + Vector3(7.0, 0, 0))
	step(m, 0.3, func(): aim_at(P, T.pos))
	var y0 := T.pos.y
	T.squash = 0.0          # (the drop's landing squash: nothing decays it headless, Ent.render does)
	T.freeze_t = 0.0
	cast_e_at(P, K, T.pos)
	var ed: Dictionary = K.e_def()
	var total := float(ed["tell"]) + float(ed["time"]) + 0.3
	var slowed := 0
	var ticks := 0
	var worst_vy := 0.0
	var worst_dy := 0.0
	var squashed := 0
	var held := 0
	var knocked := 0
	var air := 0
	var hp0 := T.hp
	var t := 0.0
	while t < total:
		aim_at(P, T.pos)
		m.step(DT)
		t += DT
		if T.slow_t > 0.0: slowed += 1
		if T.hp < hp0:
			ticks += 1
			hp0 = T.hp
		worst_vy = maxf(worst_vy, absf(T.vel.y))
		worst_dy = maxf(worst_dy, absf(T.pos.y - y0))
		if T.squash > 0.0: squashed += 1
		if T.freeze_t > 0.0: held += 1
		if T.knock_t > 0.0 or absf(T.vel.x) > 0.01 or absf(T.vel.z) > 0.01: knocked += 1
		if not T.grounded: air += 1
	ok("E slow: the foe is slowed and ticked for the rain", slowed > 60 and ticks >= 4,
		"slowed %d steps ticks %d" % [slowed, ticks])
	ok("E slow: no bounce: y velocity stays 0 and the foe never leaves the ground for the whole slow",
		worst_vy == 0.0 and worst_dy < 0.001 and air == 0, "vy %.3f dy %.4f air %d" % [worst_vy, worst_dy, air])
	ok("E slow: no knock, hop or sideways impulse from the slow", knocked == 0, "knocked %d steps" % knocked)
	ok("E slow: the ticks carry no hit squash or hold (Ent.hurt tick, Oomph skips it)", squashed == 0 and held == 0,
		"squash %d hold %d steps" % [squashed, held])
	ok("E slow: the slow only scales speed (slow_mult < 1, strength from the data)",
		is_equal_approx(T.slow_k, float(ed["slow"])) or T.slow_t <= 0.0, "slow_k %.2f" % T.slow_k)
