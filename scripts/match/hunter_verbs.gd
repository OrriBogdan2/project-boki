class_name HunterVerbs
extends RefCounted
## The garden verbs on the player's body: a pat on the head (petting), a snack held out to the mouth
## (feeding), a bend-and-lift (picking a Boki up), an underarm toss (a ball) and an arms-up cheer (races
## and drills). Procedural keys for
## HunterAnim's "act" slot: each is a function of t, the seconds since the move began. Hands are metres
## from the shoulder (left shoulder is -x, forward is -z). HomeVerbs times them; HunterAnim asks for the
## squat, legs, pitch and hands. Pat, feed and lift reach for the Boki itself (aim(): its head, its mouth,
## its flanks),
## so the body squats as deep as that Boki is small: the Empty's planted feet (EmptyGait) carry the
## squat, other bodies bend their legs to it (legs()).

const ACTS := ["feed", "pat", "lift", "toss", "cheer"]
# s each move plays at home (a Hero's pet, give and cheer clips run as long)
const LENGTH := {"feed": 1.0, "pat": 1.3, "lift": 0.8, "toss": 0.8, "cheer": 0.8}
# s into the lift: the hands close on the Boki, start up with it, and hold it at the chest (the match
# pickup's reach, lift, settle beat: 0.28, 0.55, 0.8)
const LIFT_GRIP := 0.28
const LIFT_UP := 0.34
const LIFT_HELD := 0.6
const TOSS_RELEASE := 0.5            # s into the toss when the ball leaves the hand
const STAND := Vector4(0.12, -0.22, 0.12, -0.22)      # legs at rest
const HANG := Vector3(0.0, -0.42, -0.04)      # a relaxed free hand, from its shoulder
# m (legs' rest size): the deepest the hips go (deeper, a folded leg can't keep a splayed foot)
const SQUAT_MAX := 0.17
const SQUAT_DEFAULT := {"feed": 0.16, "pat": 0.12, "lift": 0.17}     # m: with no Boki to aim at
const GRIP_W := 0.13         # m: each hand this far to the side of the lift's grip point
const GRIP_H := 0.4          # of the Boki's height: where the hands close on its flanks
const CARRY_L := Vector3(0.12, -0.36, -0.34)      # the left hand holding a Boki at the chest (HunterAnim "carry")
const LEG := 0.445           # m: thigh + shin, for legs() on a body without planted feet
const REACH_K := 0.7         # of the arm's reach: how far down the hand goes before the knees bend for it
const LEAN_OVER := 0.45      # rad: the most the back bends further for a Boki the squat cannot get down to
const OVER := 1.6            # ease-out-back overshoot: the reach lands a little past, then settles

## The world point a hand goes to: the top of its head (pat), its mouth (feed) or the middle of the
## two-handed grip on its flanks (lift: each hand GRIP_W to a side of it, on the round of its body), on
## the near side of the Boki's bounds `box` as seen from `from`; a head above `top` (world y, what the hand
## can reach) is patted on the front instead. INF for moves with no Boki to touch.
static func aim(act: String, box: AABB, from: Vector3, top := INF) -> Vector3:
	if box.size == Vector3.ZERO or not (act in SQUAT_DEFAULT):
		return Vector3.INF
	var c := box.get_center()
	var to := Vector3(from.x - c.x, 0.0, from.z - c.z).normalized()
	var r := clampf(minf(box.size.x, box.size.z) * 0.5, 0.15, 0.45)
	if act == "pat" and box.end.y > top:
		return Vector3(c.x, top, c.z) + to * (r + 0.03)
	if act == "pat":
		return Vector3(c.x, box.end.y + 0.03, c.z) + to * r * 0.5
	if act == "lift":
		return Vector3(c.x, box.position.y + box.size.y * GRIP_H, c.z) + to * sqrt(maxf(r * r - GRIP_W * GRIP_W, 0.0))
	return Vector3(c.x, box.position.y + box.size.y * 0.45, c.z) + to * r * 0.85

## How deep the hips squat (m, legs' rest size) at t: `need` is the depth the Boki asks for (the hand
## reaching its head or mouth), or below 0 for the move's own.
static func squat(act: String, t: float, need: float) -> float:
	var deep := clampf(need if need >= 0.0 else float(SQUAT_DEFAULT.get(act, 0.0)), 0.0, SQUAT_MAX)
	match act:
		"pat":
			# down as the hand arcs over, a give in the knees each stroke, up a beat after the hand lifts
			var stroke := 0.012 * sin((t - 0.4) * TAU * 2.0) * _window(t, 0.4, 1.0, 0.1)
			return deep * _back(t, 0.08, 0.42) * (1.0 - smoothstep(1.02, 1.3, t)) + stroke
		"feed":
			# a little rise to start, down with the snack, held, then up as the hands come back
			return -0.015 * _window(t, 0.0, 0.14, 0.07) + deep * _back(t, 0.08, 0.45) * (1.0 - smoothstep(0.7, 1.0, t))
		"lift":
			# down to the grip, a beat to take the weight, then up through the legs before the arms
			return deep * _back(t, 0.04, LIFT_GRIP) * (1.0 - smoothstep(LIFT_UP, LIFT_HELD - 0.08, t))
		"toss":
			return 0.05 * smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(TOSS_RELEASE, LENGTH["toss"], t))
		"cheer":
			# a dip to load the jump, sprung up, a give in the knees on each pump, settled
			var pump := 0.02 * absf(sin((t - 0.3) * TAU * 1.5)) * _window(t, 0.3, 0.65, 0.05)
			return 0.06 * _window(t, 0.0, 0.2, 0.1) + pump
	return 0.0

