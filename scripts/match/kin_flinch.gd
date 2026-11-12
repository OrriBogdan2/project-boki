class_name KinFlinch
extends RefCounted
## How a Boki's body takes a hit, for KinPuppet (the primitive bodies) and BokiRig (the rigged ones).
## KinFlinch.hit() writes the metas hit_n, hit_k, hit_push and hit_mass on the kin's model root (plain values: a hit
## allocates nothing); each driver owns one KinFlinch,
## calls update() every frame, and adds rot, shove, wide and tall to Flex.
## The body snaps to the jolt at once (it has to read within 0.1 s), then springs back: how far
## scales with the hit and shrinks with mass, how long it takes grows with mass (light Boki snap
## back, heavy ones carry the hit). Each body plan jolts its own way (PLAN).

const SETTLE_LIGHT := 0.20     # s until the jolt is down to a quarter, for MASS_LIGHT
const SETTLE_HEAVY := 0.30     # s, for MASS_HEAVY
const MASS_LIGHT := 0.8        # KinSpec mass of the lightest Boki
const MASS_HEAVY := 2.0        # ...and of the heaviest
const DAMPING := 0.55          # spring damping ratio: one small overshoot
const OMEGA_PER_S := 1.75      # natural frequency (rad) times settle time (s) at that damping
const K_MIN := 0.5             # strength of a chip hit
const K_PER_FRAC := 4.0        # strength gained per share of max health a hit takes
const K_MAX := 1.3
## Per body plan, per unit of strength: pitch and roll (rad), yaw twist (rad), shove (m), squash and lift (m).
const PLAN := {
	"quad": {"pitch": 0.15, "roll": 0.11, "yaw": 0.0, "shove": 0.025, "squash": 0.08, "lift": 0.0},
	"biped": {"pitch": 0.11, "roll": 0.09, "yaw": 0.0, "shove": 0.03, "squash": 0.10, "lift": 0.05},
	"flyer": {"pitch": 0.19, "roll": 0.175, "yaw": 0.0, "shove": 0.06, "squash": 0.03, "lift": 0.03},
	"serpent": {"pitch": 0.1, "roll": 0.15, "yaw": 0.225, "shove": 0.05, "squash": 0.04, "lift": 0.0},
	"blob": {"pitch": 0.06, "roll": 0.06, "yaw": 0.0, "shove": 0.035, "squash": 0.22, "lift": 0.0},
}

var plan := "blob"
var rot := Vector3.ZERO        # Flex rotation to add (rad)
var shove := Vector3.ZERO      # Flex offset to add (m, Flex space)
var wide := 1.0                # Flex width factor
var tall := 1.0                # Flex height factor
var _n := 0                    # the "hit" count already taken up
var _amp := 0.0                # strength of the current jolt
var _x := 0.0                  # 1 at the hit, springs to 0
var _v := 0.0
var _omega := 20.0
var push := Vector2.ZERO       # which way the last hit shoved the body, in Flex space (x right, y back)

## A hit on a Boki: `away` is the way the hit shoves it (world), `frac` the share of its max health the hit took,
## `mass` its KinSpec mass.
static func hit(model: Node3D, away: Vector3, frac: float, mass: float) -> void:
	model.set_meta(&"hit_k", clampf(K_MIN + frac * K_PER_FRAC, K_MIN, K_MAX) / sqrt(maxf(mass, 0.1)))
	model.set_meta(&"hit_push", away)
	model.set_meta(&"hit_mass", mass)
	model.set_meta(&"hit_n", count(model) + 1)

## How many hits the model has taken.
static func count(model: Node3D) -> int:
	return int(model.get_meta(&"hit_n", 0))

## Takes up a new hit if there is one and steps the spring; then rot, shove, wide and tall are the pose.
func update(root: Node3D, dt: float) -> void:
	var n := count(root)
	if n != _n:
		_n = n
		_start(root)
	var left := minf(dt, 0.1)
	while left > 0.0:
		var step := minf(left, 1.0 / 120.0)
		left -= step
		_v += (-_x * _omega * _omega - 2.0 * DAMPING * _omega * _v) * step
		_x += _v * step
	_pose()

func _start(root: Node3D) -> void:
	var cur := absf(_amp * _x)
	_amp = maxf(float(root.get_meta(&"hit_k", K_MIN)), cur)
	_x = 1.0
	_v = 0.0
	var m := float(root.get_meta(&"hit_mass", 1.0))
	var heft := clampf((m - MASS_LIGHT) / (MASS_HEAVY - MASS_LIGHT), 0.0, 1.0)
	_omega = OMEGA_PER_S / lerpf(SETTLE_LIGHT, SETTLE_HEAVY, heft)
	var local := root.global_basis.inverse() * (root.get_meta(&"hit_push", Vector3.ZERO) as Vector3)
	push = Vector2(local.x, local.z).normalized() if Vector2(local.x, local.z).length() > 0.01 else Vector2.ZERO

func _pose() -> void:
	var p: Dictionary = PLAN.get(plan, PLAN["blob"])
	var s := _amp * _x
	rot = Vector3(s * float(p["pitch"]) * push.y, s * float(p["yaw"]) * push.x, -s * float(p["roll"]) * push.x)
	shove = Vector3(push.x * float(p["shove"]), float(p["lift"]), push.y * float(p["shove"])) * s
	tall = 1.0 - s * float(p["squash"])
	wide = 1.0 + s * float(p["squash"]) * 0.5
