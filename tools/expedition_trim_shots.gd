extends RefCounted
## --expedition-trim-shots --shots-dir=<dir>: every expedition screen at 1280x720 for the before/after of the
## trim (11-17). Writes <dir>/1_first.png (first visit), 2_main.png (a few drops open, two Boki, the safe drop),
## 3_details.png (the same with Details open when the panel has one), 4_risky.png (a drop where Boki can be
## lost) and 5_confirm.png (the "Your Boki can be lost" sheet). Needs a real renderer. Never touches the save.

var main: Node
var dir := ""


func _shot(shot_name: String) -> void:
	await main.get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	print("ETSHOT %s" % shot_name)


func _save(extracts: int, boki: int) -> void:
	var d := Save.fresh()
	for i in boki:
		var k := Save.new_kin("zapple", "Pip")
		if i > 0:
			k = Save.new_kin("glintmole", "Glintmole")
		d["roster"].append(k)
		if i == 0:
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["arch"] = "gunslinger"
	d["cls"] = Arch.weight("gunslinger")
	d["extracts"] = extracts
	Save.d = d
	ClassUnlock.choose_starters(["gunslinger"])


func _button(host: Node, text: String) -> Button:
	for n in host.find_children("*", "Button", true, false):
		if (n as Button).text.begins_with(text):
			return n
	return null


func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	m.get_window().size = Vector2i(1280, 720)
	Save.no_write = true
	_save(0, 1)
	main.show_screen("title", {})
	await main.get_tree().create_timer(2.0).timeout
	var home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	home._open_expedition()
	await _shot("1_first")
	var risky := 0
	for i in Data.TIERS.size():
		if KinLoss.at_risk(i):
			risky = i
			break
	_save(int(Data.TIERS[risky]["unlock"]), 2)
	home.exp_tier = 0
	home._open_expedition()
	await _shot("2_main")
	var more := _button(home.panel_host, "Details")
	if more == null:
		more = _button(home.panel_host, "More")
	if more != null:
		more.pressed.emit()
		await _shot("3_details")
	home.exp_tier = risky
	home._open_expedition()
	await _shot("4_risky")
	home._confirm_start()
	await _shot("5_confirm")
	print("ETSHOT DONE")
	main.get_tree().quit()
