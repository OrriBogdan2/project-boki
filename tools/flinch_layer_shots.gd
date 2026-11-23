extends "res://tools/clip_shots.gd"
## --flinch-layer-shots --shots-dir=<dir>: four Hunters held in their LMB move in profile, all hit from the front at
## once: <dir>/flinch_layer_strip.png, one row per moment (before, 0.07, 0.13, 0.23, 0.47 s after the hit). The
## move keeps playing on every row; the torso leans back and settles. Needs a renderer.

const HEROES := [["archer", "arc_draw", 1.3], ["gunslinger", "gunslinger_lmb", 0.2], ["mage", "mage_lmb_l", 0.2],
	["juggernaut", "jug_slash_r", 0.2]]
const ROWS := [0, 2, 4, 7, 14]       # frames (1/30 s) after the hit
const W := 1400
const H := 350
const SPACING := 1.8                 # m between Hunters

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(W, H)
	main.get_viewport().size = Vector2i(W, H)
	_stage(main)
	cam.fov = 30.0
	cam.position = Vector3(0, 1.0, 4.1)
	cam.look_at(Vector3(0, 0.9, 0))
	var rigs: Array = []
	for i in HEROES.size():
		var model := Models.hunter(Arch.weight(HEROES[i][0]), Data.TEAM_COLORS[0], Arch.signature(HEROES[i][0]), "",
				PlayerLook.neutral(), HEROES[i][0])
		model.set_meta("anim_seed", 1)
		holder.add_child(model)
		model.position.x = (i - 1.5) * SPACING
		model.rotation.y = deg_to_rad(90.0)       # (faces -X: a front hit pushes it toward +X)
		(model.get_node("TeamRing") as Node3D).visible = false
		var s := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "kmove": HEROES[i][1],
			"kmove_t": HEROES[i][2], "hit_t": 99.0, "hit_dir": Vector2(1, 0), "hit_k": 1.0}
		model.set_meta(WardenClips.STATE, s)
		model.get_node("Warden/Sync").set_process(false)
		rigs.append([model.get_node("Warden/Sync"), s])
	for k in 30:
		await tree.process_frame
	_step(rigs, 12)
	DirAccess.make_dir_recursive_absolute(out)
	var strip := Image.create(W, H * ROWS.size(), false, Image.FORMAT_RGBA8)
	var done := 0
	for r in ROWS.size():
		_step(rigs, int(ROWS[r]) - done)
		await RenderingServer.frame_post_draw
		strip.blit_rect(tree.root.get_texture().get_image(), Rect2i(0, 0, W, H), Vector2i(0, H * r))
		done = int(ROWS[r])
		if r == 0:
			for rig in rigs:
				rig[1]["hit_t"] = 0.0
	strip.save_png(out.path_join("flinch_layer_strip.png"))
	tree.quit(0)

func _step(rigs: Array, n: int) -> void:
	for i in n:
		for rig in rigs:
			rig[1]["hit_t"] = minf(float(rig[1]["hit_t"]) + 1.0 / 30.0, 99.0)
			(rig[0] as Node).call("_process", 1.0 / 30.0)
