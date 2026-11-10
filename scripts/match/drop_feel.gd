class_name DropFeel
extends RefCounted
## How the opening drop moves and lands: smooth steering toward the keys, a flare just above the
## ground, and the landing's impact. DropReticle projects the same numbers to show where you'll land.

const ACCEL := 26.0            # m/s^2, speeding up toward the keys under the glider (90% of top speed in ~0.28s)
const DIVE_ACCEL := 45.0       # m/s^2, the same in the dive
const BRAKE := 30.0            # m/s^2, slowing down or turning back (let go of the keys)
const FLARE_H := 4.0           # m, the glider flares (slows the fall) this far above the ground
const FLARE_FALL := 2.2        # m/s, the fall speed it flares down to
const FLARE_RATE := 6.0        # 1/s, how quickly the flare takes hold
const LAND_SQUASH := 0.45      # model squash on touchdown

## The next flat velocity: it ramps toward `mv * top speed` (a no-key drift decelerates, never snaps).
static func steer(hv: Vector2, mv: Vector2, diving: bool, dt: float) -> Vector2:
	var want := mv * (Hunter.DIVE_SPEED if diving else Hunter.DROP_SPEED)
	var gain := DIVE_ACCEL if diving else ACCEL
	var turning := hv.dot(want) < hv.length_squared() * 0.8      # slowing, reversing or letting go
	return hv.move_toward(want, (BRAKE if turning else gain) * dt)

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
