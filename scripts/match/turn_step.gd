class_name TurnStep
extends RefCounted
## Turning on the spot (HunterAnim ticks it, the rig and a Hero's clips both read it). Standing, the feet stay
## where they are while the aim swings: `lag` is how far the legs are behind the facing, and the upper body leads.
## Past STEP_AT the feet step round: the foot on the side of the turn first, pivoting on the other, then the
## other follows. Moving, a kit move, a shot or a cast cancels a step at once.
## Each Hero's step is data: content/rules/warden_anim/<art>.json "turn" {dur, lift}.

const META := "turn_step"    # model meta: the TurnStep, for a Hero's clips (WardenTurn)
const STEP_AT := 1.5          # rad (~86°): a bigger lag than this steps; a smaller one stays an upper-body lead
const STEP_MAX := 1.3         # rad: the most one step turns the legs (more is taken by the next step)
const STEP_AGAIN := 0.35      # rad: still this far behind after a step: another one
const PINS := 0.05            # rad: a step that turns the legs more than this plants the other foot (it follows)
const CANCEL_RATE := 25.0     # 1/s: how fast the legs come back under the body when a step is cancelled
const DUR := 0.26             # s: one step, when the Hero's data has none
const LIFT := 0.5             # rad: the stepping thigh's raise at mid-step (the shin folds twice that)

var lag := 0.0                # rad the legs are turned off the facing (the feet stay put while the body turns)
var face := 0.0               # the facing lag was measured against (lag_at: a reader a frame apart)
var t := -1.0                 # s into the step on now; -1: none
var swing := 0                # the stepping foot: 0 left, 1 right
var turns := 0.0              # rad this step turns the legs
var pins := false             # this step plants the other foot (and a step of that foot will follow)
var held := false             # standing still and free: steps may play
var serial := 0               # counts steps (a reader sees a new one start)
var dur := DUR
var lift_max := LIFT
var _eased := 0.0

func _init(arch: String) -> void:
	var d: Dictionary = WardenClips.data(WardenGlb.art(arch)).get("turn", {})
	dur = float(d.get("dur", DUR))
	lift_max = float(d.get("lift", LIFT))

## dface: how far the facing turned this frame (rad); standing: on the ground and still; busy: a shot, cast or move.
func tick(dt: float, now_face: float, dface: float, standing: bool, busy: bool) -> void:
	face = now_face
	held = standing and not busy
	if not held:
		t = -1.0
		lag = lerpf(lag, 0.0, 1.0 - exp(-CANCEL_RATE * dt))
		return
	lag = clampf(lag - dface, -PI, PI)
	if t < 0.0:
		if absf(lag) > STEP_AT:
			_start(1 if lag > 0.0 else 0)
		return
	t += dt
	var e := smoothstep(0.0, 1.0, t / dur)
	lag -= turns * (e - _eased)
	_eased = e
	if t >= dur:
		t = -1.0
		if pins or absf(lag) > STEP_AGAIN:
			_start(1 - swing)

func _start(foot: int) -> void:
	swing = foot
	turns = clampf(lag, -STEP_MAX, STEP_MAX)
	pins = absf(turns) > PINS
	t = 0.0
	_eased = 0.0
	serial += 1

## 0..1 through the step on now (0 with none).
func progress() -> float:
	return clampf(t / dur, 0.0, 1.0) if t >= 0.0 else 0.0

## The thigh's raise (rad) of one foot (0 left, 1 right) this frame.
func lift(foot: int) -> float:
	return lift_max * sin(progress() * PI) if t >= 0.0 and foot == swing else 0.0

## lag against a facing read a frame apart from the tick (the clips' bones run in their own _process).
func lag_at(now_face: float) -> float:
	return lag + wrapf(face - now_face, -PI, PI) if held else lag
