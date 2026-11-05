extends RefCounted
## TEMP (not committed): farm shots for the Boki job step and the Boki speech size.
var main: Node
var home = null

func _snap(path: String) -> void:
	for i in 4:
		await main.get_tree().process_frame
	if main.fade:
		main.fade.reveal(0.05)
	await main.get_tree().create_timer(0.8).timeout
	main.get_viewport().get_texture().get_image().save_png(path)

func run(m: Node, out_dir: String) -> void:
	main = m
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	await main.get_tree().create_timer(0.8).timeout
	var tag := OS.get_cmdline_user_args().has("--after")
	var ke: Dictionary = home._kin_entry(Save.active_kin())
	home.cam.zoom_to = 1.0
	home.cam.zoom = 1.0
	var bp: Vector3 = (ke["node"] as Node3D).position
	home.ppos = bp + Vector3(0, 0, 2.5)
	home.player.position = home.ppos
	home.cam.snap(bp + Vector3(0, 0, 1.0))
	home._say(ke, "Hello! Is it snack time yet?", 30.0)
	await _snap("%s/speech_%s.png" % [out_dir, "after" if tag else "before"])
	if tag:
		for id in ["axe", "chop", "house", "hammer"]:
			FarmTutorial.mark(id)
		home.guide.place_house()
		FarmSites.finish(FarmHob.house_entry())
		home.guide.refresh()
		await _snap(out_dir + "/job_go.png")
		home._open_kin(Save.active_kin())
		await _snap(out_dir + "/job_page.png")
	main.get_tree().quit()
