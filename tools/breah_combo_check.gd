extends "res://tools/hero_pair_check.gd"
## --dolm-combo-check: Tarek (id dolm), docs/heroes/dolm.md. Every slot, its telegraph and cursor state
## while aiming or holding, the charge timings, where it lands, the payoffs, the small mechanics
## (docs/heroes/dolm.md "Small mechanics"), standing on and climbing rocks, the merge-start drops, and
## that every move, sound and look the kit plays exists.

func run(main_node: Node) -> void:
	main = main_node
	await _breah()
	var ult_check = load("res://tools/breah_ult_check.gd").new()
	await ult_check.ult(main)
	n += ult_check.n
	fails += ult_check.fails
	var flow = load("res://tools/dash_flow_check.gd").new()
	var bad: int = await flow.combos_of(main, "dolm")
	ok("item 51: each slot casts mid-jump; Shift / jump out of it act in 0.1 s; holds go through every move",
		bad == 0, "%d failing (the DASHFLOW lines)" % bad)
	var parity = load("res://tools/parity_pvb.gd").new()
	parity.main = main
	await parity.breah()
	n += parity.n
	fails += parity.fails
	print("PAIRCHECK dolm DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _breah() -> void:
	var r := setup("dolm", 5.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: DolmKit = P.ak
	var ld: Dictionary = K.lmb_def()
	var pd: Dictionary = ld["punch"]
	var sd: Dictionary = K.slam_def()
	var reset := func():
		P.teleport(home)
		P.vel = Vector3.ZERO
		P.roll_t = 0.0
		P.inp["crouch"] = false
		fresh(T)
		T.inv_t = 0.0
		T.teleport(home + Vector3(5.0, 0, 0))
		aim_at(P, T.pos)
		K.cd["e"] = 0.0
		K.ch_rmb = 1.0
		K.cd["rmb"] = 0.0
		P.fire_cd = 0.0
		P.dashes = P.max_dashes()
		K.rock_hits = {}
		P.inp["fire"] = false
		P.inp["sec_hold"] = false
		P.inp["jump"] = false
		P.inp["move"] = Vector2.ZERO
		for w in m.verbs.walls.duplicate(): m.verbs._break_wall(w)
		step(m, 0.25)
	ok(
		"name: the display name is the class title",
		Arch.name_of("dolm") == "Cliff Runner", Arch.name_of("dolm")
	)
	var card: Dictionary = K.d["card"]
	ok(
		"card: a role line and one line each for LMB, RMB, E, Shift and the passive",
		["role", "lmb", "rmb", "e", "dash", "passive"].all(func(k): return String(card.get(k, "")).length() > 10)
	)
	# ---- LMB tap: a boulder to full range that splashes the foe beside the one it hit
	reset.call()
	var T2: Hunter = m.make_hunter(
		"T2", 5, "medium", "Beside", "idle", {}, T.pos + Vector3(0, 0, 0.7), {"arch": "none"}
	)
	T2.max_hp = 10000.0
	T2.hp = T2.max_hp
	P.inp["fire"] = true
	step(m, 0.08, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	m.step(DT)
	var bshot: Array = m.shots.filter(func(s): return s["by"] == P)
	var blen := float(bshot[0]["life"]) * (bshot[0]["vel"] as Vector2).length() if not bshot.is_empty() else 0.0
	ok(
		"lmb: tap = boulder (one Match shot, molten skin)",
		K.boulders == 1 and bshot.size() == 1 and bshot[0].get("node") == null and KitLooks.of(m).skins_live(
			"boulder"
		) == 1,
		"shots %d" % bshot.size()
	)
	ok("lmb: the boulder flies to full range, not to the cursor (11m)", blen > 9.5, "%.1f m" % blen)
	step(m, 0.5)
	ok("lmb: the boulder hits", dmg(T) >= 8.0 and dmg(T) < 12.0, "took %.1f" % dmg(T))
	ok(
		"small: the boulder's burst splashes the foe beside it (half damage)",
		K.splashes >= 1 and dmg(T2) > 3.0 and dmg(T2) < dmg(T), "splash %d took %.1f" % [K.splashes, dmg(T2)]
	)
	T2.queue_free()
	m.hunters.erase(T2)
	# ---- LMB hold: the lane, the charge ring, the timing, the punch and its step
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0))
	aim_at(P, T.pos)
	var lane_at := {}
	var k_at := [0.0, 0.0]
	P.inp["fire"] = true
	step(m, 0.5, func(): P.inp["fire"] = true)
	k_at[0] = K.punch_k()
	lane_at = AimKit.entry(P, "punch")
	var ret := AimKit.reticle(P)
	step(m, 0.42, func(): P.inp["fire"] = true)
	k_at[1] = K.punch_k()
	ok(
		"lmb hold: the punch lane shows from the hold (4.2m by 1.8m, chevrons)",
		AimKit.shown(P, "punch") and absf(float(lane_at.get("len", 0.0)) - 4.2) < 0.05 and absf(
			float(lane_at.get("width", 0.0)) - 1.8
		) < 0.05 and int(lane_at.get("chevrons", 0)) == 3,
		str(lane_at.get("len"))
	)
	ok(
		"lmb hold: the cursor charge ring fills", float(ret["charge"]) > 0.2 and float(ret["charge"]) < 1.0,
		"charge %.2f" % float(ret["charge"])
	)
	ok(
		"lmb hold: a full punch at 0.9s (0.28s tap window)", k_at[0] > 0.2 and k_at[0] < 0.6 and k_at[1] >= 0.99,
		"k %.2f -> %.2f" % [k_at[0], k_at[1]]
	)
	ok("lmb hold: the fists glow while it charges", KitLooks.of(m).holding("br_fist"))
	ok("anim: the hold plays breah_wind", K.anim_id == "breah_wind")
	var x0 := P.pos.x
	P.inp["fire"] = false
	step(m, 0.4)
	ok(
		"lmb: hold + release = punch, knocks back", K.punches == 1 and dmg(T) >= 20.0 and T.pos.x - home.x > 3.0,
		"punches %d took %.1f dx %.1f" % [K.punches, dmg(T), T.pos.x - home.x]
	)
	ok("lmb: the punch steps her forward about half a body", P.pos.x - x0 > 0.35, "step %.2f" % (P.pos.x - x0))
	ok("lmb: the lane is gone after the punch", not AimKit.shown(P, "punch"))
	# the lane is narrow: a foe beside her is not hit
	reset.call()
	T.teleport(home + Vector3(1.4, 0, 1.6))
	aim_at(P, home + Vector3(5, 0, 0))
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 0.3)
	ok("lmb: the punch is a lane, not a cone (a foe 1.6m to the side is missed)", dmg(T) == 0.0, "took %.1f" % dmg(T))
	# audit: held as long as you like (the data: hold and release, no timeout); full stays full, one punch on release
	reset.call()
	var p0 := K.punches
	var b0 := K.boulders
	P.inp["fire"] = true
	step(m, 2.3, func(): P.inp["fire"] = true)
	var p_held := K.punches - p0
	P.inp["fire"] = false
	step(m, 0.2)
	ok(
		"small: holding LMB 2.3s throws nothing until the release, then one full punch (no boulder)",
		p_held == 0 and K.punches == p0 + 1 and K.boulders == b0, "held %d punches %d boulders %d" % [p_held,
			K.punches - p0, K.boulders - b0]
	)
	# a merge mid-hold ends it
	reset.call()
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	var punches0 := K.punches
	P.merge_st = {"phase": "xform"}
	K.lmb_override(false, DT)
	P.merge_st = {}
	P.inp["fire"] = false
	ok(
		"lmb: a merge ends the hold with no punch", K.punches == punches0 and K.lmb_t < 0.0 and P.mel_hold == 0.0,
		"punches %d -> %d" % [punches0, K.punches]
	)
	# punch into a wall: stunned, stars over the head
	reset.call()
	var W: World = m.world
	var bx := int(floor(home.x)) + 4
	var bz := int(floor(home.z))
	W.kind[W.idx(bx, bz)] = World.T_BLOCK
	T.teleport(home + Vector3(2.4, 0, 0))
	aim_at(P, T.pos)
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 0.5)
	ok(
		"combo: punch into a wall = stun, with stars over the head",
		K.wall_stuns >= 1 and T.stun_t > 0.0 and KitLooks.of(m).crowned(T),
		"wall stuns %d stun %.2f" % [K.wall_stuns, T.stun_t]
	)
	W.kind[W.idx(bx, bz)] = World.T_GROUND
	# ---- Stone Row: the red tell first, then a slight curve of three rocks 3.4m ahead
	reset.call()
	T.teleport(home + Vector3(9.0, 0, 0))
	aim_at(P, T.pos)
	K.use_e()
	m.step(DT)
	ok(
		"e: a red ground flash before the rocks (0.2s tell, everyone sees it)",
		AimKit.shown(P, "e_tell0") and bool(AimKit.entry(P, "e_tell0").get("all", false)) and rocks(m).size() == 0,
		"rocks %d" % rocks(m).size()
	)
	step(m, 0.25)
	var rs := rocks(m)
	var along: Array = rs.map(func(w): return K.rock_mid(w).x - home.x)
	along.sort()
	ok("e: Stone Row raises three rocks after the tell", rs.size() == 3, "rocks %d" % rs.size())
	ok(
		"e: the row is a slight curve 3.4m ahead (outer rocks 0.45m back, spanning about 3 body heights)",
		rs.size() == 3 and absf(float(along[2]) - 3.4) < 0.2 and absf(float(along[2]) - float(along[0]) - 0.45) < 0.1,
		str(along)
	)
	var zs0: Array = rs.map(func(w): return K.rock_mid(w).z)
	zs0.sort()
	ok(
		"e: the row spans about 5m (3 body heights) across the aim", float(zs0[2]) - float(zs0[0]) > 4.6,
		"%.2f" % (float(zs0[2]) - float(zs0[0]))
	)
	ok("anim: Stone Row plays breah_raise", K.anim_id == "breah_raise")
	# ---- verticality: stand on a rock, climb it with a jump, walking into it is blocked
	var w0: Dictionary = rs[0]
	var top := K.rock_mid(w0).y + float(w0["top"])
	var mid0 := K.rock_mid(w0)
	ok("rock: a rock is a low wall with a top you can stand on (1.25m)", absf(float(w0["top"]) - 1.25) < 0.01)
	P.teleport(Vector3(mid0.x, top + 0.02, mid0.z))
	P.grounded = false
	P.vel = Vector3.ZERO
	step(m, 0.4)
	ok(
		"rock: dropped onto a rock, she stands on its top", P.grounded and absf(P.pos.y - top) < 0.05,
		"y %.2f top %.2f" % [P.pos.y, top]
	)
	# item 25: the caster climbs his rocks by walking, no jump; owner 23:55 (the data): allies hop over by jumping
	# against them, walking they are stopped; foes are stopped either way
	var cross := _walk_over(m, P, home, w0)
	ok(
		"rock (item 25): walking into her own rock lifts her onto it and over, no jump, in 0.6s or less",
		float(cross["t"]) > 0.0 and float(cross["t"]) <= 0.6 and float(cross["peak"]) >= top - home.y - 0.05
			and not bool(cross["jumped"]),
		"cross %.2fs peak %.2f top %.2f" % [float(cross["t"]), float(cross["peak"]), top - home.y]
	)
	var tgt := Vector3(mid0.x, home.y, mid0.z)
	P.teleport(home + Vector3(0, 0, -6.0))
	for team in [P.team, 5]:
		var B: Hunter = m.make_hunter("B", team, "medium", "Other", "idle", {}, home, {"arch": "none"})
		var walk := _walk_over(m, B, home, w0)
		B.teleport(home)
		B.vel = Vector3.ZERO
		var jump_peak := [0.0]
		step(m, 0.3, func(): B.inp["move"] = Vector2(tgt.x - B.pos.x, tgt.z - B.pos.z).normalized())
		B.inp["jump"] = true
		step(m, 0.9, func():
			B.inp["move"] = Vector2(tgt.x - B.pos.x, tgt.z - B.pos.z).normalized()
			jump_peak[0] = maxf(jump_peak[0], B.pos.y - home.y))
		var near_side := (B.pos - mid0).dot((mid0 - home).normalized()) < 0.0
		var walk_stopped := float(walk["t"]) < 0.0 and float(walk["peak"]) < 0.1
		if team == P.team:
			var over := not near_side or B.pos.y >= top - 0.1
			ok("rock (the data, the owner's 23:55 answer): an ally walking into his rock is stopped, jumping hops on",
				walk_stopped and over, "walk cross %.2f peak %.2f, jump peak %.2f, y %.2f top %.2f" % [
					float(walk["t"]), float(walk["peak"]), jump_peak[0], B.pos.y, top
				])
		else:
			ok("rock (item 25): a foe walking or jumping into his rock is stopped",
				walk_stopped and jump_peak[0] > 0.8 and near_side and B.pos.y < top - 0.5,
				"walk cross %.2f peak %.2f, jump peak %.2f, y %.2f" % [
					float(walk["t"]), float(walk["peak"]), jump_peak[0], B.pos.y - home.y
				])
		B.queue_free()
		m.hunters.erase(B)
		m.step(DT)
	# ---- punch along the row: every rock flies, one after another (Rocksweeping)
	reset.call()
	K.use_e()
	step(m, 0.3)
	var rs2 := rocks(m)
	var zs: Array = rs2.map(func(w): return K.rock_mid(w).z)
	zs.sort()
	var lx := K.rock_mid(rs2[1]).x if rs2.size() > 1 else home.x + 3.4
	P.teleport(Vector3(lx - 0.25, home.y, float(zs[0]) - 1.6))
	P.vel = Vector3.ZERO
	T.teleport(Vector3(lx, home.y, float(zs[2]) + 4.0))
	aim_at(P, Vector3(lx - 0.25, home.y, float(zs[0]) + 10.0))
	P.fire_cd = 0.0
	var l0 := K.launches
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	m.step(DT)
	var first := K.launches - l0
	step(m, 0.3)
	ok(
		"combo: a punch along a row launches every rock in a stream",
		K.last_sweep == 3 and K.launches - l0 == 3 and first == 1,
		"swept %d launched %d (first frame %d)" % [K.last_sweep, K.launches - l0, first]
	)
	ok(
		"combo: launched rocks are flaming boulder shots (Match shots in the rock skin)",
		KitLooks.of(m).skins_live("rock") >= 1 or K.launches - l0 == 3
	)
	step(m, 0.6)
	ok(
		"combo: launched rocks burst on the foe, shred and slow it (ROCKFALL)",
		dmg(T) >= 10.0 and T.vuln_t > 0.0 and T.slow_t > 0.0 and K.launch_pay >= 1,
		"took %.1f vuln %.1f slow %.2f pay %d" % [dmg(T), T.vuln_t, T.slow_t, K.launch_pay]
	)
	ok(
		"numbers: a launched rock hits about 1.5x a boulder (14 vs 9)",
		float(K.rock_def()["dmg"]) / float(ld["boulder"]["dmg"]) > 1.35
	)
	K.rock_hits = {}
	var k1 := K._repeat_k(T)
	var k2 := K._repeat_k(T)
	ok(
		"small: a second burst on the same foe inside 0.8s deals 30% less", k1 == 1.0 and absf(k2 - 0.7) < 0.01,
		"%.2f %.2f" % [k1, k2]
	)
	# ---- RMB: the circle a hop ahead, everyone sees it, the sweet spot grows, the charge timing
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0))
	aim_at(P, T.pos)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	var e1 := AimKit.entry(P, "rmb")
	ok(
		"rmb hold: the slam circle shows for everyone, a hop ahead",
		AimKit.shown(P, "rmb") and bool(e1.get("all", false)) and absf(
			(e1.get("at", Vector2.ZERO) as Vector2).x - (home.x + 2.0)
		) < 0.3,
		str(e1.get("at"))
	)
	ok("rmb hold: she can walk slowly while charging", absf(K.move_k() - 0.55) < 0.01, "%.2f" % K.move_k())
	ok("anim: the charge is a crouch (breah_crouch)", K.anim_id == "breah_crouch")
	step(m, 1.0, func(): P.inp["sec_hold"] = true)
	var e2 := AimKit.entry(P, "rmb")
	ok(
		"rmb hold: circle and sweet spot grow to full at 1.4s (0.2 + 1.2)",
		absf(float(e2.get("r", 0.0)) - 4.5) < 0.01 and absf(
			float(e2.get("core", 0.0)) - 1.8
		) < 0.01 and float(e2.get("core", 9.0)) > float(e1.get("core", 0.0)) + 0.5,
		"core %.2f -> %.2f r %.2f -> %.2f" % [
			float(e1.get("core", 0)), float(e2.get("core", 0)), float(e1.get("r", 0)), float(e2.get("r", 0))
		]
	)
	ok(
		"rmb hold: the cursor shows the full flare",
		float(AimKit.reticle(P)["flare"]) > 0.0 or float(AimKit.reticle(P)["charge"]) >= 0.99
	)
	var hx := P.pos.x
	var walls0: int = m.verbs.walls.size()
	P.inp["sec_hold"] = false
	var hop := _hop(m, P, K)
	var looks := KitLooks.of(m)
	var slam_looks := ["burst", "shard", "crater"].all(
		func(kind): return looks.timed.any(func(e): return e["kind"] == kind)
	)
	step(m, 0.3)
	ok(
		"rmb (item 14): let go = a short hop, 1-1.5 body heights (1.8-2.7m) forward, off the ground, slam on landing",
		hop["x"] - hx >= 1.8 and hop["x"] - hx <= 2.7 and hop["peak"] > 0.3 and hop["peak"] < 0.9 and K.slams == 1
			and hop["t"] > 0.25 and hop["t"] < 0.45,
		"hop %.2fm up %.2fm in %.2fs slams %d" % [hop["x"] - hx, hop["peak"], hop["t"], K.slams]
	)
	var hit_key := 0.0
	var deepest := -9.0
	for key in KMovesStone.MOVES["breah_slam"]["keys"]:
		if float((key[1] as Dictionary).get("sq", 0.0)) > deepest:
			deepest = float((key[1] as Dictionary).get("sq", 0.0))
			hit_key = float(key[0])
	ok(
		"anim (item 14): breah_slam smashes down (its deepest squash) on the hop's landing frame",
		absf(hit_key - float(hop["t"])) < 0.05, "key %.2f landing %.2f" % [hit_key, float(hop["t"])]
	)
	ok(
		"rmb (item 14): no rock comes from Quakefall (rocks come from E, the dash and X)",
		m.verbs.walls.size() == walls0 and rocks(m).is_empty(), "walls %d -> %d" % [walls0, m.verbs.walls.size()]
	)
	ok(
		"rmb: a full charge in the centre stuns, with stars", T.stun_t > 0.0 and KitLooks.of(m).crowned(T),
		"stun %.2f" % T.stun_t
	)
	ok(
		"rmb: a molten starburst, rock chips flying, and the dark red crater lingering about 1s",
		slam_looks and looks.timed.any(func(e): return e["kind"] == "crater")
	)
	var d_full := dmg(T)
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0))
	aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.5)
	var d_tap := dmg(T)
	ok(
		"rmb: tap slam hits the centre and stuns", d_tap >= 13.0 and T.stun_t > 0.0,
		"took %.1f stun %.2f" % [d_tap, T.stun_t]
	)
	ok("rmb: a full charge hits harder", d_full > d_tap + 8.0, "tap %.1f full %.1f" % [d_tap, d_full])
	ok("rmb (item 14): the tap's slam raises no rock either", rocks(m).is_empty())
	# the sweet spot: a foe in the ring but outside the centre is hit, not stunned
	reset.call()
	T.teleport(home + Vector3(5.2, 0, 0))
	aim_at(P, home + Vector3(8, 0, 0))
	hold(m, P, 1.4)
	step(m, 0.6)
	ok(
		"rmb (item 14): only the sweet spot stuns (a foe 3.2m from the centre takes the outer hit, no stun)",
		dmg(T) >= 13.0 and T.stun_t <= 0.0,
		"took %.1f stun %.2f" % [dmg(T), T.stun_t]
	)
	# jump while charging: she leaps forward, the circle with her
	reset.call()
	aim_at(P, home + Vector3(10, 0, 0))
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	var lx0 := P.pos.x
	P.inp["jump"] = true
	m.step(DT)
	step(m, 0.35, func(): P.inp["sec_hold"] = true)
	var e3 := AimKit.entry(P, "rmb")
	var ly_mid := P.pos.y - home.y
	ok("rmb: the circle comes with her", (e3.get("at", Vector2.ZERO) as Vector2).x - lx0 > 2.5, str(e3.get("at")))
	P.inp["sec_hold"] = false
	var sl0 := K.slams
	step(m, 0.05)
	var leap_dive_vy := P.vel.y
	step(m, 1.15)
	ok(
		"rmb: jump while charging is a real leap, longer than the hop (up off the ground, about 3m forward)",
		K.slam.leaps == 1 and ly_mid > 0.6 and P.pos.x - lx0 > 2.8,
		"leaps %d up %.2f moved %.2f" % [K.slam.leaps, ly_mid, P.pos.x - lx0]
	)
	ok(
		"rmb: let go mid-leap = the leap's arc carries on (no plunge), slam where she lands",
		K.slams == sl0 + 1 and P.grounded and leap_dive_vy > -12.0, "slams %d vy %.1f" % [K.slams - sl0, leap_dive_vy]
	)
	# punch during the charge: a lunge
	reset.call()
	aim_at(P, home + Vector3(10, 0, 0))
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	var ux := P.pos.x
	var pn0 := K.punches
	P.inp["fire"] = true
	step(m, 0.25, func():
		P.inp["sec_hold"] = true
		P.inp["fire"] = true
	)
	P.inp["fire"] = false
	ok(
		"small: a punch during the charge lunges her forward (punch to extend)",
		K.slam.extends_n == 1 and P.pos.x - ux > 1.0 and K.punches == pn0, "moved %.2f" % (P.pos.x - ux)
	)
	P.inp["sec_hold"] = false
	step(m, 0.6)
	# rocks in the circle fly outward
	reset.call()
	P.ak.use_e()
	step(m, 0.3)
	var l1 := K.launches
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	hold(m, P, 0.5)
	step(m, 0.6)
	ok("combo: Stone Row > slam launches the rocks", K.launches > l1, "launches %d -> %d" % [l1, K.launches])
	# quiet level growth: ability damage scales with LevelGrowth.ap (through power())
	var lv0 := P.lvl
	P.lvl = 1
	LevelGrowth.apply(P)
	reset.call()
	T.teleport(home + Vector3(1.3, 0, 0))
	var apk1 := LevelGrowth.ap(P)      # (the level the hunter is at when it lands: early hits may have levelled it)
	K._slam(0.0, true)
	var d_l1 := dmg(T)
	P.lvl = 10
	LevelGrowth.apply(P)
	reset.call()
	T.teleport(home + Vector3(1.3, 0, 0))
	var apk := LevelGrowth.ap(P)
	K._slam(0.0, true)
	var d_l10 := dmg(T)
	P.lvl = lv0
	ok(
		"growth: the slam's damage scales with LevelGrowth.ap",
		apk > apk1 and absf(d_l10 / maxf(0.01, d_l1) - apk / apk1) < 0.02,
		"lvl1 %.2f lvl10 %.2f ap %.2f/%.2f" % [d_l1, d_l10, apk1, apk]
	)
	# data pass: a knock does not reset it (Volcano Crusher has no reset)
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0))
	aim_at(P, T.pos)
	T.hp = 10.0
	tap(m, P)
	step(m, 0.5)
	ok(
		"data: a slam that knocks does not reset Quakefall",
		T.hp < 10.0 and float(K.cd["rmb"]) > 1.0 and K.ch_rmb < 1.0,
		"cd %.2f charges %.2f" % [float(K.cd["rmb"]), K.ch_rmb]
	)
	# the dunk
	reset.call()
	T.teleport(home + Vector3(1.3, 0, 0))
	T.pos.y += 2.0
	T.grounded = false
	var dn0 := K.dunks
	K._slam(0.5, true)
	ok(
		"rmb: a foe in the air is dunked", K.dunks == dn0 + 1 and T.vel.y < -10.0,
		"dunks %d vy %.1f" % [K.dunks, T.vel.y]
	)
	await _hop_glide(m, P, home, K, reset)
	_glide_slam(m, P, K, reset)
	# ---- data pass: Landslide is 12s with one charge; Molten Guard is the base passive
	ok(
		"data: the leap rests 12s per charge and starts with one charge (a second at rank 3)",
		absf(float(K.dash_def()["cd"]) - 12.0) < 0.01 and P.max_dashes() == 1.0 and absf(P.dash_regen() - 12.0) < 0.01,
		"cd %.1f charges %.0f regen %.1f" % [float(K.dash_def()["cd"]), P.max_dashes(), P.dash_regen()]
	)
	reset.call()
	K.use_e()
	step(m, 0.3)
	var rsg := rocks(m)
	var gx := K.rock_mid(rsg[1]).x if rsg.size() > 1 else home.x + 3.4
	var gz := K.rock_mid(rsg[0]).z if not rsg.is_empty() else home.z
	P.teleport(Vector3(gx - 0.25, home.y, gz - 1.6))
	P.vel = Vector3.ZERO
	T.teleport(Vector3(gx, home.y, gz + 14.0))
	aim_at(P, Vector3(gx - 0.25, home.y, gz + 10.0))
	P.fire_cd = 0.0
	P.shield = 0.0
	K.shield_stacks = 0
	var gp0 := K.guard_punches
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 0.3)
	ok(
		"data: punching your own rocks gives a Molten Guard shield (one stack of 18 per punch, rank 1)",
		K.guard_punches == gp0 + 1 and K.shield_stacks == 1 and absf(P.shield - 18.0) < 0.5 and K.last_sweep >= 2,
		"punches %d stacks %d shield %.1f swept %d" % [K.guard_punches - gp0, K.shield_stacks, P.shield, K.last_sweep]
	)
	reset.call()
	P.shield = 0.0
	K.shield_stacks = 0
	T.teleport(home + Vector3(2.4, 0, 0))
	aim_at(P, T.pos)
	P.fire_cd = 0.0
	gp0 = K.guard_punches
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 0.3)
	ok(
		"data: a punch with no rock of yours in the lane gives no shield",
		K.guard_punches == gp0 and K.shield_stacks == 0 and P.shield < 0.5, "shield %.1f" % P.shield
	)
	# ---- Rubble Leap: the rock bursts up, she leaps to the cursor, lands with a crash, the rock follows
	await _leap(m, P, T, home, K, reset)
	# the base dash (in the air): her own heavy shove move
	reset.call()
	P.pos.y += 1.5
	P.grounded = false
	P.do_dash()
	ok("anim: her long air dash plays breah_exdash", K.anim_id == "breah_exdash")
	step(m, 0.8)
	await _dash_moves(m, P, T, home, K, reset)
	_air_dash_hold(m, P, K, reset)
	# ---- rank 3
	P.slot_lv["sec"] = 3
	P.slot_lv["kin"] = 3
	P.slot_lv["dash"] = 3
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0))
	aim_at(P, T.pos)
	P.shield = 0.0
	tap(m, P)
	step(m, 0.5)
	ok(
		"rank 3: slamming a foe gives a Molten Guard shield", P.shield >= 17.0 and K.shield_stacks >= 1,
		"shield %.0f" % P.shield
	)
	ok(
		"data rank 3: a second leap charge, recharging in 8.4s (12s x 0.7 on the shared rank step)",
		P.max_dashes() == 2.0 and absf(P.dash_regen() - 8.4) < 0.05,
		"charges %.0f regen %.2f" % [P.max_dashes(), P.dash_regen()]
	)
	reset.call()
	aim_at(P, home + Vector3(30.0, 0, 0))
	P.ak.on_dash(false)
	step(m, 0.9)
	var far3 := float(K.dash_def()["dist"]) * float(K.dash_feel()["dist"]) * float(K.dash_def()["speed_k"])
	ok(
		"data rank 3: the leap goes a third further", absf(P.pos.x - home.x - far3) < 0.4,
		"%.2f want %.2f" % [P.pos.x - home.x, far3]
	)
	reset.call()
	T.teleport(home + Vector3(5.0, 0, 2.7))
	aim_at(P, home + Vector3(6, 0, 0))
	P.ak.use_e()
	step(m, 0.25)
	var mid_n := rocks(m).size()
	step(m, 0.4)
	ok(
		"rank 3: an extra row behind the first, rising with it (the centre-out rise is Basalt Spine's)",
		rocks(m).size() == 6 and mid_n == 6, "at 0.25s %d, then %d" % [mid_n, rocks(m).size()]
	)
	ok("rank 3: the extra row does not slow (the slow is Basalt Spine's)", T.slow_t <= 0.0, "slow %.2f" % T.slow_t)
	P.slot_lv["sec"] = 1
	P.slot_lv["kin"] = 1
	P.slot_lv["dash"] = 1
	# ---- Tremor Sense: the cone shows while sneaking and widens
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0))
	aim_at(P, T.pos)
	P.inp["crouch"] = true
	step(m, 0.2, func(): P.inp["crouch"] = true)
	var c1 := AimKit.entry(P, "sight")
	step(m, 2.1, func(): P.inp["crouch"] = true)
	var c2 := AimKit.entry(P, "sight")
	ok("passive: sneaking shows a pale cone ahead", AimKit.shown(P, "sight") and float(c1.get("len", 0.0)) >= 15.0)
	ok(
		"passive: the cone widens 25 -> 40 degrees over 2s of sneaking",
		float(c1.get("deg", 0.0)) < 28.0 and absf(float(c2.get("deg", 0.0)) - 40.0) < 0.5,
		"%.1f -> %.1f" % [float(c1.get("deg", 0)), float(c2.get("deg", 0))]
	)
	var s_front := K.stonesight()
	T.teleport(home + Vector3(-8.0, 0, 0))
	var s_back := K.stonesight()
	ok(
		"passive: Tremor Sense shows foes in front only", s_front == 1 and s_back == 0,
		"front %d back %d" % [s_front, s_back]
	)
	P.inp["crouch"] = false
	step(m, 0.2)
	ok("passive: the cone goes when she stops sneaking", not AimKit.shown(P, "sight"))
	# ---- merge start drops every hold
	reset.call()
	P.ak.on_dash(false)
	m.step(DT)
	var leaping := not K.leap.is_empty()
	K.lmb_t = 0.5
	K.dive = true
	K.slam.leapt = true
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	K.drop_holds()
	ok(
		"merge hold: the dive, the charge, its leap and Rubble Leap all drop",
		leaping and not K.dive and K.lmb_t < 0.0 and K.leap.is_empty() and not K.slam.leapt
		and not AimKit.shown(P, "rmb")
	)
	P.inp["sec_hold"] = false
	step(m, 0.5)
	# ---- every move, sound and look exists
	var moves := [
		"breah_throw", "breah_wind", "breah_punch", "breah_crouch", "breah_leap", "breah_slam", "breah_dive",
		"breah_slam_land", "breah_lunge", "breah_dash", "breah_leap_land", "breah_exdash", "breah_raise", "breah_sense"
	]
	ok(
		"anim: every Tarek move is keyed (KMovesStone)",
		moves.all(func(mv): return not HunterAnim.km_sample(mv, 0.1).is_empty()),
		str(moves.filter(func(mv): return HunterAnim.km_sample(mv, 0.1).is_empty()))
	)
	var snd := SfxKits.NAMES.filter(func(s): return String(s).begins_with("br_"))
	ok(
		"sfx: every Tarek sound is loaded by Sfx", snd.size() >= 14 and snd.all(func(s): return Sfx.has(s)),
		str(snd.filter(func(s): return not Sfx.has(s)))
	)
	await done(m)

