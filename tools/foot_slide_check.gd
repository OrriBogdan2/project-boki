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
const DIRS := {"f": Vector3(0, 0, -1), "b": Vector3(0, 0, 1), "l": Vector3(-1, 0, 0), "r": Vector3(1, 0, 0)}
## m/s: the worst mean planted-foot slip each Hunter may show anywhere in the sweep, the measured worst of the
## FOOT_SLIDE.md "after" table rounded up to 0.05 (the sweep is deterministic: no physics, fixed steps).
const BAR := {"archer": 1.75, "juggernaut": 2.0, "gunslinger": 1.7, "bulwark": 1.3, "ashwick": 2.4, "tender": 1.9,
		"dolm": 2.7, "dredge": 1.75, "mage": 2.1, "thief": 1.85}

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

## Mean flat speed of a planted foot against the ground (m/s) while the model moves at `vel`, facing -Z.
func _slip(m: Node3D, sync: Node, clips: WardenClips, sk: Skeleton3D, vel: Vector3) -> float:
	m.set_meta(WardenClips.STATE, {"vel": vel, "face": 0.0, "grounded": true})
	clips.loco_pos = Vector2.ZERO
	for k in int(WARM_S / AUDIT.DT):
		sync.call("_process", AUDIT.DT)
	var fr: Array = []
	for k in int(SAMPLE_S / AUDIT.DT):
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
			total += Vector2(vel.x + foot_v.x, vel.z + foot_v.z).length()
			n += 1
	return total / maxi(n, 1)
