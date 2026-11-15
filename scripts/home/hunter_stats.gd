class_name HunterStats
extends RefCounted
## The Stats tab beside the Relics screen: one row per open Hunter (matches, knocks, revives, damage per
## match, times you got out) and a totals row, most played first, unplayed Hunters greyed. The numbers are
## Save.d["classes"]["hunters"][id] (ClassUnlock.after_match counts them; "matches" and "damage" were added in
## save v14). No graphs: one table.

const TITLE := "Hunter stats"
const TABS := ["Relics", "Stats"]
const COLUMNS := ["Hunter", "Matches", "Knocks", "Revives", "Damage / match", "Got out"]
const NAME_W := 190.0      # px, the Hunter column
const COL_W := 120.0       # px, each number column

## v13 -> v14 (Save._migrate_13_to_14): a Hunter with counted matches has played at least as many matches as it
## got out of (and one at least). Its damage stays 0 (not recorded before), so its damage per match shows "-".
static func migrate(data: Dictionary) -> void:
	var c = data.get("classes")
	if typeof(c) != TYPE_DICTIONARY or typeof(c.get("hunters")) != TYPE_DICTIONARY:
		return
	for id in c["hunters"]:
		var s = c["hunters"][id]
		if typeof(s) == TYPE_DICTIONARY and not s.is_empty() and not s.has("matches"):
			s["matches"] = maxi(1, int(s.get("extracts", 0)))

## One row of numbers for a Hunter's stats dict: {id, matches, knocks, revives, damage, got_out}.
static func row(id: String, s: Dictionary) -> Dictionary:
	return {"id": id, "matches": int(s.get("matches", 0)), "knocks": int(s.get("knocks", 0)),
			"revives": int(s.get("revives", 0)), "damage": int(s.get("damage", 0)),
			"got_out": int(s.get("extracts", 0))}

## The open Hunters' rows, most played first (ties in the usual Hunter order).
static func rows() -> Array:
	var per: Dictionary = ClassUnlock.state().get("hunters", {})
	var out: Array = []
	for id in ClassUnlock.open_ids():
		out.append(row(String(id), per.get(id, {})))
	out.sort_custom(func(a, b): return int(a["matches"]) > int(b["matches"]))      # (stable: ties keep Arch order)
	return out

## The totals over rows.
static func total(rs: Array) -> Dictionary:
	var t := row("", {})
	for r in rs:
		for k in ["matches", "knocks", "revives", "damage", "got_out"]:
			t[k] = int(t[k]) + int(r[k])
	return t

## "1,234 / match", or "-" when no damage was counted.
static func per_match(r: Dictionary) -> String:
	if int(r["damage"]) <= 0 or int(r["matches"]) <= 0:
		return "-"
	return str(int(round(float(r["damage"]) / float(r["matches"]))))

static func cells(r: Dictionary) -> Array:
	var name_txt := Arch.label(String(r["id"])) if String(r["id"]) != "" else "All Hunters"
	return [name_txt, str(r["matches"]), str(r["knocks"]), str(r["revives"]), per_match(r), str(r["got_out"])]

## The Relics | Stats switch, shown under both screens' titles.
static func tab_row(home: Node, cur: String) -> Control:
	var open_tab := func(nm: String) -> void:
		if nm == "Stats":
			open(home)
		else:
			HomeClasses.open(home)
	return UI.tabs(TABS, cur, open_tab)

static func open(home: Node) -> void:
	var v: VBoxContainer = home._new_panel(TITLE, NAME_W + COL_W * 5.0 + 120.0, true)
	UI.subtitle(v, "How you do with each Hunter. Most played first.")
	v.add_child(tab_row(home, "Stats"))
	var grid := GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for i in COLUMNS.size():
		grid.add_child(_cell(COLUMNS[i], i, UI.ACCENT_HI))
	var rs := rows()
	for r in rs:
		var col := UI.INK if int(r["matches"]) > 0 else Color(UI.MUTED, 0.45)
		var cs := cells(r)
		for i in cs.size():
			grid.add_child(_cell(cs[i], i, col))
	var cs := cells(total(rs))
	for i in cs.size():
		grid.add_child(_cell(cs[i], i, UI.GOLD))

static func _cell(txt: String, i: int, col: Color) -> Label:
	var l := UI.label(txt, 16, col)
	l.custom_minimum_size.x = NAME_W if i == 0 else COL_W
	if i > 0:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l
