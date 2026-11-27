extends RefCounted
## Vex's parity pass and audit fixes (docs/heroes/gunslinger.md, "Parity pass"), run inside --gunslinger-combo-check
## (tools/hero_combo_check.gd): the rifle's cadence, how its rounds track the cursor while she walks, the 30-round
## drum that refills whenever the trigger rests, the firing brackets, the shouldered recoil pose, and the Burr
## Charge fired from the cannon's launcher (item 112), a tap she walks through, and the Longneedle's wide beam,
## pushed-out view and aim (item 68).
const ROUND_GAP := 0.08  # s between rounds held (the source's ~12 rounds/s, docs/WEAPON_FIRING_DATA.md)
const MAG := 30  # rounds in the drum (game data: a 30-round magazine)
const REFILL_DRY := 1.3  # s from running dry to the next round, the trigger held (0.35s rest + 30 at 40/s)
const REFILL_BY := 1.2  # s of rest that brings a drum back from 18 to full ("rapidly reloads when not firing")
const TURN_180 := 0.2  # s: the body turns 180 degrees to a new cursor (the source's 1280 deg/s: 0.14s)
const WALK_KEEP := 0.85  # share of her walk she keeps while firing
const OLD_NEEDLE_W := 0.5  # m either side of the line, before item 68
const CANCEL_ROWS := preload("res://tools/vex_cancel_rows_check.gd")  # her Cancels table, row by row
const SWEEP := 6.0  # rad/s the cursor swings round her (a round a step late would be 5.7 degrees off)
var c  # the combo check (ok, ac, helpers)


func _init(check) -> void:
	c = check


func run(m: Match, p: Hunter, k: GunslingerKit, t: Hunter, home: Vector3) -> void:
	_rounds(m, p, home)
	_tracking(m, p, home)
	_dash_aim(m, p, k, home)
	_drum(m, p, k, home)
	_falloff(m, p, home)
	_shift_charges(p)
	_brackets(m, p, home)
	_rifle_pose()
	_coin_throw(m, p, k, t, home)
	_needle(m, p, k, t, home)
	_audit(m, p, k, t, home)
	CANCEL_ROWS.new(c).run(m, p, k, t, home)
	p.inp["fire"] = false
	p.inp["move"] = Vector2.ZERO
	c.ac.step(m, 0.5)


func _rounds(m: Match, p: Hunter, home: Vector3) -> void:
	p.teleport(home)
	p.ammo = MAG
	p.fire_cd = 0.0
	var rec := {"t": 0.0, "n": p.shot_n, "at": []}
	c.ac.step(
		m,
		1.0,
		func():
			c.ac.aim_at(p, home + Vector3(6.0, 0, 0))
			p.inp["fire"] = true
			if p.shot_n > int(rec["n"]):
				rec["n"] = p.shot_n
				(rec["at"] as Array).append(rec["t"])
			rec["t"] = float(rec["t"]) + c.DT
	)
	p.inp["fire"] = false
	var at: Array = rec["at"]
	var even := at.size() >= 7
	for i in range(1, at.size()):
		even = even and absf(float(at[i]) - float(at[i - 1]) - ROUND_GAP) <= c.DT * 1.5
	c.ok("Vex parity LMB: held, a round every 0.08s", even, "%d rounds" % at.size())


