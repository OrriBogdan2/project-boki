extends "res://tools/boki_rig_shots.gd"
## --lean-shots --shots-dir=<dir> [--px=512]: three leaned evolutions with base_mode on (Lean). One row each:
## Fire on cindle (horns), Ice on puddlet (frost crest), Flying on wisplet (wings); columns are fresh,
## leaned (one meal's tint and flecks), and at its next form (the part). <dir>/lean_parts.png is the sheet,
## lean_<type>_<0..2>.png each alone. Needs a renderer.

const ROWS := [["fire", "cindle"], ["ice", "puddlet"], ["flying", "wisplet"]]

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--px="): px = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	var sheet := Image.create(px * 3, px * ROWS.size(), false, Image.FORMAT_RGBA8)
	for r in ROWS.size():
		var type: String = ROWS[r][0]
		var rec := Save.new_kin(ROWS[r][1], "Prisma")
		for i in 3:
			if i == 1:
				rec["lean"] = {type: Evo.LEAN_FULL * 0.5}
			elif i == 2:
				rec["level"] = 4
				Evo.on_level(rec)
			var vp := _stage(Vector2i(px, px))
			var cam := _close_cam(vp)
			cam.position = Vector3(0, 0.8, 2.9)
			cam.look_at(Vector3(0, 0.42, 0))
			var k := rigged_kin(ROWS[r][1], rec)
			vp.add_child(k)
			k.rotation.y = PI * 0.8
			var img: Image = await _grab(vp)
			img.convert(Image.FORMAT_RGBA8)
			img.save_png(out.path_join("lean_%s_%d.png" % [type, i]))
			sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(i * px, r * px))
			vp.queue_free()
	sheet.save_png(out.path_join("lean_parts.png"))
	print("LEAN_SHOTS_DONE")
	main.get_tree().quit()
