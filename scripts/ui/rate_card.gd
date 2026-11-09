class_name RateCard
extends RefCounted
## The skippable "Rate this build" card (item 189): four 1-10 ratings and an optional note, shown once
## per game version after Feedback.MIN_MINUTES of play, when the player leaves for the title or quits.

const ROWS := [["combat", "Combat feel"], ["boki", "Boki"], ["onboarding", "Onboarding"], ["look", "Look"]]

## Runs `then` now, or after the card is answered or skipped when one is due.
static func gate(host: Control, then: Callable) -> void:
	if Feedback.due():
		open(host, then)
	else:
		then.call()

static func open(host: Control, then: Callable) -> Control:
	var scores := {}
	var layer := UiShell.Modal.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.04, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cc)
	var p := UiShell.sheet(560)
	cc.add_child(p)
	var v := UI.vbox(UI.GAP)
	p.add_child(v)
	v.add_child(UiText.title("Rate this build", 24))
	var intro := "Version %s. One tap per row, 1 is poor and 10 is great. Skipping is fine." % Net.VERSION
	v.add_child(UiText.para(intro, UI.T_BODY, UI.MUTED))
	var note := LineEdit.new()
	var finished := [false]
	var close := func(sent: bool) -> void:
		if finished[0]:
			return
		finished[0] = true
		Feedback.finish()
		if sent:
			Feedback.submit(host, scores, note.text)
		layer.queue_free()
		then.call()
	var send := UiWidgets.primary("Send", close.bind(true))
	send.disabled = true
	for row in ROWS:
		v.add_child(UiText.label(String(row[1]), UI.T_BODY, UI.INK, UI.semi))
		var line := UI.hbox(4)
		var group := ButtonGroup.new()
		for n in range(1, 11):
			var b := Button.new()
			b.text = str(n)
			b.toggle_mode = true
			b.button_group = group
			b.custom_minimum_size = Vector2(40, 34)
			b.toggled.connect(func(on: bool) -> void:
				if on:
					scores[row[0]] = n
					send.disabled = scores.size() < ROWS.size())
			line.add_child(b)
		v.add_child(line)
	note.placeholder_text = "Anything else? (optional)"
	note.max_length = Feedback.NOTE_MAX
	v.add_child(note)
	var buttons := UI.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_child(UiWidgets.ghost("Skip", close.bind(false)))
	buttons.add_child(send)
	v.add_child(buttons)
	layer.tree_exiting.connect(close.bind(false))   # Esc skips too
	layer.set_meta("modal", true)
	host.add_child(layer)
	return layer