## Walking while the cursor sweeps round her: every round leaves along the aim of its own step, and a cursor
## swung behind her turns her body round at the source's rate.
func _tracking(m: Match, p: Hunter, home: Vector3) -> void:
	c.ac.step(m, 0.5)
	p.teleport(home)
	p.ammo = MAG
	var sweep := {"a": 0.0, "worst": 0.0, "n": p.shot_n, "rounds": 0}
	p.inp["move"] = Vector2(0, 1)
	var p0 := p.pos
	c.ac.step(
		m,
		0.9,
		func():
			var sd: Dictionary = c._last_shot(m, p)
			if p.shot_n > int(sweep["n"]) and not sd.is_empty():
				sweep["n"] = p.shot_n
				sweep["rounds"] = int(sweep["rounds"]) + 1
				var off := absf((sd["vel"] as Vector2).angle_to(p.aim_dir()))
				sweep["worst"] = maxf(float(sweep["worst"]), rad_to_deg(off))
			sweep["a"] = float(sweep["a"]) + SWEEP * c.DT
			var aim := Vector2.from_angle(float(sweep["a"]))
			p.inp["aim"] = p.pos + Vector3(aim.x * 6.0, 0.9, aim.y * 6.0)
			p.inp["fire"] = true
	)
	var walked := p.flat_dist(p0) / 0.9
	p.inp["fire"] = false
	var plain := _walk_speed(m, p)
	c.ok(
		"Vex parity LMB: walking with the cursor sweeping round, every round leaves on the aim",
		int(sweep["rounds"]) >= 6 and float(sweep["worst"]) < rad_to_deg(float(p.wpn["spread"])) + 2.0,
		"%d rounds, worst %.1f degrees, walked %.2f m/s" % [sweep["rounds"], sweep["worst"], walked]
	)
	c.ok(
		"Vex parity LMB: she keeps walking while she fires (85% of her walk or more)",
		walked >= plain * WALK_KEEP,
		"%.2f of %.2f m/s" % [walked, plain]
	)
	p.inp["move"] = Vector2.ZERO
	c.ac.step(m, 0.3)
	c.ac.aim_at(p, p.pos + Vector3(5.0, 0, 0))
	c.ac.step(m, 0.3)
	c.ac.aim_at(p, p.pos + Vector3(-5.0, 0, 0))
	var turn := {"t": c.DT, "done": -1.0}
	c.ac.step(
		m,
		0.4,
		func():
			if float(turn["done"]) < 0.0 and absf(wrapf(p.face - PI * 0.5, -PI, PI)) < deg_to_rad(10.0):
				turn["done"] = turn["t"]
			turn["t"] = float(turn["t"]) + c.DT
	)
	c.ok(
		"Vex parity LMB: the body turns 180 degrees to the cursor inside 0.2s (source 1280 deg/s)",
		float(turn["done"]) > 0.0 and float(turn["done"]) <= TURN_180,
		"%.2f s" % turn["done"]
	)


## The drum: 30 rounds; resting refills it fast (none in the first beat of a pause).
func _drum(m: Match, p: Hunter, k: GunslingerKit, home: Vector3) -> void:
	p.teleport(home)
	p.ammo = MAG
	c.ac.step(m, 0.5)
	p.fire_cd = 0.0
	var s0 := p.shot_n
	c.ac.aim_at(p, home + Vector3(6.0, 0, 0))
	var heard: Array = []
	var ear := _ear(heard, home)
	for i in 200:
		if p.shot_n - s0 >= 12:
			break
		p.inp["fire"] = true
		m.step(c.DT)
	p.inp["fire"] = false
	var after12 := p.ammo
	var t_full := {"t": 0.0, "at": -1.0, "early": p.ammo}
	c.ac.step(m, 0.25)
	t_full["early"] = p.ammo
	c.ac.step(
		m,
		2.0,
		func():
			if float(t_full["at"]) < 0.0 and p.ammo >= MAG:
				t_full["at"] = t_full["t"]
			t_full["t"] = float(t_full["t"]) + c.DT
	)
	Sfx.played.disconnect(ear)
	var own := String(p.wpn["sfx"])
	# playtest 11-13: a wind-up whine played on the first round of every string
	c.ok(
		"Vex sounds: a string and the top-up after it play only the rifle round (no wind-up, no reload)",
		heard.has(own) and heard.all(func(sn): return sn == own),
		"kit sounds %s" % [heard]
	)
	c.ok(
		"Vex parity LMB: a 30-round drum that refills fast once the trigger rests (none in the first beat)",
		(
			int(p.wpn["mag"]) == MAG
			and after12 == MAG - 12
			and int(t_full["early"]) == MAG - 12
			and float(t_full["at"]) > 0.0
			and float(t_full["at"]) <= REFILL_BY
		),
		"after 12: %d, after 0.25s rest: %d, full at %.2f s" % [after12, t_full["early"], t_full["at"]]
	)
	_dry(m, p, k, home)


