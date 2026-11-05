extends "res://tools/vv_shots.gd"
## --breah-shots --shots-dir=<dir> [--breah-only=<part>]: Tarek's review screenshots in a live Arena match
## (xvfb with a renderer), reusing the Ryzz/Vex shot rig (tools/vv_shots.gd). Strips are a 3-wide grid
## of crops round her at gameplay zoom; <dir>/captions.txt gets "file: caption" per file.

const GRID_CROP := Vector2i(280, 200)    # px round the hero per strip frame (scaled 1.5x)
const GRID_COLS := 3
const PARTS := ["rmb", "rocks", "dash", "spine", "climb", "glide"]

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
	var at: Vector3 = focus.call() if focus.is_valid() else P.position + Vector3(0, 0.9, 0)
	var crop := _crop(img, at, GRID_CROP, 1.5)
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

## Quakefall: the short hold, then the hop and the two-fist smash on landing; the tap.
func _breah_rmb() -> void:
	await _reset(6.0)
	_aim(home + Vector3(6.0, 0, 0))
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	var hold_rmb := func(t: float): P.inp["sec_hold"] = t < 1.0
	var marks := _strip(
		"rmb_strip",
		"Quakefall hold (RMB), gameplay zoom: the gathered crouch with the circle and its sweet spot; the push-off;"
			+ " fists high at the top of the hop; swung down as he drops; the smash on landing; low in the crater",
		[0.2, 0.5, 0.75, 0.95, 1.06, 1.2]
	)
	marks.append([0.42, "full", "rmb_charge", "Quakefall charging (0.45s cap): the red circle a hop ahead"])
	marks.append([1.08, "full", "rmb_slam", "Quakefall landing: the starburst, chips and crater where he lands"])
	await _go(1.3, hold_rmb, marks)
	await _reset(6.0)
	_aim(home + Vector3(6.0, 0, 0))
	P.inp["sec_hold"] = false
	P.ak.press_rmb()
	var tap_marks := _strip(
		"rmb_tap_strip",
		"Quakefall tap (RMB), gameplay zoom: no hop, an instant slam just ahead in a slightly smaller circle",
		[0.02, 0.06, 0.12, 0.2, 0.35, 0.55]
	)
	tap_marks.append([0.08, "full", "rmb_tap", "Quakefall tap: the slam ahead of him, no hop"])
	await _go(0.6, Callable(), tap_marks)

## Stone Row at gameplay zoom, then the rocks crumbling.
func _breah_rocks() -> void:
	await _reset(14.0)
	_aim(home + Vector3(6.0, 0, 0))
	P.ak.cd["e"] = 0.0
	P.ak.use_e()
	var on_rocks := func(): return home + Vector3(3.2, 1.0, 0)
	var marks := _focused(
		_strip(
			"rocks_strip",
			"Stone Row rising (item 67), gameplay zoom: the red tell, the dust and the rocks heaving up, standing",
			[0.15, 0.25, 0.32, 0.4, 0.5, 0.9]
		),
		on_rocks
	)
	marks.append([1.0, "full", "rocks_row", "Stone Row at the match camera, beside him for scale", on_rocks])
	await _go(1.1, Callable(), marks)
	var walls: Array = m.verbs.walls.duplicate()
	var strip := _focused(
		_strip(
			"crumble_strip", "A rock breaking (item 67): the crack, the columns slumping, the chips and dust",
			[0.03, 0.1, 0.18, 0.26, 0.34, 0.5]
		),
		on_rocks
	)
	Engine.time_scale = 0.1      # (the crumble is a tween on real time; a software render takes longer per frame)
	for w in walls:
		if w.get("rock", false): w["t"] = 0.0
	await _go(0.6, Callable(), strip)
	Engine.time_scale = 1.0

func _focused(marks: Array, focus: Callable) -> Array:
	for mk in marks:
		(mk as Array).append(focus)
	return marks

