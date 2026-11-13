class_name CreatorPanel
extends PanelContainer
## The Empty's creator (docs/CHARACTER_CREATOR.md): three tabs over the turntable preview the host stands. Body: sex,
## the frame sliders, the void tint and outline, a preset to start from, the features your Relics left (MasteryLook:
## keep or fade each). Outfit: one row per layer (top, bottom,
## shoes, gloves, headwear, cloak, accessory), each one item or empty; the chosen row's colours show below it, on one
## palette. Face: hair, eyes, face marks, aura. Undo steps back through every change; Randomize rolls a whole person.
## Mouse or gamepad: every control takes focus (d-pad / stick to move, A to press, left / right on a slider),
## LB / RB change tab, X undoes, Y randomizes. The host saves the look on done.

signal changed(look: Dictionary)
signal done(look: Dictionary)

const TABS := ["Body", "Outfit", "Face"]
const LABEL_W := 112.0
const VALUE_W := 168.0
const SWATCH := 22.0
const SETTLE_S := 0.12      # s: a dragged slider rebuilds the preview at most this often
const UNDO_MAX := 60        # looks kept to step back through
const NAME_MAX := 16        # characters

var look: Dictionary = {}
var tab := "Body"
var slot_open := "top"      # the Outfit row whose colours show
var player_name := "Hunter"
var _body: VBoxContainer
var _history: Array = []
var _dirty := false
var _settle := 0.0
var _preset := 0

## A creator starting from this look.
static func make(start: Dictionary) -> CreatorPanel:
	var p := CreatorPanel.new()
	p.look = Unmasked.clean(start)
	return p

func _ready() -> void:
	add_theme_stylebox_override("panel", UI.frame(UI.CARD, UI.R_CARD, UI.RIM, 1, 16, 14))
	custom_minimum_size = Vector2(560, 0)
	_body = UI.vbox(7)
	add_child(_body)
	_build()

func _process(delta: float) -> void:
	_settle -= delta
	if _dirty and _settle <= 0.0:
		_dirty = false
		_settle = SETTLE_S
		changed.emit(look)

func _unhandled_input(event: InputEvent) -> void:
	var jb := event as InputEventJoypadButton
	if jb == null or not jb.pressed:
		return
	match jb.button_index:
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
			var step := 1 if jb.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
			show_tab(TABS[posmod(TABS.find(tab) + step, TABS.size())])
		JOY_BUTTON_X:
			undo()
		JOY_BUTTON_Y:
			randomize_look()
		_:
			return
	get_viewport().set_input_as_handled()

## A whole new random person (the quick way through for players who don't mind).
func randomize_look() -> void:
	_remember()
	var keep := String(look.get("glider", "classic"))
	var feats: Dictionary = look.get("features", {})
	look = Unmasked.clean(Unmasked.random_look())
	look["glider"] = keep
	look["features"] = feats.duplicate()
	_changed()

## Steps back to the look before the last change.
func undo() -> void:
	if _history.is_empty():
		return
	look = _history.pop_back()
	_changed()

## Shows the creator on this tab.
func show_tab(t: String) -> void:
	tab = t
	_build()

## Puts this item on in an Outfit slot (EmptyWear.NONE takes the slot off) and opens its colours.
func pick_item(id: String, it: int) -> void:
	_remember()
	EmptyWear.set_item(look, id, it)
	slot_open = id
	_changed()

## Colours an Outfit slot's k-th colour slot from the palette.
func pick_colour(id: String, k: int, ci: int) -> void:
	_remember()
	EmptyWear.set_colour(look, id, k, ci)
	_changed()

## Starts from a preset (content/rules/empty_creator.json "presets"), over a bare body.
func use_preset(preset_name: String) -> void:
	_remember()
	var keep := String(look.get("glider", "classic"))
	var feats: Dictionary = look.get("features", {})
	look = Unmasked.default_look()
	look.merge((EmptyFrame.rules()["presets"][preset_name] as Dictionary).duplicate(true), true)
	look["glider"] = keep
	look["features"] = feats
	look = Unmasked.clean(look)
	_changed()

func _remember() -> void:
	_history.append(look.duplicate(true))
	if _history.size() > UNDO_MAX:
		_history.pop_front()

func _changed() -> void:
	_build()
	changed.emit(look)

func _build() -> void:
	var focus_key := _focus_key()
	for ch in _body.get_children():
		ch.queue_free()
	_body.add_child(UI.tabs(TABS, tab, show_tab))
	match tab:
		"Body":
			_body_rows()
		"Outfit":
			_outfit_rows()
		_:
			_face_rows()
	_body.add_child(UI.spacer(4))
	var foot := UI.hbox(10)
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_child(_keyed(UI.ghost("Undo", undo, 96), "undo"))
	foot.add_child(_keyed(UI.ghost("Randomize", randomize_look, 130, "swap"), "random"))
	foot.add_child(_keyed(UI.primary("Looks good", func(): done.emit(look), 170), "done"))
	_body.add_child(foot)
	_refocus.call_deferred(focus_key)

