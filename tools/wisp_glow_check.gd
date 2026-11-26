extends RefCounted
## --wisp-glow-check [--compat] [--shots-dir=<dir>]: both wisps (the Hunter Wisp, WispLook, and a Boki wisp, BokiWispLook)
## are drawn in a real viewport on a dark ground and must glow: the brightest pixel on the body is near white and
## the body's mean is well above the ground, never a dark blob. Run it under each renderer (--compat
## re-runs it in a child game on Compatibility, which the web build uses). Needs a GPU renderer: headless draws
## nothing, so the check says SKIP there. Prints WISPGLOW PASS/FAIL/SKIP.

const GROUND := Color(0.1, 0.11, 0.1)
const MIN_PEAK := 0.6   # luma of the brightest body pixel (rim or core is near white)
const MIN_MEAN := 0.3   # luma of the body's mean (the ground is 0.1)
const SIZE := Vector2i(256, 256)
const SPECIES := 2   # Boki species drawn (the first ones in Data.KIN)

var bad := 0


func run(main: Node) -> void:
	if DisplayServer.get_name() == "headless":
		print("WISPGLOW SKIP (headless draws nothing)")
		main.get_tree().quit(0)
		return
	if "--compat" in OS.get_cmdline_user_args() and Look.full_renderer():
		var args := ["--path", ProjectSettings.globalize_path("res://"), "--rendering-method", "gl_compatibility"]
		args.append_array(["--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--"])
		args.append_array(Array(OS.get_cmdline_user_args()).filter(func(a): return a != "--compat"))
		var out := []
		var code := OS.execute(OS.get_executable_path(), args, out, true)
		print("".join(out).strip_edges())
		main.get_tree().quit(code)
		return
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var team := Color("4a9be8")
	await _shot(main, "hunter_wisp", WispLook.build(WispLook.get_look(""), team), dir)
	for id in Data.KIN.keys().slice(0, SPECIES):
		var w := BokiWispLook.build(String(id), {})
		BokiWispLook.side(w, team)
		await _shot(main, "boki_wisp_" + String(id), w, dir)
	print("WISPGLOW %s (%d fail, %s)" % ["PASS" if bad == 0 else "FAIL", bad, RenderingServer.get_current_rendering_method()])
	main.get_tree().quit(1 if bad > 0 else 0)


func _shot(main: Node, tag: String, wisp: Node3D, dir: String) -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = GROUND
	vp.add_child(env)
	vp.add_child(wisp)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.position = Vector3(0, 0.1, 1.2)
	cam.look_at(Vector3(0, 0.1, 0))
	cam.current = true
	for i in 4:
		await main.get_tree().process_frame
	var img := vp.get_texture().get_image()
	if dir != "":
		img.save_png(dir.path_join(tag + ".png"))
	var peak := 0.0
	var sum := 0.0
	var n := 0
	var ground := GROUND.get_luminance()
	for y in img.get_height():
		for x in img.get_width():
			var l := img.get_pixel(x, y).get_luminance()
			if absf(l - ground) > 0.02:
				peak = maxf(peak, l)
				sum += l
				n += 1
	var mean := sum / maxf(n, 1.0)
	var good := n > 200 and peak >= MIN_PEAK and mean >= MIN_MEAN
	print("WISPGLOW %s %s: %d px, peak %.2f, mean %.2f" % [tag, "ok" if good else "FAIL", n, peak, mean])
	if not good:
		bad += 1
	vp.queue_free()
