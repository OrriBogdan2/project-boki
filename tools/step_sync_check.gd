extends RefCounted
## --step-sync-check: a Hero's footsteps sound when his feet plant, on every walk and run loop of the ring (forward,
## back, the sides, the diagonals: the directional loops of tools/art1/hunter_dir_gait.py) and through a blend
## between two neighbours (scripts/heroes/warden_steps.gd); the crouch layer's sneak ring too ("crouch.plants").
## Per Hero with clips and feet, per ring, rows:
##  - per loop, the clip: its plant frames read off the clip itself (each ankle posed at every game frame of it, a
##    touchdown into the lowest PLANT_BAND of its height range after it rose past LIFT_BAND), the feet alternate,
##    and the data "loco.plants" sits within one frame of them;
##  - per loop, played through the game's own ring at its point: every step lands within one game frame after a
##    plant of the same foot, and the steps count the plants (one at most off, where the counted laps start and end);
##  - per pair of neighbouring run loops, the blend halfway: the feet alternate and the steps count the plants (no
##    double step at a blend, no missing step on a strafe).
## A Meshy-native Hunter (WardenNative: no hidden-rig ring) has native rows instead, for its walk, run and sneak clips
## (WardenNativeSteps): the plants read off Meshy's foot bones in the clip, the data "plants" within one frame of
## them, every step heard at a walk and a run speed within one frame after a plant of that foot (the steps count the
## plants), the feet alternating through a walk-run-walk ramp, and no step standing still.
## Run: godot --headless -- --step-sync-check [--wardens=archer,dolm] [--plants-json=<file>: the plants read].

const DT := 1.0 / 60.0  # s: one game frame
const WARM_LOOPS := 2  # loops played before counting (the blend position settles)
const COUNT_LOOPS := 3  # loops counted
const NO_FEET := ["ostra"]  # Motley hovers on his box: no feet, no steps (KMovesStone.HOVER_GAIT)
const PLANT_BAND := 0.3  # x a foot's height range over its low: under this it is planted (tools/anim_audit.gd)
const LIFT_BAND := 0.6  # x: over this it has lifted
const NATIVE_STATES := ["walk", "run", "crouch"]
const SPEED_BAND := 0.1  # x run_from: the walk is heard just under it and the run just over it
const RAMP_SECONDS := 2.0  # s each leg of the walk-run-walk-run ramp lasts

var bad := 0
var rows := 0
var holder: Node3D
var read := {}  # art -> "loco" / "crouch" -> clip -> {foot: [s]}: the plants read off the clips (--plants-json)


func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var ids: Array = Arch.ORDER.duplicate()
	var json := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wardens="):
			ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--plants-json="):
			json = a.substr(14)
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
	var nat := m.get_node_or_null("Warden/Native") as WardenNative
	if nat:
		_native(id, nat)
		m.free()
		return
	var sync := m.get_node_or_null("Warden/Sync")
	var clips: WardenClips = sync.get("clips") if sync else null
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	if clips == null or WardenSkeleton.find(sk, "shin.L") < 0:
		print("skip %s: no clips with feet" % id)
		m.free()
		return
	sync.set_process(false)
	clips.twist_on = false  # (ring points: a twisting Hero's legs would run another loop than at `at`)
	read[WardenGlb.art(id)] = {}
	_space(id, m, sync, clips, sk, "loco")
	if clips.crouch_steps:
		_space(id, m, sync, clips, sk, "crouch")
	m.free()


