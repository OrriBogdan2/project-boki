extends RefCounted
## --hunter-stats-check: the Stats tab beside the Relics screen (HunterStats). A scripted match (through
## Game.apply_result, as an expedition ends) updates the right Hunter's row and the totals; unplayed Hunters
## sort last; a v13 save migrates (Hunters it played get a match count, others stay empty); the
## tab row has its two tabs. The save is never written.

var bad := 0

## Prints a HUNTERSTATS ok or FAIL line and counts failures.
func ok(cond: bool, what: String) -> void:
	print("HUNTERSTATS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A finished expedition for Game.apply_result: played as `arch`.
func _result(arch: String, extracted: bool, knocks: int, revives: int, damage: int) -> Dictionary:
	return {"arch": arch, "extracted": extracted, "why": "extracted" if extracted else "knocked out", "knocks": knocks,
			"revives": revives, "damage": damage, "kills": 0, "gems": 0, "seeds": {}, "stats": {}, "lvl": 1,
			"caught": [], "kin_runs": [], "tonics": 0}

func _row_of(id: String) -> Dictionary:
	for r in HunterStats.rows():
		if String(r["id"]) == id:
			return r
	return {}

## Runs the check and quits with 1 on any failure.
func run(main: Node) -> void:
	Save.no_write = true
	var old := Save.d
	_play()
	_migrate()
	_tabs(main)
	Save.d = old
	print("HUNTERSTATS %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## Two Hunters play; each row and the totals count only its own matches.
func _play() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["classes"]["all"] = true
	Save.d = d
	Game.apply_result(_result("archer", true, 3, 1, 900))
	Game.apply_result(_result("archer", false, 1, 0, 300))
	Game.apply_result(_result("juggernaut", true, 2, 2, 500))
	var a := _row_of("archer")
	ok(int(a["matches"]) == 2 and int(a["knocks"]) == 4 and int(a["revives"]) == 1 and int(a["got_out"]) == 1,
		"archer's row counts its two matches: %s" % str(a))
	ok(HunterStats.per_match(a) == "600", "damage per match is the mean (%s)" % HunterStats.per_match(a))
	var j := _row_of("juggernaut")
	ok(int(j["matches"]) == 1 and int(j["knocks"]) == 2 and int(j["got_out"]) == 1
			and HunterStats.per_match(j) == "500",
		"juggernaut's row counts only its own match: %s" % str(j))
	var rs := HunterStats.rows()
	ok(String(rs[0]["id"]) == "archer" and String(rs[1]["id"]) == "juggernaut", "most played first")
	ok(rs.slice(2).all(func(r): return int(r["matches"]) == 0), "every other Hunter is an empty row, last")
	var t := HunterStats.total(rs)
	ok(int(t["matches"]) == 3 and int(t["knocks"]) == 6 and int(t["revives"]) == 3 and int(t["got_out"]) == 2
			and int(t["damage"]) == 1700,
		"totals add the rows: %s" % str(t))
	ok(HunterStats.per_match(_row_of("ostra")) == "-", "an empty row shows a dash for damage per match")
	ok(HunterStats.cells(t)[0] == "All Hunters" and HunterStats.cells(a)[0] == Arch.label("archer"), "row labels")

## A v14 save: Hunters it counted get a match count (their escapes, at least 1); empty ones stay empty.
func _migrate() -> void:
	ok(Save.VERSION >= 15 and Save.MIGRATIONS.get(14, "") == "_migrate_14_to_15", "a 14 -> 15 step exists")
	var data := Save.fresh()
	data["v"] = 14
	data["classes"]["hunters"] = {"archer": {"extracts": 4, "knocks": 9}, "juggernaut": {"knocks": 1}, "mage": {}}
	ok(Save.migrate(data) and int(data["v"]) == Save.VERSION, "a v14 save loads")
	var h: Dictionary = data["classes"]["hunters"]
	ok(int(h["archer"]["matches"]) == 4 and int(h["archer"]["knocks"]) == 9 and int(h["juggernaut"]["matches"]) == 1,
		"played Hunters keep their counts and get a match count")
	ok(not (h["mage"] as Dictionary).has("matches"), "an empty Hunter stays empty")
	data["v"] = 13
	Save.migrate(data)
	ok(int(data["classes"]["hunters"]["archer"]["matches"]) == 4, "migrating again changes nothing")

## The Relics | Stats tab row (shown on both screens).
func _tabs(main: Node) -> void:
	ok(HunterStats.TABS == ["Relics", "Stats"] and HomeClasses.TITLE == HunterStats.TABS[0], "the tab names")
	var tab_row: Control = HunterStats.tab_row(main, "Stats")
	var buttons := tab_row.find_children("*", "Button", true, false)
	ok(tab_row is PanelContainer and buttons.size() == 2, "the tab row has two buttons")
	tab_row.free()
