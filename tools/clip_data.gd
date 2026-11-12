extends RefCounted
## What --clip-check and --warden-clips-check assert about a Hero's clips, read off the data
## (content/rules/warden_anim/<art>.json): the clips it names, the moves it maps and their hold windows. The .glb has to
## match that data and meet a few invariants; no clip name, length or key of another branch is written into a check.

const LEN_MIN := 0.1       # s: a clip shorter than this is a stray key, not an animation
const LEN_MAX := 12.0      # s: and one longer than this is a take left in by mistake
const MOVE_SLACK := 0.034  # s: a clip may differ from its kit move's last key by this much (one frame at 30 fps)
const START_T := 0.001     # s: a clip's tracks all begin at 0.0
const SEAM_DEG := 1.0      # a looping clip's last key may turn a bone this far from its first
const SEAM_M := 0.01       # and move it this far
const STAND_MIN := 2.0     # s: an idle or stance shorter than this reads as a jitter, not a breath
const MIN_MOVES := 2       # a name prefix shared by this many mapped moves is the Hero's own (bul_, jug_, as_)

## Standing loops docs/art/IDLE_AUDIT.md found open: "<id>:<clip>" -> what. Each idle rework removes its entries.
const STAND_OPEN := {
	"bulwark:idle": "head seam 4.2 deg (breathe() at half rate)",
	"bulwark:stance": "head seam 4.2 deg, 1.6 s long",
	"ostra:idle": "x_fing seams 11-13 deg",
	"ostra:stance": "x_fing seams 12-16 deg",
}

## Every clip the data names: moves (and their alternates), locomotion, crouch, air, the home verbs (act), land,
## weapon_out, the states.
static func named(dd: Dictionary) -> Array:
	var out: Array = []
	for mv in (dd.get("kmoves", {}) as Dictionary).values():
		out.append(mv["clip"])
		if mv.has("alt"):
			out.append(mv["alt"])
	var lc: Dictionary = dd.get("loco", {})
	out.append_array([lc.get("idle"), lc.get("stance")])
	out.append_array((lc.get("walk", {}) as Dictionary).values())
	out.append_array((lc.get("run", {}) as Dictionary).values())
	var cr: Dictionary = dd.get("crouch", {})
	if not cr.is_empty():
		out.append_array([cr["idle"], cr["in"], cr["out"]])
		out.append_array((cr["walk"] as Dictionary).values())
	out.append_array((dd.get("air", {}) as Dictionary).values())
	out.append_array((dd.get("act", {}) as Dictionary).values())
	for key in ["land", "weapon_out"]:
		if dd.has(key):
			out.append(dd[key]["clip"])
	for v in (dd.get("states", {}) as Dictionary).values():
		if v is String:
			out.append(v)
		elif v is Dictionary and v.has("front"):
			out.append_array([v["front"], v["back"]])
	return out.filter(func(c): return c is String)      # (the data's air block also holds tilt numbers)

## The standing loops the data names (held to a seam and a length).
static func loops(dd: Dictionary) -> Array:
	var lc: Dictionary = dd.get("loco", {})
	return [lc.get("idle"), lc.get("stance")]

## The kit moves (any table) that start with a prefix the data's own moves share, and that the data does not map.
static func unmapped(dd: Dictionary) -> Array:
	var moves: Dictionary = dd.get("kmoves", {})
	var count := {}
	for km in moves:
		var p := String(km).get_slice("_", 0) + "_"
		count[p] = int(count.get(p, 0)) + 1
	var out: Array = []
	for table in [HunterAnim.KMOVES, KMovesPinBjorn.MOVES, KMovesDJ.MOVES]:
		for km in table:
			if int(count.get(String(km).get_slice("_", 0) + "_", 0)) >= MIN_MOVES and not moves.has(km):
				out.append(km)
	return out

## The invariants, as [bool, text] rows: no missing clip; each clip in the length bounds and keyed from 0.0; every
## mapped move's clip as long as the kit's move (a held one at least that long); the standing loops closed.
## A loop in STAND_OPEN is reported, never failing.
static func rows(id: String, dd: Dictionary, lib: AnimationLibrary) -> Array:
	var out: Array = []
	var names := named(dd)
	var missing: Array = names.filter(func(c): return not lib.has_animation(String(c)))
	out.append([missing.is_empty(),
			"%s: the data's %d clips are in the .glb (missing %s)" % [id, names.size(), str(missing)]])
	var odd: Array = []
	for nm in names:
		if lib.has_animation(String(nm)):
			odd.append_array(_clip_faults(String(nm), lib.get_animation(String(nm))))
	out.append([odd.is_empty(),
			"%s: every clip is %.1f to %.0f s long and keyed from 0.0 (%s)" % [id, LEN_MIN, LEN_MAX, str(odd)]])
	var off := _move_faults(dd, lib)
	out.append([off.is_empty(), "%s: each move's clip fits its kit move and hold window (%s)" % [id, str(off)]])
	var gaps := unmapped(dd)
	out.append([gaps.is_empty(), "%s: all its kit moves have a clip (missing %s)" % [id, str(gaps)]])
	for clip in loops(dd):
		if clip != null and lib.has_animation(String(clip)):
			out.append_array(_loop_rows(id, String(clip), lib.get_animation(String(clip))))
	return out

