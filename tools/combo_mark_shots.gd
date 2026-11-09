extends RefCounted
## --combo-mark-shots --shots-dir=<dir>: the overhead combo tag on a rival for Sable, Vex and Sparkle, one
## strip per kit (fresh, half the time left, the payoff frame, gone), cropped round the target. Needs a
## renderer (jobq submit --needs gpu).

const CROP := Vector2i(300, 240)       # px round the target's plate
const GAP := 4                         # px between strip frames
const ARCHES := ["thief", "gunslinger", "mage"]

var main: Node
var dir := "shots"
var ac: RefCounted
var tool: RefCounted

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	tool = load("res://tools/combo_mark_check.gd").new()
	for arch in ARCHES:
		await _kit(arch)
	print("COMBOMARKSHOTS %d strips in %s" % [ARCHES.size(), dir])
	main.get_tree().quit(0)

func _kit(arch: String) -> void:
	var r: Array = ac.setup(arch, 5.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var frames: Array = []
	tool.apply(arch, P.ak, T)
	frames.append(await _grab(m, T))
	ac.step(m, float(P.ak.combo_read(T)["total"]) * 0.5)
	frames.append(await _grab(m, T))
	tool.payoff(arch, P, P.ak, T)
	frames.append(await _grab(m, T))
	ac.step(m, 6.0)
	frames.append(await _grab(m, T))
	_save(arch, frames)
	ac.done(m)

func _grab(m: Match, T: Hunter) -> Image:
	await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	var c := m.cam.unproject_position(T.position + Vector3(0, 2.6, 0))
	var rg := Rect2i(Vector2i(int(c.x) - CROP.x / 2, int(c.y) - CROP.y / 2), CROP)
	return img.get_region(rg.intersection(Rect2i(Vector2i.ZERO, img.get_size())))

func _save(arch: String, frames: Array) -> void:
	var w: int = (frames[0] as Image).get_width()
	var first: Image = frames[0]
	var wide := w * frames.size() + GAP * (frames.size() - 1)
	var out := Image.create(wide, first.get_height(), false, first.get_format())
	out.fill(Color(0.05, 0.05, 0.07))
	for i in frames.size():
		var fr: Image = frames[i]
		out.blit_rect(fr, Rect2i(Vector2i.ZERO, fr.get_size()), Vector2i(i * (w + GAP), 0))
	out.save_png(dir.path_join("combo_tag_%s.png" % arch))
