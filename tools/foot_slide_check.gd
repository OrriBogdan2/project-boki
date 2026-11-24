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
## --fit-dirs: also a FIT line per back, left, right and forward loop at the walk and run rings: the share of the body's
## speed a planted foot covers (1 = planted) and the loco foot speed (m/s) that would plant it: the one WardenGait uses
## now ("foot_mps", "back_foot_mps", "side_foot_mps") times that share. Run it twice: a clamped rate moves less.

const AUDIT := preload("res://tools/anim_audit.gd")
const STEP := 0.5  # m/s between swept speeds
const WARM_S := 2.4  # s at a speed before sampling: three of WardenGait.MEAN_TAU, so the stride has settled
const SAMPLE_S := 6.0  # s sampled a speed: walk and run loops of unequal length drift through ~3 phase beats
const WOBBLE := 0.2  # rad: the aim's sway (0.7 Hz) while a run-and-aim Hunter runs 90 deg off it
const WOBBLE_HZ := 0.7
const DIRS := {"f": Vector3(0, 0, -1), "b": Vector3(0, 0, 1), "l": Vector3(-1, 0, 0), "r": Vector3(1, 0, 0)}
## m/s: the worst mean planted-foot slip each Hunter may show anywhere in the sweep, the measured worst of the
## FOOT_SLIDE.md "after" table rounded up to 0.05 (the sweep is deterministic: no physics, fixed steps).
## (archer stays at 1.75: its forward loop slides 4.4 m/s on main too since its clips changed, an open item.)
## (juggernaut, gunslinger, dolm, mage, dredge, thief: back and strafe loops on their own --fit-dirs speeds, 11-18.)
## (rimewright 1.05: her run foot_mps 4.4 -> 5.6 at match scale read 1.28 -> 1.00, under her foot lock, 11-20.)
const BAR := {
	"archer": 1.75,
	"juggernaut": 0.95,
	"gunslinger": 1.0,
	"bulwark": 1.35,
	"rimewright": 1.05,
	"ashwick": 1.4,
	"tender": 1.05,
	"dolm": 2.7,
	"dredge": 0.75,
	"mage": 0.95,
	"thief": 1.1
}
## m/s: a run-and-aim ("loco.aim_twist") Hunter running at its run speed 90 deg off an aim that sways WOBBLE: each sway
## across the turn-round margin swung the legs from the forward run to the back run and the feet dragged (Vex 3.30
## m/s with the 0.1 rad default margin, 0.97 with her "twist_hyst" 0.35; owner bug 11-15). A Hunter without a bar
## only prints its WOBBLE line (Lace `archer` and Cinder `ashwick` keep the default margin: open, FOOT_SLIDE.md).
const WOBBLE_BAR := {"gunslinger": 1.0}
const STEP_CM := 5.0         # cm: furthest a planted foot may travel in one step of the run at its run speed
## Hunters whose STEP line prints OPEN, not FAIL: Gil plays Meeko's run retargeted onto gil.glb ("clips_from"; his
## rig pass is ANIM_COVERAGE gap 1) and no rate plants it (foot_mps 4.55 -> 5.75 moved -20.2 -> -16.6 cm, 11-20).
const STEP_OPEN := ["gil"]
const MIN_STANCE := 0.025    # s: a shorter planted spell is a scuff, not a step (3 samples)
const CONTACT_M := 0.03      # m: a sole this close to its lowest is on the ground (a sprint's swing skims ~0.1 m)
const STEP_DT := 1.0 / 120.0 # s between STEP samples: a 0.33 s run cycle plants a foot for only a few 30 fps frames
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
var fit := false


func run(main: Node) -> void:
	WardenNative.contract_only = true  # (the contract path; Meshy-native Hunters: --warden-native-check)
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var ids: Array = Arch.ORDER.duplicate()
	for a in OS.get_cmdline_user_args():
		fit = fit or a == "--fit-dirs"
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
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)  # (only the fixed steps below move the clips: a real frame's dt would shift their phase)
	for k in 5:
		await main.get_tree().process_frame
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
			var slip := _slip(m, sync, clips, sk, DIRS[dir] * s).x
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
		var wob := _slip(m, sync, clips, sk, Vector3(-run_speed, 0, 0), WOBBLE).x
		print("WOBBLE %-10s %.2f m/s (run %.2f m/s 90 deg off the aim, sway %.2f rad)" % [id, wob, run_speed, WOBBLE])
		if WOBBLE_BAR.has(id) and wob > float(WOBBLE_BAR[id]):
			print(
				(
					"FAIL %s: running 90 deg off a swaying aim a planted foot slips %.2f m/s, bar %.2f"
					% [id, wob, WOBBLE_BAR[id]]
				)
			)
			bad += 1
	if fit:
		_fit(id, m, sync, clips, sk)
	m.scale *= Hunter.VIS_SCALE
	_step_line(m, sync, clips, sk, id, HunterMove.speed(id))
	m.free()
	return true

