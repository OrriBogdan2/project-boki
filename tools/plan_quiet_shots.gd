extends RefCounted
## --plan-quiet-shots --shots-dir=<dir>: the planning map (UI_FIRST15 5.4) on a real GPU
## (jobq submit --needs gpu): <dir>/quiet_match1.png (a new player), <dir>/info_match1.png (the
## legend key pressed) and <dir>/full_match4.png (from match 4, the screen as it was before).

var main: Node
var m: Match
var dir := ""

func _grab(file: String) -> void:
	for i in 20:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	print("PLANSHOT ", file)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 6, "squad": 3, "tier": 0, "seed": 77})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	m.hud.open_map(true)
	await _grab("quiet_match1")
	m.hud.full_map.info = true
	await _grab("info_match1")
	m.hud.full_map.info = false
	Save.d["matches"] = PlanQuiet.QUIET_MATCHES
	await _grab("full_match4")
	main.get_tree().quit(0)
