extends RefCounted
## --solo-hud-shots --shots-dir=<dir>: the HUD in play and the full map, trios beside solos, at 1280x720 (GPU,
## under xvfb with a renderer). In trios the left shows the squad; in solos nothing is there and no squad
## piece (base badge, ping hint, squad panel) shows. The matching rows are in --hudref-check (section 9).

const WIN := Vector2i(1280, 720)

var main: Node
var dir := ""


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	main.get_tree().root.size = WIN
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mode in Data.MODES:
		await _shots(mode)
	main.get_tree().quit(0)


func _shots(mode: String) -> void:
	var m := Match.new()
	main.add_child(m)
	var o := {"map": "hollowcrown", "tier": 0, "seed": 77, "no_drop": true, "god": true, "length": 1e9}
	o.merge(Data.mode_opts(mode))
	await m.start(o)
	m.set_process(false)
	m.time = 1.0
	for i in 30:
		m.step(Match.DT)
		m.cam.snap(m.player.pos)
		await main.get_tree().process_frame
	_save("play_%s.jpg" % mode)
	m.hud.full_map.open()
	for i in 10:
		await main.get_tree().process_frame
	_save("map_%s.jpg" % mode)
	var mates := m.hunters.filter(func(x): return x.team == m.player.team).size()
	print("SOLO-HUD-SHOT %s: %d hunters on your squad" % [mode, mates])
	m.queue_free()
	for i in 3:
		await main.get_tree().process_frame


func _save(file: String) -> void:
	main.get_viewport().get_texture().get_image().save_jpg(dir.path_join(file), 0.88)
