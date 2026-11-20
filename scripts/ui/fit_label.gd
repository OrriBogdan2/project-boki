class_name FitLabel
extends RefCounted
## A one-line label that shrinks its text to fit the width it is given, so a big Text size never cuts a name
## or a short line off. Below `min_px` (design size, scaled by the Text size) it ends in an ellipsis.

## Keeps `l` on one line: when it is laid out or resized, its font size goes down (never below
## `min_design_px` at the Text size) until the text fits, and back up to its made size when there is room.
static func shrink(l: Label, min_design_px := 9) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var made := l.get_theme_font_size("font_size")
	var min_px := UI.fs(min_design_px)
	var fit := func():
		var px := made
		var font := l.get_theme_font("font")
		while px > min_px and font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > l.size.x:
			px -= 1
		if px != l.get_theme_font_size("font_size"):
			l.add_theme_font_size_override("font_size", px)
	l.resized.connect(fit)
	fit.call_deferred()
