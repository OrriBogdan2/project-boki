extends RefCounted
## --map-legend-shots --shots-dir=<dir>: the full map (M) with its key at 1920x1080 and 1280x720
## (a real renderer, e.g. under jobq --needs gpu): map_1080.png, map_720.png and a zoomed crop of the key.

const SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	m.hud.full_map.open()
	for sz in SIZES:
		main.get_window().size = sz
		for i in 8:
			await main.get_tree().process_frame
		var img := main.get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("map_%d.png" % sz.y))
		var r: Rect2 = MapLegend.panel(m.hud.full_map, MapLegend.present(m).size())
		var crop := Rect2i(r.grow(8.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(crop).save_png(dir.path_join("key_%d.png" % sz.y))
		print("MAPLEGENDSHOTS %dx%d: %s" % [img.get_width(), img.get_height(), ", ".join(MapLegend.present(m))])
	main.get_tree().quit(0)
