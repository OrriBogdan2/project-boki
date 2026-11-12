extends RefCounted
## --step-sync-check: footsteps land on the plants (scripts/heroes/warden_steps.gd). For every Hunter with walk and
## run clips, and every one of those loops:
##   1. plants: the times in content/anim/warden_steps.json sit within one frame (FRAME) of the touchdowns
##      measured on the posed clip (a sole entering the lowest PLANT_BAND of its own height range, LIFT_BAND)
##   2. steps: moving along that loop's direction at its speed, through the game's own blend, every step fires
##      with that loop leading, within one update of one of its plants, and one step per plant passed
##   3. blends: half-way between two neighbouring loops, speeding up from walk to run, turning a full circle and
##      strafing left-right: no two steps closer than WardenSteps.GAP_MIN of the lead loop's shortest plant gap
##      (a double at a hand-off), none further apart than GAP_MAX of the longest plant gap of the loops that led
##      in between (a missed step; a walk loop leading for a moment steps at the walk's pace)
## --write: measure every loop and rewrite content/anim/warden_steps.json, then check.
## --wardens=a,b: only these Hunters. Never touches the save.

const FRAME := 1.0 / 60.0      # s: one frame
const SAMPLE_HZ := 240.0       # how finely a clip is posed for its plants
const PLANT_BAND := 0.2        # a sole is down in the lowest 20 % of its height range over the loop...
const LIFT_BAND := 0.5         # ...and only lands again after lifting past half of it (no double from a hover)
const DT := 1.0 / 60.0         # the update the game runs at
const POSE_DT := 1.0 / 30.0
const WARM_S := 1.0            # s on the loop before steps count (the blend settles)
const RUN_S := 3.0             # s of steps counted
const GAP_MAX := 1.75          # x the longest plant gap: a dropped step leaves a gap of 2; a hand-off between loops
                               # not in step (WardenSteps.CATCH_UP) stretches one to 1.5 and a little
const DIRS := {"f": Vector2(0, 1), "b": Vector2(0, -1), "l": Vector2(-1, 0), "r": Vector2(1, 0)}

var bad := 0
var rows := 0
var table := {}

