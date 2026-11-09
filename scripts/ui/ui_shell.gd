class_name UiShell
## The panel shell of the menu kit: title, close X, tabs, body, footer, confirm boxes and toasts.

# ---------------------------------------------------------------- the panel shell
## A menu panel, the same everywhere: a title (and an optional subtitle) with a close X at the top
## right, an optional row of tabs, the body, and an optional footer of actions at the bottom right.
## The body pages (or, with scroll, scrolls) whenever it's taller than the window, so nothing ends up
## off screen. Returns [panel, body]; use subtitle(body, ...), shell_tabs(body, ...), footer(body)
## and head_extra(body) to fill the rest.
static func scroll_panel(title_txt: String, width: float, on_close: Callable, close_txt := "Close", scroll := false) -> Array:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.theme_type_variation = ""
	var outer := UI.vbox(UI.GAP_BIG - 4)
	p.add_child(outer)
	var top := UI.vbox(UI.GAP)
	outer.add_child(top)
	var head := UI.hbox(UI.GAP)
	if on_close.is_valid() and close_txt == "Back":
		# a sub-page: the way back sits before the title
		var bb := UiWidgets.icon_button("back", on_close, "Back  (Esc)", 14.0)
		bb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		bb.focus_mode = Control.FOCUS_NONE
		bb.name = "Close"
		head.add_child(bb)
	var tcol := UI.vbox(2); tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := UiText.title(title_txt, UI.T_TITLE, UI.INK)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tcol.add_child(t)
	var sub := UiText.label("", UI.T_SMALL + 1, UI.MUTED)
	sub.visible = false
	tcol.add_child(sub)
	head.add_child(tcol)
	var extra := UI.hbox(8)
	extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(extra)
	if on_close.is_valid() and close_txt != "Back":
		var xb := UiWidgets.icon_button("close", on_close, close_txt + "  (Esc)", 14.0)
		xb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		xb.focus_mode = Control.FOCUS_NONE     # Esc does it; keep it out of the keyboard path
		xb.name = "Close"
		head.add_child(xb)
	top.add_child(head)
	var tabs_slot := UI.vbox(0)
	tabs_slot.visible = false
	top.add_child(tabs_slot)
	var body := UI.vbox(UI.GAP)
	var foot := UI.hbox(10)
	foot.visible = false
	foot.alignment = BoxContainer.ALIGNMENT_END
	var foot_left := UI.hbox(12)
	foot_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(foot_left)
	var foot_right := UI.hbox(10)
	foot.add_child(foot_right)
	if scroll:
		# a real scroll for long lists like Settings: grows with its content up to the window height
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pad := MarginContainer.new(); pad.add_theme_constant_override("margin_right", 14)
		pad.add_theme_constant_override("margin_left", 3); pad.add_theme_constant_override("margin_top", 3); pad.add_theme_constant_override("margin_bottom", 3)
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pad.add_child(body)
		sc.add_child(pad)
		outer.add_child(sc)
		var fit := func() -> void:
			if is_instance_valid(sc) and sc.is_inside_tree():
				var chrome := top.get_combined_minimum_size().y + (foot.get_combined_minimum_size().y + UI.GAP_BIG if foot.visible else 0.0)
				sc.custom_minimum_size.y = minf(pad.get_combined_minimum_size().y, sc.get_viewport_rect().size.y - 110.0 - chrome)
		body.minimum_size_changed.connect(func(): fit.call_deferred())
		top.minimum_size_changed.connect(func(): fit.call_deferred())
		foot.visibility_changed.connect(func(): fit.call_deferred())
		sc.tree_entered.connect(func(): fit.call_deferred())
		body.set_meta("scroll", sc)
	else:
		outer.add_child(UI.paged(body, 110.0, title_txt, top, width - UI.PAD * 2.0, foot))
	outer.add_child(foot)
	body.set_meta("shell", p)
	p.set_meta("key", title_txt)
	p.set_meta("title", t); p.set_meta("sub", sub); p.set_meta("extra", extra)
	p.set_meta("tabs", tabs_slot); p.set_meta("foot", foot); p.set_meta("foot_left", foot_left); p.set_meta("foot_right", foot_right)
	var fitw := func():
		if is_instance_valid(p) and p.is_inside_tree():
			p.custom_minimum_size.x = minf(width, p.get_viewport_rect().size.x - 32.0)
	p.tree_entered.connect(func(): fitw.call_deferred())
	p.custom_minimum_size.x = width
	# keyboard and pad users start on the first thing they can press
	p.tree_entered.connect(func(): UI.focus_first(p))
	return [p, body]

static func _shell_of(body: Control) -> PanelContainer:
	var n: Node = body
	while n:
		if n.has_meta("shell"): return n.get_meta("shell")
		if n.has_meta("foot"): return n as PanelContainer
		n = n.get_parent()
	return null

## A short line under a panel's title.
static func subtitle(body: Control, txt: String) -> void:
	var p := _shell_of(body)
	if p == null: return
	var s: Label = p.get_meta("sub")
	s.text = txt
	s.visible = txt != ""

## Changes a panel's title.
static func set_title(body: Control, txt: String) -> void:
	var p := _shell_of(body)
	if p: (p.get_meta("title") as Label).text = txt