## Her two dash moves: Rock Hop on the ground, the long dash in the air.
func _breah_dash() -> void:
	await _reset(9.0)
	_aim(home + Vector3(9.0, 0, 3.0))
	P.ak.on_dash(false)
	var K: DolmKit = P.ak
	# the chain re-presses by itself as it reaches each skid, steered a little each time
	var press := func(_t):
		if K.hop.chaining() and K.hop.st["phase"] == "skid":
			_aim(P.pos + Vector3(6.0, 0, -4.0 if int(K.hop.st["n"]) == 1 else 4.0))
			K.on_dash(true)
	var ground := _strip(
		"dash_ground_strip",
		"Rock Hop (ground dash), gameplay zoom: crouched on the rock as it bursts up; a low hop on the foot slab; the"
			+ " next rock rising under him and the skid; hop 2 steered; hop 3 steered; the crash; the rock rolling on",
		[0.04, 0.2, 0.42, 0.6, 0.85, 1.05, 1.3, 1.5, 1.7]
	)
	await _go(1.9, press, ground)
	await _reset(9.0)
	_aim(home + Vector3(4.0, 0, 0))
	P.pos.y += 2.2
	P.grounded = false
	P.do_dash()
	var air := _strip(
		"dash_air_strip",
		"Air dash, gameplay zoom: the gather (fists in at the chest); the shoulder-first barge, lead fist low,"
			+ " legs trailing; held through the push; braced, knees up, as it ends (0.23s). Reference: the source's"
			+ " ground shove (footage 128.8-129.4 s, shoulder down behind the rock, fists forward), taken into the air",
		[0.02, 0.07, 0.13, 0.19, 0.24]
	)
	await _go(0.4, Callable(), air)

## Basalt Spine: the ridge of real rocks, one rock deep, centre-out (tap across the aim).
func _breah_spine() -> void:
	await _reset(14.0)
	P.lvl = 6
	P.ak.cd["x"] = 0.0
	_aim(home + Vector3(5.0, 0, 0))
	P.inp["x_down"] = false
	HunterKeys.ult_pressed(P)
	var at_ridge := func(): return (P.ak as DolmKit).spine.center + Vector3(0, 0.6, 0)
	var marks := [
		[0.12, "full", "spine_cracks", "Basalt Spine released: the molten cracks along the line everyone sees for 0.2s",
			at_ridge],
		[0.42, "full", "spine_rising", "Basalt Spine rising centre-out: real rocks (Stone Row's own), one rock deep",
			at_ridge],
		[0.9, "full", "spine_up", "Basalt Spine up: a ridge of punchable rocks across the aim, one rock deep, no land;"
			+ " it stops at the island's edge (lower right)", at_ridge],
	]
	await _go(1.0, Callable(), marks)

## Item 25: she walks into her own rock and rises over it, no jump.
func _breah_climb() -> void:
	await _reset(14.0)
	_aim(home + Vector3(6.0, 0, 0))
	P.ak.cd["e"] = 0.0
	P.ak.use_e()
	await _go(0.4)
	var walk := func(_t: float): P.inp["move"] = Vector2(1, 0)
	var marks := _strip(
		"climb_strip",
		"Her own rock (item 25), gameplay zoom: she walks into it with no jump, rises up its face with her walk"
			+ " carried on, stands on its top (the rock slides under her, her foot ring on its top) and walks on over"
			+ " (about 0.6s to cross)",
		[0.3, 0.42, 0.5, 0.6, 0.72, 0.9]
	)
	await _go(1.1, walk, marks)
	P.inp["move"] = Vector2.ZERO

## Quakefall out of a glide (the owner's 23:00 answer): gliding, the press folds the glider, the plunge, the
## slam on landing.
func _breah_glide() -> void:
	await _reset(9.0)
	P.pos.y += 8.0
	P.grounded = false
	var glide := func(t: float):
		P.inp["glide"] = true
		if t >= 0.6 and t < 0.6 + DT:
			P.ak.press_rmb()
	var marks := _strip(
		"glide_slam_strip",
		"Quakefall out of a glide (per the source and the owner): gliding; the press folds the glider at once; the"
			+ " plunge at the glider's dive speed (32.5 m/s); the two-fist slam where she lands; the crater",
		[0.4, 0.62, 0.68, 0.75, 0.85, 1.2]
	)
	await _go(1.4, glide, marks)
	P.inp["glide"] = false