## Walks `h` from `home` straight at rock `w` and on past it for 1.6s: how long the crossing took (from
## touching the near face to clearing the far one; -1 if it never got past), the highest the feet got
## above `home`, and whether a jump was ever pressed.
func _walk_over(m: Match, h: Hunter, home: Vector3, w: Dictionary) -> Dictionary:
	var mid2: Vector2 = ((w["a"] as Vector2) + (w["b"] as Vector2)) * 0.5
	var mid := Vector3(mid2.x, float(w["y"]), mid2.y)
	var dir := (mid - home).normalized()
	var face := float(w["th"]) + h.r * 0.8
	h.teleport(home)
	h.vel = Vector3.ZERO
	var out := {"t": -1.0, "peak": 0.0, "jumped": false}
	var touch := -1.0
	var t := 0.0
	while t < 1.6:
		h.inp["move"] = Vector2(dir.x, dir.z)
		out["jumped"] = bool(out["jumped"]) or bool(h.inp.get("jump", false))
		m.step(DT)
		t += DT
		out["peak"] = maxf(float(out["peak"]), h.pos.y - home.y)
		var along := (h.pos - mid).dot(dir)
		if touch < 0.0 and along >= -face - 0.05:
			touch = t
		if touch >= 0.0 and float(out["t"]) < 0.0 and along > face:
			out["t"] = t - touch
	h.inp["move"] = Vector2.ZERO
	return out

