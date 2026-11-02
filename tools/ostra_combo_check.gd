extends "res://tools/hero_pair_check.gd"
## --ostra-combo-check: Ostra, docs/heroes/ostra.md. Her reticle (the aim line, the Snap's rails, the
## Trade's two ends), charge and wind-up timings, where each thing lands, the payoffs, the owner's notes
## (Shift never travels on its own, keeps her height, one Snap charge that visibly stuns the training
## dummy), the small mechanics, the merge-start drops, and that every move, sound and look exists.

func run(main_node: Node) -> void:
	main = main_node
	await _ostra()
	print("PAIRCHECK ostra DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _ostra() -> void:
	var r := setup("ostra", 6.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var home: Vector3 = r[3]
	var K: OstraKit = P.ak
	var dd: Dictionary = K.dash_def()
	var sn: Dictionary = K.rmb_def()["snap"]
	var reset := func():
		if not K.seed.is_empty(): K._pop(false)
		K._drop_holds()
		K.swollen_t = 0.0; K.res = 0.0
		P.teleport(home); P.vel = Vector3.ZERO; P.grounded = true; fresh(T); T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
		K.cd["e"] = 0.0; K.e_t = 0.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; P.fire_cd = 0.0; P.dashes = P.max_dashes()
		P.inp["fire"] = false; P.inp["sec_hold"] = false; P.inp["dash_down"] = false
		step(m, 0.2)
		fresh(T)      # (a shard still flying from the last case may have landed meanwhile)
	var card: Dictionary = K.d["card"]
	ok("card: a role line and one line each for LMB, RMB, E, Shift and the passive", ["role", "lmb", "rmb", "e", "dash", "passive"].all(func(k): return String(card.get(k, "")).length() > 10))
	# ---- the reticle: a thin line to the cursor all the time
	reset.call()
	ok("reticle: the thin aim line to the cursor shows the whole time", AimKit.shown(P, "aim") and bool(AimKit.entry(P, "aim").get("arrow", false)))
	# ---- Swell
	K.on_deal(T, 10.0, {})
	var on_h := K.res
	K.res = 0.0
	var mob := Mob.new()
	K.on_deal(mob, 10.0, {})
	var on_m := K.res
	mob.free()
	ok("passive: Swell fills ten times faster on hunters", on_h > 9.0 * on_m and on_h > 3.0, "hunter %.2f mob %.2f" % [on_h, on_m])
	K.res = 0.0
	for i in 40: K.on_deal(T, 10.0, {})
	m.step(DT)
	ok("passive: full Swell = Swollen for 9s, wrapped in the pink sphere", K.is_swollen() and K.swells == 1 and absf(float(K.res_def()["swollen_t"]) - 9.0) < 0.01 and KitLooks.of(m).holding("os_aura"), "swollen %.1f" % K.swollen_t)
	ok("anim: Swollen plays ostra_empower", K.anim_id == "ostra_empower")
	# ---- LMB: plain orbs fly to full range past the cursor; a pause primes a fast bright bolt
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
	ok("lmb: the orb is her own violet teardrop (skin)", KitLooks.of(m).skins_live("orb") >= 1)
	step(m, 1.0)
	ok("lmb: ...and hits a foe well past the cursor", dmg(T) > 5.0, "took %.1f" % dmg(T))
	reset.call()
	step(m, 1.6)
	ok("lmb: a pause primes the next orb (a charge held at her hand)", K.primed and KitLooks.of(m).holding("os_charge"), "primed %s" % K.primed)
	var spd_hot := float(P.wpn["speed"])
	P.inp["fire"] = true
	step(m, 0.05, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	ok("lmb: the Settled orb is a long bright bolt, faster (1.4x)", KitLooks.of(m).skins_live("orb_hot") >= 1 and spd_hot > 40.0, "speed %.0f" % spd_hot)
	ok("anim: the Settled bolt plays ostra_orb_hot", K.anim_id == "ostra_orb_hot")
	step(m, 1.0)
	ok("lmb: the Settled orb hits harder and slows", K.settled_shots == 1 and dmg(T) >= 11.0 and T.slow_t > 0.0, "took %.1f slow %.1f" % [dmg(T), T.slow_t])
	ok("small: the charge is stepped, not gradual (one Settled orb, then plain)", not K.primed and float(P.wpn["speed"]) < 35.0, "speed %.0f" % float(P.wpn["speed"]))
	# ---- RMB: one charge, a visible wind-up with the two rails, one bundle, a stun that reads
	reset.call()
	ok("rmb: Shard Snap has one charge", K.rmb_charges() == 1)
	P.inp["sec_hold"] = true
	m.step(DT)
	ok("rmb aim: holding RMB turns the line into two rails the bundle's width", AimKit.shown(P, "snap") and bool(AimKit.entry(P, "snap").get("rails", false)) and absf(float(AimKit.entry(P, "snap").get("width", 0.0)) - float(sn["width"])) < 0.01 and not AimKit.shown(P, "aim"))
	P.ak.press_rmb()
	m.step(DT)
	ok("rmb: a 0.2s wind-up first (dark orb at the hand, nothing fired yet)", K.snaps == 0 and not K.snap.is_empty() and KitLooks.of(m).holding("os_snaporb"), "snaps %d" % K.snaps)
	ok("small: she slows 25% while casting the Snap", absf(K.move_k() - 0.75) < 0.01, "%.2f" % K.move_k())
	ok("anim: the wind-up plays ostra_snap_wind", K.anim_id == "ostra_snap_wind")
	P.inp["sec_hold"] = false
	step(m, 0.22)
	var bundles: Array = m.shots.filter(func(s): return s["by"] == P and String((s["x"] as Dictionary).get("ab", "")) == "rmb")
	ok("rmb: then one tight bundle (a single projectile, crystal-spear skin)", K.snaps == 1 and bundles.size() == 1 and KitLooks.of(m).skins_live("spear") == 1, "bundles %d" % bundles.size())
	ok("rmb: the ability is spent (no second cast)", K.ch_rmb < 1.0 and not K.rmb_ready())
	# the stun: near vs far, and visible on the training dummy
	reset.call()
	T.teleport(home + Vector3(2.5, 0, 0)); aim_at(P, T.pos)
	var s_near := [0.0]
	tap(m, P)
	step(m, 0.5, func(): s_near[0] = maxf(s_near[0], T.stun_t))
	var d_near := dmg(T)
	ok("rmb: the stun shows on the dummy (stars over its head)", s_near[0] > 0.0 and KitLooks.of(m).crowned(T))
	reset.call()
	T.teleport(home + Vector3(11.5, 0, 0)); aim_at(P, T.pos)
	var s_far := [0.0]
	tap(m, P)
	step(m, 0.8, func(): s_far[0] = maxf(s_far[0], T.stun_t))
	ok("rmb: it stuns 0.8s up close, up to 1.8s the further it flew", s_near[0] >= 0.75 and s_near[0] < 1.1 and s_far[0] > 1.5, "near %.2f far %.2f" % [s_near[0], s_far[0]])
	reset.call()
	K.swollen_t = 5.0
	T.teleport(home + Vector3(2.5, 0, 0)); aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.5)
	ok("combo: Swollen Snap hits 40% harder", dmg(T) > d_near * 1.25, "plain %.1f swollen %.1f" % [d_near, dmg(T)])
	ok("numbers: the Snap hits about 1.4x an orb", float(sn["dmg"]) / float(Data.weapon_stats("tether_lantern")["dmg"]) > 1.3)
	# ---- Shift: hold to see both ends, let go to lob; the foe at the landing goes to where she was
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0)); aim_at(P, T.pos)
	P.inp["dash_down"] = true
	P.ak.on_dash(false)
	step(m, 0.3, func(): P.inp["dash_down"] = true)
	var se := AimKit.entry(P, "swap")
	ok("dash aim: holding Shift shows both ends, the landing at the cursor", AimKit.shown(P, "swap") and (se.get("b", Vector2.ZERO) as Vector2).distance_to(Vector2(T.pos.x, T.pos.z)) < 0.6 and K.swap.is_empty(), str(se.get("b")))
	ok("anim: aiming Shift plays ostra_swap_aim", K.anim_id == "ostra_swap_aim")
	P.inp["dash_down"] = false
	m.step(DT)
	m.step(DT)
	ok("dash: let go = the lantern is lobbed (in flight, both ends shown to all)", not K.swap.is_empty() and AimKit.shown(P, "swap_fly") and bool(AimKit.entry(P, "swap_fly").get("all", false)))
	var t_cast := m.time
	var done_at := [0.0]
	step(m, 2.0, func(): if K.swaps == 1 and done_at[0] == 0.0: done_at[0] = m.time)
	ok("dash: the lob takes about 1.7s (1.25s Swollen)", absf(done_at[0] - t_cast - float(dd["time"])) < 0.08 and absf(float(dd["time_swollen"]) - 1.25) < 0.01, "%.2f s" % (done_at[0] - t_cast))
	ok("dash: a high lob (the lantern climbs 4m and more)", K.swap_peak >= 4.0, "peak %.1f" % K.swap_peak)
	ok("dash: Trade trades places and slows the foe", K.swaps == 1 and P.pos.x - home.x > 6.0 and T.pos.x - home.x < 2.0 and T.slow_t > 0.0, "me %.1f foe %.1f" % [P.pos.x - home.x, T.pos.x - home.x])
	# owner: spamming Shift never sends her off in another direction
	reset.call()
	aim_at(P, home + Vector3(8.0, 0, 0))
	var sw0 := K.swaps
	P.ak.on_dash(false)
	m.step(DT)
	var p_mid := P.pos
	for i in 8:
		P.do_dash()
		m.step(DT)
	ok("owner: spamming Shift in flight never dashes (no travel, no second lob)", P.roll_t <= 0.0 and Vector2(P.pos.x - p_mid.x, P.pos.z - p_mid.z).length() < 0.8 and K.swaps == sw0 and K.swap_aim < 0.0, "moved %.2f roll %.2f swaps %d aim %.2f" % [Vector2(P.pos.x - p_mid.x, P.pos.z - p_mid.z).length(), P.roll_t, K.swaps, K.swap_aim])
	step(m, 2.0)
	reset.call()
	P.dashes = 0.0
	var d0 := K.denied_swaps
	for i in 4:
		P.inp["move"] = Vector2(0, -1)
		P.do_dash()
		m.step(DT)
	P.inp["move"] = Vector2.ZERO
	ok("owner: with no charge Shift is refused, never the long dash", K.denied_swaps > d0 and P.roll_t <= 0.0 and K.swap.is_empty() and Vector2(P.pos.x - home.x, P.pos.z - home.z).length() < 0.6, "moved %.2f" % Vector2(P.pos.x - home.x, P.pos.z - home.z).length())
	# owner: Shift keeps her height; and she keeps her momentum
	reset.call()
	aim_at(P, home + Vector3(7.0, 0, 0))
	P.ak.on_dash(false)
	step(m, 1.5)
	P.teleport(P.pos + Vector3(0, 2.0, 0)); P.grounded = false; P.vel = Vector3(3.0, 0.0, 0.0)
	var dy := P.pos.y - P.ground()
	K.swap["t"] = 0.0
	K._tick_swap(DT)
	ok("owner: the Trade keeps her height over the ground", absf((P.pos.y - P.ground()) - dy) < 0.1 and dy > 1.9, "before %.2f after %.2f" % [dy, P.pos.y - P.ground()])
	ok("small: the Trade keeps her momentum", absf(P.vel.x - 3.0) < 0.01, "vx %.2f" % P.vel.x)
	ok("anim: arriving plays ostra_arrive", K.anim_id == "ostra_arrive")
	step(m, 1.0)
	reset.call()
	K.swollen_t = 5.0
	ok("combo: Swollen Trade is quicker", absf(K.swap_time() - 1.25) < 0.01, "%.2f" % K.swap_time())
	# an ally at the landing goes back to where she stood
	reset.call()
	var A: Hunter = m.make_hunter("A", P.team, "medium", "Ally", "idle", {}, home + Vector3(7.0, 0, 0), {"arch": "none"})
	aim_at(P, A.pos)
	P.ak.on_dash(false)
	step(m, 2.0)
	ok("small: Trade swaps any unit at the landing, allies too", K.swapped_allies >= 1 and A.pos.x - home.x < 2.0, "ally x %.1f" % (A.pos.x - home.x))
	A.queue_free(); m.hunters.erase(A)
	# ---- E: the seed drops at the cursor, grows 6.5s, light column near full, the 0.3s recast floor
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	K.cast_e()
	m.step(DT)
	ok("e: the seed lands at the cursor, everyone sees its ring", not K.seed.is_empty() and Vector2(K.seed["pos"].x - T.pos.x, K.seed["pos"].z - T.pos.z).length() < 0.5 and bool(AimKit.entry(P, "seed").get("all", false)))
	ok("e: a small orb drops from her hand onto the spot", KitLooks.of(m).holding("os_drop"))
	ok("anim: the plant plays ostra_seed", K.anim_id == "ostra_seed")
	var e0 := K.early_pops
	K.use_e()
	ok("small: E again inside 0.3s is eaten, the seed stays", K.early_pops == e0 + 1 and not K.seed.is_empty())
	step(m, 0.4)
	K.e_recast()
	step(m, 0.2)
	var early := dmg(T)
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	K.cast_e()
	step(m, 4.0)
	var no_col := K.seed.get("col") == null
	step(m, 0.6)
	ok("e: the light column rises near full growth (from about 4.4s)", no_col and K.seed.get("col") != null)
	step(m, 1.95)
	ok("e: the seed grows for 6.5s to 3.2m", K.seed_k() >= 0.99 and absf(K.seed_radius() - 3.2) < 0.05, "k %.2f r %.2f" % [K.seed_k(), K.seed_radius()])
	K.e_recast()
	step(m, 0.2)
	var late := dmg(T)
	ok("e: a full pop hits up to 3.5x an early one", late > early * 2.5 and K.pops >= 2, "early %.1f late %.1f" % [early, late])
	ok("e: the pop grounds what it catches", KitStatus.grounded(T))
	ok("anim: the pop plays ostra_pop", K.anim_id == "ostra_pop")
	# left alone it pops by itself: the Collapse
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	var c0 := K.collapses
	K.cast_e()
	step(m, 7.2)
	ok("e: a seed left alone pops at full growth (Collapse)", K.collapses == c0 + 1 and K.seed.is_empty(), "collapses %d" % K.collapses)
	# Snap > seed > pop: the combo the kit is built around
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.4)
	var stun_in := T.stun_t
	K.cast_e()
	step(m, 0.5)
	K.e_recast()
	step(m, 0.2)
	ok("combo: Snap > seed on the stunned foe > pop", stun_in > 0.5 and dmg(T) >= 20.0, "stun %.2f took %.1f" % [stun_in, dmg(T)])
	# seed under you, Trade through the foe: it lands in the seed
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0)); aim_at(P, P.pos + Vector3(0.5, 0, 0))
	K.cast_e()
	step(m, 1.0)
	aim_at(P, T.pos)
	P.ak.on_dash(false)
	step(m, 2.0)
	var inside := Vector2(T.pos.x - float(K.seed["pos"].x), T.pos.z - float(K.seed["pos"].z)).length() < K.seed_radius() + 0.6 if not K.seed.is_empty() else false
	K.e_recast()
	step(m, 0.2)
	ok("combo: Seed > Trade puts the foe inside it", inside and dmg(T) > 10.0, "inside %s took %.1f" % [inside, dmg(T)])
	# quiet level growth: the pop's damage scales with LevelGrowth.ap (through power())
	var lv0 := P.lvl
	var dl := []
	var aps := []
	for lv in [1, 10]:
		P.lvl = lv
		reset.call()
		T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
		aps.append(LevelGrowth.ap(P))
		K.cast_e()
		step(m, 1.0)
		K.e_recast()
		step(m, 0.1)
		dl.append(dmg(T))
	var apk1: float = aps[0]; var apk: float = aps[1]
	P.lvl = lv0
	ok("growth: the seed's pop scales with LevelGrowth.ap", apk > apk1 and absf(float(dl[1]) / maxf(0.01, float(dl[0])) - apk / apk1) < 0.03, "lvl1 %.2f lvl10 %.2f ap %.2f/%.2f" % [float(dl[0]), float(dl[1]), apk1, apk])
	# knocks heal
	reset.call()
	P.hp = P.max_hp * 0.4
	var h0 := P.hp
	K.on_knock(T, true)
	ok("passive: a knock heals 20%", P.hp - h0 >= P.max_hp * 0.19, "healed %.1f" % (P.hp - h0))
	# rank 3: the pop drags foes in first
	P.slot_lv["kin"] = 3
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	K.cast_e()
	step(m, 6.0)
	var sp: Vector3 = K.seed["pos"] if not K.seed.is_empty() else T.pos
	T.teleport(sp + Vector3(K.seed_radius() * 1.15, 0, 0))
	K.e_recast()
	step(m, 0.2)
	ok("rank 3: the pop pulls foes at the rim to the middle", Vector2(T.pos.x - sp.x, T.pos.z - sp.z).length() < 1.5 and dmg(T) > 0.0, "off %.1f" % Vector2(T.pos.x - sp.x, T.pos.z - sp.z).length())
	P.slot_lv["kin"] = 1
	# ---- merge start drops every hold
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0)); aim_at(P, T.pos)
	P.ak.on_dash(false)
	step(m, 0.2)
	var trading: bool = not K.swap.is_empty()
	var swaps0 := K.swaps
	ok("merge hold: the Trade is in flight before the merge", trading, "swap %s" % trading)
	ok("merge hold: a merge is under way", _merge(P))
	step(m, 2.0)
	ok("merge hold: ostra's Trade is dropped, nobody moves mid-merge", K.swap.is_empty() and K.swaps == swaps0 and absf(P.pos.x - home.x) < 1.5 and T.pos.x - home.x > 6.0 and T.slow_t <= 0.0, "me %.1f foe %.1f" % [P.pos.x - home.x, T.pos.x - home.x])
	await done(m)
	r = setup("ostra", 6.0)
	m = r[0]; P = r[1]; T = r[2]; home = r[3]
	K = P.ak
	step(m, 1.6)
	ok("merge hold: the orb is Settled before the merge", K.primed)
	K.swap_aim = 0.2
	K.snap = {"t": 0.1}
	ok("merge hold: a merge is under way", _merge(P))
	step(m, 0.2)
	ok("merge hold: the prime, the Shift aim and the Snap wind-up drop with the merge", not K.primed and K.prime_until < 0.0 and K.swap_aim < 0.0 and K.snap.is_empty() and K.snaps == 0, "primed %s" % K.primed)
	# ---- every move, sound and look exists
	var moves := ["ostra_orb", "ostra_orb_hot", "ostra_snap_wind", "ostra_snap", "ostra_swap_aim", "ostra_swap", "ostra_arrive", "ostra_seed", "ostra_pop", "ostra_empower"]
	ok("anim: every Ostra move is keyed (KMovesStone)", moves.all(func(mv): return not HunterAnim.km_sample(mv, 0.1).is_empty()), str(moves.filter(func(mv): return HunterAnim.km_sample(mv, 0.1).is_empty())))
	var snd := SfxKits.NAMES.filter(func(s): return String(s).begins_with("os_"))
	ok("sfx: every Ostra sound is loaded by Sfx", snd.size() >= 12 and snd.all(func(s): return Sfx.has(s)), str(snd.filter(func(s): return not Sfx.has(s))))
	await done(m)
