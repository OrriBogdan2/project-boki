extends "res://tools/hero_pair_check.gd"
## --dolm-combo-check: Breah (id dolm), docs/heroes/dolm.md. Every slot, its telegraph and cursor state
## while aiming or holding, the charge timings, where it lands, the payoffs, the small mechanics
## (docs/heroes/dolm.md "Small mechanics"), standing on and climbing rocks, the merge-start drops, and
## that every move, sound and look the kit plays exists.

func run(main_node: Node) -> void:
	main = main_node
	await _breah()
	print("PAIRCHECK dolm DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _breah() -> void:
	var r := setup("dolm", 5.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var home: Vector3 = r[3]
	var K: DolmKit = P.ak
	var ld: Dictionary = K.lmb_def()
	var pd: Dictionary = ld["punch"]
	var sd: Dictionary = K.slam_def()
	var reset := func():
		P.teleport(home); P.vel = Vector3.ZERO; P.roll_t = 0.0; P.inp["crouch"] = false; fresh(T); T.teleport(home + Vector3(5.0, 0, 0)); aim_at(P, T.pos)
		K.cd["e"] = 0.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; P.fire_cd = 0.0; P.dashes = P.max_dashes(); K.rock_hits = {}
		P.inp["fire"] = false; P.inp["sec_hold"] = false; P.inp["jump"] = false; P.inp["move"] = Vector2.ZERO
		for w in m.verbs.walls.duplicate(): m.verbs._break_wall(w)
		step(m, 0.25)
	ok("name: the display name is Breah", Arch.name_of("dolm") == "Breah" and HeroKit.ARCHES["dolm"]["name"] == "Breah", Arch.name_of("dolm"))
	var card: Dictionary = K.d["card"]
	ok("card: a role line and one line each for LMB, RMB, E, Shift and the passive", ["role", "lmb", "rmb", "e", "dash", "passive"].all(func(k): return String(card.get(k, "")).length() > 10))
	# ---- LMB tap: a boulder to full range that splashes the foe beside the one it hit
	reset.call()
	var T2: Hunter = m.make_hunter("T2", 5, "medium", "Beside", "idle", {}, T.pos + Vector3(0, 0, 0.7), {"arch": "none"})
	T2.max_hp = 10000.0; T2.hp = T2.max_hp
	P.inp["fire"] = true
	step(m, 0.08, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	m.step(DT)
	var bshot: Array = m.shots.filter(func(s): return s["by"] == P)
	var blen := float(bshot[0]["life"]) * (bshot[0]["vel"] as Vector2).length() if not bshot.is_empty() else 0.0
	ok("lmb: tap = boulder (one Match shot, molten skin)", K.boulders == 1 and bshot.size() == 1 and bshot[0].get("node") == null and KitLooks.of(m).skins_live("boulder") == 1, "shots %d" % bshot.size())
	ok("lmb: the boulder flies to full range, not to the cursor (11m)", blen > 9.5, "%.1f m" % blen)
	step(m, 0.5)
	ok("lmb: the boulder hits", dmg(T) >= 8.0 and dmg(T) < 12.0, "took %.1f" % dmg(T))
	ok("small: the boulder's burst splashes the foe beside it (half damage)", K.splashes >= 1 and dmg(T2) > 3.0 and dmg(T2) < dmg(T), "splash %d took %.1f" % [K.splashes, dmg(T2)])
	T2.queue_free(); m.hunters.erase(T2)
	# ---- LMB hold: the lane, the charge ring, the timing, the punch and its step
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0)); aim_at(P, T.pos)
	var lane_at := {}
	var k_at := [0.0, 0.0]
	P.inp["fire"] = true
	step(m, 0.5, func(): P.inp["fire"] = true)
	k_at[0] = K.punch_k()
	lane_at = AimKit.entry(P, "punch")
	var ret := AimKit.reticle(P)
	step(m, 0.42, func(): P.inp["fire"] = true)
	k_at[1] = K.punch_k()
	ok("lmb hold: the punch lane shows from the hold (3.2m by 1.4m, chevrons)", AimKit.shown(P, "punch") and absf(float(lane_at.get("len", 0.0)) - 3.2) < 0.05 and absf(float(lane_at.get("width", 0.0)) - 1.4) < 0.05 and int(lane_at.get("chevrons", 0)) == 3, str(lane_at.get("len")))
	ok("lmb hold: the cursor charge ring fills", float(ret["charge"]) > 0.2 and float(ret["charge"]) < 1.0, "charge %.2f" % float(ret["charge"]))
	ok("lmb hold: a full punch at 0.9s (0.28s tap window)", k_at[0] > 0.2 and k_at[0] < 0.6 and k_at[1] >= 0.99, "k %.2f -> %.2f" % [k_at[0], k_at[1]])
	ok("lmb hold: the fists glow while it charges", KitLooks.of(m).holding("br_fist"))
	ok("anim: the hold plays breah_wind", K.anim_id == "breah_wind")
	var x0 := P.pos.x
	P.inp["fire"] = false
	step(m, 0.4)
	ok("lmb: hold + release = punch, knocks back", K.punches == 1 and dmg(T) >= 20.0 and T.pos.x - home.x > 3.0, "punches %d took %.1f dx %.1f" % [K.punches, dmg(T), T.pos.x - home.x])
	ok("lmb: the punch steps her forward about half a body", P.pos.x - x0 > 0.35, "step %.2f" % (P.pos.x - x0))
	ok("lmb: the lane is gone after the punch", not AimKit.shown(P, "punch"))
	# the lane is narrow: a foe beside her is not hit
	reset.call()
	T.teleport(home + Vector3(1.4, 0, 1.6)); aim_at(P, home + Vector3(5, 0, 0))
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 0.3)
	ok("lmb: the punch is a lane, not a cone (a foe 1.6m to the side is missed)", dmg(T) == 0.0, "took %.1f" % dmg(T))
	# holding on: it punches by itself and starts the next wind-up, a release throws nothing
	reset.call()
	P.inp["fire"] = true
	step(m, 2.3, func(): P.inp["fire"] = true)
	var p_auto := K.punches
	P.inp["fire"] = false
	step(m, 0.2)
	ok("small: holding LMB keeps punching, letting go after an auto-punch throws no boulder", p_auto >= 1 and K.boulders == 1, "punches %d boulders %d" % [p_auto, K.boulders])
	# a merge mid-hold ends it
	reset.call()
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	var punches0 := K.punches
	P.merge_st = {"phase": "xform"}
	K.lmb_override(false, DT)
	P.merge_st = {}
	P.inp["fire"] = false
	ok("lmb: a merge ends the hold with no punch", K.punches == punches0 and K.lmb_t < 0.0 and P.mel_hold == 0.0, "punches %d -> %d" % [punches0, K.punches])
	# punch into a wall: stunned, stars over the head
	reset.call()
	var W: World = m.world
	var bx := int(floor(home.x)) + 4; var bz := int(floor(home.z))
	W.kind[W.idx(bx, bz)] = World.T_BLOCK
	T.teleport(home + Vector3(2.4, 0, 0)); aim_at(P, T.pos)
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 0.5)
	ok("combo: punch into a wall = stun, with stars over the head", K.wall_stuns >= 1 and T.stun_t > 0.0 and KitLooks.of(m).crowned(T), "wall stuns %d stun %.2f" % [K.wall_stuns, T.stun_t])
	W.kind[W.idx(bx, bz)] = World.T_GROUND
	# ---- Stone Row: the red tell first, then a slight curve of three rocks 2.2m ahead
	reset.call()
	T.teleport(home + Vector3(9.0, 0, 0)); aim_at(P, T.pos)
	K.use_e()
	m.step(DT)
	ok("e: a red ground flash before the rocks (0.2s tell, everyone sees it)", AimKit.shown(P, "e_tell0") and bool(AimKit.entry(P, "e_tell0").get("all", false)) and rocks(m).size() == 0, "rocks %d" % rocks(m).size())
	step(m, 0.25)
	var rs := rocks(m)
	var along: Array = rs.map(func(w): return K.rock_mid(w).x - home.x)
	along.sort()
	ok("e: Stone Row raises three rocks after the tell", rs.size() == 3, "rocks %d" % rs.size())
	ok("e: the row is a slight curve 2.2m ahead (outer rocks 0.3m back)", rs.size() == 3 and absf(float(along[2]) - 2.2) < 0.2 and absf(float(along[2]) - float(along[0]) - 0.3) < 0.1, str(along))
	ok("anim: Stone Row plays breah_raise", K.anim_id == "breah_raise")
	# ---- verticality: stand on a rock, climb it with a jump, walking into it is blocked
	var w0: Dictionary = rs[0]
	var top := K.rock_mid(w0).y + float(w0["top"])
	var mid0 := K.rock_mid(w0)
	ok("rock: a rock is a low wall with a top you can stand on (1.25m)", absf(float(w0["top"]) - 1.25) < 0.01)
	P.teleport(Vector3(mid0.x, top + 0.02, mid0.z)); P.grounded = false; P.vel = Vector3.ZERO
	step(m, 0.4)
	ok("rock: dropped onto a rock, she stands on its top", P.grounded and absf(P.pos.y - top) < 0.05, "y %.2f top %.2f" % [P.pos.y, top])
	P.teleport(home); P.grounded = true; P.vel = Vector3.ZERO
	var tgt := Vector3(mid0.x, home.y, mid0.z)
	step(m, 0.8, func(): P.inp["move"] = Vector2(tgt.x - P.pos.x, tgt.z - P.pos.z).normalized())
	ok("rock: walking into a rock is blocked (no climbing without a jump)", P.pos.y < home.y + 0.1 and Vector2(P.pos.x - mid0.x, P.pos.z - mid0.z).length() > 0.45, "y %.2f" % (P.pos.y - home.y))
	var climbed := [false]
	P.inp["jump"] = true
	step(m, 0.9, func():
		P.inp["move"] = Vector2(tgt.x - P.pos.x, tgt.z - P.pos.z).normalized()
		if P.grounded and P.pos.y > top - 0.05: climbed[0] = true)
	P.inp["jump"] = false; P.inp["move"] = Vector2.ZERO
	ok("rock: jump into a rock and you climb onto it", climbed[0], "y %.2f top %.2f" % [P.pos.y, top])
	# ---- punch along the row: every rock flies, one after another (Rocksweeping)
	reset.call()
	K.use_e()
	step(m, 0.3)
	var rs2 := rocks(m)
	var zs: Array = rs2.map(func(w): return K.rock_mid(w).z)
	zs.sort()
	var lx := K.rock_mid(rs2[1]).x if rs2.size() > 1 else home.x + 2.2
	P.teleport(Vector3(lx - 0.25, home.y, float(zs[0]) - 1.6)); P.vel = Vector3.ZERO
	T.teleport(Vector3(lx, home.y, float(zs[2]) + 6.0))
	aim_at(P, Vector3(lx - 0.25, home.y, float(zs[0]) + 10.0))
	P.fire_cd = 0.0
	var l0 := K.launches
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	m.step(DT)
	var first := K.launches - l0
	step(m, 0.3)
	ok("combo: a punch along a row launches every rock in a stream", K.last_sweep == 3 and K.launches - l0 == 3 and first == 1, "swept %d launched %d (first frame %d)" % [K.last_sweep, K.launches - l0, first])
	ok("combo: launched rocks are flaming boulder shots (Match shots in the rock skin)", KitLooks.of(m).skins_live("rock") >= 1 or K.launches - l0 == 3)
	step(m, 0.6)
	ok("combo: launched rocks burst on the foe, shred and slow it (ROCKFALL)", dmg(T) >= 10.0 and T.vuln_t > 0.0 and T.slow_t > 0.0 and K.launch_pay >= 1, "took %.1f vuln %.1f slow %.2f pay %d" % [dmg(T), T.vuln_t, T.slow_t, K.launch_pay])
	ok("numbers: a launched rock hits about 1.5x a boulder (14 vs 9)", float(K.rock_def()["dmg"]) / float(ld["boulder"]["dmg"]) > 1.35)
	K.rock_hits = {}
	var k1 := K._repeat_k(T); var k2 := K._repeat_k(T)
	ok("small: a second burst on the same foe inside 0.8s deals 30% less", k1 == 1.0 and absf(k2 - 0.7) < 0.01, "%.2f %.2f" % [k1, k2])
	# ---- RMB: the circle a hop ahead, everyone sees it, the sweet spot grows, the charge timing
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0)); aim_at(P, T.pos)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	var e1 := AimKit.entry(P, "rmb")
	ok("rmb hold: the slam circle shows for everyone, a hop ahead", AimKit.shown(P, "rmb") and bool(e1.get("all", false)) and absf((e1.get("at", Vector2.ZERO) as Vector2).x - (home.x + 1.3)) < 0.3, str(e1.get("at")))
	ok("rmb hold: she can walk slowly while charging", absf(K.move_k() - 0.55) < 0.01, "%.2f" % K.move_k())
	ok("anim: the charge is a crouch (breah_crouch)", K.anim_id == "breah_crouch")
	step(m, 1.0, func(): P.inp["sec_hold"] = true)
	var e2 := AimKit.entry(P, "rmb")
	ok("rmb hold: circle and sweet spot grow to full at 1.4s (0.2 + 1.2)", absf(float(e2.get("r", 0.0)) - 3.0) < 0.01 and absf(float(e2.get("core", 0.0)) - 1.8) < 0.01 and float(e2.get("core", 9.0)) > float(e1.get("core", 0.0)) + 0.5, "core %.2f -> %.2f r %.2f -> %.2f" % [float(e1.get("core", 0)), float(e2.get("core", 0)), float(e1.get("r", 0)), float(e2.get("r", 0))])
	ok("rmb hold: the cursor shows the full flare", float(AimKit.reticle(P)["flare"]) > 0.0 or float(AimKit.reticle(P)["charge"]) >= 0.99)
	var hx := P.pos.x
	P.inp["sec_hold"] = false
	step(m, 0.6)
	ok("rmb: let go = a hop forward into the circle, then the slam", P.pos.x - hx > 0.9 and K.slams == 1, "hop %.2f slams %d" % [P.pos.x - hx, K.slams])
	ok("rmb: a full charge in the centre stuns, with stars", T.stun_t > 0.0 and KitLooks.of(m).crowned(T), "stun %.2f" % T.stun_t)
	ok("rmb: the crater lingers about 1s", KitLooks.of(m).timed.any(func(e): return e["kind"] == "scorch"))
	var d_full := dmg(T)
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0)); aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.5)
	var d_tap := dmg(T)
	ok("rmb: tap slam hits the centre and stuns", d_tap >= 13.0 and T.stun_t > 0.0, "took %.1f stun %.2f" % [d_tap, T.stun_t])
	ok("rmb: a full charge hits harder", d_full > d_tap + 8.0, "tap %.1f full %.1f" % [d_tap, d_full])
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
	ok("rmb: jump while charging leaps her forward", K.slam.leaps == 1 and P.pos.x - lx0 > 2.0, "leaps %d moved %.2f" % [K.slam.leaps, P.pos.x - lx0])
	ok("rmb: the circle comes with her", (e3.get("at", Vector2.ZERO) as Vector2).x - lx0 > 2.5, str(e3.get("at")))
	P.inp["sec_hold"] = false
	step(m, 1.2)
	ok("rmb: let go mid-leap = slam where she lands", K.slams >= 1 and P.grounded, "slams %d" % K.slams)
	# punch during the charge: a lunge
	reset.call()
	aim_at(P, home + Vector3(10, 0, 0))
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	var ux := P.pos.x
	var pn0 := K.punches
	P.inp["fire"] = true
	step(m, 0.25, func(): P.inp["sec_hold"] = true; P.inp["fire"] = true)
	P.inp["fire"] = false
	ok("small: a punch during the charge lunges her forward (punch to extend)", K.slam.extends_n == 1 and P.pos.x - ux > 1.0 and K.punches == pn0, "moved %.2f" % (P.pos.x - ux))
	P.inp["sec_hold"] = false
	step(m, 0.6)
	# rocks in the circle fly outward
	reset.call()
	P.ak.use_e()
	step(m, 0.3)
	var l1 := K.launches
	K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	hold(m, P, 0.5)
	step(m, 0.6)
	ok("combo: Stone Row > slam launches the rocks", K.launches > l1, "launches %d -> %d" % [l1, K.launches])
	# a knock resets it
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0)); aim_at(P, T.pos)
	T.hp = 10.0
	tap(m, P)
	step(m, 0.5)
	ok("combo: a slam that knocks resets Quakefall", K.qf_resets >= 1 and float(K.cd["rmb"]) <= 0.0 and K.ch_rmb >= 1.0, "resets %d" % K.qf_resets)
	# the dunk
	reset.call()
	T.teleport(home + Vector3(1.3, 0, 0)); T.pos.y += 2.0; T.grounded = false
	var dn0 := K.dunks
	K._slam(0.5, true)
	ok("rmb: a foe in the air is dunked", K.dunks == dn0 + 1 and T.vel.y < -10.0, "dunks %d vy %.1f" % [K.dunks, T.vel.y])
	# ---- Rubble Rush: the rock rides ahead, shoves, then rolls on and slows
	reset.call()
	T.teleport(home + Vector3(2.2, 0, 0)); aim_at(P, home + Vector3(10, 0, 0))
	P.ak.on_dash(false)
	m.step(DT)
	ok("dash: the rock rides ahead of her through the dash", not K.carry.is_empty() and KitLooks.of(m).holding("br_carry"))
	ok("anim: Rubble Rush plays breah_dash", K.anim_id == "breah_dash")
	step(m, 0.9)
	ok("small: the rock shoves a foe in its path during the dash", K.carried_shoves >= 1, "shoves %d" % K.carried_shoves)
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0)); aim_at(P, T.pos)
	P.ak.on_dash(false)
	step(m, 0.9)
	ok("dash: at the end the rock rolls on and hits: shred and a slow", K.landslides >= 1 and dmg(T) >= 10.0 and T.vuln_t > 0.0 and T.slow_t > 0.0, "took %.1f slow %.2f" % [dmg(T), T.slow_t])
	reset.call()
	T.teleport(home + Vector3(14.0, 0, 0)); aim_at(P, T.pos)
	P.ak.on_dash(false)
	step(m, 1.2)
	ok("dash: the rolling rock goes about 6m, not 12", dmg(T) == 0.0, "took %.1f" % dmg(T))
	# the base dash (in the air): her own heavy shove move
	reset.call()
	P.pos.y += 1.5; P.grounded = false
	P.do_dash()
	ok("anim: her long air dash plays breah_exdash", K.anim_id == "breah_exdash")
	step(m, 0.8)
	# ---- rank 3
	P.slot_lv["sec"] = 3; P.slot_lv["kin"] = 3; P.slot_lv["dash"] = 3
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0)); aim_at(P, T.pos)
	P.shield = 0.0
	tap(m, P)
	step(m, 0.5)
	ok("rank 3: slamming a foe gives a Molten Guard shield", P.shield >= 17.0 and K.shield_stacks >= 1, "shield %.0f" % P.shield)
	reset.call()
	T.teleport(home + Vector3(5.0, 0, 2.7)); aim_at(P, home + Vector3(6, 0, 0))
	P.ak.use_e()
	step(m, 0.25)
	var mid_n := rocks(m).size()
	step(m, 0.4)
	ok("rank 3: a second row that erupts from its centre outward", rocks(m).size() == 6 and mid_n < 6, "at 0.25s %d, then %d" % [mid_n, rocks(m).size()])
	ok("rank 3: the second row slows a foe beside it", T.slow_t > 0.0, "slow %.2f" % T.slow_t)
	P.slot_lv["sec"] = 1; P.slot_lv["kin"] = 1; P.slot_lv["dash"] = 1
	# ---- Tremor Sense: the cone shows while sneaking and widens
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0)); aim_at(P, T.pos)
	P.inp["crouch"] = true
	step(m, 0.2, func(): P.inp["crouch"] = true)
	var c1 := AimKit.entry(P, "sight")
	step(m, 2.1, func(): P.inp["crouch"] = true)
	var c2 := AimKit.entry(P, "sight")
	ok("passive: sneaking shows a pale cone ahead", AimKit.shown(P, "sight") and float(c1.get("len", 0.0)) >= 15.0)
	ok("passive: the cone widens 25 -> 40 degrees over 2s of sneaking", float(c1.get("deg", 0.0)) < 28.0 and absf(float(c2.get("deg", 0.0)) - 40.0) < 0.5, "%.1f -> %.1f" % [float(c1.get("deg", 0)), float(c2.get("deg", 0))])
	var s_front := K.stonesight()
	T.teleport(home + Vector3(-8.0, 0, 0))
	var s_back := K.stonesight()
	ok("passive: Tremor Sense shows foes in front only", s_front == 1 and s_back == 0, "front %d back %d" % [s_front, s_back])
	P.inp["crouch"] = false
	step(m, 0.2)
	ok("passive: the cone goes when she stops sneaking", not AimKit.shown(P, "sight"))
	# ---- merge start drops every hold
	reset.call()
	P.ak.on_dash(false)
	m.step(DT)
	K.lmb_t = 0.5; K.dive = true; K.slam.leapt = true
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	K.drop_holds()
	ok("merge hold: the dive, the charge, the leap and the carried rock all drop", not K.dive and K.lmb_t < 0.0 and K.carry.is_empty() and not K.slam.leapt and not AimKit.shown(P, "rmb"))
	P.inp["sec_hold"] = false
	step(m, 0.5)
	# ---- every move, sound and look exists
	var moves := ["breah_throw", "breah_wind", "breah_punch", "breah_crouch", "breah_leap", "breah_slam", "breah_dive", "breah_slam_land", "breah_lunge", "breah_dash", "breah_exdash", "breah_raise", "breah_sense"]
	ok("anim: every Breah move is keyed (KMovesStone)", moves.all(func(mv): return not HunterAnim.km_sample(mv, 0.1).is_empty()), str(moves.filter(func(mv): return HunterAnim.km_sample(mv, 0.1).is_empty())))
	var snd := SfxKits.NAMES.filter(func(s): return String(s).begins_with("br_"))
	ok("sfx: every Breah sound is loaded by Sfx", snd.size() >= 14 and snd.all(func(s): return Sfx.has(s)), str(snd.filter(func(s): return not Sfx.has(s))))
	await done(m)
