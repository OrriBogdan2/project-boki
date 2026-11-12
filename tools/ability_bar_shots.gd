extends RefCounted
## --ability-bar-shots --shots-dir=<dir>: the ability bar for Kael (dash charges, airborne Meteor Drop),
## Cinder (rank 3, two Cinder Shots), Neve (two Ice Spears) and Grimble (barges, airborne air pounce),
## each with a charge ready and the next recharging. Run under a renderer; files are <dir>/bar_<kit>.png.

var main: Node
var dir := ""

func _grab(file: String, region: Rect2i) -> void:
	for i in 4:
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	var crop := img.get_region(region.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_BILINEAR)
	crop.save_png(dir.path_join("bar_%s.png" % file))
	print("BARSHOT ", file)

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
	for o in m.hunters:
		if o != P:
			o.teleport(P.pos + Vector3(60, 0, 60))
	var sz: Vector2i = main.get_viewport().get_visible_rect().size
	var bar := Rect2i(0, sz.y - 190, 700, 190)
	for kit in ["juggernaut", "ashwick", "rimewright", "dredge"]:
		P.reclass(Arch.weight(kit), kit, Arch.signature(kit))
		P.unlock_all()
		P.slot_lv["sec"] = 3
		P.slot_lv["dash"] = 3
		P.dashes = P.max_dashes() - 0.55
		P.grounded = kit in ["ashwick", "rimewright"]
		if kit == "juggernaut":
			P.ak.cd["air"] = 3.0
		if kit == "dredge":
			P.ex_cd = P.ak.long_dash_cd() * 0.5
		if P.ak.rmb_charges() > 1:
			P.ak.ch_rmb = float(P.ak.rmb_charges() - 1)
			P.ak.cd["rmb"] = 0.25 * float(P.ak.rmb_def().get("cooldown", 6.0)) * P.ak.cd_k("sec")
		await _grab(kit, bar)
	m.over = true
	main.get_tree().quit(0)
