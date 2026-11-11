extends "res://tools/boki_rig_shots.gd"
## --lean-shots --shots-dir=<dir> [--px=512]: a fresh Prismander (puddlet) before and after Fire snacks with
## base_mode on (Lean): fresh, one snack, three snacks, and at its next form. <dir>/lean.png is the four side by
## side, and lean_0..3.png each alone. Needs a renderer.

func run(m: Node) -> void:
	main = m
	species = "puddlet"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--px="): px = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	var rec := Save.new_kin(species, "Prisma")
	var steps := [0, 1, 2]
	var sheet := _strip(steps.size() + 1)
	for i in steps.size() + 1:
		if i in [1, 2]:
			for n in (1 if i == 1 else 2):
				Evo.eat(rec, "emberberry")
		elif i == 3:
			rec["level"] = 4
			Evo.on_level(rec)
		var vp := _stage(Vector2i(px, px))
		var cam := _close_cam(vp)
		cam.position = Vector3(0, 0.8, 2.9)
		cam.look_at(Vector3(0, 0.42, 0))
		var k := rigged_kin(species, rec)
		vp.add_child(k)
		k.rotation.y = PI
		var img: Image = await _grab(vp)
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(out.path_join("lean_%d.png" % i))
		sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(i * px, 0))
		vp.queue_free()
	sheet.save_png(out.path_join("lean.png"))
	print("LEAN_SHOTS_DONE")
	main.get_tree().quit()