## The rifle's falloff: each round of a string carries its share of full damage (100% down to the 50% floor over
## the first ten rounds) and the look thins with it; a pause starts the string over.
func _falloff(m: Match, p: Hunter, home: Vector3) -> void:
	p.teleport(home)
	p.ammo = MAG
	c.ac.step(m, 0.6)
	p.fire_cd = 0.0
	c.ac.aim_at(p, home + Vector3(6.0, 0, 0))
	var share: Array[float] = []
	var seen := p.shot_n
	for i in 200:
		if share.size() >= 20:
			break
		p.inp["fire"] = true
		m.step(c.DT)
		if p.shot_n != seen:
			seen = p.shot_n
			share.append(_last_share(m, p))
	p.inp["fire"] = false
	c.ac.step(m, 0.6)
	p.fire_cd = 0.0
	p.inp["fire"] = true
	var again := p.shot_n
	for i in 40:
		m.step(c.DT)
		if p.shot_n != again:
			break
	p.inp["fire"] = false
	var restart := _last_share(m, p)
	var edge := int(float(MAG) * float(p.wpn["low_mag_at"]))
	var low_k := float(p.wpn["low_mag_dmg"])
	c.ok(
		"Vex LMB: full damage with half a drum or more, %d%% under it; a pause starts over" % int(low_k * 100),
		(
			share.size() == 20
			and is_equal_approx(share[0], 1.0)
			and is_equal_approx(share[MAG - edge - 1], 1.0)
			and is_equal_approx(share[MAG - edge], low_k)
			and is_equal_approx(share[19], low_k)
			and is_equal_approx(restart, 1.0)
		),
		"shares %s, after a pause %.2f" % [share, restart]
	)


func _last_share(m: Match, p: Hunter) -> float:
	var shots: Array = m.get("shots")
	for i in range(shots.size() - 1, -1, -1):
		if shots[i]["by"] == p:
			return float(shots[i]["dmg"]) / (float(p.wpn["dmg"]) * m.dmg_mult(p))
	return -1.0


## Item 109: a dash east with the cursor north, LMB held from before it to after it. Every round leaves north, none
## goes missing across the dash, and the body stays on the aim while the legs turn toward the dash.
func _dash_aim(m: Match, p: Hunter, _k: GunslingerKit, home: Vector3) -> void:
	for kind in ["tap", "held", "air"]:
		c.ac.step(m, 0.5)
		p.teleport(home)
		c.ac.step(m, 0.1)
		p.ammo = MAG
		p.fire_cd = 0.0
		p.dashes = p.max_dashes()
		p.inp["move"] = Vector2.ZERO
		if kind == "air":
			p.do_jump()
			c.ac.step(m, 0.15, func(): p.inp["aim"] = p.pos + Vector3(0, 0.9, -8.0))
		var rec := {"t": 0.0, "n": p.shot_n, "at": [], "worst": 0.0, "face": 0.0, "legs": 0.0}
		rec.merge({"steps": 0, "dash_rounds": 0})
		var each := func():
			p.inp["aim"] = p.pos + Vector3(0, 0.9, -8.0)
			p.inp["fire"] = true
			p.inp["dash_down"] = kind == "held" and float(rec["t"]) < 0.5
			if p.shot_n > int(rec["n"]):
				rec["n"] = p.shot_n
				(rec["at"] as Array).append(rec["t"])
				var sd: Dictionary = c._last_shot(m, p)
				var off := absf(rad_to_deg((sd["vel"] as Vector2).angle_to(Vector2(0, -1))))
				rec["worst"] = maxf(float(rec["worst"]), off)
				if p.roll_t > 0.0:
					rec["dash_rounds"] = int(rec["dash_rounds"]) + 1
			if p.roll_t > 0.0 and float(rec["t"]) > 0.15:
				rec["steps"] = int(rec["steps"]) + 1
				rec["face"] = maxf(float(rec["face"]), absf(rad_to_deg(wrapf(p.face, -PI, PI))))
				p.render(c.DT, 1.0)  # (headless steps don't pose her)
				if p.anim != null:
					rec["legs"] = maxf(float(rec["legs"]), absf(p.anim.legs_yaw))
			rec["t"] = float(rec["t"]) + c.DT
		p.inp["fire"] = true
		p.inp["aim"] = p.pos + Vector3(0, 0.9, -8.0)
		p.inp["move"] = Vector2(1, 0)
		p.inp["dash_down"] = kind == "held"
		p.do_dash()
		c.ac.step(m, 0.9, each)
		p.inp["fire"] = false
		p.inp["move"] = Vector2.ZERO
		p.inp["dash_down"] = false
		var at: Array = rec["at"]
		var gap := 0.0
		for i in range(1, at.size()):
			gap = maxf(gap, float(at[i]) - float(at[i - 1]))
		c.ok(
			"Vex item 109 (%s): dashing east at a north cursor, every round goes north (within 5 degrees)" % kind,
			at.size() >= 6 and int(rec["dash_rounds"]) >= 2 and float(rec["worst"]) <= 5.0,
			"%d rounds, %d in the dash, worst %.1f deg" % [at.size(), rec["dash_rounds"], rec["worst"]]
		)
		c.ok(
			"Vex item 109 (%s): no gap in the rifle's cadence across the dash" % kind,
			gap <= ROUND_GAP + c.DT * 1.5,
			"longest gap %.3f s" % gap
		)
		c.ok(
			"Vex item 109 (%s): the body stays on the aim through the dash, the legs follow it" % kind,
			int(rec["steps"]) > 0 and float(rec["face"]) <= 5.0 and float(rec["legs"]) > 0.5,
			"body %.1f deg off, legs turned %.2f rad, %d steps" % [rec["face"], rec["legs"], rec["steps"]]
		)
	p.anim = null  # (the rest of the check runs unposed, as a headless step does)
	c.ac.step(m, 0.5)


