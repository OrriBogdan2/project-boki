class_name GlideDive
extends RefCounted
## The glider's dive [game data]: hold crouch under an open glider and the canopy folds into a straight
## plunge toward HunterMove.dive_vy (GlideDiveZTargetSpeed), pulled there at HunterMove.dive_accel
## (GlideDiveZForceMax over the hunter's mass), while the keys steer at HunterMove.dive_steer of their
## glide force (GlideDiveXYForceMultiplier). It ends when you let go, within HunterMove.dive_cancel_h of
## the ground (GlideDiveCancelDistance) or after HunterMove.dive_timeout seconds of holding
## (GlideDiveTimeout), and the glide catches you again. The key is ours: the source's data and footage
## name no dive input.

var on := false        # plunging now
var held_t := 0.0      # s crouch has been held under the glider; past dive_timeout the dive waits for a fresh press

## Decides whether this step plunges: crouch held under the glider (not in the opening drop or a
## current), with more than the cancel height left above the ground or the island's lip.
func tick(h: Hunter, dt: float) -> void:
	var held: bool = h.gliding and not h.dropping and not h.in_current and bool(h.inp.get("crouch", false))
	if not held:
		on = false
		held_t = 0.0
		return
	held_t += dt
	var under := h.lip_y if h.over_void() else h.ground()
	on = h.pos.y - under > HunterMove.dive_cancel_h and held_t <= HunterMove.dive_timeout

## The fall speed after a step of the plunge.
func fall_vy(vy: float, dt: float) -> float:
	return move_toward(vy, -HunterMove.dive_vy, HunterMove.dive_accel * dt)

## Horizontal steering in the plunge: the glide's own steering at dive_steer of its force.
func steer(hv: Vector2, wish: Vector2, gs: float, dt: float) -> Vector2:
	return hv.lerp(Loco.glide_step(hv, wish, gs, Loco.glide_max, dt), HunterMove.dive_steer)
