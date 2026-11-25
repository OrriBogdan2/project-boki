extends RefCounted
## The match camera's framing against the source (docs/MOVEMENT_FEEL.md, "Camera framing vs the source").
## --cam-framing-check, on a 1920x1080 view:
##   1. the default style takes its numbers from content/rules/camera.json and sits inside the source's
##      bands there: pitch, lens, and your feet a little below the screen's centre
##   2. the source_scale test style (off by default) shows the source's ground across and scales Hunters; the
##      home keeps the default view under it
##   3. the cursor lean: none inside the deadzone, never past its cap, and at full lean every way (16
##      directions, at the sneak, normal and close zooms) you stay on screen, feet and head
##   3b. the default cursor pan (follow "pan", the target feel's data): the default setting, none inside the 0.1
##      deadzone, 5.5 m at the side edge, 7.25 m up and 7.75 m down at their zoom's room (an ellipse), never off
##      screen, and a critically damped spring that reaches it with no overshoot
##   4. the garden's Boki framing (HomeKinFrame): eased in 30% nearer over 0.3 s, you and the Boki on screen
##      at every wheel zoom up to its reach, and eased back when you walk off, it's too far or the card closes
## --cam-framing-shots (GPU, --shots-dir=<dir>): a live match at the default view, then the cursor held at
## the screen's top and bottom edge while sneaking (the widest grounded zoom), then the parity views (the match's
## own start zoom standing still with the cursor centred and at the right edge, and the glider's), one PNG each.