## Run dry with the trigger held: there is no reload, nothing fires while the
## drum refills, the count climbs back (the HUD shows it), and once full the held string picks up again.
func _dry(m: Match, p: Hunter, k: GunslingerKit, home: Vector3) -> void:
	p.fire_cd = 0.0
	var run := {
		"t": 0.0,
		"dry_at": -1.0,
		"back_at": -1.0,
		"shots_dry": 0,
		"s": p.shot_n,
		"low": MAG,
		"dries": 0,
		"was_dry": k.dry
	}
	var heard: Array = []
	var ear := _ear(heard, home)
	c.ac.step(
		m,
		6.0,
		func():
			c.ac.aim_at(p, home + Vector3(6.0, 0, 0))
			p.inp["fire"] = true
			if k.dry and not run["was_dry"]:
				run["dries"] = int(run["dries"]) + 1
			run["was_dry"] = k.dry
			if float(run["dry_at"]) < 0.0 and p.ammo <= 0:
				run["dry_at"] = run["t"]
				run["s"] = p.shot_n
			elif float(run["dry_at"]) >= 0.0 and float(run["back_at"]) < 0.0:
				if p.shot_n > int(run["s"]):
					run["back_at"] = run["t"]
					run["low"] = p.ammo
			run["t"] = float(run["t"]) + c.DT
	)
	Sfx.played.disconnect(ear)
	p.inp["fire"] = false
	var cues := heard.count(GunslingerKit.RELOAD_SFX)
	var dries := int(run["dries"])
	c.ok(
		"Vex sounds: each time the drum runs dry the reload cue plays once",
		dries > 0 and cues == dries,
		"%d reload cues, %d times dry" % [cues, dries]
	)
	var gap := float(run["back_at"]) - float(run["dry_at"])
	c.ok(
		"Vex parity LMB: run dry, no reload; the trigger is dead until the drum refills (about 1.1s), then fires",
		(
			float(run["dry_at"]) > 0.0
			and gap > 0.9
			and gap < REFILL_DRY
			and int(run["low"]) >= MAG - 1
			and p.wpn.get("ammo", true)
		),
		"dry at %.2f, firing again %.2f s later with %d rounds" % [run["dry_at"], gap, run["low"]]
	)
	c.ac.step(m, 1.5)


## Starts noting the kit's own sounds (gunslinger_*, vn_*) into `out`, heard from `at` (Sfx drops a sound out of
## hearing); disconnect the returned ear from Sfx.played to stop.
func _ear(out: Array, at: Vector3) -> Callable:
	Sfx.listener = at
	var ear := func(sname: String, _at: Variant, _vol: float, _pitch: float) -> void:
		if sname.begins_with("gunslinger_") or sname.begins_with("vn_"):
			out.append(sname)
	Sfx.played.connect(ear)
	return ear


## The firing brackets: two arcs either side of her while she fires (your screen only), gone soon after.
func _brackets(m: Match, p: Hunter, home: Vector3) -> void:
	p.teleport(home)
	p.ammo = MAG
	c.ac.step(
		m,
		0.4,
		func():
			c.ac.aim_at(p, home + Vector3(6.0, 0, 0))
			p.inp["fire"] = true
	)
	var e := AimKit.entry(p, "lmb_bracket1")
	var on := AimKit.shown(p, "lmb_bracket1") and AimKit.shown(p, "lmb_bracket-1") and not bool(e.get("all", true))
	p.inp["fire"] = false
	c.ac.step(m, 0.4)
	c.ok(
		"Vex parity LMB: firing brackets either side of her while she fires (yours only), gone after",
		(
			on
			and absf(float(e.get("radius", 0.0)) - GunslingerKit.BRACKET_R) < 0.01
			and not AimKit.shown(p, "lmb_bracket1")
		)
	)


