extends "res://tools/vv_shots.gd"
## --grimble-kit-shots --shots-dir=<dir> --shots-tag=<before|after>: Grimble's three owner-note moves in a live Arena
## match (xvfb with a renderer), stills at the match camera: rmb_<tag>_{out,far,reel}.png (Deep Reach in flight, then
## the foe reeled in), lmb_<tag>_{shot,hang}.png (a volley just fired, then hanging at the stop range) and
## r_<tag>_{early,charge,wave}.png (Brass Broadside's charge and its first wave). Run it on main and on the branch.

const CROP := Vector2i(1000, 600)  # px round the point AHEAD m in front of him
const AHEAD := 3.5  # m
const CLOSE := Vector2i(360, 300)  # px round him, doubled: the pose of the arms

var tag_name := "after"


func run(main_node: Node) -> void:
	main = main_node
	who = "dredge"
	hero_name = "grimble"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--shots-tag="):
			tag_name = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	await _rmb()
	await _lmb()
	await _r()
	print("GRIMBLE_KIT_SHOTS in ", dir)
	main.get_tree().quit(0)


func _rmb() -> void:
	await _reset(7.0)
	var aim_at := func(_t): _aim(T.pos)
	P.inp["sec"] = true
	await _go(0.02, aim_at)
	P.inp["sec"] = false
	await _go(0.28, aim_at)
	_save("rmb", "out")
	await _go(0.2, aim_at)
	_save("rmb", "far")
	await _go(0.7, aim_at)
	_save("rmb", "reel")


func _lmb() -> void:
	await _reset(12.0)
	var aim_at := func(_t): _aim(home + Vector3(8.0, 0, 0))
	await _go(0.4, aim_at)
	P.inp["fire"] = true
	await _go(0.05, aim_at)
	P.inp["fire"] = false
	_save("lmb", "shot")
	await _go(0.3, aim_at)
	_save("lmb", "hang")


func _r() -> void:
	await _reset(5.0)
	P.ak.cd["x"] = 0.0
	var aim_at := func(_t): _aim(T.pos)
	HunterKeys.ult_pressed(P)
	await _go(0.5, aim_at)
	_save("r", "early")
	await _go(0.4, aim_at)
	_save("r", "charge")
	await _go(0.4, aim_at)
	_save("r", "wave")


func _save(kind: String, part: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	var base := "%s_%s_%s" % [kind, tag_name, part]
	_crop(img, P.pos + Vector3(AHEAD, 0.9, 0), CROP, 1.0).save_png(dir.path_join(base + ".png"))
	_crop(img, P.pos + Vector3(0, 1.1, 0), CLOSE, 2.0).save_png(dir.path_join(base + "_close.png"))
