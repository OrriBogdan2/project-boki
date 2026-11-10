class_name HunterPicker
extends RefCounted
## The one Hunter picker, used by the pre-match lobby and the expedition panel: a grid of cards, each a
## portrait, the name and a role word. Health, dashes and weapon are the hover; a shut Hunter is dim with
## a padlock and its unlock quest on hover.

const SHUT_TINT := Color(0.55, 0.55, 0.6, 0.8)      # modulate of a Hunter that isn't open yet

## A small padlock for a shut Hunter: a body and a shackle.
class Padlock extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(22, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_arc(Vector2(11, 10), 6.0, PI, TAU, 12, UI.FAINT, 2.5)
		draw_rect(Rect2(3, 10, 16, 14), UI.FAINT)

## The grid: one card per Hunter, `picked` lit, `choose` called with the Hunter id on a click. `note` adds a
## word after the role of the picked card (e.g. "locked in").
static func grid(picked: String, choose: Callable, columns: int, card_w: float, portrait_px: float,
		note := "") -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	for ak in Arch.ids():
		g.add_child(card(String(ak), ak == picked, choose, card_w, portrait_px, note if ak == picked else ""))
	return g

static func card(ak: String, on: bool, choose: Callable, card_w: float, portrait_px: float,
		note := "") -> PanelContainer:
	var open := ClassUnlock.is_open(ak)
	var c := UI.tile_card(on, func(): choose.call(ak), 8, Arch.color(ak))
	c.custom_minimum_size = Vector2(card_w, 0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(8)
	c.add_child(row)
	row.add_child(ClassCard.portrait(ak, portrait_px))
	var col := UI.vbox(1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(UI.label(HeroTitle.base_name(ak), 18, Arch.color(ak) if open else UI.FAINT, UI.big))
	var role := String(Arch.def(ak)["card"]["role_word"])
	if note == "":
		col.add_child(UI.label(role, 12, UI.MUTED))
	else:
		col.add_child(UI.label(role + "  ·  " + note, 12, UI.GOOD))
	c.tooltip_text = HunterViewer.stat_line(ak) + "\n" + ClassCard.kit_tip(ak)
	if not open:
		row.add_child(Padlock.new())
		c.modulate = SHUT_TINT
		c.tooltip_text = "Locked: %s\n%s" % [ClassUnlock.requirement(ak), c.tooltip_text]
	c.set_meta("arch", ak)
	return c
