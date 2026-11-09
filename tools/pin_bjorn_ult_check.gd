extends "res://tools/archer_bulwark_combo_check.gd"
## The X ultimates of Hem (Starpiercer) and Breaker (Faultline), run from --archer-combo-check and
## --bulwark-combo-check (tools/archer_bulwark_combo_check.gd adds its counts): the level gate, the cast,
## the telegraph, the payoff, the cooldown, bond sent only on a land, the small mechanics, a merge
## dropping the holds, and the burst cap (the whole ult, then a merge, never takes a full-health light
## hunter down). Prints AKCHECK lines like --archetype-check.

const BURST_KIN := "cindle"
const MERGE_OPEN := 1.0        # s of the merge counted after the ult: its landing and its first attacks

## Holds LMB on `at` for `secs`.
func hold_fire(m: Match, P: Hunter, at: Vector3, secs: float) -> void:
	step(m, secs, func():
		P.inp["fire"] = true
		aim_at(P, at))

## What the bond meter owes the current ult cast (KinBond.from_ult keeps the best event per cast id).
func best(P: Hunter) -> float:
	var c: Dictionary = P.get_meta("bond_cast", {})
	return float(c.get("got", 0.0)) if String(c.get("id", "")) == HeroUlt.cast_id(P.ak) else 0.0

## Presses X the way the match does (main's HunterKeys.ult_pressed: the level gate, then the kit's cast_ult).
func press_x(m: Match, P: Hunter) -> void:
	HunterKeys.ult_pressed(P)
	m.step(DT)

## Holds LMB until one more beam has gone (or `cap` s pass).
func beam(m: Match, P: Hunter, K: ArcherKit, at: Vector3, cap := 1.8) -> void:   # recover 1.0 + nock 0.5
	var f0 := K.ult.fired
	var t := 0.0
	while K.ult.fired == f0 and t < cap:
		P.inp["fire"] = true
		aim_at(P, at)
		m.step(DT)
		t += DT
	P.inp["fire"] = false

## A full-health light hunter at the caster's level: the burst cap's target.
func light_target(T: Hunter, P: Hunter) -> void:
	T.max_hp = 124.0 * (1.0 + LevelGrowth.hp_pct(int(P.lvl)))
	fresh(T)
	T.armor = 0.0

