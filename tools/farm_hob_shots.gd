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
	HomeGather.give_tool("axe")
	Work.add_mat("wood", 3)
	FarmTutorial.detect()
	home.guide.refresh()
	var spot: Vector3 = home.guide.house_spot()
	_look(spot, Vector3(0, 0, 4.5), 1.0)
	home.cam.snap(spot + Vector3(0, 0, 2.0))
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
	await main.get_tree().create_timer(3.5).timeout
	await _shot("06_hob_panel",
		"Talking to Hob: the dialogue box (his portrait, name plate, typed line), the camera on him")
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
	await _round2()
	print("HOBSHOT DONE")
	main.get_tree().quit()

# ---------------------------------------------------------------- round 2
func _free_cells(sz: Vector2i, around: Vector3, min_r := 3) -> Array:
	for rad in range(min_r, 26):
		for k in 48:
			var a := float(k) / 48.0 * TAU
			var x := int(round(around.x + cos(a) * rad - sz.x * 0.5)); var z := int(round(around.z + sin(a) * rad - sz.y * 0.5))
			var cs := HomeLayout.cells_of([x, z, x + sz.x - 1, z + sz.y - 1])
			if home.hb.fits(home.hb.held, cs): return cs
	return []

func _paint(brush: String, cells: Array) -> void:
	home.hb.take(brush)
	home.hb.cells = cells
	home.hb._check_cells()
	home.hb.place_held()

func _round2() -> void:
	var base := {"extracts": 0, "bosses": 0, "caught": 0, "harvested": 0, "hatched": 1, "fb_built": 0}
	# 8. the Challenge House in the build menu after the first expedition, with Hob's blueprint
	await _new_home(base.duplicate())
	FarmTutorial.skip()
	Save.d["matches"] = 1
	Save.d["stats"]["extracts"] = 1
	Save.d["extracts"] = 1
	FarmBuilder.draw_up()
	Work.add_mat("wood", 8); Work.add_mat("stone", 5)
	home.guide.refresh()
	home.hb.toggle()
	home.hb.cat = "Buildings"
	home.hb._build_bar()
	_look(HomeLayout.LANDING, Vector3(0, 0, 5), 1.0)
	await main.get_tree().create_timer(0.6).timeout
	await _shot("08_challenge_house_in_menu", "After the first expedition Hob draws up the Challenge House: it is in Buildings for 6 wood and 4 stone")
	home.hb.toggle()
	# 9. the near-water preview; 10. a river channel
	await _new_home(base.duplicate())
	FarmTutorial.skip()
	Save.d["gems"] = 300
	Save.d["plot_cap"] = 8
	home.hb.toggle()
	home.hb.take("crop_patch")
	var blk := _free_cells(Vector2i(7, 10), HomeLayout.LANDING + Vector3(-8, 0, -4), 0)      # room for the channel, a gap and a patch
	print("HOBSHOT block at ", blk[0], " landing ", HomeLayout.LANDING)
	var line: Array = []
	for i in 7: line.append(Vector2i(blk[0].x + i, blk[0].y))
	_paint("river", line)
	home.hb.apply(true)
	home.hb._drop_held()
	home.hb._build_bar()
	await main.get_tree().create_timer(1.5).timeout
	_look(Vector3(line[3].x + 0.5, 0, line[3].y + 0.5), Vector3(0, 0, 4), 1.1)
	await main.get_tree().create_timer(0.4).timeout
	await _shot("10_river_channel", "A River brush drag: a cheap channel of water across the meadow (2 gems a tile)", true)
	var psz := HomeLayout.size_of("crop_patch", 0)
	home.hb.take("crop_patch")
	home.hb.debug_m = Vector2(blk[0].x + 1 + psz.x * 0.5, blk[0].y + 2 + psz.y * 0.5)      # one tile of grass between it and the water
	home.hb.tick(0.0)
	print("HOBSHOT patch ok=", home.hb.ghost_ok, " ", home.hb.why)
	_look(Vector3(line[3].x + 0.5, 0, line[3].y + 0.5), Vector3(0, 0, 3), 1.2)
	await main.get_tree().create_timer(0.5).timeout
	home.hb.tick(0.0)
	await _shot("09_near_water_preview", "Placing a crop patch within 2 tiles of the channel: 'Near water: waters itself' in green", true)
	home.hb.debug_m = Vector2.INF
	home.hb.toggle()
	# 11 / 12 / 13. the market steps
	await _new_home(base.duplicate())
	var L := HomeLayout.of(Save.d)
	var hsite := {"u": HomeLayout._next_uid(L), "id": "house", "x": 36, "z": 24, "r": 0}
	(L["deco"] as Array).append(hsite)
	var stall := {"u": HomeLayout._next_uid(L), "id": "market_stall", "x": 41, "z": 29, "r": 0}
	(L["deco"] as Array).append(stall)
	home._sync_fixtures()
	for id in ["axe", "chop", "house", "hammer", "task", "stone", "feed", "crop"]:
		FarmTutorial.mark(id)
	Save.d["gems"] = 0
	home.guide.detect_t = 0.0
	var sc := HomeLayout.deco_center(stall)
	_look(sc, Vector3(2.5, 0, 6.5), 1.0)
	await main.get_tree().create_timer(1.2).timeout
	await _shot("11_market_step", "Buy a seed: Hob slips you the gems, the stall is marked, the hint says Seeds tab", true)
	FarmTutorial.event("buy")
	Save.d["crops"]["tidebloom"] = 2
	home.guide.detect_t = 0.0
	await main.get_tree().create_timer(1.0).timeout
	await _shot("12_sell_step", "Sell a crop: the hint says Sell tab and where gems come from", true)
	home.hmk.vendor_tab = "Sell"
	home.hmk.open("Vendor")
	await _shot("13_sell_tab", "The Market opens on the Sell tab: sell one crop, gems come in", true)
	home._close_panel()
