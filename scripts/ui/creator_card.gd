class_name CreatorCard
extends PanelContainer
## The card of the Empty creator (Hatch, "Make yourself"): a row per look (Unmasked.ROWS) with a small die
## that rerolls just that row, a Random button for all of them, one step of undo and redo, and (under
## "More looks...") a row of starter presets. A new player sees three rows first; the rest open with More.
## The host stands the preview model and saves the look: it listens for changed and done.

signal changed(look: Dictionary)
signal done

const LABEL_W := 120.0
const VALUE_W := 170.0
## Starter looks (the first row of More): every row of Unmasked.ROWS except Sex, which stays yours.
const PRESETS := {
	"Calm": {"height": 1, "build": 1, "shroud": 0, "colour": 4, "hollow": 0, "glow": 5, "ghost": 0, "aura": 1},
	"Fierce": {"height": 2, "build": 2, "shroud": 3, "colour": 5, "hollow": 2, "glow": 1, "ghost": 1, "aura": 2},
	"Spooky": {"height": 2, "build": 0, "shroud": 2, "colour": 8, "hollow": 3, "glow": 2, "ghost": 3, "aura": 2},
	"Cosy": {"height": 0, "build": 2, "shroud": 4, "colour": 6, "hollow": 0, "glow": 4, "ghost": 0, "aura": 1},
	"Moonlit": {"height": 1, "build": 0, "shroud": 6, "colour": 2, "hollow": 1, "glow": 0, "ghost": 2, "aura": 1},
	"Sunny": {"height": 0, "build": 1, "shroud": 8, "colour": 7, "hollow": 0, "glow": 4, "ghost": 0, "aura": 2},
}

var look: Dictionary = {}
var all_rows := false          # every row and the presets (false: the three first rows and More looks...)
var _before: Dictionary = {}   # the look one change ago (Undo)
var _after: Dictionary = {}    # the look Undo just left (Redo)
var _rows: VBoxContainer

## A creator for this look. The name row edits Save.d["name"].
static func make(start: Dictionary, every_row: bool) -> CreatorCard:
	var c := CreatorCard.new()
	c.look = start.duplicate(true)
	c.all_rows = every_row
	return c

func _init() -> void:
	add_theme_stylebox_override("panel", UI.card(UI.CARD, 14, 16).get_theme_stylebox("panel"))
	custom_minimum_size = Vector2(500, 0)

func _ready() -> void:
	var v := UI.vbox(8)
	add_child(v)
	_rows = UI.vbox(8)
	v.add_child(_rows)
	v.add_child(_name_row())
	v.add_child(_foot())
	_build()

func _build() -> void:
	for ch in _rows.get_children():
		_rows.remove_child(ch)
		ch.queue_free()
	if all_rows:
		_rows.add_child(_preset_row())
	for r in Unmasked.ROWS.size():
		if not all_rows and not r in Unmasked.FIRST_ROWS:
			continue
		if all_rows and (r == 0 or r == Unmasked.HOLLOW_ROW):
			_rows.add_child(UI.label("Body" if r == 0 else "The hollow", 12, UI.ACCENT, UI.caps))
		_rows.add_child(_row(Unmasked.ROWS[r]))
	if not all_rows:
		_rows.add_child(UI.ghost("More looks...", func():
			all_rows = true
			_build()))

func _row(row: Array) -> HBoxContainer:
	var key: String = row[0]
	var opts: Array = row[2]
	var hr := UI.hbox(8)
	var l := UI.label(row[1], UI.T_BODY, UI.MUTED)
	l.custom_minimum_size.x = LABEL_W
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if row.size() > 3:
		l.tooltip_text = row[3]
		l.mouse_filter = Control.MOUSE_FILTER_STOP
	hr.add_child(l)
	hr.add_child(UI.icon_button("back", func(): _step(key, -1, opts.size()), "Previous", 12.0))
	var i := int(look[key])
	if opts[0] is Color:
		var sw := Panel.new()
		sw.custom_minimum_size = Vector2(VALUE_W, 26)
		sw.add_theme_stylebox_override("panel", UI.frame(opts[i], 13, Color(1, 1, 1, 0.25)))
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(sw)
	else:
		var val := UI.label(String(opts[i]), UI.T_BODY, UI.INK, UI.semi)
		val.custom_minimum_size.x = VALUE_W
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hr.add_child(val)
	hr.add_child(UI.icon_button("next", func(): _step(key, 1, opts.size()), "Next", 12.0))
	var die := UI.icon_button("die", func(): _reroll(key, opts.size()), "Pick another at random", 12.0)
	die.set_meta("die", key)
	hr.add_child(die)
	return hr

func _preset_row() -> HFlowContainer:
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	var l := UI.label("Start from", UI.T_BODY, UI.MUTED)
	l.custom_minimum_size.x = LABEL_W
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fl.add_child(l)
	for nm in PRESETS:
		var preset_name: String = nm
		fl.add_child(UI.button(preset_name, func(): _use_preset(preset_name)))
	return fl

func _name_row() -> HBoxContainer:
	var nr := UI.hbox(8)
	var nl := UI.label("Your name", UI.T_BODY, UI.MUTED)
	nl.custom_minimum_size.x = LABEL_W
	nr.add_child(nl)
	var ne := LineEdit.new()
	ne.text = Save.d.get("name", "Hunter")
	ne.max_length = 16
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.text_changed.connect(func(t): Save.d["name"] = t.strip_edges() if t.strip_edges() != "" else "Hunter")
	nr.add_child(ne)
	return nr

var _undo_btn: Button
var _redo_btn: Button

func _foot() -> HBoxContainer:
	var br := UI.hbox(8)
	_undo_btn = UI.ghost("Undo", undo, 0.0, "back")
	_redo_btn = UI.ghost("Redo", redo, 0.0, "next")
	br.add_child(_undo_btn)
	br.add_child(_redo_btn)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(gap)
	br.add_child(UI.ghost("Random", func(): _apply(Unmasked.random_look()), 0.0, "swap"))
	br.add_child(UI.primary("Looks good", func(): done.emit(), 150))
	_sync_buttons()
	return br

## Makes this the look (one undoable change) and tells the host.
func _apply(next: Dictionary) -> void:
	next["marks"] = look.get("marks", [])
	_before = look
	_after = {}
	look = next
	_changed()

func _step(key: String, d: int, n: int) -> void:
	var next := look.duplicate(true)
	next[key] = posmod(int(look[key]) + d, n)
	Sfx.play("hover", null, -6.0)
	_apply(next)

## Another value for this row only (never the one it has now).
func _reroll(key: String, n: int) -> void:
	var next := look.duplicate(true)
	next[key] = (int(look[key]) + 1 + randi() % maxi(1, n - 1)) % n
	Sfx.play("hover", null, -6.0)
	_apply(next)

func _use_preset(preset_name: String) -> void:
	var next := look.duplicate(true)
	next.merge(PRESETS[preset_name], true)
	_apply(next)

func undo() -> void:
	if _before.is_empty():
		return
	_after = look
	look = _before
	_before = {}
	_changed()

func redo() -> void:
	if _after.is_empty():
		return
	_before = look
	look = _after
	_after = {}
	_changed()

func _changed() -> void:
	_build()
	_sync_buttons()
	changed.emit(look)

func _sync_buttons() -> void:
	_undo_btn.disabled = _before.is_empty()
	_redo_btn.disabled = _after.is_empty()
