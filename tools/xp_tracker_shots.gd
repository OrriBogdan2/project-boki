extends RefCounted
## --xp-tracker-shots --shots-dir=<dir> [--res=WxH]: review screenshots of the XP tracker beside the
## health bar (run under a real renderer): quiet, mid-fill, the pop as XP lands, and a skill point
## ready to rank. Each is a crop of the bottom-left of the screen, saved as xp_<name>_<H>p.png.

var main: Node
var dir := ""
var res := Vector2i(1280, 720)

func _grab(m: Match, file: String, frames := 4) -> void:
	for i in frames:
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	var sz := img.get_size()
	var crop := img.get_region(Rect2i(0, sz.y - sz.y / 4, sz.x / 3, sz.y / 4))
	crop.save_png(dir.path_join("xp_%s_%dp.png" % [file, sz.y]))
	print("XPSHOT ", file, " ", sz, " lvl ", m.player.lvl, " xp ", m.player.xp)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--res="):
			var wh := String(a).substr(6).split("x")
			res = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	DisplayServer.window_set_size(res)
	main.get_window().size = res
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "arch": "thief",
		"cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	for o in m.hunters:
		if o != P:
			o.teleport(P.pos + Vector3(60, 0, 60))
	P.skill_pts = 0
	await _grab(m, "1_empty", 8)
	P.gain_xp(35.0)
	await _grab(m, "2_pop", 2)
	await _grab(m, "3_filled", 40)
	P.gain_xp(40.0)
	P.skill_pts = 1
	await _grab(m, "4_levelup_rank", 50)
	m.over = true
	m.queue_free()
	main.get_tree().quit(0)
