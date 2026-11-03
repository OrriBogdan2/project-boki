extends RefCounted
## --dredge-combo-check: Dredge's abilities and their interactions, scripted one by one in the
## archetype check's flat training strip (docs/heroes/dredge.md, combinations table): the Grapnel
## reel, only the barge during it, reel into the Anchor Drop, terrain the hook pierces, the abyss, the Salvage
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
	await _hook_hold()
	await _slam_tell()
	await _dash_moves()
	await load("res://tools/dredge_ult_check.gd").new(ak, ok).run()
	print("DREDGECHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Item 31 (CastHold): from the throw until the miss or the end of the reel he keeps his height mid-air (no
## fall); while the hook flies out he walks at 15-25% of his walk; gravity is back once it ends.
func _hook_hold() -> void:
	var r: Array = ak.setup("dredge", 6.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: DredgeKit = P.ak
	# on the ground: his walk, then the walk while a hook flies out at nobody
	ak.aim_at(P, home + Vector3(0, 0, -10.0))
	P.inp["move"] = Vector2(1, 0)
	ak.step(m, 0.3)
	var p0 := P.pos
	ak.step(m, 0.2)
	var walk := P.flat_dist(p0) / 0.2
	ak.tap(m, P)
	ak.step(m, 0.05)
	p0 = P.pos
	ak.step(m, 0.25)
	var crawl := P.flat_dist(p0) / 0.25
	var k := crawl / maxf(0.01, walk)
	ok(
		"hook hold: while the hook flies out he walks at 15-25% speed",
		K.flying and k >= 0.15 and k <= 0.25, "%.2f of %.1f m/s" % [k, walk]
	)
	ak.step(m, 0.5)
	P.inp["move"] = Vector2.ZERO
	# mid-air, a hook that misses: no fall while it flies, gravity the moment it ends
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	P.teleport(home + Vector3(0, 3.0, 0))
	P.vel = Vector3.ZERO
	P.grounded = false
	ak.tap(m, P)
	var y0 := P.pos.y
	var drift := 0.0
	P.inp["move"] = Vector2(1, 0)
	ak.step(m, 0.1)
	var a0 := P.pos
	ak.step(m, 0.2)
	var air_k := P.flat_dist(a0) / 0.2 / maxf(0.01, walk)
	P.inp["move"] = Vector2.ZERO
	while K.flying:
		ak.step(m, ak.DT)
		drift = maxf(drift, absf(P.pos.y - y0))
	drift = maxf(drift, absf(P.pos.y - y0))
	var y_end := P.pos.y
	ak.step(m, 0.25)
	ok(
		"hook hold: mid-air his height holds while the hook flies (a slow drift), and he falls once it misses",
		drift <= 0.05 and y_end - P.pos.y > 0.2 and air_k >= 0.15 and air_k <= 0.25,
		"drift %.3f, walk %.2f of his speed, then fell %.2f m" % [drift, air_k, y_end - P.pos.y]
	)
	# a knock during the hold still shoves him (only the height is held)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	P.teleport(home + Vector3(0, 3.0, 0))
	P.vel = Vector3.ZERO
	P.grounded = false
	ak.tap(m, P)
	var k0 := P.pos
	P.impulse(Vector2(0, 1) * 8.0 * P.mass())
	ak.step(m, 0.2)
	ok(
		"hook hold: a knock during the hold still shoves him, height held",
		K.flying and P.flat_dist(k0) > 0.6 and absf(P.pos.y - k0.y) <= 0.05,
		"shoved %.2f m, height %+.3f" % [P.flat_dist(k0), P.pos.y - k0.y]
	)
	ak.step(m, 0.6)
	# mid-air, a hook that catches: held from the throw to the end of the reel
	P.teleport(home + Vector3(0, 1.0, 0))
	P.vel = Vector3.ZERO
	P.grounded = false
	ak.fresh(T)
	T.teleport(home + Vector3(6.0, 0, 0))
	ak.aim_at(P, T.pos)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	ak.tap(m, P)
	y0 = P.pos.y
	drift = 0.0
	var tw := 0.0
	while (K.flying or not K.pull.is_empty()) and tw < 4.0:
		ak.step(m, ak.DT)
		tw += ak.DT
		drift = maxf(drift, absf(P.pos.y - y0))
	ok(
		"hook hold: mid-air his height holds from the throw to the end of the reel",
		K.grapples >= 1 and K.arrivals >= 1 and drift <= 0.05, "grapples %d arrivals %d drift %.3f" % [
			K.grapples, K.arrivals, drift]
	)
	await ak.done(m)

## Item 33: through the wind-up the slam's area fills on the ground, for everyone, and it is the exact cone
## the slam hits: a foe just inside its edge is hit, one just outside is not, and only on the slam frame.
func _slam_tell() -> void:
	var r: Array = ak.setup("dredge", 6.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: DredgeKit = P.ak
	var ed: Dictionary = K.e_def()
	var half := deg_to_rad(float(ed["angle"]) * 0.5)
	var reach := float(ed["radius"])
	# aim straight along +x; one foe inside the edge of the cone, one just past it (outside the angle)
	ak.aim_at(P, home + Vector3(5.0, 0, 0))
	T.teleport(home + Vector3(cos(half - 0.25), 0, sin(half - 0.25)) * (reach - 0.4))
	T2.teleport(home + Vector3(cos(half + 0.35), 0, sin(half + 0.35)) * (reach - 0.4))
	ak.fresh(T)
	ak.fresh(T2)
	K.cd["e"] = 0.0
	P.ak.use_e()
	ak.step(m, 0.2)
	var tell: Dictionary = AimKit.entry(P, "e_tell")
	var tdir: Vector2 = tell.get("dir", Vector2.ZERO)
	var fill_mid := float(tell.get("fill", 0.0))
	ok(
		"anchor tell: the hit cone is drawn for everyone, the slam's own radius, angle and direction",
		AimKit.shown(P, "e_tell") and bool(tell.get("all", false))
			and absf(float(tell.get("len", 0.0)) - reach) < 0.01
			and absf(float(tell.get("deg", 0.0)) - float(ed["angle"])) < 0.01 and tdir.distance_to(Vector2(1, 0)) < 0.02
			and fill_mid > 0.3 and fill_mid < 0.8 and ak.dmg(T) == 0.0,
		"len %.1f deg %.0f fill %.2f" % [float(tell.get("len", 0.0)), float(tell.get("deg", 0.0)), fill_mid]
	)
	ak.step(m, 0.3)
	ok(
		"anchor tell: the slam hits inside the drawn cone and nothing outside it",
		K.anchors == 1 and ak.dmg(T) > 10.0 and ak.dmg(T2) == 0.0 and not AimKit.shown(P, "e_tell"),
		"inside %.0f, outside %.0f" % [ak.dmg(T), ak.dmg(T2)]
	)
	await ak.done(m)

## Item 35: his own dash moves, a low clawing lunge on the ground and a pounce in the air, used by no other
## hero; each lands by the end of its 0.18 s dash and is over before the next barge of a run may start.
func _dash_moves() -> void:
	var r: Array = ak.setup("dredge", 8.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	var K: DredgeKit = P.ak
	ak.aim_at(P, home + Vector3(0, 0, -6.0))
	P.do_dash()
	var ground_move := K.anim_id
	var dash_t := P.roll_t
	ak.step(m, 0.6)
	P.teleport(home + Vector3(0, 3.0, 0))
	P.grounded = false
	P.ex_cd = 0.0
	ak.step(m, ak.DT)
	P.do_dash()
	var air_move := K.anim_id
	ak.step(m, 0.6)
	var others := {}
	var viewer: Dictionary = Content.rules("hunter_viewer")["moves"]
	for hero in viewer:
		if hero != "dredge":
			for mv in (viewer[hero] as Dictionary).get("dash", []):
				others[mv] = hero
	var gap := float(K.dash_def()["gap"])
	var fits := true
	for mv in [ground_move, air_move]:
		var keys: Array = KMovesPair.MOVES.get(mv, {"keys": [[99.0, {}]]})["keys"]
		var lands := 0.0
		for kf in keys:
			if float((kf[1] as Dictionary).get("sq", 0.0)) >= 0.3 and float(kf[0]) > 0.0:
				lands = float(kf[0])          # the squash he lands in
				break
		fits = fits and lands > 0.0 and lands <= dash_t + 0.07 and float(keys[-1][0]) <= dash_t + gap
	ok(
		"dash moves: his own low lunge and air pounce, no other hero's, each fitting the dash",
		ground_move == "dr_lunge" and air_move == "dr_pounce" and not others.has(ground_move)
			and not others.has(air_move) and fits,
		"%s / %s, dash %.2f s" % [ground_move, air_move, dash_t]
	)
	# into_dash e: buffer: Shift in the slam's wind-up is held and the barge goes the step the slam lands
	P.teleport(home)
	P.vel = Vector3.ZERO
	ak.step(m, 0.3)
	P.dashes = P.max_dashes()
	K.cd["e"] = 0.0
	P.ak.use_e()
	ak.step(m, 0.1)
	P.do_dash()
	var held_now := K.dash_held and P.roll_t <= 0.0
	var waited := 0.0
	while P.roll_t <= 0.0 and waited < 1.0:
		ak.step(m, ak.DT)
		waited += ak.DT
	ok(
		"into dash: Shift in the slam is held, and he barges the step it lands",
		held_now and K.anchors >= 1 and P.roll_t > 0.0 and waited < 0.35, "barged %.2f s after the press" % waited
	)
	await ak.done(m)

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
	# --- Grapnel reels a foe in
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
		"grapnel: foe arrives at your feet and does not land Grounded",
		K.arrivals == 1 and K.pull.is_empty() and not KitStatus.grounded(T) and P.flat_dist(T) < 3.6,
		"arrivals %d dist %.1f (was %.1f)" % [K.arrivals, P.flat_dist(T), d0]
	)
	ok("reel: Dredge's own Grounded ends with the reel", not KitStatus.grounded(P))
	# --- reel then Anchor Drop on the Grounded foe
	ak.fresh(T)
	T.teleport(P.pos + Vector3(2.0, 0, 0))
	ak.aim_at(P, T.pos)
	K.cd["e"] = 0.0
	var hp0: float = ak.dmg(T)
	var at0 := P.pos
	P.ak.use_e()
	ak.step(m, 0.3)
	var early := K.anchors
	var early_dmg: float = ak.dmg(T) - hp0
	ak.step(m, 0.2)
	ok(
		"anchor: planted, the damage lands on the slam frame (~0.38s), not at the cast",
		early == 0 and early_dmg == 0.0 and K.anchors == 1 and P.flat_dist(at0) < 0.3,
		"anchors at 0.3s %d (dmg %.0f), moved %.1f m" % [early, early_dmg, P.flat_dist(at0)]
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
	# --- terrain: the hook pierces a cliff face and the reel hauls the foe up and over it
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
		"cliff: the hook pierces a cliff face and hooks the foe behind it",
		K.grapples == g0 + 1 and ak.dmg(T) >= 5.0 and P.flat_dist(T) < 7.5,
		"grapples +%d dist %.1f took %.1f" % [K.grapples - g0, P.flat_dist(T), ak.dmg(T)]
	)
	for dz in range(-6, 7):
		W.level[W.idx(hx + 4, hz + dz)] = lv
	# a cliff face in the reel's path: the foe is hauled over it
	reset.call()
	for dz in range(-6, 7):
		W.level[W.idx(hx + 4, hz + dz)] = lv + 4
	ak.tap(m, P)
	ak.step(m, 3.4)
	ok(
		"cliff: a reel hauls the foe up and over a cliff face to your feet",
		T.pos.x < home.x + 3.6 and P.flat_dist(T) < 3.6 and K.pull.is_empty() and K.arrivals >= 1,
		"foe x %.1f dist %.1f arrivals %d" % [T.pos.x - home.x, P.flat_dist(T), K.arrivals]
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
	ok(
		"air smash rank 3: the height bonus stays at +50% (the abyss is the rank's bonus)",
		K.last_quake_k > 1.4 and K.last_quake_k < 1.55, "k %.2f" % K.last_quake_k
	)
	ok(
		"anchor rank 3: stun 1.5s (+0.1 a rank, and the rank's own +0.2)", absf(K._stun_t() - 1.5) < 0.01,
		"stun %.2f" % K._stun_t()
	)
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
	# --- rank 3 Anchor: double damage on a foe over the abyss
	var over_dmg := 0.0
	var off_dmg := 0.0
	for dz in range(-2, 3):
		for dx in range(1, 4):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_VOID
	for over in [false, true]:
		reset.call()
		P.slot_lv["kin"] = 3
		T.teleport(home + Vector3(2.0 if over else 8.0, 0, 0))
		T2.teleport(home + Vector3(-9.0, 0, 6.0))
		ak.aim_at(P, home + Vector3(2.0, 0, 0))
		P.ak.use_e()
		ak.step(m, 0.5)
		if over: over_dmg = ak.dmg(T)
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0))
	for dz in range(-2, 3):
		for dx in range(1, 4):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_GROUND
	T.teleport(home + Vector3(2.0, 0, 0))
	ak.aim_at(P, home + Vector3(2.0, 0, 0))
	P.ak.use_e()
	ak.step(m, 0.5)
	off_dmg = ak.dmg(T)
	ok(
		"anchor rank 3: a foe over the abyss takes double damage",
		K.abyss_dunks == 1 and off_dmg > 10.0 and over_dmg > off_dmg * 1.8,
		"over %.1f on ground %.1f dunks %d" % [over_dmg, off_dmg, K.abyss_dunks]
	)
	P.slot_lv["kin"] = 1
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
	# no damage from the shove; the gun's bloom resets only from rank 3
	reset.call()
	T.teleport(home + Vector3(1.8, 0, 0))
	ak.aim_at(P, T.pos)
	P.wbloom = 10.0
	P.idle_fire = 0.0
	P.ak.on_dash(false)
	ak.step(m, 0.1)
	ok(
		"barge: the shove does no damage, and rank 1 keeps the gun's spread",
		ak.dmg(T) < 0.5 and P.wbloom > 5.0, "dmg %.2f bloom %.1f" % [ak.dmg(T), P.wbloom]
	)
	reset.call()
	K.next_barge = -9.0
	P.slot_lv["dash"] = 3
	P.wbloom = 10.0
	ak.aim_at(P, home + Vector3(9.0, 0, 0))
	P.ak.on_dash(false)
	ak.step(m, 0.1)
	ok("barge rank 3: a dash resets the gun's spread", P.wbloom < 0.01, "bloom %.1f" % P.wbloom)
	P.slot_lv["dash"] = 1
	ak.step(m, 0.6)
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
		"grapnel rank 3: a hit takes half the cooldown off (12s -> 9.6s -> 4.8s)",
		float(K.cd["rmb"]) < 9.6 * 0.5 + 0.5 and K.grapples >= 1, "cd %.1f" % float(K.cd["rmb"])
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
