extends RefCounted
## --interact-prompt-shots --shots-dir=<dir>: the interact prompt with two chests in reach.
##   two_chests   nothing held: one prompt, for the nearest
##   hold         F held a moment: the hold shows
##   rebound      F rebound to G: the prompt says G (the binding is put back after)
##   uplink       at an outpost: a Ways Out line through the same widget
##   gate         the Heartspark carrier at the Heart Gate: Leave now, the ring part held
## Each at 1280x720 and ultrawide 2560x1080 (<name>_<w>x<h>.png).

const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(2560, 1080)]

const DT := 1.0 / 60.0

var main: Node
var m: Match
var P: Hunter
var dir := ""

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "heart": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	m.chests.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != P: h.teleport(P.pos + Vector3(60, 0, 0))
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var g := P.pos
	m.add_chest(g + Vector3(1.0, 0, 0.5))["free"] = true
	m.add_chest(g + Vector3(-0.7, 0, -0.5))["free"] = true
	P.inp["aim"] = g
	await _go(1.0)
	await _take("two_chests")
	P.inp["interact"] = true
	await _go(0.5)
	await _take("hold")
	P.inp["interact"] = false
	await _go(0.2)
	var first: InputEvent = InputMap.action_get_events("interact")[0].duplicate()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_G
	Settings.rebind("interact", ev)
	await _go(0.3)
	await _take("rebound")
	Settings.rebind("interact", first)
	if m.exits and not m.exits.list.is_empty():
		P.teleport(m.exits.list[0]["pos"] + Vector3(0.6, 0, 0.6))
		P.inp["aim"] = P.pos
		await _go(0.4)
		await _take("uplink")
	if m.heart and m.heart.site != Vector3.INF:
		m.heart.state = Heart.S.CARRIED
		m.heart.early_team = -1
		m.heart.charge = Heart.r("charge_s")
		m.heart.carrier = P
		P.teleport(m.heart.gate)
		P.inp["aim"] = P.pos
		P.inp["interact"] = true
		await _go(1.5)
		await _take("gate")
		P.inp["interact"] = false
	Save.no_write = false
	print("INTERACTPROMPTSHOTS in %s" % dir)
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

func _take(file: String) -> void:
	for win in SIZES:
		main.get_tree().root.size = win
		for i in 3:
			m.hud.c.queue_redraw()
			await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%dx%d.png" % [file, win.x, win.y]))
