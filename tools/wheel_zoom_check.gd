extends RefCounted
## --wheel-zoom-check: the wheel zooms the hunter. ViewZoom (wheel up zooms in, clamps both ways, eases), the Relics
## page's viewer camera follows it (wheel over the stage only), and in a match the wheel sets the zoom inside the
## range, Ctrl (sneak) goes past the max and eases back on release, and a wheel a player bound to an action stays
## theirs.

var bad := 0
const DT := 1.0 / 60.0

func ok(cond: bool, what: String) -> void:
	print("WHEELZOOM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _wheel(button: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev

func run(main: Node) -> void:
	var tree := main.get_tree()
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["cls"] = "medium"
	d["arch"] = "gunslinger"
	d["classes"] = ClassUnlock.legacy()
	Save.d = d
	_view_zoom()
	await _viewer(main)
	await _results(main)
	await _match(main)
	print("WHEELZOOM DONE, failures: %d" % bad)
	tree.quit()

func _view_zoom() -> void:
	var r := ViewZoom.rules()
	var z := ViewZoom.new()
	ok(not z.wheel(InputEventKey.new()) and z.want == 1.0, "a key is not a wheel notch")
	ok(z.wheel(_wheel(MOUSE_BUTTON_WHEEL_UP)) and z.want < 1.0, "wheel up zooms in (want %.2f)" % z.want)
	z.tick(DT)
	ok(z.k < 1.0 and z.k > z.want, "it eases toward it, not a jump (%.3f)" % z.k)
	for i in 100: z.wheel(_wheel(MOUSE_BUTTON_WHEEL_UP))
	ok(is_equal_approx(z.want, float(r["min"])), "and stops at the closest (%.2f)" % z.want)
	for i in 100: z.wheel(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	ok(is_equal_approx(z.want, float(r["max"])), "wheel down stops at the furthest (%.2f)" % z.want)
	var p := ViewZoom.new()
	p.pad(0.1, 0.1, 1.0)
	ok(p.want == 1.0, "pad: stick and trigger inside the dead zone do nothing")
	p.pad(-1.0, 0.0, 0.1)
	ok(p.want < 1.0, "pad: right stick up zooms in (%.2f)" % p.want)
	var w0 := p.want
	p.pad(0.0, -1.0, 0.1)
	ok(p.want > w0, "pad: the left trigger zooms out (%.2f)" % p.want)
	w0 = p.want
	p.pad(0.0, 1.0, 0.1)
	ok(p.want < w0, "pad: the right trigger zooms in (%.2f)" % p.want)
	p.pad(-1.0, 1.0, 100.0)
	ok(is_equal_approx(p.want, float(r["min"])), "pad: held, it stops at the closest (%.2f)" % p.want)
	p.pad(1.0, -1.0, 100.0)
	ok(is_equal_approx(p.want, float(r["max"])), "pad: and at the furthest (%.2f)" % p.want)

func _viewer(main: Node) -> void:
	var tree := main.get_tree()
	var host := Control.new()
	host.position = Vector2(-60, -200)      # (headless has no mouse: the stage sits over the 0,0 it reports)
	host.size = Vector2(900, 900)
	main.add_child(host)
	var v := HunterViewer.make("gunslinger", Vector2(220, 300), Vector2(200, 112), 2)
	host.add_child(v)
	for i in 400:
		await tree.process_frame
		if v.model != null: break
	ok(v.model != null, "the Relics viewer built its model")
	if v.model == null:
		return
	var at := Vector3(0, 0.95 * v.model.scale.y, 0)
	var d0 := v.cam.position.distance_to(at)
	ok(v._stage_box.get_global_rect().has_point(v.get_global_mouse_position()), "the mouse is over the stage")
	Input.parse_input_event(_wheel(MOUSE_BUTTON_WHEEL_UP))
	for i in 40: await tree.process_frame
	var d1 := v.cam.position.distance_to(at)
	ok(d1 < d0 - 0.2, "the wheel over the stage moves its camera in (%.2f -> %.2f m)" % [d0, d1])
	v._stage_box.global_position += Vector2(2000, 0)
	var was := v.zoom.want
	v._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	ok(v.zoom.want == was, "a wheel off the stage leaves it (the page scrolls)")
	for i in 100: v.zoom.wheel(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	v.tick(5.0)
	ok(v.cam.position.distance_to(at) > d0, "zoomed out, past its framing (%.2f m)" % v.cam.position.distance_to(at))
	host.queue_free()

func _results(main: Node) -> void:
	var tree := main.get_tree()
	var scr: Control = load("res://scripts/ui/results.gd").new()
	main.add_child(scr)
	scr.show_result({"place": 3, "squads": 10})
	for i in 5: await tree.process_frame
	ok(scr.cam != null, "results: the island camera is up")
	if scr.cam == null:
		scr.queue_free()
		return
	var at: Vector3 = scr.CAM_AT
	var d0: float = scr.cam.position.distance_to(at)
	var e := _wheel(MOUSE_BUTTON_WHEEL_UP)
	for i in 3: scr._unhandled_input(e)
	for i in 60: scr._process(DT)
	var d1: float = scr.cam.position.distance_to(at)
	ok(d1 < d0 - 0.3, "results: the wheel moves the camera in (%.2f -> %.2f m)" % [d0, d1])
	for i in 100: scr._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	for i in 120: scr._process(DT)
	var d2: float = scr.cam.position.distance_to(at)
	var far := d0 * float(ViewZoom.rules()["max"])
	ok(is_equal_approx(d2, far), "results: wheel down stops at the furthest (%.2f m)" % d2)
	scr.queue_free()

func _match(main: Node) -> void:
	var tree := main.get_tree()
	Settings.v["cam_zoom"] = 1.0      # (the wheel is kept between matches: each starts from the default)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 77, "no_drop": true})
	m.set_process(false)
	for i in 5: await tree.process_frame
	var r: Dictionary = CamWheel.rules()["match"]
	var w: Dictionary = CamWheel.rules()["widen"]
	var used := CamWheel.input(m, _wheel(MOUSE_BUTTON_WHEEL_UP))
	ok(used and m.cam.user_zoom < 1.0, "match: the wheel zooms in (%.2f)" % m.cam.user_zoom)
	for i in 100: CamWheel.input(m, _wheel(MOUSE_BUTTON_WHEEL_UP))
	ok(is_equal_approx(m.cam.user_zoom, float(r["min"])), "match: stops at the closest (%.2f)" % m.cam.user_zoom)
	for i in 100: CamWheel.input(m, _wheel(MOUSE_BUTTON_WHEEL_DOWN))
	ok(is_equal_approx(m.cam.user_zoom, float(r["max"])), "match: stops at the furthest (%.2f)" % m.cam.user_zoom)
	var kept := float(Settings.get_v("cam_zoom"))
	ok(is_equal_approx(kept, float(r["max"])), "match: the player's zoom is kept in Settings (%.2f)" % kept)
	var next := CamRig.new()
	main.add_child(next)
	ok(is_equal_approx(next.user_zoom, float(r["max"])), "match: the next camera starts there (%.2f)" % next.user_zoom)
	next.queue_free()
	Settings.set_v("cam_zoom", 9.0, false)
	ok(is_equal_approx(CamWheel.saved(), float(r["max"])), "match: a saved zoom past the range is clamped (%.2f)"
			% CamWheel.saved())
	Settings.set_v("cam_zoom", float(r["max"]), false)
	# Ctrl: past the max, then back
	var P: Hunter = m.player
	Input.action_press("crouch")
	m.set_process(true)
	for i in 120: await tree.process_frame
	m.set_process(false)
	var wide := m.cam.zoom
	var floor_z := float(r["max"]) * float(w["ctrl_floor"])
	ok(P.crouch and m.cam.zoom_to >= floor_z - 0.001, "match: sneaking aims past the max (%.2f)" % m.cam.zoom_to)
	var top := float(r["max"])
	ok(wide > top, "match: Ctrl widens the view past the max (camera %.2f > %.2f)" % [wide, top])
	Input.action_release("crouch")
	m.set_process(true)
	for i in 240: await tree.process_frame
	m.set_process(false)
	var back := m.cam.zoom < wide - 0.05 and absf(m.cam.zoom - float(r["max"])) < 0.1
	ok(back, "match: it eases back on release (%.2f)" % m.cam.zoom)
	# a wheel the player bound to an action is theirs
	var was := m.cam.user_zoom
	var bind := InputEventMouseButton.new()
	bind.button_index = MOUSE_BUTTON_WHEEL_UP
	InputMap.action_add_event("emote", bind)
	var zoomed := CamWheel.input(m, _wheel(MOUSE_BUTTON_WHEEL_UP))
	ok(not zoomed and m.cam.user_zoom == was, "match: a wheel bound to an action stays theirs")
	InputMap.action_erase_event("emote", bind)
	Settings.set_v("cam_zoom", 1.0, false)      # (a later check starts from the default)
	m.queue_free()
	await tree.process_frame
