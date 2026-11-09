extends RefCounted
## --menus-more-shots=<dir>: the title, the expedition panel and the Esc menu with their More buttons closed and open
## (run with a real renderer: jobq --needs gpu). Never touches the real save.

var main: Node
var dir := ""

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--menus-more-shots="):
			dir = String(a).substr(19)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["stats"] = {"extracts": 1}
	Save.d = d
	main.show_screen("title", {})
	await _settle(2.5)
	await _shot("title_closed")
	_press(main.screen_node().menu_col, "More...")
	await _settle(0.4)
	await _shot("title_more")
	var home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null:
			break
		await main.get_tree().process_frame
	home._open_expedition()
	await _settle(0.8)
	await _shot("expedition_closed")
	_press(home.panel_host, "More v")
	await _settle(0.4)
	await _shot("expedition_more")
	home._close_panel()
	Overlay.open_pause("home")
	await _settle(0.6)
	await _shot("pause_closed")
	Overlay.pause_acts[2].call()
	await _settle(0.4)
	await _shot("pause_more")
	print("MENUSMORE DONE")
	main.get_tree().quit()

## Presses the first visible button called `text` under `node`.
func _press(node: Node, text: String) -> void:
	for c in node.find_children("*", "Button", true, false):
		if (c as Button).text == text:
			(c as Button).pressed.emit()
			return

func _settle(secs: float) -> void:
	if main.fade:
		main.fade.reveal(0.05)
	await main.get_tree().create_timer(secs).timeout

func _shot(shot_name: String) -> void:
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
