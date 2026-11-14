class_name DropFeel
extends RefCounted
## How the opening drop moves and lands: the free fall's air control, the glider's smooth steering toward the
## keys, a fresh press that pulls the glider, a flare just above the ground, and the landing's impact.
## DropReticle projects the same numbers to show where you'll land.

const ACCEL := 26.0            # m/s^2, speeding up toward the keys under the glider (90% of top speed in ~0.28s)
const BRAKE := 30.0            # m/s^2, slowing down or turning back (let go of the keys)
const FLARE_H := 4.0           # m, the glider flares (slows the fall) this far above the ground
const FLARE_FALL := 2.2        # m/s, the fall speed it flares down to
const FLARE_RATE := 6.0        # 1/s, how quickly the flare takes hold
const LAND_SQUASH := 0.45      # model squash on touchdown

## The next flat velocity. The free fall has the air control of every jump (Loco.air_step, owner 11-08: one
## model) up to DIVE_SPEED; the glider ramps toward `mv * DROP_SPEED` (a no-key drift decelerates, never snaps).
static func steer(hv: Vector2, mv: Vector2, diving: bool, dt: float) -> Vector2:
	if diving:
		return Loco.air_step(hv, mv, Hunter.DIVE_SPEED, dt)
	var want := mv * Hunter.DROP_SPEED
	var turning := hv.dot(want) < hv.length_squared() * 0.8      # slowing, reversing or letting go
	return hv.move_toward(want, (BRAKE if turning else ACCEL) * dt)

## True when this step's keys pull the glider out of the free fall: a fresh glide-key press (a Space press goes
## through Hunter.do_jump), or scripted input holding glide. A key held from before never does (DECISIONS
## 2026-11-08 and 2026-11-11: Space held from the jump-out keeps you falling).
static func pulls(inp: Dictionary, btn_was_held: bool) -> bool:
	if inp.get("glide_press_only", false):
		return inp.get("glide_btn", false) and not btn_was_held
	return inp.get("glide", false)

## The next fall speed: the glider's sink, and a flare over the last few metres.
static func fall_vy(vy: float, sink: float, rate: float, above: float, dt: float) -> float:
	var goal := -sink
	if above < FLARE_H and sink > FLARE_FALL:
		goal = -lerpf(FLARE_FALL, sink, clampf(above / FLARE_H, 0.0, 1.0))
		rate = maxf(rate, FLARE_RATE)
	return lerpf(vy, goal, 1.0 - exp(-rate * dt))

## Touchdown: dust, a squash and a thud (no self-shake: item 50).
static func land(m: Match, h: Hunter) -> void:
	m.fx.dust(h.pos, 22)
	m.sfx("land", h.pos, -2.0, 0.8)
	h.squash = LAND_SQUASH