## The rifle's pose: each round kicks the gun (stock back, muzzle up) by 0.025s and is back on the shouldered
## pose by 0.09, before the next round; the legs are a stance (walking, they keep walking).
func _rifle_pose() -> void:
	var mv: Dictionary = KMovesVV.MOVES["gunslinger_lmb"]
	var a := HunterAnim.km_sample("gunslinger_lmb", 0.0)
	var b := HunterAnim.km_sample("gunslinger_lmb", 0.09)
	var kick := HunterAnim.km_sample("gunslinger_lmb", 0.025)
	var same := (
		is_equal_approx(a["p"], b["p"])
		and is_equal_approx(a["gp"], b["gp"])
		and (a["wo"] as Vector3).is_equal_approx(b["wo"])
	)
	c.ok(
		"Vex parity LMB: each round kicks the gun by 0.025s, back on the shoulder by 0.09 (replayed every round)",
		(
			same
			and float(kick["gp"]) > 0.15
			and absf(float(kick["p"]) - float(a["p"])) < 0.15
			and bool(mv.get("stance", false))
		),
		"gp %.2f, torso %.2f -> %.2f" % [kick["gp"], a["p"], kick["p"]]
	)


## Item 112 and the 11-17 playtest: the Coin Blast is a tap, a coin flicked off her free hand: a hand flick in the
## move and no kick on the gun, out within a step of the press, once however long the key stays down, and she keeps
## walking.
func _coin_throw(m: Match, p: Hunter, k: GunslingerKit, t: Hunter, home: Vector3) -> void:
	var keys := KMovesVV.MOVES["gunslinger_rmb"]["keys"] as Array
	var stance := bool(KMovesVV.MOVES["gunslinger_rmb"].get("stance", false))
	var thrown := keys.any(
		func(key: Array) -> bool:
			return float((key[1] as Dictionary).get("hw", 0.0)) > 0.5 and (key[1] as Dictionary).has("fl")
	)
	var gun_still := keys.all(func(key: Array) -> bool: return not (key[1] as Dictionary).has("gp"))
	c.ok(
		"Vex coin: a flick of the free hand throws the coin, the gun arm out of it, legs free to walk",
		thrown and stance and gun_still,
		"%d keys" % keys.size()
	)
	t.teleport(home + Vector3(30, 0, 8))
	p.teleport(home)
	k.cd["rmb"] = 0.0
	k.ch_rmb = 1.0
	c.ac.aim_at(p, home + Vector3(6.0, 0, 0))
	var plain := _walk_speed(m, p)
	var p0 := p.pos
	var flicks0 := k.flicks
	var burrs0 := k.burrs.size()
	p.inp["sec"] = true
	p.inp["sec_hold"] = true
	m.step(c.DT)
	var out_now := k.burrs.size() == burrs0 + 1 and float(k.cd["rmb"]) > 0.0
	var b: Dictionary = k.burrs[-1] if not k.burrs.is_empty() else {}
	var coin: Node3D = b.get("node")
	var faces := coin != null and coin.has_node("Spin/Glow")
	var spin0 := float(b.get("spin", 0.0))
	m.step(c.DT)
	var flipping := float(b.get("spin", 0.0)) > spin0
	c.ac.step(m, 1.0, func(): p.inp["sec_hold"] = true)
	p.inp["sec_hold"] = false
	var walked: float = p.flat_dist(p0) / (1.0 + 2.0 * c.DT)
	p.inp["move"] = Vector2.ZERO
	c.ok(
		"Vex coin: a tap throws the coin within one step, a gold coin with a green-fire rim, flipping end over end",
		out_now and faces and flipping,
		"spin %.2f -> %.2f" % [spin0, float(b.get("spin", 0.0))]
	)
	c.ok(
		"Vex item 112: a 1s hold throws once, at the press",
		k.flicks == flicks0 + 1 and not k.rmb_down,
		"%d flicks" % (k.flicks - flicks0)
	)
	c.ac.step(m, 1.2)
	_from_palm(m, p, k, home)
	c.ok(
		"Vex item 112: she keeps walking through the throw (85% of her walk or more)",
		walked >= plain * WALK_KEEP,
		"%.2f of %.2f m/s" % [walked, plain]
	)
	c.ac.step(m, 1.5)


