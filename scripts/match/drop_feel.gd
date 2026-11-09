class_name DropFeel
extends RefCounted
## How the opening drop moves and lands: SUPERVIVE's glide force toward the keys, a flare just above the
## ground, and the landing's impact. DropReticle projects the same numbers to show where you'll land.

const FLARE_H := 4.0           # m, the glider flares (slows the fall) this far above the ground [est]
const FLARE_FALL := 2.2        # m/s, the fall speed it flares down to [est]
const FLARE_RATE := 6.0        # 1/s, how quickly the flare takes hold [est]
const LAND_SQUASH := 0.45      # model squash on touchdown: a low crouch [footage]

## The next flat velocity: the glide's force (Hunter.GLIDE_ACCEL) pulls it toward `mv * GLIDE_SPEED`, a quarter
## of it in the dive (HunterMove.dive_steer). Letting go brakes with the same force [est]: it never snaps.
static func steer(hv: Vector2, mv: Vector2, diving: bool, dt: float) -> Vector2:
	var force := Hunter.GLIDE_ACCEL * (HunterMove.dive_steer if diving else 1.0)
	return hv.move_toward(mv * Hunter.GLIDE_SPEED, force * dt)

## The next fall speed: the glider's sink, and a flare over the last few metres.
static func fall_vy(vy: float, sink: float, rate: float, above: float, dt: float) -> float:
	var goal := -sink
	if above < FLARE_H and sink > FLARE_FALL:
		goal = -lerpf(FLARE_FALL, sink, clampf(above / FLARE_H, 0.0, 1.0))
		rate = maxf(rate, FLARE_RATE)
	return lerpf(vy, goal, 1.0 - exp(-rate * dt))

## Touchdown: dust, a ring, a squash and a thud (no self-shake: item 50).
static func land(m: Match, h: Hunter) -> void:
	m.fx.dust(h.pos, 22)
	m.fx.ring(h.pos, 3.4, Color(1, 1, 1, 0.8), 0.4)
	m.fx.ring(h.pos, 1.8, Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()], 0.25)
	m.sfx("land", h.pos, -2.0, 0.8)
	h.squash = LAND_SQUASH
