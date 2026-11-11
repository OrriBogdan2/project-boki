class_name TrainingPanel
extends RefCounted
## The Training Grounds's one controls panel (top right): every practice key with its state
## and your damage numbers. Each row is also a button. H folds it to a single "H Controls" chip and back
## (the HUD's guide_hidden). Built and ticked by Arena.

const MARGIN := 16               # px from the top right corner (the minimap has the top left)
const WIDTH := 236.0             # px
const ROW_H := 26.0              # px, one row

var a: Arena
var panel: PanelContainer = null
var chip: PanelContainer = null
var dps: Label = null
var states := {}                 # row id -> Label (the state on the right)

func _init(arena: Arena, layer: CanvasLayer) -> void:
	a = arena
	panel = UI.glass(10, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var v := UI.vbox(2)
	panel.add_child(v)
	var hd := UI.hbox(6)
	hd.add_child(UI.label("Training Grounds", UI.T_BODY, UI.INK, UI.big))
	hd.add_child(UI.fill())
	hd.add_child(UI.keycap("H", 11))
	hd.add_child(UI.label("hide", 12, UI.FAINT))
	v.add_child(hd)
	for r in rows():
		v.add_child(_row(r))
	dps = UI.label("", UI.T_SMALL, UI.MUTED)
	v.add_child(dps)
	chip = UI.glass(6, 10)
	var cr := UI.hbox(6)
	cr.add_child(UI.keycap("H", 11))
	cr.add_child(UI.label("Controls", UI.T_SMALL, UI.MUTED))
	chip.add_child(cr)
	layer.add_child(chip)
	chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if a.m.hud:
		a.m.hud.ui_extra.append(panel)       # the mouse is over UI here: no shooting, the pointer shows
	refresh()

## [id, key cap, what it does, action]. The state (right) comes from state_of.
func rows() -> Array:
	return [
		["card", "K", "Kit card", a.toggle_card],
		["menu", "L", "Loadout and bot", a.open_menu],
		["swap", "2-9", "Quick Hunter swap", a.open_menu],
		["reset", "Bksp", "Reset", a.reset],
		["bot", "N", "Sparring bot", a.cycle_bot],
		["cd", "O", "Cooldowns", a.toggle_cd],
		["ult", "U", "Ultimate", a.toggle_ult],
		["leave", "", "Leave", func(): Practice.leave(a.m, true)],
	]

func state_of(id: String) -> String:
	match id:
		"bot": return Arena.BOT_NAMES[a.bot_mode]
		"cd": return "off" if a.cd_off else "on"
		"ult": return "unlocked" if a.ult_on else "locked"
	return ""

func _row(r: Array) -> Button:
	var b := UI.button("", r[3])
	b.theme_type_variation = "Ghost"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, ROW_H)
	var h := UI.hbox(8)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 4
	h.offset_right = -4
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var kc: Control = UI.keycap(String(r[1]), 11) if String(r[1]) != "" else Control.new()
	kc.custom_minimum_size.x = 38
	h.add_child(kc)
	h.add_child(UI.label(String(r[2]), UI.T_SMALL, UI.INK))
	h.add_child(UI.fill())
	var st := UI.label("", UI.T_SMALL, UI.TEAL, UI.semi)
	h.add_child(st)
	states[String(r[0])] = st
	for c in h.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

## The row states, after a toggle.
func refresh() -> void:
	for id in states:
		(states[id] as Label).text = state_of(id)

## Per frame: shown or folded, and the damage line (only rewritten when it changes).
func tick(hidden: bool) -> void:
	panel.visible = not hidden
	chip.visible = hidden and not Record.clean()
	var line := "DPS %d   ·   dealt %d" % [int(round(Arena.dps_of(a.hits_all, a.m.time))), int(round(a.dealt))]
	if dps.text != line:
		dps.text = line
