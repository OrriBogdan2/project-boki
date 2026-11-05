class_name TalkBox
extends CanvasLayer
## A face-to-face conversation box (Hob on the farm: FarmHob): the speaker's portrait and name, one short line
## at a time typed out, advanced with a click or the interact key (a click while it types finishes the line).
## A line is {text, show?, pose?}: line_shown tells the speaker's side which line is up, so it can point at
## what he talks about. show_extra() puts something to choose from in the box's place (the Mask offer); while
## it is up the lines don't advance.
##
##   var box := TalkBox.open(home, "Hob Brackenridge", HobModel.portrait(112.0))
##   box.say([{"text": "Hello!"}], func(): box.close())

signal line_shown(i: int, line: Dictionary)
signal closed

const WIDTH := 820.0           # px
const FACE_PX := 112.0
const CHARS_PER_S := 55.0      # how fast a line types out

var lines: Array = []
var i := -1
var then := Callable()
var panel: PanelContainer
var text: Label
var hint: Label
var extra: Control
var _type_tw: Tween

static func open(host: Node, who: String, face: Control) -> TalkBox:
	var box := TalkBox.new()
	box.layer = 45
	host.add_child(box)
	box._build(who, face)
	return box

func _build(who: String, face: Control) -> void:
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_theme_constant_override("margin_bottom", 36)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var col := UI.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(col)
	extra = CenterContainer.new()
	extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(extra)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(center)
	panel = UI.card(Color(0.06, 0.055, 0.09, 0.95), 14)
	UI.set_card_border(panel, Color(UI.GOLD, 0.55), 2)
	panel.custom_minimum_size.x = WIDTH
	panel.gui_input.connect(func(ev): if _is_click(ev): advance())
	center.add_child(panel)
	var row := UI.hbox(16)
	panel.add_child(row)
	var frame := UI.card(Color(0.16, 0.14, 0.2), 4, 10)
	frame.add_child(face)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	var right := UI.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(UI.title(who, 24, UI.GOLD))
	text = UI.label("", 21, UI.INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(WIDTH - FACE_PX - 90.0, 64.0)
	right.add_child(text)
	hint = UI.label("", UI.T_SMALL, UI.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(hint)
	UI.pop_in(panel)

## Says these lines one at a time; `after` runs when the last one is clicked past.
func say(new_lines: Array, after := Callable()) -> void:
	lines = new_lines
	then = after
	i = -1
	advance()

## The next line (or the rest of this one, while it is still typing).
func advance() -> void:
	if extra.get_child_count() > 0:
		return
	if _type_tw and _type_tw.is_running():
		_type_tw.kill()
		text.visible_ratio = 1.0
		return
	i += 1
	if i >= lines.size():
		if then.is_valid():
			then.call()
		return
	var line: Dictionary = lines[i]
	text.text = String(line["text"])
	text.visible_ratio = 0.0
	_type_tw = create_tween()
	_type_tw.tween_property(text, "visible_ratio", 1.0, text.text.length() / CHARS_PER_S)
	hint.text = "Click or %s  ▸" % Settings.key_cap("interact")
	Sfx.play("click", null, -14.0, 0.15)
	line_shown.emit(i, line)

## Something to choose from in place of the box (the lines wait until clear_extra()).
func show_extra(c: Control) -> void:
	clear_extra()
	extra.add_child(c)
	panel.visible = false
	UI.pop_in(c)

func clear_extra() -> void:
	for c in extra.get_children():
		extra.remove_child(c)
		c.queue_free()
	panel.visible = true

func close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or _is_click(event):
		get_viewport().set_input_as_handled()
		advance()

func _is_click(ev: InputEvent) -> bool:
	var mb := ev as InputEventMouseButton
	return mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
