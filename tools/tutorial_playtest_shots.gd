extends RefCounted
## --tutorial-playtest-shots --shots-dir=<dir>: the owner's playtest spots as real-renderer screenshots (run on a GPU
## worker): the lookout (a crouch at its far edge), the Boki send with its camp in the open, and the marker's
## arrow with its label (the glove's "Glove", which used to read as "love"), each at 1280x720 and 1920x1080.
## Files are <dir>/<WxH>_<what>.png.

const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const EDGE_R := 3.3       # m from the lookout's middle: its far edge
const GUARD := 6000       # ticks of 2 sim steps before a step counts as never reached

var main: Node
var m: Match
var dir := "/tmp/tutplay_shots"
var n := 0


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
	m.tut.ack()
	await _drive_to("crouch")
	var tu := m.tut
	var edge := tu.stop("crouch") + Vector3(EDGE_R, 0.0, 0.0)
	m.player.teleport(Vector3(edge.x, m.world.ground_at(edge.x, edge.z), edge.z))
	for i in 40:
		m.player.inp["crouch"] = true
		m.step(Match.DT)
	await _shot("lookout_crouch")
	await _drive_to("gkey")
	for i in 40:
		m.step(Match.DT)
	await _shot("gkey_camp")
	await _drive_to("glove")
	for i in 24:
		m.step(Match.DT)
	await _shot("arrow_glove")
	print("TUTPLAYSHOTS %d in %s" % [n, dir])
	main.get_tree().quit(0)


func _drive_to(sid: String) -> void:
	var guard := 0
	while guard < GUARD and m.tut.id() != sid and not m.player.extracted:
		guard += 1
		TutorialDrive.drive(m)
		for i in 2:
			m.step(Match.DT)
		if guard % 4 == 0:
			await main.get_tree().process_frame
	m.cam.snap(m.player.pos)


func _shot(what: String) -> void:
	for sz: Vector2i in SIZES:
		main.get_window().size = sz
		for i in 4:
			await main.get_tree().process_frame
		m.cam.snap(m.player.pos)
		await RenderingServer.frame_post_draw
		var img := main.get_viewport().get_texture().get_image()
		n += 1
		img.save_png(dir.path_join("%dx%d_%s.png" % [img.get_width(), img.get_height(), what]))
