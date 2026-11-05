extends RefCounted
## --boki-moves-shots --shots-dir=<dir>: the new-Boki screen (item 82) with no tip, an ability tip and
## the bond tip open. Needs a renderer (xvfb with opengl3). Never touches the save.

const INTRO_S := 7.0       # s: the reveal's look-at-you intro, before the card is up

func run(main: Node) -> void:
	Save.no_write = true
	var dir := "user://"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	var holder := Node3D.new()     # as --reveal-test: the reveal is the current screen
	main.add_child(holder)
	main.current = holder
	if main.fade:
		main.fade.reveal(0.05)     # the boot splash stays up when a tool starts a screen by hand
	var rv := KinReveal.new("cindle", Save.new_kin("cindle", "", 4242))
	holder.add_child(rv)
	await main.get_tree().create_timer(INTRO_S).timeout
	await _shot(main, dir + "/reveal_card.png")
	rv.moves.show_tip(0)
	await _shot(main, dir + "/reveal_tip_ability.png")
	rv.moves.hide_tip(0)
	rv.moves.tiles[rv.moves.tiles.size() - 1].grab_focus()
	await _shot(main, dir + "/reveal_tip_bond.png")
	main.get_tree().quit(0)

func _shot(main: Node, path: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT %s" % path)