# ------------------------------------------------------------------------------------------ tabs
func _body_rows() -> void:
	var name_row := UI.hbox(8)
	name_row.add_child(_row_label("Your name"))
	var ne := LineEdit.new()
	ne.text = player_name
	ne.max_length = NAME_MAX
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.text_changed.connect(func(t: String): player_name = t.strip_edges() if t.strip_edges() != "" else "Hunter")
	name_row.add_child(_keyed(ne, "name"))
	_body.add_child(name_row)
	_pick_row("gender", "Sex", Unmasked.SEXES)
	var frame: Dictionary = EmptyFrame.rules()["frame"]
	for k in EmptyFrame.KEYS:
		_slider_row(String(k), String(frame[k]["label"]))
	_swatch_row("void", "Body", Unmasked.VOID_TINTS)
	_swatch_row("line", "Outline", Unmasked.LINES)
	var names: Array = EmptyFrame.rules()["presets"].keys()
	var row := UI.hbox(8)
	row.add_child(_row_label("Start from"))
	row.add_child(_keyed(UI.icon_button("back", func(): _step_preset(names, -1), "Previous", 12.0), "preset:prev"))
	row.add_child(_value(String(names[_preset % names.size()])))
	row.add_child(_keyed(UI.icon_button("next", func(): _step_preset(names, 1), "Next", 12.0), "preset:next"))
	row.add_child(_keyed(UI.button("Use", func(): use_preset(String(names[_preset % names.size()]))), "preset:use"))
	_body.add_child(row)
	_mastery_rows()

func _step_preset(names: Array, d: int) -> void:
	_preset = posmod(_preset + d, names.size())
	_build()

func _outfit_rows() -> void:
	for s in EmptyWear.slots():
		_item_row(s)
	var open := EmptyWear.slot(slot_open)
	if EmptyWear.item(look, slot_open) == EmptyWear.NONE:
		return
	_body.add_child(UI.section(String(open["label"])))
	var cols: Array = open["cols"]
	for k in cols.size():
		_palette_row(slot_open, k, String(cols[k]))
	if slot_open == "back" and Shrouds.has_hood(int(look["shroud"])):
		_pick_row("hood", "Hood", Shrouds.HOODS)
	if slot_open == "back":
		_pick_row("trim", "Trim", Shrouds.TRIMS)

## The features your Relics left (MasteryLook), each kept on the character or faded.
func _mastery_rows() -> void:
	var on: Dictionary = look.get("features", {})
	var feats := MasteryLook.features().filter(func(f): return on.has(String(f["id"])))
	if feats.is_empty():
		return
	_body.add_child(UI.label("Left by your Relics", 12, UI.ACCENT, UI.caps))
	for f in feats:
		var id := String(f["id"])
		var hr := UI.hbox(8)
		var l := UI.label("%s  (%s)" % [f["name"], HeroTitle.base_name(String(f["hunter"]))], UI.T_BODY, UI.MUTED)
		l.custom_minimum_size.x = 250
		hr.add_child(l)
		var b := UI.ghost("Keep" if bool(on[id]) else "Faded", func():
			_remember()
			MasteryLook.toggle(look, id)
			_changed(), 120)
		b.name = "Feature_%s" % id
		hr.add_child(_keyed(b, "feature:" + id))
		_body.add_child(hr)

func _face_rows() -> void:
	for r in range(Unmasked.FACE_ROW, Unmasked.ROWS.size()):
		var row: Array = Unmasked.ROWS[r]
		if row[2][0] is Color:
			_swatch_row(row[0], row[1], row[2])
		else:
			_pick_row(row[0], row[1], row[2], String(row[3]) if row.size() > 3 else "")

# ------------------------------------------------------------------------------------------ rows
## One Outfit slot: its name (press it to show its colours), the item stepping through empty and every item.
func _item_row(s: Dictionary) -> void:
	var id := String(s["id"])
	var n := EmptyWear.items(id).size()
	var it := EmptyWear.item(look, id)
	var row := UI.hbox(8)
	var name_btn := UI.choice(String(s["label"]), id == slot_open, func():
		slot_open = id
		_build(), LABEL_W)
	row.add_child(_keyed(name_btn, "slot:%s" % id))
	var step := func(d: int) -> void: pick_item(id, posmod(it + 1 + d, n + 1) - 1)
	row.add_child(_keyed(UI.icon_button("back", step.bind(-1), "Previous", 12.0), "slot:%s:prev" % id))
	row.add_child(_value("None" if it == EmptyWear.NONE else String(EmptyWear.items(id)[it])))
	row.add_child(_keyed(UI.icon_button("next", step.bind(1), "Next", 12.0), "slot:%s:next" % id))
	if it != EmptyWear.NONE:
		var ci := EmptyWear.colour(look, id, 0)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(SWATCH, SWATCH)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var shown: Color = Unmasked.COLOURS[ci] if ci >= 0 else Unmasked.COLOURS[look["colour"]]
		dot.add_theme_stylebox_override("panel", UI.frame(shown, UI.R_SMALL, Color(1, 1, 1, 0.25)))
		row.add_child(dot)
	_body.add_child(row)

