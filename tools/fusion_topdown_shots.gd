extends RefCounted
## --fusion-topdown-shots --shots-dir=<dir> (a renderer): each Fusion at the match camera, the wearer's own copy
## and a remote copy (built the way another game builds it: the form string of the snapshot through KinNet), each
## walking up the screen and toward it, at two moments of the wing beat. One strip per form
## (topdown_<form>.png) and topdown_all.png stacks them; the draw numbers print as FUSIONTOPDOWN lines.

const DT := 1.0 / 60.0
const FORMS := [["pebbit", "titan"], ["zephyrak", "stormwing"], ["puddlet", "tidal_shell"]]
const CROP := Vector2i(210, 150)          # px round the hunter for a frame
const ZOOM := 1.4
const SPACING := 3.2          # m between the wearer and the remote copy

func run(main: Node) -> void:
	var dir := "shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var chk = load("res://tools/merge_form_check.gd").new()
	chk.main = main
	Save.no_write = true
	var strips: Array = []
	for pair in FORMS:
		var strip: Image = await _strip(chk, main, pair[0], pair[1])
		strip.save_png(dir.path_join("topdown_%s.png" % pair[1]))
		strips.append(strip)
	var sheet := Image.create(strips[0].get_width(), strips[0].get_height() * strips.size(), false, strips[0].get_format())
	for i in strips.size():
		sheet.blit_rect(strips[i], Rect2i(Vector2i.ZERO, strips[i].get_size()), Vector2i(0, i * strips[0].get_height()))
	sheet.save_png(dir.path_join("topdown_all.png"))
	print("FUSIONTOPDOWN %d strips in %s" % [strips.size(), dir])
	main.get_tree().quit(0)

func _strip(chk, main: Node, species: String, form_id: String) -> Image:
	var P: Hunter = chk.merged(species)
	var m: Match = chk.m
	var R: Hunter = chk.foe(P.pos + Vector3(SPACING, 0, 0))
	R.ctrl = "idle"
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var extra: Array = KinNet.hunter_extra(P)
	var it: Array = []
	it.resize(KinNet.HUNTER_AT)
	it.append_array(extra)
	R.remote = true
	KinNet.apply_hunter(R, it)
	var frames: Array = []
	for face in [0.0, PI]:
		for who in [P, R]:
			who.face = face
		for phase in 2:
			for i in 40 if phase == 0 else 9:
				m.step(DT)
				for x in [P, R]:
					x.face = face
					x.render(DT, 1.0)
				m.cam.snap((P.pos + R.pos) * 0.5)
				await main.get_tree().process_frame
			for who in [P, R]:
				frames.append(_crop(main, who))
	print("FUSIONTOPDOWN %s draws %d objects %d" % [form_id,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	m.queue_free()
	await main.get_tree().process_frame
	var fw := int(CROP.x * ZOOM)
	var out := Image.create(fw * frames.size(), int(CROP.y * ZOOM), false, (frames[0] as Image).get_format())
	for i in frames.size():
		out.blit_rect(frames[i], Rect2i(Vector2i.ZERO, (frames[i] as Image).get_size()), Vector2i(i * fw, 0))
	return out

func _crop(main: Node, h: Hunter) -> Image:
	var img := main.get_viewport().get_texture().get_image()
	var c := main.get_viewport().get_camera_3d().unproject_position(h.position + Vector3(0, 0.9, 0))
	var corner := Vector2i(int(c.x) - CROP.x / 2, int(c.y) - CROP.y / 2)
	var rg := Rect2i(corner, CROP).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rg)
	crop.resize(int(CROP.x * ZOOM), int(CROP.y * ZOOM), Image.INTERPOLATE_BILINEAR)
	return crop
