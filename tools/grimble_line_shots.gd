extends "res://tools/vv_shots.gd"
## --grimble-line-shots --shots-dir=<dir> --shots-tag=<before|after>: Grimble in a live Arena match (xvfb with a
## renderer). line_<tag>.png: the aim line while he stands aiming; group_<tag>.png: one volley hanging at the slug
## stop range. Run it on main and on the branch (docs/heroes/dredge.md, Scattergun).

const CROP := Vector2i(900, 520)  # px round the point 3.5 m ahead of him
const AHEAD := 3.5                # m


func run(main_node: Node) -> void:
	main = main_node
	who = "dredge"
	hero_name = "grimble"
	var tag_name := "after"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--shots-tag="):
			tag_name = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	await _reset(12.0)
	T.teleport(home + Vector3(0, 0, 14.0))
	var aim_at := func(_t): _aim(home + Vector3(8.0, 0, 0))
	await _go(0.6, aim_at)
	_save("line", tag_name)
	P.inp["fire"] = true
	await _go(0.02, aim_at)
	P.inp["fire"] = false
	# the slugs have stopped and hang as dots: a beat after the shot
	await _go(0.36, aim_at)
	_save("group", tag_name)
	print("GRIMBLESHOTS in ", dir)
	main.get_tree().quit(0)


func _save(kind: String, tag_name: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	var at := P.pos + Vector3(AHEAD, 0.9, 0)
	_crop(img, at, CROP, 1.0).save_png(dir.path_join("%s_%s.png" % [kind, tag_name]))
