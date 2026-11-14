class_name RecastDrill
extends Node
## The two-step drill on the Training Grounds and the Arena (DECISIONS 2026-11-08: two-step abilities must be
## obvious): a bar station that picks the current Hunter's recast abilities (the slots whose own text says
## "again", the way KitDrill reads them) and runs REPS short reps on each: cast it, wait for the recast marker
## (RecastCue's window), press again while it is open. Each rep reads out hit, late or early. A press just
## before the window opens still counts (ArchKit.RECAST_BUFFER, the same buffer the kit applies). It watches
## the real kit (recast_window), so the cast and the recast are the real ones; after a rep the slot's cooldown
## is reset so the next rep needs no waiting.

const NAME := "RecastDrill"
const SLOTS := ["e", "x", "dash"]  # the slots a recast window can sit on (RecastCue.window ids; rmb has none)
const ACTIONS := {"e": "signature", "x": "hunter_ult", "dash": "dash"}
const REPS := 3  # reps per ability
const CAST_WAIT := 1.0  # s the cast gets to open its window before the rep is dropped (cast denied)
const COOL_MAX := 20.0  # s a finished rep waits for its window to close before the slot resets anyway
const PANEL_POS := Vector2(16, 120)  # px, from the top left, under the portrait
const WORDS := {"hit": "HIT", "late": "LATE: the window had closed", "early": "EARLY: wait for the marker"}

var m: Match
var plan: Array = []  # the Hunter's recast slots, in SLOTS order
var arch := ""
var reps := {}  # slot -> {n, res (grades), ph (idle|cast|open|cool), t, buf (s a press waits for the
# window), last (s left at the press), seen (s left on the last look)}
var _layer: CanvasLayer = null
var _panel: PanelContainer = null
var _text: Label = null


## Adds the drill to a practice area with an Arena (Practice.attach calls this).
static func attach(p: Practice) -> RecastDrill:
	if p.m.arena == null:
		return null
	var d := RecastDrill.new()
	d.name = NAME
	d.process_mode = Node.PROCESS_MODE_PAUSABLE
	d.m = p.m
	p.add_child(d)
	d.set_process(false)
	return d


## The slots of a Hunter that take a second press: the ones whose own text says "again".
static func slots(hunter_id: String) -> Array:
	return SLOTS.filter(func(s): return KitDrill.how(hunter_id, s) == "again")


func is_open() -> bool:
	return _layer != null


func toggle() -> void:
	if is_open():
		_close()
	else:
		_open()


func _open() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_panel = UI.glass(10, 14)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.position = PANEL_POS
	_layer.add_child(_panel)
	var v := UI.vbox(6)
	_panel.add_child(v)
	v.add_child(UI.label("Two-step drill", 14, UI.INK, UI.semi))
	_text = UI.label("", 13, UI.MUTED)
	v.add_child(_text)
	if m.hud:
		m.hud.ui_extra.append(_panel)
	start(m.player.arch)
	set_process(true)


func _close() -> void:
	if m.hud:
		m.hud.ui_extra.erase(_panel)
	_layer.queue_free()
	_layer = null
	_panel = null
	_text = null
	set_process(false)


## Starts over for a Hunter (the picker swapped it, or the station opened).
func start(hunter_id: String) -> void:
	arch = hunter_id
	plan = slots(hunter_id) if Arch.exists(hunter_id) else []
	reps.clear()
	for s in plan:
		reps[s] = {"n": 0, "res": [], "ph": "idle", "t": 0.0, "buf": -1.0, "last": 0.0, "seen": 0.0}
	_refresh()


func _input(event: InputEvent) -> void:
	if m.paused or not is_open():
		return
	for s in plan:
		if event.is_action_pressed(ACTIONS[s]) and not event.is_echo():
			on_press(s)


func _process(dt: float) -> void:
	if m.player.arch != arch:
		start(m.player.arch)
	tick(dt)


