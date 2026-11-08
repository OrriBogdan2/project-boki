extends "res://tools/hero_pair_check.gd"
## --ostra-combo-check: Motley, docs/heroes/ostra.md. His reticle (the aim line, the Snap's rails, the
## Trade's two ends), charge and wind-up timings, where each thing lands, the payoffs, the owner's notes
## (Shift never travels on its own, keeps his height, one Snap charge that visibly stuns the training
## dummy), the small mechanics, the merge-start drops, and that every move, sound and look exists.

func run(main_node: Node) -> void:
	main = main_node
	await _ostra()
	await _bolt_through_terrain()
	var orb_check = load("res://tools/ostra_orb_check.gd").new()
	await orb_check.orbs(main)
	n += orb_check.n
	fails += orb_check.fails
	var arena_check = load("res://tools/ostra_arena_check.gd").new()
	await arena_check.arena(main)
	n += arena_check.n
	fails += arena_check.fails
	var ult_check = load("res://tools/ostra_ult_check.gd").new()
	await ult_check.ult(main)
	n += ult_check.n
	fails += ult_check.fails
	print("PAIRCHECK ostra DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _ostra() -> void:
	var r := setup("ostra", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: OstraKit = P.ak
	var dd: Dictionary = K.dash_def()
	var sn: Dictionary = K.rmb_def()["snap"]
	var reset := func():
		if not K.seed.is_empty(): K._pop(false)
		K._drop_holds()
		K.swollen_t = 0.0
		K.res = 0.0
		P.teleport(home)
		P.vel = Vector3.ZERO
		P.grounded = true
		fresh(T)
		T.teleport(home + Vector3(6.0, 0, 0))
		aim_at(P, T.pos)
		K.cd["e"] = 0.0
		K.e_t = 0.0
		K.ch_rmb = 1.0
		K.cd["rmb"] = 0.0
		P.fire_cd = 0.0
		P.dashes = P.max_dashes()
		P.inp["fire"] = false
		P.inp["sec_hold"] = false
		P.inp["dash_down"] = false
		step(m, 0.2)
		fresh(T)      # (a shard still flying from the last case may have landed meanwhile)
	var card: Dictionary = K.d["card"]
	ok(
		"card: a role line and one line each for LMB, RMB, E, Shift and the passive",
		["role", "lmb", "rmb", "e", "dash", "passive"].all(func(k): return String(card.get(k, "")).length() > 10)
	)
	# ---- the reticle: a thin line to the cursor all the time
	reset.call()
	ok(
		"reticle: the thin aim line to the cursor shows the whole time",
		AimKit.shown(P, "aim") and bool(AimKit.entry(P, "aim").get("arrow", false))
	)
	# ---- Swell
	K.on_deal(T, 10.0, {})
	var on_h := K.res
	K.res = 0.0
	var mob := Mob.new()
	K.on_deal(mob, 10.0, {})
	var on_m := K.res
	mob.free()
	ok(
		"passive: Swell fills ten times faster on hunters", on_h > 9.0 * on_m and on_h > 3.0,
		"hunter %.2f mob %.2f" % [on_h, on_m]
	)
	K.res = 0.0
	for i in 40: K.on_deal(T, 10.0, {})
	m.step(DT)
	ok(
		"passive: full Swell = Swollen for 9s, wrapped in the pink sphere",
		K.is_swollen() and K.swells == 1 and absf(
			float(K.res_def()["swollen_t"]) - 9.0
		) < 0.01 and KitLooks.of(m).holding("os_aura"),
		"swollen %.1f" % K.swollen_t
	)
	ok("anim: Swollen plays ostra_empower", K.anim_id == "ostra_empower")
	# ---- LMB: plain orbs fly to full range past the cursor (the charge: ostra_orb_check.gd)
	reset.call()
	aim_at(P, home + Vector3(3.0, 0, 0))
	T.teleport(home + Vector3(12.0, 0, 0))
	P.fire_cd = 0.0
	K.last_shot_t = m.time
	P.inp["fire"] = true
	step(m, 0.05, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	var orb: Array = m.shots.filter(func(s): return s["by"] == P)
	var olen := float(orb[0]["life0"]) * (orb[0]["vel"] as Vector2).length() if not orb.is_empty() else 0.0
	ok("lmb: a plain orb flies past the cursor to full range (14m)", olen > 12.0, "%.1f m" % olen)
	ok("lmb: the orb is his own violet teardrop (skin)", KitLooks.of(m).skins_live("orb") >= 1)
	step(m, 1.0)
	ok("lmb: ...and hits a foe well past the cursor", dmg(T) > 5.0, "took %.1f" % dmg(T))
	reset.call()
	step(m, 1.6)
	ok(
		"lmb: a pause charges the next orb (a glow held at his hand)",
		K.charge >= 1.0 and KitLooks.of(m).holding("os_charge"), "charge %.2f" % K.charge
	)
	var spd_hot := float(P.wpn["speed"])
	P.inp["fire"] = true
	step(m, 0.05, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	ok("lmb: a full orb is faster (1.4x)", spd_hot > 40.0, "speed %.0f" % spd_hot)
	ok("anim: a full orb plays ostra_orb_hot", K.anim_id == "ostra_orb_hot")
	step(m, 1.0)
	ok(
		"lmb: a full orb hits harder and slows", K.settled_shots == 1 and dmg(T) >= 11.0 and T.slow_t > 0.0,
		"took %.1f slow %.1f" % [dmg(T), T.slow_t]
	)
	ok(
		"item 60: the charge restarts from zero after a shot (plain again)",
		K.last_orb_c >= 0.999 and K.charge < 0.9, "charge %.2f" % K.charge
	)
	_orb_parity(m, P, home, K)
	# ---- RMB: one charge, a visible wind-up with the two rails, one bundle, a stun that reads
	reset.call()
	ok("rmb: Shard Snap has one charge", K.rmb_charges() == 1)
	P.inp["sec_hold"] = true
	m.step(DT)
	ok(
		"rmb aim: holding RMB turns the line into two rails the bundle's width",
		AimKit.shown(P, "snap") and bool(AimKit.entry(P, "snap").get("rails", false)) and absf(
			float(AimKit.entry(P, "snap").get("width", 0.0)) - float(sn["width"])
		) < 0.01 and not AimKit.shown(P, "aim")
	)
	P.ak.press_rmb()
	m.step(DT)
	ok(
		"rmb: a wind-up first (dark orb at the hand, nothing fired yet)",
		K.snaps == 0 and not K.snap.is_empty() and KitLooks.of(m).holding("os_snaporb"), "snaps %d" % K.snaps
	)
	ok("small: he slows 25% while casting the Snap", absf(K.move_k() - 0.75) < 0.01, "%.2f" % K.move_k())
	ok("anim: the wind-up plays ostra_snap_wind", K.anim_id == "ostra_snap_wind")
	P.inp["sec_hold"] = false
	var wind := float(sn["wind"])
	var t_press := m.time - DT
	var rel := [0.0]
	var hit_t := [0.0]
	var seen := [0, 0]
	T.teleport(home + Vector3(6.0, 0, 0))
	aim_at(P, T.pos)
	step(m, wind - 0.1)
	ok("item 40: nothing is fired or hurt before the release", K.snaps == 0 and dmg(T) == 0.0, "snaps %d" % K.snaps)
	step(m, 0.2, func():
		if K.snaps == 1 and rel[0] == 0.0:
			rel[0] = m.time
			seen[0] = m.shots.filter(
				func(s): return s["by"] == P and String((s["x"] as Dictionary).get("ab", "")) == "rmb"
			).size()
			seen[1] = KitLooks.of(m).skins_live("spear")
		if dmg(T) > 0.0 and hit_t[0] == 0.0:
			hit_t[0] = m.time)
	ok(
		"item 40: the release is at the data's wind-up (0.32s), +40% over the old 0.2s",
		absf(rel[0] - t_press - wind) < 0.05 and wind >= 0.2 * 1.4 - 0.01, "wind %.2f" % (rel[0] - t_press)
	)
	step(m, 0.3, func(): if dmg(T) > 0.0 and hit_t[0] == 0.0: hit_t[0] = m.time)
	var travel := 6.0 / float(sn["speed"])
	ok(
		"item 40: damage lands on the impact (release + travel), not at the press or release",
		hit_t[0] > rel[0] + travel * 0.6 and absf(hit_t[0] - t_press - wind - travel) < 0.1 and dmg(T) > 0.0,
		"hit at %.2f (release %.2f travel %.2f)" % [hit_t[0] - t_press, rel[0] - t_press, travel]
	)
	var total := wind + 13.0 / float(sn["speed"])
	ok("item 40: total cast time is about 40% over the old 0.54s", absf(total / 0.54 - 1.4) < 0.1, "%.2f" % total)
	ok("item 40: a short recovery keeps him slowed after the release", float(sn["recover"]) > 0.0)
	ok(
		"rmb: then one tight bundle (a single projectile, crystal-spear skin)",
		K.snaps == 1 and seen[0] == 1 and seen[1] == 1, "bundles %d" % seen[0]
	)
	ok("rmb: the ability is spent (no second cast)", K.ch_rmb < 1.0 and not K.rmb_ready())
	# the stun: near vs far, and visible on the training dummy
	reset.call()
	T.teleport(home + Vector3(2.5, 0, 0))
	aim_at(P, T.pos)
	var s_near := [0.0]
	tap(m, P)
	step(m, 0.5, func(): s_near[0] = maxf(s_near[0], T.stun_t))
	var d_near := dmg(T)
	ok("rmb: the stun shows on the dummy (stars over its head)", s_near[0] > 0.0 and KitLooks.of(m).crowned(T))
	reset.call()
	T.teleport(home + Vector3(11.5, 0, 0))
	aim_at(P, T.pos)
	var s_far := [0.0]
	tap(m, P)
	step(m, 0.8, func(): s_far[0] = maxf(s_far[0], T.stun_t))
	ok(
		"rmb: it stuns 0.8s up close, up to 1.8s the further it flew",
		s_near[0] >= 0.75 and s_near[0] < 1.1 and s_far[0] > 1.5, "near %.2f far %.2f" % [s_near[0], s_far[0]]
	)
	reset.call()
	K.swollen_t = 5.0
	T.teleport(home + Vector3(2.5, 0, 0))
	aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.5)
	ok("combo: Swollen Snap hits 44% harder", dmg(T) > d_near * 1.35, "plain %.1f swollen %.1f" % [d_near, dmg(T)])
	var snap_k := float(sn["dmg"]) / float(Data.weapon_stats("tether_lantern")["dmg"])
	ok("data: the Snap hits about 1.05x an orb (277 vs 263)", absf(snap_k - 277.0 / 263.0) < 0.03, "%.3f" % snap_k)
	ok(
		"data: the Snap rests 10s; the Trade 9.5s; the seed 10s",
		absf(float(sn["cooldown"] if sn.has("cooldown") else K.rmb_def()["cooldown"]) - 10.0) < 0.01 and absf(
			float(dd["cd"]) - 9.5
		) < 0.01 and absf(float(K.e_def()["cooldown"]) - 10.0) < 0.01
	)
	ok(
		"data: a full orb is 34% harder (353 vs 263)",
		absf(float(K.lmb_def()["prime_dmg"]) - (353.0 / 263.0 - 1.0)) < 0.01
	)
	ok("data: no speed burst before rank 3", K.boost_t <= 0.0 and absf(K.move_k() - 1.0) < 0.01)
	# ---- Shift: hold to see both ends, let go to lob; the foe at the landing goes to where he was
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0))
	aim_at(P, T.pos)
	P.inp["dash_down"] = true
	P.ak.on_dash(false)
	step(m, 0.3, func(): P.inp["dash_down"] = true)
	var se := AimKit.entry(P, "swap")
	ok(
		"dash aim: holding Shift shows both ends, the landing at the cursor",
		AimKit.shown(P, "swap") and (
			se.get("b", Vector2.ZERO) as Vector2
		).distance_to(Vector2(T.pos.x, T.pos.z)) < 0.6 and K.swap.is_empty(),
		str(se.get("b"))
	)
	ok("anim: aiming Shift plays ostra_swap_aim", K.anim_id == "ostra_swap_aim")
	P.inp["dash_down"] = false
	m.step(DT)
	m.step(DT)
	ok(
		"dash: let go = the lantern is lobbed (in flight, both ends shown to all)",
		not K.swap.is_empty() and AimKit.shown(P, "swap_fly") and bool(AimKit.entry(P, "swap_fly").get("all", false))
	)
	ok("item 35: a ground Trade plays his underhand lob, ostra_swap", K.anim_id == "ostra_swap")
	m.step(DT)
	var lantern: Dictionary = KitLooks.of(m).held.get("os_star", {})
	ok(
		"owner 11-08: the Trade's lantern is drawn 1.3x (TRADE_LOOK_K), the catch circle stays dash.radius",
		not lantern.is_empty() and absf((lantern["n"] as Node3D).scale.x - OstraKit.TRADE_LOOK_K) < 0.001
			and absf(float(AimKit.entry(P, "swap_fly").get("r", 0.0)) - float(K.dash_def()["radius"])) < 0.001
	)
	var t_cast := m.time
	var done_at := [0.0]
	step(m, 2.0, func(): if K.swaps == 1 and done_at[0] == 0.0: done_at[0] = m.time)
	ok(
		"dash: the lob takes about 1.8s (1.25s Swollen)",
		absf(done_at[0] - t_cast - float(dd["time"])) < 0.08 and absf(float(dd["time_swollen"]) - 1.25) < 0.01,
		"%.2f s" % (done_at[0] - t_cast)
	)
	ok("dash: a high lob (the lantern climbs 4m and more)", K.swap_peak >= 4.0, "peak %.1f" % K.swap_peak)
	ok(
		"dash: Trade trades places; the foe is only moved, not slowed (the data's Swap has no slow)",
		K.swaps == 1 and P.pos.x - home.x > 6.0 and T.pos.x - home.x < 2.0 and T.slow_t <= 0.0,
		"me %.1f foe %.1f" % [P.pos.x - home.x, T.pos.x - home.x]
	)
	# owner: spamming Shift never sends him off in another direction
	reset.call()
	aim_at(P, home + Vector3(8.0, 0, 0))
	var sw0 := K.swaps
	P.ak.on_dash(false)
	m.step(DT)
	var p_mid := P.pos
	for i in 8:
		P.do_dash()
		m.step(DT)
	ok(
		"owner: spamming Shift in flight never dashes (no travel, no second lob)",
		P.roll_t <= 0.0 and Vector2(
			P.pos.x - p_mid.x, P.pos.z - p_mid.z
		).length() < 0.8 and K.swaps == sw0 and K.swap_aim < 0.0,
		"moved %.2f roll %.2f swaps %d aim %.2f" % [
			Vector2(P.pos.x - p_mid.x, P.pos.z - p_mid.z).length(), P.roll_t, K.swaps, K.swap_aim
		]
	)
	step(m, 2.0)
	reset.call()
	P.dashes = 0.0
	var d0 := K.denied_swaps
	for i in 4:
		P.inp["move"] = Vector2(0, -1)
		P.do_dash()
		m.step(DT)
	P.inp["move"] = Vector2.ZERO
	ok(
		"owner: with no charge Shift is refused, never the long dash",
		K.denied_swaps > d0 and P.roll_t <= 0.0 and K.swap.is_empty() and Vector2(
			P.pos.x - home.x, P.pos.z - home.z
		).length() < 0.6,
		"moved %.2f" % Vector2(P.pos.x - home.x, P.pos.z - home.z).length()
	)
	# item 17: he drifts slowly while the lantern flies, keeps his height over the abyss
	await _hover(m, P, T, home, K)
	_far_cast(m, P, home, K)
	reset.call()
	K.swollen_t = 5.0
	ok("combo: Swollen Trade is quicker", absf(K.swap_time() - 1.25) < 0.01, "%.2f" % K.swap_time())
	# owner: everyone in the landing circle goes to where he stood (two units both end up at the origin)
	await _multi(m, P, T, home, K)
	# ---- E: the seed drops at the cursor, grows 6.5s, light column near full, the 0.3s recast floor
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0))
	aim_at(P, T.pos)
	K.cast_e()
	m.step(DT)
	ok(
		"e: the seed lands at the cursor, everyone sees its ring",
		not K.seed.is_empty() and Vector2(
			K.seed["pos"].x - T.pos.x, K.seed["pos"].z - T.pos.z
		).length() < 0.5 and bool(AimKit.entry(P, "seed").get("all", false))
	)
	ok("e: a small orb drops from his hand onto the spot", KitLooks.of(m).holding("os_drop"))
	ok("anim: the plant plays ostra_seed", K.anim_id == "ostra_seed")
	var e0 := K.early_pops
	K.use_e()
	ok("small: E again inside 0.3s is eaten, the seed stays", K.early_pops == e0 + 1 and not K.seed.is_empty())
	step(m, 0.4)
	K.e_recast()
	step(m, 0.2)
	var early := dmg(T)
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0))
	aim_at(P, T.pos)
	K.cast_e()
	step(m, 4.0)
	var no_col := K.seed.get("col") == null
	step(m, 0.6)
	ok("e: the light column rises near full growth (from about 4.4s)", no_col and K.seed.get("col") != null)
	step(m, 1.95)
	ok(
		"e: the seed grows for 6.5s to 3.2m", K.seed_k() >= 0.99 and absf(K.seed_radius() - 3.2) < 0.05,
		"k %.2f r %.2f" % [K.seed_k(), K.seed_radius()]
	)
	K.e_recast()
	step(m, 0.2)
	var late := dmg(T)
	ok(
		"e: a full pop hits up to 3.5x an early one", late > early * 2.5 and K.pops >= 2,
		"early %.1f late %.1f" % [early, late]
	)
	ok(
		"e: a full pop is 3.5x the base 12.5 (source peak)", absf(late - 12.5 * 3.5) < 1.0,
		"late %.2f vs %.2f" % [late, 12.5 * 3.5]
	)
	ok("data: the pop does not ground what it catches", not KitStatus.grounded(T))
	ok("anim: the pop plays ostra_pop", K.anim_id == "ostra_pop")
	# the data: "reactivate to detonate": left alone at full size it waits for the recast, then the Collapse
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0))
	aim_at(P, T.pos)
	var c0 := K.collapses
	K.cast_e()
	step(m, 7.2)
	var waiting := not K.seed.is_empty() and K.collapses == c0
	K.e_recast()
	step(m, 0.1)
	ok(
		"e: a full seed waits for the recast (no auto-pop), which Collapses it",
		waiting and K.collapses == c0 + 1 and K.seed.is_empty(), "collapses %d" % K.collapses
	)
	reset.call()
	K.cd["e"] = 0.0
	var hp_fizz := T.hp
	K.cast_e()
	step(m, float(K.e_def()["grow"]) + float(K.e_def()["hold_full"]) + 0.2)
	ok("e: left unpopped at full size for 10s it fizzles out harmlessly", K.seed.is_empty() and T.hp >= hp_fizz)
	# Snap > seed > pop: the combo the kit is built around
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0))
	aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.56)
	var stun_in := T.stun_t
	K.cast_e()
	step(m, 0.5)
	K.e_recast()
	step(m, 0.2)
	ok(
		"combo: Snap > seed on the stunned foe > pop", stun_in > 0.5 and dmg(T) >= 20.0,
		"stun %.2f took %.1f" % [stun_in, dmg(T)]
	)
	# seed under you, Trade through the foe: it lands in the seed
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0))
	aim_at(P, P.pos + Vector3(0.5, 0, 0))
	K.cast_e()
	step(m, 1.0)
	aim_at(P, T.pos)
	P.ak.on_dash(false)
	step(m, 2.0)
	var inside := Vector2(
		T.pos.x - float(K.seed["pos"].x), T.pos.z - float(K.seed["pos"].z)
	).length() < K.seed_radius() + 0.6 if not K.seed.is_empty() else false
	K.e_recast()
	step(m, 0.2)
	ok("combo: Seed > Trade puts the foe inside it", inside and dmg(T) > 10.0, "inside %s took %.1f" % [inside, dmg(T)])
	# quiet level growth: the pop's damage scales with LevelGrowth.ap (through power())
	var lv0 := P.lvl
	var dl := []
	var aps := []
	for lv in [1, 10]:
		P.lvl = lv
		LevelGrowth.apply(P)      # levels set on the hunter grow nothing until applied (as when gained)
		reset.call()
		T.teleport(home + Vector3(6.0, 0, 0))
		aim_at(P, T.pos)
		aps.append(LevelGrowth.ap(P))
		K.cast_e()
		step(m, 1.0)
		K.e_recast()
		step(m, 0.1)
		dl.append(dmg(T))
	var apk1: float = aps[0]
	var apk: float = aps[1]
	P.lvl = lv0
	ok(
		"growth: the seed's pop scales with LevelGrowth.ap",
		apk > apk1 and absf(float(dl[1]) / maxf(0.01, float(dl[0])) - apk / apk1) < 0.03,
		"lvl1 %.2f lvl10 %.2f ap %.2f/%.2f" % [float(dl[0]), float(dl[1]), apk1, apk]
	)
	# data: a knock no longer heals; he floats clear of ground hazards (but not a sky strike)
	reset.call()
	P.hp = P.max_hp * 0.4
	var h0 := P.hp
	K.on_knock(T, true)
	ok("data: a knock does not heal him", absf(P.hp - h0) < 0.01, "healed %.1f" % (P.hp - h0))
	for tag in ["hazard", "lava", "spore", "toxic", "molten"]:
		var hz0 := P.hp
		P.hurt(10.0, null, {"src": "hazard", "tags": ["zone", tag], "burn": 2.0, "slow": 1.0})
		ok("data: a %s hit passes him by" % tag, absf(P.hp - hz0) < 0.01 and P.slow_t <= 0.0 and P.burn_t <= 0.0)
	var sky0 := P.hp
	P.hurt(10.0, null, {"src": "hazard", "tags": ["mut", "hazard"], "sky": true})
	ok("data: a sky strike still hits him", P.hp < sky0 - 5.0, "took %.1f" % (sky0 - P.hp))
	var plain0 := P.hp
	P.hurt(5.0, null, {"src": "mob"})
	ok("data: a plain hit still lands", P.hp < plain0 - 1.0)
	# rank 3: the growing seed burns; the pop no longer pulls (the pull is Nightwell's, on X)
	P.slot_lv["kin"] = 3
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0))
	aim_at(P, T.pos)
	K.cast_e()
	step(m, 1.2)
	ok(
		"rank 3: the growing seed burns a foe inside it, about 8 a second (250 vs a 365 bomb of 12.5)",
		dmg(T) / K.power("kin") > 11.0 and dmg(T) / K.power("kin") < 14.0,
		"dmg %.1f over 1.2s (power %.2f)" % [dmg(T), K.power("kin")]
	)
	step(m, 4.8)
	var sp: Vector3 = K.seed["pos"] if not K.seed.is_empty() else T.pos
	var rim := K.seed_radius()
	T.teleport(sp + Vector3(rim * 1.15, 0, 0))
	K.e_recast()
	step(m, 0.2)
	var off := Vector2(T.pos.x - sp.x, T.pos.z - sp.z).length()
	ok("rank 3: the pop leaves a foe outside its rim where it stands", off > rim, "off %.1f rim %.1f" % [off, rim])
	P.slot_lv["kin"] = 1
	# ---- data pass, Snap rank 3: a speed burst on the cast (11%), a bigger one on the hit (22%), for 2s
	P.slot_lv["sec"] = 3
	reset.call()
	T.teleport(home + Vector3(2.5, 0, 0))
	aim_at(P, T.pos)
	tap(m, P)
	var cast_k := [0.0]
	var hit_k := [0.0]
	step(m, 0.8, func():
		if K.boost_t > 0.0:
			if T.stun_t > 0.0: hit_k[0] = maxf(hit_k[0], K.boost_k)
			elif K.snaps > 0: cast_k[0] = maxf(cast_k[0], K.boost_k))
	ok(
		"data rank 3: Snap speeds him up 11% on the cast and 22% on a hit",
		absf(cast_k[0] - 0.108) < 0.01 and absf(hit_k[0] - 0.215) < 0.01 and absf(K.move_k() - 1.215) < 0.01,
		"cast %.3f hit %.3f now %.3f" % [cast_k[0], hit_k[0], K.move_k()]
	)
	step(m, 2.2)
	ok("data rank 3: the burst ends after 2s", K.boost_t <= 0.0 and absf(K.move_k() - 1.0) < 0.01)
	P.slot_lv["sec"] = 1
	# ---- data pass, Trade rank 3: allies beside him get a 26 shield (375 of a 2074-hp hunter, on 145 hp)
	P.slot_lv["dash"] = 3
	reset.call()
	var A: Hunter = m.make_hunter(
		"Ally", P.team, "medium", "Ally", "idle", {}, home + Vector3(1.2, 0, 1.0), {"arch": "none"}
	)
	A.max_hp = 10000.0
	A.hp = A.max_hp
	T.teleport(home + Vector3(10.0, 0, 0))
	aim_at(P, T.pos)
	P.ak.on_dash(false)
	step(m, 2.2)
	ok(
		"data rank 3: an ally beside him gets a 26 shield for 3s", A.shield >= 25.5 and A.shield < 27.0,
		"shield %.1f" % A.shield
	)
	A.queue_free()
	m.hunters.erase(A)
	P.slot_lv["dash"] = 1
	# ---- merge start drops every hold
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0))
	aim_at(P, T.pos)
	P.ak.on_dash(false)
	step(m, 0.2)
	var trading: bool = not K.swap.is_empty()
	var swaps0 := K.swaps
	ok("merge hold: the Trade is in flight before the merge", trading, "swap %s" % trading)
	ok("merge hold: a merge is under way", _merge(P))
	step(m, 2.0)
	ok(
		"merge hold: ostra's Trade is dropped, nobody moves mid-merge",
		K.swap.is_empty() and K.swaps == swaps0 and absf(
			P.pos.x - home.x
		) < 1.5 and T.pos.x - home.x > 6.0 and T.slow_t <= 0.0,
		"me %.1f foe %.1f" % [P.pos.x - home.x, T.pos.x - home.x]
	)
	await done(m)
	r = setup("ostra", 6.0)
	m = r[0]
	P = r[1]
	T = r[2]
	home = r[3]
	K = P.ak
	step(m, 1.6)
	ok("merge hold: the orb is charged before the merge", K.charge >= 1.0)
	K.swap_aim = 0.2
	K.snap = {"t": 0.1, "T": 0.32}
	ok("merge hold: a merge is under way", _merge(P))
	step(m, 0.2)
	ok(
		"merge hold: the orb's charge, the Shift aim and the Snap wind-up drop with the merge",
		K.charge <= 0.0 and K.swap_aim < 0.0 and K.snap.is_empty() and K.snaps == 0,
		"charge %.2f" % K.charge
	)
	_dash_moves(K)
	# ---- every move, sound and look exists
	var moves := [
		"ostra_orb", "ostra_orb_hot", "ostra_snap_wind", "ostra_snap", "ostra_swap_aim", "ostra_swap", "ostra_swap_air",
		"ostra_arrive", "ostra_seed", "ostra_pop", "ostra_empower", "ostra_well", "ostra_well_snap", "ostra_well_end"
	]
	ok(
		"anim: every Motley move is keyed (KMovesStone)",
		moves.all(func(mv): return not HunterAnim.km_sample(mv, 0.1).is_empty()),
		str(moves.filter(func(mv): return HunterAnim.km_sample(mv, 0.1).is_empty()))
	)
	var snd := SfxKits.NAMES.filter(func(s): return String(s).begins_with("os_"))
	ok(
		"sfx: every Motley sound is loaded by Sfx", snd.size() >= 12 and snd.all(func(s): return Sfx.has(s)),
		str(snd.filter(func(s): return not Sfx.has(s)))
	)
	await done(m)

