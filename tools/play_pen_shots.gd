extends RefCounted
## --play-pen-shots --shots-dir=<dir> [--video-s=6] [--at=4,16,40]: the whole title screen (live play pen under the
## menu) as stills at those seconds (<dir>/pen_<s>.png) and a clip stepped 30 fps (<dir>/video/NNNN.jpg, for
## `ffmpeg -framerate 30 -i %04d.jpg`). Time is stepped by hand so a slow software renderer still gives smooth
## footage. Needs a renderer.

const DT := 1.0 / 30.0
const SIZE := Vector2i(1920, 1080)

func run(main: Node) -> void:
	var out := ""
	var video_s := 6.0
	var at: Array = [4.0, 16.0, 40.0]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--video-s="): video_s = float(a.substr(10))
		if a.begins_with("--at="): at = Array(a.substr(5).split(",", false)).map(func(s): return float(s))
	DirAccess.make_dir_recursive_absolute(out.path_join("video"))
	var tree := main.get_tree()
	main.get_window().size = SIZE
	main.get_viewport().size = SIZE
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	await main.show_screen("title", {})
	for i in 40:
		await tree.process_frame        # (the menu pops in)
	var pen: PlayPen = main.screen_node().find_children("*", "PlayPen", true, false)[0]
	pen.set_process(false)
	pen.still = false       # (a software renderer is slow enough to freeze the pen; the footage is stepped by hand)
	var t := 0.0
	for shot_at: float in at:
		while t < shot_at:
			pen._process(DT)
			t += DT
		await _grab(main, out.path_join("pen_%d.png" % int(shot_at)))
	var n := 0
	for i in int(video_s / DT):
		pen._process(DT)
		await _grab(main, out.path_join("video/%04d.jpg" % n))
		n += 1
	print("PLAY_PEN_SHOTS_DONE ", at.size(), " ", n)
	tree.quit()

func _grab(main: Node, path: String) -> void:
	for k in 2:
		await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	if path.ends_with(".jpg"):
		img.save_jpg(path, 0.9)
	else:
		img.save_png(path)
