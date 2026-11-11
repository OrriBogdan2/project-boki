extends RefCounted
## --results-stage-check: the squad stage behind the results card (ResultsStage). Every Hunter has a win and a lose
## beat its GLB plays (WardenBeats). In a squad that got out every Hunter plays its own win beat with its Boki beside
## it; in one that did not, a Hunter still in plays its lose beat with no Boki and one that got out its win; the
## eliminated are dimmed Wisps either way; a Hunter whose GLB has no clips stands in its idle. A trio, a duo and a
## solo load and free all their models with the screen.
## --results-stage-shots --shots-dir=<dir>: the results screen for a trio that got out and one that did not (needs a
## renderer).

## [the squad got out, its Hunters, each one's fate, what each one plays: its "win" or "lose" beat, or a "wisp"]
const CASES := [
	[true, ["gunslinger", "juggernaut", "tender"], ["left", "left", "in"], ["win", "win", "win"]],
	[true, ["archer", "dolm"], ["left", "out"], ["win", "wisp"]],
	[true, ["mage"], ["left"], ["win"]],
	[false, ["ashwick", "rimewright", "thief"], ["out", "left", "in"], ["wisp", "win", "lose"]],
	[false, ["dredge", "ostra", "bulwark"], ["in", "in", "in"], ["lose", "lose", "lose"]],
	[false, ["gunslinger", "juggernaut", "tender"], ["out", "out", "out"], ["wisp", "wisp", "wisp"]],
	[false, ["gil"], ["in"], ["idle"]],
]
const SETTLE_FRAMES := 4     # frames after the last model stands, for its clips to pick the beat

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
		_beats_exist()
		await _stages(main)
		await _screen(main)
		print("RESULTSTAGE DONE, failures: %d" % bad)
	tree.quit()

## A squad of `archs`, each with its Boki; `fates` gives each one "in", "out" (eliminated) or "left" (got out).
func _squad(archs: Array, fates: Array = []) -> Array:
	var out: Array = []
	for i in archs.size():
		var fate := String(fates[i]) if i < fates.size() else "in"
		out.append({"arch": archs[i], "name": "H%d" % i, "you": i == 0, "kin": Save.new_kin("zapple"),
				"eliminated": fate == "out", "extracted": fate == "left"})
	return out

## Every Hunter whose GLB has clips has a win and a lose beat among them. A GLB without clips (Gil's, today) has
## no beats: HunterAnim poses its rig, and the stage stands it in its idle (the "idle" case).
func _beats_exist() -> void:
	var bad_before := bad
	var clipless: Array = []
	for id in Arch.ORDER:
		var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "",
				PlayerLook.neutral(), id)
		var sync := model.get_node_or_null("Warden/Sync") as WardenGlb.Sync
		if sync == null or sync.clips == null:
			clipless.append(id)
		else:
			var win: Dictionary = sync.clips.beats.get("win", {})
			var lose: Dictionary = sync.clips.beats.get("lose", {})
			ok(not win.is_empty() and not lose.is_empty(),
					"%s: win %s, lose %s" % [id, win.get("clip", "-"), lose.get("clip", "-")])
		model.free()
	var with_clips := Arch.ORDER.size() - clipless.size()
	ok(bad == bad_before and with_clips > 0,
			"all %d Hunters with clips have a win and a lose beat (no clips: %s)" % [with_clips, ", ".join(clipless)])

## What a model on the stage plays: "wisp" for a dimmed Wisp; its "win" or "lose" when the state asks for that
## beat and the clip on the beat's channel is the beat's own clip; "idle" for a model without clips that HunterAnim
## stands in its idle; "" otherwise.
func _playing(node: Node3D) -> String:
	var mat := node.get_meta("mat") as ShaderMaterial if node.has_meta("mat") else null
	if mat != null and mat.shader == WispLook.SHADER:
		var dim := is_equal_approx(float(mat.get_shader_parameter("glow")), ResultsStage.WISP_DIM_GLOW)
		return "wisp" if dim else "bright wisp"
	var beat := String((node.get_meta(WardenClips.STATE, {}) as Dictionary).get("beat", ""))
	var sync := node.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	if sync == null or sync.clips == null:
		return "idle" if beat != "" else ""
	var clips := sync.clips
	if not clips.beats.has(beat):
		return ""
	var b: Dictionary = clips.beats[beat]
	var on := clips.cur_u if bool(b["upper"]) else clips.cur
	return beat if on == String(b["clip"]) else ""

func _built(st: ResultsStage, n: int) -> bool:
	for k in 900:
		if st.built >= n:
			return true
		await tree.process_frame
	return false

## Each case's stage: what every member plays, a Boki beside each winner, and every model freed with the stage.
func _stages(main: Node) -> void:
	for c: Array in CASES:
		var archs: Array = c[1]
		var want: Array = c[3]
		var label := "%s, %s" % ["got out" if c[0] else "did not", ", ".join(c[2])]
		var st := ResultsStage.make(_squad(archs, c[2]), c[0])
		main.add_child(st)
		var got: bool = await _built(st, archs.size())
		for k in SETTLE_FRAMES:
			await tree.process_frame
		var plays: Array = []
		plays.resize(archs.size())
		plays.fill("")
		for pair: Array in st._bodies:
			plays[pair[0]] = _playing(pair[1])
		ok(got and plays == want, "%s: plays %s (want %s)" % [label, ", ".join(plays), ", ".join(want)])
		ok(st._kins.size() == want.count("win"), "%s: %d Boki, one beside each winner" % [label, st._kins.size()])
		var nodes: Array = st._bodies.map(func(b): return b[1]) + st._kins
		st.queue_free()
		await tree.process_frame
		await tree.process_frame
		var freed: bool = nodes.all(func(n): return not is_instance_valid(n))
		ok(freed, "%s: closing frees all %d models" % [label, nodes.size()])

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
		var fates: Array = ["left", "left", "in"] if won else ["out", "in", "in"]
		main.show_screen("results", {"extracted": won, "squad": _squad(["gunslinger", "juggernaut", "tender"], fates)})
		for k in 90:
			await tree.process_frame     # (past the fade)
		var boxes: Array = main.find_children("*", "SubViewportContainer", true, false)
		var stages: Array = boxes.filter(func(c): return c is ResultsStage)
		await _built(stages[-1], 3)
		for n in 2:
			await RenderingServer.frame_post_draw
			var file := "%s_%d.png" % ["extracted" if won else "lost", n]
			main.get_viewport().get_texture().get_image().save_png(out.path_join(file))
			for k in 120:
				await tree.process_frame
	print("RESULTS_STAGE_SHOTS_DONE")
