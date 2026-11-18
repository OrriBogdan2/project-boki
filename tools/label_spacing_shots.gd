extends "res://tools/vv_shots.gd"
## --label-spacing-shots --shots-dir=<dir>: a loot name, a damage number and a monster plate on the same
## spot of a live Arena match (xvfb with a renderer). label_before.png has the HUD's spacing pass off,
## label_after.png has it on: the lower-priority labels fade back, the number stays.

const SPOT := Vector3(4.5, 0, 0)         # m east of the hero: where the three labels meet
const CROP := Vector2i(360, 240)         # px round the spot (scaled 2x)

func run(main_node: Node) -> void:
	main = main_node
	who = "ostra"
	hero_name = "ostra"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var at := home + SPOT
	PerkOrbs.drop(m, "chest", at, 1, P)
	var mob := m.spawn_mob("brute", at + Vector3(0, 0, 0.5))
	if mob != null:
		mob.add_child(_plate())
	Settings.set_v("damage_numbers", true, false)
	var name_at: Vector3 = (PerkOrbs.list(m)[0]["node"] as Node3D).get_node("Bob/Name").global_position
	m.fx.number(name_at + Vector3(0.3, -0.2, 0), 48.0, Color("ffd24a"), true)
	var hold := func(_t):
		for n in m.fx.nums:
			n["t"] = 0.0
			n["last"] = 0.0
			n["vel"] = Vector3.ZERO
	m.hud.set_process(false)
	await _go(0.6, hold)
	_snap("label_before.png", at)
	m.hud.set_process(true)
	await _go(1.2, hold)
	_snap("label_after.png", at)
	print("LABELSHOTS in ", dir)
	main.get_tree().quit(0)

func _plate() -> Label3D:
	var lbl := Label3D.new()
	lbl.text = "Frostbitten Brute"
	lbl.font = UI.big
	lbl.font_size = 30
	lbl.pixel_size = 0.009
	lbl.outline_size = 9
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position.y = 2.6
	lbl.name = "Nameplate"
	return lbl

func _snap(file: String, at: Vector3) -> void:
	var img := main.get_viewport().get_texture().get_image()
	_crop(img, at + Vector3(0, 2.2, 0), CROP, 2.0).save_png(dir.path_join(file))