## Steps until the slam lands: where she came down, the hop's peak above the take-off and its time.
func _hop(m: Match, P: Hunter, K: DolmKit) -> Dictionary:
	var y0 := P.pos.y
	var out := {"x": P.pos.x, "peak": 0.0, "t": 0.0}
	var s0 := K.slams
	while K.slams == s0 and float(out["t"]) < 1.0:
		m.step(DT)
		out["t"] = float(out["t"]) + DT
		out["peak"] = maxf(float(out["peak"]), P.pos.y - y0)
	out["x"] = P.pos.x
	return out

## Item 26: Quakefall then the glider. Glide held from the hop, or pressed after a charge leap or an air
## press: the glider opens, she never drops below where she took off (for the first 0.3s), and it sinks
## like a normal glide.
func _hop_glide(m: Match, P: Hunter, home: Vector3, K: DolmKit, reset: Callable) -> void:
	for mode in ["hop", "leap", "air"]:
		reset.call()
		aim_at(P, home + Vector3(8, 0, 0))
		var z0 := P.pos.y
		if mode == "hop":
			tap(m, P)
		elif mode == "leap":
			P.inp["sec_hold"] = true
			P.ak.press_rmb()
			step(m, 0.4, func(): P.inp["sec_hold"] = true)
			P.inp["jump"] = true
			step(m, 0.15, func(): P.inp["sec_hold"] = true)
			P.inp["sec_hold"] = false
			m.step(DT)
		else:
			P.inp["jump"] = true
			step(m, 0.2)
			tap(m, P)
			z0 = P.pos.y
		var dove := K.dive
		var floor_z := -Hunter.GLIDE_SINK * 0.3 - 0.02 if mode == "air" else -0.01     # (in the air: a glide's sink)
		var low := 99.0
		var sink := 0.0
		var t := 0.0
		P.inp["jump"] = true
		while t < 0.3:
			P.inp["glide"] = true
			m.step(DT)
			t += DT
			low = minf(low, P.pos.y - z0)
			if P.gliding: sink = minf(sink, P.vel.y)
		ok(
			"glide (item 26, %s): Quakefall, then glide opens the glider; height kept, a normal glide" % mode,
			dove and P.gliding and not K.dive and low >= floor_z and sink >= -Hunter.GLIDE_SINK - 0.05,
			"gliding %s dive %s low %.2f sink %.2f" % [P.gliding, K.dive, low, sink]
		)
		P.inp["glide"] = false
		step(m, 0.8)

