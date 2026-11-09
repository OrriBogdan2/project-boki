extends "res://tools/vv_shots.gd"
## --gear-reveal-shots --shots-dir=<dir>: the bottom-right HUD at 1280x720 and 1920x1080 in a live
## match (xvfb with a renderer): a new hunter (nothing worn or carried), one armor piece and one
## tonic, and the same with the info key (Tab) held. <dir>/captions.txt gets "file: caption" per file.

const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]

func run(main_node: Node) -> void:
	main = main_node
	who = "gunslinger"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var armor: String = Gear.ids_for(2)[0]
	var tonic: String = UtilityBelt.stock_ids()[0]
	for sz in SIZES:
		main.get_window().size = sz
		await main.get_tree().process_frame
		P.gear = Gear.empty_slots()
		P.belt = UtilityBelt.empty()
		await _go(0.6, Callable(), [[0.5, "full", "%d_new" % sz.y, "%dp: a new hunter, nothing worn or carried" % sz.y]])
		P.gear[2] = {"id": armor, "rar": 1}
		P.belt[0] = {"id": tonic, "n": 2}
		await _go(0.6, Callable(), [[0.5, "full", "%d_one" % sz.y, "%dp: one armor piece and one tonic" % sz.y]])
		Input.action_press("scores")
		await _go(0.6, Callable(), [[0.5, "full", "%d_held" % sz.y, "%dp: the same with the info key held" % sz.y]])
		Input.action_release("scores")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		var cols := String(l).split("|")
		f.store_line("%s: %s" % [cols[1], cols[2]])
	f.close()
	print("GEARSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)
