extends RefCounted
## Sable's (thief) and Juggernaut's checks, run inside --archetype-check and --kit-combo-check (the
## helpers come from tools/archetype_check.gd, passed in as A), or alone as --dancer-combo-check /
## --juggernaut-combo-check (tools/check_registry.gd). They assert what the hero sheets ask for: cursor
## landing, the telegraph while aiming or holding, the charge timings, the payoffs, and the merge holds.

const AKCheck := preload("res://tools/archetype_check.gd")
const ULT := preload("res://tools/dj_ult_check.gd")      # both heroes' ultimates on X, and the burst cap
const ZFEEL := preload("res://tools/zedran_feel_check.gd")   # Kael's chain, RMB rows, Meteor Drop and dashes
const DFEEL := preload("res://tools/dancer_feel_check.gd")   # Sable's Cartwheel, empowered bolt and reset (item 7)
const DPARITY := preload("res://tools/dancer_parity_check.gd")   # her LMB against the source (the parity pass)
const DLOOP := preload("res://tools/dancer_loop_check.gd")   # the Vault loop and the Bola's slow (item 53)
var A: AKCheck

## Standalone: one hero's sections (both for "all"). Prints AKCHECK lines like --archetype-check.
func run(main_node: Node, who := "all") -> void:
	A = AKCheck.new()
	A.main = main_node
	if who in ["all", "thief"]:
		await thief(A)
	if who in ["all", "juggernaut"]:
		await juggernaut(A)
	await combos(A)
	print("AKCHECK DONE, %d checks, failures: %d" % [A.n, A.fails])
	main_node.get_tree().quit(1 if A.fails > 0 else 0)