## 11-17 playtest: the coin leaves her free hand's palm at the press and the Palm Lance's beam starts there too
## (its charge orb sits there in the data); neither comes out of the gun's muzzle.
func _from_palm(m: Match, p: Hunter, k: GunslingerKit, home: Vector3) -> void:
	p.teleport(home)
	c.ac.step(m, 0.1)
	var at := HeroVfx.of(m).anchor_pos(p, "palm")
	k.cd["rmb"] = 0.0
	k.ch_rmb = 1.0
	k.press_rmb()
	var b: Dictionary = k.burrs[-1] if not k.burrs.is_empty() else {}
	var coin := not b.is_empty() and (b["pos"] as Vector3).distance_to(at) < 0.01
	var flash := k.last_flick.distance_to(at) < 0.01
	c.ok("Vex coin: the coin and its glint leave her palm", coin and flash, "coin %s, glint %s" % [coin, flash])
	c.ac.step(m, 1.2)
	k.cd["e"] = 0.0
	k.use_e()
	var t := 0.0
	var palm := Vector3.INF
	while not k.needle.is_empty() and t < 1.0:
		palm = k.palm_at()
		m.step(c.DT)
		t += c.DT
	var gun := k._gun_muzzle()
	var off_gun := gun == null or k.last_beam.distance_to(gun.global_position) > 0.2
	var looks: Dictionary = HeroVfx.data("gunslinger")["moves"]
	var orb := (looks["e_charge"]["fx"] as Array).all(func(l: Dictionary) -> bool: return l.get("at") == "palm")
	c.ok(
		"Vex palm: the Palm Lance charges at her palm and its beam starts there, not at the gun's muzzle",
		k.last_beam.distance_to(palm) < 0.2 and off_gun and orb,
		"beam %.2f m off the palm, off the gun %s, orb at the palm %s" % [k.last_beam.distance_to(palm), off_gun, orb]
	)
	c.ac.step(m, 1.2)


## Item 68: the Longneedle hits a line at least 1.5x as wide, the view pushes out at least 15% through the cast, along
## the aim, with no shake, and is back within 0.3 s of the shot; the beam goes exactly where the line last pointed.
func _needle(m: Match, p: Hunter, k: GunslingerKit, t: Hunter, home: Vector3) -> void:
	var cam: CamRig = m.cam
	c.ac.fresh(t)
	var off := float(k.e_def()["width"]) + t.r * 0.5  # past the old edge, inside the new one
	t.teleport(home + Vector3(9.0, 0, off))
	p.teleport(home)
	c.ac.step(m, 0.3)
	var east := home + Vector3(18.0, 0, 0)  # the full range: the push-out scales with the aim distance (item 144b)
	c.ac.aim_at(p, east)
	cam.cast_k = 0.0
	var hits0 := k.needle_hits
	k.cd["e"] = 0.0
	k.use_e()
	var rec := {
		"wide": 1.0,
		"aim": Vector2.ZERO,
		"dir": Vector2.ZERO,
		"face": 0.0,
		"t": 0.0,
		"shake": 0.0,
		"pan": 0.0,
		"mk": 0.0
	}  # mk: the largest move_k seen while the needle charges (the source stands still)
	var charging := func():
		c.ac.aim_at(p, east + Vector3(0, 0, float(rec["t"]) * 2.0))  # the cursor drifts: the line follows it
		cam.follow(p.pos, c.DT, false)
		rec["wide"] = maxf(float(rec["wide"]), cam.cast_wide())
		rec["shake"] = float(rec["shake"]) + cam.shake_left
		if not k.needle.is_empty():
			rec["aim"] = p.aim_dir()
			rec["dir"] = AimKit.entry(p, "e").get("dir", Vector2.ZERO)
			rec["face"] = absf(rad_to_deg(Vector2(-sin(p.face), -cos(p.face)).angle_to(p.aim_dir())))
			rec["pan"] = maxf(float(rec["pan"]), (cam.focus - cam.base).dot(Vector3(1, 0, 0)))
			rec["mk"] = maxf(float(rec["mk"]), k.move_k())
		rec["t"] = float(rec["t"]) + c.DT
	while not k.needle.is_empty() and float(rec["t"]) < 1.0:
		charging.call()
		m.step(c.DT)
	var at_shot := cam.cast_wide()
	for i in int(0.3 / c.DT):
		cam.follow(p.pos, c.DT, false)
		m.step(c.DT)
	var wide_ok := float(k.e_def()["width"]) >= OLD_NEEDLE_W * 1.5
	c.ok(
		"Vex cast-move: rooted through the Longneedle cast (footage: still through its 0.6 s cast bar)",
		float(rec["mk"]) == 0.0 and is_equal_approx(float(k.e_def()["self_slow"]), 1.0),
		"move_k %.2f" % float(rec["mk"])
	)
	c.ok(
		"Vex item 68: the beam hits a line at least 1.5x as wide, and drawn that wide",
		wide_ok and k.needle_hits > hits0 and absf(k.beam_width() - float(k.e_def()["width"]) * 2.0) < 0.001,
		"%.2f m either side, a foe %.2f m off the line: %d hit" % [k.e_def()["width"], off, k.needle_hits - hits0]
	)
	c.ok(
		"Vex item 68: the view is at least 15% wider through the cast and leans along the aim, no shake",
		float(rec["wide"]) >= 1.15 and at_shot >= 1.15 and float(rec["pan"]) > 2.0 and float(rec["shake"]) == 0.0,
		"x%.2f, x%.2f at the shot, leaning %.1f m" % [rec["wide"], at_shot, rec["pan"]]
	)
	c.ok("Vex item 68: the view is back within 0.3s of the shot", cam.cast_wide() < 1.005, "x%.3f" % cam.cast_wide())
	var d_dir := rad_to_deg(absf((k.needle_dir).angle_to(rec["dir"])))
	var d_aim := rad_to_deg(absf((k.needle_dir).angle_to(rec["aim"])))
	c.ok(
		"Vex item 68: the beam fires along the line and the aim at release (1 degree); she faces it throughout",
		d_dir <= 1.0 and d_aim <= 1.0 and float(rec["face"]) <= 5.0,
		"line %.2f, aim %.2f, face %.1f deg" % [d_dir, d_aim, rec["face"]]
	)
	var was := p.ctrl
	p.ctrl = "idle"
	cam.cast_left = 0.0
	k.cd["e"] = 0.0
	k.commit_end = 0.0
	k.use_e()
	c.ac.step(m, 0.1)
	var quiet := cam.cast_left <= 0.0 and not k.needle.is_empty()
	k._end_needle()
	p.ctrl = was
	c.ok("Vex item 68: anyone else's cast leaves the camera alone", quiet)
	c.ac.step(m, 0.3)


