extends "res://tools/vv_shots.gd"
## --combo-mark-shots --shots-dir=<dir>: the overhead combo tag on a rival for Sable, Vex, Sparkle, Cinder,
## Neve, Meeko and Kael (the Slam window), one strip per kit (fresh, half the time left, the payoff frame,
## gone), cropped round the target's plate in a live Arena match (the Sparkle/Vex shot rig,
## tools/vv_shots.gd: title fade lifted, camera driven). Needs a renderer (jobq submit --needs gpu).

const PLATE_CROP := Vector2i(220, 190)   # px round the target's plate (scaled 2x)
const ARCHES := ["thief", "gunslinger", "mage", "ashwick", "rimewright", "tender", "juggernaut"]

var tool: RefCounted

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	tool = load("res://tools/combo_mark_check.gd").new()
	for arch in ARCHES:
		who = arch
		await _setup()
		await _kit(arch)
		m.queue_free()
		await main.get_tree().process_frame
	print("COMBOMARKSHOTS %d strips in %s" % [ARCHES.size(), dir])
	main.get_tree().quit(0)

func _kit(arch: String) -> void:
	var file := "combo_tag_%s.png" % arch
	strips[file] = []
	tool.apply(arch, P.ak, T)
	await _go(0.1)
	_plate(file)
	await _go(float(P.ak.combo_read(T)["total"]) * 0.5)
	_plate(file)
	tool.payoff(arch, P, P.ak, T)
	await _go(DT)
	_plate(file)
	await _go(6.0)
	_plate(file)
	_save_strip(file)
	print("COMBOMARKSHOT %s tag=%s" % [arch, str(P.ak.combo_read(T))])

func _plate(file: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	(strips[file] as Array).append(_crop(img, T.position + Vector3(0, 3.0, 0), PLATE_CROP, 2.0))

## Strip files go straight into the shots dir (no hero prefix).
func _save_strip(file: String) -> void:
	var frames: Array = strips[file]
	var w: int = (frames[0] as Image).get_width()
	var hh: int = (frames[0] as Image).get_height()
	var out := Image.create(w * frames.size() + 4 * (frames.size() - 1), hh, false, (frames[0] as Image).get_format())
	out.fill(Color(0.05, 0.05, 0.07))
	for i in frames.size():
		var fr: Image = frames[i]
		out.blit_rect(fr, Rect2i(Vector2i.ZERO, fr.get_size()), Vector2i(i * (w + 4), 0))
	out.save_png(dir.path_join(file))
