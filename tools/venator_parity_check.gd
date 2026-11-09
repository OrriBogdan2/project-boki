extends RefCounted
## Vex's parity pass and audit fixes (docs/heroes/gunslinger.md, "Parity pass"), run inside --gunslinger-combo-check
## (tools/hero_combo_check.gd): the rifle's cadence, how its rounds track the cursor while she walks, the 30-round
## drum that refills whenever the trigger rests, the firing brackets, the shouldered recoil pose, and the Burr
## Charge fired from the cannon's launcher (item 112), a tap she walks through, and the Longneedle's wide beam,
## pushed-out view and aim (item 68).
const ROUND_GAP := 0.12      # s between rounds held
const MAG := 30              # rounds in the drum (game data: a 30-round magazine)
const REFILL_DRY := 1.3      # s from running dry to the next round, the trigger held (0.35s rest + 30 at 40/s)
const REFILL_BY := 1.2       # s of rest that brings a drum back from 18 to full ("rapidly reloads when not firing")
const TURN_180 := 0.2        # s: the body turns 180 degrees to a new cursor (the source's 1280 deg/s: 0.14s)
const WALK_KEEP := 0.85      # share of her walk she keeps while firing
const OLD_NEEDLE_W := 0.5    # m either side of the line, before item 68
const SWEEP := 6.0           # rad/s the cursor swings round her (a round a step late would be 5.7 degrees off)
var C                        # the combo check (ok, ac, helpers)

func _init(check) -> void:
	C = check

