extends RefCounted
## --results-stage-check: the squad stage behind the results card (ResultsStage). A trio that got out loads three
## Hunters (each holding the pose in content/rules/results_pose.json, an existing clip of its own GLB) and their
## Boki and frees them all when the screen closes; one or two left work the same; an eliminated squad is Wisps,
## no Hunter models. --results-stage-shots --shots-dir=<dir>: the results screen for an extracted trio and an
## eliminated one (needs a renderer).

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
		_poses_exist()
		await _stages(main)
		await _screen(main)
		print("RESULTSTAGE DONE, failures: %d" % bad)
	tree.quit()

func _squad(archs: Array, kin := true) -> Array:
	var out: Array = []
	for i in archs.size():
		out.append({"arch": archs[i], "name": "H%d" % i, "you": i == 0, "kin": Save.new_kin("zapple") if kin else {}})
	return out

## Every Hunter has a pose, and it is a clip its GLB really has, held inside the clip.
func _poses_exist() -> void:
	var bad_before := bad
	for id in Arch.ORDER:
		var p: Dictionary = ResultsStage.poses().get(id, {})
		var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "",
				PlayerLook.neutral(), id)
		var sync := model.get_node_or_null("Warden/Sync") as WardenGlb.Sync
		var lib: AnimationLibrary = sync.clips.lib if sync != null and sync.clips != null else null
		var fits := not p.is_empty() and lib != null and lib.has_animation(String(p["clip"])) \
				and float(p["t"]) <= lib.get_animation(String(p["clip"])).length
		ok(fits, "%s holds %s at %s s" % [id, p.get("clip", "-"), p.get("t", "-")])
		model.free()
	ok(bad == bad_before, "all %d Hunters have a pose" % Arch.ORDER.size())

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
		var held: bool = st._bodies.all(func(b): return b[1].get_node("Warden/Sync").clips.force.has("clip"))
		ok(held, "%d left: every Hunter holds its pose" % archs.size())
		st.queue_free()
		await tree.process_frame
		await tree.process_frame
		var freed: bool = nodes.all(func(n): return not is_instance_valid(n))
		ok(freed, "%d left: closing frees all %d models" % [archs.size(), nodes.size()])
	var gone := ResultsStage.make(_squad(["gunslinger", "juggernaut", "tender"]), false)
	main.add_child(gone)
	var got: bool = await _built(gone, 3)
	var wisps: bool = gone._bodies.all(func(b): return b[1].get_node_or_null("Tilt/Core") != null)
	ok(got and wisps and gone._kins.is_empty(), "an eliminated trio is three Wisps, no Hunters, no Boki")
	gone.queue_free()
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
	for won in [true, false]:
		main.show_screen("results", {"extracted": won, "squad": _squad(["gunslinger", "juggernaut", "tender"])})
		for k in 90:
			await tree.process_frame     # (past the fade)
		var boxes: Array = main.find_children("*", "SubViewportContainer", true, false)
		var stages: Array = boxes.filter(func(c): return c is ResultsStage)
		await _built(stages[-1], 3)
		for n in 2:
			await RenderingServer.frame_post_draw
			var file := "%s_%d.png" % ["extracted" if won else "eliminated", n]
			main.get_viewport().get_texture().get_image().save_png(out.path_join(file))
			for k in 120:
				await tree.process_frame
	print("RESULTS_STAGE_SHOTS_DONE")
