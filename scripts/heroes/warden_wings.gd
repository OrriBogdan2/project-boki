class_name WardenWings
extends RefCounted
## A Hero's moth wings (warden_anim/<art>.json "wings": Sable). They rest folded down against her back and now and
## then come up, raised open behind her: WardenGlb.Springs swings a hanging wing chain back, up and out as the
## root's WING_FOLD meta goes to -1. This decides how far open they are each frame. They rise
##  - now and then while she stands about: a slow open, a hold with a small flutter, a slow close;
##  - on a kit move's "wg" channel (her Vault's flips, the Encore dance), on a dash, and in the air;
##  - on an emote;
## and fold straight back down while she runs or lies downed. A Hero without the block has no WardenWings (Pip's
## wings keep HunterAnim's skate fold).
## Docs: docs/SABLE_WINGS.md.

const RIM := 0.001           # (open below this counts as folded: the flutter rests)

var gap := Vector2(8.0, 15.0)      # s between two idle raises (random in the range)
var hold := Vector2(1.6, 3.0)      # s an idle raise stays open
var open_s := 1.1                  # s a slow open takes (idle, emote): a moth's unhurried spread
var close_s := 0.8                 # s it takes to fold back
var quick_s := 0.22                # s a kit move, a dash or a jump takes to open them
var run_close_s := 0.3             # s they fold in once she runs
var fold_speed := 3.0              # m/s: faster than this on the ground is running (folds them)
var air_open := 0.85               # how far open in the air (1 is the kit move's full raise)
var air_delay_s := 0.12            # s off the ground before the air opens them (a step's lip at a run does not)
var flutter := 0.06                # WING_FOLD units the open wing trembles by (about 8 degrees at full raise)
var flutter_hz := 1.6              # its rate

var p := 0.0                 # the open progress, 0 folded .. 1 raised (eased by smoothstep on the way out)
var idle_t := 0.0            # s until the next idle raise
var hold_t := 0.0            # s left in the current idle raise
var ph := 0.0                # the flutter's phase
var air_t := 0.0             # s off the ground so far
var rng := 0

## The Hero's wings, or null when its data has none. `seed` keeps each character's idle raises on their own clock.
static func make(cfg: Dictionary, seed: int) -> WardenWings:
	if cfg.is_empty():
		return null
	var w := WardenWings.new()
	var g: Array = cfg.get("idle_gap_s", [w.gap.x, w.gap.y])
	var h: Array = cfg.get("idle_hold_s", [w.hold.x, w.hold.y])
	w.gap = Vector2(float(g[0]), float(g[1]))
	w.hold = Vector2(float(h[0]), float(h[1]))
	w.open_s = float(cfg.get("open_s", w.open_s))
	w.close_s = float(cfg.get("close_s", w.close_s))
	w.quick_s = float(cfg.get("quick_s", w.quick_s))
	w.run_close_s = float(cfg.get("run_close_s", w.run_close_s))
	w.fold_speed = float(cfg.get("fold_speed", w.fold_speed))
	w.air_open = float(cfg.get("air_open", w.air_open))
	w.air_delay_s = float(cfg.get("air_delay_s", w.air_delay_s))
	w.flutter = float(cfg.get("flutter", w.flutter))
	w.flutter_hz = float(cfg.get("flutter_hz", w.flutter_hz))
	w.rng = seed & 0x7fffffff
	w.idle_t = w._range(w.gap) * 0.5      # (the first raise comes a little sooner)
	return w

## The WING_FOLD value this frame (0 folded .. -1 raised). `kit`: the kit move's "wg" (0..1); `off`: off the ground
## or dashing (counted once it lasts `air_delay_s`); `emote`: an emote playing; `speed`: m/s on the ground;
## `down`: downed.
func fold(dt: float, kit: float, off: bool, emote: bool, speed: float, down: bool) -> float:
	air_t = air_t + dt if off else 0.0
	var air := air_t > air_delay_s
	var running := (speed > fold_speed and not air) or down
	idle_t -= dt
	if running or air or kit > 0.0:
		hold_t = 0.0                       # (an idle raise gives way)
		idle_t = maxf(idle_t, gap.x * 0.5)
	elif idle_t <= 0.0 and hold_t <= 0.0:
		hold_t = _range(hold)
		idle_t = _range(gap) + hold_t
	hold_t = maxf(hold_t - dt, 0.0)
	var want := kit
	var dur := quick_s
	if air:
		want = maxf(want, air_open)
	if not running and (emote or hold_t > 0.0) and want < 1.0:
		want = 1.0
		dur = open_s if kit <= 0.0 and not air else quick_s
	if running and kit <= 0.0:
		want = 0.0
	if want <= p:
		dur = run_close_s if running else close_s
	var step := dt / maxf(dur, 0.01)
	p = move_toward(p, want, step)
	var e := smoothstep(0.0, 1.0, p)
	ph = fmod(ph + dt * flutter_hz * TAU, TAU)
	var fl := sin(ph) * flutter * e if e > RIM else 0.0
	return -(e + fl)

func _range(r: Vector2) -> float:
	rng = (rng * 1103515245 + 12345) & 0x7fffffff
	return lerpf(r.x, r.y, float(rng % 10000) / 10000.0)
