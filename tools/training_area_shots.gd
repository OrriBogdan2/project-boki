extends RefCounted
## --training-area-shots --shots-dir=<dir> (GPU): the Training Area as the title screen opens it
## (Match.arena_opts with no Hunter, then each one picked in place, Arena.set_arch): <dir>/hunter_<id>.png,
## every Hunter close up at 3/4 front;
## <dir>/overview.png from high above; <dir>/clip/f000.png ... a slow flyover (ffmpeg it into a clip). Runs on older
## trees too (the before shots of the 11-08 merge: the old 52 m Arena map).

const CLIP_FRAMES := 90
const FRAME := Vector2i(1280, 720)
var tree: SceneTree
var cam: Camera3D
var fade: CanvasLayer          # the boot splash ink: hidden, it would cover every shot

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := "user://training_area_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): out = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(out.path_join("clip"))
	main.get_window().size = FRAME
	fade = main.get("fade")
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts())
	if m.hud: m.hud.visible = false
	cam = Camera3D.new()
	cam.fov = 40.0
	m.add_child(cam)
	cam.current = true
	for i in 30: await tree.process_frame
	var P: Hunter = m.player
	for a in Arch.ids():
		m.arena.set_arch(String(a))
		for i in 45: await tree.process_frame
		cam.current = true
		var at := P.global_position + Vector3(0, 1.0, 0)
		var fwd := Vector3(sin(P.face), 0, cos(P.face))
		cam.global_position = at + fwd.rotated(Vector3.UP, 0.7) * 3.4 + Vector3(0, 0.6, 0)
		cam.look_at(at)
		await _grab(out.path_join("hunter_%s.png" % a))
	var big := m.world.layout_id == "training"
	var mid := Vector3(55, 0, 38) if big else Vector3(26, 0, 26)
	cam.global_position = mid + (Vector3(0, 70, 62) if big else Vector3(0, 38, 34))
	cam.look_at(mid)
	await _grab(out.path_join("overview.png"))
	for f in CLIP_FRAMES:
		var k := float(f) / float(CLIP_FRAMES - 1)
		var ang := lerpf(-0.9, 0.9, k)
		var rad := 60.0 if big else 32.0
		cam.global_position = mid + Vector3(sin(ang) * rad, rad * 0.55, cos(ang) * rad)
		cam.look_at(mid)
		await _grab(out.path_join("clip/f%03d.png" % f))
	print("TRAINING_AREA_SHOTS_DONE ", Arch.ids().size())
	tree.quit()

func _grab(path: String) -> void:
	if fade: fade.visible = false
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)
