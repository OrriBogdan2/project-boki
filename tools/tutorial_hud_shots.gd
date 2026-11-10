extends RefCounted
## --tutorial-hud-shots --shots-dir=<dir>: the first moments of the tutorial as screenshots (run with a
## real renderer, e.g. xvfb-run --rendering-driver opengl3 --resolution 1280x720): the intro card,
## the drop, the landing, and the first moments of the dash, the lookout, the shoot, the Boki and the
## fight steps. Files are <dir>/<WxH>_NN_<what>.png.

var main: Node
var m: Match
var dir := "/tmp/tuthud_shots"
var n := 0

const WATCHED := ["move", "dash", "shoot", "sig", "throw", "fight", "chest", "extract"]

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	await _shot("intro")
	await _frames(30)
	await _shot("intro_late")
	m.tut.ack()
	var seen := {}
	var times := [0.4, 1.2, 2.5, 4.0, 6.0, 9.0, 13.0, 18.0]
	var guard := 0
	while guard < 6000 and m.tut.step < 24 and not m.player.extracted:
		guard += 1
		TutorialDrive.drive(m)
		for i in 2:
			m.step(Match.DT)
		m.cam.snap(m.player.pos)
		var tu: Tutorial = m.tut
		var sid := tu.id()
		if not times.is_empty() and m.time >= float(times[0]):
			await _shot("t%04.1f_%s" % [float(times.pop_front()), sid])
		for at in [0.4, 2.2, 6.0]:
			var key := "%s_%.1f" % [sid, at]
			if sid in WATCHED and tu.t >= at and not seen.has(key):
				seen[key] = true
				await _shot("%s_%.1fs" % [sid, at])
		if guard % 4 == 0:
			await _frames(1)
	print("TUTHUDSHOTS %d in %s" % [n, dir])
	main.get_tree().quit(0)

func _frames(k: int) -> void:
	for i in k:
		await main.get_tree().process_frame

func _shot(what: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	n += 1
	var sz := img.get_size()
	img.save_png(dir.path_join("%dx%d_%02d_%s.png" % [sz.x, sz.y, n, what]))
