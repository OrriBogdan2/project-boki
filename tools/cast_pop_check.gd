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
## Second pass (POPDEG lines, every Hunter with clips unless ids are given): the whole bone rotation per frame at
## 60 fps through the four hand-overs a pop shows in, driven on the live AnimationTree by the state the game feeds it:
## jump-land (a hop and a drop, standing and running), glide-exit-to-run (the glide's and the dive's touchdown into
## the run), dash-end (his dash move's last frame into the run) and cast-end (every keyed move's end, standing and
## running). Fails any bone turning more than DEG_MAX deg between two frames. Fix: blend times in
## warden_anim/<art>.json (kmoves fade_out, land hop/drop fade, air fade_out).

const DT := 1.0 / 30.0
const GAP_M := 0.08  # m: a point may sit this far between the poses under the default 0.1 s blend
const RATE := GAP_M / WardenClips.FADE  # m/s: how fast a blend may carry a point across its gap
const IN_MAX := 0.3  # s: a blend-in no longer than this, or the move never lands
const OUT_MAX := 0.4  # s: a blend back to the legs no longer than this
const WALK_FRAMES := 40  # frames of walk sampled (over a stride cycle)
const STAND_FRAMES := 60  # frames of idle sampled (a breath), and of the rest stance
const STANCE_WAIT := 210  # frames standing still before the rest stance is fully on (loco stance_after + fade)
const SETTLE := 14  # frames a forced clip takes to own the body (longest fade and crossfade)
## The Hunters slice this pass tuned; --cast-pop-check=<ids> checks others.
const SLICE := ["archer", "juggernaut", "gunslinger", "ashwick"]
## Moves whose clip hands back to the legs as the kit's movement hold lifts (tools/vex_anim_time_check.gd E row):
## a longer blend-out would keep the legs in the clip after she may walk, so theirs stays at FADE_LOCO. (Her R holds
## nothing since the owner's 11-17 playtest: its clip is upper body over walking legs.)
const HOLD_BOUND := ["gunslinger_e"]
## A blend-in this short is a deliberate snap (hem.json: the release shows in full; `--clip-check` asserts it
## over within 0.05 s of the spawn), so the gap does not ask it longer.
const SNAP_FADE := 0.04
## (a blend-in may fall this far short of its gap: Kael's meteor landing keeps 0.05 s,
## which --slam-follow-check pins its impact frame to)
const IN_SLACK := 0.025
const DT60 := 1.0 / 60.0
const DEG_MAX := 25.0  # deg: no bone turns more than this between two frames at 60 fps (a hand-over pop)
const DEG_WARM := 90  # frames in the starting pose before a hand-over is driven (a stance settles)
const DEG_AFTER := 45  # frames watched after the hand-over (0.75 s: past the longest blend, 0.4 s)
## Bone prefixes of the springs, extras and the spinning barrel: no blend of a clip.
const SECONDARY := ["spring_", "x_", "gatling"]
const FLOOR_K := 1.25  # a bone's frame counts as a pop beyond this times its fastest steady frame
const PRE_WATCH := 30  # frames before a hand-over: a bone already turning that fast is no pop
const PHASES := [0, 3, 7]  # frames of the starting pose added to each of the three drives of a hand-over
## Hunters whose clip data a blend time cannot reach (art lane), and the worst turn each still has at this commit: the
## limit for them is this ceiling, so a change that makes it worse fails (LAND_BLEND_POPS.md has why).
const KNOWN := {"bulwark": 60.0, "dolm": 36.0, "ostra": 35.0}
const RUN_MPS := 4.6  # m/s: a run
## Each Hunter's dash move whose last frame hands over to the run (the kit move the dash plays last).
const DASH_END := {
	"archer": "pin_roll",
	"juggernaut": "jug_dash",
	"gunslinger": "gunslinger_dash",
	"bulwark": "bul_whirl",
	"rimewright": "tm_skate_stop",
	"ashwick": "as_leap",
	"dolm": "breah_leap_land",
	"mage": "mage_dash_land",
	"dredge": "dr_lunge_out",
	"tender": "mm_skip",
	"thief": "thf_vault_r",
	"ostra": "ostra_swap"
}
const WARM := 45  # frames before sampling: the gait and sway settled

