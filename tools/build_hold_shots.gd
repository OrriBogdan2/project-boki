extends RefCounted
## --build-hold-shots=<dir>: screenshots for items 90 and 91 (run with a real renderer, e.g. xvfb-run with
## --rendering-driver opengl3): holding to build with a Boki helping, the "needs materials" pause, chopping,
## mining, and the tool in hand with the weapon put away. Never touches the real save.

var main: Node
var dir := ""
var home = null

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--build-hold-shots="):
			dir = String(a).substr(19)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.set_v("cam_style", "low", false)      # a lower camera, so the tool reads
	await _new_home(2)
	await _gathering("tree", "03_chopping", "Chopping: axe raised in both hands, weapon away, facing the tree")
	await _gathering("rock", "04_mining", "Mining: pickaxe raised over a boulder, weapon away")
	await _building()
	await _paused()
	print("BUILDHOLDSHOT DONE")
	main.get_tree().quit()

func _shot(shot_name: String, caption: String) -> void:
	if main.fade:
		main.fade.reveal(0.05)
		await main.get_tree().create_timer(0.4).timeout
	for i in 900:
		if not UI.toast_busy(home.root_ui):
			break
		await main.get_tree().process_frame
	if home.hover_box:
		home.hover_box.visible = false
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	print("BUILDHOLDSHOT %s|%s" % [shot_name, caption])

func _new_home(kin_count: int) -> void:
	var d := Save.fresh()
	for i in kin_count:
		var k := Save.new_kin(["zapple", "cindle"][i], ["Pip", "Ash"][i])
		k["level"] = 5
		Care.ensure(k)
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	d["stats"] = {"extracts": 0, "bosses": 0, "caught": 0, "harvested": 0, "hatched": 0, "fb_built": 0}
	Save.d = d
	HomeLayout.ensure(d)
	if home:
		home.queue_free()
		await main.get_tree().process_frame
	home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null and home.hob != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	await main.get_tree().create_timer(0.8).timeout
	home.talk_cd = 1.0e9      # no Boki chatter over the pictures
	HomeGather.give_tool("axe")
	HomeGather.give_tool("pickaxe")

func _look(target: Vector3, zoom: float) -> void:
	home.cam.zoom_to = zoom
	home.cam.zoom = zoom
	home.cam.snap(target)

## Waits until the swing in progress is at `phase` of its way.
func _until_phase(tool: String, phase: float) -> void:
	for i in 600:
		await main.get_tree().process_frame
		if home.tw.tool == tool and home.tw.swing_t / HunterTool.period(tool) >= phase:
			return

func _building() -> void:
	home.guide.skip()
	var e := FarmHob.house_entry()
	var hc: Vector3 = HomeLayout.deco_center(e)
	var cost := FarmSites.build_cost("house")
	Work.add_mat("wood", int(cost["wood"]))
	Work.add_mat("stone", int(cost["stone"]))
	var stand := _site_spot(hc)
	home.ppos = stand
	home.player.position = stand
	var i := 0
	for k in home.kins:
		k["pos"] = hc + Vector3(-1.5 + i * 2.5, 0, 3.4)
		(k["node"] as Node3D).position = k["pos"]
		k["goal"] = k["pos"]
		k["t"] = 999.0
		i += 1
	home.hw.scan_t = 0.0
	home.hw.scan()
	_hide_stall()
	_look(hc + Vector3(0, 0, 1.6), 0.5)
	home.hob.use(home.hob.find(Vector2(home.ppos.x, home.ppos.z)))
	home.tw.test_hold = true
	await main.get_tree().create_timer(3.0).timeout
	await _until_phase("hammer", 0.62)
	await _shot("01_hold_to_build", "Holding to build: hammer in hand, weapon away, Boki helping, the bar filling")
	Settings.set_v("cam_style", "supervive", false)
	_look(hc + Vector3(0, 0, 1.0), 0.6)
	await _until_phase("hammer", 0.62)
	await _shot("05_default_camera", "The same hold at the default farm camera")
	Settings.set_v("cam_style", "low", false)
	home.tw.test_hold = false

## A spot beside the site where interact finds the site (not Hob).
func _site_spot(hc: Vector3) -> Vector3:
	var offsets := [Vector3(3.4, 0, 1.4), Vector3(-3.4, 0, 1.4), Vector3(0, 0, -3.4), Vector3(0, 0, 3.8)]
	for off in offsets:
		var p: Vector3 = hc + off
		if String(home.hob.find(Vector2(p.x, p.z)).get("kind", "")) == "site":
			return p
	return hc + Vector3(3.6, 0, 1.0)

## The market stall stands in front of the house on this island; hide it so the Boki show.
func _hide_stall() -> void:
	for n in home.find_children("*", "Node3D", true, false):
		if String(n.name).to_lower().contains("stall") or String(n.name).to_lower().contains("market"):
			(n as Node3D).visible = false

func _paused() -> void:
	var e := FarmHob.house_entry()
	var hc: Vector3 = HomeLayout.deco_center(e)
	Save.d["mats"] = {}
	home._refresh_top()
	e["site"]["got"] = 3
	e["site"]["steps"] = 1
	await main.get_tree().create_timer(1.5).timeout
	FarmModels.tick_bars(home.hw)
	home.ppos = _site_spot(hc)
	home.player.position = home.ppos
	_look(hc + Vector3(0, 0, 1.0), 0.6)
	await main.get_tree().create_timer(0.8).timeout
	await _shot("02_needs_materials", "The build paused at the quarter: the site and the prompt say what is needed")

func _gathering(what: String, shot_name: String, caption: String) -> void:
	var hg: HomeGather = home.hg
	var tile := -1
	var stand := Vector3.INF
	var fewest := 999
	var w: World = home.world
	for i in home.hb.wild_t:
		if home.hb.wild_t[i] != what:
			continue
		var b := Vector3(i % w.w - 0.45, 0, i / w.w + 0.5)      # west of it, so the camera sees you side on
		var open: bool = w.inb(i % w.w - 1, i / w.w) and w.kind[w.idx(i % w.w - 1, i / w.w)] == World.T_GROUND
		if not open or int(hg.find(Vector2(b.x, b.z)).get("i", -1)) != i:
			continue
		var crowd := 0
		for j in home.hb.wild_t:
			if Vector2(j % w.w - i % w.w, j / w.w - i / w.w).length() < 2.6:
				crowd += 1
		if crowd < fewest:
			fewest = crowd
			tile = i
			stand = b
	home.ppos = stand
	home.player.position = stand
	for k in home.kins:
		k["pos"] = stand + Vector3(5.0, 0, 5.0)
		(k["node"] as Node3D).position = k["pos"]
	_look((stand + _tile_at(tile)) * 0.5, 0.38)
	hg.demo_loop = true
	home.tw.test_hold = true
	hg.use(hg.find(Vector2(stand.x, stand.z)))
	for i in 900:      # a hit or two first, so the target shows it
		await main.get_tree().process_frame
		if int(hg.damage.get(tile, 0)) >= 1 and home.tw.swing_t < 0.1:
			break
	await _until_phase(HomeGather.tool_for(what), 0.62 if what == "tree" else 0.4)
	await _shot(shot_name, caption)
	hg.cancel()
	home.tw.test_hold = false

func _tile_at(tile: int) -> Vector3:
	var w: World = home.world
	return Vector3(tile % w.w + 0.5, 0, tile / w.w + 0.5)
