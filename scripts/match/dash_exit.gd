class_name DashExit
extends RefCounted
## How a dash hands its speed on as it ends. The shared rule carries the burst: HunterMove.dash_exit as
## the roll runs out, Hunter.DASH_JUMP_CARRY on a jump out of it and the glide handoff, so a dash into a
## jump or a glide keeps going. A kit's dash_exit() rule {"cap": k, "ease": s} says no carried momentum
## (Sparkle's Wirerun, owner 11-08: no dash into a bunny hop or a fast glide): the run, a jump out of it
## or a glide right after start at most k x run speed and ease down to run speed over s seconds (no hard
## stop, and the ordinary run speed stays if you were moving), with no glide handoff. --sparkle-dash-check.

static func rule(h: Hunter) -> Dictionary:
	return h.ak.dash_exit() if h.ak else {}

## The velocity left as the roll runs out (`run` is the hunter's run speed right now).
static func leave(h: Hunter, v: Vector2, run: float) -> Vector2:
	var r := rule(h)
	if r.is_empty():
		return HunterMove.dash_exit(v, run)
	_start(h, r)
	return v.limit_length(run * float(r["cap"]))

## What a jump out of the dash keeps of it.
static func jump_keep(h: Hunter, keep: Vector2) -> Vector2:
	var r := rule(h)
	if r.is_empty():
		return keep
	_start(h, r)
	return keep.limit_length(_run_speed(h) * float(r["cap"]))

## The glide handoff of a burst that just ended: none under a no-carry rule.
static func handoff(h: Hunter, dir: Vector2, speed: float) -> void:
	if rule(h).is_empty():
		h.glide_handoff(dir, speed)

static func _start(h: Hunter, r: Dictionary) -> void:
	h.ak.exit_ease = {"t": 0.0, "cap": float(r["cap"]), "ease": maxf(0.01, float(r["ease"]))}

static func _run_speed(h: Hunter) -> float:
	return h.base_speed * (1.0 + h.gear_stat("speed")) * (1.35 if h.haste_t > 0.0 else 1.0)

## Each step after such a dash (ArchKit.tick): the speed eases from cap x run down to run speed on a
## quadratic ease-out. With a move key held the speed follows the curve (the ease you feel); let go and
## the curve is only a ceiling, so the brake takes you down as it always does.
static func settle(h: Hunter, dt: float) -> void:
	var e: Dictionary = h.ak.exit_ease
	if e.is_empty():
		return
	if h.roll_t > 0.0:              # a new dash: its own exit starts a new ease
		h.ak.exit_ease = {}
		return
	e["t"] = float(e["t"]) + dt
	var u := clampf(float(e["t"]) / float(e["ease"]), 0.0, 1.0)
	var run := _run_speed(h)
	var on_curve := run * lerpf(float(e["cap"]), 1.0, 1.0 - (1.0 - u) * (1.0 - u))
	var hv := Vector2(h.vel.x, h.vel.z)
	var mv: Vector2 = h.inp.get("move", Vector2.ZERO)
	var pin := mv.length() > 0.1 and hv.length() >= run * 0.98 and h.knock_t <= 0.0
	if hv.length() > on_curve or (pin and hv.length() < on_curve):
		hv = hv.normalized() * on_curve
		h.vel.x = hv.x
		h.vel.z = hv.y
	if u >= 1.0:
		h.ak.exit_ease = {}
