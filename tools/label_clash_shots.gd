extends "res://tools/archetype_check.gd"
## --label-clash-shots --shots-dir=<dir>: a gear drop at a rival's feet with a damage number on them, at
## 1280x720 (run under a renderer, jobq --needs gpu). Written as clash_<tag>.png; run it once on a tree
## without LabelClash and once with, to see the loot name step aside.

func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	main.get_window().size = Vector2i(1280, 720)
	var s := setup("thief", 6.0)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var m: Match = s[0]
	var T: Hunter = s[2]
	var spot: Vector3 = T.pos + Vector3(0.3, 0, 0.2)
	m.spawn_gear(String(Gear.ALL.keys()[0]), 2, spot)
	m.wpicks[-1]["pos"] = spot
	m.fx.number(T.pos + Vector3(0, 1.6, 0), 42.0, Color.WHITE, true)
	step(m, 0.1)
	for i in 8:
		await main.get_tree().process_frame
	var tag := "after" if FileAccess.file_exists("res://scripts/ui/label_clash.gd") else "before"
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("clash_%s.png" % tag))
	print("CLASHSHOT done")
	await done(m)
	main.get_tree().quit(0)
