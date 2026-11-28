class_name KinFlinch
extends RefCounted
## How a Boki's body takes a hit, for KinPuppet (the primitive bodies) and BokiRig (the rigged ones).
## KinFlinch.hit() writes the meta "hit" on the kin's model root; each driver owns one KinFlinch,
## calls update() every frame, and adds rot, shove, wide and tall to Flex.
## The body snaps to the jolt at once (it has to read within 0.1 s), then springs back: how far
## scales with the hit and shrinks with mass, how long it takes grows with mass (light Boki snap
## back, heavy ones carry the hit). Each body plan jolts its own way (PLAN). A real hit also hops the Boki
## back a little (HOP_*), scaled by the same strength; pop() is the revive: a stretch and a lift that settle.

const SETTLE_LIGHT := 0.20     # s until the jolt is down to a quarter, for MASS_LIGHT
const SETTLE_HEAVY := 0.38     # s, for MASS_HEAVY
const MASS_LIGHT := 0.8        # KinSpec mass of the lightest Boki
const MASS_HEAVY := 2.0        # ...and of the heaviest
const DAMPING := 0.55          # spring damping ratio: one small overshoot
const OMEGA_PER_S := 1.75      # natural frequency (rad) times settle time (s) at that damping
const K_MIN := 0.5             # strength of a chip hit
const K_PER_FRAC := 4.0        # strength gained per share of max health a hit takes
const K_MAX := 1.3
const LAND_FRAC := 0.25        # the share of max health a landing jolts like (a squash, no shove: K_MAX)
const DASH_FRAC := 0.2         # the share of max health a dash start jolts like (the lean, K_MAX before mass)
const HOP_S := 0.28            # s a hit's hop-back lasts
const HOP_UP := 0.10           # m the hop lifts per unit of strength
const HOP_BACK := 0.06         # m the hop carries it away from the blow per unit of strength
const POP_K := 1.0             # strength of a revive pop (before mass)
const POP_LIFT := 0.18         # m a pop lifts at full strength
const POP_STRETCH := 0.25      # share a pop stretches it tall at full strength (the settle squashes it)
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
var _push := Vector2.ZERO      # which way the body is shoved, in Flex space (x right, y back)
var _hop := false              # this jolt is a hit that hops the body back
var _pop := false              # this jolt is a revive pop
var _hop_t := 0.0              # s into the hop

## A hit on a Boki: `push` is the way the hit shoves it (world), `frac` the share of its max health the hit took,
## `mass` its KinSpec mass.
static func hit(model: Node3D, push: Vector3, frac: float, mass: float) -> void:
	_jolt(model, {"k": clampf(K_MIN + frac * K_PER_FRAC, K_MIN, K_MAX), "push": push, "hop": true}, mass)

## A Boki touching down after a throw or a leap: the hit's spring with no push, so it only squashes.
static func land(model: Node3D, mass: float) -> void:
	_jolt(model, {"k": clampf(K_MIN + LAND_FRAC * K_PER_FRAC, K_MIN, K_MAX), "push": Vector3.ZERO}, mass)

## A downed Boki back on its feet: it pops up, stretched and lifted, then settles with a small squash.
static func pop(model: Node3D, mass: float) -> void:
	_jolt(model, {"k": POP_K, "push": Vector3.ZERO, "pop": true}, mass)

## A Boki setting off on a dash along `dir` (world): the hit's spring shoved the way it goes, so it leans into the
## move and settles at the end (the landing squash). Mass sizes it: light Boki lean more, heavy ones less.
static func dash(model: Node3D, dir: Vector3, mass: float) -> void:
	_jolt(model, {"k": clampf(K_MIN + DASH_FRAC * K_PER_FRAC, K_MIN, K_MAX), "push": dir}, mass)

static func _jolt(model: Node3D, jolt: Dictionary, mass: float) -> void:
	var cur: Dictionary = model.get_meta("hit", {"n": 0})
	jolt["k"] = float(jolt["k"]) / sqrt(maxf(mass, 0.1))
	jolt["n"] = int(cur["n"]) + 1
	jolt["mass"] = mass
	model.set_meta("hit", jolt)

## Takes up a new hit if there is one and steps the spring; then rot, shove, wide and tall are the pose.
func update(root: Node3D, dt: float) -> void:
	var h: Dictionary = root.get_meta("hit", {})
	if not h.is_empty() and int(h["n"]) != _n:
		_n = int(h["n"])
		_start(root, h)
	_hop_t += dt
	var left := minf(dt, 0.1)
	while left > 0.0:
		var step := minf(left, 1.0 / 120.0)
		left -= step
		_v += (-_x * _omega * _omega - 2.0 * DAMPING * _omega * _v) * step
		_x += _v * step
	_pose()

func _start(root: Node3D, h: Dictionary) -> void:
	var cur := absf(_amp * _x)
	_amp = maxf(float(h["k"]), cur)
	_x = 1.0
	_v = 0.0
	_hop = bool(h.get("hop", false))
	_pop = bool(h.get("pop", false))
	_hop_t = 0.0
	var m := float(h["mass"])
	var heft := clampf((m - MASS_LIGHT) / (MASS_HEAVY - MASS_LIGHT), 0.0, 1.0)
	_omega = OMEGA_PER_S / lerpf(SETTLE_LIGHT, SETTLE_HEAVY, heft)
	var local := root.global_basis.inverse() * (h["push"] as Vector3)
	_push = Vector2(local.x, local.z).normalized() if Vector2(local.x, local.z).length() > 0.01 else Vector2.ZERO

func _pose() -> void:
	var s := _amp * _x
	if _pop:
		rot = Vector3.ZERO
		shove = Vector3(0.0, POP_LIFT * s, 0.0)
		tall = 1.0 + s * POP_STRETCH
		wide = 1.0 - s * POP_STRETCH * 0.5
		return
	var p: Dictionary = PLAN.get(plan, PLAN["blob"])
	rot = Vector3(s * float(p["pitch"]) * _push.y, s * float(p["yaw"]) * _push.x, -s * float(p["roll"]) * _push.x)
	shove = Vector3(_push.x * float(p["shove"]), float(p["lift"]), _push.y * float(p["shove"])) * s
	tall = 1.0 - s * float(p["squash"])
	wide = 1.0 + s * float(p["squash"]) * 0.5
	if _hop and _hop_t < HOP_S:
		var arc := sin(PI * _hop_t / HOP_S) * _amp
		shove += Vector3(_push.x * HOP_BACK * arc, HOP_UP * arc, _push.y * HOP_BACK * arc)
