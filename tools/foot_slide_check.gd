extends RefCounted
## --foot-slide-check [--wardens=a,b]: planted-foot slip over the whole locomotion blend (docs/art/FOOT_SLIDE.md).
## --anim-audit reads three forward speeds; between the walk and run rings the two clips blend and can slide far
## more. Per Hunter with stepping legs this poses the real model (WardenClips through Warden/Sync) moving forward,
## back, left and right at 0 m/s, every 0.5 m/s, and its run speed from content/rules/hunter_move.json, and measures
## how fast a planted foot moves against the ground (m/s: the body's velocity plus the foot's own, flat).
## Prints one SLIP line per Hunter and direction; FAIL when a Hunter's worst slip passes its bar in BAR.
## A STEP line per Hunter reads the forward run as a match shows it (the model at Hunter.VIS_SCALE, moving at
## HunterMove.speed, the row times body_scale): its model (glb, triangles), the run cycle, the stride a planted foot
## sweeps per cycle at rate 1, the loco rate it plays at and its cadence, and how far a planted foot travels over the
## ground in one step (cm, + forward: the clip under-strides the speed, so "loco.foot_mps" is set too high); FAIL
## past STEP_CM.

const AUDIT := preload("res://tools/anim_audit.gd")
const STEP := 0.5  # m/s between swept speeds
const WARM_S := 2.4  # s at a speed before sampling: three of WardenGait.MEAN_TAU, so the stride has settled
const STEP_WARM_S := 4.8  # s at a STEP mode's speed before sampling (a fresh model: the gait's mean has settled)
const SAMPLE_S := 6.0  # s sampled a speed: walk and run loops of unequal length drift through ~3 phase beats
const WOBBLE := 0.2  # rad: the aim's sway (0.7 Hz) while a run-and-aim Hunter runs 90 deg off it
const WOBBLE_HZ := 0.7
const DIRS := {"f": Vector3(0, 0, -1), "b": Vector3(0, 0, 1), "l": Vector3(-1, 0, 0), "r": Vector3(1, 0, 0)}
## m/s: the worst mean planted-foot slip each Hunter may show anywhere in the sweep, the measured worst of the
## FOOT_SLIDE.md "after" table rounded up to 0.05 (the sweep is deterministic: no physics, fixed steps).
## (archer stays at 1.75: its forward loop slides 4.4 m/s on main too since its clips changed, an open item.)
const BAR := {
	"archer": 1.75,
	"juggernaut": 0.95,
	"gunslinger": 1.0,
	"bulwark": 1.35,
	"ashwick": 1.4,
	"tender": 1.05,
	"dolm": 2.7,
	"dredge": 0.95,
	"mage": 1.55,
	"thief": 1.5
}
## m/s: a run-and-aim ("loco.aim_twist") Hunter running at its run speed 90 deg off an aim that sways WOBBLE: each sway
## across the turn-round margin swung the legs from the forward run to the back run and the feet dragged (Vex 3.30
## m/s with the 0.1 rad default margin, 0.97 with her "twist_hyst" 0.35; owner bug 11-15). A Hunter without a bar
## only prints its WOBBLE line (Lace `archer` and Cinder `ashwick` keep the default margin: open, FOOT_SLIDE.md).
const WOBBLE_BAR := {"gunslinger": 1.0}
const STEP_CM := 5.0  # cm: furthest a planted foot may travel in one step of the run at its run speed
const MIN_STANCE := 0.025  # s: a shorter planted spell is a scuff, not a step (3 samples)
const CONTACT_M := 0.03  # m: a sole this close to its lowest is on the ground (a sprint's swing skims ~0.1 m)
## Hunter -> the STEP mode left over the bar: Albert's crouch walk lifts a foot only ~0.3 m/s, so no rate under
## WardenClips.CROUCH_RATE_MAX plants it (a clip to re-author: docs/DEBT.md).
const STEP_OPEN := {"bulwark": "crouch"}
const STEP_DT := 1.0 / 120.0  # s between STEP samples: a 0.33 s run cycle plants a foot for only a few 30 fps frames

## A Hunter with "loco.foot_lock" (WardenGait) runs forward from a standstill at its game speed (HunterMove.speed),
## as the play probe's run does: the median over the frames of the slower ankle's flat speed over the ground, as a
## share of the body's, at most this (the probe flags 0.6; owner target 11-18). SKATE_IDLE_S standing first, then
## SKATE_RUN_S of the run read after SKATE_SETTLE_S, so a lock that is slow to catch on at the start shows.
const SKATE_BAR := 0.45
const SKATE_IDLE_S := 1.5
const SKATE_SETTLE_S := 0.1
const SKATE_RUN_S := 1.35

