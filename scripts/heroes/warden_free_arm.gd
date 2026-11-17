class_name WardenFreeArm
extends RefCounted
## The arm a move does not use hangs relaxed (docs/art/ANIM_QUALITY_AUDIT.md: T-poses). Data "free_arm": {clip: "L"|"R"}
## names the arm that stays loose while that clip plays; {clip: {"L": 0.0, "R": 0.1}} lets each arm go from that clip
## time (seconds), so a weapon arm hangs again after its strike key. Upper arm, forearm and hand ease to their rotation
## in the idle clip (or in the clip the data "free_pose" names, when the idle holds the arm out) over whatever the clips
## key.

const BONES := ["upper_arm.", "forearm.", "hand."]
const RATE := 10.0           # 1/s: the arm eases to the loose pose and back

var skel: Skeleton3D
var clips := {}              # clip -> "L" | "R" | {side: seconds from which it is loose}
var pose := {}               # side -> [[bone index, idle rotation]]
var w := {"L": 0.0, "R": 0.0}  # per side: how loose the arm is, 0..1

func _init(sk: Skeleton3D, lib: AnimationLibrary, rest: String, loose: Dictionary) -> void:
	skel = sk
	clips = loose
	if loose.is_empty() or not lib.has_animation(rest):
		clips = {}
		return
	var a := lib.get_animation(rest)
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

## After tree.advance. `clip`: the move that is playing ("" when none), `t`: its time in seconds.
func apply(dt: float, clip: String, t: float) -> void:
	if clips.is_empty():
		return
	var spec: Variant = clips.get(clip, "")
	for side in pose:
		var loose: bool = side in spec if spec is String else spec.has(side) and t >= float(spec[side])
		w[side] = move_toward(w[side], 1.0 if loose else 0.0, RATE * dt)
		if w[side] <= 0.0:
			continue
		for b in pose[side]:
			skel.set_bone_pose_rotation(b[0], skel.get_bone_pose_rotation(b[0]).slerp(b[1], w[side]))
