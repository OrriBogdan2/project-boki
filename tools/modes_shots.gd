extends RefCounted
## --modes-shots --shots-dir=<dir>: the play space each match starts with, seen top-down on the full map, for
## trios and solos on every expedition map (start_<map>_<mode>.png; GPU, under xvfb with a renderer).
## docs/decisions/0084-modes-solos-play-space.md.

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
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for id in preload("res://tools/modes_check.gd").MAPS:
		for mode in Data.MODES:
			await _shot(id, mode)
	main.get_tree().quit(0)


func _shot(id: String, mode: String) -> void:
	var m := Match.new()
	main.add_child(m)
	var o := {
		"map": id, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true, "heart": true, "god": true, "length": 1e9
	}
	o.merge(Data.mode_opts(mode))
	await m.start(o)
	m.set_process(false)
	m.time = 1.0
	m.hud.full_map.open()
	for i in 20:
		m.step(Match.DT)
		m.cam.snap(m.player.pos)
		await main.get_tree().process_frame
	var file := "start_%s_%s.png" % [id, mode]
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
	print("MODES-SHOT %s  play space %.0f m" % [file, m.heart.start_r])
	m.queue_free()
	for i in 3:
		await main.get_tree().process_frame
