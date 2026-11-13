class_name AimPitch
extends RefCounted
## The body's pose across terrace heights: the pitch (rad, up +) the spine and arms take so the weapon points at
## what the cursor is on (a Hunter on the ledge above, a ledge below) instead of the knees. The same rule the shot
## uses (Match.AIM_DY_MAX, a rise under DEAD_DY stays flat): this is the pose, the shot's path is unchanged.
## HunterAnim eases it in under aim, casts and kit moves; WardenAim lays it on a .glb's bones. Feet stay planted.

const MAX := 0.35       # rad (20 deg): the most the body leans into an aim up or down
const SPINE := 0.5      # share of the pitch the spine takes (the hips bone / Torso); the arms take the rest
const MIN_D := 1.5      # m: a cursor nearer than this aims as if it were this far (no steep flicks point-blank)
const DEAD_DY := 0.3    # m: a rise this small is the same ground (the shot's own cut)

## The pitch for Hunter h this frame (0: flat ground, no aim height, or a cliff past what shots climb).
static func of(h: Hunter) -> float:
	if not h.inp.has("aim_y"):
		return 0.0
	return rise(float(h.inp["aim_y"]) - h.pos.y, AimMode.cursor_dist(h))

## The pitch for an aim point dy metres above the shooter's ground and dist metres away.
static func rise(dy: float, dist: float) -> float:
	if absf(dy) <= DEAD_DY or absf(dy) > Match.AIM_DY_MAX:
		return 0.0
	return clampf(atan2(dy, maxf(MIN_D, dist)), -MAX, MAX)
