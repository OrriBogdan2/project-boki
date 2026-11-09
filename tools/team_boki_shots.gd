extends RefCounted
## --team-boki-shots --shots-dir=<dir> [--size=WxH]: the squad rows with their Boki icons in the hudref demo
## (needs a renderer): one full frame with every Boki healthy, one with a hurt, a downed and a resting Boki.

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
	m.start(HudRefDemo.opts("--hudref-demo=plates").merged({"tier": 0, "length": 1e9, "seed": 5, "arch": "thief"}))
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
	mates[0].kin.dead = true
	await _frames(30)
	_shot(dir, "team_boki_down")
	print("TEAMBOKISHOTS in ", dir)
	main.get_tree().quit(0)

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func _shot(dir: String, file: String) -> void:
	var sz := main.get_viewport().get_visible_rect().size
	var img := main.get_viewport().get_texture().get_image()
	var crop := Rect2i(0, 0, int(img.get_width() * 0.3), int(img.get_height() * 0.55))
	img.get_region(crop).save_png(dir.path_join(file + ".png"))
	print("TEAMBOKISHOT %s window %s" % [file, str(sz)])
