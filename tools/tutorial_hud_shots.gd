extends RefCounted
## --tutorial-hud-shots --shots-dir=<dir>: the first moments of the tutorial as screenshots (run with a
## real renderer, e.g. xvfb-run --rendering-driver opengl3 --resolution 1280x720): the intro card,
## the drop, the landing, and each beat after it: the point, every forced pick (its gold ring), each camp
## and the move it teaches, the wall kick, the lookout, the glove, the fuse, the ranks and the way out.
## --arch=<id> plays it as that hero (a starter: archer, juggernaut, gunslinger), else the save's.
## Files are <dir>/<WxH>_NN_<what>.png.

var main: Node
var m: Match
var dir := "/tmp/tuthud_shots"
var n := 0

const WATCHED := ["points", "pick_sec", "sec", "shoot", "pick_dash", "dash", "wallkick", "crouch", "gkey",
		"pick_kin", "kin", "glove", "hook", "pick_ult", "ult", "ranks", "wayout", "uplink"]
const GUARD := 24000      # ticks of 2 sim steps (800 s): the slow steps wait ~170 s, so 6000 was too few

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var o := {"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"}
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--arch="):
			o["arch"] = String(a).substr(7)
			o["cls"] = Arch.weight(o["arch"])
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	await _shot("intro")
	await _frames(30)
	await _shot("intro_late")
	m.tut.ack()
	var seen := {}
	var times := [0.4, 1.2, 2.5]
	var guard := 0
	while guard < GUARD and m.tut.step < Tutorial.steps().size() and not m.player.extracted:
		guard += 1
		TutorialDrive.drive(m)
		for i in 2:
			m.step(Match.DT)
		m.cam.snap(m.player.pos)
		var tu: Tutorial = m.tut
		var sid := tu.id()
		if not times.is_empty() and m.time >= float(times[0]):
			await _shot("t%04.1f_%s" % [float(times.pop_front()), sid])
		var ats := [0.25] if sid.begins_with("pick_") or sid == "sec" else [0.7, 2.6]   # (a pick is made by 0.4 s)
		for at in ats:
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
