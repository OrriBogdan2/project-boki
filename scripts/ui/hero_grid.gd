class_name HeroGrid
extends RefCounted
## The Hunter picker's card grid (every Hunter in Arch.ORDER): portrait, name, health and dashes,
## fantasy line, kit hover and a Kit button. Used by the practice areas' picker (PracticeHero; the farm
## has the Hunters screen, HomeClasses). Which Hunters are open is ClassUnlock. Gated, a locked Hunter
## is greyed with its goal; not gated (the practice areas) every Hunter can be tried, locked ones are
## marked and still clickable.

static func unlocked(ak: String) -> bool:
	return ClassUnlock.is_open(ak)
static func requirement(ak: String) -> String:
	return ClassUnlock.requirement(ak)

const CARD_W := 258.0        # px, one Hunter card (three per row)

## Fills `parent` with the grid and returns it. `on_pick(ak)` runs on a click on an unlocked Hunter (on
## any when not gated), `on_locked(ak)` on a locked one when gated, `on_kit(ak)` on its Kit button,
## `on_hover(ak)` as the mouse enters a card (K opens that Hunter's kit).
## Each card carries its id as meta "arch" and its state as "class_status".
static func build(parent: Control, on_pick: Callable, on_kit: Callable, on_hover: Callable, gated := true, on_locked := Callable()) -> GridContainer:
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12)
	parent.add_child(grid)
	var cur := Arch.of_save()
	for a in Arch.ids():
		grid.add_child(_card(String(a), cur, on_pick, on_kit, on_hover, gated, on_locked))
	return grid

static func _card(ak: String, cur: String, on_pick: Callable, on_kit: Callable, on_hover: Callable, gated: bool, on_locked: Callable) -> PanelContainer:
	var open := unlocked(ak)
	var can := open or not gated        # (can it be picked here)
	var card := UiWidgets.tile_card(ak == cur, func():
		if can: on_pick.call(ak)
		elif on_locked.is_valid(): on_locked.call(ak), 10, Arch.color(ak))
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var row := UI.hbox(10)
	card.add_child(row)
	row.add_child(ClassCard.portrait(ak))
	var col := UI.vbox(2); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(UiText.label(HunterViewer.display_name(ak), 18, Arch.color(ak) if can else UI.FAINT, UI.big))
	col.add_child(UiText.label(HunterViewer.stat_line(ak), 12, UI.MUTED))
	if ak == cur:
		col.add_child(UiText.label("Playing", 12, UI.GOOD, UI.semi))
	elif not open and gated:
		col.add_child(UiText.label("Locked", 12, UI.FAINT, UI.semi))
		col.add_child(ClassCard.challenge_block(ak, 150.0))
	elif not open:
		col.add_child(UiText.label("Try only: not open for expeditions yet", 12, ClassCard.GOAL_COL, UI.semi))
	var kitb := UiWidgets.ghost("Kit (K)", func(): on_kit.call(ak), 0)
	kitb.focus_mode = Control.FOCUS_NONE
	col.add_child(kitb)
	card.tooltip_text = ClassCard.kit_tip(ak)
	card.set_meta("arch", ak)
	card.set_meta("class_status", ClassUnlock.status(ak))
	if not open: card.tooltip_text = "Locked: %s\n%s" % [requirement(ak), card.tooltip_text]
	card.mouse_entered.connect(func(): on_hover.call(ak))
	if not can:
		card.modulate = Color(0.55, 0.55, 0.6, 0.8)
	elif not open:
		card.modulate = Color(0.85, 0.85, 0.9, 0.95)
	return card

## Saves `ak` as your expedition pick (its weight, id and weapon family). Every picker does this; a
## Hunter that is still locked is only tried, never saved. Returns whether it was saved.
static func save_pick(ak: String) -> bool:
	if not unlocked(ak):
		return false
	Save.d["cls"] = Arch.weight(ak)
	Save.d["arch"] = ak
	Save.d["weapon"] = Arch.signature(ak)
	Save.save_game()
	return true
