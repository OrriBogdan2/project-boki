extends "res://tools/hero_pair_check.gd"
## Motley's ultimate on X, Nightwell, for --ostra-combo-check (docs/heroes/ostra.md): the level gate, the well at
## the cursor clamped to 10m, the 1.0s dome everyone sees, the opening, the catch (stunned until it closes and
## drawn to the middle), a foe walking in later, a foe behind a wall, allies untouched, Motley locked in the
## cast for the 1.0s dome and then free while the well runs, the small ticks, the quiet close, the Swollen
## size, the bond once per cast and only on a catch, the cooldown, the merge (the placed well stays) and the burst cap.

const BURST := preload("res://tools/ult_burst.gd")

## Every ult assertion; returns when done (the caller prints the totals).
func ult(main_node: Node) -> void:
	main = main_node
	await _cast_and_dome()
	await _catch_and_hold()
	await _lock_and_release()
	await _swollen_and_merge()
	await _lock_breaks()
	await _burst()

## The pair check's strip and dummy, with a Boki ready at his side (the bond only fills with one).
func setup_ult(arch: String, dist: float) -> Array:
	var r := setup(arch, dist)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var rec := Save.new_kin("puddlet")
	rec["trust"] = 95.0
	var kin: Kin = m.give_kin(P, rec)
	kin.stow()
	kin.brain.think_t = 1e9
	return r

## The bond this hunter's current ult cast has paid (KinBond keeps it on the hunter by cast id).
func paid(P: Hunter) -> float:
	var c: Dictionary = P.get_meta("bond_cast", {})
	if String(c.get("id", "")) != HeroUlt.cast_id(P.ak):
		return 0.0
	return float(c.get("got", 0.0))

func _press(m: Match, P: Hunter, at: Vector3) -> void:
	P.ak.cd["x"] = 0.0
	aim_at(P, at)
	HunterKeys.ult_pressed(P)
	m.step(DT)