const VIEW := Vector2i(1920, 1080)
const HEAD := 2.0  # m: the top of a medium hunter's head above its feet
const ZOOMS := [0.6, 1.0, 1.45]  # a close-up, the usual view, sneaking (Match: 1.45 while crouched)
const HOME_ZOOMS := [0.55, 1.2, 1.6]  # the farm: the wheel's closest, a middle notch, the widest (arriving home)
const HOME_STYLE := "classic"  # the style the farm's framing is measured in (home.gd HOME_ACROSS_REF)
const SHOTS := [
	["framing_default", 1.0, Vector2(0.5, 0.5)],
	["framing_sneak_lean_up", 1.45, Vector2(0.5, 0.01)],
	["framing_sneak_lean_down", 1.45, Vector2(0.5, 0.99)],
	["parity_still_centre", NO_HOLD, Vector2(0.5, 0.5)],
	["parity_still_right", NO_HOLD, Vector2(0.99, 0.5)],
	["parity_glide_centre", GLIDING, Vector2(0.5, 0.5)],
]
const NO_HOLD := 0.0  # a shot's zoom: the match's own (the wheel's widest at the start)
const GLIDING := -1.0  # a shot's zoom: the view the glider asks for (CamRig.air_zoom), standing on the ground

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("CAMFRAME %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node, what: String) -> void:
	if what == "shots":
		await _shots(main)
		return
	var vp := SubViewport.new()
	vp.size = VIEW
	main.add_child(vp)
	var cam := CamRig.new()
	vp.add_child(cam)
	_style(cam)
	_source_style(cam)
	_lean(cam)
	_pan(cam)
	_garden(cam)
	vp.queue_free()
	print("CAMFRAME CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _style(cam: CamRig) -> void:
	var src: Dictionary = CamRig.rules["source"]
	var st: Dictionary = CamRig.rules["styles"]["default"]
	cam.use_style("default")
	ok(
		(
			is_equal_approx(rad_to_deg(cam.pitch), float(st["pitch"]))
			and is_equal_approx(cam.dist, float(st["dist"]))
			and is_equal_approx(cam.lens, float(st["fov"]))
			and is_equal_approx(cam.rise, float(st["rise"]))
		),
		"the default style is camera.json's: %s" % str(st)
	)
	var pitch := rad_to_deg(cam.pitch)
	ok(_inside(pitch, src["pitch_deg"]), "pitch %.1f deg inside the source's %s" % [pitch, str(src["pitch_deg"])])
	ok(_inside(cam.lens, src["fov_deg"]), "lens %.1f deg inside the source's %s" % [cam.lens, str(src["fov_deg"])])
	cam.snap(Vector3.ZERO)
	var feet := (cam.unproject_position(Vector3.ZERO).y - VIEW.y * 0.5) / VIEW.y * 100.0
	ok(
		_inside(feet, src["feet_below_pct"]),
		"feet %.2f%% of the height below the centre, inside the source's %s" % [feet, str(src["feet_below_pct"])]
	)


func _lean(cam: CamRig) -> void:
	var fm: Array = CamRig.follow_v["lean"]
	var deadzone := float(fm[0])
	ok(cam.lean_to(Vector3(deadzone * 0.9, 0, 0)) == Vector3.ZERO, "no lean inside the %.1f m deadzone" % deadzone)
	for z in ZOOMS:
		cam.zoom = z
		var worst := 1e9
		var over_cap := 0.0
		for i in 16:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
			var p := cam.lean_to(dir * 200.0)
			over_cap = maxf(over_cap, p.length() - float(fm[2]) * maxf(1.0, z) * cam.lead)
			cam.snap(p)  # (the view's centre at the lean, you at the origin)
			for at in [Vector3.ZERO, Vector3(0, HEAD, 0)]:
				var s := cam.unproject_position(at)
				worst = minf(worst, minf(minf(s.x, VIEW.x - s.x), minf(s.y, VIEW.y - s.y)))
		ok(over_cap <= 0.001, "zoom %.2f: the lean stays within its %.1f m cap" % [z, float(fm[2]) * maxf(1.0, z)])
		ok(
			worst >= 20.0,
			"zoom %.2f: at full lean every way you stay on screen (%.0f px to the nearest edge)" % [z, worst]
		)
	cam.zoom = 1.0


func _pan(cam: CamRig) -> void:
	ok(Settings.DEFAULTS["cam_follow"] == "pan" and CamRig.follow_v.has("pan"), "the cursor pan is the default follow")
	cam.use_style("default")
	cam.follow_mode = "pan"
	cam.snap(Vector3.ZERO)
	cam.zoom = 1.0
	var mid := Vector2(VIEW) * 0.5
	var inside := cam.cursor_pan(mid + Vector2(VIEW.x * 0.04, 0.0), Vector3.ZERO)
	ok(inside == Vector3.ZERO, "pan: nothing inside the deadzone")
	var side := cam.cursor_pan(Vector2(VIEW.x, mid.y), Vector3.ZERO)
	ok(absf(side.x - 5.5) < 0.01 and absf(side.z) < 0.01, "pan: 5.5 m at the right edge (%.2f)" % side.x)
	cam.zoom = 1.457
	var up := cam.cursor_pan(Vector2(mid.x, 0.0), Vector3.ZERO)
	var down := cam.cursor_pan(Vector2(mid.x, VIEW.y), Vector3.ZERO)
	ok(up.z < -6.0 and up.z >= -7.251, "pan: %.2f m up at the top edge (7.25 at most, the screen's room)" % -up.z)
	ok(down.z > 6.5 and down.z <= 7.75 + 0.001, "pan: %.2f m down at the bottom edge (7.75 at most)" % down.z)
	for z in ZOOMS:
		cam.zoom = z
		var worst := 1e9
		for i in 16:
			var at := mid + Vector2.from_angle(TAU * i / 16.0) * mid * 1.2
			cam.snap(cam.cursor_pan(at, Vector3.ZERO))
			for pt in [Vector3.ZERO, Vector3(0, HEAD, 0)]:
				var sp := cam.unproject_position(pt)
				worst = minf(worst, minf(minf(sp.x, VIEW.x - sp.x), minf(sp.y, VIEW.y - sp.y)))
		ok(worst >= 20.0, "pan: zoom %.2f, the cursor in every direction keeps you on screen (%.0f px)" % [z, worst])
	cam.zoom = 1.0
	cam.snap(Vector3.ZERO)
	var want := cam.cursor_pan(cam.get_viewport().get_mouse_position(), Vector3.ZERO)  # (the viewport's own cursor)
	var overshoot := 0.0
	for i in 60:  # 0.5 s of follow(): a critical spring of omega 27.7 is within 1e-4 of the target
		cam.follow(Vector3.ZERO, 1.0 / 60.0)
		overshoot = maxf(overshoot, (cam.pan - want).dot(want.normalized()))
	ok(
		want.length() > 1.0 and overshoot < 0.0001 and (cam.pan - want).length() < 0.01,
		"pan: follow() settles on the %.1f m lean with no overshoot (%.4f)" % [want.length(), overshoot]
	)
	cam.pan = Vector3.ZERO
	cam.pan_v = Vector3.ZERO
	cam.follow_mode = "centred"


func _source_style(cam: CamRig) -> void:
	var src: Dictionary = CamRig.rules["source"]
	ok(
		Settings.DEFAULTS["cam_style"] != "source_scale",
		"source_scale is off by default (the Settings camera is %s)" % Settings.DEFAULTS["cam_style"]
	)
	cam.use_style("source_scale")
	var across := CamRig.style_across("source_scale")
	ok(
		_inside(across, src["across_m"]),
		"source_scale shows %.1f m across, inside the source's %s" % [across, str(src["across_m"])]
	)
	ok(cam.hunter_scale > 1.5, "source_scale draws Hunters %.2fx bigger" % cam.hunter_scale)
	var was = Settings.get_v("cam_style")
	Settings.set_v("cam_style", "source_scale", false)
	cam.apply_settings()
	ok(
		cam.style_id == "default" and is_equal_approx(cam.hunter_scale, 1.0),
		"the home keeps the default view under source_scale"
	)
	Settings.set_v("cam_style", was, false)
	cam.use_style("default")


func _garden(cam: CamRig) -> void:
	cam.use_style(HOME_STYLE)
	var node := Node3D.new()
	var boki := {"pos": Vector3(1.2, 0, 0.6), "node": node}
	var fr := HomeKinFrame.new()
	fr.start(boki, Vector3.ZERO)
	_run(fr, 0.15, Vector3.ZERO, false)
	var half := fr.amt
	_run(fr, 0.15, Vector3.ZERO, false)
	ok(
		half > 0.4 and half < 0.6 and is_equal_approx(fr.closer(), 1.0 - HomeKinFrame.CLOSER),
		(
			"garden: eases in over %.2f s to %.0f%% nearer (%.2f at half time)"
			% [HomeKinFrame.EASE_S, HomeKinFrame.CLOSER * 100.0, half]
		)
	)
	for z in HOME_ZOOMS:
		var worst := 1e9
		for i in 16:
			boki["pos"] = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0) * HomeKinFrame.REACH * z
			worst = minf(worst, _pair_margin(cam, fr, z))
		ok(
			worst >= 20.0,
			(
				"garden zoom %.2f: you and a Boki %.1f m away, framed every way, both on screen (%.0f px)"
				% [z, HomeKinFrame.REACH * z, worst]
			)
		)
	boki["pos"] = Vector3(1.2, 0, 0.6)
	_run(fr, 0.3, Vector3(HomeKinFrame.WALK_OFF_M + 0.5, 0, 0), false)
	ok(fr.amt == 0.0, "garden: walking off eases back to the usual view within %.2f s" % HomeKinFrame.EASE_S)
	fr.start(boki, Vector3.ZERO, true)
	_run(fr, 0.3, Vector3.ZERO, true)
	var held := fr.amt
	_run(fr, 0.3, Vector3.ZERO, false)
	ok(held == 1.0 and fr.amt == 0.0, "garden: framed while its card is open, eased back once it closes")
	boki["pos"] = Vector3(HomeKinFrame.REACH * 1.2 + 1.0, 0, 0)
	fr.start(boki, Vector3.ZERO)
	_run(fr, 0.05, Vector3.ZERO, false)
	ok(fr.amt == 0.0, "garden: a Boki too far to frame with you doesn't move the view")
	node.free()
	cam.dist_mul = 1.0
	cam.zoom = 1.0


## Ticks the frame for `secs` at 60 Hz, you standing at `you`.
func _run(fr: HomeKinFrame, secs: float, you: Vector3, card_open: bool) -> void:
	for i in roundi(secs * 60.0):
		fr.tick(1.0 / 60.0, you, card_open, 1.2)


## Pixels from the nearest screen edge to you or the Boki (feet and head), fully framed at zoom `z`.
func _pair_margin(cam: CamRig, fr: HomeKinFrame, z: float) -> float:
	fr.tick(0.0, Vector3.ZERO, false, z)
	cam.zoom = z
	cam.dist_mul = fr.closer()
	cam.snap(fr.frame(Vector3.ZERO))
	var worst := 1e9
	for at in [Vector3.ZERO, Vector3(0, HEAD, 0), fr.at, fr.at + Vector3(0, HEAD * 0.5, 0)]:
		var s := cam.unproject_position(at)
		worst = minf(worst, minf(minf(s.x, VIEW.x - s.x), minf(s.y, VIEW.y - s.y)))
	return worst


func _inside(v: float, band: Array) -> bool:
	return v >= float(band[0]) - 0.001 and v <= float(band[1]) + 0.001


func _shots(main: Node) -> void:
	Save.no_write = true
	var dir := "user://shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1500.0, "seed": 4242, "no_drop": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)  # (the screen fade from start-up still covers the view)
	Settings.set_v("tips", false)
	for h in m.hunters:
		if h != m.player:
			h.ctrl = "idle"
	main.get_window().size = VIEW  # (the shots are 1920x1080 whatever window the host opens)
	await main.get_tree().process_frame
	var vp := main.get_viewport()
	for sh in SHOTS:
		var hold := float(sh[1])
		if hold == GLIDING:
			m.player.gliding = true
			hold = m.cam.air_zoom(m.player, 0.0)
			m.player.gliding = false
		if hold == NO_HOLD:
			m.remove_meta("zoom_hold")
		else:
			m.set_meta("zoom_hold", hold)
		for i in 90:
			vp.warp_mouse(vp.get_visible_rect().size * Vector2(sh[2]))
			await main.get_tree().process_frame
		vp.get_texture().get_image().save_png(dir.path_join(String(sh[0]) + ".png"))
		var s := m.cam.unproject_position(m.player.pos)
		print(
			(
				"CAMFRAME shot %s: pan %.2f m, feet at %.0f,%.0f px of %s"
				% [sh[0], m.cam.pan.length(), s.x, s.y, str(vp.get_visible_rect().size)]
			)
		)
	main.get_tree().quit(0)
