extends "res://tools/pin_bjorn_owner_check.gd"
## Every input case of Albert's (bulwark) aegis against the source (supervive_kits.md Oath: Brightshield "HOLD
## to raise", "while shielding, Shift = Shield Bash", 6 s; hero sheet bjorn.md RMB), run from
## --bulwark-combo-check (tools/archer_bulwark_combo_check.gd adds the counts): RMB tap, hold and release,
## Shift while holding (and on cooldown), Shift right after the release, LMB while holding, the dash and the
## hold in either order, and that the guard pose only shows while the hold input is down. Prints AKCHECK lines.

const NEAR := Vector3(2.2, 0, 0)        # the dummy, in front of the aegis

func bjorn() -> void:
	var r := setup("bulwark", 2.2)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	var reset := func():
		P.inp["sec_hold"] = false
		P.inp["fire"] = false
		step(m, 0.5)
		P.teleport(home)
		P.vel = Vector3.ZERO
		P.dashes = P.max_dashes()
		P.fire_cd = 0.0
		P.glide_cd = 0.0
		K.lock_t = 0.0
		K.shield_hp = K.shield_max()
		K.ch_rmb = 1.0
		K.cd["rmb"] = 0.0
		K.lmb_t = -1.0
		K.hold_blocked = false
		K.res = 0.0
		fresh(T)
		T.teleport(home + NEAR)
		aim_at(P, T.pos)
		step(m, 0.3)
	# RMB tap: under the 0.1 s cast nothing rises, no pose, nothing spent, no Charge
	reset.call()
	var spins := K.spins
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.05, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	step(m, 0.3)
	ok("aegis input: an RMB tap raises nothing, shows no guard pose, spends nothing",
		K.wall.is_empty() and not K.fx.aegis.visible and K.anim_id != "bul_guard" and K.ch_rmb >= 1.0
		and K.spins == spins and K.st.get("last_dash") != "charge",
		"wall %s anim %s" % [str(K.wall.is_empty()), K.anim_id])
	# hold: up at 0.1 s with the guard pose; release: down at once, pose and aegis gone, hit points kept
	reset.call()
	var hp0 := K.shield_hp
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.06, func(): P.inp["sec_hold"] = true)
	var early := K.wall.is_empty()
	step(m, 0.2, func(): P.inp["sec_hold"] = true)
	ok("aegis input: the hold raises the aegis after 0.1 s, with the guard pose",
		early and not K.wall.is_empty() and K.fx.aegis.visible and K.anim_id == "bul_guard",
		"early %s anim %s" % [str(early), K.anim_id])
	P.inp["sec_hold"] = false
	step(m, 0.1)
	ok("aegis input: letting go lowers it, no guard pose, no Bash, hit points kept",
		K.wall.is_empty() and not K.fx.aegis.visible and K.anim_id != "bul_guard" and absf(K.shield_hp - hp0) < 1.0
		and dmg(T) <= 0.0 and K.ch_rmb >= 1.0, "anim %s hp %.0f/%.0f" % [K.anim_id, K.shield_hp, hp0])
	# Shift while holding: the Shield Charge (RMB slot cooldown, no dash charge), the aegis stays raised
	reset.call()
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	var dashes := P.dashes
	P.do_dash()
	var charged: bool = K.st.get("last_dash") == "charge"
	step(m, 0.05, func(): P.inp["sec_hold"] = true)
	var still_up := not K.wall.is_empty()
	step(m, 0.5, func(): P.inp["sec_hold"] = true)
	ok("aegis input: Shift while holding is the Shield Charge on the RMB slot, no dash charge, aegis kept",
		charged and still_up and dashes - P.dashes < 0.2 and absf(float(K.cd["rmb"]) - 6.0) < 0.6 and K.ch_rmb < 1.0,
		"dash %s up %s dashes %.2f cd %.1f" % [
			str(K.st.get("last_dash")), str(still_up), dashes - P.dashes, float(K.cd["rmb"])])
	P.inp["sec_hold"] = false
	step(m, 0.2)
	# Shift right after the release: the plain 360 Smash on a dash charge, the Charge cooldown untouched
	reset.call()
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	step(m, 0.02)
	dashes = P.dashes
	var sp := K.spins
	P.do_dash()
	step(m, 0.5)
	ok("aegis input: Shift right after the release is the 360 Smash (a dash charge, not the Charge)",
		K.st.get("last_dash") == "whirl" and K.spins == sp + 1 and dashes - P.dashes > 0.5
		and K.ch_rmb >= 1.0 and K.wall.is_empty(),
		"dash %s spins %d dashes %.2f ch %.1f" % [
			str(K.st.get("last_dash")), K.spins - sp, dashes - P.dashes, K.ch_rmb])
	# the Charge cooling down: Shift behind the aegis does nothing (no dash charge, no spin), the aegis stays
	reset.call()
	K.ch_rmb = 0.0
	K.cd["rmb"] = 4.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	dashes = P.dashes
	sp = K.spins
	var px := P.pos
	P.do_dash()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	ok("aegis input: Shift behind the aegis with the Charge cooling does nothing and the aegis stays",
		K.spins == sp and absf(dashes - P.dashes) < 0.01 and P.pos.distance_to(px) < 0.3 and not K.wall.is_empty(),
		"spins %d dashes %.2f moved %.2f" % [K.spins - sp, dashes - P.dashes, P.pos.distance_to(px)])
	P.inp["sec_hold"] = false
	step(m, 0.2)
	# LMB while holding: no throw, no swing charge, no pose, no Bash; the aegis stays up
	reset.call()
	var thr := K.throws
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.inp["fire"] = true
	step(m, 0.5, func(): P.inp["sec_hold"] = true)
	ok("aegis input: LMB while holding does not throw, charge or lower the aegis",
		K.throws == thr and K.mace.is_empty() and K.lmb_t < 0.0 and K.anim_id == "bul_guard" and not K.wall.is_empty(),
		"throws %d lmb_t %.2f anim %s" % [K.throws - thr, K.lmb_t, K.anim_id])
	P.inp["sec_hold"] = false
	step(m, 0.3, func(): P.inp["fire"] = true)
	ok("aegis input: a press made behind the aegis does not start a charge or show its pose when the aegis drops",
		K.lmb_t < 0.0 and K.anim_id != "bul_smash_wind" and K.mace.is_empty(),
		"lmb_t %.2f anim %s" % [K.lmb_t, K.anim_id])
	P.inp["fire"] = false
	step(m, 0.3)
	ok("aegis input: that press, let go, throws nothing", K.throws == thr and K.mace.is_empty())
	# dash while holding, priority: in the air Shift is the Shield Charge too (Shield Surf, main), the aegis stays
	reset.call()
	P.teleport(home + Vector3(0, 8.0, 0))
	step(m, 0.05)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.25, func(): P.inp["sec_hold"] = true)
	var air := not P.grounded
	P.do_dash()
	step(m, 0.1, func(): P.inp["sec_hold"] = true)
	ok("aegis input: Shift held in the air is the Shield Charge (Shield Surf), the aegis stays",
		air and K.st.get("last_dash") == "charge" and not K.wall.is_empty(),
		"air %s dash %s up %s" % [str(air), str(K.st.get("last_dash")), str(not K.wall.is_empty())])
	P.inp["sec_hold"] = false
	step(m, 1.5)
	# Shift first, RMB in the dash: the aegis rises mid-dash (the hold row), the pose shows only while it is held
	reset.call()
	P.do_dash()
	step(m, 0.04)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	var up := not K.wall.is_empty()
	P.inp["sec_hold"] = false
	step(m, 0.1)
	ok("aegis input: RMB pressed in a 360 Smash raises the aegis; letting go drops it and the pose",
		up and K.wall.is_empty() and K.anim_id != "bul_guard" and K.ch_rmb >= 1.0,
		"up %s anim %s" % [str(up), K.anim_id])
	# RMB let go during the Charge: the aegis comes down, the Charge goes on, and no guard pose is left over
	reset.call()
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.do_dash()
	P.inp["sec_hold"] = false
	step(m, 0.8)
	ok("aegis input: RMB let go in the Shield Charge leaves no aegis and no guard pose",
		K.wall.is_empty() and not K.fx.aegis.visible and K.anim_id != "bul_guard", "anim %s" % K.anim_id)
	# held through the Charge: the guard pose is back once the Charge ends
	reset.call()
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.do_dash()
	step(m, 0.9, func(): P.inp["sec_hold"] = true)
	ok("aegis input: held through the Shield Charge, the aegis and the guard pose are there after it",
		not K.wall.is_empty() and K.anim_id == "bul_guard", "anim %s" % K.anim_id)
	P.inp["sec_hold"] = false
	step(m, 0.2)
	# a stun while holding drops the hold: no aegis, no pose, and RMB still down raises nothing until pressed again
	reset.call()
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.stun_t = 0.5
	step(m, 0.7, func(): P.inp["sec_hold"] = true)
	ok("aegis input: a stun mid-hold drops the aegis and the pose, and a held RMB does not raise it again",
		K.wall.is_empty() and K.anim_id != "bul_guard" and not K.rmb_down,
		"anim %s down %s" % [K.anim_id, str(K.rmb_down)])
	P.inp["sec_hold"] = false
	m.queue_free()
