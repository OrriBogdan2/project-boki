extends RefCounted
## The match camera's framing against the source (docs/MOVEMENT_FEEL.md, "Camera framing vs the source").
## --cam-framing-check, on a 1920x1080 view:
##   1. the Supervive style takes its numbers from content/rules/camera.json and sits inside the source's
##      bands there: pitch, lens, and your feet a little below the screen's centre
##   2. the cursor lean: none inside the deadzone, never past its cap, and at full lean every way (16
##      directions, at the sneak, normal and close zooms) you stay on screen, feet and head
## --cam-framing-shots (GPU, --shots-dir=<dir>): a live match at the default view, then the cursor held at
## the screen's top and bottom edge while sneaking (the widest grounded zoom), one PNG each.

const VIEW := Vector2i(1920, 1080)
const HEAD := 2.0                    # m: the top of a medium hunter's head above its feet
const ZOOMS := [0.6, 1.0, 1.45]      # a close-up, the usual view, sneaking (Match: 1.45 while crouched)
const SHOTS := [
	["framing_default", 1.0, Vector2(0.5, 0.5)],
	["framing_sneak_lean_up", 1.45, Vector2(0.5, 0.01)],
	["framing_sneak_lean_down", 1.45, Vector2(0.5, 0.99)],
]

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
	_lean(cam)
	vp.queue_free()
	print("CAMFRAME CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _style(cam: CamRig) -> void:
	var src: Dictionary = CamRig.RULES["source"]
	var st: Dictionary = CamRig.RULES["styles"]["supervive"]
	cam.use_style("supervive")
	ok(is_equal_approx(rad_to_deg(cam.pitch), float(st["pitch"])) and is_equal_approx(cam.dist, float(st["dist"]))
			and is_equal_approx(cam.fov, float(st["fov"])) and is_equal_approx(cam.rise, float(st["rise"])),
			"the Supervive style is camera.json's: %s" % str(st))
	var pitch := rad_to_deg(cam.pitch)
	ok(_inside(pitch, src["pitch_deg"]), "pitch %.1f deg inside the source's %s" % [pitch, str(src["pitch_deg"])])
	ok(_inside(cam.fov, src["fov_deg"]), "lens %.1f deg inside the source's %s" % [cam.fov, str(src["fov_deg"])])
	cam.snap(Vector3.ZERO)
	var feet := (cam.unproject_position(Vector3.ZERO).y - VIEW.y * 0.5) / VIEW.y * 100.0
	ok(_inside(feet, src["feet_below_pct"]), "feet %.2f%% of the height below the centre, inside the source's %s"
			% [feet, str(src["feet_below_pct"])])

func _lean(cam: CamRig) -> void:
	var fm: Array = CamRig.FOLLOW["supervive"]
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
			cam.snap(p)      # (the view's centre at the lean, you at the origin)
			for at in [Vector3.ZERO, Vector3(0, HEAD, 0)]:
				var s := cam.unproject_position(at)
				worst = minf(worst, minf(minf(s.x, VIEW.x - s.x), minf(s.y, VIEW.y - s.y)))
		ok(over_cap <= 0.001, "zoom %.2f: the lean stays within its %.1f m cap" % [z, float(fm[2]) * maxf(1.0, z)])
		ok(worst >= 20.0, "zoom %.2f: at full lean every way you stay on screen (%.0f px to the nearest edge)"
				% [z, worst])
	cam.zoom = 1.0

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
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1500.0, "seed": 4242, "no_drop": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)      # (the screen fade from start-up still covers the view)
	Settings.set_v("tips", false)
	for h in m.hunters:
		if h != m.player:
			h.ctrl = "idle"
	var vp := main.get_viewport()
	for sh in SHOTS:
		m.set_meta("zoom_hold", float(sh[1]))
		for i in 90:
			vp.warp_mouse(vp.get_visible_rect().size * Vector2(sh[2]))
			await main.get_tree().process_frame
		vp.get_texture().get_image().save_png(dir.path_join(String(sh[0]) + ".png"))
		var s := m.cam.unproject_position(m.player.pos)
		print("CAMFRAME shot %s: pan %.2f m, feet at %.0f,%.0f px of %s"
				% [sh[0], m.cam.pan.length(), s.x, s.y, str(vp.get_visible_rect().size)])
	main.get_tree().quit(0)
