extends RefCounted
## --belt-hud-shots --shots-dir=<dir>: the six-slot belt at 1280x720 and 1920x1080 (needs a real renderer,
## so run it through jobq --needs gpu): tonic and armor kit pinned, a drink filling slot 1, a cooling
## slot, Twin Gate's gates open, two open slots. Files are <dir>/<W>x<H>_belt.png.

const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
var main: Node

func _frames(k: int) -> void:
	for i in k:
		await main.get_tree().process_frame

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Save.d["tutorial"]["hatched"] = true
	var dir := "/tmp/belt_hud_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 2, "length": 1e9, "seed": 4107, "no_drop": true})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	var P: Hunter = m.player
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, "tonic", 5)
	UtilityBelt.grant(P, "armor_kit", 3)
	UtilityBelt.grant(P, "twin_gate", 2)
	UtilityBelt.grant(P, "smoke", 1)
	P.hp = P.max_hp - 40.0
	UtilityBelt.use_id(P, "tonic")
	UtilityBelt.use_id(P, "twin_gate")
	P.belt[3]["cd"] = 3.0
	m.step(Match.DT * 20)
	await _frames(20)
	for sz in SIZES:
		main.get_window().size = sz
		await _frames(8)
		await RenderingServer.frame_post_draw
		var img := main.get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("%dx%d_belt.png" % [img.get_width(), img.get_height()]))
	print("BELTHUDSHOTS done in %s" % dir)
	main.get_tree().quit(0)
