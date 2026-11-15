extends RefCounted
## --foot-slide-check [--wardens=a,b]: planted-foot slip over the whole locomotion blend (docs/art/FOOT_SLIDE.md).
## --anim-audit reads three forward speeds; between the walk and run rings the two clips blend and can slide far
## more. Per Hunter with stepping legs this poses the real model (WardenClips through Warden/Sync) moving forward,
## back, left and right at 0 m/s, every 0.5 m/s, and its run speed from content/rules/hunter_move.json, and measures
## how fast a planted foot moves against the ground (m/s: the body's velocity plus the foot's own, flat).
## Prints one SLIP line per Hunter and direction; FAIL when a Hunter's worst slip passes its bar in BAR.

const AUDIT := preload("res://tools/anim_audit.gd")
const STEP := 0.5            # m/s between swept speeds
const WARM_S := 2.4          # s at a speed before sampling: three of WardenGait.MEAN_TAU, so the stride has settled
const SAMPLE_S := 6.0        # s sampled a speed: walk and run loops of unequal length drift through ~3 phase beats
const WOBBLE := 0.2          # rad: the aim's sway (0.7 Hz) while a run-and-aim Hunter runs 90 deg off it
const WOBBLE_HZ := 0.7
const DIRS := {"f": Vector3(0, 0, -1), "b": Vector3(0, 0, 1), "l": Vector3(-1, 0, 0), "r": Vector3(1, 0, 0)}
## m/s: the worst mean planted-foot slip each Hunter may show anywhere in the sweep, the measured worst of the
## FOOT_SLIDE.md "after" table rounded up to 0.05 (the sweep is deterministic: no physics, fixed steps).
## (archer stays at 1.75: its forward loop slides 4.4 m/s on main too since its clips changed, an open item.)
const BAR := {"archer": 1.75, "juggernaut": 1.0, "gunslinger": 1.0, "bulwark": 1.35, "ashwick": 1.4, "tender": 1.05,
		"dolm": 2.7, "dredge": 0.95, "mage": 1.55, "thief": 1.5}
## m/s: a run-and-aim ("loco.aim_twist") Hunter running at its run speed 90 deg off an aim that sways WOBBLE: each sway
## across the turn-round margin swung the legs from the forward run to the back run and the feet dragged (Vex 3.30
## m/s with the 0.1 rad default margin, 0.97 with her "twist_hyst" 0.35; owner bug 11-15). A Hunter without a bar
## only prints its WOBBLE line (Lace `archer` and Cinder `ashwick` keep the default margin: open, FOOT_SLIDE.md).
const WOBBLE_BAR := {"gunslinger": 1.0}

var bad := 0
var holder: Node3D

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
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)     # (only the fixed steps below move the clips: a real frame's dt would shift their phase)
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
		print("FAIL %s: a planted foot slips %.2f m/s (%s at %.2f m/s), bar %.2f" % [id, worst[0], worst[1],
				worst[2], BAR[id]])
		bad += 1
	if clips.twist_on:
		var wob := _slip(m, sync, clips, sk, Vector3(-run_speed, 0, 0), WOBBLE)
		print("WOBBLE %-10s %.2f m/s (run %.2f m/s 90 deg off the aim, sway %.2f rad)" % [id, wob, run_speed, WOBBLE])
		if WOBBLE_BAR.has(id) and wob > float(WOBBLE_BAR[id]):
			print("FAIL %s: running 90 deg off a swaying aim a planted foot slips %.2f m/s, bar %.2f" % [id, wob,
					WOBBLE_BAR[id]])
			bad += 1
	m.free()
	return true

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
	m.set_meta(WardenClips.STATE, {"vel": vel, "face": 0.0, "grounded": true})
	clips.loco_pos = Vector2.ZERO
	for k in int(WARM_S / AUDIT.DT):
		sync.call("_process", AUDIT.DT)
	var fr: Array = []
	var faces: Array = []
	for k in int(SAMPLE_S / AUDIT.DT):
		var face := sway * sin(TAU * WOBBLE_HZ * k * AUDIT.DT)
		m.set_meta(WardenClips.STATE, {"vel": vel, "face": face, "grounded": true})
		faces.append(face)
		sync.call("_process", AUDIT.DT)
		fr.append(AUDIT.points(sk))
	m.set_meta(WardenClips.STATE, {})
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
