extends RefCounted
## --cam-zoom-check: the match camera starts at its widest, the wheel zooms in and out, and Ctrl reaches past it.
##   1. spawn and respawn (Match._start_drop) put the view at the wheel's far end, content/rules/camera.json "zoom" max,
##      which shows the source's ground across (35-39 m);
##   2. wheel up steps in to min and stops, wheel down steps back out to max and stops; no wheel while paused;
##   3. Ctrl (sneak, on the ground) asks for max x ctrl wherever the wheel was left, past max and under the cap, and
##      lets go on release; the camera eases there in small steps (no pop);
##   4. the glider and height never push the view past the cap;
##   5. at the Ctrl view every ground corner is inside the pose LOD's pose_far_m and the camera's far plane.
## Prints "CAMZOOM ok|FAIL <what>" and "CAM ZOOM CHECK DONE, failures: N".
## --cam-zoom-shots --shots-dir=<dir> (GPU): the old view, the new start, the wheel in and Ctrl held, one PNG each, with
## the frame's draw calls and objects printed ("CAMZOOM shot ...").

const DT := 1.0 / 60.0
const EASE_FRAMES := 240
const MAX_STEP := 0.05          # a camera frame may change the zoom by at most this much (x)

var bad := 0
var m: Match
var P: Hunter
var shot_dir := "user://shots"


func ok(cond: bool, what: String) -> void:
	print("CAMZOOM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node, what: String) -> void:
	if what == "shots":
		await _shots(main)
		return
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true})
	P = m.player
	m.set_process(false)
	var r: Dictionary = CamWheel.rules()
	var lo := float(r["min"])
	var hi := float(r["max"])
	_spawn(hi)
	_wheel_range(lo, hi, float(r["step"]))
	_ctrl(hi)
	_cap()
	_reach(hi)
	m.queue_free()
	print("CAM ZOOM CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _spawn(hi: float) -> void:
	ok(is_equal_approx(m.cam.user_zoom, hi), "a match starts at the widest view (%.2f)" % m.cam.user_zoom)
	var across := CamRig.style_across("default") * m.cam.user_zoom
	var src: Array = CamRig.RULES["source"]["across_m"]
	ok(across >= float(src[0]) and across <= float(src[1]), "%.1f m across, the source's %s" % [across, src])
	m.cam.user_zoom = 0.7
	m._start_drop(P, P.pos)
	ok(is_equal_approx(m.cam.user_zoom, hi), "a respawn puts the wheel back at the widest (%.2f)" % m.cam.user_zoom)


func _wheel_range(lo: float, hi: float, step: float) -> void:
	_notch(MOUSE_BUTTON_WHEEL_UP)
	var stepped: float = m.cam.user_zoom
	ok(is_equal_approx(stepped, hi - step), "wheel up steps in by %.2f (%.2f)" % [step, stepped])
	_notch(MOUSE_BUTTON_WHEEL_DOWN)
	ok(is_equal_approx(m.cam.user_zoom, hi), "wheel down steps back out (%.2f)" % m.cam.user_zoom)
	_notch(MOUSE_BUTTON_WHEEL_DOWN)
	ok(is_equal_approx(m.cam.user_zoom, hi), "and stops at the widest")
	for i in 40:
		_notch(MOUSE_BUTTON_WHEEL_UP)
	ok(is_equal_approx(m.cam.user_zoom, lo), "wheel up stops at the closest (%.2f)" % m.cam.user_zoom)
	m.paused = true
	_notch(MOUSE_BUTTON_WHEEL_DOWN)
	ok(is_equal_approx(m.cam.user_zoom, lo), "no wheel zoom while paused")
	m.paused = false


func _ctrl(hi: float) -> void:
	var peak := CamWheel.ctrl_zoom()
	var cap := CamWheel.cap()
	ok(peak > hi and peak < cap, "Ctrl reaches %.2f: past max %.2f, under the cap %.2f" % [peak, hi, cap])
	for wheel in [m.cam.user_zoom, hi]:
		m.cam.user_zoom = wheel
		P.grounded = true
		P.gliding = false
		P.crouch = true
		var asked: float = m.cam.air_zoom(P, 0.0)
		ok(is_equal_approx(asked, peak), "holding Ctrl asks for %.2f, wheel at %.2f" % [asked, wheel])
	P.crouch = false
	ok(is_equal_approx(m.cam.air_zoom(P, 0.0), hi), "released, it asks for the wheel's %.2f again" % hi)
	m.cam.zoom = hi
	var worst := 0.0
	for held in [true, false]:
		P.crouch = held
		for i in EASE_FRAMES:
			m.cam.zoom_to = m.cam.air_zoom(P, 0.0)
			var was := m.cam.zoom
			m.cam.follow(Vector3.ZERO, DT, false)
			worst = maxf(worst, absf(m.cam.zoom - was))
		var want := peak if held else hi
		ok(absf(m.cam.zoom - want) < 0.02, "the view eases to %.2f (at %.3f)" % [want, m.cam.zoom])
	ok(worst < MAX_STEP, "in steps of at most %.3f x a frame (%.3f)" % [MAX_STEP, worst])
	P.crouch = false


func _cap() -> void:
	m.cam.user_zoom = CamWheel.far()
	P.grounded = false
	P.gliding = true
	var z: float = m.cam.air_zoom(P, 60.0)
	ok(z <= CamWheel.cap() + 0.0001, "gliding high up with the wheel at max stays under the cap (%.2f)" % z)
	P.gliding = false


func _reach(hi: float) -> void:
	var cam := m.cam
	cam.snap(Vector3.ZERO)
	cam.zoom = CamWheel.ctrl_zoom()
	cam._apply(Vector3.ZERO)
	var size := cam.get_viewport().get_visible_rect().size
	var far_m := 0.0
	var depth := 0.0
	for c in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), size]:
		var o := cam.project_ray_origin(c)
		var d := cam.project_ray_normal(c)
		if d.y >= -0.01:
			continue     # a corner above the horizon sees sky
		var hit := o + d * (-o.y / d.y)
		far_m = maxf(far_m, Vector2(hit.x, hit.z).length())
		depth = maxf(depth, o.distance_to(hit))
	var pose_m := CamRig.POSE_FAR_M
	ok(far_m <= pose_m, "Ctrl view: the furthest corner is %.1f m out, inside pose_far_m %.0f" % [far_m, pose_m])
	ok(depth < cam.far, "and %.0f m from the camera, inside its far plane %.0f" % [depth, cam.far])


