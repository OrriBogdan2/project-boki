extends RefCounted
## --blight-edge-shots --shots-dir=<dir> [--quality=low|medium|high|ultra]: does the Blight's edge read?
## One standing spot on the Heart's island, the camera turned to the tide ring, the ring set by the
## match clock to sit 60 m off, 5 m off, and 5 m behind the player (out in the Blight):
##   wall_60m    the wall 60 m away, low camera (the play camera is 57 degrees down and sees ~12 m ahead)
##   wall_edge   the wall 5 m off, play camera
##   in_blight   5 m past it: tint, line, red pulse of a tide hit
##   minimap     crop of the minimap with the ring and the dashed next ring
##   full_map    the drop map (planning) before the tide starts: the first ring, dashed
## Prints BLIGHTEDGE with the preset. <dir>/captions.txt: "file: caption".

const DT := 1.0 / 60.0
const LOW_PITCH := 0.12        # rad: the camera for the 60 m shot, nearly level so the wall is in frame

var main: Node
var m: Match
var P: Hunter
var dir := ""
var spot := Vector3.ZERO
var out := Vector2.ZERO        # unit vector from the Heart to the spot
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var d := Vector2(spot.x - m.heart.site.x, spot.z - m.heart.site.z).length()
	var play_pitch := m.cam.pitch
	await _view("wall_60m", d + 60.0, LOW_PITCH, "The wall 60 m away from the spot, seen from a low camera")
	await _view("wall_edge", d + 5.0, play_pitch, "The wall 5 m off, the play camera")
	m.heart.hit_t = 1.0e9
	await _view("in_blight", d - 5.0, play_pitch, "5 m out in the Blight: tint, the line, the red pulse of a hit")
	_crop_take("minimap", Rect2i(0, 0, 250, 250), 2.0, "The minimap: the ring, the dashed next ring, the Heart")
	m.heart.hit_t = -99.0
	m.hud.full_map.open(true)
	m.time = 0.0 - m.sess_t0
	await _go(0.3)
	_take("full_map", "The drop map before the tide starts: the first ring, dashed")
	m.hud.full_map.close()
	print("BLIGHTEDGE quality=%s" % Settings.quality())
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	main.get_tree().quit(0)

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 7301, "no_drop": true,
		"heart": true, "god": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var site := m.heart.site
	for r in range(70, 40, -2):
		for k in 36:
			var a := TAU * k / 36.0
			var g := site + Vector3(cos(a), 0, sin(a)) * r
			var wet := m.world.is_void(g.x, g.z) or m.world.is_void(g.x + 2, g.z) or m.world.is_void(g.x, g.z + 2)
			if not wet:
				spot = m.world.free_spot_near(g, [], 1.0, 0.45, 4.0)
				break
		if spot != Vector3.ZERO:
			break
	out = Vector2(spot.x - site.x, spot.z - site.z).normalized()
	P.teleport(spot)
	for h in m.hunters:
		if h != P:
			h.teleport(m.world.free_spot_near(site, [], 1.0, 0.45, 6.0))

## Ring radius `ring` m on the clock, the camera looking out at the wall, then a shot.
func _view(file: String, ring: float, pitch: float, caption: String) -> void:
	var rl := Heart.rules()
	var k := (float(rl["tide_r0"]) - ring) / (float(rl["tide_r0"]) - float(rl["tide_r1"]))
	m.time = float(rl["tide_start_s"]) + float(rl["tide_close_s"]) * k - m.sess_t0
	m.cam.pitch = pitch
	m.cam.yaw = atan2(-out.x, -out.y)
	m.cam.yaw_to = m.cam.yaw
	await _go(0.25)
	m.time = float(rl["tide_start_s"]) + float(rl["tide_close_s"]) * k - m.sess_t0
	_take(file, caption)
	await _cost(file)

## What the frame costs with this view on screen: the average of 60 frames.
func _cost(file: String) -> void:
	var vp := main.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await _go(0.1)
	var cpu := 0.0
	var gpu := 0.0
	var draws := 0.0
	var tris := 0.0
	for i in 60:
		await _go(DT)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		tris += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("BLIGHTEDGE cost %s quality=%s draws=%.0f tris=%.0f render_cpu_ms=%.2f render_gpu_ms=%.2f" % [
		file, Settings.quality(), draws / 60.0, tris / 60.0, cpu / 60.0, gpu / 60.0])

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		P.teleport(spot)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String, caption: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])

func _crop_take(file: String, r: Rect2i, zoom: float, caption: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	var crop := img.get_region(r.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	crop.resize(int(r.size.x * zoom), int(r.size.y * zoom), Image.INTERPOLATE_BILINEAR)
	crop.save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
