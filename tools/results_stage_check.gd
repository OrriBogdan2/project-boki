extends RefCounted
## --results-stage-check: the squad stage behind the results card (ResultsStage). One row per Hunter of
## content/rules/results_pose.json: a duo of it (one got out, one did not) plays its own win and lose beat
## (WardenBeats) once, the second STAGGER s after the first, then cross-fades into its pose (an existing clip of its
## GLB, held inside it) with the clips owning the body all the way (no rest pose, no snap) and no fallback warning.
## Gil (no clips) falls back to the rig idle with a warning. A trio that got out loads three Hunters and their Boki
## and frees them all when the screen closes; one or two left work the same; an eliminated squad is Wisps.
## --results-stage-shots --shots-dir=<dir>: a winning and a losing trio, three frames each across the beats
## (needs a renderer).

var bad := 0
var tree: SceneTree

func ok(cond: bool, what: String) -> void:
	print("RESULTSTAGE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node, mode := "check") -> void:
	tree = main.get_tree()
	Save.no_write = true
	Save.d = Save.fresh()
	if mode == "shots":
		await _shots(main)
	else:
		Engine.time_scale = 3.0     # (the beats play out three times faster: the same frames, sooner)
		for id in ResultsStage.poses():
			if not id.begins_with("_"):
				await _row(main, id)
		await _no_clips(main)
		await _stages(main)
		await _screen(main)
		print("RESULTSTAGE DONE, failures: %d" % bad)
	tree.quit()

func _squad(archs: Array, kin := true, flags: Array = []) -> Array:
	var out: Array = []
	for i in archs.size():
		var m := {"arch": archs[i], "name": "H%d" % i, "you": i == 0, "kin": Save.new_kin("zapple") if kin else {}}
		if i < flags.size():
			m.merge(flags[i])
		out.append(m)
	return out

## One Hunter's row: a lost duo of it, the first got out itself (win), the second not (lose), both standing.
func _row(main: Node, id: String) -> void:
	ResultsStage.warned.clear()
	var st := ResultsStage.make(_squad([id, id], true, [{"extracted": true, "eliminated": false},
			{"extracted": false, "eliminated": false}]), false)
	main.add_child(st)
	var why := []
	if not await _built(st, 2) or st._plays.size() != 2:
		why.append("not built")
	var seen := [false, false]
	var low := 1.0       # the least the clips owned the body once a beat was on
	for k in 1200:
		if why.size() > 0 or st._plays.all(func(p): return p["settled"] and p["clips"].xf == float(p["clips"].chan)):
			break
		for j in 2:
			var p: Dictionary = st._plays[j]
			var c: WardenClips = p["clips"]
			if not c.beats.has(p["beat"]):
				continue
			if c.cur == String(c.beats[p["beat"]]["clip"]) and c.act_w >= 1.0:
				seen[j] = true     # (from here: the ease in from the idle is over, the handoff is still to come)
			if seen[j]:
				low = minf(low, c.act_w * (1.0 - c.proc_w))
		await tree.process_frame
	var beats := ["win", "lose"]
	for j in 2 if why.is_empty() else 0:
		var p: Dictionary = st._plays[j]
		var c: WardenClips = p["clips"]
		var pose: Dictionary = ResultsStage.poses()[id]
		if p["beat"] != beats[j] or not c.beats.has(beats[j]):
			why.append("no %s beat" % beats[j])
		elif not seen[j]:
			why.append("%s never played" % beats[j])
		if not c.lib.has_animation(String(pose["clip"])) or float(pose["t"]) > c.lib.get_animation(String(pose["clip"])).length:
			why.append("pose %s not in its clips" % pose["clip"])
		elif not p["settled"] or c.cur != String(pose["clip"]) or c.xf != float(c.chan):
			why.append("%s never settled into %s" % [beats[j], pose["clip"]])
	if why.is_empty():
		var gap: float = st._plays[1]["at"] - st._plays[0]["at"]
		if gap < ResultsStage.STAGGER - 0.001 or gap > ResultsStage.STAGGER * 2.0:
			why.append("stagger %.2f s" % gap)
		if low < 0.99:
			why.append("clips let go of the body (%.2f)" % low)
		if not ResultsStage.warned.is_empty():
			why.append("warned %s" % str(ResultsStage.warned))
	var pose: Dictionary = ResultsStage.poses()[id]
	ok(why.is_empty(), "%s: win %s, lose %s, %.2f s apart, then holds %s at %s s%s" % [id,
			_clip_of(st, 0, "win"), _clip_of(st, 1, "lose"), ResultsStage.STAGGER, pose["clip"], pose["t"],
			"" if why.is_empty() else " -- " + ", ".join(why)])
	st.queue_free()
	await tree.process_frame

func _clip_of(st: ResultsStage, j: int, beat: String) -> String:
	if j >= st._plays.size():
		return "-"
	var c: WardenClips = st._plays[j]["clips"]
	return String(c.beats[beat]["clip"]) if c.beats.has(beat) else "-"

## A Hunter whose GLB has no clips (Gil): its rig idle, with a warning, and the stage still frees it.
func _no_clips(main: Node) -> void:
	ResultsStage.warned.clear()
	var st := ResultsStage.make(_squad(["gil"]), true)
	main.add_child(st)
	var got: bool = await _built(st, 1)
	var warned := ResultsStage.warned.any(func(w): return w[0] == "gil")
	ok(got and warned and st._anims.size() == 1 and st._plays.is_empty(),
			"gil (no clips): stands in its rig idle, warned %s" % str(ResultsStage.warned))
	st.queue_free()
	await tree.process_frame

func _built(st: ResultsStage, n: int) -> bool:
	for k in 900:
		if st.built >= n:
			return true
		await tree.process_frame
	return false

func _stages(main: Node) -> void:
	for archs in [["gunslinger", "juggernaut", "tender"], ["archer", "dolm"], ["mage"]]:
		var st := ResultsStage.make(_squad(archs), true)
		main.add_child(st)
		var got: bool = await _built(st, archs.size())
		var full: bool = st._bodies.size() == archs.size() and st._kins.size() == archs.size()
		ok(got and full, "%d left: %d Hunters and Boki on the stage" % [archs.size(), st._bodies.size()])
		var nodes: Array = st._bodies.map(func(b): return b[1]) + st._kins
		var held := false
		for k in 900:
			held = st._plays.size() == archs.size() and st._plays.all(func(p): return p["settled"] \
					and p["clips"].force.has("clip") and p["beat"] == "win")
			if held:
				break
			await tree.process_frame
		ok(held, "%d left: every Hunter plays its win beat, then holds its pose" % archs.size())
		st.queue_free()
		await tree.process_frame
		await tree.process_frame
		var freed: bool = nodes.all(func(n): return not is_instance_valid(n))
		ok(freed, "%d left: closing frees all %d models" % [archs.size(), nodes.size()])
	var gone := ResultsStage.make(_squad(["gunslinger", "juggernaut", "tender"]), false)
	main.add_child(gone)
	var got: bool = await _built(gone, 3)
	var wisps: bool = gone._bodies.all(func(b): return b[1].has_node("Body") and not b[1].has_node("Rig"))
	ok(got and wisps and gone._kins.is_empty(), "an eliminated trio is three Wisps, no Hunters, no Boki")
	gone.queue_free()
	await tree.process_frame
	var lost := ResultsStage.make(_squad(["gunslinger", "juggernaut", "tender"], true, [{"eliminated": false},
			{"eliminated": true}, {"eliminated": false}]), false)
	main.add_child(lost)
	got = await _built(lost, 3)
	var losing: bool = lost._plays.size() == 2 and lost._plays.all(func(p): return p["beat"] == "lose")
	ok(got and losing and lost._kins.is_empty(), "a lost trio, one eliminated: two lose beats, one Wisp, no Boki")
	lost.queue_free()
	await tree.process_frame

## The results screen itself: it carries the stage, and the stage goes with it.
func _screen(main: Node) -> void:
	var R = load("res://scripts/ui/results.gd")
	var trio := _squad(["gunslinger", "tender", "dolm"])
	for r in [{"extracted": true, "squad": trio}, {"extracted": false, "squad": []}, {"extracted": true}]:
		var scr = R.new()
		main.add_child(scr)
		scr.show_result(r)
		var stages: Array = scr.get_children().filter(func(c): return c is ResultsStage)
		var count: int = (r.get("squad", []) as Array).size()
		ok(stages.size() == 1, "results (extracted %s, %d in squad) carries one stage" % [r["extracted"], count])
		await tree.create_timer(0.5).timeout
		scr.queue_free()
		await tree.process_frame
		await tree.process_frame
		ok(stages[0] == null or not is_instance_valid(stages[0]), "closing results frees the stage")

func _shots(main: Node) -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	main.get_window().size = Vector2i(1280, 720)
	for k in 240:
		await tree.process_frame     # (past the boot's loading screen)
	var flags := [{"eliminated": false}, {"eliminated": false}, {"eliminated": false}]
	for won in [true, false]:
		main.show_screen("results", {"extracted": won, "squad": _squad(["gunslinger", "juggernaut", "tender"], true, flags)})
		for k in 90:
			await tree.process_frame     # (past the fade)
		var boxes: Array = main.find_children("*", "SubViewportContainer", true, false)
		var stages: Array = boxes.filter(func(c): return c is ResultsStage)
		var st: ResultsStage = stages[-1]
		await _built(st, 3)
		for n in 3:
			for k in 600:     # (frames at 0.25 s into the beats, 1.0 s, and settled)
				if [st._beat_t >= 0.25, st._beat_t >= 1.0, st._plays.all(func(p): return p["settled"])][n]:
					break
				await tree.process_frame
			if n == 2:
				await tree.create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			var file := "%s_%d.png" % ["won" if won else "lost", n]
			main.get_viewport().get_texture().get_image().save_png(out.path_join(file))
	print("RESULTS_STAGE_SHOTS_DONE")
