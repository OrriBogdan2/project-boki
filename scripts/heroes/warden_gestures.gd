class_name WardenGestures
extends RefCounted
## The emote wheel's short body gestures (warden_anim/emote_gestures.json): keyed here, from the rig's own rest, into
## clips named "g_<gesture>" in the Hero's animation library. A Hero's warden_anim "emotes" map names the clip each
## wheel emote plays: one of these, or a clip of its own .glb (Kael's roar, Sable's flourish). The gestures only key
## the upper body, so WardenClips plays them on the upper layer and the legs keep walking or standing.

const FILE := "res://content/rules/warden_anim/emote_gestures.json"
const PREFIX := "g_"
static var _defs := {}

static func defs() -> Dictionary:
	if _defs.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		_defs = (parsed as Dictionary).get("gestures", {}) if typeof(parsed) == TYPE_DICTIONARY else {}
	return _defs

## Keys the gestures `clips` name (the "g_" ones) into `lib`; the library is the .glb's, shared by every model of it.
static func add(lib: AnimationLibrary, skel: Skeleton3D, glb: Node3D, clips: Array) -> void:
	for c in clips:
		var clip := String(c)
		if clip.begins_with(PREFIX) and not lib.has_animation(clip) and defs().has(clip.substr(PREFIX.length())):
			lib.add_animation(clip, _clip(skel, glb, defs()[clip.substr(PREFIX.length())]))

static func _clip(skel: Skeleton3D, glb: Node3D, g: Dictionary) -> Animation:
	var a := Animation.new()
	var dur := float(g["len"])
	a.length = dur
	var bones := {}
	for k in g["keys"]:
		for bone in k[1]:
			bones[bone] = true
	for bone in bones:
		var bi := WardenSkeleton.find(skel, String(bone))
		if bi < 0:
			continue
		var rest := skel.get_bone_rest(bi).basis.get_rotation_quaternion()
		var i := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(i, NodePath("%s:%s" % [glb.get_path_to(skel), skel.get_bone_name(bi)]))
		a.rotation_track_insert_key(i, 0.0, rest)
		for k in g["keys"]:
			var deg: Array = k[1].get(bone, [0, 0, 0])
			var turn := Quaternion.from_euler(Vector3(deg[0], deg[1], deg[2]) * (PI / 180.0))
			a.rotation_track_insert_key(i, float(k[0]), rest * turn)
		a.rotation_track_insert_key(i, dur, rest)
	return a
