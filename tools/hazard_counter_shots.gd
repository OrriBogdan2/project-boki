extends RefCounted
## --hazard-counter-shots --shots-dir=<dir>: the hazard line ("Walks the lava safely") on the expedition
## portal's carry pick, a Boki card (Training tab) and a Field Book page. Real renderer; never touches the real save.

var main: Node
var dir := "docs/shots/farm-hazard-counter-card"

func _shot(shot_name: String) -> void:
	await main.get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	print("HSHOT %s" % shot_name)

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	m.get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	d["tutorial"] = {"hatched": true, "intro": true}
	for sp in ["cindowary", "lilybara", "cairnback"]:
		d["roster"].append(Save.new_kin(sp, sp.capitalize()))
	d["active"] = d["roster"][0]["uid"]
	d["active2"] = d["roster"][1]["uid"]
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
	await main.get_tree().process_frame
	var is_head := func(l) -> bool: return String((l as Label).text).to_lower() == "boki you bring"
	var head: Label = home.panel_host.find_children("*", "Label", true, false).filter(is_head)[0]
	for sc in home.panel_host.find_children("*", "ScrollContainer", true, false):
		var box := sc as ScrollContainer
		box.scroll_vertical += int(head.global_position.y - box.global_position.y) - 8
	await _shot("portal_carry_pick")
	home.kin_tab = "Training"
	home._open_kin(d["roster"][0])
	await _shot("boki_card_cindowary")
	home._open_kin(d["roster"][2])
	await _shot("boki_card_cairnback_none")
	home._close_panel()
	Overlay.open_dex("lilybara")
	await _shot("field_book_lilybara")
	print("HSHOT DONE")
	main.get_tree().quit()