var bad := 0
var holder: Node3D
var warm_s := WARM_S


func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var ids: Array = Arch.ORDER.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wardens="):
			ids = Array(a.substr(10).split(",", false))
	var done := 0
	for id in ids:
		if await _hero(main, String(id)):
			done += 1
	print("FOOT_SLIDE_DONE ", done, " FAIL ", bad)
	main.get_tree().quit(1 if bad > 0 or done == 0 else 0)


## Sweeps one Hunter; false when it has no stepping legs to measure.
func _hero(main: Node, id: String) -> bool:
	if id in AUDIT.NO_LEGS:
		return false
	var m := await _spawn(main, id)
	var sync := m.get_node("Warden/Sync")
	var clips: WardenClips = sync.get("clips")
	if clips == null or not clips.d.has("loco"):
		m.free()
		return false
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var run_speed := float(HunterMove.of(id)["speed"])
	var worst := [0.0, "", 0.0]
	for dir in DIRS:
		var cells: Array = []
		for s in _speeds(run_speed):
			var slip := _slip(m, sync, clips, sk, DIRS[dir] * s)
			cells.append("%.2f:%.2f" % [s, slip])
			if slip > worst[0]:
				worst = [slip, dir, s]
		print("SLIP %-10s %s %s" % [id, dir, " ".join(cells)])
	print("SLIP_WORST %-10s %.2f m/s (%s at %.2f m/s, run %.2f)" % [id, worst[0], worst[1], worst[2], run_speed])
	if not BAR.has(id):
		print("FAIL %s: no bar in BAR (measured worst %.2f m/s)" % [id, worst[0]])
		bad += 1
	elif worst[0] > float(BAR[id]):
		print(
			(
				"FAIL %s: a planted foot slips %.2f m/s (%s at %.2f m/s), bar %.2f"
				% [id, worst[0], worst[1], worst[2], BAR[id]]
			)
		)
		bad += 1
	if clips.d["loco"].has("foot_lock"):
		var skate := _skate(m, sync, sk, HunterMove.speed(id))
		print(
			(
				"SKATE %-10s %d%% of %.2f m/s (bar %d%%)"
				% [id, round(100.0 * skate), HunterMove.speed(id), round(100.0 * SKATE_BAR)]
			)
		)
		if skate > SKATE_BAR:
			print(
				(
					"FAIL %s: running from a standstill the planted foot moves at %d%% of the body's speed, bar %d%%"
					% [id, round(100.0 * skate), round(100.0 * SKATE_BAR)]
				)
			)
			bad += 1
	if clips.twist_on:
		var wob := _slip(m, sync, clips, sk, Vector3(-run_speed, 0, 0), WOBBLE)
		print("WOBBLE %-10s %.2f m/s (run %.2f m/s 90 deg off the aim, sway %.2f rad)" % [id, wob, run_speed, WOBBLE])
		if WOBBLE_BAR.has(id) and wob > float(WOBBLE_BAR[id]):
			print(
				(
					"FAIL %s: running 90 deg off a swaying aim a planted foot slips %.2f m/s, bar %.2f"
					% [id, wob, WOBBLE_BAR[id]]
				)
			)
			bad += 1
	m.free()
	await _step_line(main, id)
	return true


## A fresh model of `id` in the holder, its clips advanced only by this check's fixed steps.
func _spawn(main: Node, id: String) -> Node3D:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	m.get_node("Warden/Sync").set_process(false)  # (a real frame's dt would shift the clips' phase)
	for k in 5:
		await main.get_tree().process_frame
	return m