var bad := 0
var holder: Node3D
var subject: Node3D  # the model the second pass drives
var only_move := ""  # --pop-move=<kit move id>: the cast-end of that move only (a fix at a time)
var floors: Array = []  # deg per bone: its fastest frame in the steady idle and run
var peaks: Array = []


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
		if a.begins_with("--pop-move="):
			only_move = a.substr(11)
	for id in Arch.ids():
		var art_name := WardenGlb.art(String(id))
		var dd := WardenClips.data(art_name)
		if not only.is_empty() and not String(id) in only:
			continue
		if not dd.has("loco"):
			print("POPDEG %s: no clips (procedural rig), n/a" % id)
			continue
		if String(id) in SLICE or not only.is_empty():
			await _hero(String(id), dd)
		_degrees(String(id), dd)
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
		# ("blend_out" hands the body back to the legs while the clip plays on:
		# it covers the out gap as a fade_out does)
		var fade_out := maxf(float(mv.get("fade_out", WardenClips.FADE_LOCO)), float(mv.get("blend_out", 0.0)))
		var gaps: Array = []  # [stand in, stand out, walk in, walk out], each [m, point]
		var full_up: bool = up is bool and up  # ("moving": upper only while he walks)
		for mode in [[stand, full_up], [walk, full_up or up is String]]:
			var first: Dictionary = await _forced(sync, sk, probe, clips, clip, 0.0, mode[1])
			var last: Dictionary = await _forced(sync, sk, probe, clips, clip, length - 0.001, mode[1])
			gaps.append(_gap(first, mode[0], mode[1]))
			gaps.append(_gap(last, mode[0], mode[1]))
		var in_cap := minf(IN_MAX, _first_key(String(km), length))
		var need_in := minf(maxf(gaps[0][0], gaps[2][0]) / RATE, in_cap)
		var out_cap := WardenClips.FADE_LOCO if km in HOLD_BOUND else OUT_MAX
		var need_out := minf(maxf(gaps[1][0], gaps[3][0]) / RATE, out_cap)
		print(
			(
				"POP %s %s | %.3f %s / %.3f %s | %.3f %s / %.3f %s | %.2f / %.2f -> %.2f / %.2f"
				% [
					id,
					km,
					gaps[0][0],
					gaps[0][1],
					gaps[1][0],
					gaps[1][1],
					gaps[2][0],
					gaps[2][1],
					gaps[3][0],
					gaps[3][1],
					fade_in,
					fade_out,
					need_in,
					need_out
				]
			)
		)
		if (fade_in < need_in - IN_SLACK and fade_in > SNAP_FADE) or fade_out < need_out - 0.005:
			short.append("%s fade %.2f/%.2f" % [km, maxf(need_in, fade_in), maxf(need_out, fade_out)])
	ok(
		short.is_empty(),
		(
			"%s: every move's blend is as long as its cast gap asks, inside its first key and the caps " % id
			+ "(short: %s)" % str(short)
		)
	)
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
func _forced(
	sync: Node, sk: Skeleton3D, probe: Dictionary, clips: WardenClips, clip: String, t: float, upper: bool
) -> Dictionary:
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


## --- Second pass: the bone rotation per frame at 60 fps through the hand-overs ---


func _rots(sk: Skeleton3D) -> Array:
	var out: Array = []
	for i in sk.get_bone_count():
		out.append(sk.get_bone_pose_rotation(i))
	return out


