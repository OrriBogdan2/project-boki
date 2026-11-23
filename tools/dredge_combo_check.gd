extends RefCounted
## --dredge-combo-check: Grimble's abilities and their interactions, scripted one by one in the
## archetype check's flat training strip (docs/heroes/dredge.md, combinations table): the Deep Reach
## reel (its parity rows: tools/dredge_reel_check.gd), only the barge during it, reel into the Anchor Drop,
## terrain the hook pierces, the abyss, the Salvage passive, the back hit, the barge's turn lock after the
## Anchor, the rank-3 specials, and the X ult, Brass Broadside (tools/dredge_ult_check.gd).

## s from Brute Dash's arrival to aiming and walking (briefs/hero-ref/dredge.md:306, 493.32 -> 493.6 s)
const SRC_RECOVER_S := 0.28

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
	await _glide_wins()
	await _parity_gun()
	await load("res://tools/dredge_gun_check.gd").new(ak, ok).run()
	await load("res://tools/dredge_gun_range_check.gd").new(ak, ok).run()
	await load("res://tools/dredge_timing_check.gd").new(ak, ok).run()
	await load("res://tools/dredge_rmb_carry_check.gd").new(ak, ok).run()
	await load("res://tools/dredge_reel_check.gd").new(ak, ok).run()
	await load("res://tools/dredge_ult_check.gd").new(ak, ok).run()
	await load("res://tools/dredge_cancel_check.gd").new(ak, ok).run()
	await load("res://tools/dredge_anim_time_check.gd").new(self).run(ak)
	var rows_bad: int = await load("res://tools/dash_flow_check.gd").new().check_hero(main, "dredge")
	ok("item 51: every slot casts mid-jump and a jump or Shift moves him out of it in 0.1s (or its row's exception)",
			rows_bad == 0, "%d failures" % rows_bad)
	print("DREDGECHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Taps the Deep Reach and steps through the coil-back and the flight (it grabs, misses or is stopped), then
## one frame more so a reel's first frame is drawn.
func _throw(m: Match, p: Hunter) -> void:
	ak.tap(m, p)
	var tw := 0.0
	while (p.ak as DredgeKit).flying and tw < 1.5:
		ak.step(m, ak.DT)
		tw += ak.DT
	ak.step(m, ak.DT)

## Item 31 (CastHold): from the throw until the miss or the end of the reel he keeps his height mid-air (no
## fall); while the hook flies out he walks at 15-25% of his walk; gravity is back once it ends.
func _hook_hold() -> void:
	var r: Array = ak.setup("dredge", 6.0, "", false)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var home: Vector3 = r[4]
	var k_v: DredgeKit = p.ak
	# on the ground: his walk, then the walk while a hook flies out at nobody
	ak.aim_at(p, home + Vector3(0, 0, -10.0))
	p.inp["move"] = Vector2(1, 0)
	ak.step(m, 0.3)
	var p0 := p.pos
	ak.step(m, 0.2)
	var walk := p.flat_dist(p0) / 0.2
	ak.tap(m, p)
	ak.step(m, 0.05)
	p0 = p.pos
	ak.step(m, 0.25)
	var crawl := p.flat_dist(p0) / 0.25
	var k := crawl / maxf(0.01, walk)
	ok(
		"hook hold: while the hook flies out he walks at 15-25% speed",
		k_v.flying and k >= 0.15 and k <= 0.25, "%.2f of %.1f m/s" % [k, walk]
	)
	ak.step(m, 01.0)
	p.inp["move"] = Vector2.ZERO
	# mid-air, a hook that misses: no fall while it flies, gravity the moment it ends
	k_v.cd["rmb"] = 0.0
	k_v.ch_rmb = 1.0
	p.teleport(home + Vector3(0, 3.0, 0))
	p.vel = Vector3.ZERO
	p.grounded = false
	ak.tap(m, p)
	var y0 := p.pos.y
	var drift := 0.0
	p.inp["move"] = Vector2(1, 0)
	ak.step(m, 0.1)
	var a0 := p.pos
	ak.step(m, 0.2)
	var air_k := p.flat_dist(a0) / 0.2 / maxf(0.01, walk)
	p.inp["move"] = Vector2.ZERO
	while k_v.flying:
		ak.step(m, ak.DT)
		drift = maxf(drift, absf(p.pos.y - y0))
	drift = maxf(drift, absf(p.pos.y - y0))
	var y_end := p.pos.y
	ak.step(m, 0.25)
	ok(
		"hook hold: mid-air his height holds while the hook flies (a slow drift), and he falls once it misses",
		drift <= 0.05 and y_end - p.pos.y > 0.2 and air_k >= 0.15 and air_k <= 0.25,
		"drift %.3f, walk %.2f of his speed, then fell %.2f m" % [drift, air_k, y_end - p.pos.y]
	)
	# a knock during the hold still shoves him (only the height is held)
	k_v.cd["rmb"] = 0.0
	k_v.ch_rmb = 1.0
	p.teleport(home + Vector3(0, 3.0, 0))
	p.vel = Vector3.ZERO
	p.grounded = false
	ak.tap(m, p)
	var k0 := p.pos
	p.impulse(Vector2(0, 1) * 8.0 * p.mass())
	ak.step(m, 0.2)
	ok(
		"hook hold: a knock during the hold still shoves him, height held",
		k_v.flying and p.flat_dist(k0) > 0.6 and absf(p.pos.y - k0.y) <= 0.05,
		"shoved %.2f m, height %+.3f" % [p.flat_dist(k0), p.pos.y - k0.y]
	)
	ak.step(m, 01.0)
	# mid-air, a hook that catches: held from the throw to the end of the reel
	p.teleport(home + Vector3(0, 1.0, 0))
	p.vel = Vector3.ZERO
	p.grounded = false
	ak.fresh(t)
	t.teleport(home + Vector3(6.0, 0, 0))
	ak.aim_at(p, t.pos)
	k_v.cd["rmb"] = 0.0
	k_v.ch_rmb = 1.0
	ak.tap(m, p)
	y0 = p.pos.y
	drift = 0.0
	var tw := 0.0
	while (k_v.flying or not k_v.pull.is_empty()) and tw < 4.0:
		ak.step(m, ak.DT)
		tw += ak.DT
		drift = maxf(drift, absf(p.pos.y - y0))
	ok(
		"hook hold: mid-air his height holds from the throw to the end of the reel",
		k_v.grapples >= 1 and k_v.arrivals >= 1 and drift <= 0.05, "grapples %d arrivals %d drift %.3f" % [
			k_v.grapples, k_v.arrivals, drift]
	)
	await ak.done(m)

## Item 33: through the wind-up an outline of the slam's area shows on the ground, for everyone, and it is the
## exact cone the slam hits: a foe just inside its edge is hit, one just outside is not, and only on the slam frame.
func _slam_tell() -> void:
	var r: Array = ak.setup("dredge", 6.0, "", true)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var t2: Hunter = r[3]
	var home: Vector3 = r[4]
	var k: DredgeKit = p.ak
	var ed: Dictionary = k.e_def()
	var half := deg_to_rad(float(ed["angle"]) * 0.5)
	var reach := float(ed["radius"])
	# aim straight along +x; one foe inside the edge of the cone, one just past it (outside the angle)
	ak.aim_at(p, home + Vector3(5.0, 0, 0))
	var in_off := Vector3(cos(half - 0.25), 0, sin(half - 0.25)) * (reach - 0.4)
	var out_off := Vector3(cos(half + 0.35), 0, sin(half + 0.35)) * (reach - 0.4)
	t.teleport(home + in_off)
	t2.teleport(home + out_off)
	ak.fresh(t)
	ak.fresh(t2)
	k.cd["e"] = 0.0
	p.ak.use_e()
	ak.step(m, 0.2)
	var tell: Dictionary = AimKit.entry(p, "e_tell")
	var tdir: Vector2 = tell.get("dir", Vector2.ZERO)
	var fist: Dictionary = (HeroVfx.data("dredge")["moves"] as Dictionary)["anchor_fist"]["fx"][0]
	var lands := absf(float(fist["life"]) * float(fist["fall"]) - float(ed["windup"])) < 0.01
	var fist_up: bool = HeroVfx.of(m).plays.get("anchor_fist", 0) == 1 and lands
	ok(
		"anchor tell: an outline (no fill) of the hit cone for all; the fist lands on the slam",
		AimKit.shown(p, "e_tell") and bool(tell.get("all", false))
			and absf(float(tell.get("len", 0.0)) - reach) < 0.01
			and absf(float(tell.get("deg", 0.0)) - float(ed["angle"])) < 0.01 and tdir.distance_to(Vector2(1, 0)) < 0.02
			and bool(tell.get("outline", false)) and float(tell.get("fill", -1.0)) < 0.0
			and fist_up and ak.dmg(t) == 0.0,
		"len %.1f deg %.0f outline %s fist %s" % [
			float(tell.get("len", 0.0)), float(tell.get("deg", 0.0)), tell.get("outline"), fist_up]
	)
	# the hop carries the drawn cone with him: wait it out, then place the foes in the cone
	while k.wind > 0.03:
		ak.step(m, ak.DT)
	t.teleport(p.pos + in_off)
	t2.teleport(p.pos + out_off)
	ak.step(m, 0.1)
	ok(
		"anchor tell: the slam hits inside the drawn cone and nothing outside it",
		k.anchors == 1 and ak.dmg(t) > 10.0 and ak.dmg(t2) == 0.0 and not AimKit.shown(p, "e_tell"),
		"inside %.0f, outside %.0f (anchors %d)" % [ak.dmg(t), ak.dmg(t2), k.anchors]
	)
	# a stun in the wind-up stops the move: the tell and the falling fist go at once, and no slam
	var v := HeroVfx.of(m)
	v._process(1.0)             # (m.step leaves HeroVfx to the frame) the first fist has rested and faded
	Sfx.listener = p.pos        # the camera on him, so the fist draws
	k.cd["e"] = 0.0
	p.ak.use_e()
	ak.step(m, 0.1)
	v._process(0.1)
	var fists: Array = v.pools.get("fist", [])
	var up := fists.any(func(n_v: Node3D) -> bool: return n_v.visible)
	p.stun_t = 0.6
	ak.step(m, 0.05)
	v._process(0.05)
	var left := fists.any(func(n_v: Node3D) -> bool: return n_v.visible)
	ok(
		"anchor tell: a stun in the wind-up takes the outline and the falling fist away, no slam",
		up and not left and not AimKit.shown(p, "e_tell") and k.anchors == 1,
		"fist up %s, after the stun %s (anchors %d)" % [up, left, k.anchors]
	)
	await ak.done(m)

## Item 35: his own dash moves, a low clawing lunge on the ground and a pounce in the air, used by no other
## hero; each lands by the end of its 0.18 s dash and recovers no slower than the source, aiming and walking
## 0.28 s after it arrives (briefs/hero-ref/dredge.md:306). A chained shove cuts the recovery and restarts it.
func _dash_moves() -> void:
	var r: Array = ak.setup("dredge", 8.0, "", false)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var home: Vector3 = r[4]
	var k: DredgeKit = p.ak
	ak.aim_at(p, home + Vector3(0, 0, -6.0))
	p.do_dash()
	var ground_move := k.anim_id
	var dash_t := p.roll_t
	ak.step(m, 0.6)
	p.teleport(home + Vector3(0, 3.0, 0))
	p.grounded = false
	p.ex_cd = 0.0
	ak.step(m, ak.DT)
	p.do_dash()
	var air_move := k.anim_id
	ak.step(m, 0.6)
	var others := {}
	var viewer: Dictionary = Content.rules("hunter_viewer")["moves"]
	for hero in viewer:
		if hero != "dredge":
			for mv in (viewer[hero] as Dictionary).get("dash", []):
				others[mv] = hero
	var fits := true
	for mv in [ground_move, air_move]:
		var keys: Array = KMovesPair.MOVES.get(mv, {"keys": [[99.0, {}]]})["keys"]
		var lands := 0.0
		for kf in keys:
			if float((kf[1] as Dictionary).get("sq", 0.0)) >= 0.3 and float(kf[0]) > 0.0:
				lands = float(kf[0])          # the squash he lands in
				break
		fits = fits and lands > 0.0 and lands <= dash_t + 0.07 and float(keys[-1][0]) <= dash_t + SRC_RECOVER_S
	ok(
		"dash moves: his own low lunge and air pounce, no other hero's, each fitting the dash",
		ground_move == "dr_lunge" and air_move == "dr_pounce" and not others.has(ground_move)
			and not others.has(air_move) and fits,
		"%s / %s, dash %.2f s" % [ground_move, air_move, dash_t]
	)
	# into_dash e: fire. Shift in the slam's wind-up barges at once, the fist still raised; the slam lands where
	# the barge arrives
	p.teleport(home)
	p.vel = Vector3.ZERO
	ak.step(m, 0.3)
	p.dashes = p.max_dashes()
	k.cd["e"] = 0.0
	var anchors0 := k.anchors
	p.ak.use_e()
	ak.step(m, 0.1)
	var from := p.pos
	p.do_dash()
	ak.step(m, 0.05)
	var barged := p.roll_t > 0.0 and k.wind > 0.0 and k.anim_id == "dr_anchor"
	ak.step(m, 0.5)
	ok(
		"into dash: Shift in the slam's wind-up barges at once, the slam lands where it arrives (item 51)",
		barged and k.anchors == anchors0 + 1 and Vector2(p.pos.x - from.x, p.pos.z - from.z).length() > 2.0,
		"barged %s anchors +%d moved %.1f m" % [barged, k.anchors - anchors0, p.pos.distance_to(from)]
	)
	# ... and in the air smash: the pounce goes, then the smash drops from where it ends
	ak.step(m, 1.0)
	p.teleport(home + Vector3(0, 6.0, 0))
	p.vel = Vector3.ZERO
	p.grounded = false
	k.cd["e"] = 0.0
	p.ex_cd = 0.0
	p.dashes = p.max_dashes()
	var quakes0 := k.quakes
	p.ak.use_e()
	ak.step(m, 0.05)
	from = p.pos
	p.inp["move"] = Vector2(1, 0)
	p.do_dash()
	ak.step(m, 0.05)
	var pounced := p.roll_t > 0.0 and not k.dive.is_empty()
	p.inp["move"] = Vector2.ZERO
	ak.step(m, 1.0)
	ok(
		"into dash: Shift in the air smash pounces at once and the smash still lands, from where it took him",
		pounced and k.quakes == quakes0 + 1 and Vector2(p.pos.x - from.x, p.pos.z - from.z).length() > 2.0,
		"pounced %s quakes +%d" % [pounced, k.quakes - quakes0]
	)
	await ak.done(m)

## Bug 26 pattern: the glider wins over the Anchor Drop. A fresh glide press in the air smash ends it (no hit) and
## he glides at the normal sink, never dragged down; after a ground slam a jump and glide is a normal glide.
func _glide_wins() -> void:
	var r: Array = ak.setup("dredge", 8.0, "", false)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var home: Vector3 = r[4]
	var k: DredgeKit = p.ak
	p.teleport(home + Vector3(0, 9.0, 0))
	p.vel = Vector3.ZERO
	p.grounded = false
	ak.step(m, 0.1)
	k.cd["e"] = 0.0
	p.ak.use_e()
	ak.step(m, 0.05)
	var diving := not k.dive.is_empty()
	var z0 := p.pos.y
	var q0 := k.quakes
	p.inp["jump"] = true
	var low := z0
	var t := 0.0
	while t < 0.3:
		p.inp["glide"] = true
		p.inp["glide_btn"] = true
		m.step(ak.DT)
		t += ak.DT
		low = minf(low, p.pos.y)
	ok(
		"glide wins: a glide press in the air smash ends it and he glides at the normal sink",
		diving and k.dive.is_empty() and p.gliding and k.quakes == q0
			and low >= z0 - HunterMove.glide_sink * 0.3 - 0.35,
		"fell %.2f m in 0.3 s" % (z0 - low)
	)
	p.inp["glide"] = false
	p.inp["glide_btn"] = false
	ak.step(m, 2.0)
	# on the ground: the slam, then a jump and the glider at once
	p.teleport(home)
	p.vel = Vector3.ZERO
	ak.step(m, 0.3)
	k.cd["e"] = 0.0
	p.ak.use_e()
	ak.step(m, 0.42)
	var zg := p.pos.y
	p.inp["jump"] = true
	m.step(ak.DT)
	ak.step(m, 0.15)
	p.inp["jump"] = true
	var low_g := 99.0
	t = 0.0
	while t < 0.3:
		p.inp["glide"] = true
		p.inp["glide_btn"] = true
		m.step(ak.DT)
		t += ak.DT
		low_g = minf(low_g, p.pos.y)
	ok(
		"glide wins: after the ground slam a jump and glide is a normal glide, not dragged down",
		k.anchors >= 1 and p.gliding and low_g >= zg, "lowest %+.2f m from take-off" % (low_g - zg)
	)
	p.inp["glide"] = false
	p.inp["glide_btn"] = false
	await ak.done(m)

func _all() -> void:
	var r: Array = ak.setup("dredge", 8.0, "", true)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var t2: Hunter = r[3]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var k: DredgeKit = p.ak
	var reset := func():
		p.teleport(home)
		p.vel = Vector3.ZERO
		p.roll_t = 0.0
		p.hp = p.max_hp
		p.stun_t = 0.0
		ak.fresh(t)
		t.out = false
		t.downed = false
		t.dead = false
		t.teleport(home + Vector3(8.0, 0, 0))
		t.face = PI / 2.0     # facing away (west is +PI/2 away from P: east-looking is -PI/2)
		k.cd["rmb"] = 0.0
		k.ch_rmb = 1.0
		k.cd["e"] = 0.0
		k.pull = {}
		k.flying = false
		k.coil = 0.0
		k.wind = 0.0
		k.dive = {}
		k.scoop = []
		p.set_meta("gnd_until", 0.0)
		p.inp["move"] = Vector2.ZERO
		p.inp["fire"] = false
		t2.teleport(home + Vector3(-9.0, 0, 6.0))
		t2.downed = false
		p.dashes = p.max_dashes()
		p.fire_cd = 0.0
		ak.aim_at(p, t.pos)
	ok(
		"dredge: heavy, shotgun, 3 barge charges", p.wid == "shotgun" and p.cls == "heavy" and p.max_dashes() >= 3.0,
		"%s %s" % [p.wid, p.cls]
	)
	# --- the scattergun: a shot every 0.5s, one aim line
	reset.call()
	t.teleport(home + Vector3(0, 0, 9.0))
	ak.aim_at(p, home + Vector3(2.0, 0, 0))
	var v0: int = k.volleys
	var cone_seen := false
	var tf := 0.0
	while tf < 1.05:
		p.inp["fire"] = true
		ak.aim_at(p, home + Vector3(2.0, 0, 0))
		m.step(ak.DT)
		tf += ak.DT
		if AimKit.shown(p, "spread"): cone_seen = true
	p.inp["fire"] = false
	var cone: Dictionary = AimKit.entry(p, "spread")
	ok(
		"gun: a shot every half second",
		k.volleys - v0 >= 2 and k.volleys - v0 <= 3 and absf(float(p.wpn["rate"]) - 0.5) < 0.01,
		"volleys %d in 1.05s" % (k.volleys - v0)
	)
	ok(
		"gun: one aim line lies on the ground out to the slug range",
		cone_seen and cone.get("kind") == "vee" and absf(float(cone.get("len", 0.0)) - 6.3) < 0.3,
		"len %.1f kind %s" % [float(cone.get("len", 0.0)), cone.get("kind", "none")]
	)
	ok("gun: each shot rocks the body back (dr_shot)", k.anim_id == "dr_shot")
	ak.step(m, 1.0)
	ok("gun: idle, the same one aim line shows", AimKit.shown(p, "spread"))
	p.ammo = int(p.wpn["mag"])
	# --- every volley is tight, so its slugs shred armor (content gun.armor_k)
	var armor0: float = t.armor
	var max_armor0: float = t.max_armor
	reset.call()
	t.teleport(home + Vector3(0, 0, 1.6))
	t.max_armor = 50.0
	t.armor = 50.0
	var armor_hp0: float = t.hp
	p.ammo = int(p.wpn["mag"])
	ak.aim_at(p, t.pos)
	p.inp["fire"] = true
	ak.step(m, 0.1)
	p.inp["fire"] = false
	ak.step(m, 0.5)
	var worn: float = 50.0 - t.armor
	t.armor = armor0
	t.max_armor = max_armor0
	ok(
		"gun: a volley shreds armor (+%.0f%% wear on top of the hit)" % (float(k.gun_def()["armor_k"]) * 100.0),
		k.armor_shreds > 0 and worn > 0.0 and armor_hp0 - t.hp > 0.0,
		"armor worn %.1f, hp %.1f, shreds %d" % [worn, armor_hp0 - t.hp, k.armor_shreds]
	)
	# --- Deep Reach reels a foe in
	reset.call()
	_throw(m, p)
	var d0 := p.flat_dist(t)
	ok(
		"deep reach: hooks the first foe, reel begins",
		k.grapples == 1 and not k.pull.is_empty() and ak.dmg(t) >= 5.0 and float(k.cd["rmb"]) > 8.0,
		"grapples %d took %.1f cd %.1f" % [k.grapples, ak.dmg(t), float(k.cd["rmb"])]
	)
	ok(
		"reel: Grimble is Grounded while he reels, the foe is stunned",
		KitStatus.grounded(p) and t.stun_t > 0.0 and HeroVfx.of(k.m).holds.has("%d/reel" % p.get_instance_id()),
		"gnd %s stun %.2f" % [KitStatus.grounded(p), t.stun_t]
	)
	var reach_to: Vector3 = p.model.get_meta(WardenReach.TIP, Vector3.INF) if p.model else Vector3.INF
	ok(
		"reel: his own arm reaches to the foe (the model's reach tip on it)",
		reach_to.distance_to(t.pos + Vector3(0, 0.95, 0)) < 0.5, "tip %s foe %s" % [reach_to, t.pos]
	)
	var ghost := "%d/arm_ghost" % p.get_instance_id()
	ok("reel: in the open no through-rock silhouette is drawn", not HeroVfx.of(k.m).holds.has(ghost))
	# --- during the reel: RMB, E and the gun are locked, the barge works
	var ch0 := k.ch_rmb
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	ak.tap(m, p)
	ok("reel: a second Deep Reach is denied", k.grapples == 1)
	k.cd["e"] = 0.0
	p.ak.use_e()
	ok("reel: E is not cast while reeling (it waits for the arrival)", k.anchors == 0 and k.wind <= 0.0 and k.e_queued)
	k.e_queued = false  # (this check casts its own Anchor after the arrival, below)
	ok("reel: the gun is locked", not k.can_shoot())
	var pos0 := p.pos
	ak.aim_at(p, t.pos)
	p.inp["move"] = Vector2.ZERO
	p.ak.on_dash(false)
	ak.step(m, 0.15)
	ok(
		"reel: the barge still works", p.flat_dist(pos0) > 1.5 and p.dashes < p.max_dashes(),
		"moved %.1f" % p.flat_dist(pos0)
	)
	var tw := 0.0
	while k.arrivals < 1 and tw < 3.0:
		ak.step(m, 0.05)
		tw += 0.05
	ok(
		"deep reach: foe arrives at your feet and does not land Grounded",
		k.arrivals == 1 and k.pull.is_empty() and not KitStatus.grounded(t) and p.flat_dist(t) < 3.6,
		"arrivals %d dist %.1f (was %.1f)" % [k.arrivals, p.flat_dist(t), d0]
	)
	ok("reel: Grimble's own Grounded ends with the reel", not KitStatus.grounded(p))
	# --- reel then Anchor Drop on the Grounded foe
	ak.fresh(t)
	t.teleport(p.pos + Vector3(2.0, 0, 0))
	ak.aim_at(p, t.pos)
	k.cd["e"] = 0.0
	var hp0: float = ak.dmg(t)
	var at0 := p.pos
	Sfx.listener = p.pos           # (the camera on him, so HeroVfx draws the stun swirl)
	p.ak.use_e()
	ak.step(m, 0.3)
	var early := k.anchors
	var early_dmg: float = ak.dmg(t) - hp0
	ak.step(m, 0.2)
	ok(
		"anchor: hops ~1 bh forward, the damage lands on the slam frame (~0.38s), not at the cast",
		early == 0 and early_dmg == 0.0 and k.anchors == 1 and p.flat_dist(at0) > 0.8 and p.flat_dist(at0) < 2.0,
		"anchors at 0.3s %d (dmg %.0f), moved %.1f m" % [early, early_dmg, p.flat_dist(at0)]
	)
	ok(
		"combo: reel > Anchor Drop = damage and stun, the foe is not Grounded (no Ground in the source)",
		k.anchors == 1 and ak.dmg(t) - hp0 >= 20.0 and not KitStatus.grounded(t) and t.stun_t > 0.8,
		"anchors %d took %.0f stun %.2f gnd %s" % [k.anchors, ak.dmg(t) - hp0, t.stun_t, KitStatus.grounded(t)]
	)
	var swirl := HeroVfx.of(k.m).live.filter(func(e): return e.get("on") == t)
	ok("anchor: the stunned foe shows a stun swirl", not swirl.is_empty())
	ok("anchor: E cooldown set", float(k.cd["e"]) > 5.0)
	# --- Barge right after the Anchor can't turn
	reset.call()
	p.face = -PI / 2.0
	k.lock_until = m.time + 0.8
	ak.aim_at(p, home + Vector3(-8.0, 0, 0))
	var p1 := p.pos
	var fwd := Vector2(-sin(p.face), -cos(p.face))
	p.ak.on_dash(false)
	ak.step(m, 0.3)
	var mv := Vector2(p.pos.x - p1.x, p.pos.z - p1.z)
	ok(
		"combo: Anchor > barge turns at most 35 degrees",
		mv.length() > 1.0 and absf(rad_to_deg(fwd.angle_to(mv))) <= 40.0,
		"moved %.1f angle %.0f" % [mv.length(), rad_to_deg(fwd.angle_to(mv))]
	)
	# --- terrain: the hook pierces a cliff face and the reel hauls the foe up and over it
	reset.call()
	var w = m.world
	var hx := int(floor(home.x))
	var hz := int(floor(home.z))
	for dz in range(-6, 7):
		w.level[w.idx(hx + 4, hz + dz)] = lv + 4
	var g0 := k.grapples
	_throw(m, p)
	ak.step(m, 0.2)          # the reel under way
	ok(
		"cliff: the hook pierces a cliff face and hooks the foe behind it",
		k.grapples == g0 + 1 and ak.dmg(t) >= 5.0 and p.flat_dist(t) < 7.5,
		"grapples +%d dist %.1f took %.1f" % [k.grapples - g0, p.flat_dist(t), ak.dmg(t)]
	)
	ghost = "%d/arm_ghost" % p.get_instance_id()
	ok("cliff: the stretch of arm inside the cliff is drawn through it", HeroVfx.of(k.m).holds.has(ghost))
	for dz in range(-6, 7):
		w.level[w.idx(hx + 4, hz + dz)] = lv
	# a cliff face in the reel's path: the foe is hauled over it
	reset.call()
	for dz in range(-6, 7):
		w.level[w.idx(hx + 4, hz + dz)] = lv + 4
	ak.tap(m, p)
	ak.step(m, 3.4)
	ok(
		"cliff: a reel hauls the foe up and over a cliff face to your feet",
		t.pos.x < home.x + 3.6 and p.flat_dist(t) < 3.6 and k.pull.is_empty() and k.arrivals >= 1,
		"foe x %.1f dist %.1f arrivals %d" % [t.pos.x - home.x, p.flat_dist(t), k.arrivals]
	)
	for dz in range(-6, 7):
		w.level[w.idx(hx + 4, hz + dz)] = lv
	# --- owner rule (DECISIONS Kits): the Hand passes walls and cliffs, but a placed wall stops it
	reset.call()
	var wall_def := {"length": 8.0, "hp": 999.0, "time": 30.0, "block": "all"}
	var wall: Dictionary = m.verbs.add_wall(t, home + Vector3(4.0, 0, 0), Vector2(-1, 0), wall_def, 1.0)
	var dm0: float = ak.dmg(t)
	var gw0 := k.grapples
	_throw(m, p)
	ok(
		"placed wall: stops the Deep Reach, no hook and no damage behind it",
		k.pull.is_empty() and ak.dmg(t) <= dm0 and k.grapples == gw0,
		"grapples +%d took %.1f" % [k.grapples - gw0, ak.dmg(t) - dm0]
	)
	m.verbs.walls.erase(wall)
	if is_instance_valid(wall.get("node")): (wall["node"] as Node).queue_free()
	# --- rocks: the hook flies over a rock and the foe is dragged over it
	reset.call()
	for dz in range(-1, 2):
		w.kind[w.idx(hx + 4, hz + dz)] = World.T_BLOCK
	ak.tap(m, p)
	var h0: int = k.hauled
	var g1: int = k.grapples
	ak.step(m, 2.2)
	ok(
		"rocks: the hook goes over a rock and drags the foe over it",
		k.grapples == g1 + 1 and k.hauled > h0 and t.pos.x < home.x + 4.0 and p.flat_dist(t) < 3.0,
		"hauled %d foe x %.1f dist %.1f" % [k.hauled - h0, t.pos.x - home.x, p.flat_dist(t)]
	)
	var tw2 := 0.0
	for dz in range(-1, 2):
		w.kind[w.idx(hx + 4, hz + dz)] = World.T_GROUND
	ak.step(m, 1.0)
	# --- the reel has weight: walking sideways while reeling swings the body round you
	reset.call()
	_throw(m, p)
	var start := t.pos
	var dev := 0.0
	var p_start := p.pos
	tw2 = 0.0
	while not k.pull.is_empty() and tw2 < 3.0:
		ak.step(m, 0.02, func(): p.inp["move"] = Vector2(0, -1))
		tw2 += 0.02
		var a2 := Vector2(start.x, start.z)
		var b2 := Vector2(p.pos.x, p.pos.z)
		var tp := Vector2(t.pos.x, t.pos.z)
		dev = maxf(dev, tp.distance_to(Geometry2D.get_closest_point_to_segment(tp, a2, b2)))
	p.inp["move"] = Vector2.ZERO
	var shuffle := p.flat_dist(p_start) / maxf(tw2, 0.01)
	ok(
		"reel audit: braced, he shuffles at a fifth of his walk (not full speed), and that still swings the arrival",
		shuffle <= p.base_speed * 0.4 and absf(t.pos.z - start.z) >= 0.25 and k.arrivals >= 1,
		"arrival shift %.1f m, Grimble %.2f m/s" % [absf(t.pos.z - start.z), shuffle]
	)
	ok("reel: the body still swings on an arc, not a straight line", dev > 0.2, "off the straight line by %.2f m" % dev)
	# --- an ally in the hook's path is reeled to safety (no damage, no stun); a wisp on the way is scooped up
	reset.call()
	var t2team := t2.team
	t2.team = p.team
	ak.fresh(t2)
	t2.out = false
	t2.downed = false
	t2.dead = false
	t2.teleport(home + Vector3(4.0, 0, 0))
	ak.aim_at(p, t.pos)
	_throw(m, p)
	ok(
		"ally: the hook catches an ally in its path and reels them in",
		not k.pull.is_empty() and k.pull["t"] == t2 and t2.stun_t <= 0.0 and ak.dmg(t2) == 0.0,
		"pull %s" % [k.pull.get("t") == t2]
	)
	ak.step(m, 1.5)
	ok(
		"ally: they arrive safe (not Grounded)",
		k.pull.is_empty() and not KitStatus.grounded(t2) and p.flat_dist(t2) < 2.5, "dist %.1f" % p.flat_dist(t2)
	)
	t2.team = t2team
	reset.call()
	ak.fresh(t2)
	t2.out = false
	t2.dead = false
	t2.teleport(home + Vector3(4.0, 0, 0.3))
	m.knock(t2, p, {})
	var w0 := p.flat_dist(t2)
	ak.tap(m, p)
	var wmin := w0
	var tws := 0.0
	while tws < 1.6:
		m.step(ak.DT)
		tws += ak.DT
		wmin = minf(wmin, p.flat_dist(t2))
	ok(
		"wisp: a downed hunter the hook passes is scooped up with the catch", p.flat_dist(t2) < w0 - 1.2,
		"wisp %.1f -> %.1f" % [w0, p.flat_dist(t2)]
	)
	t2.downed = false
	t2.teleport(home + Vector3(-9.0, 0, 6.0))
	# --- Anchor Drop in the air: straight down, the anchor with you, a ring at the landing, height adds damage
	reset.call()
	t.teleport(home + Vector3(2.0, 0, 0))
	ak.aim_at(p, t.pos)
	hp0 = ak.dmg(t)
	p.ak.use_e()
	ak.step(m, 0.6)
	var low: float = ak.dmg(t) - hp0
	reset.call()
	t.teleport(home + Vector3(1.6, 0, 0))
	ak.aim_at(p, t.pos)
	p.teleport(home + Vector3(0, 6.0, 0))
	p.grounded = false
	p.vel = Vector3.ZERO
	m.step(ak.DT)
	hp0 = ak.dmg(t)
	var q0 := k.quakes
	p.ak.use_e()
	var land_seen := false
	var anchor_seen := false
	var vy := 0.0
	var te := 0.0
	while te < 1.2 and k.quakes == q0:
		ak.step(m, ak.DT)
		te += ak.DT
		vy = minf(vy, p.vel.y)
		if AimKit.shown(p, "e_land"): land_seen = true
		if HeroVfx.of(k.m).holds.has("%d/dive" % p.get_instance_id()): anchor_seen = true
	var high: float = ak.dmg(t) - hp0
	ok(
		"air smash: straight down at once", vy <= -20.0 and absf(p.pos.x - home.x) < 0.4,
		"vy %.1f drift %.2f" % [vy, p.pos.x - home.x]
	)
	ok("air smash: the landing ring shows while you fall, the fist falls with you", land_seen and anchor_seen)
	ok(
		"air smash: it lands where you land, a ring of damage and stun",
		k.quakes == q0 + 1 and high > 0.0 and t.stun_t > 0.5, "quakes %d stun %.2f" % [k.quakes - q0, t.stun_t]
	)
	ok(
		"air smash: height adds damage (6m: about +50%)", low > 20.0 and high >= low * 1.3 and k.last_quake_k > 1.4,
		"on foot %.0f from 6m %.0f k %.2f" % [low, high, k.last_quake_k]
	)
	reset.call()
	p.slot_lv["kin"] = 3
	p.teleport(home + Vector3(0, 6.0, 0))
	p.grounded = false
	p.vel = Vector3.ZERO
	m.step(ak.DT)
	q0 = k.quakes
	p.ak.use_e()
	te = 0.0
	while te < 1.2 and k.quakes == q0:
		ak.step(m, ak.DT)
		te += ak.DT
	ok(
		"air smash rank 3: the height bonus stays at +50% (the abyss is the rank's bonus)",
		k.last_quake_k > 1.4 and k.last_quake_k < 1.55, "k %.2f" % k.last_quake_k
	)
	ok(
		"anchor rank 3: stun 1.5s (+0.1 a rank, and the rank's own +0.2)", absf(k._stun_t() - 1.5) < 0.01,
		"stun %.2f" % k._stun_t()
	)
	p.slot_lv["kin"] = 1
	for dz in range(-3, 4):
		for dx in range(-2, 3):
			w.kind[w.idx(hx + dx, hz + dz)] = World.T_VOID
	reset.call()
	p.teleport(home + Vector3(0, 0.5, 0))
	p.grounded = false
	p.vel = Vector3.ZERO
	q0 = k.quakes
	k._anchor()
	ok("abyss: the Anchor never pushes you down over the void", p.vel.y > -13.0 and k.quakes == q0, "vy %.1f" % p.vel.y)
	for dz in range(-3, 4):
		for dx in range(-2, 3):
			w.kind[w.idx(hx + dx, hz + dz)] = World.T_GROUND
	# --- rank 3 Anchor: double damage on a foe over the abyss
	var over_dmg := 0.0
	var off_dmg := 0.0
	for dz in range(-2, 3):
		for dx in range(1, 4):
			w.kind[w.idx(hx + dx, hz + dz)] = World.T_VOID
	for over in [false, true]:
		reset.call()
		p.slot_lv["kin"] = 3
		t.teleport(home + Vector3(2.0 if over else 8.0, 0, 0))
		t2.teleport(home + Vector3(-9.0, 0, 6.0))
		ak.aim_at(p, home + Vector3(2.0, 0, 0))
		p.ak.use_e()
		ak.step(m, 0.5)
		if over: over_dmg = ak.dmg(t)
	reset.call()
	t.teleport(home + Vector3(8.0, 0, 0))
	for dz in range(-2, 3):
		for dx in range(1, 4):
			w.kind[w.idx(hx + dx, hz + dz)] = World.T_GROUND
	t.teleport(home + Vector3(2.0, 0, 0))
	ak.aim_at(p, home + Vector3(2.0, 0, 0))
	p.ak.use_e()
	ak.step(m, 0.5)
	off_dmg = ak.dmg(t)
	ok(
		"anchor rank 3: a foe over the abyss takes double damage",
		k.abyss_dunks == 1 and off_dmg > 10.0 and over_dmg > off_dmg * 1.8,
		"over %.1f on ground %.1f dunks %d" % [over_dmg, off_dmg, k.abyss_dunks]
	)
	p.slot_lv["kin"] = 1
	# --- the barge goes further in the air
	reset.call()
	t.teleport(home + Vector3(0, 0, 9.0))
	ak.aim_at(p, home + Vector3(9.0, 0, 0))
	p.ak.on_dash(false)
	var feel: Dictionary = k.dash_feel()
	var one: float = float(k.dash_def()["dist"]) * float(feel["dist"])
	var dash_t: float = float(k.dash_def()["time"]) * float(feel["time"])
	ak.step(m, dash_t * 0.5)
	var half_d := p.pos.x - home.x
	ak.step(m, 0.4)
	var ground_d := p.pos.x - home.x
	ok(
		"barge: a short, fast shove you see travel (about half way at half its time), then he stops",
		half_d > one * 0.3 and half_d < one * 0.8 and absf(ground_d - one) < 0.6 and dash_t < 0.25,
		"at %.2fs %.1f, settled %.1f of %.1f" % [dash_t * 0.5, half_d, ground_d, one]
	)
	# a run of barges: three charges, a short gap between them; a press inside a shove is held, never dropped,
	# and goes by itself the step the gap ends
	reset.call()
	t.teleport(home + Vector3(0, 0, 9.0))
	ak.aim_at(p, home + Vector3(12.0, 0, 0))
	var charges0 := p.dashes
	p.ak.on_dash(false)
	ak.step(m, 0.05)
	p.ak.on_dash(false)
	var held := charges0 - p.dashes
	ak.step(m, dash_t + float(k.dash_def()["gap"]))
	var went_on := charges0 - p.dashes
	p.ak.on_dash(false)
	ak.step(m, 0.5)
	ok(
		"barge: three in a row, a short gap between (a press inside a shove waits for the gap's end, then goes)",
		absf(held - 1.0) < 0.1 and absf(went_on - 2.0) < 0.1 and p.dashes < 0.5 and p.pos.x - home.x > one * 2.6,
		"spent while held %.1f, after the gap %.1f, left %.2f went %.1f" % [held, went_on, p.dashes, p.pos.x - home.x]
	)
	# audit: the barge touches nobody (Brute Dash hits nobody)
	reset.call()
	t.teleport(home + Vector3(1.8, 0, 0))
	t.knock_t = 0.0
	ak.aim_at(p, t.pos)
	p.ak.on_dash(false)
	ak.step(m, 0.1)
	ok(
		"barge: it shoves and hurts nobody (the source's Brute Dash)",
		ak.dmg(t) < 0.5 and t.knock_t <= 0.0,
		"dmg %.2f knock %.2f" % [ak.dmg(t), t.knock_t]
	)
	reset.call()
	k.next_barge = -9.0
	ak.step(m, 0.6)
	reset.call()
	t.teleport(home + Vector3(0, 0, 9.0))
	p.teleport(home + Vector3(0, 3.0, 0))
	p.grounded = false
	p.vel = Vector3.ZERO
	p.ex_cd = 0.0
	ak.aim_at(p, home + Vector3(9.0, 0, 0))
	p.ak.on_dash(true)
	ok(
		"barge: the air pounce is 3.2 m x 1.35 x the dash feel once (3.7 m), same time as the ground",
		absf(p.roll_t - dash_t) < 0.005 and absf(p.roll_speed * p.roll_t - one * 1.35) < 0.05,
		"%.2f m in %.2fs, ground %.2f m in %.2fs" % [p.roll_speed * p.roll_t, p.roll_t, one, dash_t]
	)
	ak.step(m, dash_t + 0.02)
	var air_quick := p.pos.x - home.x
	ak.step(m, 0.3)
	var air_d := p.pos.x - home.x
	ok(
		"barge: in the air the same quick time, 35% further", air_quick > one * 1.2,
		"air after %.2fs %.1f, ground %.1f" % [dash_t, air_quick, one]
	)
	ok(
		"barge: further in the air than on the ground", air_d > ground_d * 1.15 and ground_d > 2.0,
		"ground %.1f air %.1f" % [ground_d, air_d]
	)
	# the air pounce is its own slot: source Brute Dash (Air) 12.5 s, 2 s less per rank, ground charges untouched
	var cd_r := []
	for rk in [1, 2, 3]:
		p.slot_lv["dash"] = rk
		cd_r.append(k.long_dash_cd())
	p.slot_lv["dash"] = 1
	reset.call()
	p.teleport(home + Vector3(0, 3.0, 0))
	p.grounded = false
	p.ex_cd = 0.0
	p.dashes = p.max_dashes()
	p.ak.on_dash(true)
	var air_spent := p.max_dashes() - p.dashes
	ok(
		"barge air slot: its own 12.5 s recharge (10.5 / 8.5 at ranks 2 / 3), no ground charge spent",
		absf(p.ex_cd - 12.5) < 0.01 and absf(cd_r[1] - 10.5) < 0.01 and absf(cd_r[2] - 8.5) < 0.01 and air_spent < 0.01,
		"ex_cd %.2f ranks %s charge spent %.2f" % [p.ex_cd, str(cd_r), air_spent]
	)
	# --- Salvage: knocks stack, +2.5% health each, a knock heals, losing one when downed
	reset.call()
	p.slot_lv["kin"] = 1
	var mh0 := p.max_hp
	p.hp = p.max_hp * 0.5
	k.on_knock(t, true)
	ok(
		"passive: a knock = 1 stack, +2.5% health, a heal",
		k.res == 1.0 and absf(p.max_hp - mh0 * 1.025) < 0.5 and p.hp > mh0 * 0.5 + mh0 * 0.15,
		"res %.0f maxhp %.1f hp %.1f" % [k.res, p.max_hp, p.hp]
	)
	var hp1 := p.hp
	k.on_knock(t, false)
	ok("passive: an assist stacks but does not heal", k.res == 2.0 and p.hp <= hp1 + p.max_hp * 0.03 + 0.5)
	for i in 12: k.on_knock(t, false)
	ok(
		"passive: capped at 10 stacks (+25%)", k.res == 10.0 and absf(p.max_hp - mh0 * 1.25) < 0.5,
		"res %.0f maxhp %.1f" % [k.res, p.max_hp]
	)
	p.downed = true
	k._tick(0.016)
	p.downed = false
	ok("passive: being downed costs a stack", k.res == 9.0 and k.stacks_lost == 1)
	# --- a hit on the back deals 50% more
	reset.call()
	# looking east, away from... T is east of P, so facing east = away from P
	t.face = PI / 2.0 * 0.0 + (-PI / 2.0)
	var behind := k.outgoing(t, 10.0, {})
	t.face = PI / 2.0
	var front := k.outgoing(t, 10.0, {})
	ok(
		"passive: from behind +50%, from the front none", absf(behind - 15.0) < 0.01 and absf(front - 10.0) < 0.01,
		"behind %.1f front %.1f" % [behind, front]
	)
	# --- rank 3: the Deep Reach refunds on a hit, pellet hits trim the barge recharge
	reset.call()
	p.slot_lv["sec"] = 3
	p.slot_lv["dash"] = 3
	_throw(m, p)
	ok(
		"deep reach rank 3: a hit takes half the cooldown off (12s -> 9.6s -> 4.8s)",
		float(k.cd["rmb"]) < 9.6 * 0.5 + 0.5 and k.grapples >= 1, "cd %.1f" % float(k.cd["rmb"])
	)
	p.dashes = 0.0
	k.on_deal(t, 3.0, {"src": "shot"})
	ok("barge rank 3: a pellet hit trims the recharge", p.dashes > 0.01, "dashes %.3f" % p.dashes)
	# --- the abyss: a foe reeled over a gap falls
	reset.call()
	for dz in range(-6, 7):
		for dx in range(3, 8):
			w.kind[w.idx(hx + dx, hz + dz)] = World.T_VOID
	var a0 := k.arrivals
	ak.tap(m, p)
	ak.step(m, 2.5)
	ok(
		"abyss: a foe reeled over the void falls (knock rules)",
		k.arrivals == a0 and (t.out or t.downed or t.dead or p.flat_dist(t) > 3.0),
		"out %s y %.1f x %.1f" % [str(t.out), t.pos.y - home.y, t.pos.x - home.x]
	)
	for dz in range(-6, 7):
		for dx in range(3, 8):
			w.kind[w.idx(hx + dx, hz + dz)] = World.T_GROUND
	# --- a Boki merge that starts mid-reel / mid-wind-up ends them: the rope goes, no Anchor slam, no landing hit
	reset.call()
	_throw(m, p)
	var reeling: bool = not k.pull.is_empty()
	ok("merge hold: the reel is under way before the merge", reeling, "pull %s" % reeling)
	var rope: Node3D = k.pull.get("node")
	var ar0 := k.arrivals
	ok("merge hold: a merge is under way", ak.merge_now(p))
	ak.step(m, 0.1)
	ok(
		"merge hold: dredge's reel ends with the merge, the rope is freed, nobody lands Grounded",
		k.pull.is_empty() and (rope == null or not is_instance_valid(rope) or rope.is_queued_for_deletion()) and k.arrivals == ar0 and not KitStatus.grounded(t),
		"pull %s arrivals %d" % [not k.pull.is_empty(), k.arrivals - ar0]
	)
	KinMerge.end(p, "test")
	p.merge_cd = 0.0
	reset.call()
	p.hp = p.max_hp
	k.cd["e"] = 0.0
	k.cast_e()
	ak.step(m, 0.1)
	var winding: bool = k.wind > 0.0
	var an0 := k.anchors
	ok("merge hold: the Anchor is winding up before the merge", winding, "wind %.2f" % k.wind)
	ok("merge hold: a merge is under way", ak.merge_now(p))
	ak.step(m, 1.2)
	ok(
		"merge hold: dredge's Anchor wind-up is dropped, no slam mid-merge", k.wind <= 0.0 and k.anchors == an0,
		"wind %.2f anchors %d" % [k.wind, k.anchors - an0]
	)
	m.queue_free()
	await main.get_tree().process_frame

## Upgrade parity (docs/heroes/dredge.md): per rank [RMB cd, dash recharge, E cd, E power, E stun, air pounce cd]
## against the source's tier II / III+IV numbers.
func _ranks() -> void:
	var r: Array = ak.setup("dredge", 9.0, "", false)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var k: DredgeKit = p.ak
	var up: Array = []
	for sl in ["sec", "dash", "kin"]: p.slot_lv[sl] = 1
	var pk := k.power("kin")
	for rk in [1, 2, 3]:
		for sl in ["sec", "dash", "kin"]: p.slot_lv[sl] = rk
		var cd_e: float = k.e_def()["cooldown"] * k.cd_k("kin")
		up.append([k.rmb_def()["cooldown"] * k.cd_k("sec"), p.dash_regen(), cd_e, k.power("kin") / pk, k._stun_t(),
				k.long_dash_cd()])
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 0.06
	ok("upgrade parity: Abyssal Hand cooldown 12 -> 10.3 -> 8.7 (-2.5s twice on the source's 18)",
			near.call(up[1][0], 10.33) and near.call(up[2][0], 8.67), str(up))
	ok("upgrade parity: Barge recharge 10 -> 8.2 -> 6.4 (-1.25s twice on the source's 7)",
			near.call(up[1][1], 8.21) and near.call(up[2][1], 6.43), str(up))
	ok("upgrade parity: air pounce 12.5 -> 10.5 -> 8.5 (-2s twice, the source's own numbers)",
			near.call(up[1][5], 10.5) and near.call(up[2][5], 8.5), str(up))
	ok("upgrade parity: Anchor cooldown 7 -> 5.5 -> 4.1, damage +20% / +40%, stun +0.1 / +0.4",
			near.call(up[1][2], 5.54) and near.call(up[2][2], 4.08)
			and near.call(up[1][3], 1.2) and near.call(up[2][3], 1.4)
			and near.call(up[1][4] - up[0][4], 0.1) and near.call(up[2][4] - up[0][4], 0.4), str(up))
	await ak.done(m)

## Parity pass (docs/heroes/dredge.md): the hold-to-fire gun against the footage (0040-0080): he walks between
## shots (at the shared firing walk), each volley is fanned on the cursor's direction at its shot, the slugs stop
## at 6.3 m whatever the cursor distance, and the recoil settles in ~0.2 s, inside the 0.5 s cycle.
func _parity_gun() -> void:
	var r: Array = ak.setup("dredge", 9.0, "", false)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	var k: DredgeKit = p.ak
	t_v.teleport(home + Vector3(-9.0, 0, 9.0))
	var from := p.pos
	var v0 := k.volleys
	var t := 0.0
	var heads: Array = []            # the mean flight direction of each volley, as it leaves
	var reach := 0.0
	var seen := {}
	while t < 1.02:
		var east := t < 0.5
		ak.aim_at(p, p.pos + (Vector3(2.0, 0, 0) if east else Vector3(0, 0, -2.0)))
		p.inp["fire"] = true
		p.inp["move"] = Vector2(0, 1)
		m.step(ak.DT)
		t += ak.DT
		var sum := Vector2.ZERO
		for sd in m.shots:
			if sd["by"] != p:
				continue
			var at: Vector3 = sd["pos"]
			var st: Vector3 = sd["start"]
			reach = maxf(reach, Vector2(at.x - st.x, at.z - st.z).length())
			if not seen.has(int(sd["sid"])):
				seen[int(sd["sid"])] = true
				sum += (sd["vel"] as Vector2).normalized()
		if sum.length() > 0.1:
			heads.append(sum.normalized())
	p.inp["fire"] = false
	p.inp["move"] = Vector2.ZERO
	var walk := p.flat_dist(from) / 1.02
	ok(
		"parity gun: he walks on while firing, at the shared firing walk (0.8), two or three volleys in 1s",
		k.volleys - v0 >= 2 and walk >= p.base_speed * 0.8 * 0.9,
		"%d volleys, %.1f m/s of %.1f" % [k.volleys - v0, walk, p.base_speed]
	)
	var turned: bool = heads.size() >= 2 and (heads[0] as Vector2).x > 0.9 and (heads[-1] as Vector2).y < -0.9
	ok("parity gun: each volley is fanned on the cursor's direction at its shot (east, then north)", turned,
			str(heads))
	ok("parity gun: the slugs stop at 6.3 m with the cursor at 2 m", absf(reach - 6.3) < 0.5, "%.2f m" % reach)
	var keys: Array = KMovesPair.MOVES["dr_shot"]["keys"]
	ok(
		"parity gun: the recoil kicks at 0.05s and is back on the aim by ~0.25s, inside the 0.5s cycle",
		absf(float(keys[1][0]) - 0.05) < 0.01 and float(keys[-2][0]) <= 0.3 and float(keys[-1][0]) < 0.5,
		"%.2f / %.2f / %.2f" % [float(keys[1][0]), float(keys[-2][0]), float(keys[-1][0])]
	)
	await ak.done(m)
