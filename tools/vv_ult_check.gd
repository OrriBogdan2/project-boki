extends RefCounted
## The ultimates on X in --mage-combo-check (Kitefall) and --gunslinger-combo-check (Cinderfall): the level gate
## (main's, through HunterKeys.ult_pressed), one cast per press, the telegraph, the payoff, the cooldown, the bond
## paid only when it lands, the Boki merge mid-cast, and the burst cap (the ult then the merge never one-shots a
## full-health light hunter). Runs inside tools/hero_combo_check.gd and reports through its ok().

const BURST := preload("res://tools/ult_burst.gd")
const KIN := "pebbit"            # a Boki to bond with (the bond only fills while one is ready)

var hc: RefCounted                # tools/hero_combo_check.gd
var ac: RefCounted                # tools/archetype_check.gd

func _init(combo_check: RefCounted) -> void:
	hc = combo_check
	ac = combo_check.ac

func ok(what: String, cond: bool, info := "") -> void:
	hc.ok(what, cond, info)

## What this cast has paid the bond so far (KinBond keeps it on the hunter per cast id).
func _paid(P: Hunter, cast_id: String) -> float:
	var c: Dictionary = P.get_meta("bond_cast", {})
	return float(c.get("got", 0.0)) if String(c.get("id", "")) == cast_id else 0.0

func _cast_id(K: ArchKit) -> String:
	return HeroUlt.cast_id(K)

## Below the unlock level X does nothing; at it, one press is one cast.
func _gate(m: Match, P: Hunter, K: ArchKit) -> void:
	ok("X: the hero has an ultimate (the HUD tile shows)", K.has_ult() and not K.x_def().is_empty())
	P.lvl = int(Hunter.ULT_AT[0]) - 1
	var pressed := HunterKeys.ult_pressed(P)
	ac.step(m, 0.05)
	ok("X: no cast below level %d" % int(Hunter.ULT_AT[0]),
			not pressed and float(K.cd["x"]) == 0.0 and int(P.used.get("x", 0)) == 0)
	P.lvl = int(Hunter.ULT_AT[0])

