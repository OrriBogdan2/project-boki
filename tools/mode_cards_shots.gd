extends RefCounted
## --mode-cards-shots --shots-dir=<dir> [--size=WxH]: the Trios / Solos cards on the expedition panel (Trios
## picked, then Solos) and on the online lobby, at the window size. GPU, under xvfb. Never touches the save.

var main: Node
var dir := ""

func _shot(shot_name: String) -> void:
	await main.get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var file := "%s_%d.png" % [shot_name, main.get_window().size.y]
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
	print("MODE-CARDS-SHOT ", file)

func _cards_into_view(home: Node) -> void:
	var sc: ScrollContainer = home._panel_scroll()
	if sc:
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
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
	d["classes"]["open"] = Arch.ids()
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
	for mode in Data.MODES:
		Save.d["exp_mode"] = mode
		home._open_expedition()
		await main.get_tree().process_frame
		_cards_into_view(home)
		await _shot("panel_" + mode)
	main.show_screen("lobby", {})
	await _shot("lobby_solos")
	print("MODE-CARDS-SHOT DONE")
	main.get_tree().quit()