## Prints the GLB line, then one STEP line per mode (walk, run, strafe, crouch walk), each on a fresh model at the
## match's scale so no mode's phase carries into the next: FAIL when a planted foot travels past STEP_CM a step. The run
## line also gives the cycle and stride its fit reads; `fit` is the key's value (model scale, m/s) that would plant it.
func _step_line(main: Node, id: String) -> void:
	var m := await _spawn(main, id)
	var tris := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh as ArrayMesh
		if (mi as MeshInstance3D).is_visible_in_tree() and mesh:
			for si in mesh.get_surface_count():
				tris += mesh.surface_get_array_index_len(si) / 3
	print("GLB %-10s %s tris %d" % [id, WardenGlb.path(id), tris])
	var clips: WardenClips = m.get_node("Warden/Sync").get("clips")
	var run := HunterMove.speed(id)
	var modes := [
		["walk", "f", float(clips.d["loco"].get("walk_speed", 2.2)), {}],
		["run", "f", run, {}],
		["strafe", "r", run, {}]
	]
	if clips.d.has("crouch"):
		modes.append(["crouch", "f", run * HunterMove.sneak_speed, {"crouch": 1.0}])
	m.free()
	warm_s = STEP_WARM_S
	for md in modes:
		m = await _spawn(main, id)
		m.scale *= Hunter.VIS_SCALE
		var sync := m.get_node("Warden/Sync")
		clips = sync.get("clips")
		var sk := WardenGlb.skeleton(m.get_node("Warden"))
		AUDIT.soles = AUDIT.sole_ends(sk)
		var dir: Vector3 = DIRS[md[1]]
		var spd := float(md[2])
		var fr := _sample(m, sync, clips, sk, dir * spd, 0.0, STEP_DT, md[3])[0] as Array
		AUDIT.soles = {}
		var st := _stance_cm(fr, spd, dir)
		var rate := float(clips.tree.get("parameters/%s_rate/scale" % ("crouch" if md[0] == "crouch" else "loco")))
		var fit := (spd - float(st[1])) / maxf(rate, 0.01) * clips.body_mps(1.0)
		if md[0] == "walk":
			fit *= clips.gait.run_len / clips.gait.walk_len  # (the walk loop plays on the run loop's timeline)
		var tail := " fit %.2f" % fit
		if md[0] == "run":
			var stride: float = (spd - float(st[1])) * clips.gait.run_len / maxf(rate, 0.01)  # m a foot sweeps a cycle
			tail += " cycle %.3f s stride %.2f m" % [clips.gait.run_len, stride]
		print(
			(
				"STEP %-10s %-6s %.2f m/s rate %.2f%s slide %+.1f cm/step (%d steps)"
				% [id, md[0], spd, rate, tail, st[0], st[2]]
			)
		)
		if absf(st[0]) > STEP_CM:
			var open: bool = STEP_OPEN.get(id, "") == md[0]
			print(
				(
					"%s %s: a planted foot travels %+.1f cm a step in the %s at %.2f m/s, bar %.1f"
					% ["OPEN" if open else "FAIL", id, st[0], md[0], spd, STEP_CM]
				)
			)
			bad += 0 if open else 1
		m.free()
	warm_s = WARM_S


## [mean cm a planted foot travels over the ground along the run in one stance (+ forward), the mean m/s it moves
## forward while planted, stances counted]. A foot stands on the lower of its heel and toe (the ankle rolls forward
## over a stance); only whole stances count: one cut by the sample's ends is left out.
func _stance_cm(fr: Array, spd: float, dir: Vector3) -> Array:
	var total := 0.0
	var v_sum := 0.0
	var n := 0
	var frames := 0
	for side in ["L", "R"]:
		var at: Array = []
		for p in fr:
			if not p.has("heel." + side):
				at.append("foot." + side)
				continue
			var heel_low := (p["heel." + side] as Vector3).y <= (p["toe." + side] as Vector3).y
			at.append(("heel." if heel_low else "toe.") + side)
		var lo := INF
		for i in fr.size():
			lo = minf(lo, (fr[i][at[i]] as Vector3).y)
		var held := -1.0  # s into the current stance; below 0 until the first lift (a stance cut by the start)
		var d := 0.0
		for i in range(1, fr.size() - 1):
			var c: String = at[i]
			var down := (fr[i][c] as Vector3).y <= lo + CONTACT_M
			if down and held >= 0.0:
				var v := spd + ((fr[i + 1][c] as Vector3) - (fr[i - 1][c] as Vector3)).dot(dir) / (2.0 * STEP_DT)
				d += v * STEP_DT
				v_sum += v
				frames += 1
				held += STEP_DT
			elif not down:
				if held >= MIN_STANCE:
					total += d
					n += 1
				held = 0.0
				d = 0.0
	return [100.0 * total / maxi(n, 1), v_sum / maxi(frames, 1), n]