# ------------------------------------------------------------------ Sable
func thief(a) -> void:
	A = a
	var r = A.setup("thief", 6.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: ThiefKit = P.ak
	T2.teleport(home + Vector3(0, 0, 5.5))
	A.ok("dancer: kit, model, Arc Bolts",
			K != null and P.model.get_meta("arch") == "thief" and P.wid == "arc_bolts"
			and Arch.name_of("thief") == "The Silver Thief",
			P.wid)
	A.ok("dancer: her moves are keyed (KMovesDJ)",
			["thf_lmb_r", "thf_lmb_l", "thf_primed", "thf_vault_r", "thf_vault_l", "thf_bola", "thf_knife",
					"thf_arrive", "thf_encore", "thf_encore_dance", "thf_exdash", "thf_land"]
			.all(func(mv): return not HunterAnim.km_sample(mv, 0.1).is_empty()))
	# LMB: a bolt every 0.45s from alternating hands, each one to the cursor
	P.fire_cd = 0.0
	var hands := []
	A.step(m, 1.0, func():
		P.inp["fire"] = true
		if hands.is_empty() or hands[-1] != K.hand: hands.append(K.hand))
	P.inp["fire"] = false
	A.step(m, 0.5)
	A.ok("dancer LMB: a bolt every 0.45s while held, hands alternating",
			K.bolts == 3 and hands.size() >= 3, "bolts %d hands %s" % [K.bolts, str(hands)])
	A.ok("dancer LMB: bolts hit and stack Marks (one per hit)",
			A.dmg(T) >= 20.0 and K.marks_on(T) == 3, "took %.0f marks %d" % [A.dmg(T), K.marks_on(T)])
	A.ok("dancer LMB: the aim line ends at the cursor, pale lilac",
			AimKit.shown(P, "aim") and (AimKit.entry(P, "aim")["col"] as Color).is_equal_approx(ThiefKit.AIM_LILAC))
	# a bolt with nothing in its way stops at the cursor and fizzles there; past range it stops at 12m
	var spot := home + Vector3(-4.0, 0, -3.0)
	A.aim_at(P, spot)
	P.fire_cd = 0.0
	var fz := K.fizzles
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.step(m, 0.5)
	var off := Vector2(K.last_bolt_end.x - spot.x, K.last_bolt_end.z - spot.z).length()
	A.ok("dancer LMB: a bolt lands at the cursor and fizzles (cursor-placed)",
			K.fizzles == fz + 1 and off < 0.6, "%.2f m off the cursor" % off)
	A.aim_at(P, home + Vector3(-30.0, 0, 0))
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.step(m, 0.6)
	A.ok("dancer LMB: clamped to 12m",
			absf(Vector2(K.last_bolt_end.x - P.pos.x, K.last_bolt_end.z - P.pos.z).length() - 12.0) < 0.8,
			"%.1f m" % Vector2(K.last_bolt_end.x - P.pos.x, K.last_bolt_end.z - P.pos.z).length())
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	A.step(m, 0.55)
	P.inp["move"] = Vector2.ZERO
	for b in m.breaks:
		b["dead"] = true        # a crate in the long bolt's path would stop it short of 13.4 m
	A.aim_at(P, P.pos + Vector3(-30.0, 0, 0))
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	var haste_after := K.haste_t
	A.step(m, 0.6)
	var ed := Vector2(K.last_bolt_end.x - P.pos.x, K.last_bolt_end.z - P.pos.z).length()
	A.ok("dancer small mechanics: the empowered bolt flies 12% further (13.4m); firing it ends the speed",
			K.last_bolt_emp and absf(ed - 13.44) < 0.9 and haste_after <= 0.0, "%.1f m haste %.2f" % [ed, haste_after])
	A.ok("dancer LMB: each bolt has its own pooled look",
			DJFx.of(m).free_pools.has("ride_chakram") and DJFx.of(m).free_pools.has("puff"))
	# Marks: +10% per Mark on bolts only, no cap
	A.fresh(T)
	K.mark_gap = {}
	K.add_mark(T, 2, true)
	A.ok("dancer passive: +10% per Mark on bolts only",
			absf(K.outgoing(T, 10.0, {"src": "shot"}) - 12.0) < 0.01
			and absf(K.outgoing(T, 10.0, {"src": "abil", "ab": "utility"}) - 10.0) < 0.01,
			"%.2f" % K.outgoing(T, 10.0, {"src": "shot"}))
	K.on_deal(T, 5.0, {"src": "abil", "ab": "utility"})
	A.ok("dancer passive: ability hits don't stack", K.marks_on(T) == 2)
	K.add_mark(T, 20, true)
	A.ok("dancer passive: Marks have no cap (22 after 20 more), eight diamonds show",
			K.marks_on(T) == 22 and K.res_text() == "22" and K.pip_count() == 8 and K.res_frac() == 1.0, K.res_text())
	A.ok("dancer passive: 22 Marks make a bolt 3.2x", absf(K.outgoing(T, 10.0, {"src": "shot"}) - 32.0) < 0.01)
	# Vault ranks: empowered +20% at rank 2 and again at rank 3, the speed boost half again as big at rank 3
	var vault_ranks: Array = []
	for rk in [1, 2, 3]:
		P.slot_lv["dash"] = rk
		vault_ranks.append([K.prime_rank_k(), K.vault_haste()])
	P.slot_lv["dash"] = 1
	A.ok("dancer Vault ranks: empowered +20% / +40%, speed boost 0.18 -> 0.27 at rank 3",
			absf(float(vault_ranks[0][0]) - 1.0) < 0.001 and absf(float(vault_ranks[1][0]) - 1.2) < 0.001
			and absf(float(vault_ranks[2][0]) - 1.4) < 0.001 and absf(float(vault_ranks[1][1]) - 0.18) < 0.001
			and absf(float(vault_ranks[2][1]) - 0.27) < 0.001, str(vault_ranks))
	# Vault: a cartwheel, speed, the next bolt empowered; it lands for 3.5x and the Vault comes back
	A.fresh(T)
	P.teleport(home)
	P.dashes = P.max_dashes()
	A.aim_at(P, T.pos)
	var d0 := P.dashes
	var rings0 := _dancer_rings(m)
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	var wheel := K.anim_id
	var pop := [0.0]           # an Array: a lambda can't assign a captured local
	A.step(m, 0.55, func(): pop[0] = maxf(pop[0], K.glint_pop))
	P.inp["move"] = Vector2.ZERO
	A.ok("dancer dash (item 8): no ring on the cartwheel or its landing; the glint in the throwing hand flares",
			_dancer_rings(m) == rings0 and pop[0] > 0.5 and K.glint != null and K.glint.visible
			and K.glint.global_position.distance_to(K.hand_pos(K.hand == 0)) < 0.15,
			"rings %d -> %d pop %.2f glint %s" % [rings0, _dancer_rings(m), pop[0],
					K.glint.global_position.distance_to(K.hand_pos(K.hand == 0)) if K.glint else -1.0])
	var far := 4.5        # the sheet's measured 4.5m (she is off the global dash feel)
	A.ok("dancer dash: Vault cartwheels about 4.5m, speeds +18%, empowers",
			absf(P.flat_dist(home) - far) < 0.6 and K.primed_t > 0.0 and K.move_k() > 1.15
			and P.dashes < d0 - 0.5 and wheel in ["thf_vault_l", "thf_vault_r"],
		"moved %.1f primed %.2f anim %s" % [P.flat_dist(home), K.primed_t, wheel])
	var gold: Dictionary = AimKit.entry(P, "aim")
	A.ok("dancer dash: the aim line turns solid gold, thick, with a glow while empowered",
			(gold.get("col", Color.WHITE) as Color).is_equal_approx(ThiefKit.EMP_LINE)
			and float(gold.get("lw", 0.0)) >= 0.09
			and float(gold.get("hot", 1.0)) == 0.0 and AimKit.shown(P, "aim_glow"))
	A.ok("dancer HUD: EMPOWERED label + dash dot",
			K.ready_label().begins_with("EMPOWERED") and P.slot_info("dash").get("full", false)
			and not P.slot_info("sec").get("full", false),
			K.ready_label())
	A.fresh(T)
	A.aim_at(P, T.pos)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.ok("dancer empowered bolt: the big look rides it",
			K.last_bolt_emp and DJFx.of(m).free_pools.has("ride_chakram_big"))
	A.step(m, 0.5)
	A.ok("dancer empowered bolt: a big hit, 2 Marks (the owner's faster stacking), no Shred, speed ends, Vault back",
			A.dmg(T) >= 18.0 and K.marks_on(T) == 2 and T.vuln_t <= 0.0 and K.move_k() <= 1.0
			and P.dashes >= P.max_dashes() - 0.01 and K.primed_t <= 0.0 and K.primed_hits == 1,
		"dealt %.0f marks %d vuln %.1f dashes %.2f" % [A.dmg(T), K.marks_on(T), T.vuln_t, P.dashes])
	# from a jump the cartwheel holds its speed to the landing: much further than on the ground
	A.step(m, 0.5)
	P.teleport(home)
	P.dashes = P.max_dashes()
	T.teleport(home + Vector3(0, 0, 5.0))
	P.do_jump()
	A.step(m, 0.1)
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	P.inp["move"] = Vector2.ZERO
	var air_move := K.anim_id
	var air_rings := _dancer_rings(m)
	var landed := [false]
	A.step(m, 2.4, func(): landed[0] = landed[0] or K.anim_id == "thf_land")
	A.ok("dancer dash: from a jump the cartwheel carries its speed to the landing (about 1.7x the ground one)",
			P.flat_dist(home) > far * 1.35 and P.grounded and K.vault.is_empty(), "moved %.1f" % P.flat_dist(home))
	A.ok("dancer air dash (items 32, 35): the air Cartwheel, empowered by its row, lands in thf_land, no ring",
			air_move == "thf_exdash" and landed[0] and K.primed_t > 0.0
			and _dancer_rings(m) == air_rings, "move %s landed %s primed %.2f" % [air_move, landed[0], K.primed_t])
	_dancer_dash_moves(K)
	K.primed_t = 0.0
	K.haste_t = 0.0
	P.teleport(home)
	T.teleport(home + Vector3(6.0, 0, 0))
	# RMB: a 0.4s wind-up with the lane showing, then the Bola grounds the first, flies on, tangles a second
	A.fresh(T)
	A.fresh(T2)
	T.teleport(home + Vector3(4.0, 0, 0))
	T2.teleport(home + Vector3(7.0, 0, 0))
	P.teleport(home)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	A.aim_at(P, T.pos)
	A.tap(m, P)
	A.step(m, 0.2)
	var bl: Dictionary = AimKit.entry(P, "rmb")
	A.ok("dancer RMB: the lane shows through the 0.4s wind-up (about 1 bh by 6 bh), nothing thrown yet",
			AimKit.shown(P, "rmb") and absf(float(bl.get("len", 0.0)) - 10.8) < 0.1 and K.bola.is_empty()
			and A.dmg(T) <= 0.0,
			"len %.1f" % float(bl.get("len", 0.0)))
	A.step(m, 0.6)
	A.ok("dancer RMB: Bola grounds the first, flies on, tangles two (stun)",
			K.bola_pairs == 1 and KitStatus.grounded(T) and KitStatus.grounded(T2) and T.stun_t > 0.0
			and T2.stun_t > 0.0 and A.dmg(T) >= 15.0,
		"pairs %d grounded %s/%s stun %.2f/%.2f dmg %.0f" % [K.bola_pairs, KitStatus.grounded(T),
				KitStatus.grounded(T2), T.stun_t, T2.stun_t, A.dmg(T)])
	A.ok("dancer RMB: yellow binding rings on the Grounded (everyone sees them)",
			AimKit.shown(P, "gnd%d" % T.get_instance_id())
			and bool(AimKit.entry(P, "gnd%d" % T.get_instance_id()).get("all", false)))
	T.stun_t = 0.0
	T.dashes = 1.0
	T.do_dash()
	T.do_jump()
	m.step(A.DT)
	A.ok("dancer Bola: Grounded can't dash or jump",
			T.dashes >= 0.99 and T.roll_t <= 0.0 and T.vel.y < 1.0, "dashes %.2f vy %.1f" % [T.dashes, T.vel.y])
	A.step(m, 2.0)
	# ... it bounces once off a wall
	var W = m.world
	for dz in range(-3, 4):
		for dx in range(-7, -5):
			W.level[W.idx(int(home.x) + dx, int(home.z) + dz)] = lv + 3
	P.teleport(home)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	A.aim_at(P, home + Vector3(-6.0, 0, 0))
	A.tap(m, P)
	A.step(m, 0.9)
	A.ok("dancer Bola: bounces off a wall", K.bola_bounces == 1, "bounces %d" % K.bola_bounces)
	# small mechanic: a crate counts as the Bola's first catch (it breaks and flies on its after-distance)
	A.step(m, 1.0)
	P.teleport(home)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	A.aim_at(P, home + Vector3(0, 0, -6.0))
	m._add_break("crate", home + Vector3(0, 0, -2.5))
	A.tap(m, P)
	A.step(m, 0.6)
	A.ok("dancer Bola small mechanic: a crate counts as the first catch, it flies on",
			K.bola_breaks == 1, "breaks %d" % K.bola_breaks)
	# E: the dagger to the cursor (no foe on the way), the arrival circle, recast blinks through afterimages
	A.fresh(T)
	T.teleport(home + Vector3(4.0, 0, 3.0))
	P.teleport(home)
	K.cd["e"] = 0.0
	var kspot := home + Vector3(5.0, 0, -2.0)
	T2.teleport(home + Vector3(-5.0, 0, 5.0))
	A.aim_at(P, kspot)
	P.ak.use_e()
	A.step(m, 0.5)
	A.ok("dancer E: the dagger lands at the cursor, the arrival circle shows",
			not K.knife.is_empty() and K.knife.get("target") == null
			and Vector2((K.knife["pos"] as Vector3).x - kspot.x, (K.knife["pos"] as Vector3).z - kspot.z).length() < 1.0
			and AimKit.shown(P, "knife"),
		"%s vs %s" % [str(K.knife.get("pos", Vector3.ZERO)), str(kspot)])
	P.ak.use_e()
	m.step(A.DT)
	A.ok("dancer E recast: a blink to it with an afterimage chain",
			K.blinks == 1 and Vector2(P.pos.x - kspot.x, P.pos.z - kspot.z).length() < 1.2
			and (DJFx.of(m).free_pools.get("ghost", []) as Array).size() >= 5,
			"blinks %d" % K.blinks)
	# ... into a foe: it sticks (slows), recast steps behind them; left alone it steps you there after 6s
	A.fresh(T)
	T.teleport(home + Vector3(5.0, 0, 0))
	P.teleport(home)
	K.cd["e"] = 0.0
	A.aim_at(P, T.pos)
	P.ak.use_e()
	A.step(m, 0.35)
	A.ok("dancer E: the dagger sticks in a foe (slow 50%, damage)",
			not K.knife.is_empty() and K.knife.get("target") == T and T.slow_t > 0.0 and A.dmg(T) >= 7.0,
			"slow %.2f dmg %.0f" % [T.slow_t, A.dmg(T)])
	A.step(m, 6.1)
	A.ok("dancer E: waiting 6s steps you to it anyway",
			P.flat_dist(T) < 1.8 and K.knife.is_empty(), "dist %.1f" % P.flat_dist(T))
	# a knock heals a fifth (15% passive, 5% from the takedown reset) in all; the crimson star and the green pillar
	P.hp = P.max_hp * 0.5
	var php := P.hp
	T.hp = 4.0
	T.hurt(10.0, P, {"src": "shot"})
	A.step(m, 0.1)
	A.ok("dancer passive: a knock heals (20% in all), star + pillar",
			T.downed and K.knocks_seen >= 1 and P.hp >= php + P.max_hp * 0.19 and DJFx.of(m).free_pools.has("pillar")
			and DJFx.of(m).free_pools.has("star"),
			"hp %.0f -> %.0f" % [php, P.hp])
	A.fresh(T)
	T.teleport(home + Vector3(5.0, 0, 0))
	T.downed = false
	A.step(m, 1.4, func():
		P.inp["fire"] = true
		A.aim_at(P, T.pos))
	P.inp["fire"] = false
	A.step(m, 0.4)
	var made := DJFx.of(m).made
	A.step(m, 1.4, func():
		P.inp["fire"] = true
		A.aim_at(P, T.pos))
	P.inp["fire"] = false
	A.step(m, 0.4)
	var capped := DJFx.of(m).free_pools.values().all(func(arr): return (arr as Array).size() <= DJFx.POOL_CAP)
	A.ok("dancer fx: pooled (every kind capped, a handful of nodes at most per burst)",
			capped and DJFx.of(m).made <= made + 6, "made %d -> %d" % [made, DJFx.of(m).made])
	await _dancer_dash_flow(m, P, K, T, home)
	await DFEEL.new().run(A, m, P, K, T, home)
	DPARITY.new().run(A, m, P, K, T, home)
	DLOOP.new().run(A, m, P, K, T, T2, home)
	await A.done(m)
	await _growth()
	await ULT.new().dancer(A)


## Rings in Sable's own colours alive now (the shared team-colour dash ring is Hunter's, not hers).
func _dancer_rings(m: Match) -> int:
	var res_col := Color(Arch.def("thief")["resource"]["col"])
	var cols := [ThiefKit.AIM_LILAC, ThiefKit.EMP_LINE, Arch.color("thief"), res_col]
	var n := 0
	for rg in m.fx.rings:
		for c in cols:
			if (rg["col"] as Color).is_equal_approx(c): n += 1
	return n

## Item 35: her dash moves are her own (no other table has them) and fit inside their dashes.
func _dancer_dash_moves(K: ThiefKit) -> void:
	var dd: Dictionary = Arch.def("thief")["dash"]
	var feel_t := float(K.dash_feel()["time"])
	var others := [HunterAnim.KMOVES, KMovesPair.MOVES, KMovesVV.MOVES, KMovesStone.MOVES, MergeMoves.MOVES,
			KMovesCare.MOVES, KMovesPinBjorn.MOVES]
	var own := true
	for mv in ThiefKit.CARTWHEELS:
		own = own and KMovesDJ.MOVES.has(mv) and others.all(func(t): return not (t as Dictionary).has(mv))
	var ground_len := maxf(_move_len("thf_vault_r"), _move_len("thf_vault_l"))
	var air_len := _move_len("thf_exdash")
	A.ok("dancer dash moves (item 35): her own ids; the ground and air cartwheels fit inside their dashes",
			own and ground_len <= float(dd["time"]) * feel_t + 0.005 and air_len <= float(dd["air_time"]) * feel_t,
			"ground %.2f / %.2f air %.2f / %.2f" % [ground_len, float(dd["time"]) * feel_t, air_len,
					float(dd["air_time"]) * feel_t])

func _move_len(mv: String) -> float:
	var keys: Array = KMovesDJ.MOVES[mv]["keys"]
	return float(keys[-1][0])

## Item 32: a bolt pressed mid-cartwheel goes at once, empowered, and the cartwheel isn't cut; Shift in the Bola's
## wind-up cartwheels and the Bola still flies; the dagger's blink ends a cartwheel.
func _dancer_dash_flow(m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	K.primed_t = 0.0
	K.haste_t = 0.0
	A.step(m, 0.3)
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(-6.0, 0, 0))
	A.aim_at(P, T.pos)
	P.dashes = P.max_dashes()
	P.fire_cd = 0.0
	var bolts0 := K.bolts
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	A.step(m, 0.08)
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.ok("dancer dash -> LMB (row: fire, empowered): the bolt leaves mid-flip, empowered; the cartwheel plays on",
			K.bolts == bolts0 + 1 and K.last_bolt_emp and P.roll_t > 0.0 and K.anim_id in ThiefKit.CARTWHEELS,
			"bolts %d emp %s roll %.2f anim %s" % [K.bolts - bolts0, K.last_bolt_emp, P.roll_t, K.anim_id])
	A.step(m, 0.6)
	P.inp["move"] = Vector2.ZERO
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	P.dashes = P.max_dashes()
	A.tap(m, P)
	A.step(m, 0.1)
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	var wound := not K.bola_cast.is_empty() and P.roll_t > 0.0
	var thrown := [false]
	A.step(m, 0.4, func(): thrown[0] = thrown[0] or not K.bola.is_empty())
	P.inp["move"] = Vector2.ZERO
	A.ok("dancer RMB -> dash (into_dash row: fire): Shift in the wind-up cartwheels, the Bola still flies",
			wound and thrown[0], "wound %s thrown %s" % [wound, thrown[0]])
	A.step(m, 1.0)
	P.teleport(home)
	K.cd["e"] = 0.0
	A.aim_at(P, home + Vector3(4.0, 0, -2.0))
	K.use_e()
	A.step(m, 0.4)
	var blinks0 := K.blinks
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	A.step(m, 0.06)
	K.use_e()
	m.step(A.DT)
	P.inp["move"] = Vector2.ZERO
	A.ok("dancer dash -> E recast: the blink ends the cartwheel (she arrives standing)",
			K.blinks == blinks0 + 1 and P.roll_t <= 0.0 and K.vault.is_empty(),
			"blinks +%d roll %.2f vault %s" % [K.blinks - blinks0, P.roll_t, K.vault])
	K.primed_t = 0.0
	K.haste_t = 0.0
	A.step(m, 0.5)

## An Encore blade's damage on the first foe with the hunter at level `lvl`.
func _blade(lvl: int) -> float:
	var r = A.setup("thief", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: ThiefKit = P.ak
	P.lvl = lvl
	P.set_meta("growth_lvl", lvl)       # growth follows levels gained; a level set straight grows nothing
	A.fresh(T)
	K.encore._hit(T, false)
	var d: float = A.dmg(T)
	await A.done(m)
	return d

## Ability damage reads ArchKit.power(), so quiet level growth (LevelGrowth.ap) raises it.
func _growth() -> void:
	var d1: float = await _blade(1)
	var d10: float = await _blade(10)
	A.ok("dancer Encore: a blade grows with level (LevelGrowth.ap 1.0 -> %.2f)" % (1.0 + LevelGrowth.ap_pct(10)),
			d1 >= 3.9 and absf(d10 / d1 - (1.0 + LevelGrowth.ap_pct(10))) < 0.01, "L1 %.2f L10 %.2f" % [d1, d10])


# ------------------------------------------------------------------ Juggernaut
func juggernaut(a) -> void:
	A = a
	var r := A.setup("juggernaut", 2.4)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: JuggernautKit = P.ak
	P.slot_lv["dash"] = 1
	var charges_r1 := P.max_dashes()
	P.slot_lv["dash"] = 2
	var charges_r2 := P.max_dashes()
	P.slot_lv["dash"] = 1
	A.ok("juggernaut: greatsword, 2 Rampage charges at rank 1 and 3 at rank 2",
			P.wid == "greatsword" and charges_r1 == 2.0 and charges_r2 == 3.0,
			"%s %.0f %.0f" % [P.wid, charges_r1, charges_r2])
	var smash_ks: Array = []
	var chain_ks: Array = []
	for rk in [1, 2, 3]:
		P.slot_lv["sec"] = rk
		P.slot_lv["kin"] = rk
		smash_ks.append(K.smash_k())
		chain_ks.append(K.cd_k("kin"))
	P.slot_lv["sec"] = 1
	var air_r1 := K.air_cooldown()
	P.slot_lv["sec"] = 3
	var air_r3 := K.air_cooldown()
	P.slot_lv["sec"] = 1
	P.slot_lv["kin"] = 1
	A.ok("juggernaut ranks: Smash +20% at rank 2 and 3, Warchain cooldown -12.5% / -37.5%, Meteor Drop 7.2s -> 4.8s",
			absf(float(smash_ks[0]) - 1.0) < 0.001 and absf(float(smash_ks[1]) - 1.2) < 0.001
			and absf(float(smash_ks[2]) - 1.4) < 0.001 and absf(float(chain_ks[1]) - 0.875) < 0.001
			and absf(float(chain_ks[2]) - 0.625) < 0.001 and absf(air_r1 - 7.2) < 0.001 and absf(air_r3 - 4.8) < 0.001,
			"%s %s %.1f %.1f" % [smash_ks, chain_ks, air_r1, air_r3])
	# Rage (Blazing Spirit): damage fills it; nothing below full; Enraged gives damage, dash and ability haste
	K.res = 0.0
	K.enraged_t = 0.0
	K.on_deal(T, 40.0, {"src": "shot"})
	A.ok("juggernaut passive: damage fills Rage", K.res > 25.0 and K.res < 31.0, "rage %.1f" % K.res)
	A.ok("juggernaut passive: no bonus below full", absf(K.outgoing(T, 100.0, {}) - 100.0) < 0.1)
	K.gain_rage(100.0)
	A.ok("juggernaut passive: full = Enraged (+15%)",
			K.enraged_t > 0.0 and absf(K.outgoing(T, 100.0, {}) - 115.0) < 0.1 and K.ready_label() == "ENRAGED",
			"%.1f" % K.outgoing(T, 100.0, {}))
	K.cd["e"] = 10.0
	P.dashes = 0.0
	A.step(m, 1.0)
	A.ok("juggernaut Enraged: ability + dash haste",
			float(K.cd["e"]) < 8.85 and P.dashes > 1.0 / P.dash_regen() * 1.08,
			"e cd %.2f dashes %.3f" % [float(K.cd["e"]), P.dashes])
	K.enraged_t = 0.0
	K.res = 0.0
	K.cd["e"] = 0.0
	# LMB: quick slashes, double at the tip; hold for a Searing Wave
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(1.3, 0, 0))
	A.aim_at(P, T.pos)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.step(m, 0.3)
	var near := A.dmg(T)
	A.fresh(T)
	T.teleport(home + Vector3(2.95, 0, 0))
	A.aim_at(P, T.pos)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.step(m, 0.3)
	A.ok("juggernaut LMB tap: a slash, 1.6x at the tip (the footage's 151 / 94)",
			near >= 7.0 and A.dmg(T) >= near * 1.5 and K.waves == 0, "near %.0f tip %.0f" % [near, A.dmg(T)])
	A.fresh(T)
	T.teleport(home + Vector3(7.0, 0, 0))
	A.aim_at(P, T.pos)
	P.fire_cd = 0.0
	K.res = 0.0
	A.step(m, 0.5, func(): P.inp["fire"] = true)
	var midk := K.wave_k()
	A.step(m, 0.6, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	A.step(m, 0.6)
	A.ok("juggernaut LMB hold: Searing Wave (ranged, fills Rage fast)",
			K.waves == 1 and midk > 0.2 and A.dmg(T) >= 20.0 and T.slow_t > 0.0 and K.res > 45.0,
			"mid %.2f took %.0f rage %.0f" % [midk, A.dmg(T), K.res])
	K.res = 0.0
	# RMB tap: the Finishing Slam winds up (aim it), then hits; +50% under 35%; its sweet spot is the payoff
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(2.6, 0, 0))
	A.aim_at(P, T.pos)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	A.tap(m, P)
	var early := A.dmg(T)
	var winding := not K.slam_w.is_empty()
	A.step(m, 0.3)
	var lane: Dictionary = AimKit.entry(P, "slam")
	A.ok("juggernaut RMB tap: the strike lane shows through the wind-up (everyone sees it)",
			AimKit.shown(P, "slam") and bool(lane.get("all", false)) and absf(float(lane.get("len", 0.0)) - 4.0) < 0.1,
			str(lane.get("len", -1)))
	A.step(m, 0.4)
	A.ok("juggernaut RMB tap: Finishing Slam winds up, then lands",
			winding and early <= 0.0 and A.dmg(T) >= 24.0 and K.last_variant == "tap", "took %.0f" % A.dmg(T))
	A.ok("juggernaut RMB: the Slam marks the foe it hits for the Riposte reset",
			K.sweet_spots == 1 and K.slam_hit.has(T.get_instance_id()), "spots %d" % K.sweet_spots)
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(1.2, 0, 0))
	A.aim_at(P, T.pos)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	T.hp = T.max_hp * 0.3
	var hp0 := T.hp
	m.step(A.DT)
	A.ok("juggernaut RMB ready: the wounded (under 35%) are outlined red",
			AimKit.shown(P, "exec%d" % T.get_instance_id()))
	A.tap(m, P)
	A.step(m, 0.7)
	A.ok("juggernaut RMB tap: +50% under 35%, no sweet spot up close",
			hp0 - T.hp >= 36.0 and K.sweet_spots == 1, "dealt %.0f spots %d" % [hp0 - T.hp, K.sweet_spots])
	A.ok("juggernaut RMB: short cooldown (2s)",
			float(K.cd["rmb"]) <= 2.0 and float(K.cd["rmb"]) > 1.0, "%.2f" % float(K.cd["rmb"]))
	# hold: the charged Lunge into the first foe; a miss doubles the cooldown
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(5.0, 0, 0))
	A.aim_at(P, T.pos)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	A.step(m, 0.5, func(): P.inp["sec_hold"] = true)
	var ln: Dictionary = AimKit.entry(P, "rmb")
	var k_mid := float(ln.get("fill", -1.0))
	A.ok("juggernaut RMB hold: the lane grows with the charge (and the wind-up pose plays)",
			AimKit.shown(P, "rmb") and k_mid > 0.2 and k_mid < 1.0 and K.anim_id == "jug_lunge_wind"
			and not K.lunge_full,
			"k %.2f anim %s" % [k_mid, K.anim_id])
	P.do_jump()
	m.step(A.DT)
	A.ok("juggernaut RMB hold: you can jump while holding", P.vel.y > 0.5 and K.rmb_down, "vy %.1f" % P.vel.y)
	A.step(m, 0.35, func(): P.inp["sec_hold"] = true)
	A.ok("juggernaut RMB hold: full charge flashes (lane full, the cursor flare)",
			K.lunge_full and float(AimKit.entry(P, "rmb").get("fill", 0.0)) >= 1.0
			and float(AimKit.reticle(P)["flare"]) > 0.0,
			"full %s" % K.lunge_full)
	P.inp["sec_hold"] = false
	m.step(A.DT)
	A.step(m, 0.5)
	A.ok("juggernaut RMB hold: release flings you forward into them",
			K.last_variant == "hold" and A.dmg(T) >= 18.0 and P.flat_dist(home) > 3.5,
			"took %.0f moved %.1f" % [A.dmg(T), P.flat_dist(home)])
	A.step(m, 3.2)
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(0, 0, 6.0))
	A.aim_at(P, home + Vector3(6.0, 0, 0))
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	A.hold(m, P, 0.95)
	A.step(m, 0.5)
	var far := 7.5 * float(K.dash_feel()["dist"])       # the full fling, after the global dash feel
	A.ok("juggernaut RMB hold: a miss doubles the cooldown, the fling goes far",
			float(K.cd["rmb"]) > 3.0 and P.flat_dist(home) > far - 0.4,
			"cd %.1f moved %.1f" % [float(K.cd["rmb"]), P.flat_dist(home)])
	# air: the downward slam slows, the centre takes more and is stunned
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	P.teleport(T.pos + Vector3(-4.0, 3.0, 0))
	P.grounded = false
	A.fresh(T)
	A.aim_at(P, T.pos)
	m.step(A.DT)
	A.ok("juggernaut air: the landing disc shows under the cursor while the Smash is ready",
			AimKit.shown(P, "drop_aim")
			and Vector2(float(AimKit.entry(P, "drop_aim")["at"].x) - T.pos.x,
					float(AimKit.entry(P, "drop_aim")["at"].y) - T.pos.z).length() < 0.6)
	P.ak.press_rmb()
	var disc := AimKit.shown(P, "drop") and bool(AimKit.entry(P, "drop").get("all", false))
	A.step(m, 1.1)
	var off := Vector2(K.meteor.last_drop.x - T.pos.x, K.meteor.last_drop.z - T.pos.z).length()
	A.ok("juggernaut RMB air: Meteor Drop lands at the cursor (disc everyone sees)",
			disc and K.meteor.drops == 1 and off < 1.0, "landed %.1f from the cursor" % off)
	A.ok("juggernaut RMB air: Meteor Drop slows, centre stunned",
			K.last_variant == "air" and A.dmg(T) >= 24.0 and T.slow_t > 0.0 and T.stun_t > 0.0,
			"took %.0f slow %.2f stun %.2f" % [A.dmg(T), T.slow_t, T.stun_t])
	A.ok("juggernaut Meteor Drop: its own 7.2s slot, the Smash charge untouched",
			float(K.cd["air"]) > 6.0 and float(K.cd["air"]) <= 7.2 and K.ch_rmb >= 1.0 and float(K.cd["rmb"]) <= 0.0,
			"air cd %.2f smash charge %.1f cd %.2f" % [float(K.cd["air"]), K.ch_rmb, float(K.cd["rmb"])])
	P.teleport(T.pos + Vector3(-4.0, 3.0, 0))
	P.grounded = false
	A.aim_at(P, T.pos)
	P.ak.press_rmb()
	A.step(m, 0.2)
	A.ok("juggernaut Meteor Drop: a second one is denied while its slot rests", K.meteor.drops == 1,
			"drops %d" % K.meteor.drops)
	K.cd["air"] = 0.0
	K.ch_rmb = 0.0
	K.cd["rmb"] = 2.0
	P.teleport(T.pos + Vector3(-4.0, 3.0, 0))
	P.grounded = false
	A.aim_at(P, T.pos)
	P.ak.press_rmb()
	A.step(m, 1.1)
	A.ok("juggernaut Meteor Drop: it fires with the Smash resting (usable right after a ground Smash)",
			K.meteor.drops == 2 and K.ch_rmb < 1.0 and float(K.cd["air"]) > 6.0,
			"drops %d air cd %.2f" % [K.meteor.drops, float(K.cd["air"])])
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	K.cd["air"] = 0.0
	# Rampage (Flame Step): a dash attack, aimed like any dash (ArchKit.dash_dir: WASD by default); the tip
	# hits double; rank 2 adds a charge
	A.step(m, 1.0)
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(3.5, 0, 0))
	A.aim_at(P, T.pos)
	P.dashes = 3.0
	P.inp["move"] = Vector2(1, 0)        # (toward the target: the dash follows the dash setting)
	P.do_dash()
	A.step(m, 0.5)
	P.inp["move"] = Vector2.ZERO
	A.ok("juggernaut dash: Rampage the way you dash, tip hits",
			K.tips >= 1 and A.dmg(T) >= 14.0 and P.dashes < 2.5,
			"tips %d took %.0f dashes %.2f" % [K.tips, A.dmg(T), P.dashes])
	A.ok("juggernaut dash: the tip does not stun into a wall", T.wallstun <= 0.0, "wallstun %.2f" % T.wallstun)
	# rank 3: a shot dodged through the dash feeds Rage (through the real dodge hook); rank 1 does not
	K.res = 0.0
	K.on_perfect_dodge()
	var rage_r1 := K.res
	P.slot_lv["dash"] = 3
	K.res = 0.0
	P.dodged = false
	P.inv_t = 0.3
	P.dash_at = m.time
	P.hurt(10.0, T, {"src": "shot"})
	A.ok("juggernaut dash rank 3: a dodged shot builds Rage (15), rank 1 does not",
			rage_r1 <= 0.01 and absf(K.res - 15.0) < 0.5, "r1 %.1f r3 %.1f" % [rage_r1, K.res])
	P.inv_t = 0.0
	P.slot_lv["dash"] = 1
	# E: the Warchain hooks a foe (blight); its cooldown waits for the pull; a Smash in the pull spins
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(6.0, 0, 0))
	A.aim_at(P, T.pos)
	K.cd["e"] = 0.0
	P.ak.use_e()
	A.step(m, 0.3)
	A.ok("juggernaut E: Warchain hooks (no blight: the data puts Anti-Heal on the spin), cooldown waits",
			K.warchain.hooked() and K.warchain.target == T and T.blight_t <= 0.0 and A.dmg(T) >= 7.0
			and float(K.cd["e"]) <= 0.0,
			"blight %.1f cd %.1f" % [T.blight_t, float(K.cd["e"])])
	P.ak.use_e()
	A.step(m, 0.08)
	A.ok("juggernaut E recast: the pull starts the cooldown",
			K.warchain.reels == 1 and float(K.cd["e"]) > 5.0 and K.in_e(), "cd %.1f" % float(K.cd["e"]))
	A.step(m, 0.12)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	A.aim_at(P, T.pos)
	A.tap(m, P)
	A.step(m, 0.2)
	A.ok("juggernaut RMB during the pull: Cinder Spin (blight)",
			K.spins == 1 and K.last_variant == "during_e" and A.dmg(T) >= 20.0,
			"spins %d variant %s took %.0f" % [K.spins, K.last_variant, A.dmg(T)])
	# rooted: no chain; a stun breaks a chain
	A.step(m, 0.5)
	K.cd["e"] = 0.0
	P.root_t = 1.0
	P.ak.use_e()
	A.ok("juggernaut E: can't throw it rooted", K.warchain.state == "ready")
	P.root_t = 0.0
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(6.0, 0, 0))
	A.aim_at(P, T.pos)
	P.ak.use_e()
	A.step(m, 0.3)
	P.stun_t = 0.3
	A.step(m, 0.05)
	A.ok("juggernaut E: a stun breaks the chain", K.warchain.state != "hooked" and float(K.cd["e"]) > 5.0)
	A.step(m, 0.4)
	# ... or bites a wall and pulls you to it
	var W = m.world
	for dz in range(-3, 4):
		for dx in range(7, 9):
			W.level[W.idx(int(home.x) + dx, int(home.z) + dz)] = lv + 3
	P.teleport(home)
	T.teleport(home + Vector3(0, 0, 5.0))
	K.cd["e"] = 0.0
	A.aim_at(P, home + Vector3(8.0, 0, 0))
	P.ak.use_e()
	A.step(m, 0.35)
	var anchored: bool = K.warchain.hooked() and K.warchain.target == null
	P.ak.use_e()
	A.step(m, 0.45)
	A.ok("juggernaut E: chain a wall, pull yourself to it",
			anchored and P.flat_dist(home) > 4.0, "anchored %s moved %.1f" % [anchored, P.flat_dist(home)])
	var straight := P.pos
	# small mechanic (the owner's example): sideways input steers the pull, the arrival moves aside
	A.step(m, 0.5)
	P.teleport(home)
	K.cd["e"] = 0.0
	A.aim_at(P, home + Vector3(8.0, 0, 0))
	P.ak.use_e()
	A.step(m, 0.35)
	P.ak.use_e()
	A.step(m, 0.45, func(): P.inp["move"] = Vector2(0, 1))
	P.inp["move"] = Vector2.ZERO
	var side_off := absf(P.pos.z - straight.z)
	A.ok("juggernaut Warchain small mechanic: sideways input shifts the arrival by at least 1.5m",
			side_off >= 1.5, "%.2f m aside" % side_off)
	# the source's Execution Slam: knock a foe within 2s of its sweet spot and the ultimate (X) is ready again
	P.lvl = maxi(P.lvl, 6)
	P.slot_lv["ult"] = 1
	A.step(m, 2.5)
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(2.6, 0, 0))
	A.aim_at(P, T.pos)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	K.cd["x"] = 15.0
	A.tap(m, P)
	A.step(m, 0.9)
	T.hp = 4.0
	P.hp = 1.0
	T.hurt(10.0, P, {"src": "shot"})
	A.step(m, 0.1)
	A.ok("juggernaut Smash small mechanic: a knock after the sweet spot resets the Gilded Riposte",
			T.downed and K.slam_resets == 1 and float(K.cd["x"]) <= 0.0 and K.knock_healed > 0.0,
			"x cd %.1f resets %d" % [float(K.cd["x"]), K.slam_resets])
	A.ok("juggernaut passive: a knock heals 20% of their health",
			K.knock_healed >= minf(0.19 * T.max_hp, 0.9 * P.max_hp), "healed %.0f of %.0f" % [K.knock_healed, T.max_hp])
	# audit (data: "knocking an enemy resets Volcanic Rebuke"): a plain body hit then a knock resets it too
	A.step(m, 1.0)
	T.downed = false
	T.dead = false
	T.out = false
	A.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(1.4, 0, 0))
	A.aim_at(P, T.pos)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	K.cd["x"] = 15.0
	var spots0 := K.sweet_spots
	var resets0 := K.slam_resets
	A.tap(m, P)
	A.step(m, 0.9)
	T.hp = 4.0
	T.hurt(10.0, P, {"src": "shot"})
	A.step(m, 0.1)
	A.ok("juggernaut Smash: a knock after any Slam hit (not the sweet spot) resets the Gilded Riposte",
			K.sweet_spots == spots0 and K.slam_resets == resets0 + 1 and float(K.cd["x"]) <= 0.0,
			"spots +%d resets +%d" % [K.sweet_spots - spots0, K.slam_resets - resets0])
	await A.done(m)
	await ZFEEL.new().run(A)
	await ULT.new().zedran(A)