# ------------------------------------------------------------------ Sparkle: Kitefall
func mage() -> void:
	var r: Array = ac.setup("mage", 6.0, KIN, true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: MageKit = P.ak
	var U := K.ult
	var xd := K.x_def()
	_gate(m, P, K)
	# the press: one cast, the cooldown starts, the crouch
	T.teleport(home + Vector3(6, 0, 0))
	T2.teleport(home + Vector3(6.5, 0, 1.2))
	ac.aim_at(P, T.pos)
	ok("Kitefall: the press goes off", HunterKeys.ult_pressed(P))
	ok("Kitefall: one press is one cast, its own cooldown starts",
			U.casts == 1 and int(P.used.get("x", 0)) == 1 and is_equal_approx(float(K.cd["x"]), float(xd["cooldown"])),
			"casts %d cd %.1f" % [U.casts, float(K.cd["x"])])
	ok("Kitefall: the crouch first (mage_x)", U.phase() == MageUlt.CROUCH and K.anim_id == "mage_x")
	ac.step(m, 0.6, func(): ac.aim_at(P, T.pos))
	# up there: high, invulnerable, the ring for everyone, the crown at the cursor, nothing else works
	var hanging := U.phase() == MageUlt.AIR and P.pos.y > home.y + 3.5
	ok("Kitefall: launched up and hanging", hanging and K.anim_id == "mage_x_air",
			"y +%.1f %s" % [P.pos.y - home.y, U.phase()])
	var ring := AimKit.entry(P, "x_ring")
	var ring_r := float(ring.get("r", 0.0))
	ok("Kitefall: the gold range ring (8 bh) round the take-off, seen by everyone",
			AimKit.shown(P, "x_ring") and bool(ring.get("all", false)) and absf(ring_r - 8.0 * AimKit.BH) < 0.1,
			"r %.1f" % float(ring.get("r", 0.0)))
	ok("Kitefall: the crown reticle sits at the cursor", AimKit.shown(P, "x_aim")
			and Vector2(T.pos.x, T.pos.z).distance_to(AimKit.entry(P, "x_aim")["at"] as Vector2) < 0.6)
	var hp0 := P.hp + P.armor + P.shield
	P.hurt(40.0, T, {"src": "abil", "ab": "k1"})
	ok("Kitefall parity: shots pass through her up there (data), a blow still lands",
			P.phase_t > 0.0 and P.inv_t <= 0.0 and P.hp + P.armor + P.shield < hp0,
			"phase %.2f inv %.2f" % [P.phase_t, P.inv_t])
	K.cd["e"] = 0.0
	K.use_e()
	ok("Kitefall: nothing else of hers works up there (E, the attack)",
			K.strikes.is_empty() and not K.fire_ok() and K.busy())
	# the landing spot: clamped inside the ring, never in a wall
	ac.aim_at(P, home + Vector3(40, 0, 0))
	ok("Kitefall: the landing is clamped inside the ring",
			absf(hc._flat(U.land_point(), home) - float(xd["range"])) < 0.6, "%.1f m" % hc._flat(U.land_point(), home))
	var wall_at := home + Vector3(3.5, 0, -3.0)
	hc._wall(m, wall_at)
	ac.aim_at(P, wall_at)
	var lp := U.land_point()
	ok("Kitefall: a landing in a wall backs off onto the ground", not m.world.is_block(lp.x, lp.z))
	hc._unwall(m, wall_at)
	# the second press: the strike at the cursor hits both, knocks them back, adds Static, pays the bond once
	ac.aim_at(P, T.pos)
	var id := _cast_id(K)
	var t_at := T.pos
	ok("Kitefall: the second press brings her down", HunterKeys.ult_pressed(P) and U.phase() == MageUlt.FALL)
	ok("Kitefall: the landing marker shows for everyone",
			AimKit.shown(P, "x_land") and bool(AimKit.entry(P, "x_land").get("all", false)))
	ac.step(m, float(xd["drop"]) + 0.05)
	var want := float(xd["dmg"]) * K.ult.power()
	ok("Kitefall: she lands on the spot and the strike hits both foes",
			hc._flat(P.pos, t_at) < 0.8 and U.last.get("hits", 0) == 2
			and absf(ac.dmg(T) - want) < 0.5 and ac.dmg(T2) > 1.0,
			"hits %d took %.1f want %.1f" % [int(U.last.get("hits", 0)), ac.dmg(T), want])
	var moved: float = hc._flat(T.pos, t_at)
	ok("Kitefall: a knockback and 1 Static each", moved > 0.4 and K.spark_n(T) >= 1 and K.spark_n(T2) >= 1,
			"moved %.2f static %d %d" % [moved, K.spark_n(T), K.spark_n(T2)])
	ok("Kitefall: the bond fills once, for the best event of the cast (a hit)",
			is_equal_approx(_paid(P, id), float(KinBond.rules()["hit"]))
			and P.ult >= float(KinBond.rules()["hit"]) - 0.01,
			"paid %.2f bar %.2f" % [_paid(P, id), P.ult])
	ok("Kitefall: free again at once (the attack works, gold crackle at her feet)",
			U.phase() == MageUlt.AFTER and K.fire_ok() and K.anim_id == "mage_x_land")
	ok("Kitefall: on cooldown, a press now does nothing", not HunterKeys.ult_pressed(P) and U.casts == 1)
	ac.step(m, 0.6)
	await _mage_whiff(m, P, K, home)
	await _mage_merge(m, P, K, home)
	_mage_shift(m, P, K, home)
	_mage_jump(m, P, K, home)
	_mage_spread(m, P, T, T2, K, home)
	await _mage_116(m, P, T, T2, K, home)
	await ac.done(m)
	await _mage_burst()
	var flow = load("res://tools/dash_flow_check.gd").new()
	var bad: int = await flow.combos_of(hc.main, "mage")
	ok("Sparkle item 51: each slot casts mid-jump; Shift / jump out of it act in 0.1 s; the Rod held on",
			bad == 0, "%d failing (the DASHFLOW lines)" % bad)

## A cast that strikes empty ground: comes down by itself at the cursor when the hover runs out, pays no bond.
func _mage_whiff(m: Match, P: Hunter, K: MageKit, home: Vector3) -> void:
	var U := K.ult
	var xd := K.x_def()
	K.cd["x"] = 0.0
	P.teleport(home)
	P.ult = 0.0
	var spot := home + Vector3(-4, 0, 3)
	ac.aim_at(P, spot)
	HunterKeys.ult_pressed(P)
	var id := _cast_id(K)
	var air := float(xd["windup"]) + float(xd["rise"]) + float(xd["hover"]) + float(xd["drop"])
	ac.step(m, air + 0.1, func(): ac.aim_at(P, spot))
	ok("Kitefall: with no second press she comes down by herself at the cursor",
			U.phase() == MageUlt.AFTER and hc._flat(P.pos, spot) < 0.6, "%.1f m off" % hc._flat(P.pos, spot))
	ok("Kitefall: a strike that hits nobody pays no bond", _paid(P, id) == 0.0 and U.last.get("hits", -1) == 0,
			"paid %.2f bar %.2f" % [_paid(P, id), P.ult])
	ac.step(m, 0.6)

## A Boki merge while she hangs: she drops where she took off, nothing strikes, the cooldown stays spent.
func _mage_merge(m: Match, P: Hunter, K: MageKit, home: Vector3) -> void:
	var U := K.ult
	K.cd["x"] = 0.0
	P.teleport(home)
	var hits := U.hits
	ac.aim_at(P, home + Vector3(6, 0, 0))
	HunterKeys.ult_pressed(P)
	ac.step(m, 0.7)
	var up := U.phase() == MageUlt.AIR
	ok("merge hold: Kitefall is in the air before the merge", up and ac.merge_now(P))
	ac.step(m, 0.3)
	ok("merge hold: Kitefall drops (no strike, back on the ground, cooldown spent)",
			not U.running() and U.hits == hits and P.pos.y < home.y + 0.6 and float(K.cd["x"]) > 0.0,
			"y +%.1f" % (P.pos.y - home.y))
	KinMerge.end(P, "test")

## Item 72: the highest Static among the foes the strike hits goes to every foe it hits (then the ult's own
## stack, capped at 4); a foe outside the strike gets nothing; no stacked foe, nothing spreads.
func _mage_spread(m: Match, P: Hunter, T: Hunter, T2: Hunter, K: MageKit, home: Vector3) -> void:
	var spot := home + Vector3(5, 0, 0)
	var far := T2.pos
	var got := _kitefall_with(m, P, T, T2, K, home, spot, 3, 0)
	ok("Kitefall: stacks {3, 0} -> both at 4 (the highest, plus the ult's own, capped)",
			got == [4, 4], str(got))
	got = _kitefall_with(m, P, T, T2, K, home, spot, 1, 0)
	ok("Kitefall: stacks {1, 0} -> both at 2", got == [2, 2], str(got))
	got = _kitefall_with(m, P, T, T2, K, home, spot, 0, 0)
	ok("Kitefall: no stacked foe -> nothing spreads, each gets only the ult's 1", got == [1, 1], str(got))
	ac.fresh(T2)
	T2.teleport(far)
	K.sparks.clear()

func _kitefall_with(m: Match, P: Hunter, T: Hunter, T2: Hunter, K: MageKit, home: Vector3, spot: Vector3,
		a: int, b: int) -> Array:
	var xd := K.x_def()
	K.cd["x"] = 0.0
	P.teleport(home)
	ac.fresh(T)
	ac.fresh(T2)
	T.teleport(spot + Vector3(0.8, 0, 0))
	T2.teleport(spot + Vector3(-0.8, 0, 0))
	K.sparks.clear()
	if a > 0: K.add_spark(T, a)
	if b > 0: K.add_spark(T2, b)
	ac.aim_at(P, spot)
	HunterKeys.ult_pressed(P)
	ac.step(m, float(xd["windup"]) + float(xd["rise"]) + float(xd["min_air"]) + 0.05, func(): ac.aim_at(P, spot))
	HunterKeys.ult_pressed(P)
	ac.step(m, float(xd["drop"]) + 0.1)
	var res := [K.spark_n(T), K.spark_n(T2)]
	ac.step(m, 0.6)
	return res

## Item 116: what play showed and the {3, 0} test above could not. The landing comes from the cursor's ray on the
## ground, not inp["aim"] (the plane at her own height, 5 m up, or a foe's); Static waits for her while she is up;
## the spread is drawn from the stacked foe even when the ult's own stack lands on it first.
func _mage_116(m: Match, P: Hunter, T: Hunter, T2: Hunter, K: MageKit, home: Vector3) -> void:
	var U := K.ult
	var xd := K.x_def()
	var spot := home + Vector3(6.0, 0, 2.0)
	var g := Vector3(spot.x, K.ground(spot).y, spot.z)
	var cam_at := g + Vector3(0, 21.0, 9.4)
	var ray_dir := (g - cam_at).normalized()
	var ray := [cam_at, ray_dir]
	K.cd["x"] = 0.0
	P.teleport(home)
	K.sparks.clear()
	HunterKeys.ult_pressed(P)
	var hang := func() -> void:
		# as Match does: inp["aim"] is the ray cut at her own height + 0.95, inp["aim_ray"] the ray itself
		var t := ((P.pos.y + 0.95) - cam_at.y) / ray_dir.y
		P.inp["aim"] = cam_at + ray_dir * t
		P.inp["aim_ray"] = ray
	ac.step(m, float(xd["windup"]) + float(xd["rise"]) + float(xd["min_air"]) + 0.05, hang)
	var off: float = hc._flat(U.land_point(), g)
	var naive := Vector2(P.inp["aim"].x - g.x, P.inp["aim"].z - g.z).length()
	ok("Kitefall lands exactly at the cursor, from 5 m up",
			off < 0.1, "%.2f m off (the aim plane is %.2f m off)" % [off, naive])
	HunterKeys.ult_pressed(P)
	ac.step(m, float(xd["drop"]) + 0.1, hang)
	ok("Kitefall: she is on that spot", hc._flat(P.pos, g) < 0.1, "%.2f m" % hc._flat(P.pos, g))
	ac.step(m, 0.7)
	P.inp.erase("aim_ray")
	# Static out-waits the flight: a stack put on just before a full hover is still there when she lands
	K.cd["x"] = 0.0
	P.teleport(home)
	ac.fresh(T)
	ac.fresh(T2)
	T.teleport(spot + Vector3(0.8, 0, 0))
	T2.teleport(spot + Vector3(-0.8, 0, 0))
	K.sparks.clear()
	K.add_spark(T, 2)
	var dur := float(K.res_def()["dur"])
	ac.step(m, dur - 2.2)
	ac.aim_at(P, spot)
	HunterKeys.ult_pressed(P)
	var whole := float(xd["windup"]) + float(xd["rise"]) + float(xd["hover"]) + float(xd["drop"]) + 0.1
	ac.step(m, whole, func(): ac.aim_at(P, spot))
	ok("Kitefall: Static waits for her in the air (2 + the ult's 1 on the stacked foe)",
			K.spark_n(T) == 3, str(K.spark_n(T)))
	ok("Kitefall: the waited Static still spreads", K.spark_n(T2) == 3, str(K.spark_n(T2)))
	ac.step(m, 0.6)
	# drawn whichever foe the loop reaches first
	for first in [T, T2]:
		var other: Hunter = T2 if first == T else T
		K.cd["x"] = 0.0
		P.teleport(home)
		ac.fresh(T)
		ac.fresh(T2)
		T.teleport(spot + Vector3(0.8, 0, 0))
		T2.teleport(spot + Vector3(-0.8, 0, 0))
		K.sparks.clear()
		K.add_spark(first, 2)
		ac.aim_at(P, spot)
		var before := int(U.get("spreads") if U.get("spreads") != null else 0)
		HunterKeys.ult_pressed(P)
		var air := float(xd["windup"]) + float(xd["rise"]) + float(xd["min_air"]) + 0.05
		ac.step(m, air, func(): ac.aim_at(P, spot))
		HunterKeys.ult_pressed(P)
		ac.step(m, float(xd["drop"]) + 0.1)
		var drawn := int(U.get("spreads") if U.get("spreads") != null else 0) - before
		var when := "first" if first == T else "second"
		ok("Kitefall: the spread is drawn, stacked foe %s" % when, drawn == 1, str(drawn))
		ok("Kitefall: and counted", K.spark_n(other) == 3, str(K.spark_n(other)))
		ac.step(m, 0.6)
	ac.fresh(T2)
	K.sparks.clear()
	await _mage_116b(m, P, T, K, home)

## Items 116.2 and 116b: the bolt rate, and the Wirerun after a reset (further, charged quicker), press and hold.
func _mage_116b(m: Match, P: Hunter, T: Hunter, K: MageKit, home: Vector3) -> void:
	var pd: Dictionary = P.wpn
	ok("LMB: the bolts 10% faster (0.72 x 0.9)", absf(float(pd["rate"]) - 0.648) < 0.001, str(pd["rate"]))
	var dd := K.dash_def()
	var far := float(dd["dist"][1])
	var hold := float(dd["hold"])
	K.reset_dash_boost = false
	ok("Wirerun: a plain run stays 7.5 to 13 m, full at 0.6 s",
			absf(K.wire_len(0.0) - float(dd["dist"][0])) < 0.01 and absf(K.wire_len(hold) - far) < 0.01)
	K.cd["dash"] = 0.0
	P.teleport(home)
	K.grant_reset()
	ok("Wirerun: a reset arms the longer run", K.reset_dash_boost)
	P.dashes = P.max_dashes()
	K.on_dash(false)
	var boosted := bool(K.wire.get("boost", false))
	ok("Wirerun: the press takes the boost", boosted and not K.reset_dash_boost)
	var quick := hold * float(dd["reset_charge"])
	ok("Wirerun: the reset run charges in 0.75x the time",
			absf(K.wire_hold() - quick) < 0.001, "%.3f s" % K.wire_hold())
	ok("Wirerun: full at that time, 1.5x further", absf(K.wire_len(quick) - far * 1.5) < 0.01,
			"%.2f m" % K.wire_len(quick))
	ok("Wirerun: a tap is still a short zap, 1.5x", absf(K.wire_len(0.0) - float(dd["dist"][0]) * 1.5) < 0.01)
	K._end_wire(true)
	K.reset_dash_boost = false
	K.grant_reset()
	ac.step(m, float(dd["reset_window"]) + 0.1)
	ok("Wirerun: the boost fades if the reset goes unused", not K.reset_dash_boost)

## Item 51: Shift in Kitefall's crouch charges the Wirerun at once; the crouch waits for the run, starts over
## where it ended, and she launches from there (the ring moves with her) and still comes down.
func _mage_shift(m: Match, P: Hunter, K: MageKit, home: Vector3) -> void:
	var U := K.ult
	K.cd["x"] = 0.0
	P.teleport(home)
	P.dashes = P.max_dashes()
	ac.aim_at(P, home + Vector3(6, 0, 0))
	HunterKeys.ult_pressed(P)
	ac.step(m, 0.05)
	var d0 := P.dashes
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	m.step(hc.DT)
	P.inp["dash"] = false
	var went := P.dashes < d0 - 0.5 and not K.wire.is_empty()
	ac.step(m, 0.3)
	P.inp["dash_down"] = false
	var t := 0.0
	var crouched_again := false
	while U.phase() == MageUlt.CROUCH and t < 2.0:
		m.step(hc.DT)
		t += hc.DT
		crouched_again = crouched_again or (K.run_t <= 0.0 and K.anim_id == "mage_x")
	var from: Vector3 = U.leap.get("from", home)
	ok("Kitefall + Shift (item 51): the Wirerun goes from the crouch, then she launches where it took her",
			went and crouched_again and U.phase() == MageUlt.RISE and hc._flat(from, home) > 2.0
			and hc._flat(P.pos, from) < 0.3 and AimKit.entry(P, "x_ring").get("at", from) == from,
			"went %s crouch %s %s from %.1f m out" % [went, crouched_again, U.phase(), hc._flat(from, home)])
	var xd := K.x_def()
	ac.step(m, float(xd["rise"]) + float(xd["hover"]) + float(xd["drop"]) + 0.1)
	ok("Kitefall + Shift (item 51): she still comes down and strikes", U.phase() == MageUlt.AFTER, U.phase())
	ac.step(m, 0.6)

## Item 51: a jump in Kitefall's crouch goes at once; she launches from up there and the climb starts at her
## height (it never drops her back to the ground first).
func _mage_jump(m: Match, P: Hunter, K: MageKit, home: Vector3) -> void:
	var U := K.ult
	K.cd["x"] = 0.0
	P.teleport(home)
	ac.aim_at(P, home + Vector3(6, 0, 0))
	HunterKeys.ult_pressed(P)
	ac.step(m, 0.05)
	P.inp["jump"] = true
	var y0 := P.pos.y
	var left_at := -1.0
	var dip := 0.0
	var last_y := P.pos.y
	var t := 0.0
	while U.phase() != MageUlt.AIR and t < 1.5:
		m.step(hc.DT)
		t += hc.DT
		P.inp["jump"] = false
		if left_at < 0.0 and P.pos.y > y0 + 0.01 and P.vel.y > 0.5:
			left_at = t
		if U.phase() == MageUlt.RISE:
			dip = maxf(dip, last_y - P.pos.y)
		last_y = P.pos.y
	ok("Kitefall + jump (item 51): the jump goes within 0.1 s of the press, from the crouch",
			left_at >= 0.0 and left_at <= 0.1 + 0.001, "%.2f s" % left_at)
	ok("Kitefall + jump (item 51): she climbs from her jump height, never dropping first, and hangs",
			U.phase() == MageUlt.AIR and dip < 0.05, "dip %.2f m %s" % [dip, U.phase()])
	var xd := K.x_def()
	ac.step(m, float(xd["hover"]) + float(xd["drop"]) + 0.1)
	ac.step(m, 0.6)

func _mage_burst() -> void:
	var res: Dictionary = await BURST.run(ac, "mage", 6.0, func(m: Match, P: Hunter, T: Hunter):
		LevelGrowth.apply(P)          # the ult at the level it is tested at, with its real growth
		ac.aim_at(P, T.pos)
		HunterKeys.ult_pressed(P)
		ac.step(m, 0.7, func(): ac.aim_at(P, T.pos))
		HunterKeys.ult_pressed(P)
		ac.step(m, 0.4))
	_burst_ok("Kitefall", res)

func _burst_ok(ult_name: String, res: Dictionary) -> void:
	var info := "ult %.0f, ult + merge %.0f of %d" % [res["ult"], res["total"], int(Data.CLASSES["light"]["hp"])]
	ok("burst: %s then the merge never one-shots a full-health light hunter" % ult_name,
			bool(res["merged"]) and bool(res["alive"]) and float(res["ult"]) > 1.0, info)

# ------------------------------------------------------------------ Vex: Cinderfall
func gunslinger() -> void:
	var r: Array = ac.setup("gunslinger", 6.0, KIN, true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: GunslingerKit = P.ak
	var U := K.ult
	var xd := K.x_def()
	_gate(m, P, K)
	T.teleport(home + Vector3(6, 0, 0))
	T2.teleport(home + Vector3(6, 0, 2.4))
	ac.step(m, 0.05)
	ac.aim_at(P, T.pos)
	var t_at := T.pos
	ok("Cinderfall: the tap goes off", HunterKeys.ult_pressed(P))
	var id := _cast_id(K)
	var s: Dictionary = U.shells[0] if not U.shells.is_empty() else {}
	ok("Cinderfall: one press is one shell, its own cooldown starts",
			U.casts == 1 and U.shells.size() == 1 and is_equal_approx(float(K.cd["x"]), float(xd["cooldown"])))
	ok("Cinderfall: it lands exactly at the cursor", not s.is_empty() and hc._flat(s["at"], t_at) < 0.1)
	ok("Cinderfall: the rifle goes straight up (gunslinger_x)", K.anim_id == "gunslinger_x")
	ac.step(m, 0.5)
	var disc := AimKit.entry(P, "x1")
	var disc_r := float(disc.get("r", 0))
	var core_r := float(disc.get("core", 0))
	var fill := float(disc.get("fill", 0))
	ok("Cinderfall: the disc with its hot centre, seen by everyone, filling",
			AimKit.shown(P, "x1") and bool(disc.get("all", false)) and absf(disc_r - float(xd["radius"])) < 0.05
			and absf(core_r - float(xd["core_r"])) < 0.05 and fill > 0.2,
			"r %.1f core %.1f fill %.2f" % [disc_r, core_r, fill])
	# he is free the whole time: he walks and the rifle works
	var p0 := P.pos
	ac.step(m, 0.4, func(): P.inp["move"] = Vector2(-1, 0))
	P.inp["move"] = Vector2.ZERO
	ok("Cinderfall: Vex moves and can shoot while it falls",
			hc._flat(P.pos, p0) > 1.0 and not K.busy() and K.can_shoot())
	ok("Cinderfall: nothing lands before 1.6s", ac.dmg(T) == 0.0 and ac.dmg(T2) == 0.0)
	ac.step(m, float(xd["delay"]) - 0.9 + 0.05)
	var base := float(xd["dmg"]) * K.ult.power()
	ok("Cinderfall: the impact, +50% in the centre",
			absf(ac.dmg(T) - base * (1.0 + float(xd["core_k"]))) < 0.5 and absf(ac.dmg(T2) - base) < 0.5
			and U.last.get("centre", 0) == 1,
			"centre %.1f edge %.1f (base %.1f)" % [ac.dmg(T), ac.dmg(T2), base])
	var hit_share := float(KinBond.rules()["hit"])
	ok("Cinderfall: the bond fills once for the impact (a hit)", is_equal_approx(_paid(P, id), hit_share),
			"paid %.2f" % _paid(P, id))
	var took: float = ac.dmg(T)
	ac.step(m, 1.1)
	ok("Cinderfall: the patch burns and slows",
			ac.dmg(T) > took and T.slow_t > 0.0 and U.zone_ticks >= 2 and AimKit.shown(P, "xz1"),
			"+%.1f ticks %d" % [ac.dmg(T) - took, U.zone_ticks])
	ok("Cinderfall: burn ticks pay no more bond", is_equal_approx(_paid(P, id), float(KinBond.rules()["hit"])))
	ac.step(m, float(xd["zone_t"]))
	ok("Cinderfall: the patch is gone after 3s", not U.running() and not AimKit.shown(P, "xz1"))
	ok("Cinderfall: on cooldown, a press now does nothing", not HunterKeys.ult_pressed(P) and U.casts == 1)
	T2.teleport(home + Vector3(-30, 0, 0))
	await _gun_dodge(m, P, K, T, home)
	await ac.done(m)
	await _gun_burst()

## Stepping off the disc before it lands: no damage, no bond; a cursor past the range is clamped.
func _gun_dodge(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	var U := K.ult
	var xd := K.x_def()
	K.cd["x"] = 0.0
	ac.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(6, 0, 0))
	ac.aim_at(P, home + Vector3(40, 0, 0))
	HunterKeys.ult_pressed(P)
	var id := _cast_id(K)
	var s: Dictionary = U.shells[-1]
	ok("Cinderfall: a far cursor is clamped to its range",
			absf(hc._flat(s["at"], home) - float(xd["range"])) < 0.3, "%.1f m" % hc._flat(s["at"], home))
	K.cd["x"] = 0.0
	ac.aim_at(P, T.pos)
	HunterKeys.ult_pressed(P)
	id = _cast_id(K)
	ac.step(m, 0.8)
	T.teleport(home + Vector3(6, 0, 6))
	ac.step(m, 1.0)
	ok("Cinderfall: stepping out of the disc dodges it, and pays no bond", ac.dmg(T) == 0.0 and _paid(P, id) == 0.0,
			"took %.1f paid %.2f at %s impacts %d" % [ac.dmg(T), _paid(P, id), str(T.pos - home), U.impacts])
	ac.step(m, 3.2)

func _gun_burst() -> void:
	var res: Dictionary = await BURST.run(ac, "gunslinger", 6.0, func(m: Match, P: Hunter, T: Hunter):
		LevelGrowth.apply(P)          # the ult at the level it is tested at, with its real growth
		ac.aim_at(P, T.pos)
		HunterKeys.ult_pressed(P)
		ac.step(m, 1.7))
	_burst_ok("Cinderfall", res)