func _cast_and_dome() -> void:
	var r := setup_ult("ostra", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: OstraKit = P.ak
	var W := K.well
	T.teleport(home + Vector3(0, 0, 6.5))
	P.lvl = 5
	_press(m, P, home + Vector3(6, 0, 0))
	ok("ult: no cast below level 6", not W.running() and float(K.cd["x"]) == 0.0, "level %d" % P.lvl)
	P.lvl = 6
	var paid0 := paid(P)
	_press(m, P, home + Vector3(6, 0, 0))
	ok("ult: one X press is one cast", int(P.used.get("x", 0)) == 1 and W.casts == 1, "used %s" % str(P.used.get("x")))
	var cd_now := float(K.cd["x"])
	ok(
		"ult cast: a tap sets the well at the cursor, the thrust move plays, its own cooldown starts (70s, data)",
		W.phase == "tell" and K.anim_id == "ostra_well" and absf(cd_now - 70.0) < 0.2
			and W.center.distance_to(home + Vector3(6, 0, 0)) < 0.3,
		"cd %.1f at %s" % [cd_now, str(W.center - home)]
	)
	step(m, 0.5)
	var dome: Dictionary = AimKit.entry(P, "x")
	ok(
		"ult telegraph: a dome of the exact size (3.6m) everyone sees, filling over 1.0s",
		bool(dome.get("all", false)) and absf(float(dome.get("r", 0.0)) - 3.6) < 0.05
			and absf(float(dome.get("fill", 0.0)) - 0.5) < 0.1 and KitLooks.of(m).holding("os_well_dome"),
		"fill %.2f" % float(dome.get("fill", 0.0))
	)
	var t := 0.5
	while not W.is_open() and t < 2.0:
		m.step(DT)
		t += DT
	ok("ult beats: it opens 1.0s after the press", absf(t - 1.0) < 0.05 and K.anim_id == "ostra_well_snap", "%.2f" % t)
	step(m, 3.6)
	ok("ult: it closes after 3.5s, quietly", not W.running() and W.opens == 1, "phase '%s'" % W.phase)
	ok(
		"ult bond: nothing when it catches nobody",
		paid(P) == paid0,
		"paid %.2f" % (paid(P) - paid0)
	)
	HunterKeys.ult_pressed(P)
	ok("ult: the cooldown denies a new cast", W.casts == 1, "casts %d" % W.casts)
	_press(m, P, home + Vector3(25, 0, 0))
	var reach := Vector2(W.center.x - home.x, W.center.z - home.z).length()
	ok("ult aim: past its range it is set at 10m toward the cursor", reach <= 10.05 and reach > 8.0, "%.1f" % reach)
	await done(m)

func _catch_and_hold() -> void:
	var r := setup_ult("ostra", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: OstraKit = P.ak
	var W := K.well
	var c := home + Vector3(6, 0, 0)
	T.teleport(c + Vector3(2.5, 0, 0))
	var late: Hunter = m.make_hunter("L", 5, "medium", "Late", "idle", {}, c + Vector3(0, 0, 6.0), {"arch": "none"})
	var hid: Hunter = m.make_hunter("H", 5, "medium", "Hidden", "idle", {}, c + Vector3(0, 0, -3.0), {"arch": "none"})
	var ally: Hunter = m.make_hunter(
		"A",
		P.team,
		"medium",
		"Ally",
		"idle",
		{},
		c + Vector3(-2.0, 0, 1.0),
		{"arch": "none"}
	)
	for e in [late, hid, ally]:
		e.max_hp = 10000.0
		e.hp = e.max_hp
	HeroZones.rock(m, P, c + Vector3(0, 0, -1.8), Vector2(0, 1), "wall", 2.0, 30.0, 999.0, false)
	var paid0 := paid(P)
	var props := _props(m, c)
	_press(m, P, c)
	step(m, 1.05)
	ok(
		"ult open: a foe inside is caught and stunned until it closes",
		T.stun_t > 3.2 and KitLooks.of(m).crowned(T),
		"stun %.2f" % T.stun_t
	)
	var paid := paid(P) - paid0
	ok("ult bond: a hunter caught when it opens is a land (a hit: 0.6)", absf(paid - 0.6) < 0.001, "paid %.2f" % paid)
	step(m, 0.5)
	var off := Vector2(T.pos.x - c.x, T.pos.z - c.z).length()
	ok("ult: the caught foe is drawn to the middle", off < 0.5, "off %.2f" % off)
	ok("ult: a foe behind a wall is not caught", hid.stun_t <= 0.0 and dmg(hid) == 0.0, "stun %.2f" % hid.stun_t)
	ok("ult: an ally inside is untouched", ally.stun_t <= 0.0 and dmg(ally) == 0.0 and ally.pos.distance_to(c) > 1.5)
	late.teleport(c + Vector3(0, 0, 3.0))
	step(m, 0.3)
	ok("ult: a foe who walks in later is caught too", late.stun_t > 1.0, "stun %.2f" % late.stun_t)
	paid0 = paid(P)
	step(m, 2.75)
	ok("ult bond: paid once per cast, never per tick", paid(P) == paid0)
	var per := float(K.x_def()["tick_dmg"]) * K.power("x")
	ok("ult payoff: small ticks every 0.1s (35 over 3.5s)", absf(dmg(T) - per * 35.0) < per * 2.0, "dmg %.2f" % dmg(T))
	step(m, 0.3)
	ok("ult: the stun ends when it closes", not W.running() and T.stun_t <= 0.05, "stun %.2f" % T.stun_t)
	ok(
		"ult plain: a well that is not Empowered breaks and lights nothing",
		props.all(func(b): return not b["dead"] and not b.has("fuse_t"))
	)
	await done(m)

## A crate, a pot and a keg inside the well's reach (Swollen 5.1m, plain 3.6m), 2.6m out.
func _props(m: Match, c: Vector3) -> Array:
	var out := []
	for i in 3:
		var at := c + Vector3(2.6, 0, 0).rotated(Vector3.UP, TAU * (float(i) + 0.5) / 3.0)
		at.y = m.world.ground_at(at.x, at.z)
		m._add_break(["crate", "pot", "keg"][i], at)
		out.append(m.breaks[-1])
	return out

func _swollen_and_merge() -> void:
	var r := setup_ult("ostra", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: OstraKit = P.ak
	var W := K.well
	var c := home + Vector3(6, 0, 0)
	T.teleport(c + Vector3(4.5, 0, 0))
	K.swollen_t = 5.0
	_press(m, P, c)
	m.step(DT)
	var dome: Dictionary = AimKit.entry(P, "x")
	ok(
		"ult Swollen: the well is 5.1m wide, with the pink core",
		absf(W.radius - 5.1) < 0.01 and W.swollen,
		"r %.1f" % W.radius
	)
	ok("ult Swollen: its dome shows the bigger size", absf(float(dome.get("r", 0.0)) - 5.1) < 0.05)
	var props := _props(m, c)
	step(m, 1.0)
	ok(
		"ult Swollen: Empowered ticks are Explosive, they break a crate and a pot and light a keg",
		props[0]["dead"] and props[1]["dead"] and (props[2].has("fuse_t") or props[2]["dead"])
	)
	var merged := _merge(P)
	step(m, 1.2)
	ok(
		"merge: a merge doesn't take the placed well down",
		merged and W.is_open() and T.stun_t > 2.0,
		"stun %.2f" % T.stun_t
	)
	await done(m)

## A hard CC frees him early from the cast (a stun, then a knock); the placed well goes on either way.
func _lock_breaks() -> void:
	var r := setup_ult("ostra", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[3]
	var K: OstraKit = P.ak
	var W := K.well
	_press(m, P, home + Vector3(6, 0, 0))
	step(m, 0.5)
	P.stun_t = 0.4
	m.step(DT)
	ok("lock: a stun frees him early, the well goes on", not W.locked and W.running(), "phase '%s'" % W.phase)
	step(m, 5.0)
	K.cd["x"] = 0.0
	_press(m, P, home + Vector3(6, 0, 0))
	step(m, 0.4)
	var at := P.pos
	P.impulse(Vector2(8.0, 0) * P.mass())
	step(m, 0.3)
	ok(
		"lock: a knock frees him (and moves him), the well goes on",
		not W.locked and W.running() and P.pos.distance_to(at) > 0.8,
		"moved %.2f" % P.pos.distance_to(at)
	)
	await done(m)

## Burst cap: the well's full 3.5s on a light hunter, then straight into the merge and the merged form's
## ultimate, leaves that hunter standing.
func _burst() -> void:
	var ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var land := func(m: Match, P: Hunter, T: Hunter) -> void:
		P.ak.cd["x"] = 0.0
		aim_at(P, T.pos)
		HunterKeys.ult_pressed(P)
		step(m, 4.6)
	var out: Dictionary = await BURST.run(ac, "ostra", 2.5, land)
	var real_burst: bool = float(out["ult"]) > 3.0 and float(out["total"]) > float(out["ult"])
	var standing: bool = bool(out["merged"]) and bool(out["alive"]) and real_burst
	ok(
		"ult burst: the well, merge and its ultimate leave a full-health light hunter standing",
		standing,
		"ult %.1f total %.1f of %.0f" % [float(out["ult"]), float(out["total"]), float(Data.CLASSES["light"]["hp"])]
	)

## The lock (Void's footage holds the cast for the 1.0s telegraph, f23-f33, and acts freely
## once it opens, f50): from the press until the well opens Motley can't walk, use another ability or attack, or
## turn once the wind-up is over; when it opens he is free to walk out at full speed and fight while it holds.
func _lock_and_release() -> void:
	var r := setup_ult("ostra", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[3]
	var K: OstraKit = P.ak
	var W := K.well
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	P.fire_cd = 0.0
	_press(m, P, home + Vector3(6, 0, 0))
	step(m, 0.3)
	var at := P.pos
	var snaps0 := K.snaps
	var face0 := P.aim_dir()
	aim_at(P, home + Vector3(0, 0, -6))
	P.inp["move"] = Vector2(-1, 0)
	tap(m, P)
	P.inp["fire"] = true
	var seeds0 := K.seed.size()
	K.use_e()
	step(m, 0.3)
	P.inp["fire"] = false
	ok("lock: movement input doesn't move him", Vector2(P.pos.x - at.x, P.pos.z - at.z).length() < 0.05)
	ok("lock: an RMB press and an attack are ignored", K.snaps == snaps0 and K.snap.is_empty() and P.shot_n == 0)
	ok("lock: an E press is ignored (no seed)", K.seed.size() == seeds0 and K.seed.is_empty())
	ok("lock: the glove and the Boki's C are held too (the cast_locked hook)", K.cast_locked())
	ok("lock: he cannot turn once committed", P.aim_dir().distance_to(face0) < 0.01 and W.locked)
	ok("lock: the cast pose is held while the dome fills (ostra_well)", K.anim_id == "ostra_well")
	var t := 0.6 + DT * 2.0
	while not W.is_open() and t < 2.0:
		m.step(DT)
		t += DT
	ok(
		"lock: it lasts the 1.0s cast (Void's telegraph), then he is free and the well runs on",
		absf(t - 1.0) < 0.05 and not W.locked and not K.busy() and W.is_open() and K.anim_id == "ostra_well_snap",
		"freed at %.2fs" % t
	)
	step(m, 0.3)
	var from := P.pos
	step(m, 0.5)
	var speed := Vector2(P.pos.x - from.x, P.pos.z - from.z).length() / 0.5
	ok(
		"release: shortly after he walks out at >= 90% run speed while the well holds",
		speed >= 0.9 * P.base_speed and W.is_open(),
		"%.2f of %.2f m/s, well %s" % [speed, P.base_speed, W.phase]
	)
	P.inp["move"] = Vector2.ZERO
	aim_at(P, home + Vector3(0, 0, -6))
	tap(m, P)
	step(m, 0.4)
	ok("release: he can act while it holds (a Snap)", K.snaps == snaps0 + 1 and W.is_open(), "snaps %d" % K.snaps)
	var y0 := P.pos.y
	P.inp["jump"] = true
	step(m, 0.1)
	P.inp["jump"] = false
	ok(
		"release: a jump while it holds goes at once (into_jump.x locks only the cast)",
		P.pos.y > y0 + 0.05 and W.is_open()
	)
	step(m, 3.0)
	K.cd["x"] = 0.0
	_press(m, P, home + Vector3(6, 0, 0))
	step(m, 0.3)
	P.dashes = P.max_dashes()
	K.on_dash(false)
	step(m, 0.3)
	ok(
		"dash flow: Shift during the lock is held, not lost (no Trade yet)",
		W.locked and K.swap.is_empty() and K.swap_aim < 0.0
	)
	step(m, 0.45)
	ok(
		"dash flow: ... and goes the step the well opens and frees him (into_dash.x buffer)",
		not W.locked and W.is_open() and (K.swap_aim >= 0.0 or not K.swap.is_empty())
	)
	await done(m)
