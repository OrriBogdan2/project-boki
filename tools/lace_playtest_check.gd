extends "res://tools/pin_bjorn_owner_check.gd"
## --lace-playtest-check: the owner's 11-08 playtest on Lace (items 18-20 and the two "ALSO" notes), on the
## training strip of --archer-combo-check. 18 (the needle on her nock point, the shot and bar from the bow's
## mouth) is --lace-1111-check's; here: RMB leaves nothing behind (no spent arrow, stake, scorch or thread).
## 19: Starpiercer's first arrow leaves the frame X is pressed, from the bow, the cast look alongside; the next
## presses loose at once after the recover. 20: the perfect window is tuning.json's (0.35 s), the rim glow is
## on her body and bow only inside it, a perfect release pulses it. E: a foe slowed by the Hail Wall keeps y
## velocity 0, stays grounded and takes no squash, hold or knock for the whole slow.
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
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var t2: Hunter = r[3]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var k: ArcherKit = p.ak
	p.equip("longbow", 0)
	step(m, 0.3)
	_heavy_leaves_nothing(m, p, t, t2, k, home, lv)
	_ult_on_press(m, p, t, k, home)
	_perfect_window(m, p, t, k)
	_slow_no_bounce(m, p, t, k, home)
	await done(m)


# ------------------------------------------------------------------ RMB leaves nothing behind
func _heavy_leaves_nothing(m: Match, p: Hunter, t: Hunter, t2: Hunter, k: ArcherKit, home: Vector3, lv: int) -> void:
	# a miss into open ground, then a wall pin: no spent arrow, no stake, no scorch and no lingering look either way
	fresh(t)
	fresh(t2)
	t.teleport(home + Vector3(-9.0, 0, 9.0))
	t2.teleport(home + Vector3(-9.0, 0, -9.0))
	var v := HeroVfx.of(m)
	var shown := func() -> int:
		var c := 0
		for e in k.fx.spent:
			if (e["node"] as Node3D).visible:
				c += 1
		return c
	var lingering := func() -> int:
		var c := 0
		for e in v.live:
			if (e["node"] as Node3D).visible and float(e.get("dur", 0.0)) > 0.6:
				c += 1
		return c
	var spent0: int = shown.call()
	var live0: int = lingering.call()
	k.cd["rmb"] = 0.0
	var far := home + Vector3(10.0, 0, 0)
	p.inp["sec_hold"] = true
	k.press_rmb()
	step(m, 1.2, rmb_at.bind(p, far))
	p.inp["sec_hold"] = false
	step(m, 1.2)
	ok(
		"RMB miss: the Heavy Shot that lands on open ground leaves no arrow, prop or decal",
		(
			shown.call() == spent0
			and lingering.call() == live0
			and not k.fx.live.values().any(func(e): return e["kind"] == "heavy")
		),
		"spent %d -> %d lingering %d -> %d" % [spent0, shown.call(), live0, lingering.call()]
	)
	var moves: Dictionary = HeroVfx.data("archer")["moves"]
	var decal := ""
	for mv in ["heavy_go", "heavy_hit", "heavy_pin"]:
		for layer in (moves[mv] as Dictionary).get("fx", []):
			var life: Variant = layer.get("life", 0.0)
			if String(layer["p"]) in ["scorch", "thread"] or (life is float and float(life) > 0.6):
				decal = "%s %s" % [mv, layer["p"]]
	ok(
		(
			"RMB data: none of the Heavy Shot's looks is a decal or a lingering mesh"
			+ " (over 0.6 s; the trail rides the shot)"
		),
		decal == "",
		decal
	)
	# the wall pin
	fresh(t)
	t.teleport(home + Vector3(7.0, 0, 0))
	_wall_at(m, t.pos, lv, 2)
	k.cd["rmb"] = 0.0
	var pins0 := k.pins
	p.inp["sec_hold"] = true
	k.press_rmb()
	step(m, 1.2, rmb_at.bind(p, t.pos))
	p.inp["sec_hold"] = false
	step(m, 1.2)
	ok(
		"RMB wall pin: the pin lands and leaves nothing standing in the wall",
		k.pins == pins0 + 1 and shown.call() == spent0 and lingering.call() == live0,
		"pins +%d spent %d -> %d lingering %d -> %d" % [k.pins - pins0, spent0, shown.call(), live0, lingering.call()]
	)
	_clear_wall(m, t.pos, lv, 2)
	step(m, 0.5)


