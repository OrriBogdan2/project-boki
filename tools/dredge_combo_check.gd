extends RefCounted
## --dredge-combo-check: Dredge's abilities and their interactions, scripted one by one in the
## archetype check's flat training strip (docs/heroes/dredge.md, combinations table): the Grapnel
## reel, only the barge during it, reel into the Anchor Drop, walls and the abyss, the Salvage
## passive, the back hit, the barge's turn lock after the Anchor, and the rank-3 specials.

var main: Node
var fails := 0
var n := 0
var ak = null

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	print("DREDGECHECK %-52s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	await _all()
	print("DREDGECHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _all() -> void:
	var r: Array = ak.setup("dredge", 8.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	var home: Vector3 = r[4]; var lv: int = r[5]
	var K: DredgeKit = P.ak
	var reset := func():
		P.teleport(home); P.vel = Vector3.ZERO; P.roll_t = 0.0; P.hp = P.max_hp; P.stun_t = 0.0
		ak.fresh(T); T.out = false; T.downed = false; T.dead = false; T.teleport(home + Vector3(8.0, 0, 0)); T.face = PI / 2.0     # facing away (west is +PI/2 away from P: east-looking is -PI/2)
		K.cd["rmb"] = 0.0; K.ch_rmb = 1.0; K.cd["e"] = 0.0; K.pull = {}; K.flying = false; K.wind = 0.0
		P.dashes = P.max_dashes(); P.fire_cd = 0.0
		ak.aim_at(P, T.pos)
	ok("dredge: heavy, shotgun, 2 barge charges", P.wid == "shotgun" and P.cls == "heavy" and P.max_dashes() >= 2.0, "%s %s" % [P.wid, P.cls])
	# --- Grapnel reels a foe in; they land Grounded
	reset.call()
	ak.tap(m, P)
	ak.step(m, 0.3)
	var d0 := P.flat_dist(T)
	ok("grapnel: hooks the first foe, reel begins", K.grapples == 1 and not K.pull.is_empty() and ak.dmg(T) >= 5.0 and float(K.cd["rmb"]) > 8.0, "grapples %d took %.1f cd %.1f" % [K.grapples, ak.dmg(T), float(K.cd["rmb"])])
	# --- during the reel: RMB, E and the gun are locked, the barge works
	var ch0 := K.ch_rmb
	K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	ak.tap(m, P)
	ok("reel: a second Grapnel is denied", K.grapples == 1)
	K.cd["e"] = 0.0
	P.ak.use_e()
	ok("reel: E is denied while reeling", K.anchors == 0 and K.wind <= 0.0)
	ok("reel: the gun is locked", not K.can_shoot())
	var pos0 := P.pos
	ak.aim_at(P, T.pos); P.inp["move"] = Vector2.ZERO
	P.ak.on_dash(false)
	ak.step(m, 0.15)
	ok("reel: the barge still works", P.flat_dist(pos0) > 1.5 and P.dashes < P.max_dashes(), "moved %.1f" % P.flat_dist(pos0))
	var tw := 0.0
	while K.arrivals < 1 and tw < 3.0:
		ak.step(m, 0.05); tw += 0.05
	ok("grapnel: foe arrives and lands Grounded", K.arrivals == 1 and K.pull.is_empty() and KitStatus.grounded(T) and P.flat_dist(T) < 3.6, "arrivals %d dist %.1f (was %.1f)" % [K.arrivals, P.flat_dist(T), d0])
	# --- reel then Anchor Drop on the Grounded foe
	ak.fresh(T); T.teleport(P.pos + Vector3(2.0, 0, 0)); ak.aim_at(P, T.pos); K.cd["e"] = 0.0
	var hp0: float = ak.dmg(T)
	P.ak.use_e()
	ak.step(m, 0.5)
	ok("combo: reel > Anchor Drop = damage, stun, Grounded", K.anchors == 1 and ak.dmg(T) - hp0 >= 20.0 and KitStatus.grounded(T), "anchors %d took %.0f stun %.2f" % [K.anchors, ak.dmg(T) - hp0, T.stun_t])
	ok("anchor: E cooldown set", float(K.cd["e"]) > 5.0)
	# --- Barge right after the Anchor can't turn
	reset.call()
	P.face = -PI / 2.0
	K.lock_until = m.time + 0.8
	ak.aim_at(P, home + Vector3(-8.0, 0, 0))
	var p1 := P.pos
	var fwd := Vector2(-sin(P.face), -cos(P.face))
	P.ak.on_dash(false)
	ak.step(m, 0.3)
	var mv := Vector2(P.pos.x - p1.x, P.pos.z - p1.z)
	ok("combo: Anchor > barge turns at most 35 degrees", mv.length() > 1.0 and absf(rad_to_deg(fwd.angle_to(mv))) <= 40.0, "moved %.1f angle %.0f" % [mv.length(), rad_to_deg(fwd.angle_to(mv))])
	# --- walls: the hook stops at a wall, a reel can't pass one
	reset.call()
	var W = m.world
	var hx := int(floor(home.x)); var hz := int(floor(home.z))
	for dz in range(-6, 7):
		W.level[W.idx(hx + 4, hz + dz)] = lv + 4
	var g0 := K.grapples
	ak.tap(m, P)
	ak.step(m, 0.5)
	ok("wall: the hook stops at the wall, nobody is pulled", K.grapples == g0 and K.pull.is_empty() and P.flat_dist(T) > 7.5 and ak.dmg(T) < 1.0, "grapples +%d dist %.1f" % [K.grapples - g0, P.flat_dist(T)])
	for dz in range(-6, 7):
		W.level[W.idx(hx + 4, hz + dz)] = lv
	# hook first, then a wall rises in the reel's path
	reset.call()
	ak.tap(m, P)
	ak.step(m, 0.12)
	for dz in range(-6, 7):
		W.level[W.idx(hx + 4, hz + dz)] = lv + 4
	ak.step(m, 3.4)
	ok("wall: a reel is stopped by a wall, the foe stays behind it", T.pos.x > home.x + 4.4 and K.pull.is_empty(), "foe x %.1f wall x %.1f snags %d" % [T.pos.x - home.x, 4.0, K.snags])
	for dz in range(-6, 7):
		W.level[W.idx(hx + 4, hz + dz)] = lv
	# --- Anchor in the air drives you down, but not over the abyss; rank 3 adds height damage
	reset.call()
	P.slot_lv["kin"] = 3
	T.teleport(home + Vector3(2.0, 0, 0)); ak.aim_at(P, T.pos)
	hp0 = ak.dmg(T)
	P.ak.use_e()
	ak.step(m, 0.6)
	var low: float = ak.dmg(T) - hp0
	reset.call()
	P.teleport(home + Vector3(0, 5.0, 0)); P.grounded = false; P.vel = Vector3.ZERO
	T.teleport(home + Vector3(2.0, 4.6, 0)); T.grounded = false; T.vel = Vector3.ZERO; ak.aim_at(P, T.pos)
	hp0 = ak.dmg(T)
	P.ak.use_e()
	var vy := 0.0
	var te := 0.0
	while te < 0.5:
		ak.step(m, 0.02); te += 0.02
		if K.anchors >= 2 and vy == 0.0: vy = float(K.st.get("dive_vy", 0.0))
		T.vel = Vector3.ZERO if K.anchors < 2 else T.vel
		T.pos.y = maxf(T.pos.y, 3.5) if K.anchors < 2 else T.pos.y
	var high: float = ak.dmg(T) - hp0
	ok("anchor: in the air it drives you down", vy <= -10.0, "vy %.1f" % vy)
	ok("anchor rank 3: height adds damage (up to +75%)", low > 20.0 and high >= low * 1.2, "grounded %.0f in the air %.0f" % [low, high])
	P.slot_lv["kin"] = 1
	for dz in range(-3, 4):
		for dx in range(-2, 3):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_VOID
	P.teleport(home + Vector3(0, 0.5, 0)); P.grounded = false; P.vel = Vector3.ZERO
	K._anchor()
	ok("abyss: the Anchor never pushes you down over the void", P.vel.y > -13.0, "vy %.1f" % P.vel.y)
	for dz in range(-3, 4):
		for dx in range(-2, 3):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_GROUND
	# --- Salvage: knocks stack, +2.5% health each, a knock heals, losing one when downed
	reset.call()
	P.slot_lv["kin"] = 1
	var mh0 := P.max_hp
	P.hp = P.max_hp * 0.5
	K.on_knock(T, true)
	ok("passive: a knock = 1 stack, +2.5% health, a heal", K.res == 1.0 and absf(P.max_hp - mh0 * 1.025) < 0.5 and P.hp > mh0 * 0.5 + mh0 * 0.15, "res %.0f maxhp %.1f hp %.1f" % [K.res, P.max_hp, P.hp])
	var hp1 := P.hp
	K.on_knock(T, false)
	ok("passive: an assist stacks but does not heal", K.res == 2.0 and P.hp <= hp1 + P.max_hp * 0.03 + 0.5)
	for i in 12: K.on_knock(T, false)
	ok("passive: capped at 10 stacks (+25%)", K.res == 10.0 and absf(P.max_hp - mh0 * 1.25) < 0.5, "res %.0f maxhp %.1f" % [K.res, P.max_hp])
	P.downed = true
	K._tick(0.016)
	P.downed = false
	ok("passive: being downed costs a stack", K.res == 9.0 and K.stacks_lost == 1)
	# --- a hit on the back deals 50% more
	reset.call()
	T.face = PI / 2.0 * 0.0 + (-PI / 2.0)       # looking east, away from... T is east of P, so facing east = away from P
	var behind := K.outgoing(T, 10.0, {})
	T.face = PI / 2.0
	var front := K.outgoing(T, 10.0, {})
	ok("passive: from behind +50%, from the front none", absf(behind - 15.0) < 0.01 and absf(front - 10.0) < 0.01, "behind %.1f front %.1f" % [behind, front])
	# --- rank 3: the grapnel refunds on a hit, pellet hits trim the barge recharge
	reset.call()
	P.slot_lv["sec"] = 3; P.slot_lv["dash"] = 3
	ak.tap(m, P)
	ak.step(m, 0.3)
	ok("grapnel rank 3: a hit refunds a third of the cooldown", float(K.cd["rmb"]) < 11.0 * 0.7 + 0.5 and K.grapples >= 1, "cd %.1f" % float(K.cd["rmb"]))
	P.dashes = 0.0
	K.on_deal(T, 3.0, {"src": "shot"})
	ok("barge rank 3: a pellet hit trims the recharge", P.dashes > 0.01, "dashes %.3f" % P.dashes)
	# --- the abyss: a foe reeled over a gap falls
	reset.call()
	for dz in range(-6, 7):
		for dx in range(3, 6):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_VOID
	var a0 := K.arrivals
	ak.tap(m, P)
	ak.step(m, 2.5)
	ok("abyss: a foe reeled over the void falls (knock rules)", K.arrivals == a0 and (T.out or T.downed or T.dead or P.flat_dist(T) > 3.0), "out %s y %.1f x %.1f" % [str(T.out), T.pos.y - home.y, T.pos.x - home.x])
	for dz in range(-6, 7):
		for dx in range(3, 6):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_GROUND
	# --- a Boki merge that starts mid-reel / mid-wind-up ends them: the rope goes, no Anchor slam, no landing hit
	reset.call()
	ak.tap(m, P)
	ak.step(m, 0.3)
	var reeling: bool = not K.pull.is_empty()
	ok("merge hold: the reel is under way before the merge", reeling, "pull %s" % reeling)
	var rope: Node3D = K.pull.get("node")
	var ar0 := K.arrivals
	ok("merge hold: a merge is under way", ak.merge_now(P))
	ak.step(m, 0.1)
	ok("merge hold: dredge's reel ends with the merge, the rope is freed, nobody lands Grounded", K.pull.is_empty() and (rope == null or not is_instance_valid(rope) or rope.is_queued_for_deletion()) and K.arrivals == ar0 and not KitStatus.grounded(T), "pull %s arrivals %d" % [not K.pull.is_empty(), K.arrivals - ar0])
	KinMerge.end(P, "test")
	P.merge_cd = 0.0
	reset.call()
	P.hp = P.max_hp
	K.cd["e"] = 0.0
	K.cast_e()
	ak.step(m, 0.1)
	var winding: bool = K.wind > 0.0
	var an0 := K.anchors
	ok("merge hold: the Anchor is winding up before the merge", winding, "wind %.2f" % K.wind)
	ok("merge hold: a merge is under way", ak.merge_now(P))
	ak.step(m, 1.2)
	ok("merge hold: dredge's Anchor wind-up is dropped, no slam mid-merge", K.wind <= 0.0 and K.anchors == an0, "wind %.2f anchors %d" % [K.wind, K.anchors - an0])
	m.queue_free()
	await main.get_tree().process_frame
