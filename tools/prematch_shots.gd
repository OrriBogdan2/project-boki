extends RefCounted
## --prematch-shots --shots-dir=<dir>: the pre-match pick screen as a fresh save (four 'Start here' tags, Vex
## selected) and as a save with 3 matches (no tags), on a renderer (xvfb).

const SPLASH_WAIT := 8.0      # seconds: the title splash covers the screen for the first moments

func run(main: Node) -> void:
	Save.no_write = true
	var dir := "."
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var d := Save.fresh()
	d["name"] = "Tester"
	Save.d = d
	ClassUnlock.choose_starters(["gunslinger"])
	await _shot(main, dir.path_join("pick_fresh.png"))
	d["matches"] = 3
	await _shot(main, dir.path_join("pick_3_matches.png"))
	main.get_tree().quit(0)

func _shot(main: Node, file: String) -> void:
	var view: Control = load("res://scripts/ui/prematch_view.gd").new()
	view.setup({"teams": 10, "squad": 1, "tier": 0})
	main.add_child(view)
	await main.get_tree().create_timer(SPLASH_WAIT).timeout
	main.get_viewport().get_texture().get_image().save_png(file)
	view.set_process(false)
	view.queue_free()
