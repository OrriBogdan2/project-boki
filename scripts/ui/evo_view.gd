class_name EvoView
extends RefCounted
## The Next form block on a Boki card's Growth tab: its level, an XP bar to the level it evolves at
## and one plain line on what evolving takes, read through Evo.next_way. Only forms with art count:
## a Boki never evolves into a form that has no model yet.

## Adds the block to `parent`. A Boki with no next form ready gets the line alone.
static func next_block(rec: Dictionary, parent: VBoxContainer) -> void:
	var nf := next_form(rec)
	parent.add_child(UI.section("Next form", UI.FAINT.lightened(0.2)))
	parent.add_child(UI.label(String(nf["line"]), UI.T_HEAD, UI.INK, UI.big))
	if not nf.has("goal"):
		return
	var row := UI.hbox(10)       # laid out like the card's other bar rows: 92 px label, bar, 64 px value
	var level_label := UI.label("Lv %d" % int(rec["level"]), UI.T_SMALL, UI.MUTED)
	level_label.custom_minimum_size.x = 92.0
	row.add_child(level_label)
	var bar := UI.bar(float(nf["frac"]), UI.ACCENT, 150, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	var goal_label := UI.label("Lv %d" % int(nf["goal"]), 12, UI.MUTED, UI.semi)
	goal_label.custom_minimum_size.x = 64.0
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(goal_label)
	parent.add_child(row)

## What the block shows: {"line"} and, while a form with art is ahead, "goal" (the level the bar fills
## to: its evolve level, or the next level when an Ink or a trade decides) and "frac" (0..1 of the XP).
static func next_form(rec: Dictionary) -> Dictionary:
	var way := Evo.next_way(rec)
	var lv := int(rec["level"])
	var goal := mini(lv + 1, Evo.cap())
	var line := ""
	match String(way.get("how", "")):
		"level":
			goal = int(way["level"])
			return {"line": "Evolves at Lv %d" % goal, "goal": goal, "frac": _xp_share(rec, 1, goal)}
		"item":
			line = "Needs %s" % _ink_words(way["inks"])
		"trade":
			line = "Evolves when traded"
		"soon":
			return {"line": "Its next form is coming soon"}
		_:
			return {"line": "This is its last form"}
	return {"line": line, "goal": goal, "frac": _xp_share(rec, lv, goal)}

## "a Tide Ink" when one Ink works, "an Ink" when the Ink's type picks the form.
static func _ink_words(inks: Array) -> String:
	if inks.size() > 1:
		return "an Ink"
	var ink_name := Goods.name_of("good:" + String(inks[0]))
	return ("an " if "AEIOU".contains(ink_name.left(1)) else "a ") + ink_name

## The share of the XP from level `start_lv` to level `goal` it has earned (full once it is there).
static func _xp_share(rec: Dictionary, start_lv: int, goal: int) -> float:
	var lv := int(rec["level"])
	if lv >= goal:
		return 1.0
	var earned := float(rec.get("xp", 0))
	var span := 0.0
	for step_lv in range(start_lv, goal):
		span += Game.xp_need(step_lv)
		if step_lv < lv:
			earned += Game.xp_need(step_lv)
	return clampf(earned / span, 0.0, 1.0)