## Her plain walk (move held down the screen, not firing), in m/s; she is still walking when it returns.
func _walk_speed(m: Match, p: Hunter) -> float:
	p.inp["move"] = Vector2(0, 1)
	c.ac.step(m, 0.3)
	var p0 := p.pos
	c.ac.step(m, 0.6)
	return p.flat_dist(p0) / 0.6


## Her recipes played since `before` that lay a shape on the ground (a ring, a scorch, a vortex, a flame wall).
static func _ground_looks(v: HeroVfx, before: Dictionary) -> Array:
	var moves: Dictionary = HeroVfx.data("gunslinger")["moves"]
	return v.plays.keys().filter(
		func(mv: String) -> bool:
			var layers: Array = (moves.get(mv, {}) as Dictionary).get("fx", [])
			return (
				int(v.plays[mv]) > int(before.get(mv, 0))
				and layers.any(func(l: Dictionary) -> bool: return l["p"] in ["ring", "scorch", "vortex", "skirt"])
			)
	)


## The audit (Nov 3): no cosmetic ground rings, scorches or flame walls on her slide, its rank-3 end or a knock
## (a ground shape means gameplay); Dazed is only a damage window (no slow, the data); her
## air roll fires the rifle as its dash row says.
func _audit(m: Match, p: Hunter, k: GunslingerKit, t: Hunter, home: Vector3) -> void:
	var v := HeroVfx.of(m)
	var plays0 := v.plays.duplicate()
	p.teleport(home)
	p.slot_lv["dash"] = 3
	p.dashes = p.max_dashes()
	p.inp["move"] = Vector2(0, 1)
	p.do_dash()
	c.ac.step(m, 1.0)
	var slid := k.last_dash_kind
	p.inp["move"] = Vector2.ZERO
	p.slot_lv["dash"] = 1
	k.knocked.clear()
	p.dashes = 0.0
	t.hp = 0.0
	t.downed = true
	k.on_deal(t, 5.0, {"src": "abil", "ab": "k1"})
	DashReset.takedown(p, t)  # the knock's dash back is the game-wide rule now (decision 0022), as Match runs it
	var knocked := p.dashes >= 1.0
	c.ac.step(m, 0.5)
	t.downed = false
	t.hp = t.max_hp
	var on_ground := _ground_looks(v, plays0)
	var streaked := int(v.plays.get("slide", 0)) > int(plays0.get("slide", 0))
	c.ok(
		"Vex audit: no ground ring, scorch or flame wall on a slide, its rank-3 end or a knock",
		slid != "" and knocked and on_ground.is_empty() and streaked,
		"%s, knock %s, %s" % [slid, knocked, str(on_ground)]
	)
	c.ac.fresh(t)
	KitStatus.apply(t, "rat", 1.4)
	c.ok(
		"Vex audit: Dazed is a damage window only, no slow (the data)",
		KitStatus.rattled(t) and t.slow_t <= 0.0,
		"slow %.2f for %.2f s" % [t.slow_k, t.slow_t]
	)
	KitStatus.clear_rattled(t)
	p.teleport(home)
	p.do_jump()
	c.ac.step(m, 0.15)
	p.dashes = 0.0
	p.ex_cd = 0.0
	k.on_dash(true)
	var rolled := k.last_dash_kind == "air" and p.roll_t > 0.0
	c.ok(
		"Vex audit: the rifle fires through her air roll (its dash row: fire)",
		rolled and k.fires_in_dash(),
		"kind %s roll %.2f" % [k.last_dash_kind, p.roll_t]
	)
	c.ac.step(m, 1.0)
	_into_dash(m, p, k, t, home)