## The rows for one ring: `key` "loco" (walk and run) or "crouch" (the sneak ring), its data key and tree node.
func _space(id: String, m: Node3D, sync: Node, clips: WardenClips, sk: Skeleton3D, key: String) -> void:
	var node_name := "loco" if key == "loco" else "crouch_loco"
	var bs: AnimationNodeBlendSpace2D = (clips.tree.tree_root as AnimationNodeBlendTree).get_node(node_name)
	var ring := []  # [point index, clip, position, timeline s per clip s (the walks play stretched), key]
	for i in bs.get_blend_point_count():
		var at := bs.get_blend_point_position(i)
		var point := bs.get_blend_point_node(i)
		var seekable := point as AnimationNodeBlendTree
		var node := seekable.get_node("clip") as AnimationNodeAnimation if seekable else point as AnimationNodeAnimation
		if at.length() > 0.01 and node != null:
			var stretch := (
				node.timeline_length / clips.lib.get_animation(node.animation).length
				if node.use_custom_timeline
				else 1.0
			)
			ring.append([i, String(node.animation), at, stretch, key])
	var plants := {}  # clip -> {foot: [s into the clip]}
	var data: Dictionary = clips.d[key].get("plants", {})
	for p in ring:
		plants[p[1]] = _plants(sync, clips, sk, String(p[1]))
		_clip_row(id, String(p[1]), plants[p[1]], data.get(p[1], {}))
	read[WardenGlb.art(id)][key] = plants
	for p in ring:
		_loop_row(id, m, sync, clips, p, plants[p[1]])
	var runs := ring.filter(func(p): return (p[2] as Vector2).length() > 0.9)
	runs.sort_custom(func(a, b): return (a[2] as Vector2).angle() < (b[2] as Vector2).angle())
	for i in runs.size():
		_blend_row(id, m, sync, clips, runs[i], runs[(i + 1) % runs.size()], plants)


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
	return _touchdowns(ys, length)


## The touchdowns of both feet from their heights over the clip's frames `ys` ([[L], [R]]): see _plants.
func _touchdowns(ys: Array, length: float) -> Dictionary:
	var n: int = ys[0].size()
	var out := {}
	for f in 2:
		var lo: float = ys[f].min()
		var span: float = ys[f].max() - lo
		var times := []
		var down := true
		for k in 2 * n:  # (twice round: the first lap only finds where the foot is)
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
	var msg := (
		"%-10s %-8s clip plants L %s R %s, data %s: feet alternate %s, data %.2f frames off"
		% [id, clip, _ts(pl["L"]), _ts(pl["R"]), JSON.stringify(data), alternate, worst]
	)
	ok(alternate and same and worst <= 1.0, msg)


## Plays the ring at `at` (a point's place, or between two) as the game does and logs each step: [foot, s into the
## loop at ring point `p` (see _space), the rate it plays at]. A sneak ring point is played crouched.
func _play(m: Node3D, sync: Node, clips: WardenClips, at: Vector2, p: Array) -> Array:
	var sneak: bool = p[4] == "crouch"
	var top := float(clips.d["crouch"].get("speed", 2.4)) if sneak else float(clips.d["loco"].get("run_speed", 4.6))
	var spd := at.length() * top
	var dir := at.normalized()
	var st := {"vel": Vector3(dir.x, 0, -dir.y) * spd, "face": 0.0, "grounded": true}
	if sneak:
		st["crouch"] = 1.0
		clips.crouch_pos = at
	else:
		clips.loco_pos = at
	m.set_meta(WardenClips.STATE, st)
	var steps: WardenSteps = clips.crouch_steps if sneak else clips.steps
	var pos_path := "parameters/loco/%d/clip/current_position"
	if sneak:
		pos_path = "parameters/crouch_loco/%d/current_position"
	var rate_path := "parameters/crouch_rate/scale" if sneak else "parameters/loco_rate/scale"
	var length: float = clips.lib.get_animation(String(p[1])).length * float(p[3])
	for k in 12:
		sync.call("_process", DT)
	var rate := float(clips.tree.get(rate_path))
	for k in int(WARM_LOOPS * length / rate / DT):
		sync.call("_process", DT)
	var heard := []
	for k in int(COUNT_LOOPS * length / rate / DT):
		var n: int = steps.count
		sync.call("_process", DT)
		var t: float = clips.tree.get(pos_path % int(p[0]))
		if steps.count > n:
			heard.append([steps.side, t, float(clips.tree.get(rate_path))])
	m.set_meta(WardenClips.STATE, {})
	return heard


