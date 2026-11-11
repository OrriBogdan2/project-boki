class_name AboutView
extends RefCounted
## A Boki's "About": field notes on what makes it itself (Unique: height, weight, size tag, coat, eyes, shape,
## habit, voice, birthmark, favourite food) and where it came from (Save.register: origin, where,
## when, original trainer, serial, parents, edition). Used on the kin card's About tab, the Nesting
## Nook and the Kin Burrow. See docs/BOKI_IDENTITY.md.

## Field notes, not collection stats (docs/POSITIONING.md on the design branch): plain sentences
## in the card's own ink, no rarity colours or badges. What's rare about a Boki shows on the Boki.

static func size_line(rec: Dictionary) -> String:
	var si := Unique.size_info(rec)
	return "%d cm  ·  %.1f kg" % [int(round(float(si["cm"]))), float(si["kg"])]

static func _sp_name(rec: Dictionary) -> String:
	return String(Data.KIN.get(String(rec.get("species", "")), {}).get("name", "its kind"))

static func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1) if t != "" else t

## How its size compares, in words (the XS / XL tags are the rare edges).
static func size_word(rec: Dictionary) -> String:
	var nm := _sp_name(rec)
	match Unique.size_tag(rec):
		"XS": return "very small for a %s (XS): few are this small" % nm
		"S": return "small for a %s" % nm
		"L": return "large for a %s" % nm
		"XL": return "very large for a %s (XL): few grow this big" % nm
	return "about average for a %s" % nm

static func size_note(rec: Dictionary) -> String:
	var si := Unique.size_info(rec)
	var b := String(si["build"])
	return "Stands %d cm and weighs %.1f kg. %s%s." % [int(round(float(si["cm"]))), float(si["kg"]), _cap(size_word(rec)), (", and " + b) if b != "" else ""]

static func coat_note(rec: Dictionary) -> String:
	var d := Unique.of(rec)
	var c := String(Unique.MARK_COL_NAMES.get(String(d.get("mark_col", "dark")), "dark"))
	match String(d.get("mark", "plain")):
		"spots": return "Spotted with %s spots" % c
		"stripes": return "Striped, %s stripes" % c
		"patches": return "%s patches across its coat" % _cap(c)
		"freckles": return "Freckled with %s flecks" % c
	return "A plain coat, no markings"

static func eye_note(rec: Dictionary) -> String:
	var e := Unique.eye_name(rec)
	return ("The usual %s eyes" % _sp_name(rec)) if e == "Classic" else "%s eyes" % e

static func build_note(rec: Dictionary) -> String:
	var bits: Array = []
	var sh := Unique.shape_text(rec)
	var pr := Unique.prop_text(rec)
	if sh != "": bits.append(sh.to_lower())
	if pr != "": bits.append(pr)
	if bits.is_empty(): return "Built like most %s" % _sp_name(rec)
	var all: Array = ", ".join(bits).split(", ")
	return _cap(", ".join(all.slice(0, -1)) + " and " + all[-1] if all.size() > 1 else all[0])

static func voice_note(rec: Dictionary) -> String:
	match Unique.voice_word(rec):
		"Deep voice": return "A deep voice"
		"High voice": return "A high voice"
	return "An ordinary voice"

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
static func _date(t: int) -> String:
	if t <= 0: return "Before records were kept"
	var dt := Time.get_datetime_dict_from_unix_time(t)
	return "%d %s %d" % [dt["day"], MONTHS[int(dt["month"]) - 1], dt["year"]]

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
		"wild": return "Scanned in the wild" + ((" at " + place) if place != "" else "")
		"taken": return "Taken from %s" % String(o.get("from", "a rival")) + ((" at " + place) if place != "" else "")
		"egg": return "Hatched in your Nesting Nook"
		"boss_egg":
			var boss := String(w.get("lair", ""))
			var bn := String(Data.MOBS.get(boss, {}).get("name", "")) if boss != "" else ""
			return "Hatched from a Rare Egg" + ((" from %s" % bn) if bn != "" else "")
		"starter": return "Your first partner, hatched from the egg you chose"
		"market": return "Bought at the market" + ((" from %s" % String(o["from"])) if String(o.get("from", "")) != "" else "")
		"shelter":
			var giver := String(o.get("from", ""))
			return "Adopted from the shelter" + ((", raised by %s" % giver) if giver != "" else "")
		"transfer": return "Handed to you by %s" % String(o.get("from", "another hunter"))
		"event": return "Met at an event" + ((" at " + place) if place != "" else "")
	return "From before records were kept"

