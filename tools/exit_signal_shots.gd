extends RefCounted
## --exit-signal-shots --shots-dir=<dir>: review screenshots of the three exits (dock, hatch, uplink) idle,
## active and used, each at match zoom and from 60 m (run on a real GPU; see jobq). Uses only the exits'
## own entry points, so the same tool runs on a tree without ExitSignal for the "before" set.
## Files: <dir>/<kind>_<state>_<view>.png, view = match or far.

const FAR_ZOOM := 1.9     # the camera's distance factor: 32.2 m * 1.9 = about 60 m

var main: Node
var m: Match
var dir := ""
var focus := Vector3.ZERO
var pins := {}

func _frames(n: int) -> void:
	for i in n:
		for h in pins:
			h.teleport(pins[h])
			h.vel = Vector3.ZERO
			h.hp = h.max_hp
		for mb in m.mobs:
			mb.dead = true
			mb.visible = false
		m.step(Match.DT)
		m.cam.snap(focus)
		for h in m.hunters:
			h.render(Match.DT, 1.0)
		await main.get_tree().process_frame

func _zoom(z: float) -> void:
	m.cam.zoom = z
	m.cam.zoom_to = z

func _grab(kind: String, state: String) -> void:
	for view in ["match", "far"]:
		_zoom(1.0 if view == "match" else FAR_ZOOM)
		await _frames(8)
		var img := main.get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("%s_%s_%s.png" % [kind, state, view]))
		print("EXITSHOT %s %s %s" % [kind, state, view])

func _at(x: Dictionary, off: Vector3) -> Vector3:
	var base: Vector3 = x["berth"] if x["kind"] == "dock" else x["pos"]
	return base + off

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 1, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	var R: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	for h in m.hunters:
		h.ctrl = "idle"
		h.max_hp = 5000.0
		h.hp = 5000.0
	var d: Dictionary = m.exits.of_kind("dock")[0]
	var hx: Dictionary = m.exits.of_kind("hatch")[0]
	var o: Dictionary = m.exits.of_kind("outpost")[0]
	m.time = 1.0
	for x in m.exits.list:
		m.time = maxf(m.time, float(x.get("open_at", 0.0)) + 1.0)
	var away := Vector3(0, 0, 40)
	# ---- the dock: idle, called by you, then a rival on the deck while the skiff boards
	focus = _at(d, Vector3(0, 1.5, 2))
	pins = {P: _at(d, away), R: _at(d, away * 1.5)}
	await _grab("dock", "idle")
	m.exits._call(d, P)
	await _frames(30)
	await _grab("dock", "active")
	m.exits._arrive(d)
	pins[R] = _at(d, Vector3(0.4, 0, 0.3))
	await _frames(40)
	await _grab("dock", "used")
	# ---- the hatch: sealed, the key turning, then open with a rival at its edge
	focus = _at(hx, Vector3(0, 1.0, 2))
	pins = {P: _at(hx, away), R: _at(hx, away * 1.5)}
	await _grab("hatch", "idle")
	P.rift_keys = 1
	m.exits._open_hatch(hx, P)
	await _frames(60)
	await _grab("hatch", "active")
	hx["t"] = 0.0
	await _frames(20)
	pins[R] = _at(hx, Vector3(1.3, 0, 0))
	await _frames(30)
	await _grab("hatch", "used")
	# ---- the uplink: idle, started by you, then a rival squad in the yard
	focus = _at(o, Vector3(0, 1.5, 3))
	pins = {P: _at(o, away), R: _at(o, away * 1.5)}
	await _grab("outpost", "idle")
	m.exits._start(o, P)
	await _frames(30)
	o["prog"] = 0.4
	await _grab("outpost", "active")
	pins[R] = _at(o, Vector3(1.2, 0, 1.2))
	await _frames(30)
	await _grab("outpost", "used")
	main.get_tree().quit(0)
