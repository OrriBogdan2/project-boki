extends RefCounted
## --step-sync-check: a Hero's footsteps sound when his feet plant, on every walk and run loop of the ring (forward,
## back, the sides, the diagonals: the directional loops of tools/art1/hunter_dir_gait.py) and through a blend
## between two neighbours (scripts/heroes/warden_steps.gd). Per Hero with clips and feet, rows:
##  - per loop, the clip: its plant frames read off the clip itself (each ankle posed at every game frame of it, a
##    touchdown into the lowest PLANT_BAND of its height range after it rose past LIFT_BAND), the feet alternate,
##    and the data "loco.plants" sits within one frame of them;
##  - per loop, played through the game's own ring at its point: every step lands within one game frame after a
##    plant of the same foot, and the steps count the plants (one at most off, where the counted laps start and end);
##  - per pair of neighbouring run loops, the blend halfway: the feet alternate and the steps count the plants (no
##    double step at a blend, no missing step on a strafe).
## Run: godot --headless -- --step-sync-check [--wardens=archer,dolm] [--plants-json=<file>: the plants read].

const DT := 1.0 / 60.0        # s: one game frame
const WARM_LOOPS := 2         # loops played before counting (the blend position settles)
const COUNT_LOOPS := 3        # loops counted
const NO_FEET := ["ostra"]    # Motley hovers on his box: no feet, no steps (KMovesStone.HOVER_GAIT)
const PLANT_BAND := 0.3       # x a foot's height range over its low: under this it is planted (tools/anim_audit.gd)
const LIFT_BAND := 0.6        # x: over this it has lifted

var bad := 0
var rows := 0
var holder: Node3D
var read := {}                # art -> clip -> {foot: [s]}: the plants read off the clips (--plants-json)

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var ids: Array = Arch.ORDER.duplicate()
	var json := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--plants-json="): json = a.substr(14)
	for id in ids:
		if not id in NO_FEET:
			await _hero(main, String(id))
	if json != "":
		FileAccess.open(json, FileAccess.WRITE).store_string(JSON.stringify(read, "\t"))
	print("STEP_SYNC_DONE rows %d FAIL %d" % [rows, bad])
	main.get_tree().quit(1 if bad > 0 or rows == 0 else 0)

func ok(cond: bool, msg: String) -> void:
	rows += 1
	if not cond:
		bad += 1
	print(("ok   " if cond else "FAIL ") + msg)