func _palette_row(id: String, k: int, text: String) -> void:
	var row := UI.hbox(8)
	var lbl := _row_label(text)
	row.add_child(lbl)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 3)
	flow.custom_minimum_size.x = VALUE_W + 240.0
	var on := EmptyWear.colour(look, id, k)
	for ci in Unmasked.COLOURS.size():
		var b := _swatch(Unmasked.COLOURS[ci], ci == on, func(): pick_colour(id, k, ci))
		flow.add_child(_keyed(b, "pal:%s:%d:%d" % [id, k, ci]))
	row.add_child(flow)
	_body.add_child(row)

func _slider_row(key: String, text: String) -> void:
	var row := UI.hbox(8)
	row.add_child(_row_label(text))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.02
	s.value = float(look["frame"][key])
	s.custom_minimum_size.x = VALUE_W + 90.0
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	s.drag_started.connect(_remember)
	s.value_changed.connect(func(v: float):
		look["frame"][key] = snappedf(v, EmptyFrame.STEP)
		_dirty = true)
	row.add_child(_keyed(s, "slider:%s" % key))
	_body.add_child(row)

func _pick_row(key: String, text: String, opts: Array, tip := "") -> void:
	var row := UI.hbox(8)
	var lbl := _row_label(text)
	if tip != "":
		lbl.tooltip_text = tip
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(lbl)
	var step := func(d: int) -> void:
		_remember()
		look[key] = posmod(int(look.get(key, 0)) + d, opts.size())
		_changed()
	row.add_child(_keyed(UI.icon_button("back", step.bind(-1), "Previous", 12.0), "pick:%s:prev" % key))
	row.add_child(_value(String(opts[clampi(int(look.get(key, 0)), 0, opts.size() - 1)])))
	row.add_child(_keyed(UI.icon_button("next", step.bind(1), "Next", 12.0), "pick:%s:next" % key))
	_body.add_child(row)

func _swatch_row(key: String, text: String, cols: Array) -> void:
	var row := UI.hbox(8)
	row.add_child(_row_label(text))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 3)
	flow.custom_minimum_size.x = VALUE_W + 240.0
	for i in cols.size():
		var pick := func() -> void:
			_remember()
			look[key] = i
			_changed()
		flow.add_child(_keyed(_swatch(cols[i], int(look[key]) == i, pick), "sw:%s:%d" % [key, i]))
	row.add_child(flow)
	_body.add_child(row)

func _swatch(col: Color, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SWATCH, SWATCH)
	b.focus_mode = Control.FOCUS_ALL
	var edge := UI.ACCENT if on else Color(1, 1, 1, 0.2)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, UI.frame(col, UI.R_SMALL, edge, 3 if on else 1))
	b.add_theme_stylebox_override("focus", UI.frame(Color(0, 0, 0, 0), UI.R_SMALL, UI.INK, 2))
	b.pressed.connect(func():
		Sfx.play("hover", null, -6.0)
		cb.call())
	return b

func _value(text: String) -> Label:
	var val := UI.label(text, UI.T_BODY, UI.INK, UI.semi)
	val.custom_minimum_size.x = VALUE_W
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return val

func _row_label(text: String) -> Label:
	var l := UI.label(text, UI.T_BODY, UI.MUTED)
	l.custom_minimum_size.x = LABEL_W
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

# ------------------------------------------------------------------------------------------ focus
## Tags a control so the same one takes focus again after the panel is rebuilt (a gamepad keeps its place).
func _keyed(ctl: Control, key: String) -> Control:
	ctl.set_meta("fk", key)
	ctl.focus_mode = Control.FOCUS_ALL
	return ctl

func _focus_key() -> String:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return String(f.get_meta("fk", "")) if f and is_ancestor_of(f) else ""

func _refocus(key: String) -> void:
	var first: Control = null
	for top in _body.get_children():
		if top.is_queued_for_deletion():
			continue
		for ctl in [top] + top.find_children("*", "Control", true, false):
			if not ctl.has_meta("fk"):
				continue
			if String(ctl.get_meta("fk")) == key:
				(ctl as Control).grab_focus()
				return
			if first == null:
				first = ctl
	if first and get_viewport().gui_get_focus_owner() == null:
		first.grab_focus()
