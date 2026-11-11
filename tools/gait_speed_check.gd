extends RefCounted
## --gait-speed-check: the loops' cadence follows the ground speed (WardenClips._rate). Per Hero with clips: each
## forward loop's planted sole runs back at the speed its file says ("walk_sole", "run_sole", crouch "sole"); at 70%,
## 100% and 130% of the Hero's run speed (a Slow, a plain run, a haste) and over a sneak the planted foot strays under
## 3 cm in a step, or, for a loop that glides (a skate, a hover), it plays at the ground speed over its ring's. Never
## touches the save.

const DT := 1.0 / 60.0
const SIDES := ["L", "R"]
const RUN_K := [0.7, 1.0, 1.3]     # of the Hero's run speed
const FOOT_MAX := 0.03             # m: a planted foot may stray this far from where its contact began
const CROUCH_K := 0.55             # of the run speed a crouch walks at (Hunter._physics)
const PLANT_Y := 0.01              # m: a foot this near its lowest point in the loop is planted
const SPEED_TOL := 0.04            # of the authored speed the file may be off from the clip
const SETTLE := 60                 # frames at the speed before measuring
const SPAN := 150                  # frames measured: two strides and more at a walk

var bad := 0
var shin := [0.0, 0.0]         # m: knee to sole down the shin, per side
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("GAIT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var n := 0
	for id in Arch.ids():
		if WardenClips.data(WardenGlb.art(String(id))).is_empty():
			continue
		n += 1
		_hero(String(id))
	ok(n == 12, "all 12 Heroes have loops (%d)" % n)
	print("GAIT_SPEED_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hero(id: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync: Node = m.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	_measure_shins(sync)
	var lc: Dictionary = clips.d["loco"]
	var cr: Dictionary = clips.d.get("crouch", {})
	var loops := [[lc["walk"]["f"], lc.get("walk_sole")], [lc["run"]["f"], lc.get("run_sole")]]
	if not cr.is_empty():
		loops.append([cr["walk"]["f"], cr.get("sole")])
	for lp in loops:
		var got := _authored(sync, clips, String(lp[0]))
		var want := float(lp[1]) if lp[1] != null else -1.0
		var near := absf(got[0] - want) <= maxf(want * SPEED_TOL, 0.02)
		ok(near, "%s: %s sole runs back at %.2f m/s over %.2f s, file %.2f" % [id, lp[0], got[0], got[1], want])
	clips.force = {}
	var run_v := float(HunterMove.of(id)["speed"])
	for k in RUN_K:
		_gait(id, "%d%% run" % roundi(float(k) * 100.0), sync, clips, run_v * float(k), 0.0,
				[float(lc["run_sole"]), float(lc["run_speed"]), "loco_rate"])
	if not cr.is_empty():
		var sneak := [float(cr["sole"]), float(cr["speed"]), "crouch_rate"]
		_gait(id, "sneaking", sync, clips, run_v * CROUCH_K, 1.0, sneak)
	m.free()

## One steady speed `v` (crouched 0..1). `loop`: [its sole speed, its ring's speed, the rate node]. A strided loop keeps
## its planted foot under FOOT_MAX; a gliding one (WardenClips.GLIDE_K: a skate, a hover) plants nothing and plays at
## the ground speed over its ring's.
func _gait(id: String, what: String, sync: Node, clips: WardenClips, v: float, crouch: float, loop: Array) -> void:
	var worst := _drift(sync, v, crouch)
	var sole := float(loop[0])
	var ring := float(loop[1])
	if sole >= ring * WardenClips.GLIDE_K:
		ok(worst <= FOOT_MAX, "%s: %s (%.2f m/s) the planted foot strays %.3f m" % [id, what, v, worst])
		return
	var rate := float(clips.tree.get("parameters/%s/scale" % loop[2]))
	var follows := absf(rate - minf(v / ring, WardenClips.RATE_MAX)) < 0.01
	ok(follows, "%s: %s (%.2f m/s) the loop glides (sole %.2f of %.2f m/s): x%.2f, the ground over the ring" \
			% [id, what, v, sole, ring, rate])

## Both soles in the model's space (it faces -Z): down each shin's axis (its Y) as far as the floor lies in the rest
## pose. `shin` holds those lengths per side, measured once per Hero.
func _feet(sync: Node) -> Array:
	var sk: Skeleton3D = sync.get("skel")
	var out := []
	for i in 2:
		var knee := sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "shin." + SIDES[i]))
		out.append(knee.origin + knee.basis.y.normalized() * float(shin[i]))
	return out

func _measure_shins(sync: Node) -> void:
	var sk: Skeleton3D = sync.get("skel")
	for i in 2:
		var knee := sk.global_transform * sk.get_bone_global_rest(WardenSkeleton.find(sk, "shin." + SIDES[i]))
		var down := knee.basis.y.normalized()
		shin[i] = knee.origin.y / -down.y if down.y < -0.5 else 0.0

## A loop seeked through two plays: [how fast its planted soles run back (m/s), its length (s)].
func _authored(sync: Node, clips: WardenClips, clip: String) -> Array:
	var length := clips.lib.get_animation(clip).length
	clips.force = {"clip": clip, "t": 0.0}
	for f in 20:
		sync.call("_process", DT)
	var track := [[], []]
	var t := 0.0
	while t < length * 2.0:
		clips.force = {"clip": clip, "t": fmod(t, length)}
		sync.call("_process", 0.0001)
		var now := _feet(sync)
		for i in 2:
			track[i].append([t, now[i]])
		t += DT * 0.5
	var dist := 0.0
	var time := 0.0
	for i in 2:
		var low := INF
		for p in track[i]:
			low = minf(low, (p[1] as Vector3).y)
		var start: Array = []
		var last: Array = []
		for p in track[i] + [[INF, Vector3.UP * INF]]:
			if (p[1] as Vector3).y <= low + PLANT_Y:
				if start.is_empty():
					start = p
				last = p
				continue
			if not start.is_empty() and float(last[0]) > float(start[0]):
				dist += (last[1] as Vector3).z - (start[1] as Vector3).z
				time += float(last[0]) - float(start[0])
			start = []
	return [dist / maxf(time, 0.0001), length]

## Runs straight ahead at `v` (crouched 0..1) and follows each planted sole over the ground: the worst a contact
## strays from where it began (m).
func _drift(sync: Node, v: float, crouch: float) -> float:
	var s := {"vel": Vector3(0.0, 0.0, -v), "face": 0.0, "grounded": true, "crouch": crouch}
	(sync.get("root") as Node3D).set_meta(WardenClips.STATE, s)
	for f in SETTLE:
		sync.call("_process", DT)
	var low := [INF, INF]
	var track := [[], []]
	for f in SPAN:
		sync.call("_process", DT)
		var now := _feet(sync)
		for i in 2:
			var world: Vector3 = now[i] + Vector3(0.0, 0.0, -v * DT * f)
			track[i].append(world)
			low[i] = minf(low[i], world.y)
	var worst := 0.0
	for i in 2:
		var start := Vector3.INF
		var first := true             # (a contact already on at the first frame began before it)
		for p in track[i]:
			var foot: Vector3 = p
			if foot.y > float(low[i]) + PLANT_Y:
				start = Vector3.INF
				first = false
				continue
			if first:
				continue
			if start == Vector3.INF:
				start = foot
			worst = maxf(worst, Vector2(foot.x - start.x, foot.z - start.z).length())
	return worst
