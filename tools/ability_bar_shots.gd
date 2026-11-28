extends RefCounted
## --ability-bar-shots --shots-dir=<dir>: the ability bar for Kael (dash charges, airborne Meteor Drop),
## Cinder (rank 3, two Cinder Shots), Neve (two Ice Spears) and Grimble (barges, airborne air pounce),
## each with a charge ready and the next recharging, then the Thief Grounded (bar_grounded.png, bar_grounded_full.png).
## Run under a renderer; files are <dir>/bar_<kit>.png.

var main: Node
var dir := ""

func _grab(file: String, region: Rect2i) -> void:
	for i in 4:
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	var k := float(img.get_width()) / float(main.get_viewport().get_visible_rect().size.x)  # px per layout px
	var px := Rect2i(Vector2(region.position) * k, Vector2(region.size) * k)
	var crop := img.get_region(px.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	crop.save_png(dir.path_join("bar_%s.png" % file))
	print("BARSHOT ", file, " ", img.get_size())

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Settings.set_v("hud_full", true, false)  # (every HUD group: the staged HUD hides the ability row)
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "arch": "juggernaut",
		"cls": Arch.weight("juggernaut"), "weapon": Arch.signature("juggernaut")})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	for o in m.hunters:
		if o != P:
			o.teleport(P.pos + Vector3(60, 0, 60))
	await main.get_tree().process_frame
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
	P.reclass(Arch.weight("thief"), "thief", Arch.signature("thief"))
	P.unlock_all()
	P.grounded = true
	P.dashes = P.max_dashes()
	KitStatus.apply(P, "gnd", 3.0, 0.0, false)
	m.time += 1.0     # a third of the ring gone
	await _grab("grounded", bar)
	await _grab("grounded_full", Rect2i(Vector2i.ZERO, sz))
	m.over = true
	main.get_tree().quit(0)
