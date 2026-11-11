class_name NookPreview
## The Nesting Nook's preview card for a picked pair (briefs/design/GARDEN.md section 6): what an egg of
## theirs would be, read from Care.breed's own inputs. It adds no rules of its own.

const PIC_PX := 56.0     # px, each possible baby's picture on the card
## the note on an unstable mix (Care.unstable_mix: clashing elements or tempers)
const UNSTABLE_NOTE := "An unstable mix: their elements or tempers clash. It hatches glum and needs care for a day."

## What Care.breed would give these two: {species: the kinds it can be, lean: its head start,
## lean_from: whose lean that is ("" for none), look: the blended rolls, unstable: a clashing mix}.
static func facts(a: Dictionary, b: Dictionary) -> Dictionary:
	var kinds: Array = [String(a["species"])]
	if b["species"] != a["species"]: kinds.append(String(b["species"]))
	var lean := Care.head_start(a, b)
	return {"species": kinds, "lean": lean, "lean_from": "" if lean.is_empty() else String(Care.stronger(a, b)["name"]),
		"look": Unique.blend_center(a, b), "unstable": Care.unstable_mix(a, b)}

## The card: each possible baby in the blended look, its size and coats, the lean head start, the
## unstable note, and why the pair can't have an egg yet (if so).
static func card(a: Dictionary, b: Dictionary, tree: SceneTree) -> PanelContainer:
	var f := facts(a, b)
	var c := UI.card(UI.CARD, 12)
	var v := UI.vbox(6)
	c.add_child(v)
	v.add_child(UI.section("Their egg", UI.FAINT.lightened(0.2)))
	var kinds: Array = f["species"]
	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for sp in kinds:
		var pv := UI.vbox(0)
		var look := {"uid": "nook:%s:%s:%s" % [a["uid"], b["uid"], sp], "species": sp, "level": 1, "dna": f["look"]}
		var pic := KinPortrait.view(look, tree, PIC_PX)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pv.add_child(pic)
		var odds := "" if kinds.size() == 1 else " (1 in 2)"
		var l := UI.label(String(Data.KIN[sp]["name"]) + odds, UI.T_SMALL, UI.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(l)
		row.add_child(pv)
	v.add_child(row)
	var coats := Unique.mark_name(a)
	if Unique.mark_name(b) != coats: coats += " or " + Unique.mark_name(b)
	v.add_child(UI.kv("Size", Unique.size_tag({"dna": f["look"]})))
	v.add_child(UI.kv("Coat", coats))
	v.add_child(UI.kv("Head start", _lean_text(f)))
	if f["unstable"]:
		v.add_child(UI.para(UNSTABLE_NOTE, UI.T_SMALL, UI.GOLD))
	var why := NookRules.pair_why(a, b)
	if why != "": v.add_child(UI.para(why, UI.T_SMALL, UI.BAD))
	return c

## "ember 3, storm 0.5 (from Ash)", or "none" when neither parent leans anywhere yet.
static func _lean_text(f: Dictionary) -> String:
	var lean: Dictionary = f["lean"]
	if lean.is_empty(): return "none"
	var parts: Array = []
	for el in lean: parts.append("%s %s" % [el, String.num(float(lean[el]), 1)])
	return "%s (from %s)" % [", ".join(parts), f["lean_from"]]
