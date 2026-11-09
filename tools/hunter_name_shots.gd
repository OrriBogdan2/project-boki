extends RefCounted
## --hunter-name-shots --shots-dir=<dir>: the Hunter kit card (name big, title under it) and the
## Hunters-screen tile row, for the "name, not title" proof. Needs a renderer. Never touches the save.

func run(main: Node) -> void:
	Save.no_write = true
	var dir := "user://"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	var holder := Control.new()
	main.add_child(holder)
	if main.fade:
		main.fade.reveal(0.05)
	var layer := CanvasLayer.new()
	holder.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var box := UI.vbox(10)
	box.position = Vector2(30, 20)
	layer.add_child(box)
	box.add_child(KitCard.make("dolm", "cindle"))
	var row := UI.hbox(6)
	for id in Arch.ids().slice(0, 6):
		row.add_child(UI.choice(Arch.hunter_name(id), false, func(): pass, 104))
	box.add_child(row)
	await main.get_tree().create_timer(1.0).timeout    # the fade reveal
	for i in 4:
		await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir + "/hunter_name.png")
	print("SHOT %s/hunter_name.png" % dir)
	main.get_tree().quit(0)
