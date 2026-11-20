extends RefCounted
## --step-contacts-check [--wardens=a,b]: a Hero's step cue lands on its visible foot plants. Per Hero in
## content/rules/step_contacts.json, the real model (WardenClips through Warden/Sync, fixed 1/60 s frames) walks
## forward and back at its walk speed, runs forward and left at its run speed, and crouch-walks forward; each frame
## the cue is taken the way HunterAnim takes it (WardenSteps.take, before the clips advance) and the feet (Motley:
## the hips) are read after. Every cue must sit within SLACK frames of a plant of its own foot (the frame it reaches
## its lowest, found as --step-contacts-gen finds it) and every plant within SLACK of a cue. BEFORE prints how far
## the old 0.32 s running timer drifted from the same plants, for comparison (not gated). Never touches the save.

const GEN := preload("res://tools/step_contacts_gen.gd")
const SLACK := 2             # frames at 60 fps a cue may sit off its plant
const EDGE := 12             # frames at either end of a sample whose plants and cues are not judged (cut stretches)
const OLD_TIMER := 0.32      # s: the running footstep timer the cue replaced
const CASES := [["walk.f", Vector2(0, 1), "walk"], ["walk.b", Vector2(0, -1), "walk"], ["run.f", Vector2(0, 1), "run"],
		["run.l", Vector2(-1, 0), "run"], ["crouch.f", Vector2(0, 1), "crouch"]]

var bad := 0
var worst_all := 0
var holder: Node3D


func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wardens="):
			only = Array(a.substr(10).split(",", false))
	var done := {}
	for id in Arch.ids():
		var art := WardenGlb.art(id)
		if done.has(art) or WardenSteps.contacts(art).is_empty() or (not only.is_empty() and not id in only):
			continue
		done[art] = true
		await _hero(main, id)
	if done.is_empty():
		print("FAIL no Hero has a row in ", WardenSteps.TABLE)
		bad += 1
	print("STEP_CONTACTS_DONE %d Heroes, worst %d frames (slack %d) FAIL %d" % [done.size(), worst_all, SLACK, bad])
	main.get_tree().quit(1 if bad > 0 else 0)


func _hero(main: Node, id: String) -> void:
	var m: Node3D = await GEN.model(main, holder, id)
	var clips: WardenClips = m.get_node("Warden/Sync").get("clips")
	var speeds := {"walk": float(clips.d["loco"].get("walk_speed", 2.2)), "run": float(HunterMove.of(id)["speed"]),
			"crouch": float((clips.d.get("crouch", {}) as Dictionary).get("speed", 2.4))}
	for c in CASES:
		if c[2] == "crouch" and not clips.d.has("crouch"):
			continue
		var st := GEN.moving(c[1], float(speeds[c[2]]), c[2] == "crouch")
		_case(WardenGlb.art(id), String(c[0]), GEN.sample(m, clips, st, clips.steps), GEN.tracked(clips) == ["hips"])
	m.free()


## Judges one case: each cue against its own bone's plants, each plant against the cues of that bone.
func _case(art: String, case_name: String, got: Dictionary, hover: bool) -> void:
	var n := int(GEN.SAMPLE_S / GEN.DT)
	var worst := 0
	var missed := 0
	var plants_n := 0
	var all_plants: Array = []
	for i in (got["ys"] as Array).size():
		var plants := GEN.plants(got["ys"][i])
		var own: Array = (got["cues"] as Array).filter(func(c): return int(c[1]) == (2 if hover else i))
		var cue_frames: Array = own.map(func(c): return int(c[0]))
		for p in plants:
			all_plants.append(p)
			if p < EDGE or p >= n - EDGE:
				continue
			plants_n += 1
			var off := _nearest(cue_frames, p)
			worst = maxi(worst, off)
			missed += 1 if off > SLACK else 0
		for cf in cue_frames:
			if cf >= EDGE and cf < n - EDGE:
				var off := _nearest(Array(plants), cf)
				worst = maxi(worst, off)
				missed += 1 if off > SLACK else 0
	worst_all = maxi(worst_all, worst)
	print("STEP_CONTACTS_CHECK %-8s %-8s plants %2d cues %2d worst %2d fr  BEFORE timer worst %2d fr" % [art, case_name,
			plants_n, (got["cues"] as Array).size(), worst, _timer_drift(all_plants, n)])
	if plants_n == 0 or missed > 0:
		print("FAIL %s %s: %d cues or plants more than %d frames apart (%d plants judged)" % [art, case_name, missed,
				SLACK, plants_n])
		bad += 1


## Frames from `f` to the nearest of `frames` (a large number when there are none).
static func _nearest(frames: Array, f: int) -> int:
	var best := 9999
	for x in frames:
		best = mini(best, absi(int(x) - f))
	return best


## The old running timer started on the first plant: its worst distance (frames) to the nearest plant of either foot.
static func _timer_drift(plants: Array, n: int) -> int:
	if plants.is_empty():
		return 0
	plants.sort()
	var worst := 0
	var t := float(plants[0])
	while t < n - EDGE:
		worst = maxi(worst, _nearest(plants, roundi(t)))
		t += OLD_TIMER / GEN.DT
	return worst
