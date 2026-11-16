extends RefCounted
## --home-verbs-check --home-verbs-shots=<dir>: the Empty's garden moves at home on a small and a big Boki
## (a row each): the pat, the feed and the lift (through the real petting, feeding and picking-up paths, so the
## Boki comes up and the hands reach for its head, its mouth and its flanks), the cheer and the toss, each at
## its peak, cropped around the body.
## Needs a real renderer.

const PEAK := {"pat": 0.7, "feed": 0.55, "lift": 0.31, "cheer": 0.32, "toss": 0.5}      # s into each move
const BOKI := ["glomwort", "zapple"]      # the smallest and the biggest Boki (0.5 and 1.2 m)
const CROP := Vector2i(360, 400)       # px around the player

func run(main: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	for sp in BOKI:
		var k := Save.new_kin(sp, sp.capitalize())
		Care.ensure(k)
		d["roster"].append(k)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	d["items"]["kibble"] = 9
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
	home.cam.zoom_to = 0.55
	home.cam.zoom = 0.55
	home.cam.yaw = -PI * 0.5      # from the Boki's side: a front three-quarter, the reach not behind the cloak or Hob
	home.cam.yaw_to = -PI * 0.5
	if main.fade: main.fade.reveal(0.05)
	await main.get_tree().create_timer(1.0).timeout
	var strip := Image.create(CROP.x * PEAK.size(), CROP.y * BOKI.size(), false, Image.FORMAT_RGBA8)
	for row in BOKI.size():
		var rec: Dictionary = d["roster"][row]
		var ke: Dictionary = home._kin_entry(rec)
		for other in home.kins:      # the other Boki out of the frame
			if other != ke:
				other["pos"] = home.ppos + Vector3(6.0, 0.0, 6.0)
				(other["node"] as Node3D).position = other["pos"]
		var col := 0
		for verb in PEAK:
			ke["pos"] = home.ppos + Vector3(-0.9, 0.0, -0.9)
			(ke["node"] as Node3D).position = ke["pos"]
			match verb:
				"pat": home._pet_kin(ke)
				"feed": home._care_feed(rec, "kibble")
				"lift": home.carry.press_hold(ke)
				_: home.verbs.play(verb)
			await main.get_tree().create_timer(float(PEAK[verb])).timeout
			_shot(main, home, strip, Vector2i(col * CROP.x, row * CROP.y))
			print("HOMEVERBS strip %s %s" % [BOKI[row], verb])
			if home.carry.carrying():
				home.carry.drop()
			home.verbs.act = ""
			await main.get_tree().create_timer(0.6).timeout
			col += 1
	strip.save_png(dir.path_join("home_verbs_strip.png"))
	print("HOMEVERBS strip saved")
	main.get_tree().quit()

func _shot(main: Node, home, strip: Image, at_px: Vector2i) -> void:
	var vp: Viewport = main.get_viewport()
	var at := vp.get_camera_3d().unproject_position(home.player.global_position + Vector3(0, 0.6, -0.3))
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var r := Rect2i(Vector2i(at) - CROP / 2, CROP).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	strip.blit_rect(img, r, at_px + (r.position - (Vector2i(at) - CROP / 2)))
