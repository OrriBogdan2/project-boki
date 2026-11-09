class_name UiText
## Text helpers of the menu kit: labels, wrapped paragraphs, titles and section headings.

## A small spaced-out heading for a group of things in a menu (the "eyebrow").
static func section(text: String, col := Color("c9a46a")) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", UI.caps if UI.caps else UI.body)
	l.add_theme_font_size_override("font_size", UI.T_CAPS)
	l.add_theme_color_override("font_color", col)
	l.set_meta("pg_head", true)
	return l

static func label(text: String, size := 16, col := UI.INK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	# short labels sit on one line; only real sentences wrap (a wrapping label in a row collapses to nothing)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if text.length() > 48 else TextServer.AUTOWRAP_OFF
	return l

## Body text that wraps: the usual muted line under a heading.
static func para(text: String, size := UI.T_SMALL, col := UI.MUTED) -> Label:
	var l := label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func title(text: String, size := 34, col := UI.INK) -> Label:
	var l := label(text, size, col, UI.big)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

## A label: value row (settings rows, item stats): the label muted on the left, the value right.
static func kv(k: String, val: String, col := UI.INK) -> HBoxContainer:
	var r := UI.hbox(8)
	var kl := label(k, UI.T_SMALL, UI.MUTED); kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(kl)
	r.add_child(label(val, UI.T_SMALL, col, UI.semi))
	return r
