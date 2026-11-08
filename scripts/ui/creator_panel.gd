class_name CreatorPanel
extends PanelContainer
## The character creator (OWNER_REVIEW item 45): the player makes their own person with sliders and
## pickers in three tabs (Body, Face, Colours), a Randomise button, and a view switch that shows them
## as themselves or in one of their Hunters' Mantles (the Warden's likeness with a little of them in
## it, MantleLook). The host (the new-game flow, or the farm's "Change your look") stands the preview
## model and saves the look on done.

signal changed(look: Dictionary)
signal view_changed(arch: String)
signal done(look: Dictionary)

const TABS := ["Body", "Face", "Colours"]
const LABEL_W := 118.0
const VALUE_W := 176.0
const SWATCH := 24.0
const SETTLE_S := 0.12      # s: a dragged slider rebuilds the preview at most this often

var look: Dictionary = {}
var tab := "Body"
var view := ""              # "" shows you as yourself; a Hunter id shows you in its Mantle
var hunters: Array = []     # the Hunters whose Mantle you can look at here
var _body: VBoxContainer
var _dirty := false
var _settle := 0.0

## A creator for this look (PlayerLook) that can preview these Hunters' Mantles.
static func make(start: Dictionary, mantle_ids: Array) -> CreatorPanel:
	var p := CreatorPanel.new()
	p.look = PlayerLook.clean(start)
	p.hunters = mantle_ids.duplicate()
	return p

func _ready() -> void:
	add_theme_stylebox_override("panel", UI.frame(UI.CARD, UI.R_CARD, UI.RIM, 1, 16, 14))
	custom_minimum_size = Vector2(520, 0)
	_body = UI.vbox(7)
	add_child(_body)
	_build()

func _process(delta: float) -> void:
	_settle -= delta
	if _dirty and _settle <= 0.0:
		_dirty = false
		_settle = SETTLE_S
		changed.emit(look)

## The look as a fresh random person (the quick way through for players who don't mind).
func randomise() -> void:
	var keep := String(look.get("glider", "classic"))
	look = PlayerLook.random()
	look["glider"] = keep
	_build()
	changed.emit(look)

## Shows the creator on this tab.
func show_tab(t: String) -> void:
	tab = t
	_build()

func _build() -> void:
	for ch in _body.get_children():
		ch.queue_free()
	_body.add_child(UI.tabs(TABS, tab, show_tab))
	match tab:
		"Body": _body_rows()
		"Face": _face_rows()
		_: _colour_rows()
	_body.add_child(UI.spacer(4))
	_body.add_child(_view_row())
	var foot := UI.hbox(10)
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_child(UI.ghost("Randomise", randomise, 130, "swap"))
	foot.add_child(UI.primary("Looks good", func(): done.emit(look), 190))
	_body.add_child(foot)

func _body_rows() -> void:
	_pick_row("gender", "Body type", Models.LOOK_GENDERS)
	_pick_row("race", "Folk", Models.LOOK_RACES)
	_note(String(Models.RACES[int(look["race"])]["desc"]))
	_slider_rows("body")
	_note("At home you're yourself. In a Mask you take its Hunter's shape and gender, with a little of you in it.")

func _face_rows() -> void:
	var presets := UI.hbox(6)
	presets.add_child(_row_label("Start from"))
	for nm in MantleLook.rules()["presets"]:
		var preset_name := String(nm)
		presets.add_child(UI.button(preset_name, func(): _use_preset(preset_name)))
	_body.add_child(presets)
	_pick_row("face", "Expression", Models.LOOK_FACES)
	_slider_rows("face")
	_pick_row("detail", "Markings", Models.LOOK_DETAILS)

func _colour_rows() -> void:
	_swatch_row("skin", "Skin", Models.LOOK_SKIN)
	_pick_row("hair", "Hair", Models.hair_styles(int(look["race"])))
	_swatch_row("hair_col", "Hair colour", Models.LOOK_HAIR)
	_swatch_row("eyes", "Eyes", PlayerLook.EYES)
	_swatch_row("outfit", "Outfit", Models.OUTFIT_COLS)
	_note("In a Mask your colours only tint the Hunter's own; its signature colours stay.")

