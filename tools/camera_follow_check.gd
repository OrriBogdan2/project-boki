extends RefCounted
## --camera-follow-check: how far the camera trails you, frame by frame, through each kind of dash, and how
## long it takes to catch up (docs/MOVEMENT_FEEL.md, "Camera"; the follow is CamRig.follow, its numbers in
## content/rules/camera.json "trail").
## - The source curve: a 4.6 m dash in 0.12 s fed straight to the follow must pan at about 700 px/s and catch
##   up in about 0.5 s, as briefs/hero-ref/dredge.md measured Grimble's Brute Dash (50 px = 1 m there).
## - In play: Vex's tap dash and held slide, Sparkle's Wirerun (40 m/s), Grimble's barges, Motley's Lantern
##   Trade (the source cuts to the landing: ostra.md) and a glide start. Each dash must catch up inside its
##   window, no frame may leave you more than the follow's max_gap behind, and the cursor must still aim at
##   the ground under it while the camera trails.
## It drives the real frame path (Match._process: the sim step, the render lead, the camera, the aim).
## --camera-follow-shots --shots-dir=<dir>: Grimble's barge as a strip of centre crops, on a GPU.
##
## Prints "CAMLAG <case> <gap m every 2nd frame...>" and "CAMFOLLOW <case> peak <m> catch <s> ok|FAIL" per
## case and "CAMERA FOLLOW CHECK DONE, failures: N" at the end.

const DT := 1.0 / 60.0
const SETTLE := 30             # frames the follow gets on a standing hunter before a case
const PAN_STOP := 1.0          # m/s (50 px/s, the sheets' measuring floor): under it the pan has stopped, caught up
const CUT_M := 0.1             # m: a teleport leaves the view at most this far from you the same frame
const PX_PER_M := 50.0         # the hero sheets' ground scale at the source zoom (linwick.md)
const SRC_DASH := [4.6, 0.12]  # m, s: Grimble's Brute Dash in the footage (dredge.md 4)
const SRC_PAN := [630.0, 770.0]   # px/s: the pan's peak, 700 ±10%
const SRC_CATCH := [0.4, 0.55]    # s from the dash's end: ~0.5 s (dredge.md 4), ~0.4 s for a blink (dredge.md 8)
const KEYS_AFTER := 3        # frames the move key stays down after a press or a release
const GLIDE_GAP := 0.4         # m: a glide start trails no more than a run (move_feel_check's cam_lag_m)
const AIM_TOL := 0.1           # m between the aim and the ground point under the cursor
const SHOT_EVERY := 3          # frames between the strip's crops
const SHOTS := 10              # crops in the strip
const CROP := Vector2i(480, 360)

var main: Node
var m: Match
var P: Hunter
var cam: CamRig
var mf: RefCounted             # move_feel_check: its flat-spot finder, hunter reset and glide perch, reused
var flat := Vector3.ZERO
var bad := 0

func run(mn: Node, mode: String) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "map": "skyreach", "no_drop": true,
			"god": true, "tut_test": true})
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	cam = m.cam
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != P:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true
	if P.kin: (P.kin as Kin).stow()
	P.ctrl = "local"
	P.unlock_all()
	cam.lead = 0.0             # no cursor lean: the gap measured is the follow's alone
	mf = load("res://tools/move_feel_check.gd").new()
	mf.m = m
	mf.w = m.world
	mf.P = P
	flat = mf._flat_spot(10.0)
	m.acc = 0.0
	m.paused = false
	if mode == "shots":
		await _shots()
	else:
		m.set_process(false)
		_source_curve()
		for c in _cases():
			_case(c)
		print("CAMERA FOLLOW CHECK DONE, failures: ", bad)
	main.get_tree().quit()

## The follow alone against the source's dash: a straight 4.6 m in 0.12 s, then still.
func _source_curve() -> void:
	var from := flat
	cam.snap(from)
	var dist := float(SRC_DASH[0])
	var dur := float(SRC_DASH[1])
	var pan := 0.0
	var catch := -1.0
	var t := 0.0
	while t < 1.5 and catch < 0.0:
		t += DT
		var was := cam.base
		cam.follow(from + Vector3(dist * minf(1.0, t / dur), 0, 0), DT, false)
		var speed := (cam.base.x - was.x) / DT
		pan = maxf(pan, speed * PX_PER_M)
		if t > dur and speed < PAN_STOP:
			catch = t - dur
	_judge("source_dash", pan >= SRC_PAN[0] and pan <= SRC_PAN[1] and catch >= SRC_CATCH[0] and catch <= SRC_CATCH[1],
			"pan %.0f px/s (source ~700), catch %.2f s (source ~0.5)" % [pan, catch])

## Each case: the hero, frames measured, `drive` (frame -> sets the keys), `catch` [lo, hi] s from the dash's
## end to the pan stopping, `cut` (the view cuts to the Trade's landing) or `most` (m it may trail at all).
func _cases() -> Array:
	return [
		{"key": "vex_tap_dash", "arch": "gunslinger", "frames": 60, "drive": _press.bind([0]), "catch": [0.15, 0.55]},
		{"key": "vex_hold_slide", "arch": "gunslinger", "frames": 120, "drive": _hold.bind(50), "catch": [0.15, 0.55]},
		{"key": "sparkle_wirerun", "arch": "mage", "frames": 100, "drive": _hold.bind(40), "catch": [0.4, 0.55]},
		{"key": "grimble_barges", "arch": "dredge", "frames": 120, "drive": _press.bind([0, 24, 48]),
				"catch": [0.15, 0.55]},
		{"key": "motley_lob", "arch": "ostra", "frames": 150, "drive": _press.bind([0]), "cut": true},
		{"key": "glide_start", "arch": "gunslinger", "frames": 60, "drive": _glide, "glide": true, "most": GLIDE_GAP},
	]