func pin() -> void:
	var r := setup("archer", 7.0, BURST_KIN, true)      # a Boki at hand: KinBond fills the meter only with one ready
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: ArcherKit = P.ak
	var xd: Dictionary = K.d["x"]
	var ap := LevelGrowth.ap(P)
	P.equip("longbow", 0)
	step(m, 0.3)
	# the level gate
	P.lvl = 5
	press_x(m, P)
	ok("pin ult gate: no Starpiercer below level 6", not K.ult.active() and float(K.cd["x"]) <= 0.0)
	P.lvl = 6
	# the cast: no bond on the cast alone, the telegraph, its own move
	P.ult = 0.0
	aim_at(P, T.pos)
	var casts0 := int(P.used.get("x", 0))
	press_x(m, P)
	ok("pin ult cast: three shots empowered for 6s", K.ult.active() and K.ult.left == 3, "left %d" % K.ult.left)
	ok("pin ult: one X press is one cast (main's X path only)", int(P.used.get("x", 0)) == casts0 + 1,
		"casts +%d" % (int(P.used.get("x", 0)) - casts0))
	ok("pin ult cooldown: 36s from the cast",
		absf(float(K.cd["x"]) - float(xd["cooldown"])) < 0.1,
		"%.1f" % float(K.cd["x"]))
	ok("pin ult anim: the cast plays pin_ult_cast", K.anim_id == "pin_ult_cast", K.anim_id)
	var cue: Dictionary = (HeroVfx.data("archer")["moves"]["ult_cast"]["sfx"] as Array)[0]
	ok("pin ult sound: the cast cue plays for everyone on the map (no distance cut, loud for rivals too)",
		HeroVfx.of(m).plays.get("ult_cast", 0) == 1 and cue["at"] == "all" and float(cue["other"]) >= float(cue["db"]))
	ok("pin ult bond: nothing for the cast alone", best(P) <= 0.0 and P.ult < 0.01, "%.3f" % P.ult)
	step(m, 0.1)
	var lane := AimKit.entry(P, "x")
	ok("pin ult telegraph: the beam's lane out to 18m and no ground ring (the beam is the hit area)",
		AimKit.shown(P, "x") and not AimKit.shown(P, "x_ring")
		and absf(float(lane.get("len", 0.0)) - 18.0) < 0.1
		and absf(float(lane.get("width", 0.0)) - float(xd.get("width", 0.5))) < 0.01,
		"lane %s w %s" % [str(lane.get("len")), str(lane.get("width"))])
	# a press nocks (0.5 s, its own held move, the cursor ring filling), then the beam pierces both
	T.teleport(home + Vector3(7, 0, 0))
	T2.teleport(home + Vector3(16, 0, 0))
	fresh(T)
	fresh(T2)
	T.armor = 30.0
	hold_fire(m, P, T.pos, 0.1)
	ok("pin ult anim: a press nocks (pin_ult_nock), the cursor ring fills",
		K.anim_id == "pin_ult_nock" and K.ult.nock_t > 0.0 and float(AimKit.reticle(P).get("charge", 0.0)) > 0.0,
		"%s nock %.2f" % [K.anim_id, K.ult.nock_t])
	var t_press := m.time - 0.1
	beam(m, P, K, T.pos)
	var t_beam := m.time - t_press
	var t_fire1 := m.time
	m.step(DT)          # (the kit skins its new shot on its next step)
	var flying := m.shots.filter(func(sh): return sh["by"] == P and String(sh["x"].get("ab", "")) == "ultimate")
	ok("pin ult look: the shot is a travelling arrow (a skinned projectile at the data speed, not an instant lane)",
		flying.size() == 1 and K.fx.live.size() == 1 and float(xd["speed"]) >= 80.0
		and absf((flying[0]["vel"] as Vector2).length() - float(xd["speed"])) < 0.5,
		"%d shots, %d arrows" % [flying.size(), K.fx.live.size()])
	ok("pin ult look: nothing is hit the instant it is loosed", dmg(T) == 0.0 and dmg(T2) == 0.0)
	step(m, 0.1)
	ok("pin ult look: hits land after flight time (7m foe by 0.1s, the 16m foe still ahead of it)",
		dmg(T) > 0.0 and dmg(T2) == 0.0, "took %.0f / %.0f" % [dmg(T), dmg(T2)])
	step(m, 0.1)
	var want := float(xd["dmg"]) * ap
	ok("pin ult payoff: the beam pierces both foes, 16m out too (1.5x her Empowered range)",
		dmg(T) > want * 0.6 and dmg(T2) > want * 0.9, "took %.0f / %.0f (want %.0f)" % [dmg(T), dmg(T2), want])
	ok("pin ult small: the beam needs no draw (out 0.5 s after the press, footage: a 0.4-0.8 s draw)",
		K.ult.fired == 1 and P.draw_t < 0.0 and absf(t_beam - 0.5) < 0.05, "out at %.2f" % t_beam)
	# footage f48/f63/f78 at 10 fps: 1.5 s a shot. Holding fire: no nock through the recover, the next beam 1.5 s on
	hold_fire(m, P, T.pos, 0.7)
	ok("pin ult anim: no nock during the 1.0 s recover after a beam (held fire waits)",
		K.ult.nock_t < 0.0 and K.ult.fired == 1 and K.anim_id != "pin_ult_nock",
		"%s nock %.2f" % [K.anim_id, K.ult.nock_t])
	P.inp["fire"] = false
	ok("pin ult small: armor shredded by 10 on top of the hit",
		T.armor <= 30.0 - float(xd["shred"]) + 0.01,
		"armor %.1f" % T.armor)
	ok("pin ult bond: a beam that hits a hunter sends from_ult hit (0.6 into the meter)",
		absf(best(P) - 0.6) < 0.001 and P.ult >= 0.6, "best %.2f meter %.3f" % [best(P), P.ult])
	ok("pin ult anim: the beam plays pin_ult_loose", K.anim_id == "pin_ult_loose", K.anim_id)
	ok("pin ult small: the beam knocks back", T.vel.x > 0.5 or T.pos.x > home.x + 7.05, "vel %.2f" % T.vel.x)
	# a miss pays nothing
	var b0 := best(P)
	beam(m, P, K, home + Vector3(0, 0, 12))
	var cadence := m.time - t_fire1
	ok("pin ult cadence: 1.5 s from beam to beam with fire held (footage f48/f63/f78: 1.5 s)",
		K.ult.fired == 2 and absf(cadence - 1.5) < 0.06, "%.2f s" % cadence)
	step(m, 0.2)
	ok("pin ult bond: a beam that misses pays nothing", best(P) == b0 and K.ult.fired == 2,
		"owed %.2f -> %.2f" % [b0, best(P)])
	ok("pin ult small: she can move between shots", K.move_k() > 0.9, "move_k %.2f" % K.move_k())
	# the last beam executes a hunter it leaves under 12%
	T.max_hp = 150.0
	fresh(T)
	T.hp = 40.0
	T.armor = 0.0
	beam(m, P, K, T.pos)
	ok("pin ult anim: the last beam plays pin_ult_final", K.anim_id == "pin_ult_final", K.anim_id)
	step(m, 0.2)
	ok("pin ult payoff: the last beam finishes a hunter left under 12%",
		K.ult.executes == 1 and (T.downed or T.dead or T.hp <= 0.0),
		"executes %d hp %.0f downed %s" % [K.ult.executes, T.hp, T.downed])
	ok("pin ult bond: the execute's knock is the cast's best event (0.7, not added per hit)",
		absf(best(P) - 0.7) < 0.001, "best %.2f" % best(P))
	ok("pin ult ends after the third shot, the telegraph goes",
		not K.ult.active() and not AimKit.shown(P, "x"), "left %d" % K.ult.left)
	await done(m)
	await _pin_window()
	await _pin_burst()

