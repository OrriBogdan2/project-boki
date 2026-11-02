class_name HeroGrid
extends RefCounted
## The hero picker's card grid (every hero in Arch.ORDER, grouped by weight class): portrait, name, class,
## fantasy line, kit hover and a Kit button. Used by the farm's Hero panel (HomeHero) and the practice
## areas' picker (PracticeHero); each decides what a pick does.

## Whether an archetype can be picked yet, and what it takes if not. Everything is open for now;
## the class-unlock system plugs in here (return false and a requirement line for locked ones).
static func unlocked(_arch: String) -> bool:
	return true
static func requirement(_arch: String) -> String:
	return ""

const CARD_W := 258.0        # px, one hero card (three per row)

## Fills `parent` with the grid and returns it. `on_pick(ak)` runs on a click on an unlocked hero,
## `on_kit(ak)` on its Kit button, `on_hover(ak)` as the mouse enters a card (K opens that hero's kit).
## Each card carries its archetype as meta "arch".
static func build(parent: Control, on_pick: Callable, on_kit: Callable, on_hover: Callable) -> GridContainer:
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12)
	parent.add_child(grid)
	var cur := Arch.of_save()
	for cls in ["light", "medium", "heavy"]:
		for a in Arch.of_class(cls):
			grid.add_child(_card(String(a), String(cls), cur, on_pick, on_kit, on_hover))
	return grid

static func _card(ak: String, cls: String, cur: String, on_pick: Callable, on_kit: Callable, on_hover: Callable) -> PanelContainer:
	var can := unlocked(ak)
	var card := UI.tile_card(ak == cur, func(): if can: on_pick.call(ak), 10, Arch.color(ak))
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var row := UI.hbox(10)
	card.add_child(row)
	var vp := Portraits.make(cls, Data.TEAM_COLORS[0], Arch.signature(ak), Save.d.get("look", {}), ak)
	card.add_child(vp)
	var tex := TextureRect.new()
	tex.texture = vp.get_texture()
	tex.custom_minimum_size = Vector2(84, 84)
	tex.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tex)
	var col := UI.vbox(2); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(UI.label(Arch.name_of(ak), 18, Arch.color(ak) if can else UI.FAINT, UI.big))
	var cd: Dictionary = Data.CLASSES[cls]
	col.add_child(UI.label("%s  ·  %d health  ·  %d dash%s" % [String(cd["name"]), int(cd["hp"]), int(cd["dashes"]), "es" if int(cd["dashes"]) > 1 else ""], 12, UI.MUTED))
	var adf := Arch.def(ak)
	var fan := UI.para(String(adf.get("fantasy", "")), 12, UI.INK if can else UI.FAINT)
	fan.custom_minimum_size.x = 150
	col.add_child(fan)
	if ak == cur:
		col.add_child(UI.label("Playing", 12, UI.GOOD, UI.semi))
	elif not can:
		col.add_child(UI.label("Locked: " + requirement(ak), 12, UI.FAINT, UI.semi))
	var kitb := UI.ghost("Kit (K)", func(): on_kit.call(ak), 0)
	kitb.focus_mode = Control.FOCUS_NONE
	col.add_child(kitb)
	card.tooltip_text = "%s  ·  %s class\nDash: %s  ·  Passive: %s\nRMB: %s  ·  E: %s  ·  R: Boki Merge" % [Arch.name_of(ak), String(cd["name"]), String(adf["dash"]["name"]), String(adf["passive"]["name"]), String(adf["rmb"]["name"]), String(adf["e"]["name"])]
	card.set_meta("arch", ak)
	card.mouse_entered.connect(func(): on_hover.call(ak))
	if not can:
		card.modulate = Color(0.55, 0.55, 0.6, 0.8)
	return card

## Saves `ak` as your expedition pick (class, archetype, its weapon family). Both screens do this.
static func save_pick(ak: String) -> void:
	Save.d["cls"] = Arch.weight(ak)
	Save.d["arch"] = ak
	Save.d["weapon"] = Arch.signature(ak)
	Save.save_game()
