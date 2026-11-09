extends RefCounted
## --dash-trail-shots --shots-dir=<dir> [--dash-only=<id>,<id>]: one strip per Hunter of its ground dash (run
## under xvfb with a renderer): the Hunter on flat ground dashes along the screen, a crop round them at each mark.
## Files go into <dir> as dash_<hero>.png, and dash_all.png stacks the 12 strips.

const DT := 1.0 / 60.0
const MARKS := [0.04, 0.1, 0.16, 0.22, 0.3, 0.4, 0.55]      # s after the press
const CROP := Vector2i(230, 150)          # px round the Hunter for a frame
const ZOOM := 1.6

var flow := preload("res://tools/dash_flow_check.gd").new()

func run(main: Node) -> void:
	var dir := ""
	var only: PackedStringArray = Arch.ORDER
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--dash-only="):
			only = String(a).get_slice("=", 1).split(",")
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var strips: Array = []
	for hero in only:
		var strip := await _strip(main, hero)
		strip.save_png(dir.path_join("dash_%s.png" % hero))
		strips.append(strip)
	var sheet := Image.create(strips[0].get_width(), strips[0].get_height() * strips.size(), false, strips[0].get_format())
	for i in strips.size():
		sheet.blit_rect(strips[i], Rect2i(Vector2i.ZERO, strips[i].get_size()), Vector2i(0, i * strips[0].get_height()))
	sheet.save_png(dir.path_join("dash_all.png"))
	print("DASHSHOTS %d strips in %s" % [strips.size(), dir])
	main.get_tree().quit(0)

func _strip(main: Node, hero: String) -> Image:
	var m: Match = flow._match(main, hero)
	m.set_process(false)
	var h: Hunter = flow.hunter
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	flow._ready_up(m)
	h.inp["move"] = Vector2(1, 0)
	h.inp["aim"] = h.pos + Vector3(6, 0.9, 0)
	h.inp["dash"] = true
	var frames: Array = []
	var marks := MARKS.duplicate()
	var t := 0.0
	while not marks.is_empty():
		m.step(DT)
		h.inp["dash"] = false
		t += DT
		m.cam.snap(h.pos + Vector3(2.0, 0, 0))
		for x in m.hunters:
			x.render(DT, 1.0)
		await main.get_tree().process_frame
		if t >= float(marks[0]):
			marks.pop_front()
			frames.append(_crop(main, h))
	m.queue_free()
	await main.get_tree().process_frame
	var out := Image.create(int(CROP.x * ZOOM) * frames.size(), int(CROP.y * ZOOM), false, (frames[0] as Image).get_format())
	for i in frames.size():
		out.blit_rect(frames[i], Rect2i(Vector2i.ZERO, (frames[i] as Image).get_size()), Vector2i(i * int(CROP.x * ZOOM), 0))
	return out

func _crop(main: Node, h: Hunter) -> Image:
	var img := main.get_viewport().get_texture().get_image()
	var c := main.get_viewport().get_camera_3d().unproject_position(h.position + Vector3(0, 0.9, 0))
	var rg := Rect2i(Vector2i(int(c.x) - CROP.x / 2, int(c.y) - CROP.y / 2), CROP).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rg)
	crop.resize(int(CROP.x * ZOOM), int(CROP.y * ZOOM), Image.INTERPOLATE_BILINEAR)
	return crop
