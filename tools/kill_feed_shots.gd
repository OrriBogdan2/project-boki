extends RefCounted
## --kill-feed-shots --size=WxH --shots-dir=<dir>: a real match HUD with a full kill feed (your knock, your Boki's,
## a rival squad's finish, the Blight downing your teammate) in <WxH>_screen.png, and the lane blown up to twice
## its size in <WxH>_lane.png. Prints whether every row sits inside the safe margin (GPU, under xvfb).

var main: Node

func _grab(dir: String, lane: Rect2) -> void:
	for i in 12:
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	var tag := "%dx%d" % [img.get_width(), img.get_height()]
	img.save_png(dir.path_join(tag + "_screen.png"))
	var crop := img.get_region(Rect2i(lane.grow(8.0).intersection(Rect2(Vector2.ZERO, img.get_size()))))
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png(dir.path_join(tag + "_lane.png"))
	print("KILLFEED-SHOT ", dir.path_join(tag))

func run(main_node: Node) -> void:
	main = main_node
	var dir := "kill_feed_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			main.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d.erase("hud_reveal")
	Settings.set_v("hud_full", true, false)      # (every HUD group: the staged HUD hides the feed early)
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 3, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true, "god": true,
		"length": 1e9, "demo_kin": "cindle"})
	m.set_process(false)
	if main.fade != null:
		await main.fade.reveal(0.01)
	await main.get_tree().create_timer(0.5).timeout
	var me: Hunter = m.player
	var mate: Hunter = m.hunters.filter(func(x): return x != me and x.team == me.team)[0]
	var foes: Array = m.hunters.filter(func(x): return x.team != me.team)
	var blight := Blight.new()
	KillFeed.knock(m, foes[0], me, "dash")
	KillFeed.knock(m, foes[1], me.kin, KillFeed.icon_of(me.kin, {"ab": "k1"}))
	KillFeed.out(m, foes[2], foes[3], "finished")
	KillFeed.knock(m, mate, blight, KillFeed.icon_of(blight, {}))
	for i in 20:
		m.hud.panels.queue_redraw()
		await main.get_tree().process_frame
	var lane := Rect2()
	var safe := HudStyle.safe_rect(main.get_viewport().get_visible_rect().size)
	var out := 0
	for row: Dictionary in KillFeed.shown:
		lane = row["rect"] if lane.size == Vector2.ZERO else lane.merge(row["rect"])
		out += 0 if safe.grow(0.5).encloses(row["rect"]) else 1
	print("KILLFEED rows %d, outside the safe margin: %d, lane %s" % [KillFeed.shown.size(), out, lane])
	await _grab(dir, lane)
	main.get_tree().quit()
