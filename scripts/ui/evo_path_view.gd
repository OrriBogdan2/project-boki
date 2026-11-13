class_name EvoPathView
extends RefCounted
## The path meter on the Boki card's Growth tab (EvoPath): a tug bar between the two finals' silhouettes,
## the pip sources under each end, and at the line's level "Evolve now / Not yet". Ink lines show only the
## silhouette a held Ink would make. An unknown form is a black shape named '?'.

const SIL := Vector2(64, 64)                 # px: one final's silhouette
const BAR_H := 14.0                          # px: the tug bar's height
const UNKNOWN := Color(0.05, 0.05, 0.07)     # an unmet form's shape
const MET := Color(0.36, 0.38, 0.46)         # a met form's shape (no art yet to draw it)
const SIDES := [Color("ff9a6a"), Color("7ac8ff")]   # left and right end of the bar
const SOURCE_NAMES := {"stat": "stat lead", "lean": "lean", "tokens": "tokens", "care": "care", "ribbons": "ribbons"}

## Adds the meter (or the Ink preview) to v. refresh() redraws the card after Evolve.
static func block(rec: Dictionary, v: VBoxContainer, refresh: Callable) -> void:
	for p in EvoPath.ink_previews(rec):
		v.add_child(UI.section("With %s" % String(p["ink_name"]), UI.FAINT.lightened(0.2)))
		v.add_child(_sil(p["form"], p["name"]))
		if not EvoPath.has_art(p["form"]):
			v.add_child(UI.para("Art not in the game yet: it will wait.", 12, UI.FAINT))
	var ln := EvoPath.line(rec)
	if ln.is_empty():
		return
	var ends: Array = ln["ends"]
	var pips := EvoPath.pips(rec)
	v.add_child(UI.section("Path meter", UI.FAINT.lightened(0.2)))
	var tug := UI.hbox(8)
	tug.add_child(_sil(ends[0]["form"], ends[0]["name"]))
	tug.add_child(_bar(EvoPath.total(pips[0]), EvoPath.total(pips[1])))
	tug.add_child(_sil(ends[1]["form"], ends[1]["name"]))
	v.add_child(tug)
	for i in 2:
		var line_t := "%s %d: %s" % [_name(ends[i]), EvoPath.total(pips[i]), _sources(pips[i], ends[i])]
		v.add_child(UI.label(line_t, UI.T_SMALL, SIDES[i]))
	var w := EvoPath.winner(rec)
	var toward := "Growing toward %s." % _name(ends[w]) if w >= 0 else "Undecided: tip it either way."
	v.add_child(UI.para(toward, 12, UI.MUTED))
	if EvoPath.due(rec):
		_prompt(rec, v, refresh)

static func _prompt(rec: Dictionary, v: VBoxContainer, refresh: Callable) -> void:
	var why := EvoPath.blocked(rec)
	if why != "":
		var why_t := {"stay": "Wearing a Stayleaf: it will not evolve.", "undecided": "It waits until one end leads.",
				"art": "Art not in the game yet: it will wait."}
		v.add_child(UI.para(why_t[why], 12, UI.FAINT))
	var row := UI.hbox(8)
	var go := UI.button("Evolve now", func():
		EvoPath.evolve(rec)
		refresh.call(), 140)
	go.disabled = why != ""
	row.add_child(go)
	row.add_child(UI.ghost("Not yet", refresh, 100))
	v.add_child(row)

static func _name(e: Dictionary) -> String:
	return String(e["name"]) if EvoPath.known(String(e["form"])) else "?"

static func _sources(list: Array, e: Dictionary) -> String:
	if list.is_empty():
		return "no pips yet"
	var parts := []
	for p in list:
		var what := String(SOURCE_NAMES[p["source"]])
		if p["source"] == "stat":
			what += " (%s)" % Care.STATS[e["stat"]]["name"]
		elif p["source"] == "lean":
			what += " (%s)" % Lean.face(String(e["type"]))["name"]
		parts.append("%s %d" % [what, int(p["count"])])
	return ", ".join(parts)

static func _sil(form: String, nm: String) -> Control:
	var box := UI.vbox(2)
	var shape := Panel.new()
	shape.custom_minimum_size = SIL
	var sb := StyleBoxFlat.new()
	sb.bg_color = MET if EvoPath.known(form) else UNKNOWN
	sb.set_corner_radius_all(int(SIL.x / 2.0))
	shape.add_theme_stylebox_override("panel", sb)
	box.add_child(shape)
	box.add_child(UI.label(nm if EvoPath.known(form) else "?", UI.T_SMALL, UI.MUTED))
	return box

static func _bar(a: int, b: int) -> Control:
	var bar := UI.hbox(0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in 2:
		var part := ColorRect.new()
		part.color = SIDES[i]
		part.custom_minimum_size.y = BAR_H
		part.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		part.size_flags_stretch_ratio = maxf(0.5, float([a, b][i]))
		bar.add_child(part)
	return bar
