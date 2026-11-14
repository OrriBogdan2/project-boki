extends RefCounted
## --dash-slot-shots --shots-dir=<dir>: the dash slot's review screenshots (run under xvfb with a renderer).
## The match bar's slot with 2 charges, 1 recharging and 0; the same slot at home. Files go straight into
## <dir> as dash_slot_<name>.png, each a crop of the bottom of the screen.

var main: Node
var dir := ""

func _grab(file: String, region: Rect2i) -> void:
	for i in 4:
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	var crop := img.get_region(region.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_BILINEAR)
	crop.save_png(dir.path_join("dash_slot_%s.png" % file))
	print("DASHSHOT ", file)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "arch": "juggernaut",
		"cls": Arch.weight("juggernaut"), "weapon": Arch.signature("juggernaut")})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	P.unlock_all()
	for o in m.hunters:
		if o != P:
			o.teleport(P.pos + Vector3(60, 0, 60))
	var sz: Vector2i = main.get_viewport().get_visible_rect().size
	var bar := Rect2i(0, sz.y - 190, 700, 190)
	P.dashes = P.max_dashes()
	await _grab("match_2_charges", bar)
	P.dashes = 1.45
	await _grab("match_1_recharging", bar)
	P.dashes = 0.3
	P.ex_cd = 6.0
	await _grab("match_0_charges", bar)
	m.over = true
	m.queue_free()
	await main.get_tree().process_frame
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	Save.d["tutorial"] = {"home": true, "day1_done": true}
	Econ.ensure()
	var home = await main._hb_home()
	if fade != null:
		await fade.reveal(0.01)
	home._move_player(0.001)
	var hb := Rect2i(sz.x / 2 - 200, sz.y - 190, 400, 190)
	home.dash_charges = float(home._dodge()["charges"])
	await _grab("home_2_charges", hb)
	home.dash_charges = 1.45
	await _grab("home_1_recharging", hb)
	home.dash_charges = 0.3
	home.ex_cd = 6.0
	await _grab("home_0_charges", hb)
	main.get_tree().quit(0)