## 0, every STEP, and the run speed itself.
func _speeds(run_speed: float) -> Array:
	var out: Array = []
	var s := 0.0
	while s < run_speed - 0.01:
		out.append(s)
		s += STEP
	out.append(run_speed)
	return out


## Mean flat speed of a planted foot against the ground (m/s) while the model moves at `vel`, facing -Z; with `sway`
## (rad) the facing swings that far either way at WOBBLE_HZ (the model stays put: the feet are read in its own frame,
## so each frame's velocity is turned into it).
func _slip(m: Node3D, sync: Node, clips: WardenClips, sk: Skeleton3D, vel: Vector3, sway := 0.0) -> float:
	var got := _sample(m, sync, clips, sk, vel, sway)
	var fr: Array = got[0]
	var faces: Array = got[1]
	var total := 0.0
	var n := 0
	for f in ["foot.L", "foot.R"]:
		var lo := INF
		var hi := -INF
		for p in fr:
			lo = minf(lo, (p[f] as Vector3).y)
			hi = maxf(hi, (p[f] as Vector3).y)
		for i in range(1, fr.size() - 1):
			if (fr[i][f] as Vector3).y > lo + AUDIT.PLANT_BAND * maxf(hi - lo, 0.02):
				continue
			var foot_v: Vector3 = ((fr[i + 1][f] as Vector3) - (fr[i - 1][f] as Vector3)) / (2.0 * AUDIT.DT)
			var v: Vector3 = vel.rotated(Vector3.UP, -float(faces[i]))
			total += Vector2(v.x + foot_v.x, v.z + foot_v.z).length()
			n += 1
	return total / maxi(n, 1)


## [frames of AUDIT.points, the facing of each] over SAMPLE_S at `vel` after WARM_S, `dt` apart, facing -Z
## swaying `sway` (rad).
func _sample(
	m: Node3D, sync: Node, clips: WardenClips, sk: Skeleton3D, vel: Vector3, sway := 0.0, dt := AUDIT.DT, extra := {}
) -> Array:
	m.set_meta(WardenClips.STATE, {"vel": vel, "face": 0.0, "grounded": true}.merged(extra))
	clips.loco_pos = Vector2.ZERO
	for k in int(warm_s / dt):
		sync.call("_process", dt)
	var fr: Array = []
	var faces: Array = []
	for k in int(SAMPLE_S / dt):
		var face := sway * sin(TAU * WOBBLE_HZ * k * dt)
		m.set_meta(WardenClips.STATE, {"vel": vel, "face": face, "grounded": true}.merged(extra))
		faces.append(face)
		sync.call("_process", dt)
		fr.append(AUDIT.points(sk))
	m.set_meta(WardenClips.STATE, {})
	return [fr, faces]


## The play probe's skate share (see SKATE_BAR) running forward at `spd` from a standstill; the ankles are the shins'
## ends (FootPlant.ankle), read in the model's frame, the ground going back under them at `spd`.
func _skate(m: Node3D, sync: Node, sk: Skeleton3D, spd: float) -> float:
	var legs := [["thigh.L", "shin.L"], ["thigh.R", "shin.R"]].map(
		func(p: Array) -> Array: return [WardenSkeleton.find(sk, p[0]), WardenSkeleton.find(sk, p[1])]
	)
	m.set_meta(WardenClips.STATE, {"vel": Vector3.ZERO, "face": 0.0, "grounded": true})
	for k in int(SKATE_IDLE_S / AUDIT.DT):
		sync.call("_process", AUDIT.DT)
	var vel := Vector3(0, 0, -spd)
	m.set_meta(WardenClips.STATE, {"vel": vel, "face": 0.0, "grounded": true})
	for k in int(SKATE_SETTLE_S / AUDIT.DT):
		sync.call("_process", AUDIT.DT)
	var shares: Array = []
	var was: Array = []
	for k in int(SKATE_RUN_S / AUDIT.DT):
		sync.call("_process", AUDIT.DT)
		var now: Array = legs.map(
			func(l: Array) -> Vector3: return sk.global_transform * FootPlant.ankle(sk, l[0], l[1])
		)
		if not was.is_empty():
			var slow := INF
			for i in now.size():
				var v: Vector3 = (now[i] - was[i]) / AUDIT.DT + vel
				slow = minf(slow, Vector2(v.x, v.z).length())
			shares.append(slow / spd)
		was = now
	m.set_meta(WardenClips.STATE, {})
	shares.sort()
	return shares[shares.size() / 2]