## Item 35: his own ground and air dash moves (the Trade's lob), ids no other hero's table has, and each one's
## Item 60: the orb charges smoothly with the wait since the last shot (damage, speed, size monotonic from 0 to the
## window, capped after), every orb passes a wall between him and the foe at any charge, and a full orb slows.
func _bolt_through_terrain() -> void:
	var r := setup("ostra", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: OstraKit = P.ak
	var W = m.world
	var wx := int(floor(home.x)) + 3
	var wz := int(floor(home.z))
	for dz in range(-2, 3):
		W.kind[W.idx(wx, wz + dz)] = World.T_BLOCK
	aim_at(P, T.pos)
	var idle := float(K.lmb_def()["idle"])
	var waits := [0.0, 0.35, 0.7, 1.05, idle, idle + 1.0, idle + 3.0]
	var dmgs: Array = []
	var spds: Array = []
	var rads: Array = []
	var slows: Array = []
	var through := true
	for w in waits:
		fresh(T)
		K.last_shot_t = m.time - w
		step(m, 0.03)
		var shots0 := P.shot_n
		spds.append(float(P.wpn["speed"]))
		P.fire_cd = 0.0
		P.inp["fire"] = true
		step(m, 0.05)
		P.inp["fire"] = false
		step(m, 0.9)
		var d := dmg(T)
		dmgs.append(d)
		rads.append(K.last_orb_r)
		slows.append(T.slow_t > 0.0)
		if P.shot_n <= shots0 or d <= 0.5:
			through = false
		step(m, 0.6)
	var mono := true
	for i in range(1, waits.size()):
		if dmgs[i] < dmgs[i - 1] - 0.01 or spds[i] < spds[i - 1] - 0.01 or rads[i] < rads[i - 1] - 0.001:
			mono = false
	ok(
		"item 60: damage, speed and size grow with the wait (monotonic) from 0 to the window",
		mono and dmgs[4] > dmgs[0] * 1.2 and rads[4] > rads[0] * 1.5 and spds[4] > spds[0] * 1.2,
		"dmg %s speed %s r %s" % [str(dmgs), str(spds), str(rads)]
	)
	ok(
		"item 60: it is smooth, not a switch (a mid wait lands between the two ends)",
		dmgs[2] > dmgs[0] + 0.3 and dmgs[2] < dmgs[4] - 0.3 and rads[2] > rads[0] and rads[2] < rads[4]
	)
	ok(
		"item 60: capped after the window",
		absf(dmgs[5] - dmgs[4]) < 0.05 and absf(dmgs[6] - dmgs[4]) < 0.05 and absf(rads[6] - rads[4]) < 0.001,
		str(dmgs)
	)
	ok("item 60: a full orb hits for the data's +34% (353 vs 263)", absf(dmgs[4] / dmgs[0] - 1.34) < 0.06, str(dmgs))
	ok("item 60: every orb passes the wall between him and the foe at any charge", through, str(dmgs))
	ok("item 60: only the full orb slows", slows[4] and slows[5] and not slows[0] and not slows[2], str(slows))
	await done(m)

## Void's Gravity Orb (parity pass): held, an orb every 0.6 s (footage 0031 -> 0034), each a one-hand flick
## (ostra_orb) that leaves along the aim; he turns to the cursor, so while he drifts sideways every orb
## leaves at it as it swings round him.
func _orb_parity(m: Match, P: Hunter, home: Vector3, K: OstraKit) -> void:
	var seen := {}
	for s0 in m.shots.filter(func(s): return s["by"] == P):
		seen[s0["sid"]] = true
	var times: Array = []
	var worst := 0.0
	var flicks := 0
	P.inp["move"] = Vector2(0, 1)
	var t := 0.0
	while t < 2.0:
		var swing := Vector3(cos(t * 1.5), 0, sin(t * 1.5)) * 6.0
		aim_at(P, P.pos + swing)
		P.inp["fire"] = true
		m.step(DT)
		t += DT
		for s1 in m.shots.filter(func(s): return s["by"] == P):
			if seen.has(s1["sid"]):
				continue
			seen[s1["sid"]] = true
			times.append(t)
			flicks += 1 if K.anim_id in ["ostra_orb", "ostra_orb_hot"] else 0
			worst = maxf(worst, rad_to_deg(absf((s1["vel"] as Vector2).angle_to(Vector2(swing.x, swing.z)))))
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	var span := float(times[-1]) - float(times[0]) if times.size() > 1 else 0.0
	var cadence := span / maxf(1.0, times.size() - 1)
	ok(
		"lmb parity: held, an orb every 0.6 s, each with its flick, while he drifts",
		absf(cadence - 0.6) < 0.03 and flicks == times.size() and times.size() >= 3,
		"%d orbs, %.2f s apart" % [times.size(), cadence]
	)
	ok("lmb parity: every orb leaves at the cursor as it swings round him (within 8 deg)", worst < 8.0, "%.1f" % worst)
	K.res = 0.0
	step(m, 0.3)
	aim_at(P, home + Vector3(3.0, 0, 0))

## keyed length inside the quickest Trade (Swollen); the arrival's pop starts once it lands.
func _dash_moves(K: OstraKit) -> void:
	var ids := ["ostra_swap", "ostra_swap_air"]
	var others := [HunterAnim.KMOVES, KMovesPair.MOVES, KMovesVV.MOVES, MergeMoves.MOVES, KMovesCare.MOVES,
		KMovesPinBjorn.MOVES, KMovesDJ.MOVES]
	ok(
		"item 35: his ground and air dash moves are two distinct ids, his alone (KMovesStone, no other table)",
		ids[0] != ids[1] and ids.all(func(id): return KMovesStone.MOVES.has(id) and String(id).begins_with("ostra_"))
			and not others.any(func(t): return ids.any(func(id): return (t as Dictionary).has(id)))
	)
	var quickest := float(K.dash_def()["time_swollen"])
	var lengths := ids.map(func(id): return float((KMovesStone.MOVES[id]["keys"] as Array)[-1][0]))
	ok(
		"item 35: each dash move's keyed length fits inside the quickest Trade (%.2fs)" % quickest,
		lengths.all(func(l): return l > 0.2 and l <= quickest), str(lengths)
	)

## Items 17 and 75: while the lantern flies he drifts slowly (30% of run speed), holds his height even over the abyss,
## and the Trade sends everyone to where he is when it lands.
func _hover(m: Match, P: Hunter, T: Hunter, home: Vector3, K: OstraKit) -> void:
	var W = m.world
	var gap := home + Vector3(-3.0, 0, 0)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			W.kind[W.idx(int(floor(gap.x)) + dx, int(floor(gap.z)) + dz)] = World.T_VOID
	K._drop_holds()
	var run_speed := P.base_speed
	P.inp["move"] = Vector2.ZERO
	P.teleport(gap + Vector3(0, 1.5, 0))
	P.grounded = false
	P.vel = Vector3.ZERO
	P.dashes = P.max_dashes()
	fresh(T)
	T.teleport(home + Vector3(5.0, 0, 3.0))
	aim_at(P, home + Vector3(5.0, 0, 3.0))
	P.ak.on_dash(false)
	m.step(DT)
	m.step(DT)
	ok("item 35: a Trade in the air plays his air sling and drift, ostra_swap_air", K.anim_id == "ostra_swap_air")
	var y0 := P.pos.y
	var at_start := P.pos
	var low := [y0, y0]
	var last := [P.pos]
	var flying := not K.swap.is_empty()
	P.inp["move"] = Vector2(0, -1)
	var ticks := [0]
	step(m, 1.5, func():
		if not K.swap.is_empty():
			low[0] = minf(low[0], P.pos.y)
			low[1] = maxf(low[1], P.pos.y)
			last[0] = P.pos
			ticks[0] += 1)
	P.inp["move"] = Vector2.ZERO
	var drift := Vector2(last[0].x - at_start.x, last[0].z - at_start.z).length()
	var speed := drift / (float(ticks[0]) * DT)
	var fly_slow := float(K.dash_def()["fly_slow"])
	ok(
		"item 75 + owner 11-08: in flight he drifts at dash.fly_slow (0.35, +17%) of his run speed",
		flying and run_speed > 1.0 and absf(fly_slow - 0.35) < 0.001
			and absf(speed / run_speed - fly_slow) < 0.03,
		"%.2f of %.2f (data %.2f)" % [speed, run_speed, fly_slow]
	)
	ok(
		"item 17: his height is constant over the abyss (no fall)",
		low[0] > y0 - 0.02 and low[1] < y0 + 0.02 and not P.out, "%.3f..%.3f of %.3f" % [low[0], low[1], y0]
	)
	var swaps0 := K.swaps
	step(m, 0.6, func(): if K.swaps > swaps0 and last[0] == Vector3.INF: last[0] = P.pos)
	var landed := Vector2(T.pos.x - last[0].x, T.pos.z - last[0].z).length()
	ok("item 17: the foe in the circle is sent to where he was when it resolved", landed < 1.6 and K.swaps > swaps0)
	ok("anim: arriving plays ostra_arrive", K.anim_id == "ostra_arrive")
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			W.kind[W.idx(int(floor(gap.x)) + dx, int(floor(gap.z)) + dz)] = World.T_GROUND
	step(m, 1.0)

## Everyone in the landing circle goes back to where he stood, each keeping its place in the circle; a body
## another game owns is sent its move over Net (bots and online use the same path).
func _multi(m: Match, P: Hunter, T: Hunter, home: Vector3, K: OstraKit) -> void:
	var land := home + Vector3(7.0, 0, 0)
	K._drop_holds()
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.grounded = true
	P.dashes = P.max_dashes()
	fresh(T)
	T.teleport(land + Vector3(0.0, 0, 0.8))
	var none := {"arch": "none"}
	var A: Hunter = m.make_hunter("A", P.team, "medium", "Ally", "idle", {}, land + Vector3(0.0, 0, -0.8), none)
	var R: Hunter = m.make_hunter("R", 5, "medium", "Remote", "idle", {}, land + Vector3(0.9, 0, 0.0), none)
	R.remote = true
	R.nid = "r1"
	var r_at := R.pos
	aim_at(P, land)
	ok("small: the Trade's circle holds all three", K.trade_bodies(land, float(K.dash_def()["radius"])).size() == 3)
	Displace.capture = true
	Displace.sent.clear()
	var foes0 := K.swapped_foes
	var allies0 := K.swapped_allies
	P.ak.on_dash(false)
	step(m, 2.1)
	Displace.capture = false
	var t_off := Vector2(T.pos.x - home.x, T.pos.z - home.z).length()
	var a_off := Vector2(A.pos.x - home.x, A.pos.z - home.z).length()
	ok(
		"owner: two units in the circle (a foe and an ally) both end up at his origin",
		t_off < 1.3 and a_off < 1.3 and K.swapped_foes == foes0 + 2 and K.swapped_allies == allies0 + 1,
		"foe %.2f ally %.2f" % [t_off, a_off]
	)
	ok(
		"small: each keeps its place in the circle (they don't stack on one spot)",
		Vector2(T.pos.x - A.pos.x, T.pos.z - A.pos.z).length() > 1.0
	)
	ok(
		"net: a body another game owns is sent its move to his origin, not moved here",
		Displace.sent.any(func(e): return e[1] == "tp" and e[2] == "r1" and absf(float(e[3]) - home.x - 0.9) < 0.3)
		and R.pos.distance_to(r_at) < 0.05
	)
	for x in [A, R]:
		x.queue_free()
		m.hunters.erase(x)

## Item 42: the Trade is castable anywhere in reach, over the abyss too; past the reach it goes to full reach.
func _far_cast(m: Match, P: Hunter, home: Vector3, K: OstraKit) -> void:
	var W = m.world
	var reach := float(K.dash_def()["reach"])
	var cells: Array = []
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			cells.append(W.idx(int(floor(home.x + reach * 0.5)) + dx, int(floor(home.z)) + dz))
	for c in cells:
		W.kind[c] = World.T_VOID
	K._drop_holds()
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.grounded = true
	P.dashes = P.max_dashes()
	aim_at(P, home + Vector3(reach * 0.5, 0, 0))
	var near := K.swap_spot()
	ok(
		"far cast: a cursor at 0.5x reach over the abyss is the target",
		absf(near.x - home.x - reach * 0.5) < 0.01 and absf(near.z - home.z) < 0.01
	)
	K.on_dash(false)
	step(m, 0.3)
	var landing: Vector3 = K.swap.get("land", Vector3.INF)
	ok(
		"far cast: an abyss target is accepted (the lantern flies to the cursor)",
		not K.swap.is_empty() and Vector2(landing.x - near.x, landing.z - near.z).length() < 0.01
	)
	K._drop_holds()
	P.teleport(home)
	P.grounded = true
	aim_at(P, home + Vector3(2.0 * reach, 0, 0))
	var far := K.swap_spot()
	ok(
		"far cast: a cursor at 2x reach goes to exactly full reach in that direction",
		absf(Vector2(far.x - home.x, far.z - home.z).length() - reach) < 0.01 and absf(far.z - home.z) < 0.01
	)
	aim_at(P, home + Vector3(0, 0, -2.0 * reach))
	var up := K.swap_spot()
	ok(
		"far cast: the same along another direction",
		absf(Vector2(up.x - home.x, up.z - home.z).length() - reach) < 0.01 and absf(up.x - home.x) < 0.01
	)
	for c in cells:
		W.kind[c] = World.T_GROUND
	P.teleport(home)
	P.dashes = P.max_dashes()
	step(m, 0.5)
	_knock_in_flight(m, P, home, K)

## The hover holds his height, not his place: a knock while the lantern flies still shoves him.
func _knock_in_flight(m: Match, P: Hunter, home: Vector3, K: OstraKit) -> void:
	K._drop_holds()
	P.teleport(home + Vector3(0, 1.0, 0))
	P.grounded = false
	P.vel = Vector3.ZERO
	P.dashes = P.max_dashes()
	aim_at(P, home + Vector3(6.0, 0, 0))
	K.on_dash(false)
	step(m, 0.1)
	var at := P.pos
	P.impulse(Vector2(0, 8.0) * P.mass())
	step(m, 0.3)
	var moved := Vector2(P.pos.x - at.x, P.pos.z - at.z).length()
	ok(
		"item 17: a knock while the lantern flies still shoves him, at the held height",
		not K.swap.is_empty() and moved > 1.0 and absf(P.pos.y - at.y) < 0.02, "moved %.2f" % moved
	)
	K._drop_holds()
	P.teleport(home)
	P.grounded = true
	step(m, 0.3)
