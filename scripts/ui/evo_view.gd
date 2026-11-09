class_name EvoView
extends RefCounted
## The Growth tab's "Growing toward" column on a Boki's card: its nature, the form it evolves into
## next and at what level, the final its training leans toward (training-branch lines), and the
## Inks that evolve it, each with a Use button (Ink lines). Rules: Evo, content/rules/evolve.json.

## Fills `parent`; `refresh` reopens the card after an Ink is used.
static func growth(rec: Dictionary, parent: VBoxContainer, refresh: Callable) -> void:
	var lead := Evo.leading(rec)
	parent.add_child(UI.section("Growing toward", UI.FAINT.lightened(0.2)))
	parent.add_child(UI.label(String(Evo.AFF[lead]["name"]), UI.T_HEAD, Evo.AFF[lead]["tint"], UI.big))
	parent.add_child(UI.label(_next_line(rec), UI.T_SMALL, UI.MUTED))
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

## "Becomes a Sporcupine at level 8  ·  mutation at 10", or just the mutation when no level form is next.
static func _next_line(rec: Dictionary) -> String:
	var lv := int(rec["level"])
	var next_mut := lv + ((2 - lv % 4) + 4) % 4
	if next_mut == lv: next_mut += 4
	var line: Dictionary = Evo.rules()["lines"].get(String(rec["species"]), {})
	if not line.has("level"):
		return "Mutation at level %d" % next_mut
	var into: Array = line["into"]
	var to := _name(String(into[0]["id"])) if into.size() == 1 else "its final form"
	var at := maxi(int(line["level"]), lv + 1)
	return "Becomes %s at level %d  ·  mutation at %d" % [to, at, next_mut]

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
