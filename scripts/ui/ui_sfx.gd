class_name UiSfx
extends RefCounted
## Sounds for the controls Ui.button does not cover: sliders, toggles and dropdowns. Hooked once on
## the tree (Game), so any HSlider, CheckButton or OptionButton added anywhere gets them for free.

const SLIDER_GAP_MS := 55      # a drag over many steps ticks at most this often
const META := "ui_sfx"         # marks a control already wired

static func hook(tree: SceneTree) -> void:
	tree.node_added.connect(attach)

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
