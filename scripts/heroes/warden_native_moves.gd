class_name WardenNativeMoves
extends RefCounted
## A native Hunter's own clips for the kit's moves (warden_native.json data "clip_files" and "kmoves"): clips-only
## .glb files written on Meshy's skeleton (tools/meshy/cinder_native_clips.py), played by the kit's own clock
## (state "kmove" and "kmove_t") so the pose lands on the frame the kit fires. A row {clip, then, hold, upper}: `clip`
## plays from the move's start; then `then` loops, or the last pose holds (`hold`), or the move is over. An `upper`
## row is a layer: its clip keys only the torso, head and arms and lies over whatever the legs play (walk, run, idle,
## the air), faded in and out; any other row is a full-body clip on the main player.

const FADE_IN := 0.08  # s: an upper clip's weight rises
const FADE_OUT := 0.2  # s: and falls when the move is over

var rows: Dictionary = {}  # kit move id -> its row
var anims: Dictionary = {}  # clip name -> Animation
var over: AnimationPlayer  # plays the upper clips (never advanced: seeked to the kit's clock)
var skel: Skeleton3D
var weight := 0.0
var shown := ""  # the upper clip last laid over the legs
var shown_t := 0.0  # and its time (it holds while the weight falls)
var keyed: Dictionary = {}  # upper clip -> its bones (indices)


## The moves of `d` for Meshy's skeleton `skel` under `glb`, whose main player is `player`; null when the data has none.
## Full-body clips join the main player's library, upper clips a second player beside it.
static func make(glb: Node3D, player: AnimationPlayer, skel_in: Skeleton3D, d: Dictionary) -> WardenNativeMoves:
	if not d.has("kmoves"):
		return null
	var mv := WardenNativeMoves.new()
	mv.rows = d["kmoves"]
	mv.skel = skel_in
	mv.anims = WardenClipFile.read(glb.get_path_to(skel_in), d.get("clip_files", []))
	var first := player.get_animation(player.get_animation_list()[0])
	var lib := player.get_animation_library(player.find_animation_library(first))
	mv.over = AnimationPlayer.new()
	mv.over.name = "Moves"
	mv.over.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var upper := AnimationLibrary.new()
	for row: Dictionary in mv.rows.values():
		for key in ["clip", "then"]:
			if row.has(key):
				var clip := String(row[key])
				var anim: Animation = mv.anims[clip]
				if key == "then":
					anim.loop_mode = Animation.LOOP_LINEAR
				var into := upper if bool(row.get("upper", false)) else lib
				if not into.has_animation(clip):
					into.add_animation(clip, anim)
	mv.over.add_animation_library(&"", upper)
	player.get_parent().add_child(mv.over)
	mv.over.root_node = player.root_node
	for clip in upper.get_animation_list():
		mv.keyed[clip] = mv._bones(upper.get_animation(clip))
	return mv


## Whether the kit's move `km` has a row (played out or not).
func has_row(km: String) -> bool:
	return rows.has(km)


## The clip `km` shows `kt` seconds into the move: {clip, t, upper}, or {} when it has no row or has played out.
func pick(km: String, kt: float) -> Dictionary:
	var row: Dictionary = rows.get(km, {})
	if row.is_empty():
		return {}
	var first := anims[String(row["clip"])] as Animation
	var up := bool(row.get("upper", false))
	if kt < first.length:
		return {"clip": row["clip"], "t": kt, "upper": up}
	if row.has("then"):
		var loop := anims[String(row["then"])] as Animation
		return {"clip": row["then"], "t": fposmod(kt - first.length, loop.length), "upper": up}
	if bool(row.get("hold", false)):
		return {"clip": row["clip"], "t": first.length, "upper": up}
	return {}


## Lays the upper clip of `pick` (or none: {}) over the pose the main player just set, at its weight.
func lay(mv: Dictionary, dt: float) -> void:
	var on := not mv.is_empty() and bool(mv["upper"])
	if on:
		shown = String(mv["clip"])
		shown_t = float(mv["t"])
	var fade := FADE_IN if on else FADE_OUT
	weight = move_toward(weight, float(on), dt / fade)
	if weight <= 0.0 or shown == "":
		return
	var bones: Array = keyed[shown]
	var base: Array = []
	for b: int in bones:
		base.append(skel.get_bone_pose_rotation(b))
	if over.current_animation != shown:
		over.play(shown)
	over.seek(shown_t, true)
	for i in bones.size():
		var b: int = bones[i]
		skel.set_bone_pose_rotation(b, (base[i] as Quaternion).slerp(skel.get_bone_pose_rotation(b), weight))


## The bones a clip keys (indices on the skeleton).
func _bones(anim: Animation) -> Array:
	var out: Array = []
	for t in anim.get_track_count():
		var b := skel.find_bone(anim.track_get_path(t).get_concatenated_subnames())
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D and b >= 0:
			out.append(b)
	return out