# ------------------------------------------------------------------ 19: the ult fires on press
func _ult_on_press(m: Match, p: Hunter, t_v: Hunter, k: ArcherKit, home: Vector3) -> void:
	fresh(t_v)
	t_v.teleport(home + Vector3(7.0, 0, 0))
	aim_at(p, t_v.pos)
	step(m, 0.3)
	p.lvl = 6
	k.cd["x"] = 0.0
	var v := HeroVfx.of(m)
	var cast0 := int(v.plays.get("ult_cast", 0))
	var bow := k.bow_mouth()
	var fired0 := k.ult.fired
	HunterKeys.ult_pressed(p)
	var flying := m.shots.filter(func(sh): return sh["by"] == p and String(sh["x"].get("ab", "")) == "ultimate")
	var to_cursor := Vector2(t_v.pos.x - bow.x, t_v.pos.z - bow.z).normalized()
	ok(
		"19 ult: the first arrow leaves the same frame X is pressed, before any step",
		k.ult.fired == fired0 + 1 and flying.size() == 1,
		"fired +%d shots %d" % [k.ult.fired - fired0, flying.size()]
	)
	ok(
		"19 ult: it leaves the bow's mouth toward the cursor",
		(
			flying.size() == 1
			and (flying[0]["pos"] as Vector3).distance_to(bow) < 0.01
			and (flying[0]["vel"] as Vector2).normalized().distance_to(to_cursor) < 0.02
		),
		"at %s bow %s" % [str(flying[0]["pos"]) if flying.size() == 1 else "-", str(bow)]
	)
	ok(
		"19 ult: the cast's look comes with the shot (played in the same frame, not before it)",
		int(v.plays.get("ult_cast", 0)) == cast0 + 1 and k.anim_id == "pin_ult_loose",
		"cast %d anim %s" % [int(v.plays.get("ult_cast", 0)) - cast0, k.anim_id]
	)
	var pressed_at := m.time
	# the next press goes the instant the recover is up: hold fire and time the second arrow
	var t := 0.0
	while k.ult.fired == fired0 + 1 and t < 2.0:
		p.inp["fire"] = true
		aim_at(p, t_v.pos)
		m.step(DT)
		t += DT
	p.inp["fire"] = false
	var recover := float(k.d["x"]["recover"])
	ok(
		"19 ult: the next arrow goes the instant the recover is up (no nock), %.1f s on" % recover,
		k.ult.fired == fired0 + 2 and absf((m.time - pressed_at) - recover) < 0.04,
		"%.2f s" % (m.time - pressed_at)
	)
	ok("19 data: no nock time left in the data", not (k.d["x"] as Dictionary).has("nock"))
	k.ult.end()
	step(m, 0.5)


# ------------------------------------------------------------------ 20: the perfect window
func _perfect_window(m: Match, p: Hunter, t: Hunter, k: ArcherKit) -> void:
	var lace_v: Dictionary = Loco.T["lace"]
	var pt := k.draw.perfect_t()
	ok(
		"20 window: the perfect window is tuning.json lace.perfect_window_s, about 0.2 s longer than 0.15",
		is_equal_approx(pt, float(lace_v["perfect_window_s"])) and pt >= 0.3 and pt <= 0.45,
		"%.2f s" % pt
	)
	var s1 := k.draw.stage_t().x
	var body: ShaderMaterial = null
	for mt in p.mats:
		if mt is ShaderMaterial:
			body = mt
			break
	var rim0 = body.get_shader_parameter("rim_amount") if body else null
	var col0 = body.get_shader_parameter("rim_color") if body else null
	var drawing := func():
		p.inp["fire"] = true
		aim_at(p, t.pos)
	ready_bow(p)
	k.draw.quick = false
	step(m, s1 - 0.1, drawing)
	ok(
		"20 glow: before the stage comes up nothing glows",
		not k.draw.glow_on and body != null and body.get_shader_parameter("rim_amount") == rim0,
		"glow %s" % k.draw.glow_on
	)
	step(m, 0.2, drawing)
	var rim_on = body.get_shader_parameter("rim_amount") if body else null
	var col_on: Color = body.get_shader_parameter("rim_color") if body else Color.BLACK
	ok(
		"20 glow: inside the window her body and bow carry the gold rim glow",
		(
			k.draw.glow_on
			and is_equal_approx(float(rim_on), float(lace_v["perfect_glow_rim"]))
			and col_on.is_equal_approx(Color(String(lace_v["perfect_glow_col"])))
		),
		"glow %s rim %s col %s" % [k.draw.glow_on, str(rim_on), str(col_on)]
	)
	step(m, pt + 0.05, drawing)
	ok(
		"20 glow: past the window the glow is off and every material is back as it was",
		(
			not k.draw.glow_on
			and body.get_shader_parameter("rim_amount") == rim0
			and body.get_shader_parameter("rim_color") == col0
		),
		"glow %s rim %s" % [k.draw.glow_on, str(body.get_shader_parameter("rim_amount"))]
	)
	p.inp["fire"] = false
	step(m, 1.0)
	# a perfect release: the payoff pulse, stronger than the window's glow, then off
	ready_bow(p)
	k.draw.quick = false
	var pf0 := k.perfects
	step(m, s1 + 0.1, drawing)
	p.inp["fire"] = false
	m.step(DT)
	var rim_pay = body.get_shader_parameter("rim_amount") if body else null
	ok(
		"20 payoff: a perfect release pulses the rim harder (a distinct flash)",
		(
			k.perfects == pf0 + 1
			and k.draw.payoff_t > 0.0
			and is_equal_approx(float(rim_pay), float(lace_v["perfect_payoff_rim"]))
		),
		"perfects +%d payoff_t %.2f rim %s" % [k.perfects - pf0, k.draw.payoff_t, str(rim_pay)]
	)
	step(m, float(lace_v["perfect_payoff_s"]) + 0.05)
	ok(
		"20 payoff: the pulse is over and the materials are back",
		k.draw.payoff_t <= 0.0 and not k.draw.glow_on and body.get_shader_parameter("rim_amount") == rim0,
		"payoff_t %.2f" % k.draw.payoff_t
	)
	step(m, 1.0)


