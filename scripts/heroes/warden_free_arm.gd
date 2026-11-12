class_name WardenFreeArm
extends RefCounted
## The arm a move does not use hangs relaxed (docs/art/ANIM_QUALITY_AUDIT.md: T-poses). Data "free_arm": {clip: "L"|"R"}
## names the arm that stays loose while that clip plays; {clip: {"L": 0.0, "R": 0.1}} lets each arm go from that clip
## time (seconds), so a weapon arm hangs again after its strike key. Upper arm, forearm and hand ease to their rotation
## in the idle clip (or in the clip the data "free_pose" names, when the idle holds the arm out) over whatever the clips
## key.
## Data "arm_fade": {clip: {side: seconds}} eases that arm out of what it showed into the clip over those seconds while
## the rest of the upper body takes the move's own "fade": the free arm leaves a wide run swing without a pop while the
## casting arm still snaps (Sparkle's lmb_l). The arm holds the pose of the frame before and slerps to the clips.

const BONES := ["upper_arm.", "forearm.", "hand."]
const RATE := 10.0           # 1/s: the arm eases to the loose pose and back

var skel: Skeleton3D
var clips := {}              # clip -> "L" | "R" | {side: seconds from which it is loose}
var pose := {}               # side -> [[bone index, idle rotation]]
var w := {"L": 0.0, "R": 0.0}  # per side: how loose the arm is, 0..1
var fades := {}              # "arm_fade": clip -> {side: s the arm takes to ease into it}
var shown := {}              # side -> [rotation per pose bone]: the arm as last shown
var held := {}               # side -> the same, frozen the frame before the fading clip began
var fade_clip := ""          # the clip the held pose eases into
var fade_t := 0.0            # s since it began

func _init(sk: Skeleton3D, lib: AnimationLibrary, rest: String, loose: Dictionary, fade: Dictionary) -> void:
	skel = sk
	clips = loose
	fades = fade
	if (loose.is_empty() and fade.is_empty()) or not lib.has_animation(rest):
		clips = {}
		fades = {}
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
	_loosen(dt, clip, t)
	_ease_in(dt, clip)

func _loosen(dt: float, clip: String, t: float) -> void:
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

## The "arm_fade" arm: from the pose shown before the clip began to the clips' own, smoothstepped over its seconds.
func _ease_in(dt: float, clip: String) -> void:
	if fades.is_empty():
		return
	fade_t += dt
	if clip != fade_clip:
		fade_clip = clip
		fade_t = 0.0
		held = shown.duplicate()
	var spec: Dictionary = fades.get(clip, {})
	for side in pose:
		var bones: Array = pose[side]
		var k := smoothstep(0.0, float(spec.get(side, 0.0)), fade_t) if spec.has(side) and held.has(side) else 1.0
		var now: Array = []
		for i in bones.size():
			var q := skel.get_bone_pose_rotation(bones[i][0])
			if k < 1.0:
				q = (held[side][i] as Quaternion).slerp(q, k)
				skel.set_bone_pose_rotation(bones[i][0], q)
			now.append(q)
		shown[side] = now
