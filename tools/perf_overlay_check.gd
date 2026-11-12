extends RefCounted
## --perf-overlay-check: Settings > Video > Frame rate. "Performance overlay" shows the frame rate, frame time
## and 1% low, draw calls and triangles, and the match step's costliest sections (and switches their timing on);
## "Frame rate" is the rate alone; "Hidden" hides it and switches the timing off again.

var main: Node
var fails := 0

func ok(cond: bool, what: String) -> void:
	print("PERFOVERLAY %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Game.goto("match", Match.arena_opts())
	while not (main.current is Match and (main.current as Match).is_processing()):
		await main.get_tree().process_frame
	var lbl: PerfOverlay = Overlay.fps_lbl
	Settings.set_v("show_fps", 2, false)
	await main.get_tree().create_timer(1.5).timeout
	ok(lbl.visible and Match.prof_on, "the overlay shows and times the match step")
	for want in ["fps", "1% low", "draws", "tris", "script", "step ms"]:
		ok(lbl.text.contains(want), "it lists %s (%s)" % [want, lbl.text.replace("\n", " | ")])
	Settings.set_v("show_fps", 1, false)
	await main.get_tree().create_timer(0.6).timeout
	var alone := lbl.visible and not lbl.text.contains("draws") and not Match.prof_on
	ok(alone, "Frame rate: the rate alone ('%s')" % lbl.text)
	Settings.set_v("show_fps", 0, false)
	for i in 3:
		await main.get_tree().process_frame
	ok(not lbl.visible and not Match.prof_on, "Hidden: nothing shows or is timed")
	ok(Settings.fps_mode() == "" and Settings.QUALITY.has("medium"), "the setting reads back")
	print("PERFOVERLAY DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)