## Owner 23:00 (reverses item 26's "the glider wins" for a press in a glide; the source allows it): Quakefall
## pressed while gliding folds the glider and plunges at the glider's dive speed (data: 32.5 m/s down, sideways
## speed x0.25), slamming where she lands; glide still held doesn't reopen it on the way down.
func _glide_slam(m: Match, P: Hunter, K: DolmKit, reset: Callable) -> void:
	reset.call()
	P.pos.y += 8.0
	P.grounded = false
	P.inp["move"] = Vector2(1, 0)
	var t := 0.0
	while not P.gliding and t < 1.0:
		P.inp["glide"] = true
		m.step(DT)
		t += DT
	var glided := P.gliding
	var s0 := K.slams
	var vx0 := absf(P.vel.x)
	P.inp["move"] = Vector2.ZERO
	tap(m, P)
	var folded := not P.gliding and K.dive and K.dive_glide
	var vx1 := absf(P.vel.x)
	var fall := 0.0
	var vmin := 0.0
	var reopened := false
	while not P.grounded and fall < 2.0:
		P.inp["glide"] = true
		m.step(DT)
		fall += DT
		vmin = minf(vmin, P.vel.y)
		reopened = reopened or P.gliding
	P.inp["glide"] = false
	P.inp["move"] = Vector2.ZERO
	m.step(DT)
	ok("glide slam: RMB in a glide folds the glider and plunges at the glider's dive speed (data 32.5 m/s)",
		glided and folded and not reopened and vmin <= -30.0 and vx1 <= vx0 * 0.3 + 0.1,
		"glided %s folded %s reopened %s vy %.1f vx %.1f -> %.1f" % [glided, folded, reopened, vmin, vx0, vx1])
	ok("glide slam: she slams where she lands (about 0.3s down from 8m)", K.slams == s0 + 1 and P.grounded
		and fall < 0.6, "slams +%d, %.2f s down" % [K.slams - s0, fall])
	step(m, 0.8)

