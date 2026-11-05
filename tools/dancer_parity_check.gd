extends RefCounted
## Sable's LMB against the source (the parity pass), run inside --dancer-combo-check (tools/dancer_jug_check.gd):
## the throw's beats against the footage (2-3 frames a shot, one arm whipped out, the torso turned ~30 degrees),
## the held cadence and the alternating hands, how the aim tracks the cursor (each bolt at the cursor as it leaves,
## the body turning at the source's rate), and that she keeps running while she throws. Source numbers:
## docs/heroes/thief.md, "Parity pass".

const RATE := 0.45           # s between bolts held (the card's 0.45s; footage: a hit every 2-3 frames)
const REACH_BY := 0.06       # s: the blade is out this soon after the bolt leaves (under 2 frames at 30 fps) ...
const REACH_SHARE := 0.85    # ... this share of the way along its arc
const TWIN_SWING_S := 0.3    # s: a twin-hold swing (HunterAnim's base swing time for the hold)
const TWIST := [0.4, 0.65]   # rad: the torso turned into the throw (footage: about 30 degrees)
const TURN_180 := 0.2        # s: the body turns 180 degrees to a new cursor (source 1280 deg/s: 0.14s)
const RUN_KEEP := 0.85       # share of her run kept while she throws
var A

func run(a, m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	A = a
	_beats()
	_cadence(m, P, K, T, home)
	_tracking(m, P, K, home)
	_running(m, P, K, home)
	_audit(m, P, K, T, home)
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	A.step(m, 0.6)

## The throw: the blade (with the hand on it) whipped from cocked to straight at the aim within a few hundredths of a
## second of the bolt, the right, the left, both for the empowered one; the torso turned ~30 degrees into it and
## wound toward the other hand by the next bolt (where the next throw starts); the legs a stance only.
func _beats() -> void:
	var reach_t := 1.0
	for i in 101:
		if HunterAnim.swing_ease(i / 100.0) >= REACH_SHARE:
			reach_t = minf(reach_t, i / 100.0 * TWIN_SWING_S)
	var throws := ["thf_lmb_r", "thf_lmb_l", "thf_primed"]
	var arcs: Array = HunterAnim.SWINGS["arc_bolts"]
	var whips := true
	for i in arcs.size():
		var cocked: Vector3 = arcs[i]["a"]
		var torso: float = HunterAnim.km_sample(throws[i], 0.06)["y"]
		whips = whips and absf(cocked.x) > 0.8 and cocked.y > 0.3 and absf((arcs[i]["b"] as Vector3).x + torso) < 0.2
	var steps := [0, 1, 2] == throws.map(func(mv: String) -> int: return int(KMovesDJ.MOVES[mv].get("swing", -1)))
	var on_blades := throws.all(func(mv: String) -> bool:
		return (KMovesDJ.MOVES[mv]["keys"] as Array).all(func(k: Array) -> bool:
			return not (k[1] as Dictionary).has("fr") and not (k[1] as Dictionary).has("fl")))
	var at_reach := HunterAnim.km_sample("thf_lmb_r", 0.04)
	A.ok("dancer parity LMB: the blade whips from cocked to the aim by 0.06s, right, left, both when empowered",
			reach_t <= REACH_BY and whips and steps and on_blades,
			"reach at %.3f s, arcs %s steps %s hands on the blades %s" % [reach_t, whips, steps, on_blades])
	A.ok("dancer parity LMB: the torso turned ~30 degrees into the throw",
			absf(float(at_reach["y"])) >= TWIST[0] and absf(float(at_reach["y"])) <= TWIST[1],
			"%.2f rad" % at_reach["y"])
	var wound: float = HunterAnim.km_sample("thf_lmb_r", RATE)["y"]
	var flows := is_equal_approx(wound, HunterAnim.km_sample("thf_lmb_l", 0.0)["y"])
	A.ok("dancer parity LMB: by the next bolt the torso is wound toward the other hand, where the next throw starts",
			flows)
	var stance := ["thf_lmb_r", "thf_lmb_l", "thf_bola"].all(
			func(mv: String) -> bool: return bool(KMovesDJ.MOVES[mv].get("stance", false)))
	A.ok("dancer parity: the throws' and the Bola wind-up's legs are a stance, dropped at a run (legs keep running)",
			stance and HunterAnim.stance_leg_k(true, 1.0) == 0.0 and HunterAnim.stance_leg_k(true, 0.0) == 1.0)

## Held on a foe: a bolt every 0.45s, hands alternating, each one starting its own throw.
func _cadence(m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	A.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(6.0, 0, 0))
	P.fire_cd = 0.0
	K.primed_t = 0.0
	var rec := {"t": 0.0, "n": K.bolts, "at": [], "moves": []}
	A.step(m, 2.0, func():
		A.aim_at(P, T.pos)
		P.inp["fire"] = true
		if K.bolts > int(rec["n"]):
			rec["n"] = K.bolts
			(rec["at"] as Array).append(rec["t"])
			(rec["moves"] as Array).append(K.anim_id)
		rec["t"] = float(rec["t"]) + A.DT)
	P.inp["fire"] = false
	var at: Array = rec["at"]
	var moves: Array = rec["moves"]
	var even := at.size() >= 4
	for i in range(1, at.size()):
		even = even and absf(float(at[i]) - float(at[i - 1]) - RATE) <= A.DT * 1.5
	var alternate := moves.size() >= 4
	for i in range(1, moves.size()):
		alternate = alternate and moves[i] != moves[i - 1] and String(moves[i]).begins_with("thf_lmb_")
	A.ok("dancer parity LMB: held, a bolt every 0.45s from alternating hands, each with its own throw",
			even and alternate, "at %s moves %s" % [str(at), str(moves)])
	A.fresh(T)

## The cursor swung behind her mid-string: the next bolt goes at the new cursor, and the body comes round at
## the source's turn rate.
func _tracking(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	P.inp["fire"] = false
	A.step(m, 0.5)
	P.teleport(home)
	A.aim_at(P, home + Vector3(5.0, 0, 0))
	A.step(m, 0.3)
	A.aim_at(P, home + Vector3(-5.0, 0, 0.5))
	P.fire_cd = 0.0
	var b0 := K.bolts
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	var sd: Dictionary = m.shots[-1] if K.bolts > b0 else {}
	var from: Vector3 = sd.get("start", home)
	var want := Vector2(home.x - 5.0 - from.x, home.z + 0.5 - from.z).normalized()
	var off := rad_to_deg(absf((sd.get("vel", Vector2.ZERO) as Vector2).angle_to(want)))
	var turn := {"t": A.DT, "done": -1.0}
	var face_want := atan2(5.0, -0.5)
	A.step(m, 0.4, func():
		if float(turn["done"]) < 0.0 and absf(wrapf(P.face - face_want, -PI, PI)) < deg_to_rad(10.0):
			turn["done"] = turn["t"]
		turn["t"] = float(turn["t"]) + A.DT)
	A.ok("dancer parity LMB: a bolt goes at the cursor as it leaves, even swung behind her",
			K.bolts == b0 + 1 and off < 3.0, "%.1f degrees off" % off)
	A.ok("dancer parity LMB: the body turns 180 degrees to the cursor inside 0.2s (source 1280 deg/s)",
			float(turn["done"]) > 0.0 and float(turn["done"]) <= TURN_180, "%.2f s" % turn["done"])

## Running while she throws (aiming across her path): she keeps 85% of her run or more.
func _running(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	P.teleport(home)
	P.inp["move"] = Vector2(0, 1)
	A.step(m, 0.4)
	var p0 := P.pos
	A.step(m, 1.0, func(): A.aim_at(P, P.pos + Vector3(5.0, 0, 0)))
	var run_v := P.flat_dist(p0)
	p0 = P.pos
	var b0 := K.bolts
	A.step(m, 1.0, func():
		A.aim_at(P, P.pos + Vector3(5.0, 0, 0))
		P.inp["fire"] = true)
	P.inp["fire"] = false
	var fire_v := P.flat_dist(p0)
	A.step(m, 0.4)
	P.inp["move"] = Vector2.ZERO
	A.ok("dancer parity LMB: running, she throws and keeps running (85% of her run or more)",
			K.bolts >= b0 + 2 and fire_v >= run_v * RUN_KEEP, "%.2f m/s firing vs %.2f" % [fire_v, run_v])

## The audit (Nov 3): the plain bolt carries her (13, the owner's call); a bolt thrown mid-flip whips both
## blades out without cutting the cartwheel short; the blink leaves no ground ring.
func _audit(m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	A.ok("Sable audit: the plain bolt deals 13 (the owner: plain autos carry her), the empowered one 2.34x it",
			is_equal_approx(float(P.wpn["dmg"]), 13.0) and absf(K.empowered_k() - 2.34) < 0.01)
	A.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(6.0, 0, 0))
	A.step(m, 0.5)
	P.dashes = P.max_dashes()
	P.fire_cd = 0.0
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	A.step(m, 0.08)
	var b0 := K.bolts
	A.aim_at(P, T.pos)
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	var flip := K.anim_id
	P.inp["move"] = Vector2.ZERO
	var swing := int(KMovesDJ.MOVES.get(flip, {}).get("swing", -1))
	A.ok("Sable audit: a bolt mid-flip goes empowered, the cartwheel plays on and whips both blades out (swing 2)",
			K.bolts == b0 + 1 and K.last_bolt_emp and flip in ThiefKit.CARTWHEELS and swing == 2,
			"bolts +%d emp %s move %s swing %d" % [K.bolts - b0, K.last_bolt_emp, flip, swing])
	A.step(m, 0.8)
	P.teleport(home)
	T.teleport(home + Vector3(30.0, 0, 0))
	A.aim_at(P, home + Vector3(5.0, 0, 0))
	K.cd["e"] = 0.0
	K.use_e()
	A.step(m, 0.6)
	var radial0: int = m.fx.radial
	var blinks0 := K.blinks
	K.use_e()
	A.step(m, 0.1)
	A.ok("Sable audit: the blink leaves no ground ring (the afterimage chain and the puff stay)",
			K.blinks == blinks0 + 1 and m.fx.radial == radial0, "blinks +%d rings +%d" % [K.blinks - blinks0,
					m.fx.radial - radial0])
	A.fresh(T)
	A.step(m, 1.6)
