extends RefCounted
## --care-prompt-shots --shots-dir=<dir>: the care line over a Boki on the farm (run on a GPU through jobq).
##   content      nothing wanted: Pick up lit, Pet and Feed greyed
##   hungry_none  hungry with no food: Pet lit, "Feed (no food)" greyed
##   hungry_food  hungry with food: Feed lit

var main: Node

func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	var first := Save.new_kin("zapple", "Pip")
	first["starter"] = true
	d["roster"].append(first)
	d["active"] = first["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(d)
	var home = await main._hb_home()
	home._close_panel()
	var k: Dictionary = home.kins[0]
	for which in ["content", "hungry_none", "hungry_food"]:
		for n in Care.NEEDS:
			k["rec"]["needs"][n] = 80.0
		k["rec"]["needs"]["food"] = 80.0 if which == "content" else 10.0
		k["rec"]["needs_t"] = Time.get_unix_time_from_system() + 9999.0
		Save.d["items"].clear()
		Save.d["crops"].clear()
		if which == "hungry_food":
			Save.d["items"][String(Care.FOODS.keys()[0])] = 2
		home.ppos = k["pos"] + Vector3(1.2, 0, 0.4)
		for i in 40:
			await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png(dir.path_join(which + ".png"))
	Save.no_write = false
	print("CAREPROMPTSHOTS in %s" % dir)
	main.get_tree().quit(0)