static func trainer_text(rec: Dictionary) -> String:
	var ot = rec.get("ot", null)
	if typeof(ot) != TYPE_DICTIONARY: return "Not written down"
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
	return "%s and %s%s" % [names[0], names[1], (", generation %d" % gen) if gen > 1 else ""]

static func food_text(rec: Dictionary) -> String:
	var likes: Dictionary = rec.get("likes", {}) if typeof(rec.get("likes", null)) == TYPE_DICTIONARY else {}
	if likes.is_empty(): return "Not found out yet"
	if not (rec.get("known", []) as Array).has("food"): return "Not found out yet: try a few foods"
	return "Loves %s" % Care.food_name(String(likes.get("food", ""))).to_lower()

## A row: a small icon, a short muted label, the value (one line where it can), an optional extra.
static func _row(parent: Control, k: String, val: String, col := UI.INK, extra: Control = null, icon := "") -> void:
	var r := UI.hbox(8)
	var ic: Control = UI.IconDot.new(icon, UI.MUTED, 14.0) if icon != "" else Control.new()
	ic.custom_minimum_size = Vector2(14, 14)
	r.add_child(ic)
	var kl := UI.label(k, UI.T_SMALL, UI.MUTED)
	kl.custom_minimum_size.x = 74
	r.add_child(kl)
	var vl := UI.label(val, UI.T_SMALL, col, UI.semi)
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if extra == null else TextServer.AUTOWRAP_OFF
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL if extra == null else Control.SIZE_SHRINK_BEGIN
	vl.custom_minimum_size.x = 120 if extra == null else 0
	r.add_child(vl)
	if extra: r.add_child(extra)       # (right after the value: an eye colour swatch)
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

## Short values for the rows (the long sentences above stay for places that read as prose).
const HABIT_SHORT := {"tail_chase": "Chases its tail", "head_tilt": "Tilts its head", "hop": "Bouncy", "sway": "Sways",
	"sneeze": "Sneezy", "stretch": "Big stretcher", "ear_flick": "Flicks its ears", "look_around": "Watchful"}
const SIZE_SHORT := {"XS": "very small (rare)", "S": "small", "M": "average", "L": "large", "XL": "very large (rare)"}

static func size_short(rec: Dictionary) -> String:
	var si := Unique.size_info(rec)
	var b := String(si["build"])
	return "%d cm  ·  %.1f kg  ·  %s%s" % [int(round(float(si["cm"]))), float(si["kg"]), SIZE_SHORT.get(String(si["tag"]), "average"), (", " + b) if b != "" else ""]

static func coat_short(rec: Dictionary) -> String:
	var d := Unique.of(rec)
	var c := String(Unique.MARK_COL_NAMES.get(String(d.get("mark_col", "dark")), "dark"))
	match String(d.get("mark", "plain")):
		"spots": return "%s spots" % _cap(c)
		"stripes": return "%s stripes" % _cap(c)
		"patches": return "%s patches" % _cap(c)
		"freckles": return "%s freckles" % _cap(c)
	return "Plain"

static func build_short(rec: Dictionary) -> String:
	var bits: Array = []
	for t in [Unique.shape_text(rec), Unique.prop_text(rec)]:
		if t != "":
			for x in String(t).split(", "): bits.append(String(x).to_lower())
	if bits.is_empty(): return "Typical"
	return _cap(", ".join(bits.slice(0, 2)))

static func voice_short(rec: Dictionary) -> String:
	return {"Deep voice": "Deep", "High voice": "High"}.get(Unique.voice_word(rec), "Ordinary")

static func birth_short(rec: Dictionary) -> String:
	var b = Unique.of(rec).get("birth", [])
	if typeof(b) != TYPE_ARRAY or (b as Array).size() < 2: return ""
	return "%s on its %s" % [_cap(String(b[0])), String(b[1])]

static func food_short(rec: Dictionary) -> String:
	var likes: Dictionary = rec.get("likes", {}) if typeof(rec.get("likes", null)) == TYPE_DICTIONARY else {}
	if likes.is_empty() or not (rec.get("known", []) as Array).has("food"): return "Not found yet"
	return "Loves %s" % Care.food_name(String(likes.get("food", ""))).to_lower()

