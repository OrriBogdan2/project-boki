class_name WardenFreeArm
extends RefCounted
## The arm a move does not use hangs relaxed (docs/art/ANIM_QUALITY_AUDIT.md: T-poses). Data "free_arm": {clip: "L"|"R"}
## names the arm that stays loose while that clip plays; its upper arm, forearm and hand ease to their idle rotation
## (sampled once from the idle clip) over whatever the clips key. The weapon arm is never touched.

const BONES := ["upper_arm.", "forearm.", "hand."]
const RATE := 10.0           # 1/s: the arm eases to the loose pose and back

var skel: Skeleton3D
var clips := {}              # clip -> side
var pose := {}               # side -> [[bone index, idle rotation]]
var w := 0.0
var side := ""

func _init(sk: Skeleton3D, lib: AnimationLibrary, idle: String, loose: Dictionary) -> void:
	skel = sk
	clips = loose
	if loose.is_empty() or not lib.has_animation(idle):
		clips = {}
		return
	var a := lib.get_animation(idle)
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(a.track_get_path(i).get_concatenated_subnames())
		for b in BONES:
			if bone.begins_with(b) and bone.length() == b.length() + 1:
				var s := bone.substr(b.length())
				if not pose.has(s):
					pose[s] = []
				pose[s].append([skel.find_bone(bone), a.rotation_track_interpolate(i, 0.0)])

## After tree.advance. `clip`: the move that is playing ("" when none).
func apply(dt: float, clip: String) -> void:
	if clips.is_empty():
		return
	if clips.has(clip):
		side = String(clips[clip])
	w = move_toward(w, 1.0 if clips.has(clip) else 0.0, RATE * dt)
	if w <= 0.0 or not pose.has(side):
		return
	for b in pose[side]:
		skel.set_bone_pose_rotation(b[0], skel.get_bone_pose_rotation(b[0]).slerp(b[1], w))
