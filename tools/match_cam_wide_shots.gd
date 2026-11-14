extends RefCounted
## --match-cam-wide-shots --shots-dir=<dir> --bench-view=1920x1080 [--map=<skyreach>] [--wide-video]: the match camera's
## old view, the new default and the wheel's furthest, on one map (GPU: jobq --needs gpu). Each view is a still in
## the middle of the map and one at the map's outer edge (<dir>/<view>_mid.png, <view>_edge.png), and a timed run
## of a live match (autoplaying player, rivals and a monster pack brought to it, as --perf-bench's match) printed
## as WIDECAM lines: avg ms, fps, 1% low, gpu ms, draws. --wide-video also writes the new default's run as numbered
## frames with the wheel scrolled out and in (<dir>/video_NNN.png, 30 fps; encode with ffmpeg). Never writes the save.

const PerfBench := preload("res://tools/perf_bench.gd")
const DT := 1.0 / 60.0
const SETTLE := 90               # frames the view eases for before a still or a timed run
const TIMED := 300               # frames timed per view
const FIGHT_AT := 2.0            # s into the match: the rivals and the pack are brought to the player
const EDGE_IN := 0.85            # of the outermost island's radius: where the edge still stands
const NOTCH_EVERY := 8           # video frames between wheel notches
const HOLD := 45                 # video frames held still between the wheel's runs
const OLD_STYLE := "supervive_close"

var main: Node
var bench := PerfBench.new()
var dir := ""
var m: Match
var label: Label
var n := 0                       # video frame counter

func run(main_node: Node) -> void:
	main = main_node
	var video := false
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		video = video or a == "--wide-video"
	DirAccess.make_dir_recursive_absolute(dir)
	bench.setup(main)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Settings.v["cam_follow"] = "locked"      # no cursor lean: the idle cursor sits on the HUD
	Settings.v["tips"] = false
	await _style("old", OLD_STYLE, [["old", 1.0]], false)
	var out: float = CamWheel.rules()["match"]["max"]
	await _style("new", "supervive", [["new", 1.0], ["max", out]], video)
	print("WIDECAM DONE")
	main.get_tree().quit()

## A fresh match under one camera style (its draw and shadow distances are set when it is built), then its views.
func _style(tag: String, style: String, views: Array, video: bool) -> void:
	Settings.v["cam_style"] = style
	Settings.v["cam_zoom"] = 1.0
	await _build()
	for v in views:
		m.cam.user_zoom = float(v[1])
		await _view(String(v[0]), tag)
	if video:
		m.cam.user_zoom = 1.0
		await _video()

func _build() -> void:
	var o := Match.demo_opts()
	o.merge({"teams": 3, "squad": 2, "total": 6, "no_drop": true, "god": true, "autoplay": true,
		"demo_kin": "cindle", "seed": 4101}, true)
	o.erase("demo_match")
	o.erase("fresh_t")
	Game.goto("match", o)
	m = null
	while m == null:
		await main.get_tree().process_frame
		var cur = main.current
		if cur is Match and (cur as Match).is_processing() and (cur as Match).hud != null:
			m = cur
	m.set_process(false)
	m.player.max_hp *= 20.0      # the fight must not end the run
	m.hud.guide_hidden = true
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)

## One frame of the live match; returns its timing.
func _tick(steps := 1) -> Dictionary:
	m.player.hp = m.player.max_hp
	if m.time >= FIGHT_AT and not m.has_meta("wide_fight"):
		m.set_meta("wide_fight", true)
		bench.bring_fight(m)
	var last := Time.get_ticks_usec()
	for i in steps:
		m.step(DT)
	m._process(DT * steps)
	var script_ms := (Time.get_ticks_usec() - last) / 1000.0
	await main.get_tree().process_frame
	return bench.frame("wide", 0, (Time.get_ticks_usec() - last) / 1000.0, script_ms)

func _view(view: String, tag: String) -> void:
	for spot in ["mid", "edge"]:
		if spot == "edge":
			_to_edge()
		for i in SETTLE:
			await _tick()
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%s.png" % [view, spot]))
	var fl: Array = []
	for i in TIMED:
		fl.append(await _tick())
	var w: Array = fl.map(func(f): return float(f["wall"]))
	w.sort()
	var low := 0.0
	for k in 3:
		low += float(w[w.size() - 1 - k]) / 3.0
	var line := "WIDECAM %s (style %s, zoom %.2f, reach %.2f): avg %.2f ms = %.0f fps, 1%% low %.0f fps, "
	line += "gpu %.2f ms, draws %.0f, tris %.0fk"
	print(line % [view, tag, m.cam.zoom, m.cam.reach(), bench.avg(fl, "wall"), 1000.0 / bench.avg(fl, "wall"),
		1000.0 / maxf(low, 0.001), bench.avg(fl, "gpu"), bench.avg(fl, "draws"), bench.avg(fl, "tris") / 1000.0])

## The player on the shore of the island furthest from the map's middle, the camera jumped there.
func _to_edge() -> void:
	var mid := Vector2.ZERO
	for isl in m.world.islands:
		mid += (isl["c"] as Vector2) / m.world.islands.size()
	var far: Dictionary = m.world.islands[0]
	for isl in m.world.islands:
		if (isl["c"] as Vector2).distance_to(mid) > (far["c"] as Vector2).distance_to(mid):
			far = isl
	var c: Vector2 = far["c"]
	var at2: Vector2 = c + (c - mid).normalized() * float(far["r"]) * EDGE_IN
	var at: Vector3 = m.world.free_spot_near(Vector3(at2.x, m.world.ground_at(at2.x, at2.y), at2.y), [], 1.2, 0.5, 6.0)
	m.player.teleport(at)
	m.cam.snap(at)

## The new default's live fight as frames: the wheel scrolled out to its furthest, in to its closest, then back.
func _video() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)
	label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 28)
	layer.add_child(label)
	var r: Dictionary = CamWheel.rules()["match"]
	var notches := int(roundf((float(r["max"]) - 1.0) / float(r["step"])))
	var back := int(roundf((float(r["max"]) - float(r["min"])) / float(r["step"])))
	var runs := [[1, notches], [-1, back], [1, int(roundf((1.0 - float(r["min"])) / float(r["step"])))]]
	await _hold(HOLD)
	for run in runs:
		for i in int(run[1]):
			CamWheel.input(m, _wheel(MOUSE_BUTTON_WHEEL_DOWN if int(run[0]) > 0 else MOUSE_BUTTON_WHEEL_UP))
			await _hold(NOTCH_EVERY)
		await _hold(HOLD)
	layer.queue_free()

func _hold(frames: int) -> void:
	for i in frames:
		await _tick(2)      # (two match steps a frame: the video plays at 30 fps in real time)
		var across := CamRig.style_across(m.cam.style_id) * m.cam.zoom
		label.text = "wheel zoom %.2f  ·  %.0f m of ground across" % [m.cam.user_zoom, across]
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("video_%03d.png" % n))
		n += 1

func _wheel(button: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev
