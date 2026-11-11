extends RefCounted
## --aim-latency-check: a scripted mouse move, then how many rendered frames until the reticle and the
## aim point (inp["aim"], what the aim line, the kit cursors and the shot read) sit under the cursor.
## It drives Match._process (the end-to-end path: input flush, _gather_input, camera, draw) one call per
## frame at the case's refresh rate, at 720p and at 4K with a user UI scale, so the content scale sits on
## the path too. Allowed lag: one physics tick (Match.DT, 60 Hz): 1 frame at 60 Hz, 2 frames at 144 Hz.
## The findings are in docs/MOVEMENT_FEEL.md ("Aim: the raw cursor"). It never touches the save.
##
## Prints "AIMLAG <case> <key> = <value>  allow <= N  ok|FAIL" per measure and
## "AIM LATENCY CHECK DONE, failures: N" at the end.

var bad := 0
var m: Match
var P: Hunter
var root: Window
const TOL_PX := 0.5          # px: an aim point this close to where the cursor projects counts as under it
const SETTLE_FRAMES := 90    # frames with the mouse still before a move, so the camera is at rest
const STATIC_PX := 40.0      # px (canvas): a move that stays inside the camera's cursor dead zone (CamRig.FOLLOW)
const PAN_PX := 400.0        # px (canvas): a move that makes the view lean after the cursor
const WATCH := 6             # frames measured after a move
## [case, refresh rate Hz, window px, the user's UI scale (Settings ui_scale)]
const CASES := [
	["60hz_720p", 60, Vector2i(1280, 720), 1.0],
	["144hz_720p", 144, Vector2i(1280, 720), 1.0],
	["60hz_4k_ui1.5", 60, Vector2i(3840, 2160), 1.5],
	["144hz_4k_ui1.5", 144, Vector2i(3840, 2160), 1.5],
]

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	root = main.get_tree().root
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != P:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true
	if P.kin: (P.kin as Kin).stow()
	P.ctrl = "local"
	P.teleport(m.world.spawns[0])
	P.vel = Vector3.ZERO
	m.paused = false
	for c in CASES:
		_case(String(c[0]), int(c[1]), c[2], float(c[3]))
	print("AIM LATENCY CHECK DONE, failures: ", bad)
	main.get_tree().quit()

func _case(label: String, hz: int, win: Vector2i, ui: float) -> void:
	root.size = win
	Settings.v["ui_scale"] = ui
	Settings.apply("ui_scale")
	var cs := root.content_scale_factor
	var dt := 1.0 / hz
	var allow := int(floor(hz / 60.0))        # frames in one physics tick
	var centre := Vector2(win) * 0.5 / cs      # canvas px
	print("AIMLAG %s window %s content scale %.3f canvas %s" % [label, str(win), cs, str(root.get_visible_rect().size)])
	_mouse(centre, cs)
	for i in SETTLE_FRAMES: m._process(dt)
	# a small move: the view stays put, so this is the cursor-to-aim path alone
	var r := _watch(centre + Vector2(STATIC_PX, 0), cs, dt)
	_rec(label, "reticle_frames", r["reticle"], allow)
	_rec(label, "aim_frames", r["aim"], allow)
	for i in SETTLE_FRAMES: m._process(dt)
	# a big move: the camera leans after the cursor for a while; the aim must keep up with the view
	r = _watch(centre + Vector2(PAN_PX, 0), cs, dt)
	_rec(label, "aim_frames_panning", r["stale"], allow)
	print("AIMLAG %s aim_vs_cursor_px_panning = %.2f px on the move's frame" % [label, r["gap0"]])
	_mouse(centre, cs)
	for i in SETTLE_FRAMES: m._process(dt)

## Moves the mouse to `to` (canvas px) the way the OS does: an event, flushed before the frame reads it.
func _mouse(to: Vector2, cs: float) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = to * cs
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

## Moves the mouse, then steps WATCH frames: {reticle: first frame the HUD's crosshair draws under the cursor,
## aim: first frame the aim point projects onto the cursor through the camera as drawn that frame,
## stale: the most frames the aim point lagged the camera over the watch (0 none, 1 read before the
## camera moved that frame, 99 older), gap0: px between the aim point and the cursor on the move's own frame}.
func _watch(to: Vector2, cs: float, dt: float) -> Dictionary:
	_mouse(to, cs)
	var out := {"reticle": 99, "aim": 99, "stale": 0, "gap0": 0.0}
	for k in WATCH:
		var before: Transform3D = m.cam.global_transform
		m._process(dt)
		var mouse := root.get_mouse_position()
		if out["reticle"] == 99 and m.hud.c.get_local_mouse_position().distance_to(mouse) <= TOL_PX:
			out["reticle"] = k
		var gap_now := _gap(m.cam.global_transform)
		var gap_prev := _gap(before)
		if k == 0:
			out["gap0"] = m.cam.unproject_position(P.inp["aim"]).distance_to(mouse)
		if out["aim"] == 99 and gap_now <= TOL_PX:
			out["aim"] = k
		var stale := 99
		if gap_now <= TOL_PX:
			stale = 0
		elif gap_prev <= TOL_PX:
			stale = 1
		out["stale"] = maxi(int(out["stale"]), stale)
	return out

## px between the aim point and where Match._mouse_aim puts the cursor's aim (a foe's plane, or the first ground
## the cursor ray meets: AimMode.ray_ground), seen through the camera at `cam_tf`.
func _gap(cam_tf: Transform3D) -> float:
	var now: Transform3D = m.cam.global_transform
	var aim_y_was: float = m.aim_y
	m.cam.global_transform = cam_tf
	var want: Vector3 = m._mouse_aim(root.get_mouse_position())
	var aim: Vector3 = P.inp["aim"]
	var gap := m.cam.unproject_position(want).distance_to(m.cam.unproject_position(aim))
	m.cam.global_transform = now
	m.aim_y = aim_y_was
	return gap

func _rec(case_name: String, key: String, frames: int, allow: int) -> void:
	var ok := frames <= allow
	print("AIMLAG %-16s %-26s = %2d frames  allow <= %d  %s" % [case_name, key, frames, allow, "ok" if ok else "FAIL"])
	if not ok: bad += 1