## The home verbs (data "act"): the Hero plays the verb's own clip, seeked to the verb's clock, and the clip lasts as
## long as the verb (HunterVerbs.LENGTH).
static func act_rows(id: String, dd: Dictionary, clips: WardenClips) -> Array:
	var out: Array = []
	var off := 0.0
	for verb in dd.get("act", {}):
		var clip := String(dd["act"][verb])
		var pick := clips._pick({"act": verb, "act_t": 0.4}, 0.0)
		out.append([pick.get("clip") == clip and is_equal_approx(float(pick.get("t", -1.0)), 0.4),
				"%s: the home %s plays its own clip, seeked to the verb's clock" % [id, verb]])
		if clips.lib.has_animation(clip):
			off = maxf(off, absf(clips.lib.get_animation(clip).length - float(HunterVerbs.LENGTH[verb])))
	if not dd.get("act", {}).is_empty():
		out.append([off <= MOVE_SLACK, "%s: its garden clips last as long as the home verbs (off %.3f s)" % [id, off]])
	return out

static func _clip_faults(nm: String, an: Animation) -> Array:
	var out: Array = []
	if an.length < LEN_MIN or an.length > LEN_MAX:
		out.append("%s %.2f s" % [nm, an.length])
	for t in an.get_track_count():
		if an.track_get_key_count(t) > 0 and an.track_get_key_time(t, 0) > START_T:
			var bone := String(an.track_get_path(t).get_concatenated_subnames())
			out.append("%s:%s starts at %.3f" % [nm, bone, an.track_get_key_time(t, 0)])
			break
	return out

## A move's clip lasts as long as the kit's move; a held move's clip (it loops from "hold_from" while the key is held)
## at least to the kit's last key, and the window starts inside the file.
static func _move_faults(dd: Dictionary, lib: AnimationLibrary) -> Array:
	var out: Array = []
	var moves: Dictionary = dd.get("kmoves", {})
	for km in moves:
		var mv: Dictionary = moves[km]
		if not lib.has_animation(String(mv["clip"])):
			continue
		var length := lib.get_animation(String(mv["clip"])).length
		if float(mv.get("hold_from", 0.0)) < 0.0:
			out.append("%s hold from %.2f" % [km, float(mv["hold_from"])])
		var def := HunterAnim.km_def(String(km))
		if def.is_empty():
			continue
		var end_t := float((def["keys"][-1] as Array)[0])
		var off := maxf(end_t - length, 0.0) if mv.has("hold_from") else absf(length - end_t)
		if off > MOVE_SLACK:
			out.append("%s clip %.3f s, keys %.3f s" % [km, length, end_t])
	return out

## A standing loop's last key meets its first on every track, and it is long enough to carry a breath.
static func _loop_rows(id: String, clip: String, an: Animation) -> Array:
	var worst := 0.0
	var where := ""
	for t in an.get_track_count():
		var n := an.track_get_key_count(t)
		if n < 2 or an.track_get_key_time(t, n - 1) < an.length - 0.001:
			continue
		var gap := 0.0
		match an.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				var q0: Quaternion = an.track_get_key_value(t, 0)
				gap = rad_to_deg(q0.angle_to(an.track_get_key_value(t, n - 1))) / SEAM_DEG
			Animation.TYPE_POSITION_3D:
				var p0: Vector3 = an.track_get_key_value(t, 0)
				gap = p0.distance_to(an.track_get_key_value(t, n - 1)) / SEAM_M
		if gap > worst:
			worst = gap
			where = String(an.track_get_path(t)).get_slice(":", 1)
	var good := worst <= 1.0 and an.length >= STAND_MIN
	var what := "%s: %s loop seam %.1fx the limit (worst %s), %.1f s long (min %.1f)" % [
			id, clip, worst, where if where != "" else "none", an.length, STAND_MIN]
	var key := "%s:%s" % [id, clip]
	if STAND_OPEN.has(key):
		print("CLIP open %s [%s]%s" % [what, STAND_OPEN[key], " (now passes: drop it from STAND_OPEN)" if good else ""])
		return []
	return [[good, what]]