## `states` fed one a frame (60 fps) from a standing start, each bone's turn between frames from frame `from` on: one
## PackedFloat32Array per frame, a bone's turn where it is a hand-over pop candidate, else 0. A bone's own steady
## turn (`floors`: its fastest frame in the idle and the run, which some arms and legs key a swing a frame) is no
## pop; only a frame past FLOOR_K times it counts, as does one past FLOOR_K times its fastest frame in the PRE_WATCH
## frames before `from` (a spinning barrel), and a bone whose own steady frame is past DEG_MAX (a seam in the run or
## the idle: listed as "seams" per Hunter) has no limit to judge a hand-over by. `peaks` takes every bone's fastest
## frame watched, to set the floors from.
func _pops(sk: Skeleton3D, sync: Node, states: Array, from: int) -> Array:
	var out: Array = []
	var before := _rep_f(sk.get_bone_count())
	var prev := _rots(sk)
	if peaks.size() != prev.size():
		peaks = _rep_f(prev.size())
		floors = _rep_f(prev.size())
	for i in states.size():
		subject.set_meta(WardenClips.STATE, states[i])
		sync.call("_process", DT60)
		var cur := _rots(sk)
		var row := PackedFloat32Array()
		row.resize(cur.size())
		for b in cur.size():
			var deg := rad_to_deg((cur[b] as Quaternion).angle_to(prev[b]))
			if i < from:
				if i >= from - PRE_WATCH:
					before[b] = maxf(before[b], deg)
			elif not _secondary(sk.get_bone_name(b)):
				peaks[b] = maxf(peaks[b], deg)
				if deg > maxf(floors[b], before[b]) * FLOOR_K and floors[b] <= DEG_MAX:
					row[b] = deg
		if i >= from:
			out.append(row)
		prev = cur
	return out


## The worst hand-over pop over the transition driven three times, the run's phase moved on between them (PHASES
## frames more of the starting pose): a seam in the run cycle lands on other frames each time, a pop of the hand-over
## on the same one, so a bone's turn counts as the least of the three. [deg, bone, frame - from].
func _turn(sk: Skeleton3D, sync: Node, states: Array, from: int) -> Array:
	var runs: Array = []
	for off in PHASES:
		runs.append(_pops(sk, sync, _rep(states[0], off) + states, from + off))
	var worst := [0.0, "-", 0]
	for f in (runs[0] as Array).size():
		for b in (runs[0][f] as PackedFloat32Array).size():
			var deg := minf(minf(runs[0][f][b], runs[1][f][b]), runs[2][f][b])
			if deg > worst[0]:
				worst = [deg, sk.get_bone_name(b), f]
	return worst


static func _st(vy: float, spd: float, extra := {}) -> Dictionary:
	var s := {"vel": Vector3(0, vy, -spd), "face": 0.0, "grounded": vy == 0.0}
	s.merge(extra, true)
	return s


static func _rep_f(n: int) -> Array:
	var out: Array = []
	out.resize(n)
	out.fill(0.0)
	return out


static func _rep(s: Dictionary, n: int) -> Array:
	var out: Array = []
	for k in n:
		out.append(s)
	return out


## A fall of 20 frames at `vy`, then the ground: the touchdown's turn (watched from 2 frames before it).
func _land(sk: Skeleton3D, sync: Node, spd: float, vy: float, glide: bool) -> Array:
	var seq := _rep(_st(0.0, spd), DEG_WARM) + _rep(_st(vy, spd, {"gliding": glide}), 20)
	return _turn(sk, sync, seq + _rep(_st(0.0, spd), DEG_AFTER), DEG_WARM + 18)


## The kit move `km` played to its end at `spd`, then the legs: the turn from 2 frames before it ends.
func _cast_end(sk: Skeleton3D, sync: Node, clips: WardenClips, km: String, spd: float) -> Array:
	var seq := _rep(_st(0.0, spd), DEG_WARM)
	for k in DEG_WARM:
		subject.set_meta(WardenClips.STATE, seq[k])
		sync.call("_process", DT60)
	var t := 0.0
	var end := -1
	for k in 180:  # (a held move loops: its end is a release at 1.2 s)
		var s := _st(0.0, spd, {"kmove": km, "kmove_t": t})
		subject.set_meta(WardenClips.STATE, s)
		sync.call("_process", DT60)
		seq.append(s)
		t += DT60
		if not clips.busy or t > 1.2:
			end = seq.size() - 1
			break
	if end < 0:
		return [0.0, "never ends", 0]
	return _turn(sk, sync, seq + _rep(_st(0.0, spd), DEG_AFTER), end - 2)


