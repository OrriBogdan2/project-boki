extends RefCounted
## --tenzo-press-strip --shots-dir=<dir> [--press-for=0.45]: Tenzo's LMB press, frame by frame, for the before/after
## strip (docs/heroes/dolm.md, "LMB press wind-up"). The real path: Match._process runs at the engine's frame rate,
## the press goes through the `fire` Input action, and every frame from the press is saved as <dir>/f<NNN>.png
## (f000 = the frame of the press). Run it windowed at the rate under test, on main (before) and the branch (after):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy
##       --resolution 960x540 --fixed-fps 144 -- --tenzo-press-strip --shots-dir=/tmp/strip144

const SETTLE_S := 1.2   # s of idle frames before the press, so the pose is at rest
const ZOOM := 0.3     # closer than play (smaller = nearer), held through Match._process (MatchCam zoom_hold)

var main: Node
var dir := ""
var press_for := 0.45


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		elif arg.begins_with("--press-for="):
			press_for = float(arg.substr(12))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	var gm = load("res://tools/gameplay_media.gd").new()
	gm.main = main
	await gm._start("dolm", "cindle")
	var m: Match = gm.m
	var hero: Hunter = m.player
	if hero.kin:
		(hero.kin as Kin).stow()
	if m.hud:
		m.hud.visible = false
	m.set_meta("zoom_hold", ZOOM)
	gm._zoom(ZOOM)
	m.set_process(true)
	var tree := main.get_tree()
	var t := 0.0
	while t < SETTLE_S:
		gm._purge()
		await tree.process_frame
		t += main.get_process_delta_time()
	Input.action_press("fire")
	var n := 0
	t = 0.0
	while t < press_for + 0.1:
		gm._purge()
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("f%03d.png" % n))
		var at: Vector2 = m.cam.unproject_position(hero.pos + Vector3(0, 0.9, 0))
		var row := [n, t, hero.ak.anim_id, hero.ak.get("lmb_t"), at.x, at.y]
		print("PRESS_STRIP f%03d t=%.4f anim=%s lmb_t=%.3f at=%d,%d" % row)
		n += 1
		t += main.get_process_delta_time()
		if t >= press_for and Input.is_action_pressed("fire"):
			Input.action_release("fire")
	print("PRESS_STRIP_DONE frames=%d" % n)
	main.get_tree().quit(0)
