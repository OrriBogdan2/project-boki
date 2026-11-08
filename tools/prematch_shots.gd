extends RefCounted
## --prematch-shots --shots-dir=<dir>: the pre-match lobby at the window's size, three moments (full
## 30 s, 4 s left in the red pulse, locked in), as <dir>/<W>x<H>_<moment>.png. Run once per size with a
## real renderer: godot -- --prematch-shots --size=1280x720 --shots-dir=out (--size resizes the window).

const MOMENTS := [["full", 30.0], ["red", 4.0], ["locked", 0.0]]

func run(main: Node) -> void:
	Save.no_write = true
	var dir := "prematch_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			main.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	var opts := {"teams": 10, "squad": 2, "tier": 0}
	Prematch.deal_mates(opts)
	var view: Control = load("res://scripts/ui/prematch_view.gd").new()
	view.setup(opts)
	main.add_child(view)
	var tree := main.get_tree()
	await main.fade.reveal(0.01)      # the boot splash stays up when a tool opens a screen by hand
	await tree.create_timer(0.5).timeout      # let the window settle at its size
	for m in MOMENTS:
		view.pm.left = m[1]
		for i in 20:
			await tree.process_frame
		var win := main.get_window().size
		var path := dir.path_join("%dx%d_%s.png" % [win.x, win.y, m[0]])
		main.get_viewport().get_texture().get_image().save_png(path)
		print("PREMATCHSHOT ", path)
	tree.quit()