## Puts a small control (a Boki's sex icon) right after the panel's title.
static func title_icon(body: Control, c: Control) -> void:
	var p := _shell_of(body)
	if p == null: return
	var t: Label = p.get_meta("title")
	var row: HBoxContainer = p.get_meta("title_row") if p.has_meta("title_row") else null
	if row == null:
		row = UI.hbox(10)
		var par := t.get_parent()
		var at := t.get_index()
		par.remove_child(t)
		row.add_child(t)
		par.add_child(row)
		par.move_child(row, at)
		t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		t.clip_text = false          # (a clipped or trimmed label in a row collapses to nothing)
		t.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		p.set_meta("title_row", row)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)

## A row next to the close X for chips and small things (gems, stored count).
static func head_extra(body: Control) -> HBoxContainer:
	var p := _shell_of(body)
	return p.get_meta("extra") if p else UI.hbox()

## Tabs under the title (a segmented control). Returns the tabs control.
static func shell_tabs(body: Control, names: Array, cur: String, cb: Callable, counts := {}) -> Control:
	var p := _shell_of(body)
	var tb := UiWidgets.tabs(names, cur, cb, counts)
	if p == null:
		body.add_child(tb)
		return tb
	var slot: VBoxContainer = p.get_meta("tabs")
	for ch in slot.get_children(): ch.queue_free()
	slot.add_child(tb)
	slot.visible = true
	return tb

## The footer's action row (bottom right). Add buttons to it; the primary goes last.
static func footer(body: Control) -> HBoxContainer:
	var p := _shell_of(body)
	if p == null:
		var h := UI.hbox(10); h.alignment = BoxContainer.ALIGNMENT_END
		body.add_child(h)
		return h
	(p.get_meta("foot") as Control).visible = true
	return p.get_meta("foot_right")

## The footer's main button: primary, with an Enter keycap. Hosts press it on Enter when nothing
## else has focus (press_primary).
static func footer_primary(body: Control, text: String, cb: Callable, minw := 0.0, icon := "") -> Button:
	var b := UiWidgets.with_key(UiWidgets.primary(text, cb, minw, icon), "Enter")
	footer(body).add_child(b)
	var p := _shell_of(body)
	if p: p.set_meta("primary", b)
	return b

## Presses the primary footer button of the panel under host, if it has one. True when it did.
static func press_primary(host: Node) -> bool:
	for ch in host.get_children():
		if ch.has_meta("primary"):
			var b = ch.get_meta("primary")
			if is_instance_valid(b) and not (b as Button).disabled and (b as Button).is_visible_in_tree():
				(b as Button).pressed.emit()
				return true
	return false

## The footer's left side: hints and notes that go with the actions.
static func footer_left(body: Control) -> HBoxContainer:
	var p := _shell_of(body)
	if p == null: return UI.hbox()
	(p.get_meta("foot") as Control).visible = true
	return p.get_meta("foot_left")

## A plain sheet (a panel without the shell), for full-screen menus like results or the lobby.
static func sheet(width := 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	if width > 0.0:
		p.custom_minimum_size.x = width
	return p

## A small modal on top of a panel host: a badge, a question, Cancel, and a danger (or primary)
## button. Only for things that can't be undone.
static func confirm(host: Control, head: String, text: String, yes_txt: String, on_yes: Callable, dangerous := true) -> Control:
	var layer := Modal.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.04, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cc)
	var p := sheet(460)
	cc.add_child(p)
	var v := UI.vbox(UI.GAP_BIG)
	p.add_child(v)
	var top := UI.hbox(16)
	top.add_child(UiWidgets.badge("alert", UI.BAD if dangerous else UI.ACCENT))
	var words := UI.vbox(6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(UiText.title(head, 24))
	words.add_child(UiText.para(text, UI.T_BODY, UI.MUTED))
	top.add_child(words)
	v.add_child(top)
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	var no := UiWidgets.ghost("Cancel", layer.queue_free)
	row.add_child(no)
	var yes_cb := func():
		layer.queue_free()
		on_yes.call()
	row.add_child(UiWidgets.danger(yes_txt, yes_cb) if dangerous else UiWidgets.primary(yes_txt, yes_cb))
	v.add_child(row)
	layer.set_meta("modal", true)
	host.add_child(layer)
	UI.pop_in(p)
	no.grab_focus.call_deferred()
	return layer

## A short note at the top centre of `host` ("Bramble Isle is open"), in the host's message lane
## (MsgLane: stacked, repeats merged, a few at a time). `y` is where the lane starts.
static func toast(host: Control, txt: String, col := UI.GOLD, y := 100.0) -> void:
	var lane := MsgLane.of(host)
	lane.top = y
	lane.push(txt, col)

## True while a toast is on show (or waiting) over `host`.
static func toast_busy(host: Control) -> bool:
	return MsgLane.of(host).count() > 0

## The layer under confirm(): Esc (or the pad's B) cancels it before anything else sees the key.
class Modal extends Control:
	func _input(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_cancel") or (InputMap.has_action("menu") and ev.is_action_pressed("menu")):
			get_viewport().set_input_as_handled()
			queue_free()
