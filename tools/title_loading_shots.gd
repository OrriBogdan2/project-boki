extends RefCounted
## --title-loading-shots --shots-dir=<dir> [--size=WxH] [--arch=a,b]: the title screen and the loading screen
## (one per Hunter, a trio on the first map, the bar half full) as PNGs, <dir>/title.png and <dir>/loading_<arch>.png.
## Needs a renderer (GPU, or xvfb with a software one).

const SHOT_ARCHS := ["gunslinger", "rimewright", "dolm"]
const SETTLE_FRAMES := 20

var main: Node


func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	var out := ""
	var win := Vector2i(1920, 1080)
	var archs: Array = SHOT_ARCHS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--size="):
			var wh := a.substr(7).split("x")
			win = Vector2i(int(wh[0]), int(wh[1]))
		if a.begins_with("--arch="):
			archs = Array(a.substr(7).split(",", false))
	DirAccess.make_dir_recursive_absolute(out)
	main.get_tree().root.size = win
	main.get_window().size = win
	await _frames(3)
	await main.show_screen("title", {})
	await _frames(SETTLE_FRAMES)
	_save(out.path_join("title.png"))
	for ak in archs:
		var ld: Node = load("res://scripts/ui/loading.gd").new()
		ld.setup({"teams": 10, "squad": 3, "tier": 0, "arch": ak, "seed": 7})
		main.add_child(ld)
		ld.advance(0.5)
		await _frames(SETTLE_FRAMES + 60)
		_save(out.path_join("loading_%s.png" % ak))
		ld.queue_free()
	print("TITLE-LOADING SHOTS DONE: ", out)
	main.get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame


func _save(path: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(path)
