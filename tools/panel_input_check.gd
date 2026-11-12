extends RefCounted
## --panel-input-check: the first press after a panel closes reaches the Hunter, and a press made while
## it is open never does. Panels: the full map (M), the backpack (Tab) and the pause menu (Esc); a match
## has no squad chat box. Keys: LMB, dash (Shift), E and jump (Space). Everything goes through real input
## events (Input.parse_input_event, so the UI sees them first); "lands" is read off the Match the way the
## fixed step reads it (inp["fire"], pending_input, aim_hold) on the frame of the press.
## Never touches the save file. Prints PANEL ok/FAIL lines and "PANEL DONE, failures: N".

const KEYS := {"LMB": "fire", "Shift": "dash", "E": "signature", "Space": "jump"}
const PANELS := ["map", "pack", "pause"]

var bad := 0
var main: Node
var m: Match
var tree: SceneTree

func ok(cond: bool, what: String) -> void:
	print("PANEL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(host: Node) -> void:
	main = host
	tree = host.get_tree()
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Save.d["tutorial"]["hatched"] = true
	Save.d["cls"] = "medium"
	var rec := Save.new_kin("cindle", "Pip", 77)
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 2, "length": 1e9, "seed": 4242, "no_drop": true, "raid": "clear"})
	m.set_process(false)
	main.current = m      # (the pause menu asks Main for the screen)
	await tree.process_frame
	for panel in PANELS:
		for key in KEYS:
			await _trial(panel, key)
	print("PANEL DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)

## One press of `key`, sent as a real event; the match reads it on the same frame.
func _press(key: String, down: bool) -> void:
	var ev: InputEvent = InputMap.action_get_events(KEYS[key])[0].duplicate()
	if ev is InputEventMouseButton:
		(ev as InputEventMouseButton).position = Vector2(640, 360)
		(ev as InputEventMouseButton).button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	ev.set("pressed", down)
	Input.parse_input_event(ev)
	await tree.process_frame

func _tap(action: String) -> void:
	for down in [true, false]:
		var ev: InputEvent = InputMap.action_get_events(action)[0].duplicate()
		ev.set("pressed", down)
		Input.parse_input_event(ev)
	await tree.process_frame

func _landed(key: String) -> bool:
	if not m.paused:
		m._gather_input()      # (Match._process returns before it while the Esc menu is up)
	match key:
		"LMB": return bool(m.player.inp["fire"])
		"Shift": return bool(m.pending_input["dash"])
		"Space": return bool(m.pending_input["jump"])
	return m.aim_hold == "signature" or bool(m.pending_input["sig"])

func _reset() -> void:
	for k in m.pending_input:
		m.pending_input[k] = false
	m.aim_hold = ""
	m.player.inp["fire"] = false

func _open(panel: String) -> void:
	match panel:
		"map": await _tap("map")
		"pack": await _tap("inventory")
		"pause": await _tap("menu")

func _close(panel: String) -> void:
	match panel:
		"map": await _tap("map")
		"pack": await _tap("inventory")
		"pause": await _tap("menu")

func _is_open(panel: String) -> bool:
	match panel:
		"map": return m.hud.map_open()
		"pack": return m.hud.pack_open()
		_: return Overlay.is_open()

func _trial(panel: String, key: String) -> void:
	var tag := "%s / %s" % [panel, key]
	_reset()
	Input.parse_input_event(_motion())
	await tree.process_frame
	await _open(panel)
	ok(_is_open(panel), "%s: opens" % tag)
	_reset()
	await _press(key, true)
	var leaked := _landed(key)
	await _press(key, false)
	ok(not leaked, "%s: a press while open does not reach the match" % tag)
	_reset()
	await _close(panel)
	ok(not _is_open(panel), "%s: closes" % tag)
	_reset()
	await _press(key, true)
	ok(_landed(key), "%s: the first press after close lands on that frame" % tag)
	await _press(key, false)
	_reset()

func _motion() -> InputEventMouseMotion:
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(640, 360)
	mm.global_position = mm.position
	return mm
