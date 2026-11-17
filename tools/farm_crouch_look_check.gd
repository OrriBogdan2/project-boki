extends RefCounted
## --farm-crouch-look-check: holding crouch (Ctrl) on the farm pulls the camera out the way it does in a match.
##   1. held on the ground: the zoom goes to CamWheel.ctrl_zoom (the match's scout value) and the camera sits that
##      much further back; released, it eases back to the zoom it had
##   2. the wheel turned while it is held changes the zoom it comes back to, not the look
##   3. a panel open while it is held (the camera is the panel's) is left alone on release
## --farm-crouch-look-shots --shots-dir=<dir> (GPU): the farm standing and with crouch held, one PNG each.

const FRAMES := 600
var bad := 0
var main: Node
var home


func ok(cond: bool, what: String) -> void:
	print("FARMLOOK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _settle(want: float, secs_frames := FRAMES) -> void:
	for i in secs_frames:
		await main.get_tree().process_frame
		if absf(home.cam.zoom - want) < 0.01:
			break


func _back() -> float:
	return home.cam.global_position.distance_to(home.cam.focus)


func _start() -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	home = await main._hb_home()
	home.ppos = HomeLayout.LANDING + Vector3(-6, 0, -3)
	home.py = 0.0
	home.pvy = 0.0
	home._close_panel()  # (the welcome card)
	home.cam.zoom_to = home.HOME_ZOOM
	home.cam.snap(home.ppos)
	for i in 30:
		await main.get_tree().process_frame


func run(m: Node, what: String) -> void:
	main = m
	await _start()
	if what == "shots":
		await _shots()
		return
	var base: float = home.cam.zoom_to
	await _settle(base)
	var d0 := _back()
	Input.action_press("crouch")
	await _settle(CamWheel.ctrl_zoom())
	var d1 := _back()
	ok(
		is_equal_approx(home.cam.zoom_to, CamWheel.ctrl_zoom()),
		(
			"held: zoom target %.2f is the match's Ctrl zoom %.2f (%.2f before)"
			% [home.cam.zoom_to, CamWheel.ctrl_zoom(), base]
		)
	)
	ok(
		absf(home.cam.zoom - CamWheel.ctrl_zoom()) < 0.05 and d1 > d0 * 1.5,
		"held: the camera is %.1f m back, from %.1f m (zoom %.3f)" % [d1, d0, home.cam.zoom]
	)
	home._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	ok(is_equal_approx(home.cam.zoom_to, CamWheel.ctrl_zoom()), "the wheel does not touch the look while it is held")
	Input.action_release("crouch")
	await _settle(base + 0.0, 480)
	ok(
		absf(home.cam.zoom_to - (base - 0.08)) < 0.001,
		"released: the zoom is back to the wheel's (%.2f), the held wheel turn kept" % home.cam.zoom_to
	)
	home.cam.zoom_to = base
	await _settle(base)
	Input.action_press("crouch")
	await _settle(CamWheel.ctrl_zoom())
	home.panel_open = "stub"
	home.cam.zoom_to = 0.62
	Input.action_release("crouch")
	for i in 10:
		await main.get_tree().process_frame
	ok(is_equal_approx(home.cam.zoom_to, 0.62), "a panel that set the camera keeps it after the key lets go")
	home.panel_open = ""
	print("FARMLOOK CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _wheel(button: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	return e


func _shots() -> void:
	var dir := "user://shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Settings.set_v("tips", false)
	var vp := main.get_viewport()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for st in [["farm_normal", false], ["farm_crouched", true]]:
		if st[1]:
			Input.action_press("crouch")
		await _settle(CamWheel.ctrl_zoom() if st[1] else home.cam.zoom_to)
		for i in 90:
			await main.get_tree().process_frame
		vp.get_texture().get_image().save_png(dir.path_join(String(st[0]) + ".png"))
		print("FARMLOOK shot %s: zoom %.2f, camera %.1f m back" % [st[0], home.cam.zoom, _back()])
	Input.action_release("crouch")
	main.get_tree().quit(0)
