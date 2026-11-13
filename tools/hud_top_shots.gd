extends RefCounted
## --hud-top-shots --shots-dir=<dir>: the HUD's top row (squad counters top right, the match clock under
## the minimap top left) in a live match at the window's size, in the states that crowd it: the start,
## a long skiff line, and big counts (run under xvfb with a real renderer). Files are <dir>/<WxH>_<what>.png.

var main: Node
var dir := "/tmp/hud_top_shots"

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 3, "total": 12, "tier": 0, "seed": 7, "no_drop": true, "god": true})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	for i in 600:
		m.step(Match.DT)
	await _shot(m, "start")
	m.player.kills = 12
	m.player.knocks = 14
	m.player.gems = 1666
	m.time = m.length - 20.0
	await _shot(m, "big_counts_late")
	m.time = 3.0
	m.length = 99999.0
	await _shot(m, "long_match")
	main.get_tree().quit(0)

func _shot(m: Match, what: String) -> void:
	for i in 3:
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	var sz := img.get_size()
	img.crop(sz.x, 300)
	img.save_png(dir.path_join("%dx%d_%s.png" % [sz.x, sz.y, what]))
