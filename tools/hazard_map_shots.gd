extends RefCounted
## --hazard-map-shots --shots-dir=<dir>: terrain hazards on the maps at 1280x720 (HazardMap), a few metres
## from a lava field with an ember Boki (it counters lava, so the shield sits on it):
##   mm_hold    the minimap with Tab held (crop of the top left, 2x)
##   full_map   the full map: every area tinted, the key along the bottom
##   full_zoom  the full map zoomed on the lava field
## <dir>/captions.txt gets "file: caption" per file. Run on a build without HazardMap for the "before" set.

const DT := 1.0 / 60.0

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
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 5, "no_drop": true,
		"demo_kin": "cindowary"})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var lava := Vector3.ZERO
	for a in TerrainHazards.of(m).areas:
		if a["kind"] == "lava":
			lava = a["centre"]
			break
	P.teleport(m.world.free_spot_near(lava + Vector3(10, 0, 0), [], 1.0, 0.5, 12.0))
	Input.action_press("scores")
	await _go(0.4)
	_crop("mm_hold", "The minimap with Tab held: hazard areas tinted by kind, a shield on the ones your Boki counters")
	Input.action_release("scores")
	m.hud.full_map.open()
	await _go(0.3)
	_take("full_map", "The full map: every hazard area tinted, the key along the bottom")
	m.hud.full_map.zoom = 3.0
	m.hud.full_map.zoom_to = 3.0
	m.hud.full_map.center = Vector2(lava.x, lava.z)
	await _go(0.3)
	_take("full_zoom", "Zoomed in on the lava field")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("HAZARDMAPSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

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