## Item 51: the Quake Fist charge carries through her air dash (it charges on, short of the auto punch) and a
## release in it punches as the dash ends, in the air, keeping most of her speed.
func _air_dash_hold(m: Match, P: Hunter, K: DolmKit, reset: Callable) -> void:
	reset.call()
	P.inp["fire"] = true
	step(m, float(K.lmb_def()["tap"]) + 0.15)
	var k0 := K.lmb_t
	var n0 := K.punches
	P.pos.y += 4.0
	P.grounded = false
	P.inp["move"] = Vector2(1, 0)
	P.ex_cd = 0.0
	P.do_dash()
	var dashing := K.flow.move_now() == "air"
	step(m, 0.08)
	ok("item 51: the Quake Fist charge carries through her air dash, charging on",
		dashing and K.lmb_t > k0 + 0.05 and K.punches == n0, "charge %.2f -> %.2f dash %s punches +%d" % [k0, K.lmb_t,
		dashing, K.punches - n0])
	var speed := 0.0
	P.inp["fire"] = false
	var t := 0.0
	while K.punches == n0 and t < 0.5:
		speed = Vector2(P.vel.x, P.vel.z).length()       # (the last step before the punch: the dash's end)
		m.step(DT)
		t += DT
	var kept := Vector2(P.vel.x, P.vel.z).length()
	ok("item 51: let go in the air dash, she punches as it ends, still in the air and moving",
		K.punches == n0 + 1 and not P.grounded and kept >= speed * 0.5, "%.2fs speed %.1f -> %.1f" % [t, speed, kept])
	P.inp["move"] = Vector2.ZERO
	step(m, 0.8)

