class_name AboutView
extends RefCounted
## A kin's "About": what makes it itself (Unique: height, weight, size tag, coat, eyes, shape,
## habit, voice, birthmark, favourite food) and where it came from (Save.register: origin, where,
## when, original trainer, serial, parents, edition). Used on the kin card's About tab, the Nesting
## Nook and the Kin Burrow. See docs/BOKI_IDENTITY.md.

const TAG_COLS := {"XS": Color("9fe6ff"), "S": Color("b9d8ff"), "M": Color("a9b0bf"), "L": Color("ffd59a"), "XL": Color("ffb45a")}

static func size_line(rec: Dictionary) -> String:
	var si := Unique.size_info(rec)
	return "%d cm  ·  %.1f kg" % [int(round(float(si["cm"]))), float(si["kg"])]

static func tag_chip(rec: Dictionary) -> Control:
	var t := Unique.size_tag(rec)
	var c := UI.tag(t, TAG_COLS.get(t, UI.MUTED))
	var tips := {"XS": "Extra small: about 1 in 44 is this small", "S": "Small for its kind", "M": "About average for its kind",
		"L": "Large for its kind", "XL": "Extra large: about 1 in 44 is this big"}
	c.tooltip_text = String(tips.get(t, ""))
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c

static func _date(t: int) -> String:
	if t <= 0: return "Before records were kept"
	var dt := Time.get_datetime_dict_from_unix_time(t)
	return "%d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]

## Where it came from, in words.
static func origin_text(rec: Dictionary) -> String:
	var o: Dictionary = rec.get("origin", {}) if typeof(rec.get("origin", null)) == TYPE_DICTIONARY else {}
	var w: Dictionary = o.get("where", {}) if typeof(o.get("where", null)) == TYPE_DICTIONARY else {}
	var place := ""
	var bits: Array = []
	if String(w.get("island", "")) != "": bits.append(String(w["island"]))
	if String(w.get("map", "")) != "": bits.append(String(w["map"]))
	place = ", ".join(bits)
	var tn := String(w.get("tier_name", ""))
	if tn != "": place += (" (%s)" % tn) if place != "" else tn
	match String(o.get("how", "unknown")):
		"wild": return "Caught in the wild" + ((" at " + place) if place != "" else "")
		"taken": return "Taken from %s" % String(o.get("from", "a rival")) + ((" at " + place) if place != "" else "")
		"egg": return "Hatched in your Nesting Nook"
		"boss_egg":
			var boss := String(w.get("lair", ""))
			var bn := String(Data.MOBS.get(boss, {}).get("name", "")) if boss != "" else ""
			return "Hatched from a Rare Egg" + ((" from %s" % bn) if bn != "" else "")
		"starter": return "Your first kin, hatched from the egg you chose"
		"market": return "Bought at the market" + ((" from %s" % String(o["from"])) if String(o.get("from", "")) != "" else "")
		"event": return "Met at an event" + ((" at " + place) if place != "" else "")
	return "From before records were kept"

static func trainer_text(rec: Dictionary) -> String:
	var ot = rec.get("ot", null)
	if typeof(ot) != TYPE_DICTIONARY: return "Unknown"
	var mine := String(ot.get("id", "")) == String(Save.d.get("profile", {}).get("id", "")) if typeof(Save.d.get("profile", null)) == TYPE_DICTIONARY else false
	return String(ot.get("name", "a hunter")) + (" (you)" if mine else "")

static func parents_text(rec: Dictionary) -> String:
	var lin = rec.get("lineage", null)
	var names: Array = []
	var gen := 0
	if typeof(lin) == TYPE_DICTIONARY:
		names = lin.get("names", [])
		gen = int(lin.get("gen", 0))
	if names.is_empty() and rec.has("parents"): names = rec["parents"]
	if names.size() < 2: return ""
	return "%s and %s%s" % [names[0], names[1], ("  ·  generation %d" % gen) if gen > 1 else ""]

static func food_text(rec: Dictionary) -> String:
	var likes: Dictionary = rec.get("likes", {}) if typeof(rec.get("likes", null)) == TYPE_DICTIONARY else {}
	if likes.is_empty(): return "Unknown"
	if not (rec.get("known", []) as Array).has("food"): return "Not found yet (try feeding it)"
	return Care.food_name(String(likes.get("food", "")))

