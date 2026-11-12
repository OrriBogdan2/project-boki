extends RefCounted
## --muzzle-shots --shots-dir=<dir> [--only=<archetype>] [--bench-view=1920x1080] (GPU: jobq --needs gpu): each Hunter
## firing LMB, RMB, E, R and X at the match camera (the default view, Hunters drawn 2.1x), as numbered jpg frames
## cropped round the Hunter (<dir>/<archetype>_NNN.jpg, 20 fps, a label with the key pressed). Encode with ffmpeg.
## Never writes the save.

const LiveCheck := preload("res://tools/muzzle_live_check.gd")
const DT := 1.0 / 60.0
const EVERY := 3                 # sim frames per saved frame
const CROP := Vector2i(640, 440) # px round the Hunter
const ZOOM := 0.7                # the wheel's closest: the Hunter fills more of the crop
const SETTLE := 60               # frames before the first press
const GAP := 55                  # frames after each press
const SLOTS := ["lmb", "lmb", "rmb", "e", "r", "x"]

var main: Node
var m: Match
var label: Label
var dir := ""
var n := 0

func run(main_node: Node) -> void:
	main = main_node
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--only="):
			only = String(a).substr(7)
		if String(a).begins_with("--bench-view="):
			var wh := String(a).substr(13).split("x")
			main.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	Settings.v["cam_follow"] = "locked"
	Settings.v["tips"] = false
	var layer := CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)
	label = Label.new()
	label.position = Vector2(20, 14)
	label.add_theme_font_size_override("font_size", 30)
	layer.add_child(label)
	for arch in LiveCheck.ARCHS:
		if only == "" or only == arch:
			await _hunter(arch)
	print("MUZZLE_SHOTS_DONE")
	main.get_tree().quit()

func _frame(P: Hunter, save: bool) -> void:
	m.step(DT)
	m._process(DT)
	if save and n % EVERY == 0:
		var view: Vector2 = main.get_viewport().get_visible_rect().size
		var at: Vector2 = m.cam.unproject_position(P.position + Vector3(0, 1.6, 0))
		var k: Vector2 = Vector2(main.get_window().size) / view
		label.position = at - Vector2(CROP) / k * 0.5 + Vector2(10, 8) / k
	await main.get_tree().process_frame
	if save and n % EVERY == 0:
		await RenderingServer.frame_post_draw
		var img := main.get_viewport().get_texture().get_image()
		var px: Vector2 = Vector2(img.get_size()) / main.get_viewport().get_visible_rect().size
		var at := Vector2i(m.cam.unproject_position(P.position + Vector3(0, 1.6, 0)) * px)
		var rect := Rect2i(at - CROP / 2, CROP).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(rect).save_jpg(dir.path_join("%s_%03d.jpg" % [P.arch, n / EVERY]), 0.85)
	n += 1

func _hunter(arch: String) -> void:
	var o := Match.demo_opts()
	o.merge({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch), "god": true}, true)
	o.erase("demo_match")
	o.erase("fresh_t")
	Game.goto("match", o)
	m = null
	while m == null:
		await main.get_tree().process_frame
		var cur = main.current
		if cur is Match and (cur as Match).is_processing() and (cur as Match).hud != null:
			m = cur
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	P.unlock_all()
	P.lvl = 6
	P.slot_lv["ult"] = 1
	P.dashes = P.max_dashes()
	P.ult = 0.0
	m.hud.guide_hidden = true
	m.cam.user_zoom = ZOOM
	P.inp["aim"] = P.pos + Vector3(11, 0.9, 0)
	P.inp["aim_y"] = P.pos.y
	n = 0
	label.text = "%s" % arch
	for f in SETTLE:
		await _frame(P, true)
	for slot in SLOTS:
		label.text = "%s  %s" % [arch, slot.to_upper()]
		P.fire_cd = 0.0
		P.ammo = int(P.wpn.get("mag", 12))
		for k in P.ak.cd:
			P.ak.cd[k] = 0.0
		match slot:
			"lmb": P.inp["fire"] = true
			"rmb": P.inp["sec"] = true
			"e": P.ak.use_e()
			"r": P.ak.use_r()
			"x": HunterKeys.ult_pressed(P)
		P.inp["sec_hold"] = slot == "rmb"
		for f in GAP:
			if f == 2:
				P.inp["fire"] = false
				P.inp["sec"] = false
			if f == 40:
				P.inp["sec_hold"] = false
			await _frame(P, true)
