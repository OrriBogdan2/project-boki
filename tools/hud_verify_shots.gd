extends RefCounted
## --hud-verify-shots --shots-dir=<dir>: the match HUD in a fixed state (level 7, half XP, armour partly spent, a
## shield, full health): look_<W>x<H>.png is the game as it plays; hud_<W>x<H>.png is the HUD over a flat grey (3D
## off) and hud_<W>x<H>_bare.png the same without the HUD (GPU, run once per --size=WxH). tools/hud_measure.py diffs
## the flat pair and measures each element against scripts/ui/HUD_SPEC.md.
const FLAT := Color(0.47, 0.47, 0.47)

func run(main: Node) -> void:
	var dir := "shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			main.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	Settings.set_v("tips", false, false)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 3, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true, "god": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
	var P: Hunter = m.player
	P.lvl = 7
	P.xp = lerpf(float(Hunter.XP_TO[6]), float(Hunter.XP_TO[7]), 0.5)
	P.skill_pts = 0
	for s in P.slot_lv:
		P.slot_lv[s] = 1
	P.hp = P.max_hp
	P.armor = P.max_armor * 0.6
	P.shield = 30.0
	for i in 240:
		m.step(Match.DT)
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(Match.DT, 1.0)
		await main.get_tree().process_frame
	var sz := main.get_viewport().get_visible_rect().size * main.get_window().content_scale_factor
	var stem := "hud_%dx%d" % [int(sz.x), int(sz.y)]
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("look_" + stem.substr(4) + ".png"))
	main.get_viewport().disable_3d = true
	RenderingServer.set_default_clear_color(FLAT)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(stem + ".png"))
	m.hud.visible = false
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(stem + "_bare.png"))
	print("HUDVERIFY-SHOT ", stem)
	main.get_tree().quit()
