extends RefCounted
## The match camera's framing against the source (docs/MOVEMENT_FEEL.md, "Camera framing vs the source" and
## "Camera frame per aspect").
## --camera-frame-check:
##   1. the Supervive style takes its numbers from content/rules/camera.json and, on a 1920x1080 view, sits inside
##      the source's bands there: pitch, lens, your feet a little below the centre, and the shape of the ground
##      shown (metres ahead over behind, to the side over ahead)
##   2. per aspect, windowed and full screen (VIEWS): every screen shows the 16:9 frame's metres to the side, a
##      wider one less ahead and behind, a narrower one more; the same aspect at any size frames the same metres;
##      you stay on screen, feet and head
## --camera-frame-shots (GPU, --shots-dir=<dir>): a live match at the default view in a 16:9, a 21:9 and a 4:3
## window, one PNG each. --frame-before draws them with the lens kept for every aspect (the rule before
## frame_aspect), for a before/after pair from one build.

const HEAD := 2.0                    # m: the top of a medium hunter's head above its feet
const SAME := 0.005                  # share: two views frame "the same" metres within 0.5%
const EDGE_PX := 20.0                # px your feet and head keep from the screen's edges
## [label, view size]: full screen at common monitor sizes, and windows (a 16:9 window, one maximised under a
## title bar and taskbar, a 4:3 window). The first is the reference frame.
const VIEWS := [
	["16:9 full 1920x1080", Vector2i(1920, 1080)],
	["16:9 window 1280x720", Vector2i(1280, 720)],
	["16:9 full 3840x2160", Vector2i(3840, 2160)],
	["16:9 maximised window 1920x1017", Vector2i(1920, 1017)],
	["16:10 full 1920x1200", Vector2i(1920, 1200)],
	["21:9 full 2560x1080", Vector2i(2560, 1080)],
	["21:9 full 3440x1440", Vector2i(3440, 1440)],
	["21:9 window 1680x720", Vector2i(1680, 720)],
	["4:3 full 1600x1200", Vector2i(1600, 1200)],
	["4:3 window 1024x768", Vector2i(1024, 768)],
]
## [file, window size] for --camera-frame-shots: one height, so the three compare pixel for pixel.
const SHOTS := [
	["frame_16x9", Vector2i(1280, 720)],
	["frame_21x9", Vector2i(1680, 720)],
	["frame_4x3", Vector2i(960, 720)],
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
	main.add_child(vp)
	var cam := CamRig.new()
	vp.add_child(cam)
	cam.use_style("supervive")
	vp.size = VIEWS[0][1]
	cam.snap(Vector3.ZERO)
	_style(cam)
	_aspects(cam, vp)
	vp.queue_free()
	print("CAMFRAME CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _style(cam: CamRig) -> void:
	var src: Dictionary = CamRig.RULES["source"]
	var st: Dictionary = CamRig.STYLES["supervive"]
	ok(is_equal_approx(rad_to_deg(cam.pitch), float(st["pitch"])) and is_equal_approx(cam.dist, float(st["dist"]))
			and is_equal_approx(cam.lens, float(st["fov"])) and is_equal_approx(cam.rise, float(st["rise"])),
			"the Supervive style is camera.json's: %s" % str(st))
	var pitch := rad_to_deg(cam.pitch)
	ok(_inside(pitch, src["pitch_deg"]), "pitch %.1f deg inside the source's %s" % [pitch, str(src["pitch_deg"])])
	ok(_inside(cam.fov, src["fov_deg"]), "lens %.1f deg at 16:9 inside the source's %s"
			% [cam.fov, str(src["fov_deg"])])
	var view := Vector2(VIEWS[0][1])
	var feet := (cam.unproject_position(Vector3.ZERO).y - view.y * 0.5) / view.y * 100.0
	ok(_inside(feet, src["feet_below_pct"]), "feet %.2f%% of the height below the centre, inside the source's %s"
			% [feet, str(src["feet_below_pct"])])
	var g := _ground(cam, view)
	ok(_inside(g.x / g.y, src["ahead_per_behind"]), "%.2f m ahead per m behind, inside the source's %s"
			% [g.x / g.y, str(src["ahead_per_behind"])])
	ok(_inside(g.z / g.x, src["side_per_ahead"]), "%.2f m to the side per m ahead, inside the source's %s"
			% [g.z / g.x, str(src["side_per_ahead"])])

func _aspects(cam: CamRig, vp: SubViewport) -> void:
	var ref := Vector3.ZERO
	var by_aspect := {}          # aspect rounded to 0.01 -> the first view's ground at it
	for v in VIEWS:
		vp.size = v[1]
		cam.snap(Vector3.ZERO)
		var view := Vector2(vp.size)
		var g := _ground(cam, view)
		var aspect := view.x / view.y
		print("CAMFRAME view %s: lens %.1f deg, height %.1f m, ground %.1f m ahead, %.1f m behind, %.1f m each side"
				% [v[0], cam.fov, cam.global_position.y, g.x, g.y, g.z])
		if ref == Vector3.ZERO:
			ref = g
		ok(absf(g.z / ref.z - 1.0) < SAME, "%s: %.1f m each side, the 16:9 frame's %.1f m" % [v[0], g.z, ref.z])
		var wider := aspect - CamRig.FRAME_ASPECT
		var than := "under" if wider > 0.0 else "over"
		if absf(wider) < 0.01:
			than = "at"
		ok(than == "at" or (g.x < ref.x) == (wider > 0.0),
				"%s: %.1f m ahead, %s the 16:9 frame's %.1f m" % [v[0], g.x, than, ref.x])
		var key := snappedf(aspect, 0.01)
		if by_aspect.has(key):
			var was: Vector3 = by_aspect[key]
			ok((g - was).length() < SAME * was.length(), "%s frames what every %.2f view frames" % [v[0], aspect])
		else:
			by_aspect[key] = g
		var room := 1e9
		for at in [Vector3.ZERO, Vector3(0, HEAD, 0)]:
			var s := cam.unproject_position(at)
			room = minf(room, minf(minf(s.x, view.x - s.x), minf(s.y, view.y - s.y)))
		ok(room >= EDGE_PX, "%s: your feet and head %.0f px inside the screen" % [v[0], room])

## Metres of level ground the view shows from your feet `at` (the camera unturned): x ahead (to the top edge's
## middle), y behind (to the bottom edge's middle), z to each side along the row your feet are on.
func _ground(cam: CamRig, view: Vector2, at := Vector3.ZERO) -> Vector3:
	var feet := cam.unproject_position(at)
	var top := _on_ground(cam, Vector2(view.x * 0.5, 0.0), at.y) - at
	var bottom := _on_ground(cam, Vector2(view.x * 0.5, view.y), at.y) - at
	var side := _on_ground(cam, Vector2(view.x, feet.y), at.y) - at
	return Vector3(-top.z, bottom.z, side.x)

func _on_ground(cam: CamRig, px: Vector2, y: float) -> Vector3:
	var o := cam.project_ray_origin(px)
	var d := cam.project_ray_normal(px)
	return o + d * ((y - o.y) / d.y)

func _inside(v: float, band: Array) -> bool:
	return v >= float(band[0]) - 0.001 and v <= float(band[1]) + 0.001

func _shots(main: Node) -> void:
	Save.no_write = true
	var dir := "user://shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	var before := "--frame-before" in OS.get_cmdline_user_args()
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
		main.get_window().size = sh[1]
		for i in 60:
			if before:
				CamRig.FRAME_ASPECT = vp.get_visible_rect().size.aspect()      # the lens kept at every aspect
			vp.warp_mouse(vp.get_visible_rect().size * 0.5)
			await main.get_tree().process_frame
		vp.get_texture().get_image().save_png(dir.path_join(String(sh[0]) + ".png"))
		var g := _ground(m.cam, vp.get_visible_rect().size, m.player.pos)
		print("CAMFRAME shot %s %s: lens %.1f deg, %.1f m ahead, %.1f m behind, %.1f m each side (level ground)"
				% [sh[0], str(vp.get_visible_rect().size), m.cam.fov, g.x, g.y, g.z])
	main.get_tree().quit(0)