static func origin_short(rec: Dictionary) -> String:
	var o: Dictionary = rec.get("origin", {}) if typeof(rec.get("origin", null)) == TYPE_DICTIONARY else {}
	var w: Dictionary = o.get("where", {}) if typeof(o.get("where", null)) == TYPE_DICTIONARY else {}
	var place := String(w.get("island", w.get("map", "")))
	match String(o.get("how", "unknown")):
		"wild": return "Scanned" + ((" at " + place) if place != "" else " in the wild")
		"taken": return "Taken from %s" % String(o.get("from", "a rival"))
		"egg": return "Hatched at home"
		"boss_egg": return "Hatched from a Rare Egg"
		"starter": return "Your first partner"
		"market": return "From the market"
		"shelter": return "Adopted from the shelter"
		"transfer": return "Handed to you"
		"event": return "Met at an event"
	return "Before records"

## Its looks and habits (Unique), one short line each.
static func looks(rec: Dictionary, parent: Control) -> void:
	var sx := Unique.sex(rec)
	if sx != "":
		var r := UI.hbox(8)
		r.add_child(UI.sex_icon(rec, 14.0))
		var kl := UI.label("Sex", UI.T_SMALL, UI.MUTED); kl.custom_minimum_size.x = 74
		r.add_child(kl)
		r.add_child(UI.label(Unique.sex_name(rec), UI.T_SMALL, UI.SEX_COL[sx], UI.semi))
		parent.add_child(r)
	_row(parent, "Size", size_short(rec), UI.INK, null, "ruler")
	var ms := Mutations.of(rec).filter(func(m): return String(Mutations.info(m).get("group", "")) == "size")
	if not ms.is_empty():
		_row(parent, "", "%s: a size all its own" % Mutations.name_of(String(ms[0])))
	_row(parent, "Coat", coat_short(rec), UI.INK, null, "paw")
	_row(parent, "Eyes", Unique.eye_name(rec), UI.INK, Swatch.new(Unique.eye_col(rec)), "eye")
	_row(parent, "Build", build_short(rec), UI.INK, null, "jump")
	_row(parent, "Habit", String(HABIT_SHORT.get(String(Unique.of(rec).get("quirk", "")), Unique.quirk_name(rec))), UI.INK, null, "dance")
	_row(parent, "Voice", voice_short(rec), UI.INK, null, "pulse")
	var bm := birth_short(rec)
	if bm != "": _row(parent, "Birthmark", bm, UI.INK, null, "burst")
	_row(parent, "Food", food_short(rec), UI.INK, null, "tonic")

## Where it came from (Save.register), one short line each.
static func history(rec: Dictionary, parent: Control) -> void:
	_row(parent, "Origin", origin_short(rec), UI.INK, null, "pin")
	var o: Dictionary = rec.get("origin", {}) if typeof(rec.get("origin", null)) == TYPE_DICTIONARY else {}
	_row(parent, "Date", _date(int(float(o.get("t", rec.get("born", 0))))), UI.INK, null, "clock")
	_row(parent, "Raised by", trainer_text(rec), UI.INK, null, "home")
	var pt := parents_text(rec)
	if pt != "": _row(parent, "Parents", pt, UI.INK, null, "egg")
	if rec.has("serial"): _row(parent, "Number", "#%04d" % int(rec["serial"]), UI.INK, null, "info")
	var ed = rec.get("edition", null)
	if typeof(ed) == TYPE_DICTIONARY:
		_row(parent, "Edition", "%s, #%d of %d" % [String(ed.get("kind", "")).capitalize(), int(ed.get("serial", 0)), int(ed.get("cap", 0))], UI.INK, null, "gem")

## The whole About section. compact: just the headline notes (for side panels).
static func block(rec: Dictionary, parent: Control, compact := false) -> void:
	if rec.is_empty(): return
	if compact:
		var top := UI.hbox(6)
		top.add_child(UI.sex_icon(rec, 13.0))
		var sl := UI.label(size_short(rec), UI.T_SMALL, UI.INK, UI.semi)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.custom_minimum_size.x = 240
		top.add_child(sl)
		parent.add_child(top)
		var l := UI.label("%s  ·  %s eyes  ·  %s" % [coat_short(rec), Unique.eye_name(rec), String(HABIT_SHORT.get(String(Unique.of(rec).get("quirk", "")), Unique.quirk_name(rec)))], 12, UI.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 260
		parent.add_child(l)
		var ol := UI.label(origin_short(rec) + (("  ·  #%04d" % int(rec["serial"])) if rec.has("serial") else ""), 12, UI.MUTED)
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ol.custom_minimum_size.x = 260
		parent.add_child(ol)
		return
	parent.add_child(UI.section("Who it is"))
	looks(rec, parent)
	parent.add_child(UI.spacer(4))
	parent.add_child(UI.section("Where it's from"))
	history(rec, parent)
