extends RefCounted
## --show-ring-shots --shots-dir=<dir>: the Show Ring's result from the default garden camera at 1280x720,
## a frame every FRAME_S after the result (ring_00.png ...) and the lot side by side in strip.png, so the
## three judge marks and the ribbon can be judged as the player sees them. Needs a renderer (jobq --needs gpu).
## Never touches the real save.

const Check := preload("res://tools/show_ring_check.gd")
const SIZE := Vector2i(1280, 720)
const TIMES := [0.05, 0.25, 0.45, 0.65, 0.85, 1.05, 1.3, 1.55, 2.0, 2.6]   # s after the result
const STRIP_SCALE := 0.5   # each frame's size in the strip
const SETTLE := 600        # frames to wait at most for the home to finish building

func run(main: Node) -> void:
	var dir := "shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): dir = a.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = SIZE
	Save.no_write = true
	var c := Check.new()
	var d := Save.fresh()
	for i in 3:
		var k: Dictionary = c._kin(["Pip", "Ash", "Bo"][i], 95.0, 95.0, 90.0, 0.9)
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	FarmUnlocks.rules()["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	for f in 30:
		await main.get_tree().process_frame
	if main.get("fade") != null:   # the boot logo and ink stay up otherwise: the strip is of the game only
		main.fade.logo.modulate.a = 0.0
		main.fade.visible = false
	var sr: ShowRing = home.hshow
	if sr == null:
		print("SHOWRINGSHOTS FAIL no stage")
		main.get_tree().quit(1)
		return
	for k in home.kins:
		k.erase("indoors")
	sr.use()
	var t := 0.0
	while sr.run != null and t < 200.0:
		sr.tick(0.1)
		t += 0.1
	var frames: Array[Image] = []
	var got := Vector2i.ZERO
	var mm = sr.get("marks")
	if not is_instance_valid(mm):
		print("SHOWRINGSHOTS FAIL no marks after the show")
		main.get_tree().quit(1)
		return
	mm.set_process(false)   # its clock is set per grab, so a slow renderer still shows each moment
	for i in TIMES.size():
		if is_instance_valid(mm):
			mm.t = float(TIMES[i])
			mm._process(0.0)
		for f in 3:
			await RenderingServer.frame_post_draw
		print("SHOWRING frame %d t=%.2f marks=%s" % [i, TIMES[i], "on" if is_instance_valid(mm) else "gone"])
		var img := main.get_viewport().get_texture().get_image()
		if img == null:
			print("SHOWRINGSHOTS FAIL no renderer (run through jobq --needs gpu)")
			main.get_tree().quit(1)
			return
		img.save_png(dir.path_join("ring_%02d.png" % i))
		frames.append(img)
		got = img.get_size()
	var w := int(SIZE.x * STRIP_SCALE)
	var hh := int(SIZE.y * STRIP_SCALE)
	var cols := 5
	var strip := Image.create(w * cols, hh * ceili(frames.size() / float(cols)), false, Image.FORMAT_RGB8)
	for i in frames.size():
		var f: Image = frames[i]
		f.convert(Image.FORMAT_RGB8)
		f.resize(w, hh, Image.INTERPOLATE_BILINEAR)
		strip.blit_rect(f, Rect2i(0, 0, w, hh), Vector2i((i % cols) * w, (i / cols) * hh))
	strip.save_png(dir.path_join("strip.png"))
	var rib: String = mm.col.to_html(false) if is_instance_valid(mm) else "gone"
	print("SHOWRINGSHOTS DONE %s %dx%d, show %.1f s, ribbon %s" % [dir, got.x, got.y, t, rib])
	main.get_tree().quit()
