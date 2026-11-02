extends "res://tools/hero_pair_check.gd"
## Breah's ultimate on X, Basalt Spine, for --dolm-combo-check (docs/heroes/dolm.md): the level gate, the
## tap (across the aim, at the cursor) and the hold-and-drag (pivots on its centre), the preview only while
## held, the 0.2s cracks everyone sees, the centre-out rise over 0.4s, the slow beside it, bodies shoved off
## the line, the rocks standing apart from Stone Row's, a punch along the ridge launching it, the bond only on
## a land (and inside its window), the merge drop while aiming, the cooldown and the burst cap.

const BURST := preload("res://tools/ult_burst.gd")

## Every ult assertion; returns when done (the caller prints the totals).
func ult(main_node: Node) -> void:
	main = main_node
	await _cast_and_rise()
	await _drag_slow_shove()
	await _punch_and_bond()
	await _guards()
	await _burst()

func _press(m: Match, P: Hunter, at: Vector3, hold_down: bool) -> void:
	P.ak.cd["x"] = 0.0
	aim_at(P, at)
	P.inp["x_down"] = hold_down
	P.ak.use_x()
	m.step(DT)

func _cast_and_rise() -> void:
	var r := setup("dolm", 9.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: DolmKit = P.ak
	var S := K.spine
	T.teleport(home + Vector3(0, 0, 9.0))
	P.lvl = 5
	_press(m, P, home + Vector3(7, 0, 0), false)
	ok("ult: no cast below level 6", not S.running() and float(K.cd["x"]) == 0.0, "level %d" % P.lvl)
	P.lvl = 6
	var paid0 := HeroUlt.paid_total
	_press(m, P, home + Vector3(7, 0, 0), false)
	var released := m.time
	m.step(DT)
	var cd_now := float(K.cd["x"])
	ok(
		"ult cast: a tap casts at once, the slam move plays, its own cooldown starts (45s)",
		S.phase == "tell" and K.anim_id == "breah_spine" and absf(cd_now - 45.0) < 0.2, "cd %.1f" % cd_now
	)
	var crack: Dictionary = AimKit.entry(P, "x_cracks")
	var across: bool = absf(S.axis.dot(Vector2(1, 0))) < 0.05
	var at_cursor: bool = Vector2(S.center.x - home.x - 7.0, S.center.z - home.z).length() < 0.2
	ok(
		"ult telegraph: the cracks show to everyone, at the cursor, across the aim, 19.8m",
		bool(crack.get("all", false)) and at_cursor and across and absf(float(crack.get("len", 0.0)) - 19.8) < 0.1,
		"axis %s" % str(S.axis)
	)
	step(m, 1.0)
	var first := S.first_rise_t - released
	ok("ult beats: the first rock rises 0.2s after the release (the cracks)", absf(first - 0.2) < 0.05, "%.2f" % first)
	var ult_rocks := rocks(m).filter(func(w): return w.has("ult"))
	var mids: Array = ult_rocks.map(func(w): return K.rock_mid(w))
	var near_mid := mids.any(func(p): return Vector2(p.x - S.center.x, p.z - S.center.z).length() < 0.1)
	ok(
		"ult: rocks all along the ridge, one at its centre",
		ult_rocks.size() >= 9 and near_mid,
		"rocks %d" % ult_rocks.size()
	)
	ok(
		"ult: the ridge's rocks are apart from Stone Row's (no pips, no cap)",
		K.rocks_up() == 0,
		"pips %d" % K.rocks_up()
	)
	ok(
		"ult bond: nothing when it catches nobody",
		HeroUlt.paid_total == paid0,
		"paid %.2f" % (HeroUlt.paid_total - paid0)
	)
	P.ak.use_x()
	ok("ult: the cooldown denies a new cast", S.casts == 1, "casts %d" % S.casts)
	var newest: float = ult_rocks.map(func(w): return float(w["t"])).max()
	var life := newest + m.time - S.last_rise_t
	ok("ult: the rocks stand 7s", absf(life - 7.0) < 0.1, "%.2f" % life)
	await done(m)

func _drag_slow_shove() -> void:
	var r := setup("dolm", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: DolmKit = P.ak
	var S := K.spine
	# hold: the preview shows only while held, and dragging swings the ridge round its centre
	_press(m, P, home + Vector3(6, 0, 0), true)
	ok("ult hold: X held aims (nothing cast yet), the crouch move holds", S.aiming() and K.anim_id == "breah_spine_aim")
	var prev: Dictionary = AimKit.entry(P, "x")
	ok("ult hold: the preview line with chevrons, yours only", AimKit.shown(P, "x") and not bool(prev.get("all", true)))
	aim_at(P, home + Vector3(9, 0, 3))
	step(m, 0.1)
	var want := Vector2(3, 3).normalized()
	var swung: Vector2 = AimKit.entry(P, "x").get("dir", Vector2.ZERO)
	ok("ult drag: the preview pivots on its centre toward the cursor", swung.dot(want) > 0.99, str(swung))
	# T stands right on the swung line, 2m from the centre: it is shoved aside, slowed, and that is a land
	var on_line := S.center + Vector3(want.x, 0, want.y) * 2.0
	T.teleport(on_line)
	var paid0 := HeroUlt.paid_total
	P.inp["x_down"] = false
	step(m, 0.9)
	ok("ult drag: let go casts along the dragged line", S.axis.dot(want) > 0.99 and S.phase == "up", str(S.axis))
	var off := absf(Vector2(T.pos.x - on_line.x, T.pos.z - on_line.z).dot(Vector2(-want.y, want.x)))
	ok("ult: a body on the line is shoved off it, never inside a rock", S.shoved >= 1 and off >= 0.75, "off %.2f" % off)
	ok(
		"ult: the rise slows a foe beside it (35% for 1s)",
		T.slow_t > 0.0 and absf(T.slow_k - 0.35) < 0.01,
		"slow %.2f" % T.slow_t
	)
	var paid := HeroUlt.paid_total - paid0
	ok("ult bond: a hunter slowed by the rise is a land (a hit: 0.6)", absf(paid - 0.6) < 0.001, "paid %.2f" % paid)
	paid0 = HeroUlt.paid_total
	step(m, 1.0)
	ok("ult bond: paid once per cast, nothing more while it stands", HeroUlt.paid_total == paid0)
	await done(m)

func _punch_and_bond() -> void:
	var r := setup("dolm", 16.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: DolmKit = P.ak
	_ridge_along(m, P, home)
	var spread := K.spine.last_rise_t - K.spine.first_rise_t
	ok("ult beats: the rocks rise from the centre outward over 0.4s", absf(spread - 0.4) < 0.05, "%.2f" % spread)
	var n_up := rocks(m).filter(func(w): return w.has("ult")).size()
	ok("ult: 13 rocks over 19.8m on open ground", n_up == 13, "rocks %d" % n_up)
	var paid0 := HeroUlt.paid_total
	var l0 := K.launches
	_punch(m, P, T)
	step(m, 0.8)
	ok(
		"ult combo: a punch along the ridge launches its rocks in a stream",
		K.launches - l0 >= 6,
		"launched %d" % (K.launches - l0)
	)
	var cap := float(K.x_def()["rock_cap"])
	ok(
		"ult combo: the ridge's rocks hit, at most 40 to one hunter",
		dmg(T) > 10.0 and dmg(T) <= cap + 0.5,
		"dmg %.1f" % dmg(T)
	)
	ok(
		"ult bond: a ridge rock into a hunter is a land",
		HeroUlt.paid_total - paid0 > 0.0,
		"paid %.2f" % (HeroUlt.paid_total - paid0)
	)
	# after the 4s window its rocks no longer fill the bond
	step(m, float(K.x_def()["time"]))
	fresh(T)
	_ridge_along(m, P, home)
	step(m, float(K.x_def()["bond_t"]) + 0.2)
	paid0 = HeroUlt.paid_total
	_punch(m, P, T)
	step(m, 0.8)
	ok(
		"ult bond: a ridge rock after the 4s window pays nothing",
		dmg(T) > 0.0 and HeroUlt.paid_total == paid0,
		"dmg %.1f" % dmg(T)
	)
	await done(m)

## A ridge laid along the aim (+x) from just behind her toward a target 16m out, its far end well short of it.
func _ridge_along(m: Match, P: Hunter, home: Vector3) -> void:
	for w in m.verbs.walls.duplicate():
		m.verbs._break_wall(w)
	P.teleport(home)
	_press(m, P, home + Vector3(3, 0, 0), true)
	aim_at(P, home + Vector3(8, 0, 0))
	step(m, 0.05)
	P.inp["x_down"] = false
	step(m, 0.75)

func _punch(m: Match, P: Hunter, T: Hunter) -> void:
	aim_at(P, T.pos)
	P.fire_cd = 0.0
	step(m, 0.95, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	m.step(DT)

func _guards() -> void:
	var r := setup("dolm", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[3]
	var K: DolmKit = P.ak
	_press(m, P, home + Vector3(6, 0, 0), true)
	var merged := _merge(P)
	step(m, 0.1)
	var ok_drop := merged and not K.spine.running() and float(K.cd["x"]) == 0.0
	ok("merge hold: a merge while aiming the ult drops it, not spent", ok_drop, "phase '%s'" % K.spine.phase)
	await done(m)
	r = setup("dolm", 6.0)
	m = r[0]
	P = r[1]
	home = r[3]
	K = P.ak
	_press(m, P, home + Vector3(6, 0, 0), true)
	P.stun_t = 0.5
	step(m, 0.1)
	ok("ult hold: a stun while aiming cancels it, not spent", not K.spine.running() and float(K.cd["x"]) == 0.0)
	await done(m)

## Burst cap: the ridge, a full punch launching it into a light hunter, then straight into the merge and the
## merged form's ultimate, leaves that hunter standing.
func _burst() -> void:
	var ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var land := func(m: Match, P: Hunter, T: Hunter) -> void:
		var home := P.pos
		T.teleport(home + Vector3(16, 0, 0))
		_ridge_along(m, P, home)
		_punch(m, P, T)
		step(m, 0.8)
		T.teleport(P.pos + Vector3(2.5, 0, 0))      # the merge closes in: its ultimate must reach the target
	var out: Dictionary = await BURST.run(ac, "dolm", 16.0, land)
	var real_burst: bool = float(out["ult"]) > 10.0 and float(out["total"]) > float(out["ult"])
	var standing: bool = bool(out["merged"]) and bool(out["alive"]) and real_burst
	ok(
		"ult burst: ridge, punch, merge and its ultimate leave a full-health light hunter standing",
		standing,
		"ult %.1f total %.1f of %.0f" % [float(out["ult"]), float(out["total"]), float(Data.CLASSES["light"]["hp"])]
	)
