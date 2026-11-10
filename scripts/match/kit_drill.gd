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
	k.start(p.m.player.arch)

## Every slot's step for a Hunter: {slot, action, key, line, how ("", "again" or "hold")}.
static func steps(hunter_id: String) -> Array:
	var out := []
	for slot in SLOTS:
		var action: String = ACTIONS[slot]
		out.append({"slot": slot, "action": action, "key": Settings.key_cap(action),
				"line": line(hunter_id, slot), "how": how(hunter_id, slot)})
	return out

## The slot's line: the Hunter's own text for the slice Hunters, else a generic one.
static func line(hunter_id: String, slot: String) -> String:
	if hunter_id in SLICE:
		return AbilityClip.line_for(hunter_id, slot)
	var nm := String(HunterViewer.slot_info(hunter_id, slot)["name"])
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
	return ""

func start(hunter_id: String) -> void:
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

func _next() -> void:
	step += 1
	presses = 0
	held_t = 0.0
	if step >= plan.size():
		done_t = 0.0
		finish()
	_show()

## Marks the drill done (or skipped) for good.
func finish() -> void:
	Save.d["tutorial"][SAVE_KEY] = true
	Save.save_game()

func _skip() -> void:
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
	elif step < plan.size() and not m.paused and Input.is_action_pressed(plan[step]["action"]):
		on_held(plan[step]["action"], dt)

func build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
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
