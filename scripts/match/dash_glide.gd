class_name DashGlide
extends RefCounted
## Shift into the glider without a hitch (decision 0061). Some kits end an air dash short (an air slide to a quarter,
## a barge planted) and wind it down (no glider for a moment). For WINDOW after an air dash:
## - a kit's cut of the dash's speed eases out (exponentially, `ease_t`) instead of landing in one step (it adds
##   cut x ease_t metres: 0.7-1.2 m on the air dashes that stop short);
## - an open glider keeps the dash's whole speed (a glide pressed in the dash, item 4): Loco.glide_step bleeds it;
## - a fresh glide press within `grace` (per hunter, Loco.dash_glide_grace) counts as a press in the dash: the
##   glider opens that step at the speed you have (Hunter._dash_into_glide), past the kit's wind-down.
## Measured by --airdash-glide-check. Numbers in content/rules/tuning.json "dash_glide".

const WINDOW := 0.3  # s after an air dash the carry is watched (a few ease_t: by then nothing is left)
const KNOCK_RECENT := 0.4  # s: a real knockback (Hunter.kb_t) this recent ends the watch
const CUT_MIN := 0.5  # m/s: a smaller drop between steps is the air step's own drag, not a kit's cut

var since := 9.0  # s since the last air dash step (9 = long ago, on the ground, or knocked)
var last := Vector2.ZERO  # m/s, the horizontal velocity the last step ended with while watching
var carry := Vector2.ZERO  # m/s of the dash's speed still easing out


## True while a glide press still counts as a press in the dash that just ended.
func fresh(h: Hunter) -> bool:
	return since < Loco.dash_glide_grace(h.arch)


## The horizontal velocity after one move step. `v0` is the step's starting velocity (after the kit's tick, which
## may have cut it), `hv` the move's result.
func step(h: Hunter, v0: Vector2, hv: Vector2, dt: float) -> Vector2:
	# (knock_t alone is not a knock: Sparkle's Wirerun holds it as its no-keys hold, through the streak and after)
	if h.grounded or (h.knock_t > 0.0 and h.m.time - h.kb_t < KNOCK_RECENT) or h.dropping or h.downed:
		since = 9.0
		carry = Vector2.ZERO
		return hv
	if h.roll_t > 0.0:
		since = 0.0 if h.move_kind == "dash" else 9.0
		carry = Vector2.ZERO
		last = hv
		return hv
	if since >= WINDOW:
		return hv
	since += dt
	var cut := last - v0
	if v0.length() < last.length() - CUT_MIN and h.wall_hit_v == Vector2.ZERO:  # (a wall's stop stays a stop)
		hv += cut
		carry += cut
	if h.gliding:
		carry = Vector2.ZERO  # the glider has it all now (its drag takes it from here)
	elif carry.length_squared() > 0.0:
		hv = _ease(hv, dt)
	last = hv
	return hv


## Lets `carry` go at the ease rate. A wall (or keys turning the hunter) that already took some of it off
## shrinks it first, so the ease never pushes back the other way.
func _ease(hv: Vector2, dt: float) -> Vector2:
	var dir := carry.normalized()
	carry = dir * minf(carry.length(), maxf(0.0, hv.dot(dir)))
	var drop := carry * (1.0 - exp(-dt / Loco.dash_glide_ease))
	carry -= drop
	if carry.length() < 0.05:
		drop += carry
		carry = Vector2.ZERO
	return hv - drop
