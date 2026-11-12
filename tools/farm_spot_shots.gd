extends RefCounted
## --farm-spot-shots=<dir>: screenshots of the farm tutorial's "Give your Boki a job" step (run with a real renderer and
## a --resolution): the step arriving (the spotlight beat), the settled screen, the Boki page before a job is set, and
## the page after one is. Only touches classes that exist before the spotlight too, so the same file can shoot the
## "before" on an older checkout. Never touches the real save.

var main: Node
var dir := ""
var home = null

func _shot(shot_name: String) -> void:
	for i in 3:
		await main.get_tree().process_frame
	if home.hover_box:
		home.hover_box.visible = false
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	print("SPOTSHOT %s %s" % [shot_name, main.get_viewport().get_visible_rect().size])

func run(m: Node, out_dir: String) -> void:
	main = m
	dir = out_dir
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	k["level"] = 5
	Care.ensure(k)
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	var lay := HomeLayout.ensure(d)
	d["stats"] = {"extracts": 0, "bosses": 0, "caught": 0, "harvested": 0, "hatched": 0, "fb_built": 0}
	var house := {"u": HomeLayout._next_uid(lay), "id": "house", "x": 36, "z": 24, "r": 0}
	(lay["deco"] as Array).append(house)
	FarmTutorial.mark("hob")
	FarmTutorial.detect()
	home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.panel_host != null and home.player != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	var hc: Vector3 = HomeLayout.deco_center(house)
	home.ppos = hc + Vector3(0, 0, 3.5)
	home.player.position = home.ppos
	home.cam.zoom_to = 1.0
	home.cam.zoom = 1.0
	home.cam.snap(hc + Vector3(0, 0, 2.0))
	if main.fade:
		main.fade.reveal(0.05)
	await main.get_tree().create_timer(1.5).timeout
	home.guide.tick(0.6)
	await main.get_tree().create_timer(0.35).timeout
	await _shot("1_task_step_arrives")
	await main.get_tree().create_timer(2.0).timeout
	await _shot("2_task_step_settled")
	home._open_kin(Save.active_kin())
	await main.get_tree().create_timer(0.5).timeout
	await _shot("3_boki_page_unset")
	var rec: Dictionary = Save.active_kin()
	var jobs := Work.list(rec)
	Work.set_pin(rec, String(jobs[jobs.size() - 1][0]))
	FarmTutorial.event("task")
	home._open_kin(rec)
	await main.get_tree().create_timer(0.5).timeout
	await _shot("4_boki_page_job_set")
	print("SPOTSHOT DONE")
	main.get_tree().quit()
