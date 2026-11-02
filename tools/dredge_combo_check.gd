extends RefCounted
## --dredge-combo-check: Dredge's abilities and their interactions, scripted one by one in the
## archetype check's flat training strip (docs/heroes/dredge.md, combinations table): the Grapnel
## reel, only the barge during it, reel into the Anchor Drop, walls and the abyss, the Salvage
## passive, the back hit, the barge's turn lock after the Anchor, the rank-3 specials, and the X ult,
## Brass Broadside (tools/dredge_ult_check.gd).

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
	await load("res://tools/dredge_ult_check.gd").new(ak, ok).run()
	print("DREDGECHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _all() -> void:
	var r: Array = ak.setup("dredge", 8.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: DredgeKit = P.ak
	var reset := func():
		P.teleport(home)
		P.vel = Vector3.ZERO
		P.roll_t = 0.0
		P.hp = P.max_hp
		P.stun_t = 0.0
		ak.fresh(T)
		T.out = false
		T.downed = false
		T.dead = false
		T.teleport(home + Vector3(8.0, 0, 0))
		T.face = PI / 2.0     # facing away (west is +PI/2 away from P: east-looking is -PI/2)
		K.cd["rmb"] = 0.0
		K.ch_rmb = 1.0
		K.cd["e"] = 0.0
		K.pull = {}
		K.flying = false
		K.wind = 0.0
		K.dive = {}
		K.scoop = []
		P.set_meta("gnd_until", 0.0)
		P.inp["move"] = Vector2.ZERO
		P.inp["fire"] = false
		T2.teleport(home + Vector3(-9.0, 0, 6.0))
		T2.downed = false
		P.dashes = P.max_dashes()
		P.fire_cd = 0.0
		ak.aim_at(P, T.pos)
	ok(
		"dredge: heavy, shotgun, 3 barge charges", P.wid == "shotgun" and P.cls == "heavy" and P.max_dashes() >= 3.0,
		"%s %s" % [P.wid, P.cls]
	)
	# --- the scattergun: a shot every 0.5s, a tight fan, the spread's edge lines while firing, one line idle
	reset.call()
	T.teleport(home + Vector3(0, 0, 9.0))
	ak.aim_at(P, home + Vector3(2.0, 0, 0))
	var v0: int = K.volleys
	var cone_seen := false
	var tf := 0.0
	while tf < 1.05:
		P.inp["fire"] = true
		ak.aim_at(P, home + Vector3(2.0, 0, 0))
		m.step(ak.DT)
		tf += ak.DT
		if AimKit.shown(P, "spread"): cone_seen = true
	P.inp["fire"] = false
	var cone: Dictionary = AimKit.entry(P, "spread")
	ok(
		"gun: a shot every half second",
		K.volleys - v0 >= 2 and K.volleys - v0 <= 3 and absf(float(P.wpn["rate"]) - 0.5) < 0.01,
		"volleys %d in 1.05s" % (K.volleys - v0)
	)
	ok(
		"gun: the spread's edge lines lie on the ground out to the slug range",
		cone_seen and absf(float(cone.get("len", 0.0)) - 6.3) < 0.3 and float(cone.get("deg", 0.0)) >= 30.0 and float(cone.get("deg", 0.0)) <= 46.0,
		"len %.1f deg %.0f" % [float(cone.get("len", 0.0)), float(cone.get("deg", 0.0))]
	)
	ok("gun: each shot rocks the body back (dr_shot)", K.anim_id == "dr_shot")
	ak.step(m, 1.0)
	ok("gun: idle, the cone folds into one aim line", AimKit.shown(P, "spread_idle") and not AimKit.shown(P, "spread"))
	P.ammo = int(P.wpn["mag"])
	P.reload_t = 0.0
	# --- Grapnel reels a foe in; they land Grounded
	reset.call()
	ak.tap(m, P)
	ak.step(m, 0.3)
	var d0 := P.flat_dist(T)
	ok(
		"grapnel: hooks the first foe, reel begins",
		K.grapples == 1 and not K.pull.is_empty() and ak.dmg(T) >= 5.0 and float(K.cd["rmb"]) > 8.0,
		"grapples %d took %.1f cd %.1f" % [K.grapples, ak.dmg(T), float(K.cd["rmb"])]
	)
	ok(
		"reel: Dredge is Grounded while he reels, the foe is stunned",
		KitStatus.grounded(P) and T.stun_t > 0.0 and K.fx.shown("chain%d" % P.get_instance_id()),
		"gnd %s stun %.2f" % [KitStatus.grounded(P), T.stun_t]
	)
	ok("reel: the braided rope is drawn (through rocks)", K.fx.rope_shown("rope%d" % P.get_instance_id()))
	# --- during the reel: RMB, E and the gun are locked, the barge works
	var ch0 := K.ch_rmb
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	ak.tap(m, P)
	ok("reel: a second Grapnel is denied", K.grapples == 1)
	K.cd["e"] = 0.0
	P.ak.use_e()
	ok("reel: E is denied while reeling", K.anchors == 0 and K.wind <= 0.0)
	ok("reel: the gun is locked", not K.can_shoot())
	var pos0 := P.pos
	ak.aim_at(P, T.pos)
	P.inp["move"] = Vector2.ZERO
	P.ak.on_dash(false)
	ak.step(m, 0.15)
	ok(
		"reel: the barge still works", P.flat_dist(pos0) > 1.5 and P.dashes < P.max_dashes(),
		"moved %.1f" % P.flat_dist(pos0)
	)
	var tw := 0.0
	while K.arrivals < 1 and tw < 3.0:
		ak.step(m, 0.05)
		tw += 0.05
	ok(
		"grapnel: foe arrives and lands Grounded",
		K.arrivals == 1 and K.pull.is_empty() and KitStatus.grounded(T) and P.flat_dist(T) < 3.6,
		"arrivals %d dist %.1f (was %.1f)" % [K.arrivals, P.flat_dist(T), d0]
	)
	ok("reel: Dredge's own Grounded ends with the reel", not KitStatus.grounded(P))
	# --- reel then Anchor Drop on the Grounded foe
	ak.fresh(T)
	T.teleport(P.pos + Vector3(2.0, 0, 0))
	ak.aim_at(P, T.pos)
	K.cd["e"] = 0.0
	var hp0: float = ak.dmg(T)
	var hop0 := P.pos
	P.ak.use_e()
	ak.step(m, 0.3)
	var early := K.anchors
	ak.step(m, 0.2)
	ok(
		"anchor: hop about a body length forward, the slam lands at ~0.38s",
		early == 0 and K.anchors == 1 and P.flat_dist(hop0) > 1.2 and P.flat_dist(hop0) < 2.4,
		"anchors at 0.3s %d, hop %.1f m" % [early, P.flat_dist(hop0)]
	)
	ok(
		"combo: reel > Anchor Drop = damage, stun, Grounded",
		K.anchors == 1 and ak.dmg(T) - hp0 >= 20.0 and KitStatus.grounded(T) and T.stun_t > 0.8,
		"anchors %d took %.0f stun %.2f" % [K.anchors, ak.dmg(T) - hp0, T.stun_t]
	)
	ok("anchor: the stunned foe shows a stun spiral", K.fx.shown("spiral%d" % T.get_instance_id()))
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
	ok(
		"combo: Anchor > barge turns at most 35 degrees",
		mv.length() > 1.0 and absf(rad_to_deg(fwd.angle_to(mv))) <= 40.0,
		"moved %.1f angle %.0f" % [mv.length(), rad_to_deg(fwd.angle_to(mv))]
	)
	# --- walls: the hook stops at a wall, a reel can't pass one
	reset.call()
	var W = m.world
	var hx := int(floor(home.x))
	var hz := int(floor(home.z))
	for dz in range(-6, 7):
		W.level[W.idx(hx + 4, hz + dz)] = lv + 4
	var g0 := K.grapples
	ak.tap(m, P)
	ak.step(m, 0.5)
	ok(
		"cliff: a cliff face stops the hook, nobody is pulled",
		K.grapples == g0 and K.pull.is_empty() and P.flat_dist(T) > 7.5 and ak.dmg(T) < 1.0,
		"grapples +%d dist %.1f" % [K.grapples - g0, P.flat_dist(T)]
	)
	for dz in range(-6, 7):
		W.level[W.idx(hx + 4, hz + dz)] = lv
	# hook first, then a wall rises in the reel's path
	reset.call()
	ak.tap(m, P)
	ak.step(m, 0.12)
	for dz in range(-6, 7):
		W.level[W.idx(hx + 4, hz + dz)] = lv + 4
	ak.step(m, 3.4)
	ok(
		"cliff: a reel is stopped by a cliff face, the foe stays behind it",
		T.pos.x > home.x + 4.4 and K.pull.is_empty(),
		"foe x %.1f wall x %.1f snags %d" % [T.pos.x - home.x, 4.0, K.snags]
	)
	for dz in range(-6, 7):
		W.level[W.idx(hx + 4, hz + dz)] = lv
	# --- rocks: the hook flies over a rock and the foe is dragged over it
	reset.call()
	for dz in range(-1, 2):
		W.kind[W.idx(hx + 4, hz + dz)] = World.T_BLOCK
	ak.tap(m, P)
	var h0: int = K.hauled
	var g1: int = K.grapples
	ak.step(m, 2.2)
	ok(
		"rocks: the hook goes over a rock and drags the foe over it",
		K.grapples == g1 + 1 and K.hauled > h0 and T.pos.x < home.x + 4.0 and P.flat_dist(T) < 3.0,
		"hauled %d foe x %.1f dist %.1f" % [K.hauled - h0, T.pos.x - home.x, P.flat_dist(T)]
	)
	var tw2 := 0.0
	for dz in range(-1, 2):
		W.kind[W.idx(hx + 4, hz + dz)] = World.T_GROUND
	ak.step(m, 1.0)
	# --- the reel has weight: walking sideways while reeling swings the body round you
	reset.call()
	ak.tap(m, P)
	ak.step(m, 0.25)
	var start := T.pos
	var dev := 0.0
	var p_start := P.pos
	tw2 = 0.0
	while not K.pull.is_empty() and tw2 < 3.0:
		ak.step(m, 0.02, func(): P.inp["move"] = Vector2(0, -1))
		tw2 += 0.02
		var a2 := Vector2(start.x, start.z)
		var b2 := Vector2(P.pos.x, P.pos.z)
		var tp := Vector2(T.pos.x, T.pos.z)
		dev = maxf(dev, tp.distance_to(Geometry2D.get_closest_point_to_segment(tp, a2, b2)))
	P.inp["move"] = Vector2.ZERO
	ok(
		"reel: strafing sideways shifts the arrival point by 1.5m or more",
		absf(T.pos.z - start.z) >= 1.5 and K.arrivals >= 1,
		"arrival shift %.1f m (Dredge moved %.1f)" % [absf(T.pos.z - start.z), P.flat_dist(p_start)]
	)
	ok("reel: the body swings on an arc, not a straight line", dev > 0.3, "off the straight line by %.2f m" % dev)
	# --- an ally in the hook's path is reeled to safety (no damage, no stun); a wisp on the way is scooped up
	reset.call()
	var t2team := T2.team
	T2.team = P.team
	ak.fresh(T2)
	T2.out = false
	T2.downed = false
	T2.dead = false
	T2.teleport(home + Vector3(4.0, 0, 0))
	ak.aim_at(P, T.pos)
	ak.tap(m, P)
	ak.step(m, 0.4)
	ok(
		"ally: the hook catches an ally in its path and reels them in",
		not K.pull.is_empty() and K.pull["t"] == T2 and T2.stun_t <= 0.0 and ak.dmg(T2) == 0.0,
		"pull %s" % [K.pull.get("t") == T2]
	)
	ak.step(m, 1.5)
	ok(
		"ally: they arrive safe (not Grounded)",
		K.pull.is_empty() and not KitStatus.grounded(T2) and P.flat_dist(T2) < 2.5, "dist %.1f" % P.flat_dist(T2)
	)
	T2.team = t2team
	reset.call()
	ak.fresh(T2)
	T2.out = false
	T2.dead = false
	T2.teleport(home + Vector3(4.0, 0, 0.3))
	m.knock(T2, P, {})
	var w0 := P.flat_dist(T2)
	ak.tap(m, P)
	var wmin := w0
	var tws := 0.0
	while tws < 1.6:
		m.step(ak.DT)
		tws += ak.DT
		wmin = minf(wmin, P.flat_dist(T2))
	ok(
		"wisp: a downed hunter the hook passes is scooped up with the catch", P.flat_dist(T2) < w0 - 1.2,
		"wisp %.1f -> %.1f" % [w0, P.flat_dist(T2)]
	)
	T2.downed = false
	T2.teleport(home + Vector3(-9.0, 0, 6.0))
	# --- Anchor Drop in the air: straight down, the anchor with you, a ring at the landing, height adds damage
	reset.call()
	T.teleport(home + Vector3(2.0, 0, 0))
	ak.aim_at(P, T.pos)
	hp0 = ak.dmg(T)
	P.ak.use_e()
	ak.step(m, 0.6)
	var low: float = ak.dmg(T) - hp0
	reset.call()
	T.teleport(home + Vector3(1.6, 0, 0))
	ak.aim_at(P, T.pos)
	P.teleport(home + Vector3(0, 6.0, 0))
	P.grounded = false
	P.vel = Vector3.ZERO
	m.step(ak.DT)
	hp0 = ak.dmg(T)
	var q0 := K.quakes
	P.ak.use_e()
	var land_seen := false
	var anchor_seen := false
	var vy := 0.0
	var te := 0.0
	while te < 1.2 and K.quakes == q0:
		ak.step(m, ak.DT)
		te += ak.DT
		vy = minf(vy, P.vel.y)
		if AimKit.shown(P, "e_land"): land_seen = true
		if K.fx.shown("dive_anchor%d" % P.get_instance_id()): anchor_seen = true
	var high: float = ak.dmg(T) - hp0
	ok(
		"air smash: straight down at once", vy <= -20.0 and absf(P.pos.x - home.x) < 0.4,
		"vy %.1f drift %.2f" % [vy, P.pos.x - home.x]
	)
	ok("air smash: the landing ring shows while you fall, the anchor falls with you", land_seen and anchor_seen)
	ok(
		"air smash: it lands where you land, a ring of damage and stun",
		K.quakes == q0 + 1 and high > 0.0 and T.stun_t > 0.5, "quakes %d stun %.2f" % [K.quakes - q0, T.stun_t]
	)
	ok(
		"air smash: height adds damage (6m: about +50%)", low > 20.0 and high >= low * 1.3 and K.last_quake_k > 1.4,
		"on foot %.0f from 6m %.0f k %.2f" % [low, high, K.last_quake_k]
	)
	reset.call()
	P.slot_lv["kin"] = 3
	P.teleport(home + Vector3(0, 6.0, 0))
	P.grounded = false
	P.vel = Vector3.ZERO
	m.step(ak.DT)
	q0 = K.quakes
	P.ak.use_e()
	te = 0.0
	while te < 1.2 and K.quakes == q0:
		ak.step(m, ak.DT)
		te += ak.DT
	ok("air smash rank 3: up to +75% by height", K.last_quake_k > 1.6, "k %.2f" % K.last_quake_k)
	P.slot_lv["kin"] = 1
	for dz in range(-3, 4):
		for dx in range(-2, 3):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_VOID
	reset.call()
	P.teleport(home + Vector3(0, 0.5, 0))
	P.grounded = false
	P.vel = Vector3.ZERO
	q0 = K.quakes
	K._anchor()
	ok("abyss: the Anchor never pushes you down over the void", P.vel.y > -13.0 and K.quakes == q0, "vy %.1f" % P.vel.y)
	for dz in range(-3, 4):
		for dx in range(-2, 3):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_GROUND
	# --- the barge goes further in the air
	reset.call()
	T.teleport(home + Vector3(0, 0, 9.0))
	ak.aim_at(P, home + Vector3(9.0, 0, 0))
	P.ak.on_dash(false)
	var feel: Dictionary = K.dash_feel()
	var one: float = float(K.dash_def()["dist"]) * float(feel["dist"])
	var dash_t: float = float(K.dash_def()["time"]) * float(feel["time"])
	ak.step(m, dash_t * 0.5)
	var half_d := P.pos.x - home.x
	ak.step(m, 0.4)
	var ground_d := P.pos.x - home.x
	ok(
		"barge: a short, fast shove you see travel (about half way at half its time), then he stops",
		half_d > one * 0.3 and half_d < one * 0.8 and absf(ground_d - one) < 0.6 and dash_t < 0.25,
		"at %.2fs %.1f, settled %.1f of %.1f" % [dash_t * 0.5, half_d, ground_d, one]
	)
	# a run of barges: three charges, a short gap between them
	reset.call()
	T.teleport(home + Vector3(0, 0, 9.0))
	ak.aim_at(P, home + Vector3(12.0, 0, 0))
	var charges0 := P.dashes
	P.ak.on_dash(false)
	ak.step(m, 0.05)
	P.ak.on_dash(false)
	var in_gap := charges0 - P.dashes
	ak.step(m, dash_t + float(K.dash_def()["gap"]))
	P.ak.on_dash(false)
	ak.step(m, dash_t + float(K.dash_def()["gap"]))
	P.ak.on_dash(false)
	ak.step(m, 0.5)
	ok(
		"barge: three in a row, a short gap between (a press inside the gap does nothing)",
		absf(in_gap - 1.0) < 0.01 and P.dashes < 0.5 and P.pos.x - home.x > one * 2.6,
		"used in gap %.1f left %.2f went %.1f" % [in_gap, P.dashes, P.pos.x - home.x]
	)
	reset.call()
	T.teleport(home + Vector3(0, 0, 9.0))
	P.teleport(home + Vector3(0, 3.0, 0))
	P.grounded = false
	P.vel = Vector3.ZERO
	P.ex_cd = 0.0
	ak.aim_at(P, home + Vector3(9.0, 0, 0))
	P.ak.on_dash(true)
	ak.step(m, dash_t + 0.02)
	var air_quick := P.pos.x - home.x
	ak.step(m, 0.3)
	var air_d := P.pos.x - home.x
	ok(
		"barge: in the air the same quick time, 35% further", air_quick > one * 1.2,
		"air after %.2fs %.1f, ground %.1f" % [dash_t, air_quick, one]
	)
	ok(
		"barge: further in the air than on the ground", air_d > ground_d * 1.15 and ground_d > 2.0,
		"ground %.1f air %.1f" % [ground_d, air_d]
	)
	# --- Salvage: knocks stack, +2.5% health each, a knock heals, losing one when downed
	reset.call()
	P.slot_lv["kin"] = 1
	var mh0 := P.max_hp
	P.hp = P.max_hp * 0.5
	K.on_knock(T, true)
	ok(
		"passive: a knock = 1 stack, +2.5% health, a heal",
		K.res == 1.0 and absf(P.max_hp - mh0 * 1.025) < 0.5 and P.hp > mh0 * 0.5 + mh0 * 0.15,
		"res %.0f maxhp %.1f hp %.1f" % [K.res, P.max_hp, P.hp]
	)
	var hp1 := P.hp
	K.on_knock(T, false)
	ok("passive: an assist stacks but does not heal", K.res == 2.0 and P.hp <= hp1 + P.max_hp * 0.03 + 0.5)
	for i in 12: K.on_knock(T, false)
	ok(
		"passive: capped at 10 stacks (+25%)", K.res == 10.0 and absf(P.max_hp - mh0 * 1.25) < 0.5,
		"res %.0f maxhp %.1f" % [K.res, P.max_hp]
	)
	P.downed = true
	K._tick(0.016)
	P.downed = false
	ok("passive: being downed costs a stack", K.res == 9.0 and K.stacks_lost == 1)
	# --- a hit on the back deals 50% more
	reset.call()
	# looking east, away from... T is east of P, so facing east = away from P
	T.face = PI / 2.0 * 0.0 + (-PI / 2.0)
	var behind := K.outgoing(T, 10.0, {})
	T.face = PI / 2.0
	var front := K.outgoing(T, 10.0, {})
	ok(
		"passive: from behind +50%, from the front none", absf(behind - 15.0) < 0.01 and absf(front - 10.0) < 0.01,
		"behind %.1f front %.1f" % [behind, front]
	)
	# --- rank 3: the grapnel refunds on a hit, pellet hits trim the barge recharge
	reset.call()
	P.slot_lv["sec"] = 3
	P.slot_lv["dash"] = 3
	ak.tap(m, P)
	ak.step(m, 0.3)
	ok(
		"grapnel rank 3: a hit refunds a third of the cooldown",
		float(K.cd["rmb"]) < 11.0 * 0.7 + 0.5 and K.grapples >= 1, "cd %.1f" % float(K.cd["rmb"])
	)
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
	ok(
		"abyss: a foe reeled over the void falls (knock rules)",
		K.arrivals == a0 and (T.out or T.downed or T.dead or P.flat_dist(T) > 3.0),
		"out %s y %.1f x %.1f" % [str(T.out), T.pos.y - home.y, T.pos.x - home.x]
	)
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
	ok(
		"merge hold: dredge's reel ends with the merge, the rope is freed, nobody lands Grounded",
		K.pull.is_empty() and (rope == null or not is_instance_valid(rope) or rope.is_queued_for_deletion()) and K.arrivals == ar0 and not KitStatus.grounded(T),
		"pull %s arrivals %d" % [not K.pull.is_empty(), K.arrivals - ar0]
	)
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
	ok(
		"merge hold: dredge's Anchor wind-up is dropped, no slam mid-merge", K.wind <= 0.0 and K.anchors == an0,
		"wind %.2f anchors %d" % [K.wind, K.anchors - an0]
	)
	m.queue_free()
	await main.get_tree().process_frame
