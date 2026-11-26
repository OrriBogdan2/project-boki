extends "res://tools/bjorn_launch_check.gd"
## Breaker's feel pass (docs/decisions/0061-breaker-swing-lunge.md, docs/heroes/bulwark.md), run from
## --bulwark-combo-check (tools/archer_bulwark_combo_check.gd adds the counts): the Faultline hop and wider lane,
## the rope's auto-return and the swing lunges (his size and the aegis boop are main's: warden_model_check and
## pin_bjorn_owner_check hold them).
## Prints AKCHECK lines.

const OLD_WIDTH := 5.5  # m: the Faultline lane before the owner's 11-26 pass (4.5 before decision 0061)
const OLD_LEN := 16.0  # m: the Faultline lane's length before that pass
const LUNGE_SLACK := 0.3  # m: a measured lunge may miss its data distance by this (step rounding, slide)


func albert() -> void:
	await _shield_up()
	await _ult_hop()
	await _rope()
	await _lunges()


## R: a 1-1.5 m hop with the hammer up, the slam on the old 0.4 s, back on the ground; a 22% wider lane.
func _ult_hop() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	var k: BulwarkKit = p.ak
	var xd: Dictionary = k.d["x"]
	var wind := float(xd["windup"])
	var width := float(xd["width"])
	var length := float(xd["cells"]) * float(xd["cell_len"])
	ok(
		"albert ult: the lane is shorter and at least 25% wider, the owner's 11-26 ask (telegraph and hits: one width)",
		width >= OLD_WIDTH * 1.25 and length < OLD_LEN,
		"%.1f x %.1f -> %.1f x %.1f m" % [OLD_LEN, OLD_WIDTH, length, width]
	)
	step(m, 0.3)
	p.teleport(home)
	p.vel = Vector3.ZERO
	var y0 := p.pos.y
	# a dummy 8 m down the lane, 3.4 m off its line: outside the old lane, inside the new
	t_v.teleport(home + Vector3(8.0, 0, 3.4))
	fresh(t_v)
	k.cd["x"] = 0.0
	aim_at(p, home + Vector3(12.0, 0, 0))
	press_x(m, p)
	var top := 0.0
	var slam_at := -1.0
	var down_at_slam := false
	var free_at := -1.0
	var end_at := -1.0
	var t := DT
	while t < 1.4:
		m.step(DT)
		t += DT
		top = maxf(top, p.pos.y - y0)
		if slam_at < 0.0 and k.ult.phase == "erupt":
			slam_at = t
			down_at_slam = p.pos.y - y0 < 0.15
		if free_at < 0.0 and k.lock_left() <= 0.0 and k.move_k() > 0.0:
			free_at = t
		if end_at < 0.0 and k.ult.phase == "":
			end_at = t
	ok(
		"albert ult: rooted at most 0.45 s, done within 0.95 s of the press (before 11-26: 0.6 s + hit-stop, 1.4 s)",
		free_at > 0.0 and free_at <= 0.45 + 1.5 * DT and end_at > 0.0 and end_at <= 0.95 + 1.5 * DT,
		"root %.2f s, done %.2f s, lane %.1f x %.1f m" % [free_at, end_at, length, width]
	)
	ok("albert ult: he hops 1-1.5 m with the hammer up", top >= 1.0 and top <= 1.5, "top %.2f m" % top)
	ok(
		"albert ult: the slam keeps its 0.4 s and lands him on the ground",
		absf(slam_at - wind) <= 2.0 * DT and down_at_slam and p.grounded,
		"slam at %.2f, %.2f m up" % [slam_at, p.pos.y - y0]
	)
	ok(
		"albert ult: a foe 3.4 m off the line is thrown (outside the old lane, inside the new)",
		dmg(t_v) > 0.0,
		"took %.0f" % dmg(t_v)
	)
	await done(m)


## RMB: his own wooden shield comes up in front of his chest (WardenArmRaise over the guard clip, owner 11-26), not
## left at his hip where the clip keys it; the arm gives it back to the clips once the aegis is down.
func _shield_up() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var clips := (p.model.get_node("Warden/Sync") as WardenGlb.Sync).clips
	var sk := WardenGlb.skeleton(p.model.get_node("Warden"))
	var shield := WardenSkeleton.find(sk, "x_shield")
	var shoulder := WardenSkeleton.find(sk, "upper_arm.L")
	var raise := clips.arm_raise
	var at := {}
	for k in ["clip", "raised", "down"]:
		clips.arm_raise = null if k == "clip" else raise
		p.inp["sec_hold"] = k != "down"
		if k != "down":
			p.ak.press_rmb()
		for i in 30:
			p.inp["sec_hold"] = k != "down"
			m.step(DT)
			p.render(DT, 1.0)
			await main.get_tree().process_frame
		at[k] = sk.get_bone_global_pose(shield).origin
		at[k + "_sh"] = sk.get_bone_global_pose(shoulder).origin
	var up: Vector3 = at["raised"]
	var clip_y: float = at["clip"].y
	var sh: Vector3 = at["raised_sh"]
	ok(
		"albert RMB: his wooden shield is pulled up in front of his chest (not at his hip, as the clip keys it)",
		raise != null and up.y >= clip_y + 0.12 and up.y >= sh.y - 0.15 and up.z <= sh.z - 0.3,
		"shield y %.2f (clip %.2f, shoulder %.2f), %.2f in front of the shoulder" % [up.y, clip_y, sh.y, sh.z - up.z]
	)
	ok("albert RMB: the arm goes back to the clips once the aegis is down", raise.w == 0.0, "w %.2f" % raise.w)
	await done(m)


