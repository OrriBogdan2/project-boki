extends RefCounted
## --title-shots=<dir>: the title screen for a before/after sheet. Four shots: a fresh save and a save with
## a Boki, each with the owner's admin tools on and off (off = Record.level 1, as a clean recording run);
## with admin on also the corner chip's popover when the title has one, and the title's Settings page.
## Run with a real renderer (xvfb-run, --rendering-driver opengl3, --resolution WxH). Never touches the
## real save. Writes <name>.png and prints "TSHOT <name>".

var main: Node
var dir := ""


func _shot(shot_name: String, settle := 0.5) -> void:
	await main.get_tree().create_timer(settle).timeout
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	print("TSHOT %s" % shot_name)


func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--title-shots="):
			dir = String(a).substr(14)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	for saved in [false, true]:
		Save.d = Save.fresh()
		if saved:
			var k := Save.new_kin("zapple", "Pip")
			Save.d["roster"].append(k)
			Save.d["active"] = k["uid"]
		for admin in [true, false]:
			Record.level = 0 if admin else 1
			var who := "admin" if admin else "player"
			var tag := ("save_" if saved else "fresh_") + who
			main.show_screen("title", {})
			await _shot(tag, 3.0)
			var ts: Node = main.screen_node()
			var chip = ts.find_child("AdminChip", true, false) if ts else null
			if chip:
				(chip as Button).pressed.emit()
				await _shot(tag + "_chip", 0.6)
			if admin and saved:
				Overlay.ctx = "title"
				Overlay.open_settings()
				await _shot(tag + "_settings", 0.8)
				Overlay.close()
	Record.level = 0
	print("TSHOT DONE")
	main.get_tree().quit()
