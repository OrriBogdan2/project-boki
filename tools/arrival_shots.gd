extends RefCounted
## --arrival-shots --shots-dir=<dir>: review screenshots of the results screen and the farm on arrival
## (run under xvfb with a renderer). Full-screen PNGs: results.png, farm_welcome.png, farm_after.png.

var main: Node
var dir := ""

func _grab(file: String) -> void:
	for i in 12:
		await main.get_tree().process_frame
	await main.get_tree().create_timer(2.5).timeout      # the numbers count up, the chips pop in
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	print("ARRIVALSHOT ", file)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Snuffapi")
	k["starter"] = true
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	Save.d["name"] = "Vex"
	Save.d["tutorial"] = {"hatched": true, "intro": true}
	main.show_screen("results", {"extracted": true, "gems": 40, "seeds": {"sunroot": 2},
			"caught": [Save.new_kin("puddlet")], "knocks": 3, "damage": 1240, "taken": 388, "kills": 2,
			"downs": 1, "revives": 0, "time": 552.0, "kin_trust": 60.0})
	await _grab("results")
	Save.d["tutorial"] = {"hatched": true, "intro": true}
	var home = await main._hb_home()
	await _grab("farm_welcome")
	home._close_panel()
	await _grab("farm_after")
	main.get_tree().quit()
