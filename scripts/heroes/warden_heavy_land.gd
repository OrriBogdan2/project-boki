class_name WardenHeavyLand
extends RefCounted
## A long drop lands heavier than a terrace drop on a Hero with hand-keyed clips. The "land" clip is one crouch for
## every drop from 2.5 m up; this deepens it with the fall: the root bone's pose (how far down the body sits, how
## far it leans) is pushed past the clip's by the Hero's "heavy" "deep" x HunterAnim.heavy_k (0 under a 6 m fall,
## 0.6 at 6 m, 1 for a dive's plunge). It rides the clip's own crouch, so it begins and ends with it and never holds
## the body longer: the control is the terrace drop's (a landing locks no input). Runs after the clips each frame.

const FADE_OUT := 0.3  # share of the hold the push eases off over, so the clip's recovery is not cut short

var clips: WardenClips
var skel: Skeleton3D
var bone := -1
var push := 0.0  # how far past the clip's crouch the pose is pushed now (x the clip's own, 0 = none)


static func make(c: WardenClips, sk: Skeleton3D) -> WardenHeavyLand:
	var h := WardenHeavyLand.new()
	h.clips = c
	h.skel = sk
	h.bone = WardenSkeleton.find(sk, "root")
	return h


func step() -> void:
	push = 0.0
	if bone < 0 or clips.heavy_k <= 0.0 or clips.land_t >= clips.land_hold:
		return
	var u := clips.land_t / maxf(clips.land_hold, 0.001)
	push = clips.heavy_deep * clips.heavy_k * minf(1.0, (1.0 - u) / FADE_OUT)
	var rest := skel.get_bone_rest(bone)
	var pose := skel.get_bone_pose(bone)
	var amp := 1.0 + push
	skel.set_bone_pose_position(bone, rest.origin + (pose.origin - rest.origin) * amp)
	var q0 := rest.basis.get_rotation_quaternion()
	skel.set_bone_pose_rotation(bone, q0.slerp(pose.basis.get_rotation_quaternion(), amp))
