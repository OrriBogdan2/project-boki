extends RefCounted
## --extract-ui-shots --shots-dir=<dir>: full-screen HUD shots of every way out in its main states
## (run under xvfb with a renderer). Files go into <dir> as extract_<name>.png.

var main: Node
var dir := ""

func _grab(file: String) -> void:
	for i in 6:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("extract_%s.png" % file))
	print("EXTRACTSHOT ", file)

func _fresh(squad: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": squad, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	for h in m.hunters:
		if h != m.player:
			h.ctrl = "idle"
			h.teleport(m.player.pos + Vector3(300, 0, 300))
		h.max_hp = 5000.0
		h.hp = 5000.0
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	return m

func _run(m: Match, sec: float) -> void:
	for i in int(sec / Match.DT):
		m.step(Match.DT)

func _finish(m: Match) -> void:
	m.over = true
	m.queue_free()
	await main.get_tree().process_frame

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var fade = main.get("fade")
	var m := _fresh(2)
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	var dock: Dictionary = m.exits.of_kind("dock")[0]
	P.teleport(dock["pos"] + Vector3(18, 0, 0))
	_run(m, 0.5)
	await _grab("0_none_yet")
	m.time = float(dock["open_at"]) + 1.0
	_run(m, 0.3)
	await _grab("1_dock_open")
	P.teleport(dock["pos"] + Vector3(0.3, 0, 0.3))
	m.exits.act(dock, "call", P)
	dock["t"] = 25.0
	_run(m, 0.3)
	await _grab("2_dock_called")
	dock["t"] = 0.05
	_run(m, 0.3)
	P.teleport(dock["pos"] + Vector3(-6, 0, 0))
	_run(m, 0.3)
	await _grab("3_boarding_ashore")
	P.teleport(dock["berth"])
	_run(m, 4.0)
	await _grab("4_boarding_aboard")
	await _finish(m)
	m = _fresh(2)
	P = m.player
	var up: Dictionary = m.exits.of_kind("outpost")[0]
	m.time = float(up["open_at"]) + 1.0
	P.teleport(up["pos"] + Vector3(14, 0, 0))
	_run(m, 0.3)
	await _grab("5_uplink_idle")
	P.teleport(up["pos"] + Vector3(0.6, 0, 0.6))
	m.exits.act(up, "start", P)
	P.set_meta("pin", P.pos)
	_run(m, 8.0)
	await _grab("6_uplink_charging")
	P.teleport(up["pos"] + Vector3(30, 0, 0))
	_run(m, 3.0)
	await _grab("7_uplink_draining")
	P.teleport(up["pos"] + Vector3(0.6, 0, 0.6))
	up["prog"] = 1.0
	_run(m, 0.3)
	await _grab("8_lift_open")
	await _finish(m)
	m = _fresh(2)
	P = m.player
	var hx: Dictionary = m.exits.of_kind("hatch")[0]
	P.teleport(hx["pos"] + Vector3(20, 0, 0))
	_run(m, 0.3)
	await _grab("9_hatch_sealed")
	P.rift_keys = 1
	P.teleport(hx["pos"] + Vector3(0.7, 0, 0.5))
	m.exits.act(hx, "open", P)
	_run(m, 3.0)
	await _grab("a_hatch_opening")
	hx["t"] = 0.05
	_run(m, 0.3)
	P.teleport(hx["pos"] + Vector3(3.0, 0, 0))
	await _grab("b_hatch_open")
	await _finish(m)
	main.get_tree().quit(0)