func _loop_row(id: String, m: Node3D, sync: Node, clips: WardenClips, p: Array, pl: Dictionary) -> void:
	var length: float = clips.lib.get_animation(String(p[1])).length * float(p[3])
	var heard := _play(m, sync, clips, p[2], p)
	var worst := 0.0
	var off := 0
	for st in heard:
		var near := INF
		for t in pl[st[0]]:
			var d := absf(float(st[1]) - float(t) * float(p[3]))
			near = minf(near, minf(d, length - d))
		var frames := near / (DT * float(st[2]))
		worst = maxf(worst, frames)
		if frames > 1.0:
			off += 1
	var want: int = COUNT_LOOPS * (pl["L"].size() + pl["R"].size())
	var msg := (
		"%-10s %-8s plants L %s R %s: %d steps for %d plants, worst %.2f frames off"
		% [id, p[1], _ts(pl["L"]), _ts(pl["R"]), heard.size(), want, worst]
	)
	ok(off == 0 and want > 0 and absf(heard.size() - want) <= 1, msg)


func _blend_row(id: String, m: Node3D, sync: Node, clips: WardenClips, a: Array, b: Array, plants: Dictionary) -> void:
	var per_loop: int = plants[a[1]]["L"].size() + plants[a[1]]["R"].size()
	var heard := _play(m, sync, clips, ((a[2] as Vector2) + (b[2] as Vector2)) * 0.5, a)
	var gap := INF  # the fewest steps from one step of a foot to its next (2: the feet alternate)
	var last := {}
	var k := 0
	for st in heard:
		k += 1
		if last.has(st[0]):
			gap = minf(gap, float(k - int(last[st[0]])))
		last[st[0]] = k
	var want: int = COUNT_LOOPS * per_loop
	var msg := (
		"%-10s %s+%s blend: %d steps for %d plants (feet alternate: %s)"
		% [id, a[1], b[1], heard.size(), want, "yes" if gap >= 2.0 else "no"]
	)
	ok(per_loop > 0 and absf(heard.size() - want) <= 1 and gap >= 2.0, msg)


## The rows of a Meshy-native Hunter (see the header): `nat` plays Meshy's clips, its steps read their foot plants.
func _native(id: String, nat: WardenNative) -> void:
	if WardenSkeleton.find(nat.skel, "foot.L") < 0:
		print("skip %s: no feet" % id)
		return
	nat.set_process(false)
	var plants := {}  # state -> {foot: [s into the clip]}
	var data: Dictionary = nat.d.get("plants", {})
	for state in NATIVE_STATES:
		plants[state] = _native_plants(nat, state)
		_clip_row(id, state, plants[state], data.get(state, {}))
	read[WardenGlb.art(id)] = {"native": plants}
	for state in NATIVE_STATES:
		for speed in _native_speeds(nat.d, state):
			_native_row(id, nat, state, speed, plants[state])
	_ramp_row(id, nat)
	_still_row(id, nat)


## The ground speeds (m/s) a Hunter is heard at in `state`, from its own data (walk_mps, run_from, run_mps, crouch_mps:
## --foot-slide-check measures them per Hunter).
func _native_speeds(d: Dictionary, state: String) -> Array:
	var from := float(d.get("run_from", 3.0))
	match state:
		"walk":
			return [float(d.get("walk_mps", 1.4)), from * (1.0 - SPEED_BAND)]
		"run":
			return [from * (1.0 + SPEED_BAND), float(d.get("run_mps", 4.6))]
	return [float(d.get("crouch_mps", 1.4))]


