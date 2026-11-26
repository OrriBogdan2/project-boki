extends "res://tools/vv_shots.gd"
## --toon-lineup-shots --shots-dir=<dir> [--close] [--species=a,b] [--arch=a,b]: every Boki and Hunter the game
## draws, one after another on the same spot under the same light at the match camera, in a real match
## --ab=<species>:<atlas png/webp> adds that species again, right after itself, with the given coat atlas (an old one):
## a before/after in the same run and frame, row id <species>_ab (separate runs drift by up to 0.09 luminance).
## --ab-plain drops the species' own coat override from that row too (the live look before the override).
## --turn=<deg> turns every model about its up axis (90: its side to the camera, where a baked top light shows most).
## (jobq submit --needs gpu). Writes <dir>/lineup_<id>.png (crop round the model), <dir>/lineup_sheet.png (all of
## them, labelled, darkest rendered model first) and <dir>/lineup_stats.tsv (rendered luminance of the model's own
## pixels, from the shot minus the empty spot). Pairs with --toon-consistency-check, which judges the materials.

const COLS := 10
const DIFF_MIN := 0.12  # colour-balance shift from the empty spot that makes a pixel the model's

var crop_px := Vector2i(170, 170)  # px of the screen round the model, drawn at `zoom`
var zoom := 2.5
var ids: Array = []
var world: Node3D  # what the models are added to: the match, or the farm
## The shared coat look's values for what a species' own "coat" override changes (WardenGlb.PAINTED dark_lift).
const PLAIN_LOOK := {
	"desat": 0.0,
	"dark_lift": 0.07,
	"albedo_flat": 0.0,
	"albedo_flat_gain": 1.0,
	"albedo_flat_contrast": 1.0
}
var ab := PackedStringArray()  # --ab: [species, atlas path]
var turn := 0.0  # --turn, degrees


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
		if arg.begins_with("--turn="):
			turn = float(arg.substr(7))
		if arg.begins_with("--ab="):
			ab = arg.substr(5).split(":", true, 1)
		if arg.begins_with("--arch="):
			var named := Array(arg.substr(7).split(","))  # "none" or empty: no Hunters
			hunters = named.filter(func(a): return a != "" and a != "none")
	for sp in boki:
		ids.append(["boki", sp])
		if ab.size() == 2 and ab[0] == sp:
			ids.append(["boki", sp, ab[1]])
	for arch in hunters:
		ids.append(["hunter", arch])
	DirAccess.make_dir_recursive_absolute(dir)
	var spot: Vector3 = await _stage()
	# --crop=<px round the model> --zoom=<magnification of that crop>
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--crop="):
			crop_px = Vector2i.ONE * int(String(a).substr(7))
		if String(a).begins_with("--zoom="):
			zoom = float(String(a).substr(7))
	var empty := main.get_viewport().get_texture().get_image()
	var shots: Array = []
	for row in ids:
		var node: Node3D = _spawn(row, spot)
		await _settle(0.7)
		var img := main.get_viewport().get_texture().get_image()
		var st := _model_stats(img, empty, spot + Vector3(0, 0.8, 0))
		var crop := _crop_px(img, st["centre"], crop_px, zoom)
		crop.save_png(dir.path_join("lineup_%s.png" % _label(row)))
		shots.append([row, crop, st])
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
		if row.size() > 2:
			_swap_atlas(node, String(row[2]))
	else:
		var arch := String(row[1])
		var look := PlayerLook.neutral()
		node = Models.hunter(
			Arch.weight(arch), Data.TEAM_COLORS[0], Arch.signature(arch), "", look, arch
		)
	node.position = at
	node.rotation.y = deg_to_rad(turn)
	world.add_child(node)
	return node


func _label(row: Array) -> String:
	return String(row[1]) + ("_ab" if row.size() > 2 else "")


