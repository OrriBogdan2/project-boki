extends RefCounted
## --cast-pop-check[=<id>,<id>]: PRIORITIES area 4 (blends and gaps). For every keyed move of a Hero with clips,
## standing and walking: how far each hand, each foot and the weapon tip sit between the locomotion pose and the
## clip's first frame (the gap the blend-in crosses) and between its last frame and the locomotion pose he comes
## back to (the blend-out). The clip is forced at full weight; the walk is sampled over a stride, the idle over a
## breath, and the worst phase counts. An upper-body move leaves the legs on the walk, so its feet are not counted.
## A gap over GAP_M needs a blend long enough to cross it at RATE or slower (warden_anim kmoves "fade" in,
## "fade_out" back), unless the move cannot wait: a blend-in ends by the kit move's first key (the strike pose
## lands on its beat) and never runs past IN_MAX, a blend-out past OUT_MAX. Standing covers the idle and the
## rest stance he settles into. Prints the rows docs/heroes/<id>.md carry (POP lines). Never touches the save.

const DT := 1.0 / 30.0
const GAP_M := 0.08             # m: a point may sit this far between the poses under the default 0.1 s blend
const RATE := GAP_M / WardenClips.FADE      # m/s: how fast a blend may carry a point across its gap
const IN_MAX := 0.3             # s: a blend-in no longer than this, or the move never lands
const OUT_MAX := 0.4            # s: a blend back to the legs no longer than this
const WALK_FRAMES := 40         # frames of walk sampled (over a stride cycle)
const STAND_FRAMES := 60        # frames of idle sampled (a breath), and of the rest stance
const STANCE_WAIT := 210        # frames standing still before the rest stance is fully on (loco stance_after + fade)
const SETTLE := 14              # frames a forced clip takes to own the body (longest fade and crossfade)
const WARM := 45                # frames before sampling: the gait and sway settled