func _notch(button: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	m._unhandled_input(ev)


func _shots(main: Node) -> void:
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shot_dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(shot_dir)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1500.0, "seed": 4242, "no_drop": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)      # (the screen fade from start-up still covers the view)
	Settings.set_v("tips", false)
	for h in m.hunters:
		if h != m.player:
			h.ctrl = "idle"
	var tree := main.get_tree()
	var vp := main.get_viewport()
	vp.warp_mouse(vp.get_visible_rect().size * 0.5)
	m.cam.user_zoom = 1.0      # the view before this change: the style's own distance
	await _shot(tree, "before_old_view")
	m._start_drop(m.player, m.player.pos)
	await _shot(tree, "after_start")
	for i in 3:
		_notch(MOUSE_BUTTON_WHEEL_UP)
	await _shot(tree, "after_wheel_in_3")
	Input.action_press("crouch")
	await _shot(tree, "after_ctrl_held")
	Input.action_release("crouch")
	tree.quit(0)


func _shot(tree: SceneTree, name: String) -> void:
	for i in 120:
		await tree.process_frame
	var img := tree.root.get_viewport().get_texture().get_image()
	img.save_png(shot_dir.path_join(name + ".png"))
	var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objs := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	print("CAMZOOM shot %s: zoom %.2f, %d draw calls, %d objects" % [name, m.cam.zoom, calls, objs])
