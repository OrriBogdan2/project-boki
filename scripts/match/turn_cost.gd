class_name TurnCost
extends RefCounted
## What a sharp turn costs a chained move (docs/decisions/0083). A dash, rush or kit step that starts while you
## carry speed over your run speed keeps only the part of it along its own heading:
## the same way is free, square across or straight back costs it all. The cost is `loss` (0..1): the move
## starts at (1 - loss) of its speed and builds back to it over `recover` seconds, and an air move hands over
## only (1 - loss) of the speed above the run when it ends. The speed you carry is your velocity now, or the
## last dash's for `window` seconds after it ended (the ground hands a dash over at the run, so without this a
## dash straight back right after one would be free). Tunables: content/rules/hunter_move.json physics.

static var _phys: Dictionary = HunterMove.rules()["physics"]
static var full: float = _phys["turn_full"]           # m/s over the run speed at which a turn costs in full
static var window: float = _phys["turn_window"]       # s after a dash ends that its speed still counts
static var recover: float = _phys["turn_recover"]     # s a turned move takes to build back to its speed

var loss := 0.0
var ramp_t := 0.0             # s of the build-back left
var peak := 0.0               # m/s: the move's top speed so far (a dash's curve can end slow)
var last_v := Vector2.ZERO    # the last dash: its heading at its top speed
var last_at := -9.0           # when it ended (match time)

## The loss carried speed `carried` puts on a move along `dir` against run speed `run`.
static func loss_of(carried: Vector2, dir: Vector2, run: float) -> float:
	var weight := clampf((carried.length() - run) / full, 0.0, 1.0)
	if weight <= 0.0:
		return 0.0
	return weight * (1.0 - clampf(carried.normalized().dot(dir), 0.0, 1.0))

## A move along `dir` starts at match time `now` with velocity `hv`, run speed `run`: sets its loss.
func start(hv: Vector2, dir: Vector2, run: float, now: float) -> void:
	var fade := clampf(1.0 - (now - last_at) / window, 0.0, 1.0)
	loss = maxf(loss_of(hv, dir, run), loss_of(last_v, dir, run) * fade)
	ramp_t = recover if loss > 0.0 else 0.0
	peak = 0.0

## The move's velocity `hv` at match time `now` with the turn's build-back taken off (once per step while it
## lasts). Remembers it as it goes, since a kit may cut its move short itself.
func step(hv: Vector2, dt: float, now: float) -> Vector2:
	peak = maxf(peak, hv.length())
	if peak > 0.0:     # a standing wind-up (Kael's) is not a move to remember
		last_v = hv.normalized() * peak
		last_at = now
	if ramp_t <= 0.0:
		return hv
	var k := 1.0 - loss * ramp_t / recover
	ramp_t -= dt
	return hv * k

## What an air move ending at velocity `hv` carries on with, its hand-over `run_v` (the run) plus the share of the
## rest the turn left it. A kit with a carry of its own (Cinder's poof) hands it over through this too.
func hand_over(hv: Vector2, run_v: Vector2) -> Vector2:
	ramp_t = 0.0
	return run_v + (hv - run_v) * (1.0 - loss)