var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("POP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cast-pop-check="):
			only = Array(a.substr(17).split(",", false))
	for id in Arch.ids():
		var art_name := WardenGlb.art(String(id))
		var dd := WardenClips.data(art_name)
		if not dd.has("loco") or (not only.is_empty() and not String(id) in only):
			continue
		await _hero(String(id), dd)
	print("CAST_POP_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hero(id: String, dd: Dictionary) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var probe := _probe(sk, sync)
	var stand: Array = await _loco(m, sync, sk, probe, 0.0, STAND_FRAMES, WARM)
	stand.append_array(await _loco(m, sync, sk, probe, 0.0, STAND_FRAMES, STANCE_WAIT))
	var walk: Array = await _loco(m, sync, sk, probe, float(dd["loco"].get("walk_speed", 2.2)), WALK_FRAMES, WARM)
	print("POP %s: move | stand in / out | walk in / out (m, worst point) | fade in / out now -> needed" % id)
	var short: Array = []
	var moves: Dictionary = dd.get("kmoves", {})
	for km in moves:
		var mv: Dictionary = moves[km]
		var clip := String(mv["clip"])
		var length := clips.lib.get_animation(clip).length
		var up = mv.get("upper", false)
		var fade_in := float(mv.get("fade", WardenClips.FADE))
		var fade_out := float(mv.get("fade_out", WardenClips.FADE_LOCO))
		var gaps: Array = []     # [stand in, stand out, walk in, walk out], each [m, point]
		var full_up: bool = up is bool and up        # ("moving": upper only while he walks)
		for mode in [[stand, full_up], [walk, full_up or up is String]]:
			var first: Dictionary = await _forced(sync, sk, probe, clips, clip, 0.0, mode[1])
			var last: Dictionary = await _forced(sync, sk, probe, clips, clip, length - 0.001, mode[1])
			gaps.append(_gap(first, mode[0], mode[1]))
			gaps.append(_gap(last, mode[0], mode[1]))
		var in_cap := minf(IN_MAX, _first_key(String(km), length))
		var need_in := minf(maxf(gaps[0][0], gaps[2][0]) / RATE, in_cap)
		var need_out := minf(maxf(gaps[1][0], gaps[3][0]) / RATE, OUT_MAX)
		print("POP %s %s | %.3f %s / %.3f %s | %.3f %s / %.3f %s | %.2f / %.2f -> %.2f / %.2f" % [id, km,
				gaps[0][0], gaps[0][1], gaps[1][0], gaps[1][1], gaps[2][0], gaps[2][1], gaps[3][0], gaps[3][1],
				fade_in, fade_out, need_in, need_out])
		if fade_in < need_in - 0.005 or fade_out < need_out - 0.005:
			short.append("%s fade %.2f/%.2f" % [km, maxf(need_in, fade_in), maxf(need_out, fade_out)])
	ok(short.is_empty(), "%s: every move's blend is as long as its cast gap asks, inside its first key and the caps "
			% id + "(short: %s)" % str(short))
	m.free()

## The points watched: both hands, both feet (a body with no foot bone: the shin's far end) and the weapon tip, each
## a bone and an offset on it.
func _probe(sk: Skeleton3D, sync: Node) -> Dictionary:
	var out := {}
	for side in ["L", "R"]:
		out["hand." + side] = [WardenSkeleton.find(sk, "hand." + side), Vector3.ZERO]
		var foot := WardenSkeleton.find(sk, "foot." + side)
		if foot >= 0:
			out["foot." + side] = [foot, Vector3.ZERO]
			continue
		var shin := WardenSkeleton.find(sk, "shin." + side)
		var thigh := WardenSkeleton.find(sk, "thigh." + side)
		var shin_m := sk.get_bone_global_rest(thigh).origin.distance_to(sk.get_bone_global_rest(shin).origin)
		var rest := sk.get_bone_global_rest(shin)
		var down := Vector3(0, shin_m, 0)
		if (rest * down).y > rest.origin.y:
			down = -down
		out["foot." + side] = [shin, down]
	var tip := sync.get("blade_tip") as Node3D
	if tip != null:
		out["weapon"] = [int(sync.get("blade_bone")), tip.position]
	return out

func _points(sk: Skeleton3D, probe: Dictionary) -> Dictionary:
	var out := {}
	for nm in probe:
		var bi := int(probe[nm][0])
		out[nm] = sk.global_transform * (sk.get_bone_global_pose(bi) * (probe[nm][1] as Vector3))
	return out

## The kit move's first beat (s): the time of its first keyed pose after the start, else the clip's length.
func _first_key(km: String, length: float) -> float:
	for key in HunterAnim.km_def(km).get("keys", []):
		if float(key[0]) > 0.0 and not (key[1] as Dictionary).is_empty():
			return float(key[0])
	return length

## The locomotion at `speed` m/s (0: standing), the points sampled every frame for `frames` after `warm` frames.
func _loco(m: Node3D, sync: Node, sk: Skeleton3D, probe: Dictionary, speed: float, frames: int, warm: int) -> Array:
	(sync.get("clips") as WardenClips).force = {}
	var s := {"vel": Vector3(0, 0, -speed), "face": 0.0, "grounded": true}
	m.set_meta(WardenClips.STATE, s)
	for k in warm:
		sync.call("_process", DT)
	var out: Array = []
	for k in frames:
		sync.call("_process", DT)
		await holder.get_tree().process_frame
		out.append(_points(sk, probe))
	return out

## The clip forced at `t` until it owns the body (an upper move: the arms; the legs keep the locomotion fed last).
func _forced(sync: Node, sk: Skeleton3D, probe: Dictionary, clips: WardenClips, clip: String, t: float,
		upper: bool) -> Dictionary:
	clips.force = {"clip": clip, "t": t, "upper": upper}
	for k in SETTLE:
		sync.call("_process", DT)
	await holder.get_tree().process_frame
	clips.force = {}
	return _points(sk, probe)

## The worst point: how far it sits from where the locomotion has it, over every sampled phase.
func _gap(pose: Dictionary, loco: Array, upper: bool) -> Array:
	var worst := 0.0
	var where := "-"
	for nm in pose:
		if upper and String(nm).begins_with("foot"):
			continue
		var far := 0.0
		for frame in loco:
			far = maxf(far, (pose[nm] as Vector3).distance_to(frame[nm]))
		if far > worst:
			worst = far
			where = String(nm)
	return [worst, where]
