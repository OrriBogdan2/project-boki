class_name WardenGlidePose
extends RefCounted
## The glide and glider-dive clips of a Hunter on Meshy's skeleton (docs/art/wardens/MESHY_NATIVE.md), built once per
## model from one shared pose (content/rules/warden_glide.json): each named bone is turned so it points the
## data's way in the body's frame, read off this skeleton's own rest (left from the right hip to the left, up from the
## hips to the head, forward their cross: the toes' way), so the same pose fits every Meshy body. Every track Meshy's
## idle clip keys is keyed (the rest for the unnamed bones), so no other clip's pose is left on a bone.

const DATA_PATH := "res://content/rules/warden_glide.json"
const CLIP := "%s_pose"  # the clip's name in the library: glide_pose, dive_pose
const SAMPLES := 8  # keys per loop (the sway is a sine; the clip interpolates between them)
const LIB := &"warden_glide"  # the poses' library on the player
static var _data = null
static var _libs := {}  # Meshy idle clip -> the poses' library built for its skeleton


## Gives `player` the poses' clips in a library of their own (LIB), built once per Meshy clip set (`like`: its idle
## clip, whose tracks they key) and shared by every model of the .glb; returns slot -> clip name for WardenNative's
## plays. (The .glb's own library stays as loaded, and this one is whole before any player takes it.)
static func add(player: AnimationPlayer, skel: Skeleton3D, like: Animation) -> Dictionary:
	var lib: AnimationLibrary = _libs.get(like)
	if lib == null:
		lib = AnimationLibrary.new()
		var poses: Dictionary = data().get("poses", {})
		for slot in poses:
			lib.add_animation(CLIP % slot, clip(skel, like, poses[slot]))
		_libs[like] = lib
	if not player.has_animation_library(LIB):
		player.add_animation_library(LIB, lib)
	var out := {}
	for nm in lib.get_animation_list():
		out[String(nm).trim_suffix("_pose")] = "%s/%s" % [LIB, nm]
	return out


static func data() -> Dictionary:
	if _data == null:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _data


## The looping clip of `pose` on `skel`, with the bone tracks of `like` (rotations solved, positions at rest).
static func clip(skel: Skeleton3D, like: Animation, pose: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = float(pose.get("length", 1.0))
	anim.loop_mode = Animation.LOOP_LINEAR
	var rot := {}  # track -> its bone
	for ti in like.get_track_count():
		var tt := like.track_get_type(ti)
		var b := skel.find_bone(String(like.track_get_path(ti).get_concatenated_subnames()))
		if b < 0 or tt not in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]:
			continue
		var nt := anim.add_track(tt)
		anim.track_set_path(nt, like.track_get_path(ti))
		if tt == Animation.TYPE_POSITION_3D:
			anim.position_track_insert_key(nt, 0.0, skel.get_bone_rest(b).origin)
		else:
			rot[nt] = b
	var body := frame(skel)
	for i in SAMPLES + 1:
		var ph := TAU * float(i) / float(SAMPLES)
		var locals := solve(
			skel, body, _mirrored(pose.get("bones", {}), pose.get("sway", {}), ph), pose.get("tilt", {})
		)
		for nt in rot:
			anim.rotation_track_insert_key(nt, anim.length * float(i) / float(SAMPLES), locals[rot[nt]])
	return anim


## The body's frame on the rest skeleton: x its left, y up, z forward.
static func frame(skel: Skeleton3D) -> Basis:
	var at := func(nm: String) -> Vector3: return skel.get_bone_global_rest(skel.find_bone(nm)).origin
	var up: Vector3 = (at.call("Head") - at.call("Hips")).normalized()
	var left: Vector3 = at.call("LeftUpLeg") - at.call("RightUpLeg")
	left = (left - up * left.dot(up)).normalized()
	return Basis(left, up, left.cross(up))


## Each bone's local rotation with the named ones (bone -> body-frame Vector3) turned to point their way, and the
## tilt ones (bone -> deg) pitched about the body's left-right axis; the bones below them follow.
static func solve(skel: Skeleton3D, body: Basis, dirs: Dictionary, tilts: Dictionary) -> Array:
	var glob := []
	var out := []
	glob.resize(skel.get_bone_count())
	out.resize(skel.get_bone_count())
	var todo: Array = Array(skel.get_parentless_bones())
	while not todo.is_empty():  # (parents first: each bone's global turn is its parent's and its own)
		var b: int = todo.pop_front()
		todo.append_array(Array(skel.get_bone_children(b)))
		var par := skel.get_bone_parent(b)
		var pg: Basis = Basis.IDENTITY if par < 0 else glob[par]
		var g := pg * skel.get_bone_rest(b).basis.orthonormalized()
		var nm := skel.get_bone_name(b)
		if dirs.has(nm):
			var from: Vector3 = g * _child_dir(skel, b)
			g = Basis(Quaternion(from.normalized(), (body * (dirs[nm] as Vector3)).normalized())) * g
		if tilts.has(nm):
			g = Basis(body.x, deg_to_rad(float(tilts[nm]))) * g
		glob[b] = g
		out[b] = (pg.inverse() * g).get_rotation_quaternion()
	return out


## The bone's way to the mean of its children's heads, in its own frame.
static func _child_dir(skel: Skeleton3D, b: int) -> Vector3:
	var sum := Vector3.ZERO
	for c in skel.get_bone_children(b):
		sum += skel.get_bone_rest(c).origin
	return sum if sum.length() > 0.0001 else Vector3.UP


## The data's Left bones with their Right mirrors (x flipped), as Vector3s swung by their sway at phase `ph`.
static func _mirrored(bones: Dictionary, sway: Dictionary, ph: float) -> Dictionary:
	var out := {}
	for nm in bones:
		var v: Array = bones[nm]
		var dir := Vector3(v[0], v[1], v[2])
		if sway.has(nm):
			var sw: Array = sway[nm]
			dir = dir.rotated(Vector3.RIGHT, deg_to_rad(float(sw[0])) * sin(ph + float(sw[1])))
		out[nm] = dir
		if String(nm).begins_with("Left"):
			out[String(nm).replace("Left", "Right")] = Vector3(-dir.x, dir.y, dir.z)
	return out