## Leg angles for a body without planted feet: Vector4(hip_l, knee_l, hip_r, knee_r), the knees bent so
## the hips come down by squat() with the feet under them.
static func legs(act: String, t: float, need := -1.0) -> Vector4:
	if act == "toss":
		var d := smoothstep(0.0, 0.35, t) * (1.0 - 0.5 * smoothstep(TOSS_RELEASE, LENGTH["toss"], t))
		return STAND.lerp(Vector4(0.55, -0.6, -0.3, -0.35), d)
	var a := acos(clampf(1.0 - maxf(squat(act, t, need), 0.0) / LEG, 0.0, 1.0))
	return STAND + Vector4(a, -2.0 * a, a, -2.0 * a)

## How far forward the body leans (negative leans back); a Boki lower than the squat can go (`need`, as
## squat()) bends the back further over it.
static func pitch(act: String, t: float, need := -1.0) -> float:
	var over := LEAN_OVER * clampf((need - SQUAT_MAX) / 0.15, 0.0, 1.0)
	match act:
		"feed": return (0.3 + over) * _back(t, 0.08, 0.45) * (1.0 - smoothstep(0.7, 1.0, t))
		"pat": return (0.38 + over) * _back(t, 0.05, 0.4) * (1.0 - smoothstep(1.0, 1.28, t))
		"lift":
			# folded over the grip, straightened as it comes up, a little lean back under its weight
			var fold := (0.4 + over) * _back(t, 0.04, LIFT_GRIP) * (1.0 - smoothstep(LIFT_UP, LIFT_HELD, t))
			return fold - 0.08 * _window(t, LIFT_HELD - 0.1, LENGTH["lift"], 0.12)
		"toss": return -0.12 * smoothstep(0.0, 0.3, t) + 0.35 * smoothstep(0.3, TOSS_RELEASE, t)
		"cheer": return 0.12 * _window(t, 0.0, 0.2, 0.1) - 0.2 * _back(t, 0.1, 0.3) * (1.0 - smoothstep(0.62, 0.8, t))
	return 0.0

## Where the hands go: [left hand, right hand, how much the right hand lets go of the weapon]. `at` is
## aim() in the torso's space (INF: the move's own spot), `reach` the arm's length.
static func hands(act: String, t: float, sh_l: Vector3, sh_r: Vector3, at := Vector3.INF, reach := 0.44) -> Array:
	match act:
		"feed":
			return _feed_hands(t, sh_l, sh_r, at, reach)
		"pat":
			return _pat_hands(t, sh_l, sh_r, at, reach)
		"lift":
			return _lift_hands(t, sh_l, sh_r, at, reach)
		"toss":
			return _toss_hands(t, sh_l, sh_r)
		"cheer":
			return _cheer_hands(t, sh_l, sh_r)
	return [sh_l, sh_r, 0.0]

## The right hand lifts, arcs over and lands on the head, strokes it front to back twice (pressing a
## little at the middle of each), lifts off and drops; the left braces forward over the knee.
static func _pat_hands(t: float, sh_l: Vector3, sh_r: Vector3, at: Vector3, reach: float) -> Array:
	var head := _within(sh_r, at if at != Vector3.INF else sh_r + Vector3(-0.1, -0.3, -0.4), reach)
	var lift := sh_r + Vector3(0.02, -0.12, -0.2)       # up and over before it comes down on the head
	var p := HANG.lerp(lift - sh_r, smoothstep(0.0, 0.2, t)) + sh_r
	if t >= 0.2:
		p = lift.lerp(head + Vector3(0.0, 0.05, 0.03), smoothstep(0.2, 0.34, t))
		p = p.lerp(head, smoothstep(0.3, 0.42, t))
	var s := _window(t, 0.42, 1.0, 0.06)
	var ph := (t - 0.42) * TAU * 2.0
	p += Vector3(0.0, -0.015 * sin(ph) * sin(ph) - 0.01, 0.05 * cos(ph)) * s
	if t > 1.0:
		p = p.lerp(head + Vector3(0.0, 0.08, 0.04), smoothstep(1.0, 1.1, t))
		p = p.lerp(sh_r + HANG, smoothstep(1.08, 1.3, t))
	var brace := smoothstep(0.08, 0.4, t) * (1.0 - smoothstep(1.0, 1.3, t))
	return [sh_l + HANG.lerp(Vector3(0.08, -0.38, -0.2), brace), p, 1.0]

