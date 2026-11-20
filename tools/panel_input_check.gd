extends RefCounted
## --panel-input-check: the first press after a panel closes reaches the Hunter, and a press made while
## it is open never does. Panels: the full map (M), the backpack (Tab) and the pause menu (Esc); a match
## has no squad chat box. Keys: LMB, dash (Shift), E and jump (Space). Everything goes through real input
## events (Input.parse_input_event, so the UI sees them first); "lands" is read off the Match the way the
## fixed step reads it (inp["fire"], pending_input, aim_hold) on the frame of the press.
## Pick-one panels too (_pick_one_rows): one click, or Enter, on a card takes it, with no Confirm step: the egg
## pick and the Hunter grid. The Relic pick asks "Take <Name>?" on purpose (caf32dd280) and is not driven here.
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
	await _pick_one_rows()
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

## A left click on a card, sent to the card itself the way the mouse would.
func _click(card: Control) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	card.gui_input.emit(ev)

## Enter (or the pad's A) on the focused card.
func _accept(card: Control) -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	card.gui_input.emit(ev)

## The pick cards under `root`: the selectable tiles (a locked tile takes no focus).
func _cards(root: Node) -> Array:
	var out: Array = []
	for n in root.find_children("*", "PanelContainer", true, false):
		if (n as Control).focus_mode == Control.FOCUS_ALL:
			out.append(n)
	return out

## Any button left on the panel that would be a second step.
func _confirm_buttons(root: Node) -> Array:
	var out: Array = []
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).visible:
			out.append((b as Button).text)
	return out

func _pick_one_rows() -> void:
	for how in ["click", "Enter"]:
		await _egg_row(how)
	_hunter_grid_row()

## The egg pick: one click, or Enter on the focused card, starts the knock with that egg.
func _egg_row(how: String) -> void:
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"intro": true}
	Save.d["look"] = Unmasked.default_look()
	var hx = load("res://scripts/ui/hatch.gd").new()
	main.add_child(hx)
	for i in 4: await tree.process_frame
	hx._looks_good()
	await tree.process_frame
	var cards := _cards(hx.bottom)
	ok(cards.size() >= 3 and hx.stage == "pick", "egg pick (%s): the egg cards are up (%d)" % [how, cards.size()])
	ok(_confirm_buttons(hx.bottom).is_empty(), "egg pick (%s): no Confirm button on the panel" % how)
	if how == "click":
		_click(cards[1])
	else:
		(cards[1] as Control).grab_focus()
		_accept(cards[1])
	ok(hx.chosen == 1 and hx.stage == "warm", "egg pick (%s): taken at once (stage %s)" % [how, hx.stage])
	hx.queue_free()

## The Hunter grid (lobby and Hunters pick): one click on an open Hunter's card hands its id to the pick callback.
func _hunter_grid_row() -> void:
	var got: Array = []
	var holder := Control.new()
	main.add_child(holder)
	var grid := HeroGrid.build(holder, func(ak: String): got.append(ak), func(_a): pass, func(_a): pass, false)
	var cards := _cards(grid)
	_click(cards[0])
	ok(got == [cards[0].get_meta("arch")],
		"Hunter grid: one click on a card picks it (%s)" % str(got))
	var extra := _confirm_buttons(grid).filter(func(t): return t != "Kit (K)")      # (Kit only opens the kit page)
	ok(extra.is_empty(), "Hunter grid: no Confirm button (%s)" % str(extra))
	holder.queue_free()
