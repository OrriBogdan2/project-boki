class_name KinNap
extends RefCounted
## How a Boki naps, for KinPuppet (the primitive bodies) and BokiRig (the rigged ones). The home sets the meta
## kstate "sleep" while a Boki's nap_t runs (home.gd), so every nap (alone, in a friends' pile, in the yard) gets
## the three moves:
##   settle: it lies down over SETTLE (`lie` eases 0 to 1; the rig crossfades into its sleep clip that long)
##   sleep: a slow breath (`breath`) and an ear twitch now and then (`twitch`, 1 down to 0)
##   wake: it gets up over the first UP of WAKE and stretches long and low, front down (`long`, `low`, `bow`)
## A bigger Boki (its scale times the root of its KinSpec mass) does all of it slower: every time is multiplied
## by `slow`, worked out when it lies down or gets up. Each driver owns one and calls update() every frame;
## nothing here allocates.

const SETTLE := 0.6                     # s to lie down, for a Boki of heft 1
const WAKE := 1.1                       # s of the wake stretch, getting up included
const UP := 0.35                        # share of WAKE it takes to get up off the ground
const BREATH := 3.6                     # s per breath asleep (the awake idle breath is about 2.9 s)
const BREATH_DEPTH := 0.045             # height swell per breath asleep, as a share of its height
const TWITCH_GAP := Vector2(3.0, 8.0)   # s between ear twitches asleep (min, max)
const TWITCH := 0.3                     # s an ear twitch lasts
const STRETCH_LONG := 0.16              # length gained at the top of the stretch, as a share
const STRETCH_LOW := 0.07               # height lost at the top of the stretch, as a share
const STRETCH_BOW := 0.14               # rad it tips front down at the top of the stretch
const SLOW_MIN := 0.85                  # the smallest Boki naps this much faster than heft 1...
const SLOW_MAX := 1.4                   # ...and the biggest this much slower

var lie := 0.0
var breath := 0.0
var twitch := 0.0
var long := 0.0
var low := 0.0
var bow := 0.0
var slow := 1.0
var asleep := false
var _mass := 1.0
var _u := 0.0                  # 0 up, 1 lying (before easing)
var _wake := 1.0               # progress of the wake stretch, 1 when done
var _breath_t := 0.0
var _twitch_t := 0.0
## Twitches roll on their own generator, like KinPuppet's blinks: the global one stays the match's.
static var _rng := RandomNumberGenerator.new()

func _init(species: String) -> void:
	var spec := KinLib.kin(species)
	if spec:
		_mass = spec.mass
	_twitch_t = _rng.randf_range(TWITCH_GAP.x, TWITCH_GAP.y)

## Seconds the rig crossfades into the sleep clip (`to_sleep`) or out of it.
func fade(to_sleep: bool) -> float:
	return (SETTLE if to_sleep else WAKE * UP) * slow

## Steps the nap: `sleep` is true while the kstate is "sleep"; `root` is the kin's model root (its size).
func update(root: Node3D, sleep: bool, dt: float) -> void:
	if sleep != asleep:
		asleep = sleep
		slow = clampf(sqrt(root.scale.y * sqrt(_mass)), SLOW_MIN, SLOW_MAX)
		_wake = 1.0 if sleep else 0.0
	if asleep:
		_u = minf(1.0, _u + dt / (SETTLE * slow))
	else:
		_u = maxf(0.0, _u - dt / (WAKE * UP * slow))
		_wake = minf(1.0, _wake + dt / (WAKE * slow))
	lie = smoothstep(0.0, 1.0, _u)
	var s := sin(_wake * PI) if _wake < 1.0 else 0.0
	long = s * STRETCH_LONG
	low = s * STRETCH_LOW
	bow = s * STRETCH_BOW
	if lie <= 0.0:
		breath = 0.0
		twitch = 0.0
		return
	_breath_t += dt
	breath = sin(_breath_t * TAU / (BREATH * slow)) * BREATH_DEPTH * lie
	twitch = maxf(0.0, twitch - dt / TWITCH)
	if _u >= 1.0:
		_twitch_t -= dt
		if _twitch_t <= 0.0:
			_twitch_t = _rng.randf_range(TWITCH_GAP.x, TWITCH_GAP.y) * slow
			twitch = 1.0
