extends RefCounted
## --ghost-visible-check: the quiet (Ghost) button reads as a button at rest, on any background: its
## normal and disabled states are drawn boxes (a fill and a rim), its label is brighter than the muted
## body text, and it is not the Primary ticket.
## --ghost-visible-shots --shots-dir=<dir> (needs a renderer, e.g. xvfb-run): the Hob talk menu row over
## the open farm, the Expedition panel and the Boki panel, for the PR's before/after.

var main: Node
var dir := "user://shots"
var fails := 0


func ok(what: String, cond: bool) -> void:
	printerr("GHOSTVIS %-52s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		fails += 1


func run(m: Node, what: String) -> void:
	main = m
	if what == "shots":
		await _shots()
		m.get_tree().quit()
		return
	var t := UI.theme()
	for state in ["normal", "disabled"]:
		var sb := t.get_stylebox(state, "Ghost") as UiTorn
		ok("Ghost %s is a drawn box" % state, sb != null and sb.fill.a > 0.1)
		ok("Ghost %s has a light rim" % state, sb != null and sb.edge.a > 0.1)
	var lum := func(c: Color) -> float: return c.get_luminance() * c.a
	ok("Ghost label brighter than muted text", lum.call(t.get_color("font_color", "Ghost")) > lum.call(UI.MUTED))
	ok("Ghost keeps a hover face", t.get_stylebox("hover", "Ghost") != t.get_stylebox("normal", "Ghost"))
	ok("Ghost is not a ticket (that is Primary)", not (t.get_stylebox("normal", "Ghost") as UiTorn).ticket)
	print("GHOSTVIS %s" % ("FAIL" if fails > 0 else "OK"))
	m.get_tree().quit(1 if fails > 0 else 0)


func _shot(shot_name: String, home) -> void:
	for i in 3:
		await main.get_tree().process_frame
	if main.fade:
		main.fade.reveal(0.05)
	await main.get_tree().create_timer(0.8).timeout
	if home.hover_box:
		home.hover_box.visible = false
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	print("GHOSTSHOT %s" % shot_name)


func _shots() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	main.get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["stats"] = {"extracts": 0, "bosses": 0, "caught": 0, "harvested": 0, "hatched": 1, "fb_built": 0}
	Save.d = d
	Save.d["gems"] = 200
	Save.d["extracts"] = 0
	var home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	FarmTutorial.skip()
	if not is_instance_valid(home.hob.node):       # (no stall or house site in this bare farm: stand him by the player)
		home.hob.node = HobModel.new()
		home.add_child(home.hob.node)
		home.hob.pos = home.player.position + Vector3(2, 0, 0)
		home.hob.node.position = home.hob.pos
	home.cam.snap(home.player.position)
	await main.get_tree().create_timer(1.0).timeout
	home.hob.talk()
	var box: TalkBox = home.hob.chat.box
	for i in 40:
		if box.extra.get_child_count() > 0:
			break
		box.advance()
		await main.get_tree().create_timer(0.15).timeout
	await _shot("1_hob_menu", home)
	box.close()
	ClassUnlock.choose_starters(["gunslinger"])
	home._close_panel()
	home._open_expedition()
	await _shot("2_expedition", home)
	home._close_panel()
	home._open_kin(k)
	await _shot("3_boki_panel", home)
