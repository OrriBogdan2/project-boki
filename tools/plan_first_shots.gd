extends RefCounted
## --plan-first-shots --shots-dir=<dir>: the plan-your-drop screen (FullMap), under xvfb with a renderer:
##   plan_first   a fresh save's first expedition: the map, the timer and the jump line
##   plan_held    the same with the scoreboard key held: squad, legend and ways out
##   plan_later   a later match (today's screen)

var main: Node
var dir := ""

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _shot("plan_first", 0, false)
	await _shot("plan_held", 0, true)
	await _shot("plan_later", 2, false)
	print("PLANFIRSTSHOTS 3 in %s" % dir)
	main.get_tree().quit(0)

func _shot(file: String, had: int, held: bool) -> void:
	Save.d["first_guide"] = had
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if held: Input.action_press("scores")
	for i in 4:
		m.step(Match.DT)
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	Input.action_release("scores")
	m.queue_free()
	await main.get_tree().process_frame
