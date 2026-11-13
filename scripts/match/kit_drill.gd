class_name KitDrill
extends Node
## The first-time kit drill in the practice areas (DECISIONS 2026-11-08: two-step abilities must be
## obvious): one banner line per slot (LMB, RMB, E, R, dash), tried on the dummies, with the hold or the
## recast called out the way the recast HUD shows it ("E AGAIN"). The lines come from the Hunter's own
## JSON text (clip lines, card text, desc), the keys from the player's bindings. A step is done when
## the player does what it asks. Skippable any time; once done or skipped it never shows again
## (Save.d["tutorial"]["kit_drill"]). Attached by Practice.attach.

const NAME := "KitDrill"
const SAVE_KEY := "kit_drill"
## The Hunters whose lines are written in their JSON; the rest get the generic line until theirs are.
const SLICE := ["gunslinger", "juggernaut", "archer", "ashwick"]
const SLOTS := ["lmb", "rmb", "e", "x", "dash"]      # "x" is the hunter ultimate (R)
const ACTIONS := {"lmb": "fire", "rmb": "secondary", "e": "signature", "x": "hunter_ult", "dash": "dash"}
const HOLD_S := 0.4            # s: how long a "hold" step wants the key down
const DONE_S := 2.0            # s: the closing line stays up
const GOLD := Color("f2c84a")
const MINT := Color("8fe3c8")
static var _again: RegEx       # "press E again" / "recast" in a slot's JSON text, compiled once
static var _hold: RegEx        # "hold" / "held"

var m: Match
var arch := ""
var plan: Array = []           # the current Hunter's steps (steps())
var step := 0
var presses := 0               # of the current step
var held_t := 0.0
var rig_t := 0.0               # s until the tech step's dummy is set up again
var done_t := -1.0             # >= 0 once the last step is done: counting the closing line
var _panel: PanelContainer
var _key: Label
var _line: Label
var _call: Label
var _count: Label

## Adds the drill to a practice area that has dummies, once per save (Practice.attach calls this).
static func attach(p: Practice) -> void:
	var o := p.m.opts
	if o.get("tutorial", false) or o.get("duel", false) or bool(Save.d["tutorial"].get(SAVE_KEY, false)):
		return
	var k := KitDrill.new()
	k.name = NAME
	k.m = p.m
	p.add_child(k)
	k.build_ui()
	CombatBus.tech.connect(k._on_tech)
	k.start(p.m.player.arch)

## Every slot's step for a Hunter, then its signature tech (SignatureDrill): {slot, action, key, line, how ("", "again",
## "hold" or "tech")}.
static func steps(hunter_id: String) -> Array:
	var out := []
	if not Arch.exists(hunter_id):
		return out      # no Hunter picked yet ("" before the pick): nothing to drill until one is
	for slot in SLOTS:
		var action: String = ACTIONS[slot]
		out.append({"slot": slot, "action": action, "key": Settings.key_cap(action),
				"line": line(hunter_id, slot), "how": how(hunter_id, slot)})
	var tech := SignatureDrill.step(hunter_id)
	if not tech.is_empty():
		out.append(tech)
	return out

## The slot's line: the Hunter's own text for the slice Hunters, else a generic one.
static func line(hunter_id: String, slot: String) -> String:
	if hunter_id in SLICE:
		return AbilityClip.line_for(hunter_id, slot)
	var nm := String(HunterViewer.slot_info(hunter_id, slot).get("name", ""))
	return "Try %s on the dummy." % (nm if nm != "" else "it")

## What the slot's JSON text says it takes: "again" (a recast), "hold", or "" (a plain press).
static func how(hunter_id: String, slot: String) -> String:
	var d := Arch.def(hunter_id)
	var sd: Dictionary = d.get(slot, {})
	var card: Dictionary = d.get("card", {})
	var text := "%s %s %s %s" % [sd.get("hint", ""), sd.get("desc", ""), card.get(slot, ""), sd.get("variants", "")]
	if _again == null:
		_again = RegEx.create_from_string("(?i)\\b(press|tap|hit|use|click)\\b[^.]{0,20}\\bagain\\b|\\brecast")
		_hold = RegEx.create_from_string("(?i)\\bhold\\b|\\bheld\\b")
	if slot in (d.get("clip", {}) as Dictionary).get("holds", []):
		return "hold"      # the Hunter's JSON says this slot is a charged draw (Lace's bow)
	if slot == "lmb":
		return ""
	if _again.search(text) != null:
		return "again"
	return "hold" if _hold.search(text) != null else ""

