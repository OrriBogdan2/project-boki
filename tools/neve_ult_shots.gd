extends "res://tools/archetype_check.gd"
## --neve-ult-shots --shots-dir=<dir> [--shot-tag=before|after]: Neve (rimewright) casts Rimelock beside a
## rival dummy, at 1280x720 with the match HUD up (run under a renderer, jobq --needs gpu). Saves
## neve_ult_<tag>_<n>.png at 0.5, 1.5 and 3 s into the ult, to see what is drawn over her and the rival.

const AT := [0.5, 1.5, 3.0]  # s after the cast for each shot
const HUD_WAIT := 600  # process frames at most for the match HUD to finish building


func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	var tag := "shot"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--shot-tag="):
			tag = String(a).substr(11)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	main.get_window().size = Vector2i(1280, 720)
	var s := setup("rimewright", 3.0)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var m: Match = s[0]
	var hero: Hunter = s[1]
	for i in HUD_WAIT:
		if m.hud != null and m.hud.is_inside_tree() and m.hud.process_mode != Node.PROCESS_MODE_DISABLED:
			break
		await main.get_tree().process_frame
	hero.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(hero)
	var t := 0.0
	for i in AT.size():
		while t < float(AT[i]):
			step(m, 1.0 / 60.0)
			t += 1.0 / 60.0
			await main.get_tree().process_frame
		for f in 3:
			await main.get_tree().process_frame
		var img := main.get_viewport().get_texture().get_image()
		if img == null:
			print("NEVESHOT no image (headless? run under a renderer)")
			break
		img.save_png(dir.path_join("neve_ult_%s_%d.png" % [tag, i + 1]))
	print("NEVESHOT done ", tag)
	await done(m)
	main.get_tree().quit(0)
