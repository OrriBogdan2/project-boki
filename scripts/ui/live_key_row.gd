class_name LiveKeyRow
extends HBoxContainer
## A row of key caps (UI.key_hints) that rebuilds its own key groups when a binding changes, so a rebind
## in Settings shows without leaving the screen. `pairs_fn` returns the [[caps, words], ...] to show.

var pairs_fn: Callable
var cap_px := 12
var tint := Color(1, 1, 1, 0.78)

static func make(fn: Callable, px := 12, col := Color(1, 1, 1, 0.78)) -> LiveKeyRow:
	var r := LiveKeyRow.new()
	r.pairs_fn = fn
	r.cap_px = px
	r.tint = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_constant_override("separation", 16)
	return r

func _ready() -> void:
	Settings.changed.connect(_on_changed)
	_rebuild()

func _exit_tree() -> void:
	Settings.changed.disconnect(_on_changed)

func _on_changed(k: String) -> void:
	if k == "keys" or k == "":
		_rebuild()

func _rebuild() -> void:
	for c in get_children():
		if c.has_meta("live"):
			c.free()
	var fresh := UI.key_hints(pairs_fn.call(), cap_px, tint)
	for c in fresh.get_children():
		fresh.remove_child(c)
		c.set_meta("live", true)
		add_child(c)
	fresh.free()
