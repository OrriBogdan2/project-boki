extends "res://tools/pin_bjorn_ult_check.gd"
## Owner playtest items of 2026-11-03 for Pin and Bjorn (briefs/OWNER_REVIEW_1103.md #5, #6, #10, #29, #30),
## run from --archer-combo-check and --bulwark-combo-check (tools/archer_bulwark_combo_check.gd adds the
## counts). Prints AKCHECK lines like --archetype-check.

## Holds LMB with the cursor on `at`.
func press_at(P: Hunter, at: Vector3) -> void:
	P.inp["fire"] = true
	aim_at(P, at)

## Holds LMB on `at` with Focus kept empty (no full-Focus draw).
func press_dry(P: Hunter, K: ArcherKit, at: Vector3) -> void:
	K.res = 0.0
	press_at(P, at)

## Holds RMB with the cursor on `at`.
func rmb_at(P: Hunter, at: Vector3) -> void:
	P.inp["sec_hold"] = true
	aim_at(P, at)

## Casts E at once with its cooldown cleared.
func cast_e_at(P: Hunter, K: ArchKit, at: Vector3) -> void:
	K.cd["e"] = 0.0
	P.inp["aim"] = at
	P.ak.use_e()

## Arrows of ours in flight or just spawned.
func arrows(m: Match, P: Hunter) -> int:
	return m.shots.filter(func(sh): return sh["by"] == P).size()

## How far `p` is from the line through `from` along `dir` (flat, m).
func off_line(from: Vector3, dir: Vector2, p: Vector3) -> float:
	var d := Vector2(p.x - from.x, p.z - from.z)
	return absf(d.x * dir.y - d.y * dir.x)

## The first visible fletch burst of Pin's pool (its world place and width), or null.
func burst_node(K: ArcherKit) -> MeshInstance3D:
	for b in K.fx.bursts:
		var node: MeshInstance3D = b["node"]
		if node.visible:
			return node
	return null