func ok(cond: bool, what: String) -> void:
	rows += 1
	print("STEPSYNC %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var holder := Node3D.new()
	main.add_child(holder)
	var ids: Array = Arch.ORDER.duplicate()
	var write := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a == "--write": write = true
	if write:
		for id in ids:
			await _hero(main, holder, String(id), true)
		var f := FileAccess.open(WardenSteps.PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(table, "\t", true) + "\n")
		f.close()
		WardenSteps.table(true)
		print("STEPSYNC wrote ", WardenSteps.PATH, " (", table.size(), " Hunters)")
	for id in ids:
		await _hero(main, holder, String(id), false)
	print("STEP_SYNC_DONE %d rows, %d FAIL" % [rows, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _hero(main: Node, holder: Node3D, id: String, measure_only: bool) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	for k in 5:
		await main.get_tree().process_frame
	var sync := m.get_node_or_null("Warden/Sync")
	var clips: WardenClips = sync.get("clips") if sync != null else null
	if clips == null or (clips.d.get("loco", {}) as Dictionary).get("walk", {}).is_empty():
		print("STEPSYNC skip %s: no walk and run clips (the rig's own steps)" % id)
	elif KMovesStone.gait(id) < 0.5:
		print("STEPSYNC skip %s: no feet, no steps" % id)
	else:
		sync.set_process(false)
		if measure_only:
			table[clips.art] = _measure_all(sync, clips)
		else:
			_check(id, m, sync, clips)
	m.queue_free()
	await main.get_tree().process_frame

func _loops(clips: WardenClips) -> Array:
	var lc: Dictionary = clips.d["loco"]
	var out: Array = []
	for g in ["walk", "run"]:
		for k in lc[g]:
			out.append({"gait": g, "dir": k, "clip": String(lc[g][k])})
	return out

func _measure_all(sync: Node, clips: WardenClips) -> Dictionary:
	var out := {}
	var sk: Skeleton3D = clips.skel
	for l in _loops(clips):
		out[l["clip"]] = _plants(sync, clips, sk, l["clip"])
	return out

## The touchdowns of `clip` (s), both soles, from the posed skeleton.
func _plants(sync: Node, clips: WardenClips, sk: Skeleton3D, clip: String) -> Array:
	var length := clips.lib.get_animation(clip).length
	var n := maxi(int(ceil(length * SAMPLE_HZ)), 16)
	clips.force = {"clip": clip, "t": 0.0}
	for k in 8:
		sync.call("_process", POSE_DT)
	var ys := {"L": [], "R": []}
	for i in n:
		clips.force = {"clip": clip, "t": length * i / n}
		sync.call("_process", POSE_DT)
		for side in ys:
			ys[side].append(_sole(sk, side))
	clips.force = {}
	var out: Array = []
	for side in ys:
		var y: Array = ys[side]
		var lo: float = y.min()
		var band := lo + PLANT_BAND * (float(y.max()) - lo)
		var lift := lo + LIFT_BAND * (float(y.max()) - lo)
		var top := y.find(y.max())
		var up := true
		for j in n:
			var i := (top + j) % n
			var a := float(y[(i - 1 + n) % n])
			var b := float(y[i])
			if b >= lift:
				up = true
			elif up and a > band and b <= band:
				up = false
				out.append(snappedf(fposmod(length * (i - 1 + (a - band) / (a - b)) / n, length), 0.001))
	out.sort()
	return out

## The sole's height (skeleton frame): the shin's end, a thigh's length down the shin (tools/anim_audit.gd).
func _sole(sk: Skeleton3D, side: String) -> float:
	var shin := WardenSkeleton.find(sk, "shin." + side)
	var thigh := WardenSkeleton.find(sk, "thigh." + side)
	var gs := sk.get_bone_global_pose(shin)
	var leg := (sk.get_bone_global_rest(shin).origin - sk.get_bone_global_rest(thigh).origin).length()
	return (gs.origin + gs.basis.y.normalized() * leg).y

func _check(id: String, m: Node3D, sync: Node, clips: WardenClips) -> void:
	var steps := clips.steps
	var lc: Dictionary = clips.d["loco"]
	var by_clip := {}
	var bs := clips.tree.tree_root.get_node("loco") as AnimationNodeBlendSpace2D
	for i in steps.loops:
		var clip := String((bs.get_blend_point_node(i) as AnimationNodeAnimation).animation)
		by_clip[clip] = steps.loops[i].merged({"i": i})
	ok(not steps.loops.is_empty() and m.has_meta(WardenClips.STEP), "%s: steps come from its clips' plants" % id)
	for l in _loops(clips):
		var clip := String(l["clip"])
		var have: Array = by_clip[clip]["plants"] if by_clip.has(clip) else []
		var got := _plants(sync, clips, clips.skel, clip)
		var near := have.size() == got.size() and not got.is_empty()
		var length := clips.lib.get_animation(clip).length
		for i in mini(have.size(), got.size()):
			near = near and _cyc(float(have[i]), float(got[i]), length) <= FRAME
		ok(near, "%s %s plants: data %s, clip %s" % [id, clip, have, got])
		if not by_clip.has(clip):
			continue
		var spd := float(lc.get("walk_speed" if l["gait"] == "walk" else "run_speed", 2.0))
		var dir := _dir(l["dir"])
		var fired := _drive(m, sync, clips, func(_t: float) -> Vector3: return _vel(dir, spd))
		var lp: Dictionary = by_clip[clip]
		var worst := 0.0
		var other := 0
		for s in fired:
			if int(s["lead"]) != int(lp["i"]):
				other += 1
				continue
			var off := INF
			for t in lp["plants"]:
				off = minf(off, _cyc(float(s["pos"]), float(t), length))
			worst = maxf(worst, off - float(s["moved"]))
		var passed: int = fired.back()["passed"] if not fired.is_empty() else 0
		ok(other == 0 and worst <= 0.0005 and fired.size() == passed and not fired.is_empty(),
				"%s %s steps: %d (plants passed %d), on another loop %d, worst %.1f ms past one update"
				% [id, clip, fired.size(), passed, other, worst * 1000.0])
	_blends(id, m, sync, clips)

## Half-way between neighbouring loops, a walk->run ramp, a full turn: no doubles, no misses.
func _blends(id: String, m: Node3D, sync: Node, clips: WardenClips) -> void:
	var lc: Dictionary = clips.d["loco"]
	var walk := float(lc.get("walk_speed", 2.0))
	var run := float(lc.get("run_speed", 4.6))
	var cases := {}
	for g in ["walk", "run"]:
		var angs: Array = []
		for k in lc[g]:
			var v := _dir(k)
			angs.append(atan2(v.x, v.y))
		angs.sort()
		var spd := walk if g == "walk" else run
		for i in angs.size():
			var a := float(angs[i])
			var b := float(angs[(i + 1) % angs.size()]) + (TAU if i + 1 == angs.size() else 0.0)
			var mid := (a + b) * 0.5
			var at := Vector2(sin(mid), cos(mid))
			cases["%s half-way %d deg" % [g, roundi(rad_to_deg(mid))]] = func(_t: float) -> Vector3:
				return _vel(at, spd)
	cases["walk->run ramp"] = func(t: float) -> Vector3:
		return _vel(Vector2(0, 1), lerpf(walk, run, clampf(t / 2.0, 0, 1)))
	cases["run full turn"] = func(t: float) -> Vector3:
		return _vel(Vector2(sin(t * TAU / RUN_S), cos(t * TAU / RUN_S)), run)
	cases["strafe left-right"] = func(t: float) -> Vector3:      # (reversing every 0.75 s)
		return _vel(Vector2(1 if int(t / 0.75) % 2 == 0 else -1, 0), run)
	var by_i := clips.steps.loops
	for nm in cases:
		var fired := _drive(m, sync, clips, cases[nm])
		var lo := INF
		var hi := 0.0
		for i in range(1, fired.size()):
			var l: Dictionary = by_i[int(fired[i]["lead"])]
			lo = minf(lo, float(fired[i]["gap"]) / float(l["short"]))
			hi = maxf(hi, float(fired[i]["gap"]) / float(fired[i]["slow"]))
		ok(fired.size() >= 2 and lo >= WardenSteps.GAP_MIN - 0.001 and hi <= GAP_MAX,
				"%s %s: %d steps, gaps %.2f of the shortest plant gap .. %.2f of the longest"
				% [id, nm, fired.size(), lo, hi])

## Runs the game's own update with the velocity `vel_at(t)`; the steps after WARM_S: {lead, pos, moved, gap, passed}
## (passed: plants the lead loop's playhead crossed so far, steps or not; slow: the longest plant gap of the loops
## that led since the step before).
func _drive(m: Node3D, sync: Node, clips: WardenClips, vel_at: Callable) -> Array:
	var out: Array = []
	var passed := 0
	var slow := 0.0
	clips.loco_pos = Vector2.ZERO
	WardenClips.foot_down(m, false)
	for k in int((WARM_S + RUN_S) / DT):
		var t := k * DT
		m.set_meta(WardenClips.STATE, {"vel": vel_at.call(maxf(t - WARM_S, 0.0)), "face": 0.0, "grounded": true})
		sync.call("_process", DT)
		var down := WardenClips.foot_down(m, false)
		if t < WARM_S or clips.steps.lead < 0:
			continue
		var key := "parameters/loco/%d/" % clips.steps.lead
		var moved := float(clips.tree.get(key + "current_delta"))
		slow = maxf(slow, float(clips.steps.loops[clips.steps.lead]["long"]))
		var length := float(clips.tree.get(key + "current_length"))
		var pos := fposmod(float(clips.tree.get(key + "current_position")), length)
		for p in clips.steps.loops[clips.steps.lead]["plants"]:
			if _cyc(pos - moved * 0.5, float(p), length) <= moved * 0.5 and moved > 0.0:
				passed += 1
		if down:
			out.append({"lead": clips.steps.lead, "pos": pos, "moved": moved, "gap": clips.steps.gap, "passed": passed,
					"slow": slow})
			slow = float(clips.steps.loops[clips.steps.lead]["long"])
	m.set_meta(WardenClips.STATE, {})
	return out

## A loop's direction key ("f", "bl", ...) as a blend direction.
func _dir(k: String) -> Vector2:
	return DIRS[k] if DIRS.has(k) else (DIRS[k[0]] + DIRS[k[1]]).normalized()

## The world velocity for a blend direction (x right, y forward of a Hunter facing -Z) at `spd`.
func _vel(dir: Vector2, spd: float) -> Vector3:
	return Vector3(dir.x, 0.0, -dir.y) * spd

func _cyc(a: float, b: float, length: float) -> float:
	var d := fposmod(a - b, length)
	return minf(d, length - d)
