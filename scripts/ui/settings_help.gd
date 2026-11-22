class_name SettingsHelp
extends RefCounted
## The Settings description line: one plain sentence per option (content/rules/settings_help.json) shown in the
## fixed line at the bottom of the panel while the option's row is hovered or focused, controller included.

const PATH := "res://content/rules/settings_help.json"
const IDLE := "Point at an option to see what it does."
const BIND_PREFIX := "bind:"

static var _data := {}

## The line for a row: its setting's text, else its label's; every key bind shares one. "" when none is written.
static func line(setting: String, label: String) -> String:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	var key := setting if setting != "" else label
	if setting.begins_with(BIND_PREFIX):
		key = "bind"
	return Settings.fill_keys(String(_data.get(key, "")))

## Shows each row's line in the panel's help line while the mouse is over it or a control in it has focus.
## `body` is the settings page; its rows are the ones `Overlay._row` made (meta "setting" and "label").
static func attach(body: Control) -> void:
	var help := UI.footer_help(body)
	help.clip_text = true       # a long line is cut, never widens the panel
	help.text = IDLE
	for row in body.find_children("*", "HBoxContainer", true, false):
		if not row.has_meta("label"):
			continue
		var text := line(String(row.get_meta("setting")), String(row.get_meta("label")))
		var put := func(): help.text = text if text != "" else IDLE
		for c in [row] + row.find_children("*", "Control", true, false):
			c.mouse_entered.connect(put)
			if c.focus_mode != Control.FOCUS_NONE:
				c.focus_entered.connect(put)
