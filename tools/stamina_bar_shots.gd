extends "res://tools/vv_shots.gd"
## --stamina-bar-shots --shots-dir=<dir>: the dash bar's review screenshots in a live Arena match (xvfb
## with a renderer), on a two-charge hunter. A 6-frame strip at gameplay zoom round the hero's head and
## plate (full, dash, dash, refilling, refill done with the flash, empty press), one with the cool-blue
## long-dash state, and the bottom-left HUD block. <dir>/captions.txt gets "file: caption" per file.

const CAP_STRIP := "Dash bar over the hunter, gameplay zoom, a two-charge hunter. 1 full (both lit, long dash pale)"\
	+ "; 2 dash; 3 second dash (both spent, dimmed not hidden); 4 a charge sweeping back; 5 refill"\
	+ " complete, the bright flash; 6 empty press, red flash and shake"
const CAP_COOL := "The long dash on cooldown: the bar tints cool blue and its own segment (right) sweeps back"
const CROP := Vector2i(170, 150)

func run(main_node: Node) -> void:
	main = main_node
	who = "juggernaut"
	hero_name = "stamina"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	await _strip_main()
	await _cool()
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		var cols := String(l).split("|")
		f.store_line("%s: %s" % [cols[1], cols[2]])
	f.close()
	print("STAMINASHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _take(kind: String, file: String, caption: String, focus: Callable) -> void:
	var img := main.get_viewport().get_texture().get_image()
	if kind == "hud":
		var sz := img.get_size()
		var crop := img.get_region(Rect2i(0, sz.y - 170, 560, 170))
		crop.resize(1120, 340, Image.INTERPOLATE_BILINEAR)
		crop.save_png(dir.path_join(file + ".png"))
		lines.append("x|%s.png|%s" % [file, caption])
		return
	var crop := _crop(img, P.position + Vector3(0, 2.2, 0), CROP, 2.2)
	var strip_file := "%s.png" % kind
	if not strips.has(strip_file):
		strips[strip_file] = []
		lines.append("x|%s|%s" % [strip_file, caption])
	(strips[strip_file] as Array).append(crop)
	_save_strip(strip_file)

func _strip_main() -> void:
	await _reset(9.0)
	P.ctrl = "local"
	P.ak.cd["dash"] = 0.0
	var fired := {}
	var once := func(key: String, fn: Callable):
		if not fired.has(key):
			fired[key] = true
			fn.call()
	var each := func(t: float):
		m.hud.plates.stam.clock = 100.0 + t
		if t >= 0.2: once.call("d1", func(): P.do_dash())
		if t >= 0.7: once.call("d2", func(): P.do_dash())
		if t >= 1.4: once.call("half", func(): P.dashes = 0.5)
		if t >= 1.5: once.call("ex", func(): P.ex_cd = 0.0)
		if t >= 2.0: once.call("near", func(): P.dashes = 1.97)
		if t >= 2.6: once.call("empty", func():
			P.dashes = 0.0
			P.ex_cd = 6.0
			P.do_dash())
	var marks := [
		[0.1, "dash_bar_strip", "dash_bar_strip", CAP_STRIP],
		[0.4, "dash_bar_strip", "", ""],
		[0.9, "dash_bar_strip", "", ""],
		[1.7, "dash_bar_strip", "", ""],
		[2.4, "dash_bar_strip", "", ""],
		[2.66, "dash_bar_strip", "", ""],
		[2.0, "hud", "dash_bar_hud", "Bottom-left HUD block with the dash bar under the dash slot, a charge half back"],
	]
	await _go(3.0, each, marks)

func _cool() -> void:
	await _reset(9.0)
	m.hud.plates.stam.clock = -1.0
	P.dashes = 1.0
	P.ex_cd = StaminaBar.long_cd(P) * 0.6
	await _go(0.2, Callable(), [[0.1, "dash_bar_cool", "dash_bar_cool", CAP_COOL]])
