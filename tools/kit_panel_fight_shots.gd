extends RefCounted
## --kit-panel-fight-shots --shots-dir=<dir>: the "Your kit" panel through a first fight (1280x720 on a GPU,
## jobq --needs gpu): fresh match (panel up), a hit lands on you (fight budget on, panel faded), the fight ends
## (panel back). Files are <dir>/kit_NN_<what>.png. Uses only hurt_at, so it runs on any build.

var main: Node
var dir := "shots"
var n := 0


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start(
		{
			"teams": 1,
			"squad": 1,
			"tier": 0,
			"length": 1e9,
			"seed": 4242,
			"no_drop": true,
			"arch": "thief",
			"cls": Arch.weight("thief"),
			"weapon": Arch.signature("thief")
		}
	)
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	await _run_for(m, 3.0)
	await _shot("start")
	m.player.hurt_at = m.time
	await _run_for(m, 1.5)
	await _shot("fight")
	await _run_for(m, 6.0)
	await _shot("after_fight")
	print("KITSHOTS %d in %s" % [n, dir])
	main.get_tree().quit(0)


func _run_for(m: Match, secs: float) -> void:
	for _i in int(secs / Match.DT):
		m.step(Match.DT)
		await main.get_tree().process_frame  # one frame per step: the HUD fade runs on frame time


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	n += 1
	img.save_png(dir.path_join("kit_%02d_%s.png" % [n, what]))