## Shift tapped on these frames, the keys held only round each press, so you stand once the dash is done.
func _press(i: int, frames: Array) -> void:
	var near := false
	for f in frames:
		near = near or (i >= f and i < f + KEYS_AFTER)
	P.inp["move"] = Vector2(1, 0) if near else Vector2.ZERO
	P.inp["dash"] = i in frames
	P.inp["dash_down"] = i in frames

func _hold(i: int, n: int) -> void:
	P.inp["move"] = Vector2(1, 0) if i < n + KEYS_AFTER else Vector2.ZERO
	P.inp["dash"] = i < n
	P.inp["dash_down"] = i < n

func _glide(_i: int) -> void:
	P.inp["move"] = Vector2(1, 0)
	P.inp["glide"] = true

func _gap() -> float:
	return Vector2(cam.base.x - P.position.x, cam.base.z - P.position.z).length()

func _case(c: Dictionary) -> void:
	P.reclass(Arch.weight(String(c["arch"])), String(c["arch"]))
	if c.has("glide"):
		mf._glide_at(25.0)
		P.inp["jump"] = true
	else:
		mf._reset(flat + Vector3(-7.0, 0, 0))
	P.inp["aim"] = P.pos + Vector3(9.0, 0, 0)
	cam.snap(P.position)
	if not c.has("glide"):
		for i in SETTLE: m._process(DT)
	var drive: Callable = c["drive"]
	var gaps: Array = []
	var peak := 0.0
	var ended := -1            # the last frame your dash ended (you fell back to run speed or under)
	var stopped := -1          # the first frame after it the view's pan stopped: caught up
	var cut := false
	var aim_err := -1.0
	var from := P.position
	var last := P.position
	var view := cam.base
	var run_step := P.base_speed * DT * 1.05
	var was_fast := false
	for i in int(c["frames"]):
		drive.call(i)
		m._process(DT)
		var g := _gap()
		gaps.append(g)
		if g > peak:
			peak = g
			if aim_err < 0.0 and g > 1.0:
				aim_err = _aim_err()
		var step := Vector2(P.position.x - last.x, P.position.z - last.z).length()
		var fast := step > run_step and step <= 2.0
		if step > 2.0 and g <= CUT_M:
			cut = true
		elif was_fast and not fast:
			ended = i
			stopped = -1
		was_fast = fast
		if ended >= 0 and stopped < 0 and Vector2(cam.base.x - view.x, cam.base.z - view.z).length() < PAN_STOP * DT:
			stopped = i
		last = P.position
		view = cam.base
	var catch := (stopped - ended) * DT if ended >= 0 and stopped >= 0 else 9.0
	var row := PackedStringArray()
	for i in range(0, gaps.size(), 2): row.append("%.2f" % gaps[i])
	print("CAMLAG %s %s" % [c["key"], " ".join(row)])
	var okk := peak <= _max_gap() + 0.05 and (aim_err < 0.0 or aim_err <= AIM_TOL)
	if c.has("catch"):
		okk = okk and catch >= c["catch"][0] and catch <= c["catch"][1]
	if c.has("cut"):
		okk = okk and cut
	if c.has("most"):
		okk = okk and peak <= float(c["most"])
	var moved := Vector2(P.position.x - from.x, P.position.z - from.z).length()
	var aimed := ", aim off %.3f m" % aim_err if aim_err >= 0.0 else ""
	_judge(String(c["key"]), okk, "moved %.1f m, peak %.2f m, catch %.2f s%s%s" % [moved, peak, catch,
			", cut" if cut else "", aimed])
	P.inp["glide"] = false
	P.inp["jump"] = false

func _max_gap() -> float:
	return CamRig.max_gap

## With the view trailing: the cursor over a ground point beside you must aim at that point.
func _aim_err() -> float:
	var spot := P.pos + Vector3(2.5, 0, 2.0)
	spot.y = m.world.ground_at(spot.x, spot.z) + 0.95
	var ev := InputEventMouseMotion.new()
	ev.position = cam.unproject_position(spot)
	ev.global_position = main.get_viewport().get_screen_transform() * ev.position     # (window pixels)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	var aim: Vector3 = m._mouse_aim()
	return Vector2(aim.x - spot.x, aim.z - spot.z).length()

func _judge(key: String, okk: bool, what: String) -> void:
	print("CAMFOLLOW %-16s %s  %s" % [key, what, "ok" if okk else "FAIL"])
	if not okk: bad += 1

## Grimble's barges on a real screen: centre crops every SHOT_EVERY frames from the first press.
func _shots() -> void:
	var dir := "user://camera_follow_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	P.reclass(Arch.weight("dredge"), "dredge")
	mf._reset(flat + Vector3(-7.0, 0, 0))
	P.inp["aim"] = P.pos + Vector3(9.0, 0, 0)
	cam.snap(P.pos)
	for i in SETTLE: await main.get_tree().process_frame
	var strip := Image.create(CROP.x * SHOTS, CROP.y, false, Image.FORMAT_RGB8)
	for i in SHOT_EVERY * SHOTS:
		_press(i, [0, 24])
		await main.get_tree().process_frame
		if i % SHOT_EVERY != 0:
			continue
		var img := main.get_viewport().get_texture().get_image()
		var at := Vector2i(img.get_size() / 2) - CROP / 2
		var n := i / SHOT_EVERY
		strip.blit_rect(img.get_region(Rect2i(at, CROP)), Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * n, 0))
		for y in CROP.y:
			strip.set_pixel(CROP.x * n + CROP.x / 2, y, Color.WHITE)     # the screen's centre line
	strip.save_png(dir.path_join("camera_follow_barges.png"))
	print("CAMFOLLOW SHOTS DONE")
