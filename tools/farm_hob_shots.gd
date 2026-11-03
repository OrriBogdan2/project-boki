extends RefCounted
## --farm-hob-shots=<dir>: screenshots of Hob and the farm tutorial (run with a real renderer, e.g.
## xvfb-run with --rendering-driver opengl3): a tutorial prompt, the starter build menu, Hob with
## his talk prompt, the "new blueprints" toast and the Goals card. Never touches the real save.

var main: Node
var dir := ""
var home = null

func _shot(shot_name: String, caption: String, keep_prompt := false) -> void:
	for i in 3:
		await main.get_tree().process_frame
	if main.fade:
		main.fade.reveal(0.05)
	await main.get_tree().create_timer(0.3).timeout
	if not keep_prompt:
		home.set_process(false)
		home.prompt_box.visible = false
	if home.hover_box:
		home.hover_box.visible = false
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	home.set_process(true)
	print("HOBSHOT %s|%s" % [shot_name, caption])

func _new_home(stats: Dictionary, kin_count := 1):
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	Save.d["gems"] = 200
	Save.d["stats"] = stats
	Save.d["extracts"] = int(stats.get("extracts", 0))
	if home:
		home.queue_free()
		await main.get_tree().process_frame
	home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	await main.get_tree().create_timer(0.8).timeout
	return home

func _look(target: Vector3, offset: Vector3, zoom: float) -> void:
	var p := target + offset
	home.ppos = p
	home.player.position = p
	home.cam.zoom_to = zoom
	home.cam.zoom = zoom
	home.cam.snap(target)

func run(m: Node, out_dir: String) -> void:
	main = m
	dir = out_dir
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	# 1. the first tutorial prompt, before the house
	await _new_home({"extracts": 0, "bosses": 0, "caught": 0, "harvested": 0, "hatched": 1, "fb_built": 0})
	var spot: Vector3 = home.guide.house_spot()
	_look(spot, Vector3(0, 0, 8), 1.0)
	await main.get_tree().create_timer(1.0).timeout
	await _shot("01_tutorial_prompt", "Tutorial step 1: house marker, hint with the real key and Skip, Goals", true)
	# 2. the starter build menu
	home.hb.toggle()
	await _shot("02_starter_build_menu", "B opens on Buildings: starter set only, empty tabs hidden, footer line")
	home.hb.toggle()
	# 3. Hob by the house with his talk prompt
	home.guide.place_house()
	home._sync_fixtures()
	var hc: Vector3 = HomeLayout.deco_center(FarmHob.house_entry())
	_look(home.hob.pos, Vector3(1.6, 0, 1.6), 0.9)
	await main.get_tree().create_timer(0.8).timeout
	await _shot("03_hob_talk_prompt", "Hob Brackenridge by the house site; walking up shows 'Talk to Hob'", true)
	_look(hc, Vector3(3.5, 0, 3.4), 0.9)
	await main.get_tree().create_timer(0.8).timeout
	await _shot("04_house_site_prompt", "The house going up: swing a hammer prompt and the waiting hint", true)
	# 4. the new blueprints toast
	Save.d["stats"]["harvested"] = 30
	home.hob.poll_t = 0.0
	home.guide.detect_t = 0.0
	_look(home.hob.pos, Vector3(2.5, 0, 3.5), 1.0)
	await main.get_tree().create_timer(0.7).timeout
	await _shot("05_new_blueprints_toast", "Farm level 2: the toast points at Hob, a gold mark floats over him", true)
	# 5. his panel
	home.hob.talk()
	await _shot("06_hob_panel", "Talking to Hob: his line and the blueprints he drew up")
	home._close_panel()
	# 6. the Goals card with some progress
	ClassUnlock.choose_starters(ClassUnlock.starters().slice(0, ClassUnlock.picks_needed()))
	Save.d["stats"]["caught"] = 1
	var cs := ClassUnlock.state()
	cs["stats"]["stuns"] = 2
	cs["stats"]["slams"] = 1
	FarmTutorial.skip()
	home.guide.refresh()
	_look(hc, Vector3(4, 0, 5), 1.0)
	await main.get_tree().create_timer(0.6).timeout
	await _shot("07_goals_tracker", "The Goals card: Hunter challenges, mastery, a farm milestone, the next farm level")
	print("HOBSHOT DONE")
	main.get_tree().quit()