func _hero(main: Node, id: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	for k in 5:
		await main.get_tree().process_frame
	var sync := m.get_node_or_null("Warden/Sync")
	var clips: WardenClips = sync.get("clips") if sync else null
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	if clips == null or WardenSkeleton.find(sk, "shin.L") < 0:
		print("skip %s: no clips with feet" % id)
		m.free()
		return
	sync.set_process(false)
	var bs: AnimationNodeBlendSpace2D = (clips.tree.tree_root as AnimationNodeBlendTree).get_node("loco")
	var ring := []         # [point index, clip, position]
	for i in bs.get_blend_point_count():
		var at := bs.get_blend_point_position(i)
		if at.length() > 0.01:
			ring.append([i, String((bs.get_blend_point_node(i) as AnimationNodeAnimation).animation), at])
	var plants := {}       # clip -> {foot: [s into the clip]}
	var data: Dictionary = clips.d["loco"].get("plants", {})
	for p in ring:
		plants[p[1]] = _plants(sync, clips, sk, String(p[1]))
		_clip_row(id, String(p[1]), plants[p[1]], data.get(p[1], {}))
	read[WardenGlb.art(id)] = plants
	for p in ring:
		_loop_row(id, m, sync, clips, p, plants[p[1]])
	var runs := ring.filter(func(p): return (p[2] as Vector2).length() > 0.9)
	runs.sort_custom(func(a, b): return (a[2] as Vector2).angle() < (b[2] as Vector2).angle())
	for i in runs.size():
		_blend_row(id, m, sync, clips, runs[i], runs[(i + 1) % runs.size()], plants)
	m.free()

## Where each foot plants in `clip` (s), read off the clip: posed at every game frame of it, a touchdown is the
## first frame in the lowest PLANT_BAND of the foot's height range after it rose past LIFT_BAND.
func _plants(sync: Node, clips: WardenClips, sk: Skeleton3D, clip: String) -> Dictionary:
	var length := clips.lib.get_animation(clip).length
	var n := maxi(int(round(length / DT)), 2)
	var ys := [[], []]
	clips.force = {"clip": clip, "t": 0.0}
	for k in 6:
		sync.call("_process", DT)
	for k in n:
		clips.force = {"clip": clip, "t": length * k / n}
		sync.call("_process", DT)
		for f in 2:
			ys[f].append(_ankle(sk, "LR"[f]))
	clips.force = {}
	var out := {}
	for f in 2:
		var lo: float = ys[f].min()
		var span: float = ys[f].max() - lo
		var times := []
		var down := true
		for k in 2 * n:          # (twice round: the first lap only finds where the foot is)
			var y: float = ys[f][k % n]
			if down and y > lo + LIFT_BAND * span:
				down = false
			elif not down and y < lo + PLANT_BAND * span:
				down = true
				if k >= n:
					times.append(snappedf(length * (k - n) / n, 0.001))
		out["LR"[f]] = times
	return _stance_plants(out)

## A foot that dips twice with no plant of the other between taps first: the later dip, which the stance follows,
## is its plant.
func _stance_plants(pl: Dictionary) -> Dictionary:
	var feet := []
	for foot in ["L", "R"]:
		for t in pl[foot]:
			feet.append([t, foot])
	feet.sort()
	var out := {"L": [], "R": []}
	for i in feet.size():
		if feet[i][1] != feet[(i + 1) % feet.size()][1] or feet.size() == 1:
			out[feet[i][1]].append(feet[i][0])
	return out

## The ankle's height (m): the shin's end, a leg's length down it (as tools/anim_audit.gd; Kael has no foot bone).
func _ankle(sk: Skeleton3D, foot: String) -> float:
	var shin := WardenSkeleton.find(sk, "shin." + foot)
	var thigh := WardenSkeleton.find(sk, "thigh." + foot)
	var leg := (sk.get_bone_global_rest(shin).origin - sk.get_bone_global_rest(thigh).origin).length()
	var gs := sk.get_bone_global_pose(shin)
	return (sk.global_transform * (gs.origin + gs.basis.y.normalized() * leg)).y

## The clip's plants: the feet alternate, and the data's sit within one frame of them.
func _clip_row(id: String, clip: String, pl: Dictionary, data: Dictionary) -> void:
	var feet := []
	for foot in ["L", "R"]:
		for t in pl[foot]:
			feet.append([t, foot])
	feet.sort()
	var alternate: bool = not feet.is_empty() and pl["L"].size() == pl["R"].size()
	for i in feet.size():
		alternate = alternate and feet[i][1] != feet[(i + 1) % feet.size()][1]
	var worst := 0.0
	var same: bool = data.get("L", []).size() == pl["L"].size() and data.get("R", []).size() == pl["R"].size()
	for foot in ["L", "R"]:
		for i in mini(pl[foot].size(), data.get(foot, []).size()):
			worst = maxf(worst, absf(float(data[foot][i]) - float(pl[foot][i])) / DT)
	var msg := "%-10s %-8s clip plants L %s R %s, data %s: feet alternate %s, data %.2f frames off" % [
			id, clip, _ts(pl["L"]), _ts(pl["R"]), JSON.stringify(data), alternate, worst]
	ok(alternate and same and worst <= 1.0, msg)

## Plays the ring at `at` (a point's place, or between two) as the game does and logs each step: [foot, s into the
## loop at ring point `pi` (`clip`), the rate it plays at].
func _play(m: Node3D, sync: Node, clips: WardenClips, at: Vector2, pi: int, clip: String) -> Array:
	var lc: Dictionary = clips.d["loco"]
	var spd := at.length() * float(lc.get("run_speed", 4.6))
	var dir := at.normalized()
	m.set_meta(WardenClips.STATE, {"vel": Vector3(dir.x, 0, -dir.y) * spd, "face": 0.0, "grounded": true})
	clips.loco_pos = at
	var length := clips.lib.get_animation(clip).length
	var rate := clips.gait.plan(spd, lc)
	for k in int(WARM_LOOPS * length / rate / DT):
		sync.call("_process", DT)
	var heard := []
	for k in int(COUNT_LOOPS * length / rate / DT):
		var n: int = clips.steps.count
		sync.call("_process", DT)
		var t: float = clips.tree.get("parameters/loco/%d/current_position" % pi)
		if clips.steps.count > n:
			heard.append([clips.steps.side, t, float(clips.tree.get("parameters/loco_rate/scale"))])
	m.set_meta(WardenClips.STATE, {})
	return heard

func _loop_row(id: String, m: Node3D, sync: Node, clips: WardenClips, p: Array, pl: Dictionary) -> void:
	var length := clips.lib.get_animation(String(p[1])).length
	var heard := _play(m, sync, clips, p[2], p[0], String(p[1]))
	var worst := 0.0
	var off := 0
	for st in heard:
		var near := INF
		for t in pl[st[0]]:
			var d := absf(float(st[1]) - float(t))
			near = minf(near, minf(d, length - d))
		var frames := near / (DT * float(st[2]))
		worst = maxf(worst, frames)
		if frames > 1.0:
			off += 1
	var want: int = COUNT_LOOPS * (pl["L"].size() + pl["R"].size())
	var msg := "%-10s %-8s plants L %s R %s: %d steps for %d plants, worst %.2f frames off" % [
			id, p[1], _ts(pl["L"]), _ts(pl["R"]), heard.size(), want, worst]
	ok(off == 0 and want > 0 and absf(heard.size() - want) <= 1, msg)

func _blend_row(id: String, m: Node3D, sync: Node, clips: WardenClips, a: Array, b: Array, plants: Dictionary) -> void:
	var per_loop: int = plants[a[1]]["L"].size() + plants[a[1]]["R"].size()
	var heard := _play(m, sync, clips, ((a[2] as Vector2) + (b[2] as Vector2)) * 0.5, a[0], String(a[1]))
	var gap := INF          # the fewest steps from one step of a foot to its next (2: the feet alternate)
	var last := {}
	var k := 0
	for st in heard:
		k += 1
		if last.has(st[0]):
			gap = minf(gap, float(k - int(last[st[0]])))
		last[st[0]] = k
	var want: int = COUNT_LOOPS * per_loop
	var msg := "%-10s %s+%s blend: %d steps for %d plants (feet alternate: %s)" % [
			id, a[1], b[1], heard.size(), want, "yes" if gap >= 2.0 else "no"]
	ok(per_loop > 0 and absf(heard.size() - want) <= 1 and gap >= 2.0, msg)

func _ts(a: Array) -> String:
	return "[" + ", ".join(a.map(func(t): return "%.3f" % t)) + "]"
