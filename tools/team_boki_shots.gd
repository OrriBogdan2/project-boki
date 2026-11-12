extends RefCounted
## --team-boki-shots --shots-dir=<dir> [--size=WxH]: the squad rows with their Boki icons in the hudref demo
## (needs a renderer), 3 squads of 3: one frame with every Boki healthy, one with a hurt and a resting Boki, one with
## a teammate knocked (a wisp: bleed timer, violet Boki tint) beside a dead Boki, one after that wisp bled out
## (deathbox).

var main: Node

func run(main_node: Node) -> void:
	main = main_node
	var dir := "shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			main.get_tree().root.size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start(HudRefDemo.opts("--hudref-demo=plates").merged({"tier": 0, "length": 1800.0, "seed": 5, "arch": "thief"}))
	main.fade.reveal(0.05)     # the boot splash stays up when a tool starts a match by hand
	await _frames(90)
	_shot(dir, "team_boki_healthy")
	var mates: Array = m.hunters.filter(func(x): return x != m.player and x.team == m.player.team and x.kin != null)
	mates[0].downed = false
	mates[0].kin.hp = mates[0].kin.max_hp * 0.4
	mates[1].downed = false
	mates[1].kin.rest_t = 30.0
	mates[1].kin.hp = mates[1].kin.max_hp * 0.8
	await _frames(30)
	_shot(dir, "team_boki_hurt_resting")
	mates[1].kin.rest_t = 0.0
	mates[1].kin.dead = true
	var rival: Hunter = m.hunters.filter(func(x): return x.team != m.player.team)[0]
	m.knock(mates[0], rival, {})      # a teammate down (a wisp): the 3-squad HUD with one down
	await _frames(30)
	_shot(dir, "team_boki_down")
	mates[0].down_hp = 0.01           # bleeds out: eliminated, deathbox on the row
	await _frames(30)
	_shot(dir, "team_boki_deathbox")
	print("TEAMBOKISHOTS in ", dir)
	main.get_tree().quit(0)

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func _shot(dir: String, file: String) -> void:
	var sz := main.get_viewport().get_visible_rect().size
	var img := main.get_viewport().get_texture().get_image()
	var crop := Rect2i(0, 0, int(img.get_width() * 0.3), int(img.get_height() * 0.9))
	img.get_region(crop).save_png(dir.path_join(file + ".png"))
	print("TEAMBOKISHOT %s window %s" % [file, str(sz)])
