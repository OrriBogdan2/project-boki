class_name SettingsSearch
extends RefCounted
## The Settings search: a field under the tab bar, and a results page made of the very rows the tabs build
## (Overlay._row marks each with its label), each tagged with the tab it lives on.

const TAG := "TabTag"     # the node name of the tab tag on a hit
const PLACEHOLDER := "Search settings"

## True when `query` is a real search (not empty or only spaces).
static func active(query: String) -> bool:
	return query.strip_edges() != ""

## The search field, pinned under the tab bar of the settings shell `body`. `on_change` gets the new text.
## A search in progress keeps the keyboard, so typing carries on after the page rebuilds.
static func field(body: Control, text: String, on_change: Callable) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = PLACEHOLDER
	le.clear_button_enabled = true
	le.text = text
	le.caret_column = text.length()
	le.text_changed.connect(on_change)
	var slot: Control = (body.get_meta("shell") as Control).get_meta("tabs")
	slot.add_child(le)
	slot.visible = true
	if active(text):
		le.grab_focus.call_deferred()
	return le

## Puts the tab's name beside the row's name (the hint keeps the full width under both).
static func _tag(row: Control, tab_name: String) -> void:
	var names := row.get_child(0)
	var head := names.get_child(0) as Label
	var line := UI.hbox(8)
	names.remove_child(head)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(head)
	var tag := UI.label(tab_name, UI.T_SMALL, UI.MUTED)
	tag.name = TAG
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(tag)
	names.add_child(line)
	names.move_child(line, 0)

## Adds to `body` every row, on any of `tabs`, whose label holds `query`. `build` is called as
## build(tab, vbox) to make that tab's rows; the matching ones move into `body` and the rest go.
static func fill(body: VBoxContainer, query: String, tabs: Array, build: Callable) -> void:
	var q := query.strip_edges().to_lower()
	var hits := 0
	for t in tabs:
		var scratch := VBoxContainer.new()
		build.call(t, scratch)
		for row in scratch.get_children():
			if not row.has_meta("label") or not String(row.get_meta("label")).to_lower().contains(q):
				continue
			scratch.remove_child(row)
			row.visible = true      # (a fold may have hidden it)
			_tag(row, t)
			body.add_child(row)
			hits += 1
		scratch.free()
	if hits == 0:
		body.add_child(UI.para("No setting matches \"%s\"." % query.strip_edges(), UI.T_BODY, UI.MUTED))