## Yourself, or one of your Hunters' Mantles, on the preview.
func _view_row() -> HBoxContainer:
	var row := UI.hbox(6)
	row.add_child(_row_label("See"))
	row.add_child(UI.choice("Yourself", view == "", func(): show_view("")))
	if hunters.is_empty():
		return row
	var at := maxi(0, hunters.find(view))
	var shown := String(hunters[at])
	row.add_child(UI.choice(Arch.name_of(shown) if view != "" else "In a Mask", view != "",
		func(): show_view(shown)))
	if view != "" and hunters.size() > 1:
		row.add_child(UI.icon_button("next", func(): show_view(String(hunters[(at + 1) % hunters.size()])),
			"Next Hunter", 12.0))
	return row

## Shows you as yourself ("") or in this Hunter's Mantle on the preview.
func show_view(arch: String) -> void:
	view = arch
	_build()
	view_changed.emit(view)

func _use_preset(preset_name: String) -> void:
	var p: Dictionary = MantleLook.rules()["presets"][preset_name]
	for k in p:
		look["sliders"][k] = float(p[k])
	_build()
	changed.emit(look)

func _slider_rows(group: String) -> void:
	var sliders: Dictionary = MantleLook.rules()["sliders"]
	for k in sliders:
		if String(sliders[k]["group"]) == group:
			_slider_row(String(k), String(sliders[k]["label"]))

func _slider_row(key: String, text: String) -> void:
	var row := UI.hbox(8)
	row.add_child(_row_label(text))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = float(look["sliders"][key])
	s.custom_minimum_size.x = VALUE_W + 70.0
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.set_meta("slider", key)
	s.value_changed.connect(func(v: float):
		look["sliders"][key] = v
		_dirty = true)
	row.add_child(s)
	_body.add_child(row)

func _pick_row(key: String, text: String, opts: Array) -> void:
	var row := UI.hbox(8)
	row.add_child(_row_label(text))
	row.add_child(UI.icon_button("back", func(): _step(key, -1, opts.size()), "Previous", 12.0))
	var val := UI.label(String(opts[clampi(int(look[key]), 0, opts.size() - 1)]), UI.T_BODY, UI.INK, UI.semi)
	val.custom_minimum_size.x = VALUE_W
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(val)
	row.add_child(UI.icon_button("next", func(): _step(key, 1, opts.size()), "Next", 12.0))
	_body.add_child(row)

func _step(key: String, d: int, n: int) -> void:
	look[key] = posmod(int(look[key]) + d, n)
	if key == "race":
		# each folk starts in its own colouring and on its own first head style
		look["skin"] = int(Models.RACES[int(look["race"])]["skin"])
		look["hair"] = 0
	_build()
	changed.emit(look)

func _swatch_row(key: String, text: String, cols: Array) -> void:
	var row := UI.hbox(8)
	var lbl := _row_label(text)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(lbl)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	flow.custom_minimum_size.x = VALUE_W + 180.0
	for i in cols.size():
		flow.add_child(_swatch(key, i, cols[i]))
	row.add_child(flow)
	_body.add_child(row)

func _swatch(key: String, i: int, col: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SWATCH, SWATCH)
	b.focus_mode = Control.FOCUS_ALL
	var on := int(look[key]) == i
	var edge := UI.ACCENT if on else Color(1, 1, 1, 0.2)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, UI.frame(col, UI.R_SMALL, edge, 3 if on else 1))
	b.set_meta("swatch", "%s:%d" % [key, i])
	b.pressed.connect(func():
		Sfx.play("hover", null, -6.0)
		look[key] = i
		_build()
		changed.emit(look))
	return b

func _row_label(text: String) -> Label:
	var l := UI.label(text, UI.T_BODY, UI.MUTED)
	l.custom_minimum_size.x = LABEL_W
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

func _note(text: String) -> void:
	var l := UI.label(text, UI.T_SMALL, UI.ACCENT_HI)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 380
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(LABEL_W) + 8)
	m.add_child(l)
	_body.add_child(m)