func run(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	_rounds(m, P, home)
	_tracking(m, P, home)
	_dash_aim(m, P, K, home)
	_drum(m, P, K, home)
	_string_fades(m, P, home)
	_shift(m, P, home)
	_brackets(m, P, home)
	_rifle_pose()
	_launcher(m, P, K, T, home)
	_needle(m, P, K, T, home)
	_audit(m, P, K, T, home)
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	C.ac.step(m, 0.5)

func _rounds(m: Match, P: Hunter, home: Vector3) -> void:
	P.teleport(home)
	P.ammo = MAG
	P.fire_cd = 0.0
	var rec := {"t": 0.0, "n": P.shot_n, "at": []}
	C.ac.step(m, 1.0, func():
		C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
		P.inp["fire"] = true
		if P.shot_n > int(rec["n"]):
			rec["n"] = P.shot_n
			(rec["at"] as Array).append(rec["t"])
		rec["t"] = float(rec["t"]) + C.DT)
	P.inp["fire"] = false
	var at: Array = rec["at"]
	var even := at.size() >= 7
	for i in range(1, at.size()):
		even = even and absf(float(at[i]) - float(at[i - 1]) - ROUND_GAP) <= C.DT * 1.5
	C.ok("Vex parity LMB: held, a round every 0.12s", even, "%d rounds" % at.size())

## Walking while the cursor sweeps round her: every round leaves along the aim of its own step, and a cursor
## swung behind her turns her body round at the source's rate.
func _tracking(m: Match, P: Hunter, home: Vector3) -> void:
	C.ac.step(m, 0.5)
	P.teleport(home)
	P.ammo = MAG
	var sweep := {"a": 0.0, "worst": 0.0, "n": P.shot_n, "rounds": 0}
	P.inp["move"] = Vector2(0, 1)
	var p0 := P.pos
	C.ac.step(m, 0.9, func():
		var sd: Dictionary = C._last_shot(m, P)
		if P.shot_n > int(sweep["n"]) and not sd.is_empty():
			sweep["n"] = P.shot_n
			sweep["rounds"] = int(sweep["rounds"]) + 1
			var off := absf((sd["vel"] as Vector2).angle_to(P.aim_dir()))
			sweep["worst"] = maxf(float(sweep["worst"]), rad_to_deg(off))
		sweep["a"] = float(sweep["a"]) + SWEEP * C.DT
		var aim := Vector2.from_angle(float(sweep["a"]))
		P.inp["aim"] = P.pos + Vector3(aim.x * 6.0, 0.9, aim.y * 6.0)
		P.inp["fire"] = true)
	var walked := P.flat_dist(p0) / 0.9
	P.inp["fire"] = false
	var plain := _walk_speed(m, P)
	C.ok("Vex parity LMB: walking with the cursor sweeping round, every round leaves on the aim",
			int(sweep["rounds"]) >= 6 and float(sweep["worst"]) < rad_to_deg(float(P.wpn["spread"])) + 2.0,
			"%d rounds, worst %.1f degrees, walked %.2f m/s" % [sweep["rounds"], sweep["worst"], walked])
	C.ok("Vex parity LMB: she keeps walking while she fires (85% of her walk or more)",
			walked >= plain * WALK_KEEP, "%.2f of %.2f m/s" % [walked, plain])
	P.inp["move"] = Vector2.ZERO
	C.ac.step(m, 0.3)
	C.ac.aim_at(P, P.pos + Vector3(5.0, 0, 0))
	C.ac.step(m, 0.3)
	C.ac.aim_at(P, P.pos + Vector3(-5.0, 0, 0))
	var turn := {"t": C.DT, "done": -1.0}
	C.ac.step(m, 0.4, func():
		if float(turn["done"]) < 0.0 and absf(wrapf(P.face - PI * 0.5, -PI, PI)) < deg_to_rad(10.0):
			turn["done"] = turn["t"]
		turn["t"] = float(turn["t"]) + C.DT)
	C.ok("Vex parity LMB: the body turns 180 degrees to the cursor inside 0.2s (source 1280 deg/s)",
			float(turn["done"]) > 0.0 and float(turn["done"]) <= TURN_180, "%.2f s" % turn["done"])

## The drum: 30 rounds; resting refills it fast (none in the first beat of a pause).
func _drum(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	P.teleport(home)
	P.ammo = MAG
	C.ac.step(m, 0.5)
	P.fire_cd = 0.0
	var s0 := P.shot_n
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	for i in 200:
		if P.shot_n - s0 >= 12:
			break
		P.inp["fire"] = true
		m.step(C.DT)
	P.inp["fire"] = false
	var after12 := P.ammo
	var t_full := {"t": 0.0, "at": -1.0, "early": P.ammo}
	C.ac.step(m, 0.25)
	t_full["early"] = P.ammo
	C.ac.step(m, 2.0, func():
		if float(t_full["at"]) < 0.0 and P.ammo >= MAG:
			t_full["at"] = t_full["t"]
		t_full["t"] = float(t_full["t"]) + C.DT)
	C.ok("Vex parity LMB: a 30-round drum that refills fast once the trigger rests (none in the first beat)",
			int(P.wpn["mag"]) == MAG and after12 == MAG - 12 and int(t_full["early"]) == MAG - 12
			and float(t_full["at"]) > 0.0 and float(t_full["at"]) <= REFILL_BY,
			"after 12: %d, after 0.25s rest: %d, full at %.2f s" % [after12, t_full["early"], t_full["at"]])
	_dry(m, P, K, home)

## Ghost's Combat Slide is one charge: the archetype's own count wins over its weight class's, and a perk's or a
## gear's extra charge still adds on top.
func _shift_charges(P: Hunter) -> void:
	var base := P.max_dashes()
	P.add_perk("secondwind")
	var perked := P.max_dashes()
	P.perks.clear()
	C.ok("Vex Shift: one charge (Ghost's Combat Slide), Second Wind still adds one",
			base == 1.0 and perked == base + 1.0 and P.max_dashes() == base,
			"%.0f, with Second Wind %.0f" % [base, perked])

## The wiki: the rifle's damage decays over the first 10 rounds to 50%. Each round carries its share of full damage
## (sus_k) and its tracer is drawn that much smaller, back to full size after a pause.
func _string_fades(m: Match, P: Hunter, home: Vector3) -> void:
	P.teleport(home)
	C.ac.step(m, 0.6)
	P.ammo = MAG
	P.fire_cd = 0.0
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	var vfx := HeroVfx.of(m)
	var rec := {"n": P.shot_n, "k": [], "w": [], "sd": {}}
	var fire := func():
		P.inp["fire"] = true
		# the kit dresses a round on the step after it leaves: its two newest ribbons (shot nodes are pooled, so
		# older ribbons may follow the same node), the outer one is the wider
		var node: Variant = (rec["sd"] as Dictionary).get("node")
		var mine: Array = vfx.ribbons.filter(func(r: Dictionary) -> bool: return node != null and r["follow"] == node)
		if not mine.is_empty():
			var outer := float(mine[-2]["width"]) if mine.size() > 1 else 0.0
			(rec["w"] as Array).append(maxf(float(mine[-1]["width"]), outer))
			rec["sd"] = {}
		if P.shot_n > int(rec["n"]):
			rec["n"] = P.shot_n
			rec["sd"] = C._last_shot(m, P)
			(rec["k"] as Array).append(float((rec["sd"]["x"] as Dictionary)["sus_k"]))
	C.ac.step(m, 1.6, fire)
	P.inp["fire"] = false
	var ks: Array = rec["k"]
	var ws: Array = rec["w"]
	var steady := ks.size() >= 12 and absf(float(ks[0]) - 1.0) < 0.001 and absf(float(ks[10]) - 0.5) < 0.001
	for i in range(1, ks.size()):
		steady = steady and float(ks[i]) <= float(ks[i - 1]) + 0.0001
	C.ok("Vex LMB: damage decays over the first 10 rounds to 50% and holds there (the wiki)", steady,
			"%d rounds, first %.2f, 11th %.2f, last %.2f" % [ks.size(), ks[0], ks[10], ks[-1]])
	C.ok("Vex LMB: the tracer thins as the string decays", ws.size() >= 11 and float(ws[-1]) < float(ws[0]) * 0.5
			and float(ws[5]) < float(ws[0]), "%.3f m wide, then %.3f" % [ws[0], ws[-1]])
	C.ac.step(m, 0.6)
	rec["k"] = []
	rec["w"] = []
	rec["sd"] = {}
	rec["n"] = P.shot_n
	P.fire_cd = 0.0
	C.ac.step(m, 0.3, fire)
	P.inp["fire"] = false
	C.ok("Vex LMB: after a pause the string starts over, full damage and a full-size tracer",
			(rec["k"] as Array).size() >= 1 and float(rec["k"][0]) == 1.0
			and absf(float(rec["w"][0]) - float(ws[0])) < 0.001)

## Shift: one charge, and the tap skid and the hold slide ease in and out (a lower peak than the old linear
## bleed-off: 11.2 m/s for the tap, 19.1 for the slide), over a little longer, the same distance, the camera untouched.
func _shift(m: Match, P: Hunter, home: Vector3) -> void:
	_shift_charges(P)
	for kind in ["tap", "held"]:
		C.ac.step(m, 0.5)
		P.teleport(home)
		C.ac.step(m, 0.1)
		P.dashes = P.max_dashes()
		P.inp["move"] = Vector2(1, 0)
		P.inp["aim"] = P.pos + Vector3(8.0, 0.9, 0.0)
		P.inp["dash_down"] = kind == "held"
		var x0 := P.pos.x
		P.do_dash()
		var rec := {"t": 0.0, "peak": 0.0, "first": -1.0, "end": 0.0}
		C.ac.step(m, 1.2, func():
			var v := Vector2(P.vel.x, P.vel.z).length()
			if P.roll_t > 0.0:
				if float(rec["first"]) < 0.0:
					rec["first"] = v
				rec["peak"] = maxf(float(rec["peak"]), v)
				rec["end"] = float(rec["t"])
			rec["t"] = float(rec["t"]) + C.DT)
		P.inp["dash_down"] = false
		P.inp["move"] = Vector2.ZERO
		var peak_max := 10.0 if kind == "tap" else 16.5
		var eased := float(rec["peak"]) <= peak_max and float(rec["first"]) < float(rec["peak"]) * 0.7
		C.ok("Vex Shift %s: eases in and out, lower peak (%.1f m/s), a little longer (%.2fs)"
				% [kind, rec["peak"], rec["end"]], eased and float(rec["end"]) >= 0.6,
				"start %.1f" % float(rec["first"]))
		var want_m := 3.6 if kind == "tap" else 4.2
		var went := P.pos.x - x0
		C.ok("Vex Shift %s: it still covers its distance (%.1f m)" % [kind, went], went >= want_m)

## Item 109: a dash east with the cursor north, LMB held from before it to after it. Every round leaves north, none
## goes missing across the dash, and the body stays on the aim while the legs turn toward the dash.
func _dash_aim(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	for kind in ["tap", "held", "air"]:
		C.ac.step(m, 0.5)
		P.teleport(home)
		C.ac.step(m, 0.1)
		P.ammo = MAG
		P.fire_cd = 0.0
		P.dashes = P.max_dashes()
		P.inp["move"] = Vector2.ZERO
		if kind == "air":
			P.do_jump()
			C.ac.step(m, 0.15, func(): P.inp["aim"] = P.pos + Vector3(0, 0.9, -8.0))
		var rec := {"t": 0.0, "n": P.shot_n, "at": [], "worst": 0.0, "face": 0.0, "legs": 0.0}
		rec.merge({"steps": 0, "dash_rounds": 0})
		var each := func():
			P.inp["aim"] = P.pos + Vector3(0, 0.9, -8.0)
			P.inp["fire"] = true
			P.inp["dash_down"] = kind == "held" and float(rec["t"]) < 0.5
			if P.shot_n > int(rec["n"]):
				rec["n"] = P.shot_n
				(rec["at"] as Array).append(rec["t"])
				var sd: Dictionary = C._last_shot(m, P)
				var off := absf(rad_to_deg((sd["vel"] as Vector2).angle_to(Vector2(0, -1))))
				rec["worst"] = maxf(float(rec["worst"]), off)
				if P.roll_t > 0.0: rec["dash_rounds"] = int(rec["dash_rounds"]) + 1
			if P.roll_t > 0.0 and float(rec["t"]) > 0.15:
				rec["steps"] = int(rec["steps"]) + 1
				rec["face"] = maxf(float(rec["face"]), absf(rad_to_deg(wrapf(P.face, -PI, PI))))
				P.render(C.DT, 1.0)          # (headless steps don't pose her)
				if P.anim != null: rec["legs"] = maxf(float(rec["legs"]), absf(P.anim.legs_yaw))
			rec["t"] = float(rec["t"]) + C.DT
		P.inp["fire"] = true
		P.inp["aim"] = P.pos + Vector3(0, 0.9, -8.0)
		P.inp["move"] = Vector2(1, 0)
		P.inp["dash_down"] = kind == "held"
		P.do_dash()
		C.ac.step(m, 0.9, each)
		P.inp["fire"] = false
		P.inp["move"] = Vector2.ZERO
		P.inp["dash_down"] = false
		var at: Array = rec["at"]
		var gap := 0.0
		for i in range(1, at.size()):
			gap = maxf(gap, float(at[i]) - float(at[i - 1]))
		C.ok("Vex item 109 (%s): dashing east at a north cursor, every round goes north (within 5 degrees)" % kind,
				at.size() >= 6 and int(rec["dash_rounds"]) >= 2 and float(rec["worst"]) <= 5.0,
				"%d rounds, %d in the dash, worst %.1f deg" % [at.size(), rec["dash_rounds"], rec["worst"]])
		C.ok("Vex item 109 (%s): no gap in the rifle's cadence across the dash" % kind,
				gap <= ROUND_GAP + C.DT * 1.5, "longest gap %.3f s" % gap)
		C.ok("Vex item 109 (%s): the body stays on the aim through the dash, the legs follow it" % kind,
				int(rec["steps"]) > 0 and float(rec["face"]) <= 5.0 and float(rec["legs"]) > 0.5,
				"body %.1f deg off, legs turned %.2f rad, %d steps" % [rec["face"], rec["legs"], rec["steps"]])
	P.anim = null                    # (the rest of the check runs unposed, as a headless step does)
	C.ac.step(m, 0.5)

## Run dry with the trigger held: there is no reload (none starts, by hand or by itself), nothing fires while the
## drum refills, the count climbs back (the HUD shows it), and once full the held string picks up again.
func _dry(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	P.fire_cd = 0.0
	var run := {"t": 0.0, "dry_at": -1.0, "back_at": -1.0, "shots_dry": 0, "s": P.shot_n, "low": MAG, "reload": 0.0}
	var clicks0 := int(HeroVfx.of(m).plays.get("reload", 0))
	C.ac.step(m, 6.0, func():
		C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
		P.inp["fire"] = true
		run["reload"] = maxf(float(run["reload"]), P.reload_t)
		if float(run["dry_at"]) < 0.0 and P.ammo <= 0:
			run["dry_at"] = run["t"]
			run["s"] = P.shot_n
		elif float(run["dry_at"]) >= 0.0 and float(run["back_at"]) < 0.0:
			if P.shot_n > int(run["s"]):
				run["back_at"] = run["t"]
				run["low"] = P.ammo
		run["t"] = float(run["t"]) + C.DT)
	P.inp["fire"] = false
	P.start_reload()
	var gap := float(run["back_at"]) - float(run["dry_at"])
	C.ok("Vex parity LMB: run dry, no reload; the trigger is dead until the drum refills (about 1.1s), then fires",
			float(run["dry_at"]) > 0.0 and gap > 0.9 and gap < REFILL_DRY and float(run["reload"]) == 0.0
			and P.reload_t == 0.0 and int(run["low"]) >= MAG - 1 and P.wpn.get("ammo", true),
			"dry at %.2f, firing again %.2f s later with %d rounds; reload %.2f" % [run["dry_at"], gap, run["low"],
					run["reload"]])
	C.ok("Vex parity LMB: the dry drum clicks home once it is full (HeroVfx reload)",
			int(HeroVfx.of(m).plays.get("reload", 0)) > clicks0)
	C.ac.step(m, 1.5)

## The firing brackets: two arcs either side of her while she fires (your screen only), gone soon after.
func _brackets(m: Match, P: Hunter, home: Vector3) -> void:
	P.teleport(home)
	P.ammo = MAG
	C.ac.step(m, 0.4, func():
		C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
		P.inp["fire"] = true)
	var e := AimKit.entry(P, "lmb_bracket1")
	var on := AimKit.shown(P, "lmb_bracket1") and AimKit.shown(P, "lmb_bracket-1") and not bool(e.get("all", true))
	P.inp["fire"] = false
	C.ac.step(m, 0.4)
	C.ok("Vex parity LMB: firing brackets either side of her while she fires (yours only), gone after",
			on and absf(float(e.get("radius", 0.0)) - GunslingerKit.BRACKET_R) < 0.01
			and not AimKit.shown(P, "lmb_bracket1"))

## The rifle's pose: each round kicks the gun (stock back, muzzle up) by 0.025s and is back on the shouldered
## pose by 0.09, before the next round; the legs are a stance (walking, they keep walking).
func _rifle_pose() -> void:
	var mv: Dictionary = KMovesVV.MOVES["gunslinger_lmb"]
	var a := HunterAnim.km_sample("gunslinger_lmb", 0.0)
	var b := HunterAnim.km_sample("gunslinger_lmb", 0.09)
	var kick := HunterAnim.km_sample("gunslinger_lmb", 0.025)
	var same := is_equal_approx(a["p"], b["p"]) and is_equal_approx(a["gp"], b["gp"]) \
			and (a["wo"] as Vector3).is_equal_approx(b["wo"])
	C.ok("Vex parity LMB: each round kicks the gun by 0.025s, back on the shoulder by 0.09 (rounds 0.12 apart)",
			same and float(kick["gp"]) > 0.15 and absf(float(kick["p"]) - float(a["p"])) < 0.15
			and bool(mv.get("stance", false)),
			"gp %.2f, torso %.2f -> %.2f" % [kick["gp"], a["p"], kick["p"]])

## Item 112: the Burr Charge is a tap fired from the cannon's launcher: no throw in the move, a kick on the gun, out
## within a step of the press, once however long the key stays down, and she keeps walking.
func _launcher(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	var kick := HunterAnim.km_sample("gunslinger_rmb", 0.04)
	var stance := bool(KMovesVV.MOVES["gunslinger_rmb"].get("stance", false))
	var no_hand := (KMovesVV.MOVES["gunslinger_rmb"]["keys"] as Array).all(func(key: Array) -> bool:
		return float((key[1] as Dictionary).get("hw", 0.0)) == 0.0 and not (key[1] as Dictionary).has("fl"))
	C.ok("Vex item 112: no throw pose, the left hand stays out of it, a recoil kick on the cannon",
			no_hand and stance and float(kick["gp"]) > 0.3 and not GunslingerKit.TRAILS.has("gunslinger_rmb"),
			"gp %.2f" % kick["gp"])
	T.teleport(home + Vector3(30, 0, 8))
	P.teleport(home)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	C.ac.aim_at(P, home + Vector3(6.0, 0, 0))
	var plain := _walk_speed(m, P)
	var p0 := P.pos
	var puffs0 := K.puffs
	var burrs0 := K.burrs.size()
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	m.step(C.DT)
	# (the charge goes at once; on her model the puff waits for the bell, TUBE_SWING)
	var out_now := K.burrs.size() == burrs0 + 1 and float(K.cd["rmb"]) > 0.0
	var b: Dictionary = K.burrs[-1] if not K.burrs.is_empty() else {}
	var gun := P.model.get_node_or_null("Rig/Torso/Aim/Gun/Muzzle") as Node3D
	var from_gun := not b.is_empty() and gun != null and (b["pos"] as Vector3).y >= gun.global_position.y
	var was_at: Vector3 = b.get("y0", 0.0) * Vector3.UP
	C.ac.step(m, 1.0, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	var walked: float = P.flat_dist(p0) / (1.0 + C.DT)
	P.inp["move"] = Vector2.ZERO
	# (her model has the launcher's own firing point, which the empties check below covers)
	from_gun = from_gun or WardenGlb.anchor(P.model, GunslingerKit.TUBE_FIRE) != null
	C.ok("Vex item 112: a tap fires within one step, from above the gun's muzzle on a model with no launcher",
			out_now and from_gun, "y %.2f" % was_at.y)
	C.ok("Vex item 112: a 1s hold fires once, at the press", K.puffs == puffs0 + 1 and not K.rmb_down,
			"%d puffs" % (K.puffs - puffs0))
	C.ac.step(m, 1.2)
	_launcher_empties(m, P, K, home)
	C.ok("Vex item 112: she keeps walking through the shot (85% of her walk or more)",
			walked >= plain * WALK_KEEP, "%.2f of %.2f m/s" % [walked, plain])
	C.ac.step(m, 1.5)

## On the new model: the charge leaves from launcher_fire at the press, read live, and the flash waits for the bell
## (launcher_muzzle), which starts the shot behind her shoulder. Her real empties, held at known spots for the shot,
## or stand-ins on a stand-in Warden node on a model that has none.
func _launcher_empties(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	var w := P.model.get_node_or_null("Warden") as Node3D
	var made := w == null
	if made:
		w = Node3D.new()
		w.name = "Warden"
		P.model.add_child(w)
	var spot := WardenGlb.anchor(P.model, GunslingerKit.TUBE_FIRE)
	var bell := WardenGlb.anchor(P.model, GunslingerKit.TUBE_BELL)
	var stand_in := spot == null or bell == null
	if stand_in:
		spot = Node3D.new()
		spot.name = GunslingerKit.TUBE_FIRE
		bell = Node3D.new()
		bell.name = GunslingerKit.TUBE_BELL
		w.add_child(spot)
		w.add_child(bell)
	var spot0 := spot.transform
	var bell0 := bell.transform
	P.teleport(home)
	C.ac.step(m, 0.1)
	spot.global_position = P.pos + Vector3(0.7, 1.4, 0.2)
	bell.global_position = P.pos + Vector3(-0.5, 1.7, 0.0)
	var fire_at := spot.global_position
	var bell_at := bell.global_position
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	var puffs0 := K.puffs
	K.press_rmb()
	var b: Dictionary = K.burrs[-1] if not K.burrs.is_empty() else {}
	var from_spot := not b.is_empty() and (b["pos"] as Vector3).distance_to(fire_at) < 0.01
	var waits := K.puffs == puffs0
	C.ac.step(m, 0.05)
	waits = waits and K.puffs == puffs0
	bell.global_position = bell_at
	C.ac.step(m, 0.1)
	C.ok("Vex item 112: the charge leaves launcher_fire at the press, the flash launcher_muzzle after 0.1s",
			from_spot and waits and K.puffs == puffs0 + 1 and K.last_puff.distance_to(bell_at) < 0.01,
			"from spot %s, waited %s, %d puff" % [from_spot, waits, K.puffs - puffs0])
	spot.transform = spot0
	bell.transform = bell0
	if stand_in:
		w.remove_child(spot)
		w.remove_child(bell)
		spot.free()
		bell.free()
	if made:
		P.model.remove_child(w)
		w.free()
	C.ac.step(m, 1.2)

## Item 68: the Longneedle hits a line at least 1.5x as wide, the view pushes out at least 15% through the cast, along
## the aim, with no shake, and is back within 0.3 s of the shot; the beam goes exactly where the line last pointed.
func _needle(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	var cam: CamRig = m.cam
	C.ac.fresh(T)
	var off := float(K.e_def()["width"]) + T.r * 0.5       # past the old edge, inside the new one
	T.teleport(home + Vector3(9.0, 0, off))
	P.teleport(home)
	C.ac.step(m, 0.3)
	var east := home + Vector3(10.0, 0, 0)
	C.ac.aim_at(P, east)
	cam.cast_k = 0.0
	var hits0 := K.needle_hits
	K.cd["e"] = 0.0
	K.use_e()
	var rec := {"wide": 1.0, "aim": Vector2.ZERO, "dir": Vector2.ZERO, "face": 0.0, "t": 0.0, "shake": 0.0, "pan": 0.0}
	var charging := func():
		C.ac.aim_at(P, east + Vector3(0, 0, float(rec["t"]) * 2.0))      # the cursor drifts: the line follows it
		cam.follow(P.pos, C.DT, false)
		rec["wide"] = maxf(float(rec["wide"]), cam.cast_wide())
		rec["shake"] = float(rec["shake"]) + cam.shake_left
		if not K.needle.is_empty():
			rec["aim"] = P.aim_dir()
			rec["dir"] = AimKit.entry(P, "e").get("dir", Vector2.ZERO)
			rec["face"] = absf(rad_to_deg(Vector2(-sin(P.face), -cos(P.face)).angle_to(P.aim_dir())))
			rec["pan"] = maxf(float(rec["pan"]), (cam.focus - cam.base).dot(Vector3(1, 0, 0)))
		rec["t"] = float(rec["t"]) + C.DT
	while not K.needle.is_empty() and float(rec["t"]) < 1.0:
		charging.call()
		m.step(C.DT)
	var at_shot := cam.cast_wide()
	for i in int(0.3 / C.DT):
		cam.follow(P.pos, C.DT, false)
		m.step(C.DT)
	var wide_ok := float(K.e_def()["width"]) >= OLD_NEEDLE_W * 1.5
	C.ok("Vex item 68: the beam hits a line at least 1.5x as wide, and drawn that wide",
			wide_ok and K.needle_hits > hits0 and absf(K.beam_width() - float(K.e_def()["width"]) * 2.0) < 0.001,
			"%.2f m either side, a foe %.2f m off the line: %d hit" % [K.e_def()["width"], off, K.needle_hits - hits0])
	C.ok("Vex item 68: the view is at least 15% wider through the cast and leans along the aim, no shake",
			float(rec["wide"]) >= 1.15 and at_shot >= 1.15 and float(rec["pan"]) > 2.0 and float(rec["shake"]) == 0.0,
			"x%.2f, x%.2f at the shot, leaning %.1f m" % [rec["wide"], at_shot, rec["pan"]])
	C.ok("Vex item 68: the view is back within 0.3s of the shot", cam.cast_wide() < 1.005, "x%.3f" % cam.cast_wide())
	var d_dir := rad_to_deg(absf((K.needle_dir).angle_to(rec["dir"])))
	var d_aim := rad_to_deg(absf((K.needle_dir).angle_to(rec["aim"])))
	C.ok("Vex item 68: the beam fires along the line and the aim at release (1 degree); she faces it throughout",
			d_dir <= 1.0 and d_aim <= 1.0 and float(rec["face"]) <= 5.0,
			"line %.2f, aim %.2f, face %.1f deg" % [d_dir, d_aim, rec["face"]])
	var was := P.ctrl
	P.ctrl = "idle"
	cam.cast_left = 0.0
	K.cd["e"] = 0.0
	K.use_e()
	C.ac.step(m, 0.1)
	var quiet := cam.cast_left <= 0.0 and not K.needle.is_empty()
	K._end_needle()
	P.ctrl = was
	C.ok("Vex item 68: anyone else's cast leaves the camera alone", quiet)
	C.ac.step(m, 0.3)

## Her plain walk (move held down the screen, not firing), in m/s; she is still walking when it returns.
func _walk_speed(m: Match, P: Hunter) -> float:
	P.inp["move"] = Vector2(0, 1)
	C.ac.step(m, 0.3)
	var p0 := P.pos
	C.ac.step(m, 0.6)
	return P.flat_dist(p0) / 0.6

## The audit (Nov 3): no cosmetic ground rings, discs or columns on her slide, its rank-3 end, a knock or the
## Longneedle's recoil (a ground shape means gameplay); Dazed is only a damage window (no slow, the data); her
## air roll fires the rifle as its dash row says.
func _audit(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	var fx := VVFx.of(m)
	var seen := {"ring": 0, "disc": 0, "pillar": 0}
	var before := fx.live.map(func(e: Dictionary) -> Node3D: return e["node"])
	var counted := {}
	var watch := func():
		for e in fx.live:
			var kind := String(e["kind"])
			if seen.has(kind) and not e["node"] in before and not counted.has(e["node"]):
				counted[e["node"]] = true
				seen[kind] = int(seen[kind]) + 1
	P.teleport(home)
	P.slot_lv["dash"] = 3
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	C.ac.step(m, 1.0, watch)
	var slid := K.last_dash_kind
	P.inp["move"] = Vector2.ZERO
	P.slot_lv["dash"] = 1
	K.knocked.clear()
	P.dashes = 0.0
	T.hp = 0.0
	T.downed = true
	K.on_deal(T, 5.0, {"src": "abil", "ab": "k1"})
	var knocked := P.dashes >= 1.0
	C.ac.step(m, 0.5, watch)
	T.downed = false
	T.hp = T.max_hp
	C.ok("Vex audit: no ground ring, disc or column on a slide, its rank-3 end or a knock",
			slid != "" and knocked and int(seen["ring"]) + int(seen["disc"]) + int(seen["pillar"]) == 0,
			"%s, knock %s, %s" % [slid, knocked, str(seen)])
	C.ac.fresh(T)
	KitStatus.apply(T, "rat", 1.4)
	C.ok("Vex audit: Dazed is a damage window only, no slow (the data)",
			KitStatus.rattled(T) and T.slow_t <= 0.0, "slow %.2f for %.2f s" % [T.slow_k, T.slow_t])
	KitStatus.clear_rattled(T)
	P.teleport(home)
	P.do_jump()
	C.ac.step(m, 0.15)
	P.dashes = 0.0
	P.ex_cd = 0.0
	K.on_dash(true)
	var rolled := K.last_dash_kind == "air" and P.roll_t > 0.0
	C.ok("Vex audit: the rifle fires through her air roll (its dash row: fire)", rolled and K.fires_in_dash(),
			"kind %s roll %.2f" % [K.last_dash_kind, P.roll_t])
	C.ac.step(m, 1.0)
	_into_dash(m, P, K, T, home)

## Shift during her moves (the into_dash rows, all "fire": owner item 51, every move combos with Shift): pressed in
## the Longneedle's charge she slides and the beam still fires; pressed right after a Burr Charge she slides at once.
func _into_dash(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	C.ac.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(6.0, 0, 0))
	C.ac.step(m, 0.2)
	T.inv_t = 0.0
	C.ac.aim_at(P, T.pos)
	K.cd["e"] = 0.0
	var hits0 := K.needle_hits
	K.use_e()
	C.ac.step(m, 0.2)
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	var p0 := P.pos
	C.ac.step(m, 0.9)
	P.inp["move"] = Vector2.ZERO
	var e_ok := K.needle_hits > hits0 and P.flat_dist(p0) > 1.0
	C.ac.fresh(T)
	C.ac.step(m, 0.5)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	var n0 := K.burrs.size()
	K.press_rmb()
	var thrown := K.burrs.size() > n0
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, -1)
	P.do_dash()
	var slid := P.roll_t > 0.0
	C.ac.step(m, 0.3)
	P.inp["move"] = Vector2.ZERO
	C.ac.step(m, 0.1)
	var rmb_ok := thrown and slid
	var rows := ["lmb", "rmb", "e", "x", "q"].all(func(sl: String) -> bool:
		var r := DashFlow.into_dash_of("gunslinger", sl)
		return String(r.get("mode", "")) == "fire" and String(r.get("source", "")) != "")
	C.ok("Vex audit: Shift in the Longneedle charge slides and the beam fires; after a Burr Charge she slides at once",
			e_ok and rmb_ok and rows, "E %s RMB %s rows %s" % [e_ok, rmb_ok, rows])
	C.ac.step(m, 1.5)
