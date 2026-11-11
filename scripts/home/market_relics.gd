class_name MarketRelics
extends RefCounted
## The market's Relics tab: a card per Hunter in the canonical order (Arch.ids), owned or locked, and for a
## locked one the line on how to open it (ClassUnlock.requirement, from the live challenge counters).
## Relics are earned first and bought later (briefs DECISIONS, "Getting Masks"), so no prices show yet.

const COLS := 2
const CARD_W := 404.0         # px, one card: two fill the market panel like the Vendor's goods

## The line under the tab bar.
static func summary() -> String:
	var owned := Arch.ids().filter(func(id): return ClassUnlock.is_open(String(id)))
	return "%d of %d Relics yours. Earn the rest through challenges and rewards." % [owned.size(), Arch.ids().size()]

## The tab's body: the cards, one per Hunter.
static func build(v: VBoxContainer) -> void:
	UI.subtitle(v, summary())
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for id in Arch.ids():
		grid.add_child(card(String(id)))
	v.add_child(grid)

## One Hunter: its name, and either "Yours" or what it takes to open it.
static func card(id: String) -> Control:
	var mine := ClassUnlock.is_open(id)
	var c := UI.card(UI.CARD if mine else Color(UI.NIGHT_HI, 0.9), 10, 12)
	c.custom_minimum_size = Vector2(CARD_W, 0)
	var row := UI.hbox(10)
	c.add_child(row)
	var badge := UI.badge("swap", Arch.color(id), 32.0) if mine else UI.badge("lock", UI.FAINT, 32.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var text := UI.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var top := UI.hbox(6)
	text.add_child(top)
	var nm := UI.label(HunterViewer.display_name(id), UI.T_BODY, UI.INK if mine else UI.MUTED, UI.semi)
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	if mine:
		top.add_child(UI.label("Yours", 12, UI.GOOD))
	var how := UI.label("Play it from the Relics screen", 12, UI.MUTED)
	if not mine:
		how = UI.label(ClassUnlock.requirement(id), 12, Color("ffb3a8"))
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(how)
	return c
