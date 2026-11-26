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
const MAX_STEP := 0.05  # a camera frame may change the zoom by at most this much (x)

var bad := 0
var m: Match
var p: Hunter
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
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true})
	p = m.player
	m.set_process(false)
	var r: Dictionary = CamWheel.rules(true)
	var lo := float(r["min"])
	var hi := float(r["max"])
	_spawn(hi)
	_wheel_range(lo, hi, float(r["step"]))
	_ctrl(hi)
	_cap()
	_arm(lo, hi, float(r["step"]))
	_reach(hi)
	m.queue_free()
	print("CAM ZOOM CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _spawn(hi: float) -> void:
	ok(is_equal_approx(m.cam.user_zoom, hi), "a match starts at the widest view (%.2f)" % m.cam.user_zoom)
	var across := CamRig.style_across("default") * m.cam.user_zoom
	var src: Array = CamRig.rules["source"]["across_m"]
	ok(across >= float(src[0]) and across <= float(src[1]), "%.1f m across, the source's %s" % [across, src])
	m.cam.user_zoom = 0.7
	m._start_drop(p, p.pos)
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
	var peak := CamWheel.ctrl_zoom(true)
	var cap := CamWheel.cap()
	ok(peak > hi and peak < cap, "Ctrl reaches %.2f: past max %.2f, under the cap %.2f" % [peak, hi, cap])
	for wheel in [m.cam.user_zoom, hi]:
		m.cam.user_zoom = wheel
		p.grounded = true
		p.gliding = false
		p.crouch = true
		var asked: float = m.cam.air_zoom(p, 0.0)
		ok(is_equal_approx(asked, peak), "holding Ctrl asks for %.2f, wheel at %.2f" % [asked, wheel])
	p.crouch = false
	ok(is_equal_approx(m.cam.air_zoom(p, 0.0), hi), "released, it asks for the wheel's %.2f again" % hi)
	m.cam.zoom = hi
	var worst := 0.0
	for held in [true, false]:
		p.crouch = held
		for i in EASE_FRAMES:
			m.cam.zoom_to = m.cam.air_zoom(p, 0.0)
			var was := m.cam.zoom
			m.cam.follow(Vector3.ZERO, DT, false)
			worst = maxf(worst, absf(m.cam.zoom - was))
		var want := peak if held else hi
		ok(absf(m.cam.zoom - want) < 0.02, "the view eases to %.2f (at %.3f)" % [want, m.cam.zoom])
	ok(worst < MAX_STEP, "in steps of at most %.3f x a frame (%.3f)" % [MAX_STEP, worst])
	p.crouch = false


func _cap() -> void:
	m.cam.user_zoom = CamWheel.far(true)
	p.grounded = false
	p.gliding = true
	var z: float = m.cam.air_zoom(p, 60.0)
	ok(z <= CamWheel.cap() + 0.0001, "gliding high up with the wheel at max stays under the cap (%.2f)" % z)
	p.gliding = false


## The data's arm: 20.2..30.2 m in four 2.5 m notches (34.2 m / 22.9 m of ground across), +5.81 m gliding, the abyss
## ramp from 3.5 m deep, and a critically damped spring of omega 10 on the arm length.
func _arm(lo: float, hi: float, step: float) -> void:
	var wide := CamRig.style_across("default")
	ok(
		absf(wide * hi - 34.17) < 0.1 and absf(wide * lo - 22.86) < 0.1,
		"%.1f m across at the widest, %.1f m at the closest (34.2 / 22.9)" % [wide * hi, wide * lo]
	)
	ok(absf(m.cam.dist * hi - 30.2) < 0.05, "the arm starts %.2f m back (the data's 30.2)" % (m.cam.dist * hi))
	ok(absf((hi - lo) / step - 4.0) < 0.01, "the wheel has four notches (%.2f)" % ((hi - lo) / step))
	var cam: CamRig = m.cam
	cam.user_zoom = hi
	p.grounded = false
	p.gliding = false
	p.lip_y = 0.0
	p.pos.y = 0.0
	var still: float = cam.air_zoom(p, 0.0)
	p.gliding = true
	var glide_m: float = (cam.air_zoom(p, 0.0) - still) * cam.dist
	p.gliding = false
	ok(absf(glide_m - 5.81) < 0.01, "the glider adds %.2f m to the arm (the data's 5.81 m)" % glide_m)
	var seen := []
	for deep in [3.0, 3.5, 6.75, 10.0, 14.0]:
		p.pos.y = -deep
		seen.append(snappedf((cam.air_zoom(p, 0.0) - still) * cam.dist, 0.01))
	ok(seen == [0.0, 0.5, 7.75, 15.0, 15.0], "the abyss adds %s m at 3 / 3.5 / 6.75 / 10 / 14 m deep" % [seen])
	p.pos.y = 0.0
	cam.zoom_omega = 10.0
	cam.zoom = hi
	cam.zoom_v = 0.0
	cam.zoom_to = hi + 0.5
	var at_half := 0.0
	var overshoot := 0.0
	for i in 120:
		cam.follow(Vector3.ZERO, DT, false)
		overshoot = maxf(overshoot, cam.zoom - cam.zoom_to)
		if i == 29:
			at_half = (cam.zoom - hi) / 0.5
	ok(overshoot < 0.0001, "the arm spring never overshoots (%.5f)" % overshoot)
	ok(absf(at_half - 0.96) < 0.01, "half a second in, the arm is %.0f%% there (omega 10: 96%%)" % [at_half * 100.0])
	cam.zoom_omega = 0.0
	cam.zoom = hi
	cam.zoom_to = hi


func _reach(_hi: float) -> void:
	var cam := m.cam
	cam.snap(Vector3.ZERO)
	cam.zoom = CamWheel.ctrl_zoom(true)
	cam._apply(Vector3.ZERO)
	var size := cam.get_viewport().get_visible_rect().size
	var far_m := 0.0
	var depth := 0.0
	for c in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), size]:
		var o := cam.project_ray_origin(c)
		var d := cam.project_ray_normal(c)
		if d.y >= -0.01:
			continue  # a corner above the horizon sees sky
		var hit := o + d * (-o.y / d.y)
		far_m = maxf(far_m, Vector2(hit.x, hit.z).length())
		depth = maxf(depth, o.distance_to(hit))
	var pose_m := CamRig.pose_far_m
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
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1500.0, "seed": 4242, "no_drop": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)  # (the screen fade from start-up still covers the view)
	Settings.set_v("tips", false)
	for h in m.hunters:
		if h != m.player:
			h.ctrl = "idle"
	var tree := main.get_tree()
	var vp := main.get_viewport()
	vp.warp_mouse(vp.get_visible_rect().size * 0.5)
	m.cam.user_zoom = 1.0  # the view before this change: the style's own distance
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
