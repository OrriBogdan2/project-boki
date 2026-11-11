class_name EvoView
extends RefCounted
## The Growth tab's "Growing toward" column on a Boki's card: the "Next form" block (level, XP bar and
## what evolving takes), its nature, the next mutation, the final its training leans toward
## (training-branch lines) and the Inks that evolve it, each with a Use button (Ink lines).
## Rules: Evo, content/rules/evolve.json.

## Fills `parent`; `refresh` reopens the card after an Ink is used.
static func growth(rec: Dictionary, parent: VBoxContainer, refresh: Callable) -> void:
	next_block(rec, parent)
	var lead := Evo.leading(rec)
	parent.add_child(UI.section("Growing toward", UI.FAINT.lightened(0.2)))
	parent.add_child(UI.label(String(Evo.AFF[lead]["name"]), UI.T_HEAD, Evo.AFF[lead]["tint"], UI.big))
	var lv := int(rec["level"])
	parent.add_child(UI.label("Mutation at level %d" % (lv + 4 - (lv + 2) % 4), UI.T_SMALL, UI.MUTED))
	var ln := Evo.lean(rec)
	if not ln.is_empty():
		var pts: Array = ln["stats"].map(func(p): return "%s %d" % [Care.STATS[p[0]]["name"], p[1]])
		var why := "Its higher trained stat when it evolves picks its final; a tie goes by its nature."
		parent.add_child(UI.para("Leaning %s (%s). %s" % [_name(String(ln["id"])), "  ·  ".join(pts), why], 12, UI.INK))
	var inks := Evo.inks_for(rec)
	if inks.is_empty():
		parent.add_child(UI.para("What you feed it and how you raise it shapes how it grows.", 12, UI.FAINT))
		return
	parent.add_child(UI.para("An Ink used on it decides what it becomes.", 12, UI.FAINT))
	for pair in inks:
		parent.add_child(_ink_row(rec, String(pair[0]), String(pair[1]), refresh))

## The "Next form" block: level, an XP bar to the level of the form it evolves into and, in one plain
## line, what that takes (see `next_form`). A Boki with no next form gets the line alone.
static func next_block(rec: Dictionary, parent: VBoxContainer) -> void:
	var nf := next_form(rec)
	parent.add_child(UI.section("Next form", UI.FAINT.lightened(0.2)))
	parent.add_child(UI.label(String(nf["line"]), UI.T_HEAD, UI.INK, UI.big))
	if not nf.has("goal"):
		return
	var r := UI.hbox(10)
	var l := UI.label("Lv %d" % int(rec["level"]), UI.T_SMALL, UI.MUTED)
	l.custom_minimum_size.x = 92
	r.add_child(l)
	var bar := UI.bar(float(nf["frac"]), UI.ACCENT, 150, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(bar)
	var to := UI.label("Lv %d" % int(nf["goal"]), 12, UI.MUTED, UI.semi)
	to.custom_minimum_size.x = 64
	to.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(to)
	parent.add_child(r)

## What comes next for `rec`, read from the evolution data: {"line": the plain condition, and for a
## Boki that is still growing "goal" (the level the bar fills toward: its evolve level, or the next
## level when an Ink or a trade decides) and "frac" (0..1, XP earned on the way to it)}.
## Only forms that have art count (Evo.has_art); a Boki never shows a form it cannot become.
static func next_form(rec: Dictionary) -> Dictionary:
	var line: Dictionary = Evo.rules()["lines"].get(String(rec["species"]), {})
	var into: Array = line.get("into", [])
	if into.is_empty():
		return {"line": "Fully grown"}
	var ready := into.filter(func(o): return Evo.has_art(String(o["id"])))
	if ready.is_empty():
		return {"line": "Its next form is coming soon"}
	var goal := mini(int(rec["level"]) + 1, Evo.cap())
	var text := ""
	if ready[0].has("item"):
		text = "Needs %s" % _ink_name(ready)
	elif ready[0].get("trade", false):
		text = "Evolves when traded"
	else:
		goal = int(line["level"])
		text = "Evolves at Lv %d" % goal
	return {"line": text, "goal": goal, "frac": _xp_frac(rec, goal)}

## "a Tide Ink" when one Ink is the way, "an Ink" when its type picks the form.
static func _ink_name(opts: Array) -> String:
	if opts.size() > 1:
		return "an Ink"
	return "a " + Goods.name_of("good:" + String(opts[0]["item"]))

## The share of the XP from the start of its level to level `goal` that it has earned (full once there).
static func _xp_frac(rec: Dictionary, goal: int) -> float:
	var lv := int(rec["level"])
	if lv >= goal:
		return 1.0
	var span := Evo.xp_between(lv, goal)
	return clampf(float(rec.get("xp", 0)) / float(span), 0.0, 1.0)

static func _ink_row(rec: Dictionary, ink: String, to: String, refresh: Callable) -> HBoxContainer:
	var r := UI.hbox(8)
	var have := Goods.have("good:" + ink)
	var txt := "%s makes a %s  ·  you have %d" % [Goods.name_of("good:" + ink), _name(to), have]
	var l := UI.label(txt, UI.T_SMALL, UI.INK if have > 0 else UI.FAINT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	var b := UI.ghost("Use", func():
		if not Evo.use_ink(rec, ink).is_empty():
			Save.save_game()
		refresh.call())
	b.disabled = have <= 0 or not Evo.has_art(to)
	if not Evo.has_art(to): b.tooltip_text = "Its %s look isn't ready yet" % _name(to)
	r.add_child(b)
	return r

static func _name(id: String) -> String:
	var k := KinLib.entry(id)
	return k.display_name if k else id.capitalize()
