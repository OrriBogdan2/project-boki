class_name DotLook
extends RefCounted
## How damage over time reads on a body: one look for every source (Cinder's Ignite and burn, poison parts,
## item and merge burns, Blight embers; they all arrive as Ent.burn_t). A low flicker in the DoT's colour
## rides the body's flash tint, and each damage tick (Ent.dot_tick_at) adds one short pulse of the same colour.
## No particles, no extra draw calls. On Low quality it is a steady tint with no flicker or pulse.

const COL := Color("ff9a4a")     # the burn colour (also the damage numbers)
const BASE := 0.10               # tint strength while burning (0..1 of the body's flash mix)
const FLICKER := 0.07            # extra tint at the top of a flicker
const FLICKER_HZ := 11.0         # flicker steps per second
const PULSE := 0.22              # extra tint at the instant of a damage tick
const PULSE_S := 0.2             # s a tick pulse takes to fade
const STEP := 0.02               # tint is rounded to this, so a shader parameter is only set on a real change

## The DoT tint on `e` right now, 0 when nothing burns. `lite`: steady tint only.
static func amount(e: Ent, lite: bool) -> float:
	if e.burn_t <= 0.0 or e.dead:
		return 0.0
	if lite:
		return BASE
	var step := floorf(e.m.time * FLICKER_HZ) + float(e.get_instance_id() % 17)
	var flick := 0.5 + 0.5 * sin(step * 12.9898)
	var since: float = e.m.time - e.dot_tick_at
	var pulse := clampf(1.0 - since / PULSE_S, 0.0, 1.0)
	return snappedf(BASE + FLICKER * flick + PULSE * pulse, STEP)
