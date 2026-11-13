extends RefCounted
## --hud-groups-shots --shots-dir=<dir> [--size=WxH]: one picture per moment of --hud-groups-check (landing, fight,
## heart, race) on the real HUD, with the group list printed beside each. Needs a renderer (jobq submit --needs gpu).

const CHECK := preload("res://tools/hud_groups_check.gd")

func run(main: Node) -> void:
	var dir := "/tmp/hud_groups"
	var win := Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--size="):
			var p := String(a).substr(7).split("x")
			win = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_tree().root.size = win
	var m: Match = await CHECK.make_match(main)
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for id in CHECK.MOMENTS:
		CHECK.set_moment(m, id)
		for i in 20:
			m.step(Match.DT)
			m.cam.snap(m.player.pos)
			await main.get_tree().process_frame
		CHECK.set_moment(m, id)      # the settling steps ran the toasts down
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%dx%d.png" % [id, win.x, win.y]))
		print("HUDGROUPS-SHOT %s: %s" % [id, ", ".join(HudGroups.on_screen(m.hud))])
	main.get_tree().quit(0)
