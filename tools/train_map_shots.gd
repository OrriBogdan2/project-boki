extends RefCounted
## --train-map-shots --shots-dir=<dir>: the sky train on both maps at 1280x720, under xvfb with a renderer.
##   mm_near   the minimap beside a halt, the train a few seconds out: the loop, the halt and "Next train"
##   mm_far    the minimap away from the loop: no train line (the declutter rule)
##   full_map  the full map: the loop, every halt named, the train's marker
##   full_zoom the full map zoomed in on the halt nearest the player, with its countdown
## <dir>/captions.txt gets "file: caption" per file.

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
	await _setup()
	var halts: Array = m.hud.train_map.halts(m.skytrain)
	var at: Vector2 = halts[0]["pos"]
	m.time += m.skytrain.dwell + 1.0      # the train has pulled out of its first stop
	m.time += m.skytrain.halt_eta(float(halts[0]["s"])) - 24.0      # 24 s from coming back to it
	var deck := m.world.train_at(float(halts[0]["s"]))      # the pier is level with the deck
	var spot := Vector3(at.x, deck.y + 0.3, at.y)
	P.teleport(spot)
	await _go(0.5)
	print("TRAINMAPSHOTS halt %s player %s" % [at, P.pos])
	_crop("mm_near", "The minimap beside a halt: the loop, the halt, the train, 'Next train: 0:24'")
	_far_from_loop()
	await _go(0.5)
	_crop("mm_far", "Away from the loop the minimap shows no train")
	P.teleport(spot)
	m.hud.full_map.open()
	await _go(0.3)
	_take("full_map", "The full map: the loop, every halt named, the train's marker, the countdown at the nearest halt")
	m.hud.full_map.zoom = 3.0
	m.hud.full_map.zoom_to = 3.0
	m.hud.full_map.center = at
	await _go(0.3)
	_take("full_zoom", "Zoomed in on the nearest halt")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("TRAINMAPSHOTS %d in %s" % [lines.size(), dir])
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
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)

## Moves the player to ground out of the minimap's range of the loop.
func _far_from_loop() -> void:
	for _try in 60:
		P.teleport(m.world.random_ground())
		if not m.hud.train_map.near(m.skytrain, P):
			return

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
