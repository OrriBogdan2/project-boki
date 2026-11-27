class_name WardenNativeTwist
extends RefCounted
## Strafing and back-pedalling on a native Hunter: Meshy has one forward run, so the legs turn to the way he goes while
## the torso stays on the aim (the contract path's "aim_twist", WardenClips._aim_twist), up to WardenClips.TWIST_MAX
## off the aim. Past BACK_FROM off the aim the legs stop turning and the run clip plays in reverse instead (`dir`
## goes from +1 to -1), turned only by what is left of the way to dead behind the aim.

const BACK_FROM := deg_to_rad(120.0)  # rad off the aim: the run clip goes into reverse beyond this
const BACK_HYST := deg_to_rad(10.0)  # rad: it reverses this far past BACK_FROM and forwards again this far inside it
const DIR_RATE := 12.0  # 1/s: how fast the clip's direction eases between forwards and reverse

var skel: Skeleton3D
var hips := -1  # Meshy's root bone: the legs turn with it
var torso := -1  # the bone the body above hangs from: it takes the turn back
var turn := 0.0  # rad the legs are turned off the aim now
var dir := 1.0  # the run clip's direction: +1 forwards, -1 in reverse (the caller signs the clip's rate with it)
var back := false  # moving more than BACK_FROM off the aim (with the hysteresis): the reverse run


## After the loop clips have posed the skeleton. `on`: the body is running on its legs (walk, run, crouch walk).
func step(dt: float, s: Dictionary, on: bool) -> void:
	var goal := 0.0
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	if on and Vector2(vel.x, vel.z).length() >= WardenClips.STILL:
		var rel := wrapf(atan2(-vel.x, -vel.z) - float(s.get("face", 0.0)), -PI, PI)
		var edge := BACK_FROM - BACK_HYST if back else BACK_FROM + BACK_HYST
		back = absf(rel) > edge
		# (rel - PI wraps to 0 at dead behind from either side: exactly -PI would pick a side at random)
		goal = wrapf(rel - PI, -PI, PI) if back else clampf(rel, -WardenClips.TWIST_MAX, WardenClips.TWIST_MAX)
	else:
		back = false
	turn = lerpf(turn, goal, 1.0 - exp(-dt * WardenClips.HEADING_RATE))
	dir = lerpf(dir, -1.0 if back else 1.0, 1.0 - exp(-dt * DIR_RATE))
	if hips < 0 or torso < 0 or absf(turn) < 0.002:
		return
	# (the torso keeps its posed world turn: the spine bones between bend with the run, so undoing the turn in the
	# hips' own frame would tip the chest at a wide strafe)
	var held := skel.get_bone_global_pose(torso).basis.get_rotation_quaternion()
	skel.set_bone_pose_rotation(hips, Quaternion(Vector3.UP, turn) * skel.get_bone_pose_rotation(hips))
	var up := skel.get_bone_global_pose(skel.get_bone_parent(torso)).basis.get_rotation_quaternion()
	skel.set_bone_pose_rotation(torso, up.inverse() * held)