## A row: muted label left, the value right (wrapping), with an optional chip or swatch after it.
static func _row(parent: Control, k: String, val: String, col := UI.INK, extra: Control = null) -> void:
	var r := UI.hbox(8)
	var kl := UI.label(k, UI.T_SMALL, UI.MUTED)
	kl.custom_minimum_size.x = 112
	r.add_child(kl)
	var vl := UI.label(val, UI.T_SMALL, col, UI.semi)
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.custom_minimum_size.x = 120
	r.add_child(vl)
	if extra: r.add_child(extra)
	parent.add_child(r)

class Swatch extends Control:
	var col := Color.WHITE
	func _init(c: Color) -> void:
		col = c
		custom_minimum_size = Vector2(16, 16)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		draw_circle(size * 0.5, 7.0, Color(0, 0, 0, 0.5))
		draw_circle(size * 0.5, 5.5, col)
		draw_circle(size * 0.5 + Vector2(-1.8, -1.8), 1.6, Color(1, 1, 1, 0.8))

## Its looks and habits (Unique).
static func looks(rec: Dictionary, parent: Control) -> void:
	var si := Unique.size_info(rec)
	_row(parent, "Height", "%d cm" % int(round(float(si["cm"]))), UI.INK, tag_chip(rec))
	_row(parent, "Weight", "%.1f kg%s" % [float(si["kg"]), ("  ·  " + String(si["build"])) if String(si["build"]) != "" else ""])
	var ms := Mutations.of(rec).filter(func(m): return String(Mutations.info(m).get("group", "")) == "size")
	if not ms.is_empty():
		_row(parent, "", "%s on top: a rare size of its own" % Mutations.name_of(String(ms[0])), Mutations.col_of(String(ms[0])))
	_row(parent, "Coat", Unique.mark_name(rec))
	_row(parent, "Eyes", Unique.eye_name(rec), UI.INK, Swatch.new(Unique.eye_col(rec)))
	var shape := Unique.shape_text(rec)
	var props := Unique.prop_text(rec)
	var sh: Array = []
	if shape != "": sh.append(shape)
	if props != "": sh.append(props)
	var shape_s := ", ".join(sh)
	_row(parent, "Shape", (shape_s.substr(0, 1).to_upper() + shape_s.substr(1)) if shape_s != "" else "Typical of its kind")
	_row(parent, "Habit", Unique.quirk_name(rec))
	_row(parent, "Voice", Unique.voice_word(rec))
	var bm := Unique.birthmark_text(rec)
	if bm != "": _row(parent, "Birthmark", bm.substr(0, 1).to_upper() + bm.substr(1))
	_row(parent, "Favourite food", food_text(rec))

## Where it came from (Save.register).
static func history(rec: Dictionary, parent: Control) -> void:
	var st := Save.serial_text(rec)
	if st != "": _row(parent, "Serial", st, UI.GOLD)
	var ed = rec.get("edition", null)
	if typeof(ed) == TYPE_DICTIONARY:
		_row(parent, "Edition", "%s  #%d of %d" % [String(ed.get("kind", "")).capitalize(), int(ed.get("serial", 0)), int(ed.get("cap", 0))], UI.GOLD)
	_row(parent, "Origin", origin_text(rec))
	var o: Dictionary = rec.get("origin", {}) if typeof(rec.get("origin", null)) == TYPE_DICTIONARY else {}
	_row(parent, "When", _date(int(float(o.get("t", rec.get("born", 0))))))
	_row(parent, "Trainer", trainer_text(rec))
	var pt := parents_text(rec)
	if pt != "": _row(parent, "Parents", pt)

## The whole About section. compact: just the headline facts (for side panels).
static func block(rec: Dictionary, parent: Control, compact := false) -> void:
	if rec.is_empty(): return
	if compact:
		var h := UI.hbox(6)
		h.add_child(UI.label(size_line(rec), UI.T_SMALL, UI.INK, UI.semi))
		h.add_child(tag_chip(rec))
		var st := Save.serial_text(rec)
		if st != "":
			h.add_child(UI.fill())
			h.add_child(UI.label(st, 12, UI.GOLD))
		parent.add_child(h)
		var l := UI.label("%s  ·  %s eyes  ·  %s" % [Unique.mark_name(rec), Unique.eye_name(rec), Unique.quirk_name(rec)], 12, UI.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 260
		parent.add_child(l)
		var ol := UI.label(origin_text(rec), 12, UI.MUTED)
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ol.custom_minimum_size.x = 260
		parent.add_child(ol)
		return
	parent.add_child(UI.section("About", UI.FAINT.lightened(0.2)))
	looks(rec, parent)
	parent.add_child(UI.spacer(4))
	parent.add_child(UI.section("History", UI.FAINT.lightened(0.2)))
	history(rec, parent)