func pin() -> void:
	var r := setup("archer", 7.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: ArcherKit = P.ak
	P.equip("longbow", 0)
	step(m, 0.3)
	_pin_no_early_release(m, P, T, K)
	_pin_readout(m, P, T, K)
	_pin_draw_pose(m, P, T, K)
	_pin_heavy(m, P, T, K, home, lv)
	_pin_dash(m, P, T, K)
	await done(m)

func ready_bow(P: Hunter) -> void:
	P.fire_cd = 0.0
	P.ammo = maxi(P.ammo, 1)
	P.reload_t = 0.0
	P.draw_t = -1.0

## #5: the arrow leaves only when the button comes up.
func _pin_no_early_release(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	var aim := press_at.bind(P, T.pos)
	# 5 s on the button: past Empowered, Supercharged and the overdraw, nothing leaves the string
	ready_bow(P)
	var early := 0
	var t := 0.0
	while t < 5.0:
		aim.call()
		K.res = 0.0
		m.step(DT)
		t += DT
		early += arrows(m, P)
	ok("pin early release: 5 s on the button looses nothing", early == 0 and K.draw.loosed_at < 0.0 and P.ammo == 1,
		"arrows %d ammo %d" % [early, P.ammo])
	P.inp["fire"] = false
	m.step(DT)
	m.step(DT)
	ok("pin early release: letting go looses exactly one arrow (an overdrawn one)",
		arrows(m, P) == 1 and K.draw.last_kind == "over", "arrows %d kind %s" % [arrows(m, P), K.draw.last_kind])
	step(m, 1.0)
	# a full Focus is drawn at once but waits for the button to come up (it used to loose on the press)
	ready_bow(P)
	K.res = K.res_max()
	early = 0
	t = 0.0
	while t < 2.0:
		aim.call()
		m.step(DT)
		t += DT
		early += arrows(m, P)
	ok("pin early release: a full Focus held 2 s waits for the release (drawn at the top stage)",
		early == 0 and P.focus_draw and P.draw_t > 0.0,
		"arrows %d focus_draw %s draw_t %.2f" % [early, P.focus_draw, P.draw_t])
	P.inp["fire"] = false
	m.step(DT)
	m.step(DT)
	ok("pin early release: the Focus shot goes on release, Supercharged and aimed at once",
		arrows(m, P) == 1 and K.draw.last_kind == "super", "arrows %d kind %s" % [arrows(m, P), K.draw.last_kind])
	step(m, 1.0)
	# a cooldown running mid-draw never looses it
	ready_bow(P)
	K.res = 0.0
	step(m, 0.3, aim)
	P.fire_cd = 0.4
	early = 0
	t = 0.0
	while t < 0.8:
		aim.call()
		m.step(DT)
		t += DT
		early += arrows(m, P)
	ok("pin early release: a cooldown mid-draw does not loose it", early == 0 and P.draw_t > 0.5,
		"arrows %d draw_t %.2f" % [early, P.draw_t])
	# a dash cancels the draw with no shot, and holding on does not start a new one by itself being a shot
	P.dashes = P.max_dashes()
	P.do_dash()
	step(m, 0.4, aim)
	ok("pin early release: a dash cancels the draw with no arrow", arrows(m, P) == 0
		and K.draw.loosed_at < m.time - 0.3,
		"arrows %d" % arrows(m, P))
	P.inp["fire"] = false
	step(m, 1.0)

## #5: the readout sits on the aim line.
func _pin_readout(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	ready_bow(P)
	K.res = 0.0
	T.teleport(P.pos + Vector3(7.0, 0, 3.0))
	var aim := press_dry.bind(P, K, T.pos)
	step(m, 0.3, aim)
	var d := P.aim_dir()
	var ve := AimKit.entry(P, "draw")
	var from: Vector2 = ve.get("from", Vector2(-99, -99))
	var vd: Vector2 = ve.get("dir", Vector2.ZERO)
	ok("pin readout: the V leaves Pin along the aim line and is symmetric about it",
		String(ve.get("kind", "")) == "vee" and from.distance_to(Vector2(P.pos.x, P.pos.z)) < 0.01
		and vd.distance_to(d) < 0.01 and float(ve.get("half", 0.0)) > 0.0,
		"from %s dir %s aim %s" % [str(from), str(vd), str(d)])
	ok("pin readout: the bow cue sits on the aim line, not beside her", off_line(P.pos, d, K.draw.bow_at()) < 0.02,
		"off %.3f" % off_line(P.pos, d, K.draw.bow_at()))
	step(m, 0.4, aim)
	ve = AimKit.entry(P, "draw")
	ok("pin readout: Empowered ready merges the two lines into one on the aim line",
		bool(ve.get("merged", false)) and (ve.get("dir", Vector2.ZERO) as Vector2).distance_to(d) < 0.01,
		"merged %s t %.2f" % [str(ve.get("merged")), P.draw_t])
	step(m, 0.7, aim)
	var le := AimKit.entry(P, "draw")
	var to: Vector2 = le.get("to", Vector2.ZERO)
	var cursor := Vector2(T.pos.x - P.pos.x, T.pos.z - P.pos.z).length()
	ok("pin readout: full draw runs one line from Pin along the aim line, past the cursor, to max range",
		String(le.get("kind", "")) == "line" and to.distance_to(le.get("from", Vector2.ZERO)) > cursor + 3.0
		and off_line(P.pos, d, Vector3(to.x, P.pos.y, to.y)) < 0.05,
		"len %.1f cursor %.1f" % [to.distance_to(le.get("from", Vector2.ZERO)), cursor])
	P.inp["fire"] = false
	step(m, 1.0)
	# the perfect release: a gold flash on the aim line (and the star on the cursor), never beside her
	ready_bow(P)
	step(m, K.draw.stage_t().x + 0.05, aim)
	P.inp["fire"] = false
	m.step(DT)
	var flash := burst_node(K)
	var at := flash.global_position if flash != null else Vector3(999, 0, 999)
	ok("pin readout: the perfect release flash sits on the aim line at the bow, and the cursor star fires",
		K.draw.perfect_now and flash != null and off_line(P.pos, d, at) < 0.05
			and float(AimKit.reticle(P)["perfect"]) > 0.0,
		"perfect %s off %.3f" % [K.draw.perfect_now, off_line(P.pos, d, at)])
	step(m, 1.0)

## #5: the nock on the press, and one steady pull with no pose pop.
func _pin_draw_pose(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	ready_bow(P)
	K.res = 0.0
	var aim := press_dry.bind(P, K, T.pos)
	step(m, 0.06, aim)
	var nock := HunterAnim.km_sample("arc_draw", 0.05)
	ok("pin draw: the arrow nocks within 0.05 s of the press (arc_draw, the string hand on the string)",
		K.anim_id == "arc_draw" and P.draw_t >= 0.0 and float(nock.get("hw", 0.0)) > 0.9 and float(nock.get("rw",
			0.0)) > 0.9,
		"anim %s draw_t %.2f" % [K.anim_id, P.draw_t])
	step(m, 0.5, aim)
	ok("pin draw: the pose runs on the draw's own clock", absf((m.time - K.anim_at) - P.draw_t) < 0.03,
		"clock %.2f draw_t %.2f" % [m.time - K.anim_at, P.draw_t])
	P.inp["fire"] = false
	step(m, 1.0)
	# a quick draw (after a perfect release) runs the pose faster with it
	ready_bow(P)
	K.draw.quick = true
	step(m, 0.3, aim)
	ok("pin draw: a quick draw keeps the pose and the stage cues together",
		P.draw_t > 0.4 and absf((m.time - K.anim_at) - P.draw_t) < 0.03,
		"clock %.2f draw_t %.2f" % [m.time - K.anim_at, P.draw_t])
	P.inp["fire"] = false
	step(m, 1.0)
	# one steady pull: no step in any channel bigger than a smooth ramp, and no jump into the release poses
	var worst := 0.0
	var prev := HunterAnim.km_sample("arc_draw", 0.05)
	for i in range(6, 131):
		var cur := HunterAnim.km_sample("arc_draw", float(i) * 0.01)
		for ch in ["p", "y"]:
			worst = maxf(worst, absf(float(cur.get(ch, 0.0)) - float(prev.get(ch, 0.0))))
		worst = maxf(worst, ((cur.get("fl", Vector3.ZERO) as Vector3) - (prev.get("fl",
			Vector3.ZERO) as Vector3)).length())
		prev = cur
	ok("pin draw: no pose pop between stages (the biggest 10 ms step is a smooth ramp)", worst < 0.045,
		"worst %.3f" % worst)
	var pops := 0.0
	for pair in [["arc_loose", 0.6], ["arc_super", 1.15], ["arc_over", 1.15]]:
		var rel := HunterAnim.km_sample(String(pair[0]), 0.0)
		var held := HunterAnim.km_sample("arc_draw", float(pair[1]))
		for ch in ["p", "y"]:
			pops = maxf(pops, absf(float(rel.get(ch, 0.0)) - float(held.get(ch, 0.0))))
	ok("pin draw: each release starts from the pose the draw held (no pop)", pops < 0.02, "worst %.3f" % pops)

## #6: the Heavy Shot is a big, unmistakable arrow with its own release and impact.
func _pin_heavy(m: Match, P: Hunter, T: Hunter, K: ArcherKit, home: Vector3, lv: int) -> void:
	var arrow_look: Array = PinFx.LOOK["arrow"]
	var heavy_look: Array = PinFx.LOOK["heavy"]
	var ratio := float(heavy_look[6]) / float(arrow_look[6])
	ok("pin heavy: the arrow is 3-4 times a normal arrow with a long trail",
		ratio >= 3.0 and ratio <= 4.0 and float(heavy_look[4]) >= 2.0 * float(arrow_look[4]),
		"scale x%.1f trail %.1f vs %.1f" % [ratio, float(heavy_look[4]), float(arrow_look[4])])
	fresh(T)
	T.teleport(home + Vector3(7.0, 0, 0))
	K.ch_rmb = 2.0
	K.cd["rmb"] = 0.0
	K.res = 0.0
	_wall_at(m, T.pos, lv, 2)
	aim_at(P, T.pos)
	var kicks0 := K.heavy_kicks
	var pins0 := K.pins
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.8, rmb_at.bind(P, T.pos))
	var bar := AimKit.entry(P, "rmb_bar")
	var d := P.aim_dir()
	ok("pin heavy: the telegraph while held is a thick gold lane with a tip, from Pin along the aim line",
		AimKit.shown(P, "rmb_bar") and AimKit.shown(P, "rmb_v") and float(bar.get("width", 0.0)) >= 0.45
		and bool(bar.get("tip", false)) and (bar.get("dir", Vector2.ZERO) as Vector2).distance_to(d) < 0.01,
		"width %.2f tip %s" % [float(bar.get("width", 0.0)), str(bar.get("tip"))])
	step(m, 0.5, rmb_at.bind(P, T.pos))
	P.inp["sec_hold"] = false
	m.step(DT)
	m.step(DT)
	var heavy := 0
	var lmb_kinds := 0
	var node: Node3D = null
	for sh in m.shots:
		if sh["by"] != P:
			continue
		var kind := String((sh["x"] as Dictionary).get("pin", ""))
		if kind == "heavy":
			heavy += 1
			node = K.fx.live.get(int(sh["sid"]), {}).get("node")
		elif kind != "":
			lmb_kinds += 1
	ok("pin heavy: it spawns its own projectile type (heavy), never an LMB arrow type",
		heavy >= 1 and lmb_kinds == 0 and node != null and (node.get_node("Core") as Node3D).visible,
		"heavy %d lmb %d" % [heavy, lmb_kinds])
	var burst := burst_node(K)
	ok("pin heavy: a release burst at the bow, on the aim line, wider than the bow cues, with a screen kick",
		burst != null and off_line(P.pos, d, burst.global_position) < 0.05 and burst.scale.x >= 1.4
			and K.heavy_kicks == kicks0 + 1,
		"scale %.1f kicks %d" % [burst.scale.x if burst != null else 0.0, K.heavy_kicks - kicks0])
	var flashed := 0.0
	for i in 20:
		m.step(DT)
		flashed = maxf(flashed, T.flash_t)
	ok("pin heavy: it pins the foe to the wall and the target flashes",
		K.pins >= pins0 + 1 and T.stun_t > 0.5 and flashed > 0.0, "pins %d stun %.2f flash %.2f" % [K.pins - pins0,
			T.stun_t, flashed])
	ok("pin heavy: a stake stays in the wall after the pin", K.fx.staked >= 1, "stakes %d" % K.fx.staked)
	step(m, 5.0)
	var standing := 0
	for c in K.fx.spent:
		if float(c["t"]) > 0.5 and (c["node"] as Node3D).visible:
			standing += 1
	ok("pin heavy: the stake is still standing 5 s later", standing >= 1, "standing %d" % standing)

func bjorn() -> void:
	var r := setup("bulwark", 7.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	step(m, 0.3)
	_bjorn_cadence(m, P, T, K)
	_bjorn_shield(m, P, T, K, home)
	_bjorn_hold(m, P, T, K, home)
	_bjorn_dash(m, P, T, K, home)
	await done(m)
	await _bjorn_abyss()

## #10: the auto attack recovers 10-15% faster than before (0.55 s throw, 0.7 s swing, 0.25 s recall lock).
func _bjorn_cadence(_m: Match, _P: Hunter, _T: Hunter, K: BulwarkKit) -> void:
	var md := K.lmb_def()
	var tr := float(md["throw_rate"])
	var sr := float(md["smash_rate"])
	var rl := float(md["recall_lock"])
	ok("bjorn auto: the throw, the swing and the recall lock recover 10-15% faster",
		tr <= 0.55 * 0.90 and tr >= 0.55 * 0.85 and sr <= 0.7 * 0.90 and sr >= 0.7 * 0.85 and rl <= 0.25 * 0.90
			and rl >= 0.25 * 0.85,
		"throw %.3f swing %.3f lock %.3f" % [tr, sr, rl])
	var tail := 0.0
	for id in ["bul_throw", "bul_recall"]:
		var keys: Array = KMovesPinBjorn.MOVES[id]["keys"]
		tail = maxf(tail, float((keys[-1] as Array)[0]))
	ok("bjorn auto: the throw and recall poses end with the faster cadence (no pose cut mid-way)",
		float((KMovesPinBjorn.MOVES["bul_throw"]["keys"][-1] as Array)[0]) <= tr + 0.08 and tail < 0.62,
			"tail %.2f" % tail)
	var throws := _throws_in(_m, _P, K, 3.0)
	ok("bjorn auto: throw, recall and throw again within 3 s at least 4 times", throws >= 4, "throws %d" % throws)

## Taps LMB to throw and again to recall, for `secs` s; returns the throws made.
func _throws_in(m: Match, P: Hunter, K: BulwarkKit, secs: float) -> int:
	var t0 := K.throws
	P.fire_cd = 0.0
	P.teleport(P.pos)
	var t := 0.0
	var prev := false
	while t < secs:
		var press := fmod(t, 0.1) < 0.05
		P.inp["fire"] = press
		aim_at(P, P.pos + Vector3(3.0, 0, 0))
		m.step(DT)
		t += DT
		prev = press
	P.inp["fire"] = false
	step(m, 1.0)
	return K.throws - t0 if prev or true else 0

## #29: the raised aegis pushes foes back and shows it, is bigger and plated.
func _bjorn_shield(m: Match, P: Hunter, T: Hunter, K: BulwarkKit, home: Vector3) -> void:
	P.teleport(home)
	P.vel = Vector3.ZERO
	fresh(T)
	K.shield_hp = K.shield_max()
	K.lock_t = 0.0
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	T.teleport(home + Vector3(2.0, 0, 0))
	aim_at(P, T.pos)
	var sd: Dictionary = K.rmb_def()["shield"]
	ok("bjorn shield: the wall is 40% longer (4.2 m)", absf(float(sd["len"]) - 4.2) < 0.01,
		"len %.2f" % float(sd["len"]))
	var x0 := T.pos.x
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.35, rmb_at.bind(P, home + Vector3(5.0, 0, 0)))
	var hint := AimKit.entry(P, "aegis_push")
	ok("bjorn shield: a forward double chevron shows in front of the raised wall, to everyone, as long as the push",
		AimKit.shown(P, "aegis_push") and int(hint.get("chevrons", 0)) == 2 and bool(hint.get("all", false))
		and absf(float(hint.get("len", 0.0)) - float(sd["push"])) < 0.01,
		str(hint.keys()))
	var d := P.aim_dir()
	ok("bjorn shield: the chevron points the way the wall faces", (hint.get("dir",
		Vector2.ZERO) as Vector2).distance_to(d) < 0.01)
	step(m, 0.6, rmb_at.bind(P, home + Vector3(5.0, 0, 0)))
	var moved := T.pos.x - x0
	ok("bjorn shield: a foe walking into the raised wall is pushed back at least its push distance",
		K.pushes >= 1 and moved >= float(sd["push"]) - 0.05, "pushed %d moved %.2f" % [K.pushes, moved])
	ok("bjorn shield: a push flashes the wall", K.fx.aegis_hit > 0.0 or K.fx.push_flash > 0.0 or K.pushes >= 1)
	ok("bjorn shield: the wall is built of plates (solid, not a flat slab) and bigger",
		K.fx.aegis.get_child_count() >= 30 and K.fx.AEGIS_H >= 1.3 * 1.3 - 0.01 and K.fx.aegis.visible,
		"parts %d height %.2f" % [K.fx.aegis.get_child_count(), K.fx.AEGIS_H])
	P.inp["sec_hold"] = false
	step(m, 0.4)
	ok("bjorn shield: lowered, the chevron is gone", not AimKit.shown(P, "aegis_push") and not K.fx.aegis.visible)

## #30: the held swing ends on a mantle and other actions, lunges him forward and knocks back.
func _bjorn_hold(m: Match, P: Hunter, T: Hunter, K: BulwarkKit, home: Vector3) -> void:
	var aim := press_at.bind(P, home + Vector3(9.0, 0, 0))
	T.teleport(home + Vector3(30.0, 0, 6.0))
	var reset := func():
		P.inp["fire"] = false
		step(m, 0.8)
		P.teleport(home)
		P.vel = Vector3.ZERO
		P.fire_cd = 0.0
		P.dashes = P.max_dashes()
		K.lmb_t = -1.0
		K.hold_blocked = false
	# a mantle ends the hold within one frame, and it stays ended while the button stays down
	reset.call()
	step(m, 0.6, aim)
	ok("bjorn hold: the swing is charging", K.lmb_t > 0.4, "lmb_t %.2f" % K.lmb_t)
	P.lfloat = {"lip": P.pos.y + 2.0, "n": Vector2(1, 0), "t": 0.0, "g0": false, "shove": false, "kb0": P.kb_t,
		"at": Vector2(P.pos.x, P.pos.z), "downed": false, "win": false, "tile": Vector2i(0, 0), "max_t": 5.0}
	m.step(DT)
	ok("bjorn hold: a mantle ends the hold within one frame", K.lmb_t < 0.0 and P.mel_hold == 0.0 and K.hold_blocked,
		"lmb_t %.2f blocked %s" % [K.lmb_t, K.hold_blocked])
	P.lfloat = {}
	var sl0 := K.slams
	step(m, 0.5, aim)
	ok("bjorn hold: after the mantle the held button does not start it again", K.lmb_t < 0.0 and K.slams == sl0,
		"lmb_t %.2f slams %d" % [K.lmb_t, K.slams - sl0])
	P.inp["fire"] = false
	m.step(DT)
	step(m, 0.5, aim)
	ok("bjorn hold: letting go and pressing again starts a fresh hold", K.lmb_t > 0.2, "lmb_t %.2f" % K.lmb_t)
	# a glide, a dash, a knock, another ability each end it too
	var cases := {
		"glide": func(): P.gliding = true,
		"dash": func(): P.do_dash(),
		"knock": func(): P.impulse(Vector2(40.0, 0.0)),
		"ability": cast_e_at.bind(P, K, home),
	}
	for key in cases:
		reset.call()
		step(m, 0.6, aim)
		var live := K.lmb_t > 0.4
		(cases[key] as Callable).call()
		m.step(DT)
		m.step(DT)
		ok("bjorn hold: %s ends the hold" % key, live and K.lmb_t < 0.0 and P.mel_hold == 0.0,
			"live %s lmb_t %.2f" % [live, K.lmb_t])
		P.gliding = false
	reset.call()
	# the swing lunges him forward and knocks a foe back along it
	T.teleport(home + Vector3(2.6, 0, 0))
	fresh(T)
	aim_at(P, T.pos)
	step(m, 0.5)
	step(m, float(K.lmb_def()["full"]) + 0.05, aim)
	var p0 := P.pos
	var t0 := T.pos
	P.inp["fire"] = false
	step(m, 0.8)
	var lunge := Vector2(P.pos.x - p0.x, P.pos.z - p0.z).dot(Vector2(1, 0))
	var knock := Vector2(T.pos.x - t0.x, T.pos.z - t0.z).dot(Vector2(1, 0))
	ok("bjorn hold: the swing moves him forward at least 1.5 m", lunge >= 1.5, "lunge %.2f" % lunge)
	ok("bjorn hold: the swing knocks the foe back along it, at least 2 m", knock >= 2.0, "knock %.2f" % knock)

## #29: the Faultline's trail keeps drawing over the abyss, at his height.
func _bjorn_abyss() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	step(m, 0.3)
	var W: World = m.world
	# the strip of island ends 6 m east of him: void beyond it
	for dz in range(-6, 7):
		for dx in range(5, 24):
			var i: int = W.idx(int(home.x) + dx, int(home.z) + dz)
			W.kind[i] = World.T_VOID
	P.lvl = 6
	P.ult = 0.0
	aim_at(P, home + Vector3(8.0, 0, 0))
	press_x(m, P)
	step(m, 0.45)
	var ud: BjornUlt = K.ult
	var drawn := 0.0
	var floating := true
	for i in ud.cells.size():
		var e := AimKit.entry(P, "x%d" % i)
		if not e.is_empty():
			drawn += float(e.get("len", 0.0))
			var mid := (ud.cells[i] as Vector3) + Vector3(ud.dir.x, 0, ud.dir.y) * ud.cell_len() * 0.5
			var at_height: bool = absf(float(e.get("y", -999.0)) - ud.origin.y) < 0.05
			floating = floating and (at_height or W.ground_at(mid.x, mid.z) > World.VOID + 1.0)
	var over := 0
	for i in ud.cells.size():
		var c: Vector3 = ud.cells[i]
		if W.ground_at(c.x + ud.dir.x * 2.0, c.z + ud.dir.y * 2.0) <= World.VOID + 1.0:
			over += 1
	ok("bjorn ult trail: the lane runs on over the abyss (cells over it: %d)" % over, ud.cells.size() == 4
		and over >= 2,
		"cells %d over %d" % [ud.cells.size(), over])
	ok("bjorn ult trail: the drawn length equals its travel length, over the abyss cells too",
		absf(drawn - ud.trail_len()) < 0.01 and absf(ud.trail_len() - ud.cell_len() * ud.cells.size()) < 0.01,
		"drawn %.1f travel %.1f" % [drawn, ud.trail_len()])
	ok("bjorn ult trail: over the abyss it is drawn at his height (floating), not down at the bottom", floating)
	step(m, 1.5)
	var mid_far := ud.origin + Vector3(ud.dir.x, 0, ud.dir.y) * (ud.trail_len() - 2.0)
	ok("bjorn ult trail: the scar's height over the void is his own", absf(ud._trail_y(mid_far) - ud.origin.y) < 0.01)
	await done(m)

## The dash moves are each hero's own, and each fits its dash (#35).
func _dash_moves(ids: Array, dash_t: Dictionary) -> void:
	var seen := {}
	var dup := false
	var empty := false
	var worst := 0.0
	for id in ids:
		dup = dup or seen.has(id)
		seen[id] = true
		var keys: Array = HunterAnim.km_def(String(id)).get("keys", [])
		empty = empty or keys.is_empty()
		if not keys.is_empty():
			worst = maxf(worst, float((keys[-1] as Array)[0]) - float(dash_t.get(id, 0.0)))
	ok("dash moves %s: each is its own move, none shared" % str(ids), not dup and not empty, str(seen.keys()))
	ok("dash moves %s: each move's length fits its dash plus a short settle" % str(ids), worst <= 0.62,
		"worst +%.2f s" % worst)

## The attack key let go before a step: DashFlow plays a press made in a dash as a one-step tap, which a check
## driving the keys by hand has to release, as a player's lifted button would.
func _let_go(P: Hunter) -> void:
	P.inp["fire"] = false

## The DashFlow mode of a `slot` press during the hero's ground or air dash.
func _mode(hero: String, slot: String, in_air: bool) -> String:
	return String(DashFlow.row_of(hero, slot, in_air)["mode"])

## #32 / #35 for Pin: a press during the roll is carried, RMB / E / X work at once, a draw ends on a dash.
func _pin_dash(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	ok("pin dash table: LMB buffers, RMB / E / X fire, a draw is cancelled by a dash",
		_mode("archer", "lmb", false) == "buffer" and _mode("archer", "lmb", true) == "buffer"
		and _mode("archer", "rmb", false) == "fire" and _mode("archer", "e", false) == "fire"
		and _mode("archer", "x", false) == "fire"
		and DashFlow.into_dash_of("archer", "lmb").get("mode") == "cancel")
	step(m, 1.5)
	ready_bow(P)
	K.res = 0.0
	P.dashes = P.max_dashes()
	aim_at(P, T.pos)
	var loosed0 := K.draw.loosed_at
	P.do_dash()
	var rolling := P.roll_t > 0.0
	for i in 3:
		P.inp["fire"] = true
		m.step(DT)
	step(m, 0.8, _let_go.bind(P))
	ok("pin dash > LMB: a tap during the roll is not lost, the arrow goes when the roll ends",
		rolling and K.draw.loosed_at > loosed0, "rolling %s loosed %.2f -> %.2f" % [rolling, loosed0, K.draw.loosed_at])
	step(m, 1.0)
	P.dashes = P.max_dashes()
	K.cd["e"] = 0.0
	K.ch_rmb = 2.0
	K.cd["rmb"] = 0.0
	P.do_dash()
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	var rmb_ok := K.rmb_down
	P.ak.use_e()
	var e_ok := float(K.cd["e"]) > 0.0
	P.inp["sec_hold"] = false
	step(m, 0.5)
	ok("pin dash > RMB and E: both start during the dash", rolling and rmb_ok and e_ok, "rmb %s e %s" % [rmb_ok, e_ok])
	_dash_moves(["pin_roll", "pin_flick"], {"pin_roll": 0.18, "pin_flick": 0.22})

## into_dash.x for Bjorn: Shift while planted for Faultline isn't lost, it goes when the plant ends.
func _bjorn_plant_dash(m: Match, P: Hunter, K: BulwarkKit) -> void:
	step(m, 1.5)
	P.lvl = 6
	K.cd["x"] = 0.0
	P.dashes = P.max_dashes()
	K.st["last_dash"] = ""
	press_x(m, P)
	step(m, 0.1)
	P.do_dash()
	var held_back := K.ult.planted() and P.roll_t <= 0.0
	var waited := 0.0
	while K.ult.planted() and waited < 1.0:
		m.step(DT)
		waited += DT
	step(m, 0.1)
	ok("bjorn plant > Shift: the dash waits through the plant (row: %s) and goes when it ends" %
			String(DashFlow.into_dash_of("bulwark", "x").get("mode")),
		held_back and String(K.st.get("last_dash")) == "whirl" and P.dashes < P.max_dashes(),
		"held %s last %s dashes %.2f" % [held_back, str(K.st.get("last_dash")), P.dashes])
	step(m, 2.5)

## #32 / #35 for Bjorn.
func _bjorn_dash(m: Match, P: Hunter, T: Hunter, K: BulwarkKit, home: Vector3) -> void:
	ok("bjorn dash table: LMB buffers, RMB / E fire, a held swing is cancelled by a dash",
		_mode("bulwark", "lmb", false) == "buffer" and _mode("bulwark", "lmb", true) == "buffer"
		and _mode("bulwark", "rmb", false) == "fire" and _mode("bulwark", "e", false) == "fire"
		and DashFlow.into_dash_of("bulwark", "lmb").get("mode") == "cancel")
	step(m, 1.5)
	P.teleport(home)
	T.teleport(home + Vector3(30.0, 0, 6.0))
	P.vel = Vector3.ZERO
	P.fire_cd = 0.0
	K.mace = {}
	P.dashes = P.max_dashes()
	aim_at(P, home + Vector3(5.0, 0, 0))
	var t0 := K.throws
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	var rolling := P.roll_t > 0.0
	for i in 3:
		P.inp["fire"] = true
		m.step(DT)
	P.inp["move"] = Vector2.ZERO
	step(m, 0.8, _let_go.bind(P))
	ok("bjorn dash > LMB: a tap during the dash is not lost, the hammer goes when it ends",
		rolling and K.throws == t0 + 1, "rolling %s throws %d" % [rolling, K.throws - t0])
	step(m, 1.0)
	K.mace = {}
	P.fire_cd = 0.0
	P.dashes = P.max_dashes()
	P.do_dash()
	var pressed_in_dash := P.roll_t > 0.0
	P.inp["fire"] = true
	step(m, 0.5)
	ok("bjorn dash > LMB held: a press made in the dash and held through it winds up the swing when the dash ends",
		pressed_in_dash and K.lmb_t > 0.0, "in dash %s hold %.2f" % [pressed_in_dash, K.lmb_t])
	P.inp["fire"] = false
	step(m, 1.0)
	P.dashes = P.max_dashes()
	K.cd["e"] = 0.0
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	P.do_dash()
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	var rmb_ok := K.rmb_down
	P.inp["aim"] = home
	P.ak.use_e()
	var e_ok := float(K.cd["e"]) > 0.0
	P.inp["sec_hold"] = false
	step(m, 0.5)
	ok("bjorn dash > RMB and E: both start during the dash", rolling and rmb_ok and e_ok, "rmb %s e %s" % [rmb_ok,
		e_ok])
	_bjorn_plant_dash(m, P, K)
	_dash_moves(["bul_whirl", "bul_charge", "bul_lumber", "bul_short"],
		{"bul_whirl": 0.2, "bul_charge": 0.27, "bul_lumber": 0.3, "bul_short": 0.15})
