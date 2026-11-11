extends RefCounted
## --hud-vitals-shots --shots-dir=<dir>: the bottom HUD (armour over health, one G slot) and a squadmate's
## row, a rival's plate and your own plate, on the real HUD (GPU, under xvfb with a renderer).

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 3, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true,
		"god": true, "length": 1e9})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		h.max_armor = maxf(h.max_armor, 50.0)
		h.armor = 35.0
		h.hp = h.max_hp * 0.7
	var foe: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	P.teleport(m.world.free_spot_near(foe.pos + Vector3(6, 0, 4), [], 1.0, 0.45, 4.0))
	for i in 30:
		m.step(Match.DT)
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(Match.DT, 1.0)
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("hud_vitals.png"))
	print("HUDVITALS-SHOT ok")
