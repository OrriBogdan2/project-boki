class_name KinFaint
extends RefCounted
## How a knocked-out Boki (kstate "faint") goes down, for KinPuppet (the primitive bodies) and BokiRig (the rigged
## ones): it tumbles onto its side, the way the last hit pushed it (KinFlinch.push), lands with one small bounce and
## lies there until it comes round or is gone. Each driver owns one, calls update() every frame and adds roll and
## shove to Flex; the eyes, the breath and the spring back up stay the driver's.
## The tumble pivots on the edge of the body (half_w out to the side), so it tips over and does not sink into
## the ground.

const FALL_S := 0.26           # s from standing to lying on its side, falling faster as it goes
const BOUNCE_S := 0.2          # s of the one bounce after it lands
const BOUNCE_M := 0.045        # m the bounce lifts it
const BOUNCE_ROLL := 0.1       # share of the lying roll it rocks back on the bounce
const RISE_RATE := 18.0        # 1/s it rights itself at when it comes round: 97% in 0.2 s
## Roll (rad) it lies at, per body plan: a quad or biped on its side, a flyer on one wing, a serpent half over,
## a blob just slumps sideways.
const ROLL := {"quad": 1.25, "biped": 1.3, "flyer": 1.0, "serpent": 0.9, "blob": 0.4}

var plan := "blob"
var half_w := 0.15             # m from the middle of the body to its side: the edge it tips over
var roll := 0.0                # Flex rotation.z to add (rad)
var shove := Vector3.ZERO      # Flex offset to add (m): the tip over the edge, and the bounce
var _t := -1.0                 # s since it went down; below 0 while it is up
var _side := 1.0               # 1: falls to its right, -1: to its left
var _k := 0.0                  # how far over it is, 0..1

## Steps the tumble: `down` while knocked out, `push_x` the sideways part of the last hit's shove (KinFlinch.push.x).
func update(down: bool, push_x: float, dt: float) -> void:
	if down:
		if _t < 0.0:
			_t = 0.0
			_side = -1.0 if push_x < -0.1 else 1.0
		_t += dt
		var u := minf(_t / FALL_S, 1.0)
		_k = u * u
	else:
		_t = -1.0
		_k = lerpf(_k, 0.0, 1.0 - exp(-RISE_RATE * dt))
	var b := 0.0
	if _t >= FALL_S and _t < FALL_S + BOUNCE_S:
		b = sin(PI * (_t - FALL_S) / BOUNCE_S)
	var lie := float(ROLL.get(plan, ROLL["blob"])) * _k * (1.0 - BOUNCE_ROLL * b)
	roll = -_side * lie
	shove = Vector3(_side * half_w * (1.0 - cos(lie)), half_w * sin(lie) + BOUNCE_M * b, 0.0)

## True once it is lying on its side (the tumble and the bounce are done).
func lying() -> bool:
	return _t >= FALL_S + BOUNCE_S
