class_name MantleCarry
extends RefCounted
## Item 185b: a mantle keeps your momentum (SUPERVIVE's mini-mantle). You fly into a ledge from a jump,
## a dash, a glide or the abyss and come over the top still moving: one motion, not a stop and climb.
##  - Keys into the face within APPROACH_DOT (about 60 degrees) catch a ledge; with the keys idle, so
##    does momentum: heading into it that closely at PUSH_SPEED or more. Keys along or away from a
##    wall never pull you up it.
##  - Over the lip you leave at KEEP of the speed you came in with (SV MiniMantleXYSpeedTargetCoefficient
##    0.6), never above it, and never under the usual mantle launch (HunterMove.mantle_launch). For
##    MINI_S after it (SV MiniMantlePostLaunchDuration) that speed is held while you're still in the air
##    and your keys don't pull back, so air drag doesn't take it straight back off you.
## The speed you came in with is a decaying peak (carry_v), so the wall that stopped you a step
## before the catch doesn't count as having stopped you.

const KEEP := 0.6              # [game data] MiniMantleXYSpeedTargetCoefficient
const APPROACH_DOT := 0.45     # keys or momentum this far into the face (cos ~63 degrees) catch a ledge
const PUSH_SPEED := 2.0        # m/s into the face: momentum alone is a push
const PEAK_DECAY := 6.0        # m/s per s: how fast the remembered approach speed fades
const MINI_S := 0.75           # [game data] MiniMantlePostLaunchDuration

## Every step, before the move: hold a fresh mantle's speed, and remember how fast you're going (a
## decaying peak). Returns the horizontal velocity to move with.
static func step(h: Hunter, hv: Vector2, dt: float) -> Vector2:
	var mini := h.carry_mini
	if not mini.is_empty():
		mini["t"] = float(mini["t"]) - dt
		if mini["t"] <= 0.0 or h.grounded or not h.lfloat.is_empty():
			h.carry_mini = {}
		else:
			var d: Vector2 = mini["dir"]
			var short := float(mini["v"]) - hv.dot(d)
			if short > 0.0 and h.inp["move"].dot(d) >= 0.0:
				hv += d * short       # held firm: air drag doesn't take it back off you
	h.carry_v = maxf(hv.length(), h.carry_v - PEAK_DECAY * dt)
	if hv.length() > 0.5:
		h.carry_dir = hv.normalized()
	return hv

## A teleport (a blink, a respawn, a portal) starts you with no momentum to carry.
static func forget(h: Hunter) -> void:
	h.carry_v = 0.0
	h.carry_mini = {}

## Does heading `toward` (from you to the face) count as pushing into it: keys or momentum?
static func pushing(h: Hunter, toward: Vector2, mv: Vector2) -> bool:
	if toward.length() < 0.01:
		return mv.length() > 0.3
	var tn := toward.normalized()
	if mv.length() > 0.3:
		return tn.dot(mv.normalized()) >= APPROACH_DOT
	return h.carry_v >= PUSH_SPEED and tn.dot(h.carry_dir) >= APPROACH_DOT

## The way you're heading when the keys are idle (momentum), else the keys.
static func heading(h: Hunter, mv: Vector2) -> Vector2:
	if mv.length() > 0.3:
		return mv
	return h.carry_dir * (1.0 if h.carry_v >= PUSH_SPEED else 0.0)

## Over the lip: at least KEEP of the speed you caught the ledge with, toward your keys (or on in the
## direction you were going), capped at that speed.
static func exit(h: Hunter, hv: Vector2, n: Vector2, mv: Vector2, v_in: float) -> Vector2:
	var d := mv.normalized() if mv.length() > 0.3 else n
	if d.dot(n) < 0.0:
		return hv       # steering back off the ledge: your keys win
	var want := minf(maxf(v_in * KEEP, HunterMove.mantle_launch(h.base_speed)), maxf(v_in, h.base_speed))
	var along := hv.dot(d)
	if along < want:
		hv += d * (want - along)
	h.carry_mini = {"t": MINI_S, "v": want, "dir": d}
	return hv

## How far up the face a ledge rise has got, 0 (at the foot) to 1 (at the lip); -1 when you are not rising. The
## Warden's mantle clip plays at this phase, so its pose is the body's own progress and never lags it.
static func rise_k(h: Hunter) -> float:
	var lf := h.lfloat
	if lf.is_empty():
		return -1.0
	var y0 := float(lf["y0"])
	return clampf((h.pos.y - y0) / maxf(float(lf["lip"]) + 0.12 - y0, 0.05), 0.0, 1.0)
