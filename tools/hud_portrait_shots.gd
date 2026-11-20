extends "res://tools/vv_shots.gd"
## --hud-portrait-shots --shots-dir=<dir> --shots-tag=<before|after>: a live Arena match per hunter (xvfb
## with a renderer); hud_<archetype>_<neutral|excited|hurt>_<tag>.png is the full screen with the hero's HUD
## portrait showing that face (neutral; just after a kill; just after a hit).

const ARCHS := ["ostra", "mage", "rimewright", "dredge", "dolm", "bulwark", "thief"]


func run(main_node: Node) -> void:
	main = main_node
	var tag_name := "after"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--shots-tag="):
			tag_name = String(a).substr(12)
		elif String(a).begins_with("--archs="):
			ARCHS.assign(String(a).substr(8).split(","))
	DirAccess.make_dir_recursive_absolute(dir)
	for ak in ARCHS:
		who = ak
		await _setup()
		await _go(1.0)
		_snap(ak, "neutral", tag_name)
		P.kills += 1
		await _go(0.4)
		_snap(ak, "excited", tag_name)
		await _go(3.0)
		P.hp = P.max_hp * 0.6
		await _go(0.3)
		_snap(ak, "hurt", tag_name)
		m.queue_free()
		await main.get_tree().process_frame
	print("HUDPORTRAITSHOTS in ", dir)
	main.get_tree().quit(0)


func _snap(ak: String, mood: String, tag_name: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("hud_%s_%s_%s.png" % [ak, mood, tag_name]))