## The line under the step: the call-out for a hold or the recast, in the recast HUD's words.
static func callout(st: Dictionary, pressed: int) -> String:
	match String(st["how"]):
		"again":
			return "%s AGAIN" % st["key"] if pressed > 0 else "Press %s, then %s AGAIN" % [st["key"], st["key"]]
		"hold":
			return "HOLD %s, not just a tap" % st["key"]
		"tech":
			return "The trick: %s" % st["tech"]
	return ""

func start(hunter_id: String) -> void:
	SignatureDrill.unrig(m)
	arch = hunter_id
	plan = steps(hunter_id)
	step = 0
	presses = 0
	held_t = 0.0
	done_t = -1.0
	_show()

## One press of the current step's action (the input, or a check).
func on_press(action: String) -> void:
	if done_t >= 0.0 or step >= plan.size() or action != String(plan[step]["action"]):
		return
	presses += 1
	if String(plan[step]["how"]) == "hold" or (String(plan[step]["how"]) == "again" and presses < 2):
		_show()
		return
	_next()

func on_held(action: String, dt: float) -> void:
	if done_t >= 0.0 or step >= plan.size():
		return
	var st: Dictionary = plan[step]
	if st["how"] != "hold" or action != st["action"]:
		return
	held_t += dt
	if held_t >= HOLD_S:
		_next()

## The kit reports the player's own tech (CombatBus.tech); the tech step is done by it and by nothing else.
func _on_tech(hunter: Node, id: String) -> void:
	if hunter == m.player:
		tech_done(id)

func tech_done(id: String) -> void:
	if done_t < 0.0 and step < plan.size() and plan[step]["how"] == "tech" and plan[step]["id"] == id:
		_next()

func _next() -> void:
	step += 1
	presses = 0
	held_t = 0.0
	rig_t = 0.0
	if step >= plan.size():
		SignatureDrill.unrig(m)
		done_t = 0.0
		finish()
	_show()

## Marks the drill done (or skipped) for good.
func finish() -> void:
	Save.d["tutorial"][SAVE_KEY] = true
	Save.save_game()

func _skip() -> void:
	SignatureDrill.unrig(m)
	finish()
	queue_free()

func _input(event: InputEvent) -> void:
	if m.paused or step >= plan.size():
		return
	for slot in SLOTS:
		if event.is_action_pressed(ACTIONS[slot]) and not event.is_echo():
			on_press(ACTIONS[slot])

func _process(dt: float) -> void:
	if done_t >= 0.0:
		done_t += dt
		if done_t >= DONE_S:
			queue_free()
		return
	if m.player.arch != arch:
		start(m.player.arch)      # a swap in the hero picker: the drill follows the Hunter
	elif step < plan.size() and not m.paused:
		var st: Dictionary = plan[step]
		if st["how"] == "tech":
			rig_t -= dt
			if rig_t <= 0.0:
				rig_t = float(Content.rules("signature_drills")["rearm_s"])
				SignatureDrill.rig(m, arch)
		elif Input.is_action_pressed(st["action"]):
			on_held(st["action"], dt)

func build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_panel = UI.glass(10, 14)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(_panel)
	var rows := VBoxContainer.new()
	_panel.add_child(rows)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	rows.add_child(top)
	_key = _label(top, Color.WHITE, 26)
	_line = _label(top, GOLD, 22)
	_call = _label(rows, Color.WHITE, 20)
	var bottom := HBoxContainer.new()
	rows.add_child(bottom)
	_count = _label(bottom, MINT, 16)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skip := Button.new()
	skip.text = "Skip drill"
	skip.pressed.connect(_skip)
	bottom.add_child(skip)
	if m.hud:
		m.hud.ui_extra.append(skip)       # the mouse is over UI here: no shooting, the pointer shows

func _label(parent: Node, col: Color, px: int) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", px)
	parent.add_child(l)
	return l

func _show() -> void:
	if _panel == null:
		return
	_panel.visible = not plan.is_empty()      # no steps (the player has no Hunter): no banner
	if plan.is_empty():
		return
	if step >= plan.size():
		_key.text = ""
		_line.text = "That's the kit. Try it all on the dummies."
		_call.text = ""
		_count.text = ""
		return
	var st: Dictionary = plan[step]
	_key.text = "[%s]" % st["key"]
	_line.text = st["line"]
	_call.text = callout(st, presses)
	_count.text = "%d / %d" % [step + 1, plan.size()]
