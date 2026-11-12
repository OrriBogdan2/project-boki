class_name WardenBeats
extends RefCounted
## A Hero's three result beats (win, lose, board), played by the results card and the skiff deck: the state key "beat"
## names one, "beat_t" is the seconds since it began. The data is the Hero's content/rules/warden_anim/<art>.json
## "beats": {name: {"clip": an existing clip, "loop_from": s} or {"pose": {bone: [pitch, yaw, roll] degrees}}}, and
## "upper": false to give the body to the clip (legs too). A pose is keyed here, from the rig's own rest, into a short
## clip that eases in and then breathes: the Hero keeps his legs (a lose beat over the crouch layer stays crouched).

const NAMES := ["win", "lose", "board"]
const INTRO := 0.45      # s: from the rest into the pose
const BREATH := 2.0      # s: one slow breath, looped for as long as the beat lasts
const BREATH_PITCH := 1.6  # degrees: the hips tip forward and the head back on the out-breath
const BONES := ["hips", "head", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R"]

## The beats of this Hero that the .glb can play: {name: {clip, loop_from, upper}}. Poses are keyed into `lib`.
static func build(lib: AnimationLibrary, skel: Skeleton3D, glb: Node3D, beats: Dictionary) -> Dictionary:
	var out := {}
	for nm in beats:
		var b: Dictionary = beats[nm]
		var clip := String(b.get("clip", ""))
		if b.has("pose"):
			clip = "beat_" + String(nm)
			if lib.has_animation(clip):
				lib.remove_animation(clip)     # (the library is the .glb's, shared by every model of it)
			lib.add_animation(clip, _pose_clip(skel, glb, b["pose"]))
		if clip != "" and lib.has_animation(clip):
			var from := float(b.get("loop_from", INTRO if b.has("pose") else 0.0))
			out[nm] = {"clip": clip, "loop_from": from, "upper": bool(b.get("upper", b.has("pose")))}
	return out

## Where in the clip a beat that began `t` seconds ago stands: it plays once, then loops from "loop_from".
static func time_of(length: float, from: float, t: float) -> float:
	if t < length or length - from < 0.05:
		return minf(t, length - 0.001)
	return from + fmod(t - from, length - from)

static func _pose_clip(skel: Skeleton3D, glb: Node3D, pose: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = INTRO + BREATH
	var path := String(glb.get_path_to(skel))
	for bone in BONES:
		var bi := WardenSkeleton.find(skel, bone)
		if bi < 0:
			continue
		var rest := skel.get_bone_rest(bi).basis.get_rotation_quaternion()
		var deg := _vec(pose.get(bone, [0, 0, 0]))
		var held := rest * Quaternion.from_euler(deg * (PI / 180.0))
		var out_breath := deg
		if bone == "hips":
			out_breath.x += BREATH_PITCH
		elif bone == "head":
			out_breath.x -= BREATH_PITCH
		var breath := rest * Quaternion.from_euler(out_breath * (PI / 180.0))
		var i := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(i, NodePath("%s:%s" % [path, skel.get_bone_name(bi)]))
		a.rotation_track_insert_key(i, 0.0, rest)
		a.rotation_track_insert_key(i, INTRO, held)
		a.rotation_track_insert_key(i, INTRO + BREATH * 0.5, breath)
		a.rotation_track_insert_key(i, INTRO + BREATH, held)
	return a

static func _vec(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2]))
