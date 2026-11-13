class_name NookPreview
## The Nesting Nook's preview card for a picked pair (briefs/design/GARDEN.md section 6): what an egg of
## theirs would be, read from Care.breed's own inputs. It adds no rules of its own.

const PIC_PX := 56.0     # px, each possible baby's picture on the card
const SWATCH_PX := 12.0   # px, a parent's colour swatch

## What Care.breed would give these two: {species: the kinds it can be, lean: its head start,
## lean_from: whose lean that is ("" for none), look: the blended rolls, unstable: why it clashes ("" if calm)}.
## A Locket of Kind on a parent fixes the kind (NestItems.plan).
static func facts(a: Dictionary, b: Dictionary) -> Dictionary:
	var kinds: Array = [String(a["species"])]
	if b["species"] != a["species"]: kinds.append(String(b["species"]))
	var locket: String = NestItems.plan(a, b)["species"]
	if locket != "": kinds = [locket]
	var lean := Care.head_start(a, b)
	return {"species": kinds, "lean": lean, "lean_from": "" if lean.is_empty() else String(Care.stronger(a, b)["name"]),
		"look": Unique.blend_center(a, b), "unstable": UnstableMix.preview_line(a, b), "odds": odds(a, b)}

## The chances Care.breed and Unique.inherit give an egg, per trait: each stat from one parent (each)
## or fresh (gift Threads raise the count, NestItems.plan), the coat from one parent (each) or fresh,
## and the species when the parents differ.
static func odds(a: Dictionary, b: Dictionary) -> Dictionary:
	var stat_from := float(NestItems.plan(a, b)["inherit"]) / float(Care.IV_KEYS.size()) * 0.5
	return {"species": 0.5, "stat_parent": stat_from, "stat_fresh": 1.0 - 2.0 * stat_from,
		"coat_parent": Unique.COAT_TAKE, "coat_fresh": 1.0 - 2.0 * Unique.COAT_TAKE}

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
		var odds := "" if kinds.size() == 1 else " (%s)" % _pct(f["odds"]["species"])
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
	v.add_child(UI.kv("Shimmer", Shiny.odds_text(Shiny.egg_chance(a, b))))
	if f["unstable"] != "": v.add_child(UI.para(f["unstable"], UI.T_SMALL, UI.GOLD))
	v.add_child(UI.section("What each can pass on", UI.FAINT.lightened(0.2)))
	v.add_child(parents(a, b))
	var o: Dictionary = f["odds"]
	var line := "Each stat: %s from %s, %s from %s, %s fresh. Coat: %s each, %s new. Colour lands between theirs."
	var stat := _pct(o["stat_parent"])
	var coat := _pct(o["coat_parent"])
	line = line % [stat, a["name"], stat, b["name"], _pct(o["stat_fresh"]), coat, _pct(o["coat_fresh"])]
	v.add_child(UI.para(line, UI.T_SMALL, UI.MUTED))
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

## The two parents side by side: lean (the stronger one's carries over), colour and coat, and the
## judge's band for each stat (any stat may come from either one).
static func parents(a: Dictionary, b: Dictionary) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 3)
	var giver := Care.stronger(a, b) if Care.lean_total(Care.stronger(a, b)) > 0.0 else {}
	g.add_child(UI.label("", UI.T_SMALL, UI.MUTED))
	for r in [a, b]: g.add_child(UI.label(String(r["name"]), UI.T_SMALL, UI.INK))
	g.add_child(UI.label("Lean", UI.T_SMALL, UI.MUTED))
	for r in [a, b]:
		var passes: bool = not giver.is_empty() and giver["uid"] == r["uid"]
		var word := lean_word(r) + (" (passes)" if passes else "")
		g.add_child(UI.label(word, UI.T_SMALL, UI.GOOD if passes else UI.INK))
	g.add_child(UI.label("Colour", UI.T_SMALL, UI.MUTED))
	for r in [a, b]: g.add_child(_colour(r))
	for k in Care.IV_KEYS:
		g.add_child(UI.label(String(Care.IVS[k]["name"]), UI.T_SMALL, UI.MUTED))
		for r in [a, b]:
			var n := Care.iv(r, k)
			g.add_child(UI.label(Care.iv_word(n), UI.T_SMALL, IvView.word_col(n)))
	return g

## "ember 6" (its strongest element), or "none" with no lean yet.
static func lean_word(rec: Dictionary) -> String:
	var lean: Dictionary = rec.get("lean", {})
	if lean.is_empty(): return "none"
	var top: String = lean.keys().reduce(func(x, y): return x if float(lean[x]) >= float(lean[y]) else y)
	return "%s %s" % [top, String.num(float(lean[top]), 1)]

## A swatch of its own body colour and the name of its coat.
static func _colour(rec: Dictionary) -> HBoxContainer:
	var h := UI.hbox(4)
	var sw := ColorRect.new()
	sw.color = Unique.tint(Shiny.body(rec), Unique.of(rec))
	sw.custom_minimum_size = Vector2(SWATCH_PX, SWATCH_PX)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	h.add_child(UI.label(Unique.mark_name(rec), UI.T_SMALL, UI.INK))
	return h

## 0.3 -> "30%".
static func _pct(p: float) -> String:
	return "%d%%" % int(round(p * 100.0))
