class_name DropFeel
extends RefCounted
## How the opening drop moves and lands: smooth steering toward the keys, a flare just above the
## ground, and the landing's impact. DropReticle projects the same numbers to show where you'll land.


## The next flat velocity: it ramps toward `mv * top speed` (a no-key drift decelerates, never snaps).
static func steer(hv: Vector2, mv: Vector2, diving: bool, dt: float) -> Vector2:
	var want := mv * (HunterFeel.dive_speed if diving else HunterFeel.drop_speed)
	var gain := HunterFeel.drop_dive_accel if diving else HunterFeel.drop_accel
	var turning := hv.dot(want) < hv.length_squared() * 0.8      # slowing, reversing or letting go
	return hv.move_toward(want, (HunterFeel.drop_brake if turning else gain) * dt)

## The next fall speed: the glider's sink, and a flare over the last few metres.
static func fall_vy(vy: float, sink: float, rate: float, above: float, dt: float) -> float:
	var goal := -sink
	if above < HunterFeel.drop_flare_h and sink > HunterFeel.drop_flare_fall:
		goal = -lerpf(HunterFeel.drop_flare_fall, sink, clampf(above / HunterFeel.drop_flare_h, 0.0, 1.0))
		rate = maxf(rate, HunterFeel.drop_flare_rate)
	return lerpf(vy, goal, 1.0 - exp(-rate * dt))

## Touchdown: dust, a ring, a squash and a thud (no self-shake: item 50).
static func land(m: Match, h: Hunter) -> void:
	m.fx.dust(h.pos, 22)
	m.fx.ring(h.pos, 3.4, Color(1, 1, 1, 0.8), 0.4)
	m.fx.ring(h.pos, 1.8, Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()], 0.25)
	m.sfx("land", h.pos, -2.0, 0.8)
	h.squash = HunterFeel.drop_land_squash
