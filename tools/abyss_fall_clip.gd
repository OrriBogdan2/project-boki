extends "res://tools/abyss_check.gd"
## --abyss-fall-clip --shots-dir=<dir>: a walk off an island's lip at the match camera, 15 fps: <dir>/f000.png...
## The Hunter walks over a rim, falls FALL_S on its own, then holds glide on an overheated glider (half strength)
## back up to the lip and lands. Prints "AFCLIP t depth cam" rows (camera distance in metres) and "AFCLIP DONE".
## Needs a renderer (jobq --needs gpu). Never touches the save.

const STEPS_PER_FRAME := 4       # 60 Hz steps per 15 fps frame
const FALL_S := 1.3              # s of free fall before glide is pressed (about 10 m under the lip)
const CLIP_S := 4.5

func run(main: Node) -> void:
	Save.no_write = true
	var dir := "user://abyss_fall_clip"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	_open(main)
	await main.get_tree().process_frame
	if main.get("fade") != null:
		await main.fade.reveal(0.01)       # the boot splash stays up when a tool starts the match by hand
	var edges := _edges(6)
	if edges.is_empty():
		print("AFCLIP no rim")
		main.get_tree().quit()
		return
	var e: Dictionary = edges[0]
	var d: Vector2 = e["dir"]
	var top: float = e["top"]
	_reset(Vector3(e["ex"] - d.x * 2.5, top, e["ez"] - d.y * 2.5), Vector3.ZERO)
	h.grounded = true
	h.last_gy = top
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 20:
		_frame(STEPS_PER_FRAME * Match.DT)        # the camera settles on the start
		await main.get_tree().process_frame
	var fall_t := -1.0
	var n := 0
	var t := 0.0
	while t < CLIP_S:
		for s in STEPS_PER_FRAME:
			h.inp["move"] = d if fall_t < 0.0 else Vector2.ZERO
			h.inp["glide"] = fall_t >= FALL_S and not h.grounded
			if h.inp["glide"]:
				h.glide_fuel = 0.0              # overheated: it still lifts, at half strength (DECISIONS)
			m.step(Match.DT)
			t += Match.DT
			if fall_t < 0.0 and not h.grounded and w.is_void(h.pos.x, h.pos.z):
				fall_t = 0.0
			elif fall_t >= 0.0:
				fall_t += Match.DT
		_frame(STEPS_PER_FRAME * Match.DT)
		await main.get_tree().process_frame
		m.get_viewport().get_texture().get_image().save_png(dir.path_join("f%03d.png" % n))
		n += 1
		print("AFCLIP %.2f depth %.1f cam %.1f" % [t, top - h.pos.y, m.cam.position.distance_to(m.cam.focus)])
	print("AFCLIP DONE (%d frames)" % n)
	main.get_tree().quit()