## Where each foot plants in the clip Meshy's `state` plays (s), read off Meshy's foot bones posed at every frame of it.
func _native_plants(nat: WardenNative, state: String) -> Dictionary:
	var clip := String(nat.plays[state])
	var length := nat.player.get_animation(clip).length
	var n := maxi(int(round(length / DT)), 2)
	var ys := [[], []]
	nat.player.play(clip, 0.0)
	for k in n:
		nat.player.seek(length * k / n, true)
		nat.player.advance(0.0)
		for f in 2:
			ys[f].append(_foot_y(nat.skel, "LR"[f]))
	return _touchdowns(ys, length)


## The foot bone's height (m): Meshy's own foot bone (the ankle).
func _foot_y(sk: Skeleton3D, foot: String) -> float:
	return (sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "foot." + foot))).origin.y


## `seconds` of the Hunter moving at `speed` (m/s) on the ground (crouched or not); the steps heard: [foot, s into the
## clip, the clip's rate].
func _native_walk(nat: WardenNative, speed: float, sneak: bool, seconds: float) -> Array:
	var state := {"vel": Vector3(0, 0, -speed), "grounded": true, "crouch": 1.0 if sneak else 0.0}
	nat.root.set_meta(WardenClips.STATE, state)
	var heard := []
	for k in int(seconds / DT):
		var n := nat.steps.count
		nat._process(DT)
		if nat.steps.count > n:
			heard.append([nat.steps.side, nat.player.current_animation_position, nat.player.speed_scale])
	return heard


func _native_row(id: String, nat: WardenNative, state: String, speed: float, pl: Dictionary) -> void:
	var length := nat.player.get_animation(String(nat.plays[state])).length
	var sneak := state == "crouch"
	_native_walk(nat, speed, sneak, 1.0)  # (settle: the clip and its rate)
	var heard := _native_walk(nat, speed, sneak, COUNT_LOOPS * length / maxf(nat.player.speed_scale, 0.01))
	var worst := 0.0
	var off := 0
	for st in heard:
		var near := INF
		for t in pl[st[0]]:
			var d := absf(float(st[1]) - float(t))
			near = minf(near, minf(d, length - d))
		var frames := near / (DT * float(st[2]))
		worst = maxf(worst, frames)
		off += 1 if frames > 1.0 else 0
	var want: int = COUNT_LOOPS * (pl["L"].size() + pl["R"].size())
	var msg := (
		"%-10s native %-6s at %.1f m/s: %d steps for %d plants, worst %.2f frames off"
		% [id, state, speed, heard.size(), want, worst]
	)
	ok(off == 0 and want > 0 and absf(heard.size() - want) <= 1 and nat.cur == state, msg)
	nat.root.set_meta(WardenClips.STATE, {})


## Walk, run, walk, run: the feet alternate across the hand-overs (a switch of clip never steps one foot twice).
func _ramp_row(id: String, nat: WardenNative) -> void:
	var heard := []
	var walk := float(nat.d.get("walk_mps", 1.4))
	var run := float(nat.d.get("run_mps", 4.6))
	var mid := float(nat.d.get("run_from", 3.0))
	for speed in [walk, run, (walk + mid) * 0.5, (mid + run) * 0.5]:  # walk, run, walk, run
		heard.append_array(_native_walk(nat, speed, false, RAMP_SECONDS))
	var alternate := heard.size() > 1
	for i in heard.size() - 1:
		alternate = alternate and heard[i][0] != heard[i + 1][0]
	ok(alternate, "%-10s native walk-run ramp: %d steps, the feet alternate: %s" % [id, heard.size(), alternate])
	nat.root.set_meta(WardenClips.STATE, {})


func _still_row(id: String, nat: WardenNative) -> void:
	var heard := _native_walk(nat, 0.0, false, 2.0)
	ok(heard.is_empty(), "%-10s native standing: %d steps" % [id, heard.size()])
	nat.root.set_meta(WardenClips.STATE, {})


func _ts(a: Array) -> String:
	return "[" + ", ".join(a.map(func(t): return "%.3f" % t)) + "]"
