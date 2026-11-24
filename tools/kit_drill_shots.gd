extends RefCounted
## --kit-drill-shots --size=WxH --shots-dir=<dir>: the Training Grounds as a first-time player sees it (banner, key
## line, first kit drill card), one frame per size. GPU, under xvfb with a renderer. The card must not cover the banner.

func run(main: Node) -> void:
	var dir := "kit_drill_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			main.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["arch"] = "gunslinger"
	d["cls"] = Arch.weight("gunslinger")
	d["classes"] = ClassUnlock.legacy()
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"training": true, "practice": true})
	if main.fade != null:
		await main.fade.reveal(0.01)
	await main.get_tree().create_timer(1.0).timeout
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("%dx%d.png" % [img.get_width(), img.get_height()]))
	print("KITDRILL-SHOT ", img.get_size())
	main.get_tree().quit()
