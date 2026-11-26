extends "res://tools/vv_shots.gd"
## --toon-lineup-shots --shots-dir=<dir> [--close] [--species=a,b] [--arch=a,b]: every Boki and Hunter the game
## draws, one after another on the same spot under the same light at the match camera, in a real match
## (jobq submit --needs gpu). Writes <dir>/lineup_<id>.png (crop round the model), <dir>/lineup_sheet.png (all of
## them, labelled, darkest rendered model first) and <dir>/lineup_stats.tsv (rendered luminance of the model's own
## pixels, from the shot minus the empty spot). Pairs with --toon-consistency-check, which judges the materials.

const COLS := 10
const DIFF_MIN := 0.12  # colour-balance shift from the empty spot that makes a pixel the model's

var crop_px := Vector2i(170, 170)  # px of the screen round the model, drawn at `zoom`
var zoom := 2.5
var ids: Array = []
var world: Node3D  # what the models are added to: the match, or the farm


func run(main_node: Node) -> void:
	main = main_node
	var boki: Array = Data.KIN.keys().filter(func(sp): return BokiRig.has(sp))
	boki.sort()
	var hunters: Array = Arch.ORDER.duplicate()
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--species="):
			boki = Array(arg.substr(10).split(","))
		if arg.begins_with("--arch="):
			hunters = Array(arg.substr(7).split(","))
	for sp in boki:
		ids.append(["boki", sp])
	for arch in hunters:
		ids.append(["hunter", arch])
	DirAccess.make_dir_recursive_absolute(dir)
	var spot: Vector3 = await _stage()
	var empty := main.get_viewport().get_texture().get_image()
	var shots: Array = []
	for row in ids:
		var node: Node3D = _spawn(row, spot)
		await _settle(0.7)
		var img := main.get_viewport().get_texture().get_image()
		var crop := _crop(img, spot + Vector3(0, 0.8, 0), crop_px, zoom)
		crop.save_png(dir.path_join("lineup_%s.png" % row[1]))
		shots.append([row, crop, _rendered_lum(img, empty, spot + Vector3(0, 0.8, 0))])
		node.queue_free()
	_write(shots)
	print("TOONLINEUP %d models in %s" % [shots.size(), dir])
	main.get_tree().quit(0)


## The scene and the spot the models stand on, the match camera on it and one frame of the empty spot drawn.
func _stage() -> Vector3:
	await _setup()
	world = m
	m.hud.visible = false
	if "--close" in OS.get_cmdline_user_args():  # the wheel's closest zoom, the model fills the crop
		m.cam.zoom_to = CamWheel.near(true)
		m.cam.zoom = m.cam.zoom_to
		crop_px = Vector2i(300, 300)
		zoom = 1.4
	P.teleport(home + Vector3(-30, 0, 30))  # the hero and the target out of every crop
	T.teleport(home + Vector3(-30, 0, 40))
	cam_at = home + Vector3(8, 0, 0)
	await _go(0.8)
	return cam_at


func _settle(secs: float) -> void:
	await _go(secs)


func _spawn(row: Array, at: Vector3) -> Node3D:
	var node: Node3D
	if row[0] == "boki":
		node = Models.kin(String(row[1]), {"level": 5})
	else:
		var arch := String(row[1])
		var look := PlayerLook.neutral()
		node = Models.hunter(Arch.weight(arch), Data.TEAM_COLORS[0], Arch.signature(arch), "", look, arch)
	node.position = at
	world.add_child(node)
	return node


## Mean luminance of the crop's pixels that are the model's own: not the empty spot, and not the ground darkened by
## its shadow (a shadow keeps the ground's colour balance, a model does not).
func _rendered_lum(img: Image, empty: Image, at: Vector3) -> float:
	var cam := main.get_viewport().get_camera_3d()
	var c := cam.unproject_position(at)
	var sum := 0.0
	var n := 0
	var half := crop_px / 2
	for y in range(int(c.y) - half.y, int(c.y) + half.y):
		for x in range(int(c.x) - half.x, int(c.x) + half.x):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var a := img.get_pixel(x, y)
			var b := empty.get_pixel(x, y)
			var la := maxf(a.get_luminance(), 0.001)
			var lb := maxf(b.get_luminance(), 0.001)
			var hue_shift := Vector3(a.r / la - b.r / lb, a.g / la - b.g / lb, a.b / la - b.b / lb).length()
			if hue_shift > DIFF_MIN:
				sum += la
				n += 1
	return sum / maxi(n, 1)


func _write(shots: Array) -> void:
	shots.sort_custom(func(p, q): return float(p[2]) < float(q[2]))
	var w := int(crop_px.x * zoom)
	var h := int(crop_px.y * zoom)
	var rows := int(ceil(shots.size() / float(COLS)))
	var sheet := Image.create(w * COLS, h * rows, false, Image.FORMAT_RGB8)
	var f := FileAccess.open(dir.path_join("lineup_stats.tsv"), FileAccess.WRITE)
	f.store_line("kind\tid\trendered_lum")
	for i in shots.size():
		var crop: Image = shots[i][1]
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i((i % COLS) * w, int(i / COLS) * h))
		f.store_line("%s\t%s\t%.3f" % [shots[i][0][0], shots[i][0][1], shots[i][2]])
	f.close()
	sheet.save_png(dir.path_join("lineup_sheet.png"))
