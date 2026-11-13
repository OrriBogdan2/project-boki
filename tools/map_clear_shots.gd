extends RefCounted
## --map-clear-shots --shots-dir=<dir>: the full map (M) with two extraction points (one open, one closed with
## a timer) and the cursor resting on one, at 1280x720, plus the minimap with an open lift far off.
##   full_hover_open     the cursor rests on the open one: its tooltip
##   full_hover_closed   the cursor rests on the closed one
##   full_map            the cursor off the markers
##   minimap_far_open    the minimap crop: the open lift pinged on its edge
## <dir>/captions.txt gets "file: caption" per file. Run it on a base and on the branch for before/after.

const DT := 1.0 / 60.0
const REST_S := 1.1      # s of real time the cursor rests (the tooltip waits MapHover.DWELL_S)

var main: Node
var m: Match
var P: Hunter
var dir := ""
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await main.get_tree().process_frame
	await _setup()
	while m.hud.full_map == null:      # (the HUD builds it a few frames after the match starts)
		await main.get_tree().process_frame
	var fm: FullMap = m.hud.full_map
	await _go(0.5)
	_crop("minimap_far_open", "The minimap with an open lift far off: a pulsing arrow on its edge")
	fm.open()
	await _go(0.4)
	await _hover(m.exits.list[0])
	_take("full_hover_open", "Full map, cursor resting on the open extraction point")
	await _hover(m.exits.list[1])
	_take("full_hover_closed", "Full map, cursor resting on the closed extraction point")
	main.get_viewport().warp_mouse(Vector2(640, 20))
	await _go(0.3)
	_take("full_map", "Full map, cursor off the markers")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("MAPCLEARSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var xs: Array = m.exits.list
	xs[0]["state"] = "open"
	xs[0]["t"] = 12.0
	xs[1]["state"] = "idle"
	xs[1]["open_at"] = m.time + 80.0
	P.teleport(m.world.free_spot_near(xs[0]["pos"] + Vector3(60, 0, 0), [], 1.0, 0.5, 20.0))

## Rest the cursor on an exit for longer than the dwell.
func _hover(x: Dictionary) -> void:
	var pv: Vector2 = m.hud.full_map.to_screen(x["pos"])
	main.get_viewport().warp_mouse(pv)
	await _go(0.1)
	await main.get_tree().create_timer(REST_S).timeout
	await _go(0.1)

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String, caption: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])

func _crop(file: String, caption: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	var crop := img.get_region(Rect2i(0, 0, 250, 250).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	crop.resize(500, 500, Image.INTERPOLATE_BILINEAR)
	crop.save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
