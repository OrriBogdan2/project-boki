class_name CastHold
extends RefCounted
## A cast that hovers the caster in place: slowed walking, height held (no fall, even over the abyss) until
## the owner drops it. The kit asks `slow_k` from its move_k() while it holds and calls tick() every step.

var slow_k := 0.2        # share of run speed kept while held
var hold_y := 0.0        # m, the height kept
var _h: Hunter

## Starts holding `h` at its current height with `slow` (0..1) of its run speed.
static func hover_slow(h: Hunter, slow: float) -> CastHold:
	var c := CastHold.new()
	c._h = h
	c.slow_k = slow
	c.hold_y = h.pos.y
	return c

## Pins the height (never below the ground under it) and cancels vertical speed; returns where it is now.
## Sideways speed is left to the walk (slowed by slow_k through move_k) and to knocks.
func tick(world: World) -> Vector3:
	_h.vel.y = 0.0
	_h.pos.y = maxf(hold_y, world.ground_at(_h.pos.x, _h.pos.z))
	if _h.pos.y - _h.ground() > 0.05:
		_h.grounded = false
	return _h.pos
