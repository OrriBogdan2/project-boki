extends RefCounted
## --home-verbs-check --home-verbs-shots=<dir>: a strip of the four garden moves on the home player
## (feed, pat, toss, cheer), each at its peak, cropped around the body. Needs a real renderer.

const PEAK := {"feed": 0.9, "pat": 0.85, "toss": 0.5, "cheer": 0.7}      # s into each move
const CROP := Vector2i(300, 360)       # px around the player

func run(main: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	Save.d = d
	HomeLayout.ensure(d)
	Settings.set_v("cam_style", "low", false)
	var home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.player != null and home.hb != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	home.talk_cd = 1.0e9
	home.cam.zoom_to = 3.0
	home.cam.zoom = 3.0
	if main.fade: main.fade.reveal(0.05)
	await main.get_tree().create_timer(1.0).timeout
	var strip := Image.create(CROP.x * PEAK.size(), CROP.y, false, Image.FORMAT_RGBA8)
	var i := 0
	for verb in PEAK:
		home.verbs.play(verb)
		await main.get_tree().create_timer(float(PEAK[verb])).timeout
		var vp := main.get_viewport()
		var at := vp.get_camera_3d().unproject_position(home.player.global_position + Vector3(0, 0.9, 0))
		var img := vp.get_texture().get_image()
		var r := Rect2i(Vector2i(at) - CROP / 2, CROP).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		strip.blit_rect(img, r, Vector2i(i * CROP.x, 0) + (r.position - (Vector2i(at) - CROP / 2)))
		print("HOMEVERBS strip %s" % verb)
		home.verbs.act = ""
		await main.get_tree().create_timer(0.5).timeout
		i += 1
	strip.save_png(dir.path_join("home_verbs_strip.png"))
	print("HOMEVERBS strip saved")
	main.get_tree().quit()