func _degrees(id: String, dd: Dictionary) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	subject = m
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	peaks = []
	_pops(sk, sync, _rep(_st(0.0, 0.0), DEG_WARM + 120), DEG_WARM)
	_pops(sk, sync, _rep(_st(0.0, RUN_MPS), DEG_WARM + 120), DEG_WARM)
	floors = peaks.duplicate()
	var land: Array = []
	for w in [[0.0, 6.0], [RUN_MPS, 6.0], [0.0, 10.0], [RUN_MPS, 10.0]]:
		var r: Array = _land(sk, sync, w[0], -w[1], false)
		var way := "hop" if w[1] < 8.0 else "drop"
		r.append("%s %s" % ["run" if w[0] > 0.0 else "stand", way])
		land.append(r)
	var glide: Array = [_land(sk, sync, RUN_MPS, -2.0, true), _land(sk, sync, RUN_MPS, -20.0, true)]
	glide[0].append("glide")
	glide[1].append("dive")
	var dash: Array = ["-"]
	var dm := String(DASH_END.get(id, ""))
	if dd.get("kmoves", {}).has(dm):
		dash = _cast_end(sk, sync, clips, dm, RUN_MPS)
		dash.append(dm)
	var cast: Array = [0.0, "-", 0, "-"]
	var cast_over: Array = []
	for km in dd.get("kmoves", {}):
		if not only_move.is_empty() and String(km) != only_move:
			continue
		for spd in [0.0, RUN_MPS]:
			var r: Array = _cast_end(sk, sync, clips, String(km), spd)
			if r[0] > cast[0]:
				cast = [r[0], r[1], r[2], "%s %s" % [km, "run" if spd > 0.0 else "stand"]]
			if r[0] > _limit(id):
				cast_over.append("%s %s %s %.0f" % [km, "run" if spd > 0.0 else "stand", r[1], r[0]])
	var row: Dictionary = {
		"jump-land": _worst(land), "glide-exit-to-run": _worst(glide), "dash-end": dash, "cast-end": cast
	}
	var over: Array = []
	var seams: Array = []
	for b in floors.size():
		if floors[b] > DEG_MAX:
			seams.append("%s %.0f" % [sk.get_bone_name(b), floors[b]])
	var line := "POPDEG %s | seams in the steady idle/run: %s" % [id, str(seams)]
	for k in row:
		var r: Array = row[k]
		if r.size() < 2:
			line += " | %s n/a" % k
			continue
		line += " | %s %.1f deg %s @%d (%s)" % [k, r[0], r[1], r[2], r[-1]]
		if r[0] > _limit(id):
			over.append("%s %s %.0f" % [k, r[-1], r[0]])
	print(line)
	print("POPDEG %s moves over: %s" % [id, str(cast_over)])
	ok(
		over.is_empty(),
		(
			(
				"%s: no bone turns over %.0f deg a frame at 60 fps through land, glide exit, dash end and "
				% [id, _limit(id)]
			)
			+ "cast end (over: %s)" % str(over)
		)
	)
	m.free()


static func _secondary(bone: String) -> bool:
	for pre in SECONDARY:
		if bone.begins_with(pre):
			return true
	return false


static func _limit(id: String) -> float:
	return maxf(DEG_MAX, float(KNOWN.get(id, 0.0)))


static func _worst(rows: Array) -> Array:
	var w: Array = rows[0]
	for r in rows:
		if r[0] > w[0]:
			w = r
	return w