## Item 35: her own ground (Rubble Leap) and air (the long dash) moves, ids no other hero's table has, each one
## keyed to end with its dash (the leap's crouch and flight; the air dash's time with the dash feel), and
## neither dash draws a ground ring or a blast (the leap's hit area is its landing circle, shown in flight).
func _dash_moves(m: Match, P: Hunter, T: Hunter, home: Vector3, K: DolmKit, reset: Callable) -> void:
	var ids := ["breah_dash", "breah_exdash"]
	var others := [HunterAnim.KMOVES, KMovesPair.MOVES, KMovesVV.MOVES, MergeMoves.MOVES, KMovesCare.MOVES,
		KMovesPinBjorn.MOVES, KMovesDJ.MOVES]
	ok(
		"item 35: her ground and air dash moves are two distinct ids, hers alone (KMovesStone, no other table)",
		ids[0] != ids[1] and ids.all(func(id): return KMovesStone.MOVES.has(id) and String(id).begins_with("breah_"))
			and not others.any(func(t): return ids.any(func(id): return (t as Dictionary).has(id)))
	)
	var feel_t := float(K.dash_feel()["time"])
	var ground_t := DolmKit.LEAP_CROUCH + float(K.dash_def()["time"]) * feel_t
	var air_t := float(P.cdat["ex_time"]) * feel_t
	var lengths: Array = ids.map(func(id): return float((KMovesStone.MOVES[id]["keys"] as Array)[-1][0]))
	ok(
		"item 35: each dash move ends with its dash (ground %.2fs, air %.2fs)" % [ground_t, air_t],
		absf(float(lengths[0]) - ground_t) <= 0.03 and float(lengths[1]) <= air_t + 0.005 and float(lengths[1]) > 0.15,
		str(lengths)
	)
	for air in [false, true]:
		reset.call()
		T.teleport(home + Vector3(0, 0, 12.0))
		aim_at(P, home + Vector3(3.0, 0, 0))
		if air:
			P.pos.y += 1.5
			P.grounded = false
			P.ex_cd = 0.0
			P.do_dash()
		else:
			P.ak.on_dash(false)
		if air:
			m.step(DT)
			P.render(DT, 1.0)
			ok(
				"item 35: her air dash plays breah_exdash as the whole pose (no shared roll under it)",
				K.anim_id == "breah_exdash" and String(P.anim_s.get("dash_kind", "")) == "kit",
				"anim %s kind %s roll %.2f" % [K.anim_id, str(P.anim_s.get("dash_kind")), P.roll_t]
			)
		var seen: Array = m.fx.rings.duplicate() + KitLooks.of(m).timed.duplicate()
		var blasts := [0]
		step(m, 0.9, func():
			for e in m.fx.rings + KitLooks.of(m).timed.filter(func(e): return e["kind"] in ["burst", "crater"]):
				if not seen.any(func(o): return is_same(o, e)):
					seen.append(e)
					blasts[0] += 1)
		ok(
			"item 35: her %s dash draws no ground ring and no blast" % ("air" if air else "ground"),
			blasts[0] == 0, "rings/blasts %d" % blasts[0]
		)