## The rope: the hammer reels home past "rope.max_len" m or after "rope.max_t" s, the throw shut till the catch.
func _rope() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	var k: BulwarkKit = p.ak
	var rd: Dictionary = k.lmb_def()["rope"]
	# by length: thrown 6 m east, he steps 12 m west of where he stood
	_ready_swing(m, p, t_v, home)
	_tap_throw(m, p, home + Vector3(6.0, 0, 0))
	step(m, 0.6)
	var landed := not k.mace.is_empty() and String(k.mace["st"]) == "ground"
	var r0 := k.reels
	p.teleport(home - Vector3(float(rd["max_len"]) - 4.0, 0, 0))
	m.step(DT)
	m.step(DT)
	var reeled := k.reels == r0 + 1 and String(k.mace.get("st", "")) == "back"
	var t0 := k.throws
	_tap_throw(m, p, p.pos + Vector3(-5.0, 0, 0))
	var shut := k.throws == t0
	var t := 0.0
	while not k.mace.is_empty() and t < 3.0:
		m.step(DT)
		t += DT
	ok(
		"albert rope: past %.0f m the hammer reels home on its own, the throw shut till the catch" % rd["max_len"],
		landed and reeled and shut and k.mace.is_empty() and not k.fx.taut,
		"landed %s reeled %s shut %s home in %.2f s" % [landed, reeled, shut, t]
	)
	step(m, 0.3)
	_tap_throw(m, p, p.pos + Vector3(5.0, 0, 0))
	ok("albert rope: caught, it throws again", k.throws == t0 + 1, "throws %d" % (k.throws - t0))
	# by time: thrown 6 m, he stands by it
	_ready_swing(m, p, t_v, home)
	step(m, 1.0)
	var r1 := k.reels
	_tap_throw(m, p, home + Vector3(6.0, 0, 0))
	var out := 0.0
	while k.reels == r1 and out < float(rd["max_t"]) + 1.0:
		m.step(DT)
		out += DT
	ok(
		"albert rope: left out %.0f s it reels home on its own" % rd["max_t"],
		k.reels == r1 + 1 and absf(out - float(rd["max_t"])) < 0.2,
		"after %.2f s" % out
	)
	step(m, 1.5)
	await done(m)


## One LMB tap aimed at `at` (a throw when the hammer is in hand).
func _tap_throw(m: Match, p: Hunter, at: Vector3) -> void:
	p.fire_cd = 0.0
	press_at(p, at)
	m.step(DT)
	m.step(DT)
	p.inp["fire"] = false
	m.step(DT)


## The swing lunge: a part charge the short end of "lunge.d", a full one the long end, running further, in
## the air "air_k" of it; the 360 Smash's spin lunges on "spin_d" m.
func _lunges() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var home: Vector3 = r[4]
	var k: BulwarkKit = p.ak
	var ld := k.lunge.ld()
	var full := float(k.lmb_def()["full"])
	var at := home + Vector3(9.0, 0, 0)
	_ready_swing(m, p, t, home)
	step(m, float(k.lmb_def()["tap"]) + 0.05, press_at.bind(p, at))
	p.inp["fire"] = false
	step(m, 0.8)
	var part := k.lunge.last_d
	_ready_swing(m, p, t, home)
	_swing(m, p, home, full + 0.3)
	var whole := k.lunge.last_d
	var d: Array = ld["d"]
	ok(
		"albert lunge: standing, a part charge ~%.1f m and a full one ~%.1f m (the finisher pulls more)" % [d[0], d[1]],
		absf(part - float(d[0])) < LUNGE_SLACK and absf(whole - float(d[1])) < LUNGE_SLACK and k.lunge.count >= 2,
		"part %.2f full %.2f" % [part, whole]
	)
	# running east into the full swing: his run stacks on the pull
	_ready_swing(m, p, t, home)
	step(
		m,
		full + 0.3,
		func():
			press_at(p, at)
			p.inp["move"] = Vector2(1, 0)
	)
	p.inp["fire"] = false
	p.inp["move"] = Vector2.ZERO
	step(m, 0.8)
	var run_v := k.lunge.last_d
	ok(
		"albert lunge: running, the swing travels further than standing",
		run_v > whole + 0.3,
		"run %.2f standing %.2f" % [run_v, whole]
	)
	# in the air: the same full swing let go at the top of a standing jump pulls "air_k" of it
	_ready_swing(m, p, t, home)
	step(m, full + 0.1, press_at.bind(p, at))
	_tap_key(m, p, "jump", at)
	step(m, 0.2, press_at.bind(p, at))
	var up := not p.grounded
	p.inp["fire"] = false
	step(m, 1.2)
	var air := k.lunge.last_d
	var want := float(d[1]) * float(ld["air_k"])
	ok(
		"albert lunge: in the air it pulls ~%.0f%% of the ground's" % (100.0 * float(ld["air_k"])),
		up and k.lunge.last_air and absf(air - want) < LUNGE_SLACK,
		"air %.2f (want %.2f) ground %.2f" % [air, want, whole]
	)
	# the 360 Smash: a dash then the spin, which lunges on
	_ready_swing(m, p, t, home)
	p.dashes = p.max_dashes()
	aim_at(p, at)
	p.inp["dash"] = true
	m.step(DT)
	p.inp["dash"] = false
	step(m, 1.2)
	ok(
		(
			"albert lunge: the 360 Smash's spin lunges him on at least %.1f m (the dash's speed stacks like a run)"
			% ld["spin_d"]
		),
		(
			k.lunge.last_kind == "spin"
			and k.lunge.last_d >= float(ld["spin_d"]) - 0.1
			and k.lunge.last_d <= float(ld["spin_d"]) + p.base_speed * float(ld["t"]) + LUNGE_SLACK
		),
		"%s %.2f m" % [k.lunge.last_kind, k.lunge.last_d]
	)
	await done(m)