## A press of the slot's key (the input, or a check): the cast, then the second press that is graded.
func on_press(slot: String) -> void:
	var r: Dictionary = reps.get(slot, {})
	if r.is_empty() or int(r["n"]) >= REPS:
		return
	match String(r["ph"]):
		"idle":
			r["ph"] = "cast"
			r["t"] = 0.0
		"cast":
			r["buf"] = ArchKit.RECAST_BUFFER  # before the marker: it may still open inside the buffer
		"open":
			var w := m.player.ak.recast_window()
			if bool(w.get("armed", true)):
				_grade(slot, "hit", float(w.get("left", 0.0)))
			else:
				r["buf"] = ArchKit.RECAST_BUFFER
	_refresh()


## One step: follows each rep's window and ends it (late or early) when it has to.
func tick(dt: float) -> void:
	if plan.is_empty():
		return
	var w := m.player.ak.recast_window()
	for s in plan:
		var r: Dictionary = reps[s]
		var mine: bool = String(w.get("slot", "")) == s
		r["t"] = float(r["t"]) + dt
		match String(r["ph"]):
			"cast":
				if mine:
					r["ph"] = "open"
				elif float(r["t"]) > CAST_WAIT and float(r["buf"]) < 0.0:
					r["ph"] = "idle"  # the cast never opened a window (it was denied): no rep
			"cool":
				if not mine or float(r["t"]) > COOL_MAX:
					_reset(s)
		if mine:
			r["seen"] = float(w["left"])
		if String(r["ph"]) == "open" and not mine:
			# it ended: with time left it was used (a buffered press went through, Shift), else it ran out
			var used := float(r["seen"]) >= RecastCue.RAN_OUT
			if used:
				_grade(s, "hit", float(r["seen"]))
			else:
				_grade(s, "late", 0.0)
		elif float(r["buf"]) >= 0.0 and String(r["ph"]) in ["cast", "open"]:
			r["buf"] = float(r["buf"]) - dt
			if mine and bool(w.get("armed", true)):
				_grade(s, "hit", float(w.get("left", 0.0)))
			elif float(r["buf"]) < 0.0:
				_grade(s, "early", 0.0)


func _grade(slot: String, res: String, left: float) -> void:
	var r: Dictionary = reps[slot]
	(r["res"] as Array).append(res)
	r["n"] = int(r["n"]) + 1
	r["ph"] = "cool"
	r["t"] = 0.0
	r["buf"] = -1.0
	r["last"] = left
	_refresh()


## A finished rep's slot is ready again: no cooldown to wait for between reps.
func _reset(slot: String) -> void:
	var k: ArchKit = m.player.ak
	var r: Dictionary = reps[slot]
	r["ph"] = "idle"
	r["buf"] = -1.0
	match slot:
		"e":
			k.cd["e"] = 0.0
		"x":
			k.cd["x"] = 0.0
		"dash":
			m.player.dashes = m.player.max_dashes()


func _refresh() -> void:
	if _text == null:
		return
	if plan.is_empty():
		_text.text = "No two-step abilities"
		return
	var lines := PackedStringArray()
	for s in plan:
		var r: Dictionary = reps[s]
		var nm := String(HunterViewer.slot_info(arch, s).get("name", s))
		var key := Settings.key_cap(ACTIONS[s])
		var done := "  ·  done" if int(r["n"]) >= REPS else ""
		lines.append("[%s] %s: %d / %d%s" % [key, nm, mini(int(r["n"]), REPS), REPS, done])
		lines.append("    %s" % _readout(s, r))
	_text.text = "\n".join(lines)


## What the slot's last rep said, or what to do next.
func _readout(slot: String, r: Dictionary) -> String:
	var key := Settings.key_cap(ACTIONS[slot])
	var ph := String(r["ph"])
	if ph in ["cast", "open"]:
		return "%s AGAIN when the marker shows" % key
	if (r["res"] as Array).is_empty():
		return "Press %s, then %s AGAIN" % [key, key]
	var last := String((r["res"] as Array).back())
	if last == "hit" and is_finite(float(r["last"])):  # (a window with no timer, Ostra's seed, has no time left)
		return "%s (%.1f s left)" % [WORDS[last], float(r["last"])]
	return WORDS[last]