## Shift during her moves (the into_dash rows, all "fire": owner item 51, every move combos with Shift): pressed in
## the Longneedle's charge she slides and the beam still fires; pressed right after a Burr Charge she slides at once.
func _into_dash(m: Match, p: Hunter, k: GunslingerKit, t: Hunter, home: Vector3) -> void:
	c.ac.fresh(t)
	p.teleport(home)
	t.teleport(home + Vector3(6.0, 0, 0))
	c.ac.step(m, 0.2)
	t.inv_t = 0.0
	c.ac.aim_at(p, t.pos)
	k.cd["e"] = 0.0
	var hits0 := k.needle_hits
	k.use_e()
	c.ac.step(m, 0.2)
	p.dashes = p.max_dashes()
	# back along the line: the beam is yaw-locked, so a sideways slide would walk off it
	p.inp["move"] = Vector2(-1, 0)
	p.do_dash()
	var p0 := p.pos
	c.ac.step(m, 0.9)
	p.inp["move"] = Vector2.ZERO
	var e_ok := k.needle_hits > hits0 and p.flat_dist(p0) > 1.0
	c.ac.fresh(t)
	c.ac.step(m, 0.5)
	k.cd["rmb"] = 0.0
	k.ch_rmb = 1.0
	var n0 := k.burrs.size()
	k.press_rmb()
	var thrown := k.burrs.size() > n0
	p.dashes = p.max_dashes()
	p.inp["move"] = Vector2(0, -1)
	p.do_dash()
	var slid := p.roll_t > 0.0
	c.ac.step(m, 0.3)
	p.inp["move"] = Vector2.ZERO
	c.ac.step(m, 0.1)
	var rmb_ok := thrown and slid
	var rows := ["lmb", "rmb", "e", "x", "q"].all(
		func(sl: String) -> bool:
			var r := DashFlow.into_dash_of("gunslinger", sl)
			return String(r.get("mode", "")) == "fire" and String(r.get("source", "")) != ""
	)
	c.ok(
		"Vex audit: Shift in the Longneedle charge slides and the beam fires; after a Burr Charge she slides at once",
		e_ok and rmb_ok and rows,
		"E %s RMB %s rows %s" % [e_ok, rmb_ok, rows]
	)
	c.ac.step(m, 1.5)


## The source's Combat Slide is one charge: her own dash.charges, even over a two-charge class dodge.
func _shift_charges(p: Hunter) -> void:
	var roll := p.dodge_def
	p.dodge_def = Content.class_dodge("heavy")
	var over_two := p.max_dashes()
	p.dodge_def = roll
	var own := p.max_dashes()
	c.ok(
		"Vex Shift: one charge (the source's slide), her own count over a two-charge class dodge",
		own == 1.0 and over_two == 1.0,
		"%.0f, over a two-charge dodge %.0f" % [own, over_two]
	)
