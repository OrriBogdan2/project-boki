extends RefCounted
## --hunter-stats-check: the Stats tab on the Relics screen (HunterStats, HunterStatsView, docs/decisions/0022).
##   1. finished expeditions (Game.apply_result) count into the played Hunter's row only: matches, knocks,
##      revives, damage per match, times got out; rows sort by most played and add up to the totals
##   2. a v11 save (per-Hunter tallies without matches or damage) upgrades to v12: each played Hunter gets
##      its fewest possible matches, damage per match counts only matches played after the upgrade
##   3. the farm: Relics | Stats tabs, the table with one row per owned or played Hunter, unplayed ones greyed
## Prints HUNTERSTATS lines and "HUNTERSTATS DONE, n checks, failures: n".

var bad := 0
var n := 0

func ok(cond: bool, what: String) -> void:
	n += 1
	print("HUNTERSTATS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	_counting()
	_migration()
	await _tab(main)
	print("HUNTERSTATS DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## A save with Vex and Lace open.
func _new_save() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["classes"]["picks"] = ["archer"]
	d["classes"]["open"] = ["gunslinger", "archer"]
	d["classes"]["seen"] = ["gunslinger", "archer"]
	Save.d = d

func _match(arch: String, out: bool, knocks: int, revives: int, damage: int) -> void:
	Game.apply_result({"arch": arch, "extracted": out, "why": "extracted" if out else "knocked out",
			"knocks": knocks, "revives": revives, "damage": damage, "kills": 0, "gems": 0, "seeds": {},
			"stats": {}, "lvl": 1, "caught": [], "kin_runs": [], "tonics": 0})

# ---------------------------------------------------------------- 1. counting
func _counting() -> void:
	_new_save()
	var rs := HunterStats.rows()
	ok(rs.size() == 2 and rs.all(func(r): return int(r["matches"]) == 0 and HunterStats.per_match(r) == -1),
			"a new save: a row per owned Hunter, all empty (%d)" % rs.size())
	_match("gunslinger", true, 1, 0, 200)
	_match("archer", true, 3, 1, 500)
	_match("archer", false, 1, 0, 300)
	var a := HunterStats.row("archer")
	ok(int(a["matches"]) == 2 and int(a["knocks"]) == 4 and int(a["revives"]) == 1 and int(a["outs"]) == 1,
			"Lace's row: 2 matches, 4 knocks, 1 revive, got out once (%s)" % str(a))
	ok(HunterStats.per_match(a) == 400, "Lace's damage per match is 800 / 2 (%d)" % HunterStats.per_match(a))
	var g := HunterStats.row("gunslinger")
	ok(int(g["matches"]) == 1 and int(g["knocks"]) == 1 and HunterStats.per_match(g) == 200 and int(g["outs"]) == 1,
			"Vex's row has only Vex's match (%s)" % str(g))
	ok(int(HunterStats.row("juggernaut")["matches"]) == 0, "a Hunter not played stays empty")
	rs = HunterStats.rows()
	var order := rs.map(func(r): return r["id"])
	ok(order == ["archer", "gunslinger"], "most played first (%s)" % str(order))
	var t := HunterStats.totals(rs)
	ok(int(t["matches"]) == 3 and int(t["knocks"]) == 5 and int(t["outs"]) == 2 and HunterStats.per_match(t) == 333,
			"totals add the rows up (%s)" % str(t))

# ---------------------------------------------------------------- 2. migration
func _migration() -> void:
	_new_save()
	var old := Save.d.duplicate(true)
	old["v"] = 11
	old["classes"]["hunters"] = {"archer": {"knocks": 5, "revives": 2, "extracts": 3}, "mage": {"knocks": 1}}
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION and Save.VERSION == 12, "a v11 save upgrades to v12")
	Save.d = old
	var a := HunterStats.row("archer")
	ok(int(a["matches"]) == 3 and int(a["knocks"]) == 5 and int(a["outs"]) == 3 and HunterStats.per_match(a) == -1,
			"Lace keeps her tallies and gets 3 matches (her get-outs), no damage figure yet (%s)" % str(a))
	ok(int(HunterStats.row("mage")["matches"]) == 1, "a Hunter played but never out counts 1 match")
	ok(HunterStats.rows().size() == 3, "the played but not owned Hunter gets a row too")
	_match("archer", true, 2, 0, 450)
	a = HunterStats.row("archer")
	ok(int(a["matches"]) == 4 and HunterStats.per_match(a) == 450,
			"after the upgrade damage per match counts only the new match (%s)" % str(a))
	HunterStats.migrate(old)
	ok(int(HunterStats.row("archer")["matches"]) == 4, "running the migration again changes nothing")

# ---------------------------------------------------------------- 3. the farm
func _tab(main: Node) -> void:
	_new_save()
	_match("archer", true, 3, 1, 500)
	var hm = await main._hb_home()
	var tree := main.get_tree()
	HomeClasses.open(hm)
	await tree.process_frame
	var tab := _find(hm.panel_host, func(c): return c is Button and c.get_meta("tab", "") == "Stats")
	ok(tab != null, "the Relics screen has a Stats tab")
	if tab == null: return
	(tab as Button).pressed.emit()
	await tree.process_frame
	var grid: GridContainer = _find(hm.panel_host, func(c): return c is GridContainer
			and c.columns == HunterStatsView.HEADS.size())
	ok(hm.panel_open == HomeClasses.TITLE and grid != null, "Stats opens the table on the same screen")
	if grid == null: return
	var cells := grid.get_children().filter(func(c): return not c.is_queued_for_deletion())
	var cols := grid.columns
	ok(cells.size() == cols * 4, "a header, Lace, Vex and the totals (%d rows)" % (cells.size() / cols))
	ok((cells[cols] as Label).text == Arch.name_of("archer") and (cells[cols + 1] as Label).text == "1",
			"the played Hunter's row first, with its match")
	var vex := cells[cols * 2] as Label
	ok(vex.text == Arch.name_of("gunslinger") and vex.get_theme_color("font_color") == UI.FAINT,
			"the unplayed Hunter is greyed")
	ok((cells[cols * 3] as Label).text == "Total", "the totals row closes the table")
	var back := _find(hm.panel_host, func(c): return c is Button and c.get_meta("tab", "") == "Relics")
	(back as Button).pressed.emit()
	await tree.process_frame
	var viewer = hm.get_meta("hunter_viewer", null)
	ok(viewer != null and is_instance_valid(viewer), "Relics goes back to the Hunters")

func _find(node: Node, pred: Callable) -> Node:
	for c in node.get_children():
		if not c.is_queued_for_deletion() and pred.call(c): return c
		var f := _find(c, pred)
		if f: return f
	return null
