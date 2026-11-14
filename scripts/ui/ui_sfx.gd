class_name UiSfx
extends Node
## Sounds for the controls Ui.button does not cover: sliders, toggles, dropdowns and drag and drop.
## Hooked once on the tree (Game), so any HSlider, CheckButton or OptionButton added anywhere gets
## them for free, and so does every drag of one of our things (the Boki box).

const SLIDER_GAP_MS := 55      # a drag over many steps ticks at most this often
const META := "ui_sfx"         # marks a control already wired

var _ours := false             # the drag under way carries one of our things, not a text field's text

static func hook(tree: SceneTree) -> void:
	tree.node_added.connect(attach)
	var ears := UiSfx.new()
	ears.name = "UiSfx"
	tree.root.add_child.call_deferred(ears)

## Every node hears a drag begin and end: picking a thing up sounds, setting it down in a slot that
## takes it sounds, and letting go anywhere else is silent (it goes back where it was).
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_ours = get_viewport().gui_get_drag_data() is Dictionary
		if _ours:
			Sfx.play("pickup", null, -6.0)
	elif what == NOTIFICATION_DRAG_END and _ours:
		_ours = false
		if get_viewport().gui_is_drag_successful():
			Sfx.play("click", null, -3.0, 0.03, 0.9)

static func attach(n: Node) -> void:
	if n.has_meta(META): return
	if n is Slider:
		n.set_meta(META, true)
		n.value_changed.connect(func(_v): _tick(n))
	elif n is CheckButton or n is CheckBox:
		n.set_meta(META, true)
		n.toggled.connect(func(on): Sfx.play("click", null, -6.0, 0.03, 1.15 if on else 0.85))
	elif n is OptionButton:
		n.set_meta(META, true)
		n.item_selected.connect(func(_i): Sfx.play("ui_tab"))

static func _tick(s: Slider) -> void:
	if not s.is_inside_tree(): return
	var now := Time.get_ticks_msec()
	if now - int(s.get_meta("tick_at", -1000)) < SLIDER_GAP_MS: return
	s.set_meta("tick_at", now)
	var span := maxf(s.max_value - s.min_value, 0.0001)
	var pitch := 0.9 + 0.3 * (s.value - s.min_value) / span
	Sfx.play("hover", null, -8.0, 0.0, pitch)
