class_name HomeClasses
extends RefCounted
## The Classes screen on the farm: every class as open, in progress or locked, each with its goal and
## the account level it needs, plus your account level and XP. Open it from the Hero panel. Rules and
## numbers: content/rules/class_unlock.json, logic: ClassUnlock.

const RANK := ["open", "progress", "locked"]

static func open(home: Node) -> void:
	var v: VBoxContainer = home._new_panel("Classes", 900, true)
	UI.subtitle(v, "New classes open as you play: finish a goal and reach its account level.")
	v.add_child(_account_row())
	var xp_note := UI.para("Expeditions earn account XP: most for getting out, then knocking hunters down and felling bosses.", 12, UI.FAINT)
	xp_note.custom_minimum_size.x = 600
	v.add_child(xp_note)
	if ClassUnlock.all_open() and not Game.modding():
		v.add_child(UI.para("Every class is open on this save.", 13, UI.GOOD))
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var ordered: Array = []       # open first, then in progress, then locked; each group in the usual order
	for rank in RANK:
		for a in Arch.ids():
			if ClassUnlock.status(String(a)) == rank: ordered.append(a)
	var cur := Arch.of_save()
	for a in ordered:
		var id: String = a
		var open := ClassUnlock.is_open(id)
		var tag := ""
		if open:
			tag = "Playing" if id == cur else ("Your starter" if id == ClassUnlock.starter() else "Open: click to play")
		var card := ClassCard.make(id, id == cur, func(): _click(home, id), tag)
		if not open:
			card.tooltip_text = "Locked: " + ClassUnlock.requirement(id)
		grid.add_child(card)
	home.set_meta("classes_grid", grid)
	UI.footer_left(v).add_child(UI.ghost("Back to heroes", func(): HomeHero.open(home), 0))

static func _click(home: Node, id: String) -> void:
	if ClassUnlock.is_open(id):
		HomeHero.pick(home, id)
	else:
		Sfx.play("hover", null, -6.0)
		home._toast("%s is locked. %s" % [Arch.name_of(id), ClassUnlock.requirement(id)])

## "Account level 3" with the XP bar to the next level.
static func _account_row() -> Control:
	var lv := ClassUnlock.level_of(ClassUnlock.xp())
	var card := UI.card(Color(ClassCard.GOAL_COL, 0.08), 12, 10)
	var row := UI.hbox(12); card.add_child(row)
	row.add_child(UI.label("Account level %d" % int(lv[0]), 18, ClassCard.GOAL_COL, UI.big))
	row.add_child(UI.bar(float(lv[1]) / float(lv[2]), ClassCard.GOAL_COL, 260.0, 10.0))
	row.add_child(UI.label("%d / %d XP" % [int(lv[1]), int(lv[2])], 13, UI.MUTED))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(sp)
	card.set_meta("account_level", int(lv[0]))
	return card
