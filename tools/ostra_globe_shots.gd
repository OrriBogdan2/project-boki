extends "res://tools/vv_shots.gd"
## --ostra-globe-shots --shots-dir=<dir>: Motley's Brimseed at 0, 25, 50 and 100% growth at the match camera (xvfb with
## a renderer), one strip; the drawn radius is printed next to the hit radius.

const GROWTH := [0.0, 0.25, 0.5, 1.0]      # share of the grow time
const CROP := Vector2i(520, 360)           # px round the seed per strip frame
const SEED_AT := 8.0                       # m east of Motley

func run(main_node: Node) -> void:
	main = main_node
	who = "ostra"
	hero_name = "ostra"
	tag = "kits/ostra"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var K: OstraKit = P.ak
	var grow := float(K.e_def()["grow"])
	await _reset(SEED_AT)
	cam_at = home + Vector3(SEED_AT, 0, 0)
	_aim(home + Vector3(SEED_AT, 0, 0))
	T.teleport(home + Vector3(-30, 0, 30))
	K.cast_e()
	var t := 0.0
	for g in GROWTH:
		await _go(maxf(grow * g - t, 0.02))
		t = grow * g
		_take("globe", "brimseed_growth", "Brimseed at 0, 25, 50 and 100% growth, match camera", Callable())
		var vis: Node3D = K.seed["vis"]
		print("GLOBE %3d%%: drawn radius %.2f m, hit radius %.2f m" % [g * 100.0, vis.scale.x, K.seed_radius()])
	var f := FileAccess.open(dir.path_join("MANIFEST_ostra.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("OSTRAGLOBESHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _take(_kind: String, file: String, caption: String, _focus: Callable) -> void:
	var img := main.get_viewport().get_texture().get_image()
	var crop := _crop(img, cam_at, CROP, 1.0)
	var strip_file := "%s_%s.png" % [hero_name, file]
	if not strips.has(strip_file):
		strips[strip_file] = []
		lines.append("%s/%s|%s|%s" % [hero_name, tag, strip_file, caption])
	(strips[strip_file] as Array).append(crop)
	_save_strip(strip_file)