## The --ab row: the rig's coat draws the given atlas instead of its own.
func _swap_atlas(node: Node3D, path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		push_error("toon lineup: no atlas at %s" % path)
		return
	img.generate_mipmaps()
	for n in node.find_children("*", "", true, false):
		if n is BokiRig and (n as BokiRig)._coat != null:
			(n as BokiRig)._coat.set_shader_parameter(
				"albedo_tex", ImageTexture.create_from_image(img)
			)
	if "--ab-plain" in OS.get_cmdline_user_args():  # (the old atlas as the shared look drew it, no coat override)
		_apply_look(node, PLAIN_LOOK)


## A Boki's painted-coat materials (the atlas) with these shader uniforms put over the game's; albedo_flat* only on
## the atlas, so the face and eyes keep their texture.
func _apply_look(node: Node, look: Dictionary) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		for s in (mi as MeshInstance3D).get_surface_override_material_count():
			var mat := (mi as MeshInstance3D).get_active_material(s)
			if (
				mat is ShaderMaterial
				and (mat as ShaderMaterial).get_shader_parameter("use_tex") == true
			):
				var tex: Texture2D = (mat as ShaderMaterial).get_shader_parameter("albedo_tex")
				var coat := tex.resource_path.contains("atlas")
				for k in look:
					if coat or not String(k).begins_with("albedo_flat"):
						(mat as ShaderMaterial).set_shader_parameter(k, look[k])


## The model's own pixels in a window round `at` (not the empty spot, and not the ground darkened by its shadow: a
## shadow keeps the ground's colour balance, a model does not): mean luminance, mean HSV saturation, pixel count, the
## 10th and 90th percentile luminance (its shaded and lit sides) and the centre of those pixels, which the crop is
## cut round (the model stands low in the frame, not on `at`).
func _model_stats(img: Image, empty: Image, at: Vector3) -> Dictionary:
	var cam := main.get_viewport().get_camera_3d()
	var c := cam.unproject_position(at)
	var sum := 0.0
	var sat := 0.0
	var sum_p := Vector2.ZERO
	var n := 0
	var lums := PackedFloat32Array()
	var half := Vector2i(160, 160)
	for y in range(int(c.y) - half.y, int(c.y) + half.y):
		for x in range(int(c.x) - half.x, int(c.x) + half.x):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var a := img.get_pixel(x, y)
			var b := empty.get_pixel(x, y)
			var la := maxf(a.get_luminance(), 0.001)
			var lb := maxf(b.get_luminance(), 0.001)
			var hue_shift := (
				Vector3(a.r / la - b.r / lb, a.g / la - b.g / lb, a.b / la - b.b / lb).length()
			)
			if hue_shift > DIFF_MIN:
				sum += la
				lums.append(la)
				sat += a.s
				sum_p += Vector2(x, y)
				n += 1
	n = maxi(n, 1)
	var centre := Vector2i(sum_p / n) if sum_p != Vector2.ZERO else Vector2i(c)
	lums.sort()
	var p10 := lums[int(lums.size() * 0.1)] if lums.size() > 0 else 0.0
	var p90 := lums[int(lums.size() * 0.9)] if lums.size() > 0 else 0.0
	return {"lum": sum / n, "sat": sat / n, "n": n, "centre": centre, "p10": p10, "p90": p90}


func _crop_px(img: Image, centre: Vector2i, px: Vector2i, mag: float) -> Image:
	var rg := Rect2i(centre - px / 2, px).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rg)
	crop.resize(int(px.x * mag), int(px.y * mag), Image.INTERPOLATE_BILINEAR)
	return crop


func _write(shots: Array) -> void:
	shots.sort_custom(func(p, q): return float(p[2]["lum"]) < float(q[2]["lum"]))
	var w := int(crop_px.x * zoom)
	var h := int(crop_px.y * zoom)
	var rows := int(ceil(shots.size() / float(COLS)))
	var sheet := Image.create(w * COLS, h * rows, false, Image.FORMAT_RGB8)
	var f := FileAccess.open(dir.path_join("lineup_stats.tsv"), FileAccess.WRITE)
	f.store_line("kind\tid\trendered_lum\trendered_sat\tpixels\tlum_p10\tlum_p90")
	for i in shots.size():
		var crop: Image = shots[i][1]
		crop.convert(Image.FORMAT_RGB8)  # blit_rect between formats draws nothing
		sheet.blit_rect(
			crop,
			Rect2i(Vector2i.ZERO, crop.get_size()),
			Vector2i((i % COLS) * w, int(i / COLS) * h)
		)
		var st: Dictionary = shots[i][2]
		var row := [
			shots[i][0][0], _label(shots[i][0]), st["lum"], st["sat"], st["n"], st["p10"], st["p90"]
		]
		f.store_line("%s\t%s\t%.3f\t%.3f\t%d\t%.3f\t%.3f" % row)
	f.close()
	sheet.save_png(dir.path_join("lineup_sheet.png"))