# ------------------------------------------------------------------ cross-ability combinations (--kit-combo-check)

# ------------------------------------------------------------------ combinations (--kit-combo-check)
func combos(a) -> void:
	A = a
	# ---- Juggernaut
	var r := A.setup("juggernaut", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: JuggernautKit = P.ak
	var hook := func():
		P.teleport(home)
		A.fresh(T)
		T.teleport(home + Vector3(6.0, 0, 0))
		A.aim_at(P, T.pos)
		K.cd["e"] = 0.0
		K.ch_rmb = 1.0
		K.cd["rmb"] = 0.0
		K.haul = {}
		P.ak.use_e()
		A.step(m, 0.3)
	# E, E, then RMB tap in the pull: Cinder Spin
	hook.call()
	P.ak.use_e()
	var wait := 0.0
	while K.warchain.pulling() and wait < 1.0:      # (the spin's blight lands on who it hits: wait to be close)
		m.step(A.DT)
		wait += A.DT
	A.tap(m, P)
	A.step(m, 0.3)
	A.ok("combo jug: E > E > RMB tap = Cinder Spin (it blights who it hits)",
			K.spins == 1 and K.last_variant == "during_e" and T.blight_t > 0.0,
			"spins %d variant %s" % [K.spins, K.last_variant])
	A.ok("combo jug: the spin's Anti-Heal lasts 5s (wiki: Scorching Spin) and cuts healing 60%",
			T.blight_t > 4.5 and T.blight_t <= 5.0 and is_equal_approx(T.blight_k, 0.6),
			"blight %.2f k %.2f" % [T.blight_t, T.blight_k])
	Sfx.listener = P.pos      # (the body looks draw near the camera focus; no camera runs here)
	var tags := HudPlate.statuses(T).map(func(s): return s[2])
	A.ok("combo jug: Anti-Heal shows one icon on the plate and one body look (streaks)",
			tags.count("ANTI-HEAL") == 1 and StatusLooks.of(m).showing(T, "antiheal"), str(tags))
	# E, then RMB held and let go while attached: Chain Lunge along it
	A.step(m, 1.0)
	hook.call()
	var hp0 := A.dmg(T)
	A.hold(m, P, 0.95)
	A.step(m, 0.4)
	A.ok("combo jug: E > hold RMB = Chain Lunge",
			K.chain_lunges == 1 and K.warchain.state != "hooked" and A.dmg(T) - hp0 >= 18.0 and T.stun_t > 0.0
			and P.flat_dist(T) < 3.4,
			"lunges %d dist %.1f took %.0f" % [K.chain_lunges, P.flat_dist(T), A.dmg(T) - hp0])
	# E, hold RMB, then E while still holding: pulled in, Haul Slam on arrival
	A.step(m, 1.0)
	hook.call()
	hp0 = A.dmg(T)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	A.step(m, 0.5, func(): P.inp["sec_hold"] = true)
	P.ak.use_e()
	P.inp["sec_hold"] = false
	A.step(m, 0.45)
	A.ok("combo jug: E > hold RMB > E = Haul Slam on arrival",
			K.haul_slams == 1 and A.dmg(T) - hp0 >= 16.0 and T.stun_t > 0.0 and K.chain_lunges == 1,
			"slams %d took %.0f stun %.2f" % [K.haul_slams, A.dmg(T) - hp0, T.stun_t])
	# E, E, then RMB pressed (and held) in the pull: the Cinder Spin goes on the press, no Haul Slam
	A.step(m, 1.0)
	hook.call()
	P.ak.use_e()
	A.step(m, 0.04)
	var spins0 := K.spins
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	var spun_on_press := K.spins == spins0 + 1
	A.step(m, 0.4, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	A.step(m, 0.3)
	A.ok("combo jug: E > E > hold RMB = Cinder Spin on the press (no Haul Slam, no second move)",
			spun_on_press and K.spins == spins0 + 1 and K.haul_slams == 1,
			"spins %d slams %d" % [K.spins, K.haul_slams])
	# E attached, RMB tapped (not pulling): a normal Finishing Slam
	A.step(m, 1.0)
	hook.call()
	A.tap(m, P)
	A.ok("combo jug: E > RMB tap = Finishing Slam", not K.slam_w.is_empty() and K.last_variant == "tap")
	A.ok("combo jug: the attached Warchain draws as a link chain",
			is_instance_valid(DJFx.of(m).chains.get("war%d" % P.get_instance_id(), {}).get("node"))
			and (DJFx.of(m).chains["war%d" % P.get_instance_id()]["node"] as Node3D).visible)
	A.step(m, 0.8)
	# the Finishing Slam's sweet spot, then a knock within 2s: the Riposte (X) is ready again, a heal, a dash back
	P.lvl = maxi(P.lvl, 6)
	P.slot_lv["ult"] = 1
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(2.6, 0, 0))
	A.aim_at(P, T.pos)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	K.cd["x"] = 15.0
	A.tap(m, P)
	A.step(m, 0.8)
	P.dashes = 0.0
	var rs := K.slam_resets
	T.hp = 4.0
	T.hurt(10.0, P, {"src": "shot"})
	A.step(m, 0.05)
	A.ok("combo jug: RMB sweet spot > knock = Riposte reset + heal + a dash",
			K.slam_resets == rs + 1 and float(K.cd["x"]) <= 0.0 and K.knock_healed > 0.0 and P.dashes >= 0.99,
			"dashes %.2f" % P.dashes)
	await A.done(m)
	r = A.setup("juggernaut", 6.0)
	m = r[0]
	P = r[1]
	T = r[2]
	home = r[4]
	lv = r[5]
	K = P.ak
	# a Lunge that strikes nothing doubles the Smash cooldown
	A.aim_at(P, home + Vector3(0, 0, 6.0))
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	A.hold(m, P, 0.95)
	A.step(m, 0.5)
	A.ok("combo jug: RMB hold miss = cooldown x2", float(K.cd["rmb"]) > 3.0, "%.1f" % float(K.cd["rmb"]))
	# a dash or a lunge winds down: no glider straight out of it
	P.dashes = 2.0
	A.aim_at(P, home + Vector3(6.0, 0, 0))
	P.do_dash()
	A.step(m, 0.05)
	A.ok("combo jug: Rampage winds down (no instant glide)", P.glide_cd > 0.2, "%.2f" % P.glide_cd)
	# rooted: no chain; a stun breaks it; Enraged speeds every cooldown
	A.step(m, 1.0)
	K.cd["e"] = 0.0
	P.root_t = 1.0
	P.ak.use_e()
	A.ok("combo jug: rooted = no Warchain", K.warchain.state == "ready")
	P.root_t = 0.0
	KitStatus.apply(P, "gnd", 1.0)
	P.ak.use_e()
	A.ok("combo jug: Grounded = no Warchain", K.warchain.state == "ready")
	A.step(m, 1.1)
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(6.0, 0, 0))
	A.aim_at(P, T.pos)
	P.ak.use_e()
	A.step(m, 0.3)
	P.stun_t = 0.3
	A.step(m, 0.05)
	A.ok("combo jug: stun breaks the Warchain", K.warchain.state != "hooked" and float(K.cd["e"]) > 5.0)
	A.step(m, 0.4)
	K.gain_rage(100.0)
	K.cd["rmb"] = 3.0
	A.step(m, 1.0)
	A.ok("combo jug: Enraged hastes the Smash", float(K.cd["rmb"]) < 1.85, "%.2f" % float(K.cd["rmb"]))
	await A.done(m)
	# ---- Sable
	r = A.setup("thief", 4.0, "", true)
	m = r[0]
	P = r[1]
	T = r[2]
	var T2: Hunter = r[3]
	home = r[4]
	var TK: ThiefKit = P.ak
	# Vault > empowered bolt hits: Vault reset, speed ends
	P.dashes = P.max_dashes()
	A.aim_at(P, T.pos)
	P.inp["move"] = Vector2(0, 1 if TK.primed_hits % 2 == 0 else -1)
	P.do_dash()
	A.step(m, 0.55)
	P.inp["move"] = Vector2.ZERO
	A.aim_at(P, T.pos)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.step(m, 0.4)
	A.ok("combo dancer: Vault > bolt = empowered hit + Vault reset",
			TK.primed_hits == 1 and P.dashes >= P.max_dashes() - 0.01 and TK.haste_t <= 0.0)
	# the loop: Vault again at once, empowered again, about 1.4s a loop while the hits land
	P.inp["move"] = Vector2(0, 1 if TK.primed_hits % 2 == 0 else -1)
	P.do_dash()
	A.step(m, 0.55)
	P.inp["move"] = Vector2.ZERO
	A.aim_at(P, T.pos)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.step(m, 0.4)
	A.ok("combo dancer: the reset loop (Vault > bolt > Vault > bolt)",
			TK.primed_hits == 2 and P.dashes >= P.max_dashes() - 0.01)
	# an empowered bolt that misses is spent (no reset)
	P.inp["move"] = Vector2(0, 1 if TK.primed_hits % 2 == 0 else -1)
	P.do_dash()
	A.step(m, 0.55)
	P.inp["move"] = Vector2.ZERO
	A.aim_at(P, home + Vector3(0, 0, -5.0))
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.step(m, 0.5)
	A.ok("combo dancer: an empowered bolt that misses is spent",
			TK.primed_hits == 2 and TK.primed_t <= 0.0 and P.dashes < P.max_dashes() - 0.5)
	# Knife into a foe: the Vault comes back with the Knife's rank 3, not Vault's
	P.slot_lv["dash"] = 3
	P.slot_lv["kin"] = 2
	P.teleport(home)
	A.fresh(T)
	T2.teleport(home + Vector3(0, 0, 9.0))
	A.aim_at(P, T.pos)
	P.dashes = 0.0
	TK.cd["e"] = 0.0
	P.ak.use_e()
	A.step(m, 0.35)
	A.ok("combo dancer: Knife in a foe at rank 2 (Vault rank 3) gives no Vault back",
			P.dashes < 0.99, "dashes %.2f" % P.dashes)
	P.ak.use_e()
	A.step(m, 0.3)
	P.slot_lv["dash"] = 1
	P.slot_lv["kin"] = 3
	P.teleport(home)
	A.fresh(T)
	T2.teleport(home + Vector3(0, 0, 9.0))
	A.aim_at(P, T.pos)
	P.dashes = 0.0
	TK.cd["e"] = 0.0
	P.ak.use_e()
	A.step(m, 0.35)
	A.ok("combo dancer: Knife in a foe (Knife rank 3) = Vault reset + refund",
			P.dashes >= 0.99 and float(TK.cd["e"]) < 10.0, "dashes %.2f e cd %.1f" % [P.dashes, float(TK.cd["e"])])
	P.ak.use_e()
	A.step(m, 0.05)
	A.ok("combo dancer: Knife > E = step to them", P.flat_dist(T) < 1.8)
	# Bola into two at rank 3: their Marks pool
	P.slot_lv["sec"] = 3
	P.teleport(home)
	A.fresh(T)
	A.fresh(T2)
	T.teleport(home + Vector3(4.0, 0, 0))
	T2.teleport(home + Vector3(7.0, 0, 0))
	A.aim_at(P, T.pos)
	TK.add_mark(T2, 3, true)
	TK.ch_rmb = 1.0
	TK.cd["rmb"] = 0.0
	A.tap(m, P)
	A.step(m, 0.9)
	A.ok("combo dancer: Bola on two (rank 3) = pooled Marks",
			TK.bola_pairs >= 1 and TK.marks_on(T) >= 4 and TK.marks_on(T) == TK.marks_on(T2),
			"T %d T2 %d" % [TK.marks_on(T), TK.marks_on(T2)])
	A.ok("combo dancer: Bola > Grounded = no dash", KitStatus.grounded(T) and _dash_blocked(T))
	A.step(m, 2.0)
	await A.done(m)
	await ULT.new().combos(A)
	await merge_holds()

