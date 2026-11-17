extends RefCounted
## --farm-crouch-look-check: the farm camera's wheel and Ctrl look are the match's (CamWheel).
##   0. you arrive at the wheel's widest (CamWheel.far); each wheel notch steps the zoom (and the camera's distance)
##      by the match's step, never past its min or max; with a panel open the wheel leaves the camera alone
##   1. held on the ground: the zoom goes to CamWheel.ctrl_zoom (the match's scout value) and the camera sits that
##      much further back; released, it eases back to the zoom it had
##   2. the wheel turned while it is held changes the zoom it comes back to, not the look
##   3. a panel open while it is held (the camera is the panel's) is left alone on release
## --farm-crouch-look-shots --shots-dir=<dir> (GPU): the farm at the landing, by the house (when the farm holds it)
## and the portal, at the old arrival zoom (1.2), the wheel's closest and its widest (the arrival now), and with Ctrl
## held: one PNG each.

const FRAMES := 600
var bad := 0
var main: Node
var home
var arrive := 0.0  # the zoom the farm opened with


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
	arrive = home.cam.zoom_to
	home.cam.zoom_to = CamWheel.far()
	home.cam.snap(home.ppos)
	for i in 30:
		await main.get_tree().process_frame


func run(m: Node, what: String) -> void:
	main = m
	await _start()
	if what == "shots":
		await _shots()
		return
	await _wheel_part()
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
		absf(home.cam.zoom - CamWheel.ctrl_zoom()) < 0.05 and d1 > d0 * CamWheel.ctrl_zoom() / base * 0.95,
		"held: the camera is %.1f m back, from %.1f m (zoom %.3f)" % [d1, d0, home.cam.zoom]
	)
	home._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	ok(is_equal_approx(home.cam.zoom_to, CamWheel.ctrl_zoom()), "the wheel does not touch the look while it is held")
	Input.action_release("crouch")
	await _settle(base + 0.0, 480)
	ok(
		is_equal_approx(home.cam.zoom_to, CamWheel.stepped(base, MOUSE_BUTTON_WHEEL_UP)),
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


## Part 0: the arrival zoom, then the wheel all the way in and back out, then a panel open.
func _wheel_part() -> void:
	var step := float(CamWheel.rules()["step"])
	ok(
		is_equal_approx(arrive, CamWheel.far()),
		"arriving: zoom %.2f is the wheel's widest %.2f" % [arrive, CamWheel.far()]
	)
	await _settle(CamWheel.far())
	var far_back := _back()
	var zooms := [home.cam.zoom_to]
	var steps_ok := true
	for button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		for i in 14:  # more notches than the range holds: it must stop at the end
			var was: float = home.cam.zoom_to
			home._unhandled_input(_wheel(button))
			var moved := absf(home.cam.zoom_to - was)
			var at_end := is_equal_approx(was, CamWheel.near()) or is_equal_approx(was, CamWheel.far())
			steps_ok = steps_ok and moved <= step + 0.001 and (moved > 0.001 or at_end)
			steps_ok = (
				steps_ok and home.cam.zoom_to >= CamWheel.near() - 0.001 and home.cam.zoom_to <= CamWheel.far() + 0.001
			)
			zooms.append(home.cam.zoom_to)
		if button == MOUSE_BUTTON_WHEEL_UP:
			ok(
				is_equal_approx(home.cam.zoom_to, CamWheel.near()),
				"wheel in: stops at the closest %.2f" % home.cam.zoom_to
			)
			await _settle(CamWheel.near())
			var near_back := _back()
			ok(
				near_back < far_back * 0.5,
				"closest: the camera %.1f m back, from %.1f m widest" % [near_back, far_back]
			)
	ok(
		steps_ok,
		(
			"every notch is one step of %.2f inside %.2f..%.2f (%d notches)"
			% [step, CamWheel.near(), CamWheel.far(), zooms.size() - 1]
		)
	)
	ok(is_equal_approx(home.cam.zoom_to, CamWheel.far()), "wheel out: stops at the widest %.2f" % home.cam.zoom_to)
	await _settle(CamWheel.far())
	ok(absf(_back() - far_back) < far_back * 0.02, "widest again: %.1f m back (%.1f m)" % [_back(), far_back])
	home.panel_open = "stub"
	home._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	ok(is_equal_approx(home.cam.zoom_to, CamWheel.far()), "a panel open: the wheel leaves the camera alone")
	home.panel_open = ""


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
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	print("FARMLOOK arrival zoom %.2f" % arrive)
	var at := {"landing": home.ppos}
	var house: Vector3 = home.spots.get("house", home.FAR)
	if house != home.FAR:
		at["house"] = house + Vector3(0, 0, 4)
	at["portal"] = home.spots["portal"] + Vector3(0, 0, 3)  # the way out
	# zoom 1.2: where the farm used to open, before it opened at the wheel's widest
	var views := [["old_default", 1.2], ["closest", CamWheel.near()], ["widest_default", CamWheel.far()]]
	for spot in at:
		home.ppos = at[spot]
		for v in views:
			home.cam.zoom_to = v[1]
			await _shot(dir, "base_%s_%s" % [spot, v[0]], v[1])
	home.ppos = at["landing"]
	home.cam.zoom_to = CamWheel.far()
	Input.action_press("crouch")
	await _shot(dir, "base_landing_ctrl", CamWheel.ctrl_zoom())
	Input.action_release("crouch")
	main.get_tree().quit(0)


func _shot(dir: String, file: String, want: float) -> void:
	await _settle(want)
	for i in 90:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	print("FARMLOOK shot %s: zoom %.2f, camera %.1f m back" % [file, home.cam.zoom, _back()])
