extends RefCounted
## --expedition-shots=<dir> [--size=WxH]: the expedition panel (Hunter pick) on a fresh save (one Hunter
## open, the rest locked) and on a save with every Hunter open. Run with a real renderer; --size resizes the
## window. Writes <H>_fresh.png and <H>_all.png (H = window height), prints "ESHOT <name>". Never touches the real save.

var main: Node
var dir := ""

func _shot(shot_name: String) -> void:
	await main.get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	print("ESHOT %s" % shot_name)

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--expedition-shots="):
			dir = String(a).substr(19)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			m.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	ClassUnlock.choose_starters(["gunslinger"])
	main.show_screen("title", {})
	await main.get_tree().create_timer(2.0).timeout
	var home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	home._open_expedition()
	var h := m.get_window().size.y
	await _shot("%d_fresh" % h)
	Save.d["classes"]["open"] = Arch.ids()
	home._open_expedition()
	await _shot("%d_all" % h)
	print("ESHOT DONE")
	main.get_tree().quit()