## Rubble Leap (owner's dash note: a leap, not the source's odd dash): the rock first, an arc to the cursor
## clamped by the dash feel, the landing marker for everyone, the landing crash, then the rock's roll-on hit.
func _leap(m: Match, P: Hunter, T: Hunter, home: Vector3, K: DolmKit, reset: Callable) -> void:
	var dd := K.dash_def()
	reset.call()
	T.teleport(home + Vector3(0, 0, 9.0))
	aim_at(P, home + Vector3(3.0, 0, 0))
	P.ak.on_dash(false)
	m.step(DT)
	ok(
		"dash: the rock bursts up first; she crouches on it before the leap",
		P.grounded and KitLooks.of(m).holding("br_carry") and K.anim_id == "breah_dash"
	)
	ok(
		"dash: the landing spot shows for everyone through the leap",
		AimKit.shown(P, "leap") and bool(AimKit.entry(P, "leap").get("all", false))
	)
	var peak := [0.0]
	step(m, 0.9, func(): peak[0] = maxf(peak[0], P.pos.y - home.y))
	var land_off := Vector2(P.pos.x - home.x - 3.0, P.pos.z - home.z).length()
	ok(
		"dash: an arc (a clear take-off and landing) that lands at the cursor",
		peak[0] > 0.6 and land_off < 0.45 and P.grounded and K.leap_lands == 1,
		"peak %.2f off %.2f" % [peak[0], land_off]
	)
	ok("anim: the landing plays breah_leap_land", K.anim_id == "breah_leap_land")
	reset.call()
	aim_at(P, home + Vector3(20.0, 0, 0))
	P.ak.on_dash(false)
	step(m, 0.9)
	var far := float(dd["dist"]) * float(K.dash_feel()["dist"])
	ok(
		"dash: a far cursor clamps the leap to its reach, with the dash feel on top (5m x 0.85)",
		absf(P.pos.x - home.x - far) < 0.4, "%.2f want %.2f" % [P.pos.x - home.x, far]
	)
	# the landing crash catches whoever is beside the spot
	reset.call()
	T.teleport(home + Vector3(4.0, 0, 0.9))
	aim_at(P, home + Vector3(3.0, 0, 0))
	var hits0 := K.leap_hits
	var lands0 := K.leap_lands
	var rolls0 := K.landslides
	var t_at := T.pos
	P.ak.on_dash(false)
	var rock_first := [false]
	step(m, 0.75, func(): if K.leap_lands > lands0 and K.landslides == rolls0: rock_first[0] = true)
	ok(
		"dash: the landing crash hits and shoves a foe beside the spot",
		K.leap_hits == hits0 + 1 and dmg(T) >= float(dd["land_dmg"]) * 0.9 and T.pos.distance_to(t_at) > 0.5,
		"hits %d took %.1f" % [K.leap_hits - hits0, dmg(T)]
	)
	ok("dash: the rock comes down after her landing (two hits, not one)", rock_first[0])
	# the rock rolls on from the landing and hits: shred and a slow
	reset.call()
	T.teleport(home + Vector3(7.5, 0, 0))
	aim_at(P, home + Vector3(3.0, 0, 0))
	P.ak.on_dash(false)
	step(m, 1.2)
	ok(
		"dash: the rock rolls on from the landing and hits: shred and a slow",
		K.landslides >= 1 and dmg(T) >= 10.0 and T.vuln_t > 0.0 and T.slow_t > 0.0,
		"took %.1f slow %.2f" % [dmg(T), T.slow_t]
	)
	reset.call()
	T.teleport(home + Vector3(13.0, 0, 0))
	aim_at(P, home + Vector3(3.0, 0, 0))
	P.ak.on_dash(false)
	step(m, 1.4)
	ok("dash: the rolling rock goes about 6m, not 12", dmg(T) == 0.0, "took %.1f" % dmg(T))
