extends "res://tools/tele_net_shots.gd"
## --reach-net-film --shots-dir=<dir>: Grimble's Deep Reach seen from another game (Net 0.24.20). Two games over the
## desktop relay (the --remote-anim-check harness): the guest (headless) plays Grimble and hooks this game's hunter
## CASTS times, reeling it in; this game draws every other step to <dir>/f_NNNN.png (30 fps) with the camera on
## both, for an MP4 (ffmpeg). Frames are kept small in memory and written after, so this game keeps real time with the
## guest's. Run it with a renderer (GPU, jobq). Lines: REACHFILM ok|FAIL <what>.

const CASTS := 5
const STAND := Vector3(6.0, 0, 0)  # m from home: where this game's hunter waits to be hooked
const CAST_GAP := 2.6  # s between the guest's casts (the reel and the arm's way home play out)
const ZOOM := 0.4  # the camera, close on both
const FRAME_W := 960  # px: each kept frame's width
const FILM_S := 12.0  # s of game time filmed (the guest starts casting as this game comes up)

var frames: Array[Image] = []
var go := false  # (the guest) this game is filming: cast


func _init() -> void:
	tag = "REACHFILM"
	guest_flag = "--reach-net-film=guest"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			shots_dir = a.substr(12)


func _host() -> void:
	Save.d["tutorial"][KitDrill.SAVE_KEY] = true  # no first-time drill banner over the frames
	var copy := await _host_up()
	if copy == null:
		return _finish()
	RenderingServer.render_loop_enabled = true  # (the harness turns drawing off; this one is looked at)
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if m.hud:
		m.hud.visible = false
	copy.reclass(Arch.weight("dredge"), "dredge")  # the copy's body (the arch does not ride the snapshot)
	m.cam.zoom = ZOOM
	m.cam.zoom_to = ZOOM
	_fresh(m.player)
	m.player.teleport(home + STAND)
	Net.lobby_emit("rf", {})
	var out_frames := 0
	var idle := 0.0  # s the copy's arm has been home (once the reel ends, this game's hunter goes back to STAND)
	var t := 0.0
	while t < FILM_S:
		var wire: Variant = copy.ak.get("wire")  # (null on a build before Net 0.24.20: the before film)
		idle = idle + DT if wire == null or (wire as Array).is_empty() else 0.0
		if idle > 0.6 and m.player.pos.distance_to(home + STAND) > 0.3:
			_fresh(m.player)
			m.player.teleport(home + STAND)
		var tip: Vector3 = copy.model.get_meta(WardenReach.TIP, Vector3.INF) if copy.model else Vector3.INF
		if tip.is_finite():
			out_frames += 1
		m.cam.snap(home + STAND * 0.5)
		for h in m.hunters:
			h.render(DT, 1.0)
		await _run(DT)
		t += DT
		if int(round(t / DT)) % 2 == 0:
			var img := main.get_viewport().get_texture().get_image()
			if img != null:
				img.resize(FRAME_W, FRAME_W * img.get_height() / img.get_width(), Image.INTERPOLATE_BILINEAR)
				frames.append(img)
	for i in frames.size():
		frames[i].save_png(shots_dir.path_join("f_%04d.png" % i))
	ok(out_frames > 30, "the guest's Grimble's arm is out on this game (%d steps)" % out_frames)
	ok(frames.size() > 100, "frames saved (%d; needs a renderer)" % frames.size())
	if FileAccess.file_exists(dir.path_join("guest.log")):
		DirAccess.copy_absolute(dir.path_join("guest.log"), shots_dir.path_join("guest.log"))
	_finish()


## Once its match is up, the guest's Grimble hooks the other game's hunter (STAND out) every CAST_GAP s.
func _cast_loop() -> void:
	while m == null or m.player == null:
		await main.get_tree().create_timer(0.2).timeout
	while not go and not stop:
		await main.get_tree().create_timer(0.1).timeout
	await main.get_tree().create_timer(0.5).timeout
	for i in CASTS:
		if stop:
			return
		_kit("dredge")
		_aim(home + STAND)
		m.player.inp["sec_hold"] = false
		m.player.ak.press_rmb()
		printerr("%s guest cast %d at %s, t %.1f" % [tag, i, home + STAND, m.time])
		await main.get_tree().create_timer(CAST_GAP).timeout


func _on_msg(topic: String, data, from: String) -> void:
	if topic == "rf":
		go = true
		return
	super._on_msg(topic, data, from)
