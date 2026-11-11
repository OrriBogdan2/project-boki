extends RefCounted
## --hushwood-shots --shots-dir=<dir>: Hushwood at noon and at midnight on the day clock (hushwood_day.png,
## hushwood_night.png). Its sky stays at dusk, so the two should match. Needs a real renderer.

func run(main: Node) -> void:
	var dir := "/tmp/hushwood_shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): dir = a.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	var d := Save.fresh()
	for i in 3:
		var rec := Save.new_kin(["zapple", "cindle", "burrlet"][i], "B%d" % i)
		Care.ensure(rec)
		rec["zone"] = "hushwood"
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	d["zones"]["hushwood"] = {"open": true}
	Save.d = d
	var home = load("res://scripts/home/home.gd").new()
	home.zone = "hushwood"
	main.add_child(home)
	main.current = home
	for i in 900:
		if home.root_ui != null and home.player != null and home.hb != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	if main.fade: main.fade.reveal(0.05)
	for shot in [["day", 0.5], ["night", 0.0]]:
		home.day_t = shot[1]
		await main.get_tree().create_timer(1.5).timeout
		var img := main.get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("hushwood_%s.png" % shot[0]))
		print("HUSHWOOD_SHOT ", shot[0])
	main.get_tree().quit()