## True when a dash attempt leaves `t` with the dashes it had (Grounded blocks the dash).
func _dash_blocked(t: Hunter) -> bool:
	var d0 := t.dashes
	t.stun_t = 0.0
	t.do_dash()
	return t.dashes == d0

## A Boki merge starting mid-hold: nothing the hunter was holding or winding up fires, and none of it is left
## behind for when the merge ends (ArchKit.drop_holds: the kits' _drop_holds, then AimKit.clear).
func merge_holds() -> void:
	# ---- Juggernaut: the Searing Wave charge (LMB held)
	var r := A.setup("juggernaut", 6.0, "cindle")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: JuggernautKit = P.ak
	P.ult = 1.0
	P.merge_cd = 0.0
	A.step(m, 0.7, func(): P.inp["fire"] = true)
	A.ok("merge hold jug: the Searing Wave is charging", K.lmb_t > 0.3 and P.mel_hold > 0.0, "lmb_t %.2f" % K.lmb_t)
	var w0 := K.waves
	A.ok("merge hold jug: the merge starts", KinMerge.cast(P) and KinMerge.active(P))
	A.step(m, 0.6, func(): P.inp["fire"] = false)
	A.ok("merge hold jug: the charged wave does not fire",
			K.waves == w0 and A.dmg(T) <= 0.0, "waves %d took %.0f" % [K.waves - w0, A.dmg(T)])
	A.ok("merge hold jug: no charge left behind",
			K.lmb_t < 0.0 and K.lmb_buf <= 0.0 and P.mel_hold <= 0.0, "lmb_t %.2f" % K.lmb_t)
	await A.done(m)
	# the Finishing Slam winding up
	# (a control first: what the merge's own transformation does to a foe this close, with no slam)
	r = A.setup("juggernaut", 2.6, "cindle")
	m = r[0]
	P = r[1]
	T = r[2]
	P.ult = 1.0
	P.merge_cd = 0.0
	KinMerge.cast(P)
	A.step(m, 1.0)
	var ctl := A.dmg(T)
	await A.done(m)
	r = A.setup("juggernaut", 2.6, "cindle")
	m = r[0]
	P = r[1]
	T = r[2]
	K = P.ak
	P.ult = 1.0
	P.merge_cd = 0.0
	A.aim_at(P, T.pos)
	A.tap(m, P)
	A.ok("merge hold jug: the Finishing Slam is winding up", not K.slam_w.is_empty())
	KinMerge.cast(P)
	A.step(m, 1.0)
	A.ok("merge hold jug: the wound-up slam does not land",
			K.slam_w.is_empty() and K.sweet_spots == 0 and A.dmg(T) <= ctl + 0.5,
			"took %.0f (merge alone %.0f)" % [A.dmg(T), ctl])
	await A.done(m)
	# the Smash held (the Lunge charge), and a Haul Slam armed for the end of a pull
	r = A.setup("juggernaut", 6.0, "cindle")
	m = r[0]
	P = r[1]
	T = r[2]
	K = P.ak
	P.ult = 1.0
	P.merge_cd = 0.0
	A.aim_at(P, T.pos)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	A.step(m, 0.6, func(): P.inp["sec_hold"] = true)
	A.ok("merge hold jug: the Lunge is charging", K.rmb_down and K.rmb_t > 0.3)
	K.haul = {"k": 1.0}
	var chg := K.ch_rmb
	KinMerge.cast(P)
	P.inp["sec_hold"] = false
	A.step(m, 0.6)
	A.ok("merge hold jug: the charged Lunge does not go and no Smash charge is spent",
			K.lunge.is_empty() and not K.rmb_down and K.ch_rmb >= chg, "charges %.1f of %.1f" % [K.ch_rmb, chg])
	A.ok("merge hold jug: an armed Haul Slam is dropped", K.haul.is_empty() and K.haul_slams == 0)
	await A.done(m)
	# ---- Sable: the Bola's wind-up stops when a merge starts (a running Encore: tools/dj_ult_check.gd)
	r = A.setup("thief", 4.0, "cindle")
	m = r[0]
	P = r[1]
	T = r[2]
	var TK: ThiefKit = P.ak
	P.ult = 1.0
	P.merge_cd = 0.0
	A.aim_at(P, T.pos)
	TK.ch_rmb = 1.0
	TK.cd["rmb"] = 0.0
	A.tap(m, P)
	A.ok("merge hold dancer: the Bola is winding up", not TK.bola_cast.is_empty())
	KinMerge.cast(P)
	A.step(m, 0.8)
	A.ok("merge hold dancer: the wound-up Bola is not thrown",
			TK.bola_cast.is_empty() and TK.bola.is_empty() and not KitStatus.grounded(T) and not AimKit.shown(P, "rmb"))
	await A.done(m)
	# ---- Juggernaut: a Meteor Drop diving when a merge starts doesn't land
	r = A.setup("juggernaut", 4.0, "cindle")
	m = r[0]
	P = r[1]
	T = r[2]
	var JK: JuggernautKit = P.ak
	P.ult = 1.0
	P.merge_cd = 0.0
	P.teleport(T.pos + Vector3(-3.0, 4.0, 0))
	P.grounded = false
	A.aim_at(P, T.pos)
	JK.ch_rmb = 1.0
	JK.cd["rmb"] = 0.0
	P.ak.press_rmb()
	A.ok("merge hold jug: the Meteor Drop is diving", JK.meteor.running())
	KinMerge.cast(P)
	A.step(m, 0.8)
	A.ok("merge hold jug: the dive is dropped, no slam lands", not JK.meteor.running() and JK.meteor.drops == 0)
	await A.done(m)
