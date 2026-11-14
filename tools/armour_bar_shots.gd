extends RefCounted
## --armour-bar-shots --shots-dir=<dir> --res=<w>x<h> [--hover=armor_level] (under xvfb with a renderer):
## the armour progress bar under the armour strip, as crops of the bottom-left vitals block: partway into a
## tier, a hit's tick, the next tier's colour, and full at the top tier. Files: armour_bar_<res>_<label>.png.

var main: Node
var dir := ""
var res := "1280x720"

func _grab(m: Match, label: String, crop_scale: int) -> void:
	m.hud.c.queue_redraw()
	m.hud.panels.queue_redraw()
	await main.get_tree().create_timer(0.4).timeout     # the hover tip waits 0.25 s
	var img := main.get_viewport().get_texture().get_image()
	var sz := img.get_size()
	var crop := img.get_region(Rect2i(0, int(sz.y * 0.62), int(sz.x * 0.42), int(sz.y * 0.38)))
	crop.resize(crop.get_width() * crop_scale, crop.get_height() * crop_scale, Image.INTERPOLATE_BILINEAR)
	crop.save_png(dir.path_join("armour_bar_%s_%s.png" % [res, label]))
	print("ARMOURSHOT ", res, " ", label)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--res="):
			res = String(a).substr(6)
	DirAccess.make_dir_recursive_absolute(dir)
	var wh := res.split("x")
	main.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
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
	var k := 2 if int(wh[1]) <= 800 else 1
	P.armor_gain(90.0)
	await _grab(m, "1_in_tier", k)
	m.time += 1.0
	P.armor_gain(40.0)
	await _grab(m, "2_after_hit", k)
	P.armor_gain(float(Hunter.ARMOR_TIERS[2][2]) - P.armor_xp - 100.0)
	await _grab(m, "3_rare_tier", k)
	P.armor_gain(5000.0)
	await _grab(m, "4_top_tier", k)
	m.flow.finish("check done")
	m.queue_free()
	await main.get_tree().process_frame
	main.get_tree().quit()
