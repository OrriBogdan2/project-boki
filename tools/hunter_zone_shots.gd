extends "res://tools/vv_shots.gd"
## --hunter-zone-shots --shots-dir=<dir> --shots-tag=<before|after>: a live Arena match (xvfb with a
## renderer) where the hero is hit, healed and told a word at once, a rival stands close, and several
## messages fire together. zone_<tag>.png is the screen round the hero; zone_lane_<tag>.txt lists the
## cards on show. Run it on main and on the branch.

const CROP := Vector2i(900, 560)  # px round the hero


func run(main_node: Node) -> void:
	main = main_node
	who = "ostra"
	hero_name = "ostra"
	var tag_name := "after"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--shots-tag="):
			tag_name = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	Settings.set_v("damage_numbers", true, false)
	T.teleport(P.pos + Vector3(3.5, 0, -1.5))
	var hold := func(_t):
		for n in m.fx.nums:
			n["t"] = 0.0
			if n.has("last"):
				n["last"] = 0.0
				n["vel"] = Vector3.ZERO
	await _go(0.3, hold)
	m.fx.hit_number(P, T, 34.0, Color("ff6a5a"), false)
	m.fx.hit_number(P, T, 61.0, Color("ffd24a"), true)
	m.fx.healed(P, 18.0)
	m.fx.word(P.pos + Vector3(0, 1.3, 0), "COMBO", Color.WHITE)
	for t in [
		"ARMOR BROKEN",
		"Chest key found",
		"WALL SLAM",
		"Bramble Isle  ·  low ground",
		"Drop wave incoming",
		"Monsters incoming!"
	]:
		m.hud.toast_small(t, Color("ffd27a"))
	m.hud.toast("LEVEL 4  ·  +1 skill point", Color("ffd24a"))
	await _go(0.8, hold)
	var img := main.get_viewport().get_texture().get_image()
	var at := Rect2i(Vector2i(img.get_size() / 2) - CROP / 2, CROP).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(at).save_png(dir.path_join("zone_%s.png" % tag_name))
	img.save_png(dir.path_join("zone_full_%s.png" % tag_name))
	var f := FileAccess.open(dir.path_join("zone_lane_%s.txt" % tag_name), FileAccess.WRITE)
	f.store_string("\n".join(m.hud.msgs.texts()) + "\n")
	f.close()
	print("ZONESHOTS in ", dir)
	main.get_tree().quit(0)