## The window, the cooldown, the bow coming back, Spirit Walk between shots, a wall, a merge.
func _pin_window() -> void:
	var r := setup("archer", 7.0, BURST_KIN, false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: ArcherKit = P.ak
	P.equip("longbow", 0)
	step(m, 0.3)
	press_x(m, P)
	step(m, 6.1)
	ok("pin ult small: unused shots go when the 6s window ends", not K.ult.active() and K.ult.fired == 0)
	press_x(m, P)
	ok("pin ult cooldown: no recast while it recharges", not K.ult.active())
	hold_fire(m, P, T.pos, 1.0)
	ok("pin ult: after the window the bow draws as normal", P.draw_t > 0.5, "draw_t %.2f" % P.draw_t)
	P.inp["fire"] = false
	step(m, 0.3)
	# Spirit Walk between shots keeps the empowered shots
	K.cd["x"] = 0.0
	press_x(m, P)
	P.dashes = P.max_dashes()
	P.inp["dash"] = true
	step(m, 0.3)
	ok("pin ult small: Spirit Walk between shots keeps them", K.ult.active() and K.ult.left == 3 and K.spirit.active())
	# a wall stops the beam
	fresh(T)
	_wall_at(m, home + Vector3(4, 0, 0), lv, 0)
	beam(m, P, K, T.pos)
	step(m, 0.2)
	ok("pin ult small: a wall stops the beam (the foe behind it untouched)",
		K.ult.fired == 1 and dmg(T) <= 0.01,
		"took %.0f" % dmg(T))
	_clear_wall(m, home + Vector3(4, 0, 0), lv, 0)
	# a merge mid nock: no beam, the window ends (the 1.0 s recover first)
	step(m, 0.9)
	hold_fire(m, P, T.pos, 0.1)
	ok("pin ult: nocking before the merge", K.ult.nock_t > 0.0)
	merge_now(P)
	P.inp["fire"] = false
	step(m, 0.5)
	ok("pin ult merge: the nock and the empowered window drop with no beam",
		not K.ult.active() and K.ult.fired == 1 and K.ult.nock_t < 0.0,
		"fired %d" % K.ult.fired)
	await done(m)

## Burst cap: all three beams on a full-health light hunter, then straight into a merge (its landing and
## first attacks, MERGE_OPEN s).
func _pin_burst() -> void:
	var r := setup("archer", 6.0, BURST_KIN, false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: ArcherKit = P.ak
	P.equip("longbow", 0)
	step(m, 0.3)
	light_target(T, P)
	press_x(m, P)
	for i in 3:
		beam(m, P, K, T.pos)
		step(m, 0.6)
	var after_ult := dmg(T)
	merge_now(P)
	hold_fire(m, P, T.pos, MERGE_OPEN)
	P.inp["fire"] = false
	ok("pin ult burst: three beams then a merge leave a full-health light hunter standing",
		not T.downed and not T.dead and T.hp > 0.0 and K.ult.fired == 3,
		"ult %.0f, with the merge %.0f of %.0f" % [after_ult, dmg(T), T.max_hp])
	await done(m)

func bjorn() -> void:
	var r := setup("bulwark", 7.0, BURST_KIN, true)      # a Boki at hand: KinBond fills the meter only with one ready
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	var xd: Dictionary = K.d["x"]
	var ap := LevelGrowth.ap(P)
	step(m, 0.3)
	P.lvl = 5
	press_x(m, P)
	ok("bjorn ult gate: no Faultline below level 6", K.ult.phase == "" and float(K.cd["x"]) <= 0.0)
	P.lvl = 6
	P.ult = 0.0
	T.teleport(home + Vector3(7, 0, 0))
	T2.teleport(home + Vector3(10, 0, 1.0))
	aim_at(P, T.pos)
	var casts0 := int(P.used.get("x", 0))
	press_x(m, P)
	ok("bjorn ult: one X press is one cast (main's X path only)", int(P.used.get("x", 0)) == casts0 + 1,
		"casts +%d" % (int(P.used.get("x", 0)) - casts0))
	step(m, 0.1)
	ok("bjorn ult cast: planted, hammer up (bul_ult_wind)",
		K.ult.phase == "wind" and K.anim_id == "bul_ult_wind" and K.move_k() == 0.0,
		"%s %s move %.2f" % [K.ult.phase, K.anim_id, K.move_k()])
	var c0 := AimKit.entry(P, "x0")
	ok("bjorn ult telegraph: four 4x4m cells down the lane, shown to everyone",
		AimKit.shown(P, "x0") and AimKit.shown(P, "x3") and bool(c0.get("all", false))
			and absf(float(c0.get("len", 0.0)) - 4.0) < 0.01,
		str(c0.keys()))
	ok("bjorn ult cooldown: 40 s from the cast (0.8 x the data's 50 s)",
		absf(float(K.cd["x"]) - float(xd["cooldown"])) < 0.2,
		"%.1f" % float(K.cd["x"]))
	ok("bjorn ult bond: nothing for the cast alone", best(P) <= 0.0 and P.ult < 0.05, "%.3f" % P.ult)
	P.inp["fire"] = true
	step(m, 0.05)
	P.inp["fire"] = false
	ok("bjorn ult small: planted, no throw or swing in the wind-up", K.mace.is_empty() and K.lmb_t < 0.0)
	step(m, 0.3)
	ok("bjorn ult anim: the slam (bul_ult_slam) at 0.4s", K.ult.slams == 1 and K.anim_id == "bul_ult_slam", K.anim_id)
	step(m, 0.35)
	var hit_t := T.stun_t > 0.0 and T.slow_t > 0.0
	ok("bjorn ult: the racing fissure struck every foe on the lane before its cell erupts (data: stuns struck targets)",
		K.ult.hit.size() >= 2, "struck %d" % K.ult.hit.size())
	step(m, 0.3)
	var want := (float(xd["dmg"]) + float(xd["strike_dmg"])) * ap
	ok("bjorn ult payoff: each foe on the lane struck (stun) and thrown once (4 + 18, a heavy slow)",
		hit_t and absf(dmg(T) - want) < want * 0.35 and dmg(T2) > want * 0.6,
		"took %.0f / %.0f (want %.0f) stunned %s" % [dmg(T), dmg(T2), want, hit_t])
	ok("bjorn ult bond: two hunters thrown, the cast pays its best event once (hit, 0.6)",
		absf(best(P) - 0.6) < 0.001 and HeroUlt.cast_id(K).begins_with("bulwark_") and P.ult >= 0.6,
		"best %.2f cast %s meter %.3f" % [best(P), HeroUlt.cast_id(K), P.ult])
	step(m, 0.4)
	ok("bjorn ult small: a scar stays on the lane and slows a foe on it",
		not K.ult.scar.is_empty() and K.ult.phase == "", "scar %s" % str(K.ult.scar.keys()))
	fresh(T)
	T.teleport(home + Vector3(5, 0, 0))
	step(m, 0.2)
	ok("bjorn ult small: the scar slows 20%",
		T.slow_t > 0.0 and absf(T.slow_k - float(xd["scar_slow"])) < 0.01,
		"slow %.2f" % T.slow_k)
	step(m, 10.0)
	ok("bjorn ult small: the scar fades after 10s", K.ult.scar.is_empty())
	await done(m)
	await _bjorn_more()
	await _bjorn_burst()

## A miss, the wall stop, an interrupt, a merge in the wind-up.
func _bjorn_more() -> void:
	var r := setup("bulwark", 7.0, BURST_KIN, false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: BulwarkKit = P.ak
	step(m, 0.3)
	P.ult = 0.0
	aim_at(P, home + Vector3(0, 0, -6))
	press_x(m, P)
	step(m, 1.4)
	ok("bjorn ult bond: a Faultline that hits nobody pays nothing",
		K.ult.slams == 1 and best(P) == 0.0 and HeroUlt.cast_id(K) != "",
		"owed %.2f" % best(P))
	press_x(m, P)
	ok("bjorn ult cooldown: no recast while it recharges", K.ult.phase == "")
	# a raised ledge 6 m out stops the fissure: the foe beyond is safe
	K.cd["x"] = 0.0
	T.teleport(home + Vector3(11, 0, 0))
	_wall_at(m, home + Vector3(5, 0, 0), lv, 0)
	aim_at(P, T.pos)
	press_x(m, P)
	ok("bjorn ult small: a wall stops the fissure (cells %d)" % K.ult.cells.size(), K.ult.cells.size() == 1)
	step(m, 1.4)
	ok("bjorn ult small: the foe past the wall is untouched", dmg(T) <= 0.01, "took %.0f" % dmg(T))
	_clear_wall(m, home + Vector3(5, 0, 0), lv, 0)
	# a stun in the wind-up interrupts it: no slam, most of the cooldown back
	K.cd["x"] = 0.0
	press_x(m, P)
	P.stun_t = 0.3
	step(m, 0.6)
	ok("bjorn ult small: a stun in the wind-up interrupts it (cooldown back to 8s)",
		K.ult.interrupts == 1 and K.ult.slams == 2
			and float(K.cd["x"]) <= 8.0, "slams %d cd %.1f" % [K.ult.slams, float(K.cd["x"])])
	step(m, 0.5)
	# a merge in the wind-up: no slam
	K.cd["x"] = 0.0
	press_x(m, P)
	step(m, 0.1)
	merge_now(P)
	step(m, 0.6)
	ok("bjorn ult merge: the wind-up drops with no slam",
		K.ult.phase == "" and K.ult.slams == 2,
		"slams %d" % K.ult.slams)
	await done(m)

## Burst cap: a Faultline then straight into a merge and its attacks on a full-health light hunter.
func _bjorn_burst() -> void:
	var r := setup("bulwark", 3.0, BURST_KIN, false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: BulwarkKit = P.ak
	step(m, 0.3)
	light_target(T, P)
	aim_at(P, T.pos)
	press_x(m, P)
	step(m, 1.2)
	var after_ult := dmg(T)
	merge_now(P)
	hold_fire(m, P, T.pos, MERGE_OPEN)
	P.inp["fire"] = false
	ok("bjorn ult burst: a Faultline then a merge leave a full-health light hunter standing",
		not T.downed and not T.dead and T.hp > 0.0 and K.ult.slams == 1 and after_ult > 0.0,
		"ult %.0f, with the merge %.0f of %.0f" % [after_ult, dmg(T), T.max_hp])
	await done(m)
