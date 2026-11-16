extends RefCounted
## --glint-fishing-check --glint-fishing-shots=<dir>: one full cast on the home player (the rod held, wind-back, flick,
## the bite, the reel, the lift), each at its moment, cropped around the body. Needs a real renderer
## (jobq submit --needs gpu). The body turns to face the right of the screen so the rod reads side-on.

# what the cast does, in order: a held pose ("hold"), a one-shot ("play"), the seconds it runs before the next step,
# and whether a frame is taken then
const STEPS := [{"hold": "wait", "wait": 0.6, "shot": true}, {"play": "cast", "wait": 0.27, "shot": true},
		{"wait": 0.12, "shot": true}, {"wait": 0.7}, {"play": "bite", "wait": 0.06, "shot": true}, {"wait": 0.5},
		{"hold": "reel", "wait": 0.3, "shot": true}, {"hold": "wait", "play": "land", "wait": 0.4, "shot": true}]
const SHOTS := 6
const CROP := Vector2i(360, 420)       # px around the player
const TURN_PX := 300.0                 # px right of the body the mouse is warped to, to face it that way

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
	home.cam.zoom_to = 0.3
	home.cam.zoom = 0.3
	home.cam.yaw = -PI * 0.5      # from the side, the rod not behind the cloak or Hob
	home.cam.yaw_to = -PI * 0.5
	home.root_ui.visible = false
	if main.fade: main.fade.reveal(0.05)
	var vp := main.get_viewport()
	var at := vp.get_camera_3d().unproject_position(home.player.global_position + Vector3(0, 0.9, 0))
	vp.warp_mouse(at + Vector2(TURN_PX, 0.0))
	await main.get_tree().create_timer(1.0).timeout
	var strip := Image.create(CROP.x * SHOTS, CROP.y, false, Image.FORMAT_RGBA8)
	var taken := 0
	for st in STEPS:
		if st.has("hold"):
			home.verbs.hold(st["hold"])
		if st.has("play"):
			home.verbs.play(st["play"])
		await main.get_tree().create_timer(float(st["wait"])).timeout
		if not st.has("shot"):
			continue
		at = vp.get_camera_3d().unproject_position(home.player.global_position + Vector3(0, 0.9, 0))
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var r := Rect2i(Vector2i(at) - CROP / 2, CROP).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		strip.blit_rect(img, r, Vector2i(taken * CROP.x, 0) + (r.position - (Vector2i(at) - CROP / 2)))
		print("GLINTFISH strip %d %s %s" % [taken, home.verbs.act, home.verbs.stance])
		taken += 1
	home.verbs.hold("")
	strip.save_png(dir.path_join("glint_fishing_cast_strip.png"))
	print("GLINTFISH strip saved")
	main.get_tree().quit()
