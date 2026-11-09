extends RefCounted
## --minimap-shots --shots-dir=<dir>: the minimap at 1280x720 in a mid-match state (MapDetail), under xvfb with a
## renderer. A mate close by, a rival and a Boki out, some spawns scouted, a squad ping:
##   mid_default   the minimap as it plays (crop of the top left, 2x)
##   mid_hold      the same moment with Tab held
##   mid_frame     the whole frame, for the minimap's place on the screen
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
	await _go(0.5)
	_crop("mid_default", "The minimap as it plays: you, your squad, the nearest exit, pings")
	Input.action_press("scores")
	await _go(0.2)
	_crop("mid_hold", "The same moment with Tab held: places, train, every exit, lairs, caches, beacons, rivals' boxes")
	_take("mid_frame", "The held frame, 1280x720")
	Input.action_release("scores")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("MINIMAPSHOTS %d in %s" % [lines.size(), dir])
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
	var n_k := 0
	for cnd in m.spawn_plan.cands:
		if cnd["cat"] in ["rare_kin", "cache"] and n_k < 6 and (n_k % 2 == 0 or cnd["active"]):
			cnd["known"][P.team] = true
			n_k += 1
	var mate: Hunter = m.hunters.filter(func(h): return h.team == P.team and h != P)[0]
	var rival: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	mate.teleport(m.world.free_spot_near(P.pos + Vector3(12, 0, -6), [], 1.0, 0.5, 12.0))
	rival.teleport(m.world.free_spot_near(P.pos + Vector3(-15, 0, 10), [], 1.0, 0.5, 12.0))
	m.squad_ping(mate, m.world.free_spot_near(P.pos + Vector3(-10, 0, -14), [], 1.0, 0.5, 12.0))

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