# ------------------------------------------------------------------ E: the slow takes speed, nothing else
func _slow_no_bounce(m: Match, p: Hunter, t_v: Hunter, k: ArcherKit, home: Vector3) -> void:
	fresh(t_v)
	t_v.teleport(home + Vector3(7.0, 0, 0))
	step(m, 0.3, func(): aim_at(p, t_v.pos))
	var y0 := t_v.pos.y
	t_v.squash = 0.0  # (the drop's landing squash: nothing decays it headless, Ent.render does)
	t_v.freeze_t = 0.0
	cast_e_at(p, k, t_v.pos)
	var ed: Dictionary = k.e_def()
	var total := float(ed["tell"]) + float(ed["time"]) + 0.3
	var slowed := 0
	var ticks := 0
	var worst_vy := 0.0
	var worst_dy := 0.0
	var squashed := 0
	var held := 0
	var knocked := 0
	var air := 0
	var hp0 := t_v.hp
	var t := 0.0
	while t < total:
		aim_at(p, t_v.pos)
		m.step(DT)
		t += DT
		if t_v.slow_t > 0.0:
			slowed += 1
		if t_v.hp < hp0:
			ticks += 1
			hp0 = t_v.hp
		worst_vy = maxf(worst_vy, absf(t_v.vel.y))
		worst_dy = maxf(worst_dy, absf(t_v.pos.y - y0))
		if t_v.squash > 0.0:
			squashed += 1
		if t_v.freeze_t > 0.0:
			held += 1
		if t_v.knock_t > 0.0 or absf(t_v.vel.x) > 0.01 or absf(t_v.vel.z) > 0.01:
			knocked += 1
		if not t_v.grounded:
			air += 1
	ok(
		"E slow: the foe is slowed and ticked for the rain",
		slowed > 60 and ticks >= 4,
		"slowed %d steps ticks %d" % [slowed, ticks]
	)
	ok(
		"E slow: no bounce: y velocity stays 0 and the foe never leaves the ground for the whole slow",
		worst_vy == 0.0 and worst_dy < 0.001 and air == 0,
		"vy %.3f dy %.4f air %d" % [worst_vy, worst_dy, air]
	)
	ok("E slow: no knock, hop or sideways impulse from the slow", knocked == 0, "knocked %d steps" % knocked)
	ok(
		"E slow: the ticks carry no hit squash or hold (Ent.hurt tick, Oomph skips it)",
		squashed == 0 and held == 0,
		"squash %d hold %d steps" % [squashed, held]
	)
	ok(
		"E slow: the slow only scales speed (slow_mult < 1, strength from the data)",
		is_equal_approx(t_v.slow_k, float(ed["slow"])) or t_v.slow_t <= 0.0,
		"slow_k %.2f" % t_v.slow_k
	)
