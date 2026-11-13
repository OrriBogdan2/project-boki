extends RefCounted
## --void-ui-shots=<dir>: one screenshot of every menu screen restyled in the "Void & Masks" pass
## (UI_STYLE.md on ext/agent-briefs), for the before/after grid in the PR: the title, save slots,
## settings, the pause menu, the creator, the hatch intro card, the egg pick, a new Boki's reveal card, the
## welcome box, the farm (Goals tracker and hub bar), the Job Board, the Kin Burrow, a Boki's page
## (its care card), the Market, the Black Market, the build menu, the pause menu, the inventory, the
## pre-match lobby, the match HUD and the results screen. Run with a real renderer
## (xvfb-run, --rendering-driver opengl3, --resolution WxH). Never touches the real save. Writes
## <name>.png and prints "VSHOT <name>".

var main: Node
var dir := ""

func _shot(shot_name: String, settle := 0.5) -> void:
	await main.get_tree().create_timer(settle).timeout
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	print("VSHOT %s" % shot_name)

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--void-ui-shots="):
			dir = String(a).substr(16)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	_fill_save()
	await _front_screens()
	await _farm_screens()
	await _match_screens()
	print("VSHOT DONE")
	main.get_tree().quit()

func _front_screens() -> void:
	main.show_screen("title", {})
	await _shot("01_title", 2.0)
	Overlay.ctx = "title"
	Overlay.open_saves()
	await _shot("02_save_slots")
	Overlay.close()
	Overlay.open_settings()
	await _shot("03_settings")
	Overlay.close()
	Save.d["tutorial"] = {}
	main.show_screen("hatch", {"create": true})
	await _shot("05_creator", 2.5)
	main.current.create_box.visible = false     # the real intro card comes before the creator
	main.current.call("_show_card")
	await _shot("04_hatch_card")
	main.current.call("_show_pick")
	await _shot("04b_egg_pick")
	main.current.create_box.visible = true
	main.current.call("_looks_good")
	await _shot("06_welcome_modal", 7.0)
	Save.d["tutorial"] = {"hatched": true, "intro": true}
	main.current.queue_free()
	var holder := Node3D.new()
	main.add_child(holder)
	holder.add_child(KinReveal.new("cindle", Save.new_kin("cindle", "", 4242)))
	await _shot("04c_boki_reveal", 6.0)
	holder.queue_free()

func _farm_screens() -> void:
	var home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	await _shot("07_farm_goals", 3.0)
	home.open_job_board()
	await _shot("08_job_board")
	home._close_panel()
	home.open_kin_box()
	await _shot("09_kin_burrow")
	home._close_panel()
	home._open_kin(Save.d["roster"][0])
	await _shot("10_boki_page")
	home._close_panel()
	home.hmk.open()
	await _shot("11_market")
	home._close_panel()
	home.hbm.open("rare")
	await _shot("12_black_market")
	home._close_panel()
	home.open_build()
	await _shot("13_build_menu")
	home.open_build()
	Overlay.open_pause("home")
	await _shot("14_pause")
	Overlay.close()
	Overlay.open_inventory()
	await _shot("15_inventory")
	Overlay.close()

## The screens around an expedition: the pre-match lobby, the match HUD and the results.
func _match_screens() -> void:
	main.show_screen("prematch", {"teams": 10, "squad": 2, "tier": 0})
	await _shot("16_prematch", 2.0)
	main.show_screen("match", {"no_drop": true, "teams": 3, "squad": 3, "seed": 4242})
	for i in 3000:
		var cur = main.current
		if cur is Match and cur.player != null and cur.time > 3.0:
			break
		await main.get_tree().process_frame
	await _shot("17_hud", 0.5)
	main.show_screen("results", {"extracted": true, "gems": 42, "seeds": {"sunroot": 1},
		"caught": [Save.new_kin("zapple")], "knocks": 3, "damage": 512, "taken": 388, "kills": 1, "downs": 1,
		"deaths": 0, "revives": 2, "armor_tier": 3, "time": 201.0, "kin_trust": 57.0, "tonics": 1,
		"kin_events": [{"kind": "refused", "trust": -1.0,
			"text": "refused to jump into a fight that looked too dangerous"}]})
	await _shot("18_results", 3.0)

## A played farm: the starter partner and four grown Boki, gems and a few goods.
func _fill_save() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	k["level"] = 7
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["gems"] = 860
	d["name"] = "Orri"
	Save.d = d
	for pair in [["cindle", "Ash"], ["burrlet", "Bun"], ["puddlet", "Drip"], ["pebbit", "Rocky"]]:
		var r := Save.new_kin(String(pair[0]), String(pair[1]))
		r["level"] = 5
		Care.ensure(r)
		Save.register(r)
		Save.d["roster"].append(r)
	for g in ["colossus_horn", "heartwood", "dye_gold"]:
		Goods.give("good:" + g)
