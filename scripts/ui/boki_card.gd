class_name BokiCard
extends RefCounted
## The Boki card's first tab, read at a glance (docs/UI_DESIGN.md §7): how far to the next level, how it
## feels (hunger and mood as icons with one line), its bond as a ring with a percent, what it likes, and
## its task and skills (the WorkView chips). Two columns that never scroll at 1280x720.

const RING_PX := 64.0  # design px, the bond ring's width and height
const RING_W := 7.0  # design px, the ring's stroke
const HUNGER_FULL := 70.0  # Full need (0-100) from which a Boki counts as well fed
const HUNGER_LOW := 40.0  # below this it is hungry
const ICON_PX := 20.0  # design px, the hunger and mood icons
const WANTS := {"food": "a meal", "energy": "a nap", "clean": "a bath", "joy": "some play"}


## The bond ring: trust 0-100 as an arc with its percent in the middle.
class Ring:
	extends Control
	var frac := 0.0
	var pct := ""

	func _init(f: float, text: String) -> void:
		frac = f
		pct = text
		custom_minimum_size = Vector2(UI.fs(int(RING_PX)), UI.fs(int(RING_PX)))
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var mid := size * 0.5
		var w := UI.fs(int(RING_W))
		var rad := minf(size.x, size.y) * 0.5 - w
		draw_arc(mid, rad, 0.0, TAU, 48, Color(0, 0, 0, 0.35), w, true)
		draw_arc(mid, rad, -PI * 0.5, -PI * 0.5 + TAU * clampf(frac, 0.0, 1.0), 48, UI.PINK, w, true)
		var fsz := UI.fs(16)
		var tw := UI.semi.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		draw_string(
			UI.semi, Vector2(mid.x - tw * 0.5, mid.y + fsz * 0.35), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, UI.INK
		)


## Fills the card's two columns.
static func fill(h: Node, rec: Dictionary, c1: Control, c2: Control, reopen: Callable) -> void:
	c1.add_child(UI.section("Level"))
	c1.add_child(_level(rec))
	c1.add_child(UI.section("Feeling"))
	c1.add_child(_feeling(rec))
	c1.add_child(UI.section("Likes"))
	ZoneAffinity.add_line(c1, rec)
	var known: Array = rec["known"]
	var lk: Dictionary = rec["likes"]
	c1.add_child(_like("Loves", known.has("food"), Care.food_name(lk["food"]) if known.has("food") else ""))
	c1.add_child(_like("Won't eat", known.has("hates"), Care.food_name(lk["hates"]) if known.has("hates") else ""))
	c1.add_child(_like("Favourite game", known.has("play"), Care.PLAY_NAMES[lk["play"]] if known.has("play") else ""))
	if known.size() < 3:
		c1.add_child(UI.para(KinSpeak.about(rec, "Feed {him} and play with {him} to find out."), 12, UI.FAINT))
	c2.add_child(UI.section("Bond"))
	c2.add_child(_bond(rec))
	WorkView.card_section(h, rec, c2, reopen)


## "Level 8" with the XP bar and what is left to the next level.
static func _level(rec: Dictionary) -> Control:
	var lv := int(rec["level"])
	var r := UI.hbox(10)
	r.add_child(UI.label("Level %d" % lv, UI.T_BODY, UI.INK, UI.semi))
	var capped := lv >= Evo.cap()
	var need := maxi(1, Game.xp_need(lv))
	var have := int(rec.get("xp", 0))
	var bb := UI.bar(1.0 if capped else float(have) / float(need), UI.TEAL, 120, 8)
	bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(bb)
	var to_go := "Top level" if capped else "%d XP to level %d" % [need - have, lv + 1]
	var l := UI.label(to_go, 12, UI.MUTED, UI.semi)
	l.tooltip_text = "" if capped else "%d of %d XP" % [have, need]
	r.add_child(l)
	return r


## Hunger icon, mood icon and one line: "Peckish and happy  ·  wants a nap".
static func _feeling(rec: Dictionary) -> Control:
	var food := Care.need(rec, "food")
	var ss := Care.starve_stage(rec)
	var starving := ss != "" and ss != "dead"
	var hungry := food < HUNGER_LOW or starving
	var hunger := "Well fed"
	var hunger_col := UI.GOOD
	if food < HUNGER_FULL:
		hunger = "Peckish"
		hunger_col = UI.GOLD
	if hungry:
		hunger = "Hungry"
		hunger_col = UI.BAD
	if starving:
		hunger = String(Care.STARVE_INFO[ss][0])
	var mood := ZoneCards.mood(rec)
	var line := "%s and %s" % [hunger, mood]
	var want := Care.want(rec)
	if want != "" and not (want == "food" and hungry):
		line += "  ·  wants " + String(WANTS[want])
	var r := UI.hbox(8)
	var hi := Icons.Glyph.new("seed", hunger_col, ICON_PX)
	hi.tooltip_text = "Hunger: %d of 100" % int(food)
	hi.mouse_filter = Control.MOUSE_FILTER_PASS
	var mi := Icons.Glyph.new(mood, ZoneCards.MOOD_COL[mood], ICON_PX)
	mi.tooltip_text = "Mood: " + mood
	mi.mouse_filter = Control.MOUSE_FILTER_PASS
	r.add_child(hi)
	r.add_child(mi)
	var l := UI.label(line, UI.T_SMALL, UI.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FitLabel.shrink(l)
	l.tooltip_text = line
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	r.add_child(l)
	return r


## The ring with its percent, then the bond's name, what it brings and what comes next.
static func _bond(rec: Dictionary) -> Control:
	var bd: Array = Care.bond(rec)
	var nb: Array = Care.next_bond(rec)
	var trust := float(rec["trust"])
	var r := UI.hbox(12)
	r.add_child(Ring.new(trust / 100.0, "%d%%" % int(trust)))
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_child(UI.label(String(bd[1]), UI.T_HEAD, UI.PINK, UI.big))
	tv.add_child(UI.para(String(bd[2]), 12, UI.MUTED))
	var next := "Fully bonded"
	if nb.size() > 0:
		next = "Next: %s at %d%%" % [nb[1], int(nb[0])]
	tv.add_child(UI.label(next, 12, UI.FAINT))
	r.add_child(tv)
	return r


## The last thing it remembers, and the Soul Shrine's title (the About tab).
static func remembers(rec: Dictionary, into: Control) -> void:
	var mem: Array = rec.get("memory", [])
	if mem.size() > 0:
		into.add_child(UI.section("Remembers"))
		var t := String(mem[-1]["text"])
		into.add_child(UI.para("\u201c%s\u201d" % (t.substr(0, 1).to_upper() + t.substr(1)), 13, UI.INK.darkened(0.1)))
	if String(rec.get("title", "")) != "":
		into.add_child(
			UI.para("%s %s  ·  came back from the Soul Shrine" % [rec["name"], rec["title"]], 12, Color("bff8ec"))
		)


static func _like(what: String, known: bool, val: String) -> Control:
	if known:
		return UI.kv(what, val)
	return UI.kv(what, "???", UI.FAINT)
