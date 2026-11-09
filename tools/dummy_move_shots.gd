extends RefCounted
## --dummy-move-shots --shots-dir=<dir> (GPU): the Training Area's station dummy as it strafes, then dodges
## (Arena.cycle_dummy): <dir>/clip/f000.png ... (ffmpeg it into a clip), the station sign in view.

const STRAFE_FRAMES := 100
const DODGE_FRAMES := 300
const FRAME := Vector2i(1280, 720)
var tree: SceneTree

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := "user://dummy_move_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): out = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(out.path_join("clip"))
	main.get_window().size = FRAME
	var fade = main.get("fade")
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts())
	if m.hud: m.hud.visible = false
	for c in main.find_children("*", "CanvasLayer", true, false):
		if c != fade: (c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.fov = 40.0
	m.add_child(cam)
	cam.current = true
	for i in 30: await tree.process_frame
	var A: Arena = m.arena
	var mid := A.dummies[0]["at"] as Vector3
	cam.global_position = mid + Vector3(-2.0, 6.5, 9.5)
	cam.look_at(mid + Vector3(0, 1.0, 0))
	A.cycle_dummy()
	for f in STRAFE_FRAMES + DODGE_FRAMES:
		if f == STRAFE_FRAMES: A.cycle_dummy()
		if fade: fade.visible = false
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png(out.path_join("clip/f%03d.png" % f))
	print("DUMMY_MOVE_SHOTS_DONE")
	tree.quit()
