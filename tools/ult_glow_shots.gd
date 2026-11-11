extends RefCounted
## --ult-glow-shots --shots-dir=<dir> (xvfb with a renderer): at match zoom, a rival whose ultimate is ready next to
## you with yours ready too, then the moment after your cast (the flash), then the flash faded. Each is the full
## frame and a 3x crop round you. Never touches the save.

const CROP := Vector2i(220, 160)     # px round the player, scaled 3x

var main: Node
var m: Match
var dir := "user://shots"

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1500.0, "seed": 4242, "no_drop": true,
		"cls": Arch.weight("ashwick"), "arch": "ashwick", "weapon": Arch.signature("ashwick")})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	m.cam.lead = 0.0
	Settings.set_v("tips", false)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var P := m.player
	var foe: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	foe.ctrl = "idle"
	foe.set_arch("thief")
	foe.teleport(m.world.free_spot_near(P.pos + Vector3(2.5, 0, -1.0), [], 1.0, 0.5, 8.0))
	foe.reveal_t = 60.0
	for h in [P, foe]:
		h.lvl = int(Hunter.ULT_AT[0])
		h.ak.cd["x"] = 0.0
	await _shot("1_ready")
	P.ak.cd["x"] = 30.0
	await _shot("2_cast_flash", 2)
	await _shot("3_after", 60)
	main.get_tree().quit(0)

func _shot(tag: String, frames := 40) -> void:
	var vp := main.get_viewport()
	for i in frames:
		await main.get_tree().process_frame
	var img := vp.get_texture().get_image()
	img.save_png(dir.path_join(tag + ".png"))
	var c := Vector2i(m.cam.unproject_position(m.player.pos + Vector3.UP))
	var crop := img.get_region(Rect2i(c - CROP / 2, CROP))
	crop.resize(CROP.x * 3, CROP.y * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(dir.path_join(tag + "_zoom.png"))
	print("ULTGLOWSHOTS %s glow %.2f" % [tag, m.player.ult_glow])
