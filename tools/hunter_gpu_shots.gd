extends "res://tools/gameplay_media.gd"
## --hunter-gpu-shots --heroes=<arch ids> --shots-dir=<dir>: each Hunter alone in a real match (Dusk Isles, seed 5),
## under the match camera, as <dir>/<hero>_<shot>.png: match (idle, the camera's default zoom), zoom (idle, closer)
## and run (moving, closer). Needs a renderer (jobq --needs gpu).

const SIZE := Vector2i(1600, 900)   # px of each shot
const SETTLE := 1.5                 # s of idle before a shot
const RUN_SECS := 1.2               # s of run before the run shot
const ZOOM_CLOSE := 0.5             # camera zoom of the closer shots

func run(main_node: Node) -> void:
	main = main_node
	var heroes := ["gunslinger", "thief", "ashwick", "juggernaut", "rimewright"]
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--heroes="): heroes = Array(String(a).substr(9).split(","))
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	main.get_window().size = SIZE
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	for hero in heroes:
		if m:
			m.queue_free()
		await _start(hero, "cindle")
		m.player.ctrl = "idle"
		m.player.teleport(_ground(m.player.pos))
		await _take(SETTLE, 1.0, Vector2.ZERO, "%s_match.png" % hero)
		await _take(SETTLE, ZOOM_CLOSE, Vector2.ZERO, "%s_zoom.png" % hero)
		await _take(RUN_SECS, ZOOM_CLOSE, Vector2(1, 0.4).normalized(), "%s_run.png" % hero)
		print("HUNTERGPU %s done" % hero)
	print("HUNTERGPU all in %s" % dir)
	main.get_tree().quit(0)

## Steps `secs` of the match as Match runs a frame (the player holds `move`), then saves the shot.
func _take(secs: float, zoom_v: float, move: Vector2, file: String) -> void:
	var P := m.player
	_zoom(zoom_v)
	m.cam.snap(P.pos)
	var t := 0.0
	while t < secs:
		_purge()
		P.inp["move"] = move
		for _i in 2:
			m.step(STEP)
		m.cam.follow(P.pos, FRAME, false)
		for h in m.hunters:
			h.render(FRAME, 1.0)
		await main.get_tree().process_frame
		t += FRAME
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