## Prints the STEP line of the forward run at `spd` (m/s): FAIL when a planted foot travels past STEP_CM a step.
func _step_line(m: Node3D, sync: Node, clips: WardenClips, sk: Skeleton3D, id: String, spd: float) -> void:
	AUDIT.soles = AUDIT.sole_ends(sk)
	var fr := _sample(m, sync, clips, sk, DIRS["f"] * spd, 0.0, STEP_DT)[0] as Array
	AUDIT.soles = {}
	var rate := float(clips.tree.get("parameters/loco_rate/scale"))
	var cycle := clips.gait.run_len
	var st := _stance_cm(fr, spd)
	var stride: float = (spd - float(st[1])) * cycle / maxf(rate, 0.01)     # m a planted foot sweeps a cycle at rate 1
	var tris := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh as ArrayMesh
		if (mi as MeshInstance3D).is_visible_in_tree() and mesh:
			for si in mesh.get_surface_count():
				tris += int(mesh.surface_get_array_index_len(si) / 3.0)
	var fmt := "STEP %-10s %s tris %d run %.2f m/s cycle %.3f s stride %.2f m rate %.2f (%.1f steps/s) slide %+.1f"
	print((fmt + " cm/step (%d steps)") % [id, WardenGlb.path(id), tris, spd, cycle, stride, rate, 2.0 * rate / cycle,
			st[0], st[2]])
	if absf(st[0]) > STEP_CM and id in STEP_OPEN:
		print("OPEN %s: a planted foot travels %+.1f cm a step (bar %.1f, STEP_OPEN)" % [id, st[0], STEP_CM])
	elif absf(st[0]) > STEP_CM:
		print("FAIL %s: a planted foot travels %+.1f cm a step at its run speed, bar %.1f" % [id, st[0], STEP_CM])
		bad += 1

## [mean cm a planted foot travels over the ground along the run in one stance (+ forward), the mean m/s it moves
## forward while planted, stances counted]. A foot stands on the lower of its heel and toe (the ankle rolls forward
## over a stance); only whole stances count: one cut by the sample's ends is left out.
func _stance_cm(fr: Array, spd: float) -> Array:
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
				var v := spd - ((fr[i + 1][c] as Vector3).z - (fr[i - 1][c] as Vector3).z) / (2.0 * STEP_DT)
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

func _fit(id: String, m: Node3D, sync: Node, clips: WardenClips, sk: Skeleton3D) -> void:
	var lc: Dictionary = clips.d["loco"]
	var fw: Array = lc.get("foot_mps", [lc.get("walk_speed", 2.2), lc.get("run_speed", 4.6)])
	var keys := {"f": "foot_mps", "b": "back_foot_mps", "l": "side_foot_mps", "r": "side_foot_mps"}
	for dir in DIRS:
		var now: Array = lc.get(keys[dir], fw)
		var cells: Array = []
		for ring in 2:
			var s := float(lc.get("walk_speed", 2.2)) if ring == 0 else float(lc.get("run_speed", 4.6))
			if ring == 0:
				_slip(m, sync, clips, sk, Vector3.ZERO)  # (run straight to walk is a let-go: WardenStride)
			var r := _slip(m, sync, clips, sk, DIRS[dir] * s)
			var rate := float(clips.tree.get("parameters/loco_rate/scale"))
			cells.append(
				(
					"%s %.2f m/s cover %.2f rate %.2f: %.2f -> %.2f"
					% [["walk", "run"][ring], s, r.y, rate, float(now[ring]), float(now[ring]) * r.y]
				)
			)
		print("FIT %-10s %s %s  %s" % [id, dir, keys[dir], " | ".join(cells)])


## 0, every STEP, and the run speed itself.
func _speeds(run_speed: float) -> Array:
	var out: Array = []
	var s := 0.0
	while s < run_speed - 0.01:
		out.append(s)
		s += STEP
	out.append(run_speed)
	return out


## x: mean flat speed of a planted foot against the ground (m/s) while the model moves at `vel`, facing -Z; y: the
## share of `vel` a planted foot moves back against it (1 = planted, under 1 the clip steps too short); with `sway`
## (rad) the facing swings that far either way at WOBBLE_HZ (the model stays put: the feet are read in its own frame,
## so each frame's velocity is turned into it).
func _slip(m: Node3D, sync: Node, clips: WardenClips, sk: Skeleton3D, vel: Vector3, sway := 0.0) -> Vector2:
	var got := _sample(m, sync, clips, sk, vel, sway)
	var fr: Array = got[0]
	var faces: Array = got[1]
	var total := 0.0
	var back := 0.0
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
			back -= Vector2(foot_v.x, foot_v.z).dot(Vector2(v.x, v.z)) / maxf(Vector2(v.x, v.z).length_squared(), 0.01)
			n += 1
	return Vector2(total, back) / maxi(n, 1)


## [frames of AUDIT.points, the facing of each] over SAMPLE_S at `vel` after WARM_S, `dt` apart, facing -Z
## swaying `sway` (rad).
func _sample(m: Node3D, sync: Node, clips: WardenClips, sk: Skeleton3D, vel: Vector3, sway := 0.0,
		dt := AUDIT.DT) -> Array:
	m.set_meta(WardenClips.STATE, {"vel": vel, "face": 0.0, "grounded": true})
	clips.loco_pos = Vector2.ZERO
	for k in int(WARM_S / dt):
		sync.call("_process", dt)
	var fr: Array = []
	var faces: Array = []
	for k in int(SAMPLE_S / dt):
		var face := sway * sin(TAU * WOBBLE_HZ * k * dt)
		m.set_meta(WardenClips.STATE, {"vel": vel, "face": face, "grounded": true})
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
	return shares[int(shares.size() / 2.0)]
