extends "res://tools/vv_shots.gd"
## --glide-cam-shots --shots-dir=<dir>: the match camera through a glide, a glide dive (crouch held) and the
## landing, driven the way Match drives it (CamRig.air_zoom, the glide lead, follow). One strip of whole views,
## glide_cam.png, with each frame's time and zoom in <dir>/captions.txt.

const FRAME_SCALE := 3          # each whole view shrunk this many times in the strip
const START_UP := 18.0          # m above the island where the glide starts
const DIVE_AT := 1.2            # s into the glide when crouch goes down

func run(main_node: Node) -> void:
	main = main_node
	hero_name = "glide"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	T.teleport(home + Vector3(-30, 0, 30))
	P.pos.y += START_UP
	P.grounded = false
	m.cam.zoom = m.cam.air_zoom(P, m.player_altitude())
	m.cam.snap(P.pos)
	var to_mid := Vector2(m.world.w * 0.5 - P.pos.x, m.world.h * 0.5 - P.pos.z).normalized()     # glide over the island
	var notes: Array = []
	var marks := [0.0, 0.5, DIVE_AT]
	var dive_mid := -1.0
	var land_t := -1.0
	var t := 0.0
	while t < 12.0:
		P.inp["glide"] = land_t < 0.0
		P.inp["crouch"] = t >= DIVE_AT and land_t < 0.0
		P.inp["move"] = to_mid if land_t < 0.0 else Vector2.ZERO
		m.step(DT)
		t += DT
		_park_others()
		for h in m.hunters:
			h.render(DT, 1.0)
		m.cam.zoom_to = m.cam.air_zoom(P, m.player_altitude())
		m.cam.lead_vel = m.cam_lead_vel()
		m.cam.follow(P.position, DT, false)
		await main.get_tree().process_frame
		if dive_mid < 0.0 and P.glide_dive.on and P.pos.y - P.ground() < START_UP * 0.5:
			dive_mid = t
			marks.append(t)
		if land_t < 0.0 and P.grounded:
			land_t = t
			marks.append_array([t, t + 0.5, t + 1.5])
		if not marks.is_empty() and t >= float(marks[0]):
			marks.pop_front()
			_frame(notes, t)
		if land_t > 0.0 and t > land_t + 1.6:
			break
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	f.store_line("glide_cam.png: left to right, " + ", ".join(notes))
	f.close()
	print("GLIDECAMSHOTS %d frames in %s" % [notes.size(), dir])
	main.get_tree().quit(0)

## Adds the whole view, shrunk, to the strip, and notes its time, state and zoom.
func _frame(notes: Array, t: float) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.resize(img.get_width() / FRAME_SCALE, img.get_height() / FRAME_SCALE, Image.INTERPOLATE_BILINEAR)
	if not strips.has("glide_cam.png"):
		strips["glide_cam.png"] = []
	(strips["glide_cam.png"] as Array).append(img)
	_save_strip("glide_cam.png")
	notes.append("t %.2f s %s zoom %.2f" % [t, _state(), m.cam.zoom])

func _state() -> String:
	if P.glide_dive.on:
		return "diving"
	if P.gliding:
		return "gliding"
	return "landed" if P.grounded else "falling"
