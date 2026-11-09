class_name WardenTurn
extends RefCounted
## A Hunter turning on the spot re-plants the feet. The body follows the aim at Hunter.FACE_TURN (facing, casts and
## hit direction are the sim's and are never touched here); the feet stay where they were. Once the hips trail the
## aim by more than TRIGGER, one foot lifts and the legs swing round to meet the body (one step per STEP_MAX, so
## 180 degrees takes two). Bones only, on top of whatever stance clip is playing, so each Hunter keeps its own
## idle or stance pose between the steps. Heavier Hunters step slower and lower.

const TRIGGER := 1.57        # rad the hips may trail the aim before the feet step (about 90 degrees)
const STEP_MAX := 1.75       # rad one step turns the feet through
const STEP_MORE := 0.35      # rad: still this far behind when a step ends, another follows
const SETTLE := 4.0          # 1/s: a small leftover twist unwinds
const UNWIND := 12.0         # 1/s: the feet come round when he moves or acts
const KNEE := 2.0            # knee fold per unit of thigh lift
## Per weight class: s one step lasts, rad the thigh swings forward at the top of it.
const CLASS := {
	"light": {"t": 0.12, "lift": 0.55},
	"medium": {"t": 0.15, "lift": 0.45},
	"heavy": {"t": 0.22, "lift": 0.3},
}

var trail := 0.0             # rad the feet are turned off the body (negative of what the body has turned since)
var step_t := -1.0           # s into the step on now, -1 none
var step_amt := 0.0          # rad this step takes out of the trail
var side := 1                # which foot lifts: 1 left, -1 right
var face_prev := NAN
var t_step: float
var lift: float
var skel: Skeleton3D
var root_bi: int
var hips_bi: int
var thigh: Array = []        # [bone, shin bone, knee axis in the thigh's frame] per foot, left then right

func _init(sk: Skeleton3D, weight: String) -> void:
	skel = sk
	var cls: Dictionary = CLASS.get(weight, CLASS["medium"])
	t_step = float(cls["t"])
	lift = float(cls["lift"])
	root_bi = WardenSkeleton.find(sk, "root")
	hips_bi = WardenSkeleton.find(sk, "hips")
	for sd in ["L", "R"]:
		var ti := WardenSkeleton.find(sk, "thigh." + sd)
		thigh.append([ti, WardenSkeleton.find(sk, "shin." + sd), sk.get_bone_rest(ti).basis.inverse() * Vector3.RIGHT])

## Once a frame, after the clips: `standing` is a Hunter on the ground with no walk or full-body move over the legs.
func apply(face: float, standing: bool, dt: float) -> void:
	var dface := 0.0 if is_nan(face_prev) else wrapf(face - face_prev, -PI, PI)
	face_prev = face
	if not standing:
		step_t = -1.0
		trail = lerpf(trail, 0.0, 1.0 - exp(-UNWIND * dt))
	else:
		trail = wrapf(trail - dface, -PI, PI)
		_step(dt)
	var up := 0.0 if step_t < 0.0 else sin(clampf(step_t / t_step, 0.0, 1.0) * PI)
	if absf(trail) < 0.002 and up <= 0.0:
		return
	var was := skel.get_bone_pose_rotation(root_bi)
	var turn := Quaternion(Vector3.UP, trail)
	skel.set_bone_pose_rotation(root_bi, turn * was)
	skel.set_bone_pose_rotation(hips_bi, was.inverse() * turn.inverse() * was * skel.get_bone_pose_rotation(hips_bi))
	if up > 0.0:
		var f: Array = thigh[0 if side > 0 else 1]
		var a := up * lift
		skel.set_bone_pose_rotation(f[0], Quaternion(Vector3.RIGHT, a) * skel.get_bone_pose_rotation(f[0]))
		skel.set_bone_pose_rotation(f[1], Quaternion(f[2], -a * KNEE) * skel.get_bone_pose_rotation(f[1]))

func _step(dt: float) -> void:
	if step_t < 0.0:
		if absf(trail) > TRIGGER:
			_begin(false)
		else:
			if absf(trail) < STEP_MORE:
				trail = lerpf(trail, 0.0, 1.0 - exp(-SETTLE * dt))
			return
	var p0 := smoothstep(0.0, 1.0, step_t / t_step)
	step_t += dt
	var p1 := smoothstep(0.0, 1.0, step_t / t_step)
	trail -= step_amt * (p1 - p0)
	if step_t >= t_step:
		step_t = -1.0
		if absf(trail) > STEP_MORE:
			_begin(true)

## A step of its own take-out of the trail; the next one in a row lifts the other foot.
func _begin(chained: bool) -> void:
	step_t = 0.0
	step_amt = clampf(trail, -STEP_MAX, STEP_MAX)
	if chained:
		side = -side
	else:
		side = 1 if trail > 0.0 else -1
