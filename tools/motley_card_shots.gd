extends "res://tools/clip_shots.gd"
## --motley-card-shots --shots-dir=<dir>: the flurry's card (VoidCard) beside Motley at the viewer and the match camera,
## for the "Weapon scale + fit" proof. The kit's flight is S5's; this only shows its scale against him.

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	var look := PlayerLook.neutral()
	var m := Models.hunter(Arch.weight("ostra"), Data.TEAM_COLORS[0], Arch.signature("ostra"), "", look, "ostra")
	holder.add_child(m)
	m.rotation.y = deg_to_rad(200.0)
	var clips: WardenClips = m.get_node("Warden/Sync").get("clips")
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	for k in 12:
		clips.force = {"clip": "flurry", "t": 0.2}
		sync.call("_process", 1.0 / 30.0)
	for i in 8:
		var c := VoidCard.make()
		holder.add_child(c)
		c.position = Vector3(-0.5 - i * 0.42, 1.0 + 0.04 * i, 0.9 + 0.05 * i * (i % 3 - 1))
		c.rotation.y = 1.2
	cam.fov = 30.0
	cam.position = Vector3(-0.9, 1.5, 5.0)
	cam.look_at(Vector3(-0.9, 0.9, 0))
	await _grab(out.path_join("view.png"))
	await RenderingServer.frame_post_draw
	await _grab(out.path_join("view.png"))
	cam.fov = 8.0
	cam.position = Vector3(-0.9, 21.0, 9.4)
	cam.look_at(Vector3(-0.9, 0.8, 0))
	await RenderingServer.frame_post_draw
	await _grab(out.path_join("match.png"))
	print("MOTLEY_CARD_SHOTS_DONE")
	tree.quit()
