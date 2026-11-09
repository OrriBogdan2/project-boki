extends RefCounted
## --prematch-shots --size=WxH --shots-dir=<dir>: the pre-match lobby at the window's size, before and after
## the first chat line, as <dir>/<W>x<H>_<moment>.png, and the controls outside the safe margin. Run once per
## size with a real renderer: godot -- --prematch-shots --size=1280x720 --shots-dir=out

const MARGIN := 36.0      # px, the screen's edge padding: nothing may sit closer to the edge than this

## The visible controls under `node` (not its frame) that stick out of `area` less MARGIN, as "Class at rect".
func outside(node: Node, area: Rect2) -> Array:
	var safe := area.grow(-MARGIN + 1.0)
	var bad: Array = []
	for c in node.find_children("*", "Control", true, false):
		var inside := safe.encloses(c.get_global_rect())
		if c.get_parent() != node and c.is_visible_in_tree() and c.size.x > 0.0 and not inside:
			bad.append("%s at %s" % [c.get_class(), c.get_global_rect()])
	return bad

func run(main: Node) -> void:
	Save.no_write = true
	var classes := ClassUnlock.fresh()      # a new player: Vex open, the rest shut
	classes["picks"] = ["gunslinger"]
	classes["open"] = ["gunslinger"]
	Save.d = Save.fresh()
	Save.d["arch"] = "gunslinger"
	Save.d["name"] = "Ember"
	Save.d["classes"] = classes
	var dir := "prematch_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			main.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	var opts := {"teams": 10, "squad": 3, "tier": 0}
	Prematch.deal_mates(opts)
	var view: Control = load("res://scripts/ui/prematch_view.gd").new()
	view.setup(opts)
	main.add_child(view)
	var tree := main.get_tree()
	await main.fade.reveal(0.01)      # the boot splash stays up when a tool opens a screen by hand
	await tree.create_timer(0.5).timeout      # let the window settle at its size
	for moment in ["pick", "chat"]:
		if moment == "chat":
			view._add_chat("Ember", "push north, I hold the ridge", UI.INK)
		for i in 20:
			await tree.process_frame
		var win := main.get_window().size
		var path := dir.path_join("%dx%d_%s.png" % [win.x, win.y, moment])
		main.get_viewport().get_texture().get_image().save_png(path)
		var bad := outside(view, Rect2(Vector2.ZERO, Vector2(win)))
		print("PREMATCHSHOT %s outside the safe area: %d %s" % [path, bad.size(), bad.slice(0, 3)])
	tree.quit()
