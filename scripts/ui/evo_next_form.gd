class_name EvoNextForm
extends RefCounted
## The Growth tab's "Next form" block on a Boki's card: one plain line for what evolving takes, read from the
## evolution data (content/rules/evolve.json), and for a level evolution an XP bar from where it is now to the
## level it evolves at. Only forms that have art count (Evo.has_art): a Boki never shows a form it cannot become.


## Fills `parent` with the section, the line and (for a level evolution) the bar.
static func block(rec: Dictionary, parent: VBoxContainer) -> void:
	var nf := info(rec)
	parent.add_child(UI.section("Next form", UI.FAINT.lightened(0.2)))
	parent.add_child(UI.label(String(nf["line"]), UI.T_HEAD, UI.INK, UI.big))
	if not nf.has("goal"):
		return
	var r := UI.hbox(10)
	var from := UI.label("Lv %d" % int(rec["level"]), UI.T_SMALL, UI.MUTED)
	from.custom_minimum_size.x = 92
	r.add_child(from)
	var bar := UI.bar(float(nf["frac"]), UI.ACCENT, 150, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(bar)
	var to := UI.label("Lv %d" % int(nf["goal"]), 12, UI.MUTED, UI.semi)
	to.custom_minimum_size.x = 64
	to.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(to)
	parent.add_child(r)


## What comes next for `rec`: {"line": the plain condition} and, for a level evolution, "goal" (its evolve
## level) and "frac" (0..1, the XP earned on the way to it; full once there).
static func info(rec: Dictionary) -> Dictionary:
	var line: Dictionary = Evo.rules()["lines"].get(String(rec["species"]), {})
	var into: Array = line.get("into", [])
	if into.is_empty():
		return {"line": "Fully grown"}
	var ready := into.filter(func(o): return Evo.has_art(String(o["id"])))
	if ready.is_empty():
		return {"line": "Its next form is coming soon"}
	if ready[0].has("item"):
		return {"line": "Needs %s" % _ink_name(ready)}
	if ready[0].get("trade", false):
		return {"line": "Evolves when traded"}
	var goal := int(line["level"])
	return {"line": "Evolves at Lv %d" % goal, "goal": goal, "frac": _xp_frac(rec, goal)}


## "a Tide Ink" when one Ink is the way, "an Ink" when its type picks the form.
static func _ink_name(opts: Array) -> String:
	if opts.size() > 1:
		return "an Ink"
	return "a " + Goods.name_of("good:" + String(opts[0]["item"]))


## The share of the XP from now (the level it is at plus its XP in it) to level `goal` that it has earned.
static func _xp_frac(rec: Dictionary, goal: int) -> float:
	var lv := int(rec["level"])
	if lv >= goal:
		return 1.0
	var span := 0
	for l in range(lv, goal):
		span += Game.xp_need(l)
	return clampf(float(rec.get("xp", 0)) / float(span), 0.0, 1.0)