## Both hands gather at the belly (the snack between them), go out to the mouth and a touch past, hold
## it there and nudge it in once, then open and come back.
static func _feed_hands(t: float, sh_l: Vector3, sh_r: Vector3, at: Vector3, reach: float) -> Array:
	var mid := (sh_l + sh_r) * 0.5
	var mouth := at if at != Vector3.INF else mid + Vector3(0.0, -0.32, -0.46)
	mouth = _within(mid, mouth, reach)
	var gather := mid + Vector3(0.0, -0.32, -0.16)
	var out := _back(t, 0.12, 0.45)
	var p := gather.lerp(mouth, out) + (mouth - mid).normalized() * 0.03 * _window(t, 0.5, 0.62, 0.06)
	var c := smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.72, 1.0, t))
	var open := 0.07 * smoothstep(0.66, 0.8, t)
	var hl := (sh_l + HANG).lerp(p + Vector3(-0.06 - open, 0.0, 0.0), c)
	var hr := (sh_r + HANG).lerp(p + Vector3(0.06 + open, 0.0, 0.0), c)
	return [hl, hr, 1.0]

## Both hands go down to the Boki's flanks and close on them, hold a beat as the weight is taken, bring
## it up to the chest and settle there in the carry hold (HunterAnim "carry", which takes over).
static func _lift_hands(t: float, sh_l: Vector3, sh_r: Vector3, at: Vector3, reach: float) -> Array:
	var mid := (sh_l + sh_r) * 0.5
	var grip := at if at != Vector3.INF else mid + Vector3(0.0, -0.75, -0.4)
	var held := [sh_l + CARRY_L, sh_r + CARRY_L * Vector3(-1.0, 1.0, 1.0)]
	var down := _back(t, 0.04, LIFT_GRIP)
	var up := smoothstep(LIFT_UP, LIFT_HELD, t)
	var give := Vector3(0.0, -0.025, 0.0) * _window(t, LIFT_HELD - 0.04, LENGTH["lift"], 0.08)
	var out := []
	for i in 2:
		var sh: Vector3 = [sh_l, sh_r][i]
		var on := _within(sh, grip + Vector3(GRIP_W * (2 * i - 1), 0.0, 0.0), reach)
		out.append((sh + HANG).lerp(on, down).lerp(held[i], up) + give)
	return [out[0], out[1], 1.0]

## How far a lifted Boki has come up from the ground to the carry hold at t: 0 until the hands have it.
static func lifted(t: float) -> float:
	return smoothstep(LIFT_UP, LIFT_HELD, t)

## Arms swing down and back with the dip, thrust up past straight and settle, two pumps (one fist then
## the other), then come down.
static func _cheer_hands(t: float, sh_l: Vector3, sh_r: Vector3) -> Array:
	var dip := _window(t, 0.0, 0.2, 0.1)
	var up := _back(t, 0.12, 0.3) * (1.0 - smoothstep(0.62, 0.8, t))
	var pump := sin((t - 0.3) * TAU * 1.5) * 0.08 * _window(t, 0.3, 0.65, 0.05)
	var low := Vector3(0.0, -0.36, 0.14)
	var hl := sh_l + HANG.lerp(low * Vector3(-1.0, 1.0, 1.0), dip).lerp(Vector3(-0.22, 0.42 + pump, -0.06), up)
	var hr := sh_r + HANG.lerp(low, dip).lerp(Vector3(0.22, 0.42 - pump, -0.06), up)
	return [hl, hr, 1.0]

## Underarm: the right hand swings back and low, then forward and up through the release and
## settles; the left points the way for balance.
static func _toss_hands(t: float, sh_l: Vector3, sh_r: Vector3) -> Array:
	var back := Vector3(0.05, -0.38, 0.28)
	var thru := Vector3(-0.05, 0.0, -0.55)
	var end := TOSS_RELEASE + 0.1
	var p := back.lerp(thru, smoothstep(0.3, end, t))
	if t < 0.3:
		p = HANG.lerp(back, smoothstep(0.0, 0.3, t))
	elif t > end:
		p = thru.lerp(HANG, smoothstep(end, LENGTH["toss"], t))
	return [sh_l + Vector3(0.15, -0.1, -0.4) * smoothstep(0.0, 0.3, t), sh_r + p, 1.0]

## 0 -> 1 from a to b, easing out past 1 and back (the weight arriving and settling).
static func _back(t: float, a: float, b: float) -> float:
	var x := clampf((t - a) / (b - a), 0.0, 1.0) - 1.0
	return 1.0 + (OVER + 1.0) * x * x * x + OVER * x * x

## 1 between a and b, eased in and out over `edge` seconds at each end.
static func _window(t: float, a: float, b: float, edge: float) -> float:
	return smoothstep(a, a + edge, t) * (1.0 - smoothstep(b - edge, b, t))

## `want`, pulled in to `reach` from `from` when it is further.
static func _within(from: Vector3, want: Vector3, reach: float) -> Vector3:
	var d := want - from
	return from + d.limit_length(reach * 0.98)
