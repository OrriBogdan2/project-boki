class_name WardenNativeTwist
extends RefCounted
## Strafing and back-pedalling on a native Hunter: Meshy has one forward run, so the legs turn to the way he goes while
## the torso stays on the aim (the contract path's "aim_twist", WardenClips._aim_twist), up to WardenClips.TWIST_MAX
## off the aim. Past it the legs turn round to face away from the way he goes and the loop clip plays backwards
## (`back`: WardenNative flips its rate), so a back-pedal steps backwards and the torso never twists past the limit.

var skel: Skeleton3D
var hips := -1  # Meshy's root bone: the legs turn with it
var torso := -1  # the bone the body above hangs from: it takes the turn back
var turn := 0.0  # rad the legs are turned off the aim now
var back := false  # going more than the limit off the aim: the legs face away from the way and run backwards


## After the loop clips have posed the skeleton. `on`: the body is running on its legs (walk, run, crouch walk).
func step(dt: float, s: Dictionary, on: bool) -> void:
	var goal := 0.0
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	if on and Vector2(vel.x, vel.z).length() >= WardenClips.STILL:
		var rel := wrapf(atan2(-vel.x, -vel.z) - float(s.get("face", 0.0)), -PI, PI)
		# (the contract's hysteresis: past the limit he turns round, back under PI - limit he turns forward again)
		back = absf(rel) > (PI - WardenClips.TWIST_MAX if back else WardenClips.TWIST_MAX)
		goal = rel - signf(rel) * PI if back else rel
	else:
		back = false
	turn = lerpf(turn, goal, 1.0 - exp(-dt * WardenClips.HEADING_RATE))
	if hips < 0 or torso < 0 or absf(turn) < 0.002:
		return
	var was := skel.get_bone_pose_rotation(hips)
	skel.set_bone_pose_rotation(hips, Quaternion(Vector3.UP, turn) * was)
	var back := was.inverse() * Quaternion(Vector3.UP, -turn) * was
	skel.set_bone_pose_rotation(torso, back * skel.get_bone_pose_rotation(torso))
