extends "res://tools/vv_shots.gd"
## --breah-shots --shots-dir=<dir> [--breah-only=<part>]: Breah's review screenshots in a live Arena match
## (xvfb with a renderer), reusing the Vireo/Venator shot rig (tools/vv_shots.gd). Strips are a 3-wide grid
## of crops round her at gameplay zoom; <dir>/captions.txt gets "file: caption" per file.

const GRID_CROP := Vector2i(280, 200)    # px round the hero per strip frame (scaled 1.5x)
const GRID_COLS := 3
const PARTS := ["rmb"]

func run(main_node: Node) -> void:
	main = main_node
	who = "dolm"
	hero_name = "breah"
	var parts: Array = PARTS
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--breah-only="):
			parts = [arg.substr(13)]
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	for part in parts:
		await Callable(self, "_breah_%s" % part).call()
	_write_captions()
	print("BREAHSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

## captions.txt keeps the other parts' lines and replaces the lines of the files just taken.
func _write_captions() -> void:
	var path := dir.path_join("captions.txt")
	var fresh := {}
	for l in lines:
		var cols := String(l).split("|")
		fresh[cols[1]] = cols[2]
	var keep: Array = []
	if FileAccess.file_exists(path):
		for old in FileAccess.get_file_as_string(path).split("\n", false):
			if not fresh.has(String(old).get_slice(":", 0)):
				keep.append(old)
	var f := FileAccess.open(path, FileAccess.WRITE)
	for l in keep:
		f.store_line(l)
	for file in fresh:
		f.store_line("%s: %s" % [file, fresh[file]])
	f.close()

func _take(kind: String, file: String, caption: String, focus: Callable) -> void:
	if kind == "full":
		super._take(kind, file, caption, focus)
		return
	var img := main.get_viewport().get_texture().get_image()
	var crop := _crop(img, P.position + Vector3(0, 0.9, 0), GRID_CROP, 1.5)
	var strip_file := "%s_%s.png" % [hero_name, kind]
	if not strips.has(strip_file):
		strips[strip_file] = []
		lines.append("%s|%s|%s" % [hero_name, strip_file, caption])
	(strips[strip_file] as Array).append(crop)
	_save_strip(strip_file)

func _save_strip(file: String) -> void:
	var frames: Array = strips[file]
	var w: int = (frames[0] as Image).get_width()
	var hh: int = (frames[0] as Image).get_height()
	var cols := mini(GRID_COLS, frames.size())
	var rows := ceili(frames.size() / float(GRID_COLS))
	var out_size := Vector2i(w * cols + 4 * (cols - 1), hh * rows + 4 * (rows - 1))
	var out := Image.create(out_size.x, out_size.y, false, (frames[0] as Image).get_format())
	out.fill(Color(0.05, 0.05, 0.07))
	for i in frames.size():
		var fr: Image = frames[i]
		var at := Vector2i((i % GRID_COLS) * (w + 4), (i / GRID_COLS) * (hh + 4))
		out.blit_rect(fr, Rect2i(Vector2i.ZERO, fr.get_size()), at)
	out.save_png(dir.path_join(file))

## Quakefall: the charge, then the hop and the two-fist smash on landing.
func _breah_rmb() -> void:
	await _reset(6.0)
	_aim(home + Vector3(6.0, 0, 0))
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	var hold_rmb := func(t: float): P.inp["sec_hold"] = t < 1.2
	var marks := _strip(
		"rmb_strip",
		"Quakefall (RMB), gameplay zoom: the gathered crouch with the circle and its sweet spot; the push-off;"
			+ " fists high at the top of the short hop; swung down as she drops; the smash on landing;"
			+ " low in the crater",
		[1.15, 1.25, 1.37, 1.49, 1.56, 1.9]
	)
	marks.append([1.0, "full", "rmb_charge", "Quakefall charging: the red circle a hop ahead, the sweet spot grown"])
	marks.append([1.58, "full", "rmb_slam", "Quakefall landing: the starburst, chips and crater where she lands"])
	await _go(2.1, hold_rmb, marks)
