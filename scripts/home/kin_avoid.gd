class_name KinAvoid
extends RefCounted
## A Boki walking past one that is parked (asleep, in the tub, held, at a toy or a bowl) goes round it instead of
## pushing into it and getting pinned against a toy or a rim. A parked Boki never moves, so the walker bends its
## aim sideways. One that is boxed in (by them or a corner) steps out the open side first, and drops its errand if
## that keeps happening.

const ERRAND := 1.0     # m: a parked Boki this near the walker's goal is the errand (a pile to join), not in the way
const REACH := 1.2       # m: a parked Boki this near is steered round
const SLIDE := 1.5       # how hard the aim swings along a parked Boki's side (the way that agrees with the walk)
const SHY := 0.8         # how hard it also backs off one
const PIN_DIST := 0.15   # m: a walker that wants to go and stays within this for PIN_SECS is pinned
const PIN_SECS := 1.0    # s pinned before it steps out
const OUT_SECS := 0.8    # s it steps out for
const OUT_RUN := 2.0     # m: how far ahead the step-out aims
const GIVE_UP := 2.0     # step-outs (fading 1 per 3 s) after which a walker drops its errand: the way is shut

## Asleep, in the tub or held.
static func lying(o: Dictionary) -> bool:
	return float(o.get("nap_t", 0.0)) > 0.0 or o.has("bath") or float(o.get("hold_t", 0.0)) > 0.0

## Lying, or busy at its toy or bowl: it stays where it is, so the others make room (separation) and go round.
static func parked(o: Dictionary) -> bool:
	return lying(o) or o.get("play", {}).get("phase", "") == "play" or o.get("eat", {}).get("phase", "") == "eat"

## Has k been boxed in so often that its errand should be dropped?
static func shut(k: Dictionary) -> bool:
	return float(k.get("out_n", 0.0)) >= GIVE_UP

## `aim` (where k is heading, from HomeBuild.steer) bent round the parked Boki near it or in its way. d: the step in s.
static func around(kins: Array, k: Dictionary, pos: Vector3, aim: Vector3, d: float) -> Vector3:
	var to := Vector2(aim.x - pos.x, aim.z - pos.z)
	var goal: Vector3 = k["goal"]
	var near := kins.filter(func(o): return o != k and parked(o) and not o.has("indoors") \
			and Vector2(o["pos"].x - pos.x, o["pos"].z - pos.z).length() < REACH \
			and Vector2(o["pos"].x - goal.x, o["pos"].z - goal.z).length() > ERRAND)
	var anchor: Vector3 = k.get("avoid_at", Vector3.INF)
	var still := float(k.get("avoid_t", 0.0)) + d
	if to.length() <= 0.4 or anchor == Vector3.INF or Vector2(pos.x - anchor.x, pos.z - anchor.z).length() > PIN_DIST:
		k["avoid_at"] = pos
		still = 0.0
	k["avoid_t"] = still
	k["out_n"] = maxf(0.0, float(k.get("out_n", 0.0)) - d / 3.0)
	if still > PIN_SECS:
		k["out_t"] = OUT_SECS
		k["avoid_t"] = 0.0
		k["out_n"] = float(k["out_n"]) + 1.0
	if float(k.get("out_t", 0.0)) > 0.0:
		k["out_t"] = float(k["out_t"]) - d
		var open := Vector2.ZERO
		for o in near:
			open += Vector2(pos.x - o["pos"].x, pos.z - o["pos"].z).normalized()
		if open.length() < 0.01 and to.length() > 0.01:
			var turn := 1.0 if int(k["out_n"]) % 2 == 1 else -1.0
			open = Vector2(-to.y, to.x) * turn      # pinned by a corner: sidestep it
		if open.length() > 0.01:
			var out := open.normalized() * OUT_RUN
			return pos + Vector3(out.x, 0, out.y)
	if to.length() < 0.01:
		return aim
	var fwd := to.normalized()
	var dir := fwd
	for o in near:
		var rel := Vector2(o["pos"].x - pos.x, o["pos"].z - pos.z)
		var dist := rel.length()
		if dist < 0.001 or rel.dot(fwd) < -0.3 * dist:
			continue
		var tangent := Vector2(-rel.y, rel.x) / dist
		if tangent.dot(fwd) < 0.0:
			tangent = -tangent
		dir += (tangent * SLIDE - rel / dist * SHY) * (1.0 - dist / REACH)
	dir = dir.normalized() * to.length()
	return pos + Vector3(dir.x, 0, dir.y)
