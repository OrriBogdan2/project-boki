class_name WardenNativeUpper
extends RefCounted
## A swing, cast or shot on a native Hunter's upper body while the legs keep running (the contract path's "upper"
## layer, WardenClips): the clip is sampled on the bones from the torso up (Meshy's Spine02 and all below it: spine,
## neck, head, arms) and eased over the pose the loop clips just gave, so a run is not frozen into the attack clip.
## Standing still the clip owns the whole body as before (WardenNative._process decides).

const FADE_IN := 0.1  # s: the layer over the legs' run
const FADE_OUT := 0.16  # s: back to the loop clip's torso and arms

var skel: Skeleton3D
var bones := {}  # bone name -> true: the torso and everything above it
var clip: Animation  # the clip on the upper body (null: none yet)
var t := 0.0  # s into it
var rate := 1.0  # its play rate
var on := false  # the clip still plays
var w := 0.0  # 0..1: how much of the upper body it owns
var _tracks := {}  # Animation -> [[track index, bone index]] of its rotation tracks on the upper bones


## The layer for `sk`, its upper body rooted at bone `torso` (-1: none, the layer stays off).
static func make(sk: Skeleton3D, torso: int) -> WardenNativeUpper:
	var up := WardenNativeUpper.new()
	up.skel = sk
	up._collect(torso)
	return up


## Starts `anim` from its first frame at `speed` times its pace.
func play(anim: Animation, speed: float) -> void:
	clip = anim
	t = 0.0
	rate = speed
	on = not bones.is_empty()


## Lets go of the upper body (the clip's pose eases out).
func stop() -> void:
	on = false


## After the loop clips have posed the skeleton: lays the clip over the upper bones.
func lay(dt: float) -> void:
	if clip == null:
		return
	if on:
		t += dt * rate
		on = t < clip.length
	var fade := FADE_IN if on else FADE_OUT
	w = move_toward(w, 1.0 if on else 0.0, dt / fade)
	if w <= 0.0:
		return
	for trk in tracks():
		var bi: int = trk[1]
		var q := clip.rotation_track_interpolate(trk[0], minf(t, clip.length))
		skel.set_bone_pose_rotation(bi, skel.get_bone_pose_rotation(bi).slerp(q, w))


## [track index, bone index] of the clip's rotation tracks on the upper bones.
func tracks() -> Array:
	if not _tracks.has(clip):
		var found := []
		for ti in clip.get_track_count():
			var bi := skel.find_bone(String(clip.track_get_path(ti).get_concatenated_subnames()))
			if clip.track_get_type(ti) == Animation.TYPE_ROTATION_3D and bi >= 0 and bones.has(skel.get_bone_name(bi)):
				found.append([ti, bi])
		_tracks[clip] = found
	return _tracks[clip]


## Bone `b` and every bone below it into `bones`.
func _collect(b: int) -> void:
	if b < 0:
		return
	bones[skel.get_bone_name(b)] = true
	for c in skel.get_bone_children(b):
		_collect(c)
