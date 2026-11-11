extends RefCounted
## --interact-prompt-shots --shots-dir=<dir>: the interact prompt with two chests in reach.
##   two_chests   nothing held: one prompt, for the nearest
##   hold         F held a moment: the hold shows
##   rebound      F rebound to G: the prompt says G (the binding is put back after)

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
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
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
	_take("two_chests")
	P.inp["interact"] = true
	await _go(0.5)
	_take("hold")
	P.inp["interact"] = false
	await _go(0.2)
	var first: InputEvent = InputMap.action_get_events("interact")[0].duplicate()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_G
	Settings.rebind("interact", ev)
	await _go(0.3)
	_take("rebound")
	Settings.rebind("interact", first)
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
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
