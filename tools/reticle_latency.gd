extends RefCounted
## --reticle-latency: how many frames the drawn reticle and the aim point trail the cursor.
## A live match (nothing else moving) gets one scripted mouse sample per frame, taken before the match's
## own _process, going round a circle at a fixed step per frame. After each frame is drawn the tool finds the
## reticle's dot in the rendered image and projects the player's aim with the camera that was drawn, then
## converts both to frames behind the cursor from their angle on the circle. 0 means same-frame.
##   godot -- --reticle-latency [--frames=300] [--step=20 (px per frame)] [--shots-dir=<dir>] [--expect-max=<frames>]
## Runs the four cases (60 and 144 fps cap, vsync on and off) and prints "LATENCY" lines; with
## --expect-max it fails when either trails the cursor by more than that at the 95th percentile.

const VIEW := Vector2i(960, 540)
const WARMUP := 90                  # frames before measuring (the camera settles, shaders compile)
const RADIUS := 100.0               # px: the circle the cursor goes round (clear of the bottom bar)
const DOT_COL := Color("ff5cd1")    # the reticle's colour for the run: nothing else on screen is this pink
const DOT_TOL := 0.12               # colour distance that still counts as the dot
const AIM_FAR := 60.0               # m: a point along the aim ray to project back onto the screen
const FIND_R := 90                  # px: where to look for the dot around the cursor sample

var main: Node
var m: Match
const CASES := [[60, true], [60, false], [144, true], [144, false]]    # [fps cap, vsync]
var fps := 60
var vsync := true
var bad := false
var frames := 300
var step_px := 20.0                 # px the cursor moves per frame: 1200 px/s at 60 fps
var expect_max := -1.0
var n := 0
var rig := Node.new()
var ret_lag := PackedFloat32Array()
var aim_lag := PackedFloat32Array()
var missed := 0
var shots_dir := ""

func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback

func _centre() -> Vector2:
	return Vector2(VIEW) * 0.5

func _angle_step() -> float:
	return step_px / RADIUS

## The cursor sample for frame i, in viewport pixels.
func _cursor_at(i: int) -> Vector2:
	return _centre() + Vector2.from_angle(float(i) * _angle_step()) * RADIUS

## How many frames behind the cursor of frame i a point on the circle's plane sits, by its angle.
func _frames_behind(i: int, p: Vector2) -> float:
	var d := wrapf((_cursor_at(i) - _centre()).angle() - (p - _centre()).angle(), -PI, PI)
	return d / _angle_step()

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Settings.reset_all()
	frames = int(_arg("--frames", "300"))
	step_px = float(_arg("--step", "20"))
	shots_dir = _arg("--shots-dir", "")
	expect_max = float(_arg("--expect-max", "-1"))
	main.get_window().size = VIEW
	Input.use_accumulated_input = false      # a sample reaches the match the moment it is parsed, as the OS flush does
	Settings.set_v("reticle_shape", "dot")
	Settings.set_v("reticle_size", 2.0)
	Settings.set_v("reticle_outline", false)
	Settings.set_v("reticle_alpha", 1.0)
	Settings.set_v("reticle_col", "pink")
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 6262, "no_drop": true, "training": true,
		"god": true}
	Game.goto("match", o)
	while not (main.current is Match and main.current.is_processing() and main.current.hud != null):
		await main.get_tree().process_frame
	m = main.current
	rig.process_priority = -1000
	rig.set_script(load("res://tools/reticle_latency_rig.gd"))
	rig.set("tool", self)
	main.add_child(rig)
	RenderingServer.frame_post_draw.connect(_after_draw)
	for c in CASES:
		fps = c[0]
		vsync = c[1]
		Engine.max_fps = fps
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		n = 0
		ret_lag.clear()
		aim_lag.clear()
		missed = 0
		while n < WARMUP + frames:
			await main.get_tree().process_frame
		_report()
	RenderingServer.frame_post_draw.disconnect(_after_draw)
	print("LATENCY %s" % ["FAIL" if bad else "PASS"])
	main.get_tree().quit(1 if bad else 0)

## Called by the rig first thing in each frame: this frame's cursor sample.
func sample() -> void:
	var p := _cursor_at(n)
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	Input.parse_input_event(ev)

func _after_draw() -> void:
	if n >= WARMUP and n < WARMUP + frames and m.player != null:
		var img := main.get_viewport().get_texture().get_image()
		var at := _find_dot(img, _cursor_at(n))
		if at.x >= 0.0:
			ret_lag.append(_frames_behind(n, at))
		else:
			missed += 1
			if missed == 1 and shots_dir != "":
				img.save_png("%s/miss_%d.png" % [shots_dir, n])
		# the aim ray the kit's ground-targeted moves use, as it lands on the screen drawn this frame
		var ray: Array = m.player.inp["aim_ray"]
		var far: Vector3 = ray[0] + ray[1] * AIM_FAR
		if not m.cam.is_position_behind(far):
			aim_lag.append(_frames_behind(n, m.cam.unproject_position(far)))
	n += 1

## The dot's centre: the mean of the dot-coloured pixels around `near`, or (-1, -1).
func _find_dot(img: Image, near: Vector2) -> Vector2:
	var sum := Vector2.ZERO
	var cnt := 0
	var x0 := maxi(0, int(near.x) - FIND_R)
	var y0 := maxi(0, int(near.y) - FIND_R)
	for y in range(y0, mini(img.get_height(), int(near.y) + FIND_R)):
		for x in range(x0, mini(img.get_width(), int(near.x) + FIND_R)):
			var c := img.get_pixel(x, y)
			if absf(c.r - DOT_COL.r) + absf(c.g - DOT_COL.g) + absf(c.b - DOT_COL.b) < DOT_TOL * 3.0:
				sum += Vector2(x + 0.5, y + 0.5)
				cnt += 1
	return sum / float(cnt) if cnt > 0 else Vector2(-1, -1)

func _stats(a: PackedFloat32Array) -> Array:
	if a.is_empty():
		return [NAN, NAN, 0]
	var s := Array(a)
	s.sort()
	var tot := 0.0
	for v in s:
		tot += v
	return [tot / s.size(), s[int(s.size() * 0.95)], s.size()]

func _report() -> void:
	var r := _stats(ret_lag)
	var a := _stats(aim_lag)
	var live := maxf(1.0, Engine.get_frames_per_second())
	var frame_ms := 1000.0 / live
	print("LATENCY cap=%d vsync=%s step=%.0fpx/frame measured_fps=%.1f dot_missed=%d" % [fps, "on" if vsync else "off",
		step_px, live, missed])
	print("LATENCY reticle  mean %.2f  p95 %.2f frames (%.1f ms)  n=%d" % [r[0], r[1], r[0] * frame_ms, r[2]])
	print("LATENCY aim      mean %.2f  p95 %.2f frames (%.1f ms)  n=%d" % [a[0], a[1], a[0] * frame_ms, a[2]])
	bad = bad or r[2] == 0 or a[2] == 0
	if expect_max >= 0.0:
		bad = bad or r[1] > expect_max or a[1] > expect_max
