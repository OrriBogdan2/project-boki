extends RefCounted
## --match-summary-check: the one-card match summary. Assists go to rivals who hurt a Hunter shortly
## before the knock, the squad's place ranks squads that got out above those knocked out, and the
## results screen shows place, four numbers, your Boki's summons and the squadmates (in plain words).

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MATCHSUM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _hunter(team: int, nm: String) -> Hunter:
	var h := Hunter.new()
	h.team = team
	h.pname = nm
	h.max_hp = 100.0
	h.hp = 10.0
	return h

func _texts(root: Node) -> String:
	return " ".join(root.find_children("*", "Label", true, false).map(func(l): return (l as Label).text))

func _has_summons(root: Node, n: int) -> bool:
	var tagged := root.find_children("*", "", true, false).filter(func(c): return c.has_meta("boki_summons"))
	return tagged.size() == 1 and tagged[0].get_meta("boki_summons") == n

func _assists_and_healing() -> void:
	var me := _hunter(0, "Me")
	var ally := _hunter(0, "Ally")
	var foe := _hunter(1, "Foe")
	var victim := _hunter(1, "Victim")
	MatchSummary.on_hurt(ally, victim, 10.0)
	MatchSummary.on_hurt(me, victim, 12.0)
	MatchSummary.on_hurt(victim, victim, 12.0)
	MatchSummary.on_knock(victim, me, 13.0)
	ok(me.assists == 0 and ally.assists == 1, "the knocker gets the knock, the helper an assist")
	MatchSummary.on_hurt(ally, victim, 20.0)
	MatchSummary.on_knock(victim, me, 21.0 + MatchSummary.ASSIST_WINDOW)
	ok(ally.assists == 1, "damage from long before the knock is not an assist")
	MatchSummary.on_hurt(foe, victim, 30.0)
	MatchSummary.on_hurt(me, victim, 30.0)
	ok(victim.hurt_by.size() == 1, "only rivals are remembered")
	me.heal(0.5)
	ok(is_equal_approx(me.healed, 0.5), "health you get back is counted")

## Squads: 0 (me, ally) knocked out at 200 s and 150 s, 1 (foe) out at 100 s, 2 (far) extracted at 50 s.
func _places(hs: Array) -> void:
	var me: Hunter = hs[0]
	var ally: Hunter = hs[1]
	var foe: Hunter = hs[2]
	var far: Hunter = hs[3]
	far.extracted = true
	far.left_at = 50.0
	foe.out = true
	foe.left_at = 100.0
	me.out = true
	me.left_at = 200.0
	ally.out = true
	ally.left_at = 150.0
	ok(MatchSummary.placement(hs, 0, 300.0) == Vector2i(2, 3), "knocked out after a rival: 2nd of 3")
	ok(MatchSummary.placement(hs, 1, 300.0) == Vector2i(3, 3), "the earliest knocked-out squad is last")
	ok(MatchSummary.placement(hs, 2, 300.0) == Vector2i(1, 3), "extracting beats being knocked out")
	foe.out = false
	foe.left_at = -1.0
	ok(MatchSummary.placement(hs, 0, 300.0) == Vector2i(3, 3), "a squad still in at the end beats the knocked out")

func run(main: Node) -> void:
	Save.no_write = true
	_assists_and_healing()
	var hs := [_hunter(0, "Me"), _hunter(0, "Ally"), _hunter(1, "Foe"), _hunter(2, "Far")]
	_places(hs)
	var me: Hunter = hs[0]
	var ally: Hunter = hs[1]
	var r := {"extracted": false, "why": "ko", "time": 200.0, "knocks": 2, "damage": 640, "taken": 100}
	me.dmg_done = 640.0
	me.knocks = 2
	me.assists = 3
	me.healed = 85.0
	ally.dmg_done = 210.0
	ally.knocks = 1
	ally.assists = 4
	ally.healed = 30.0
	MatchSummary.fill(r, hs, me, 300.0)
	var placed: bool = r["place"] == 3 and r["places"] == 3
	ok(placed and r["assists"] == 3 and r["healing"] == 85, "the result carries place, assists, healing")
	var squad: Array = r["squad"]
	ok(squad.size() == 1 and squad[0]["name"] == "Ally" and squad[0]["assists"] == 4, "and a row per squadmate")
	var kin := Save.new_kin("zapple")
	kin["name"] = "Zip"
	Save.d["roster"].append(kin)
	r["summons"] = 4
	var ran := {"hits": 3, "kos": 0, "throws": 4, "skills": 1, "revives": 0, "caught": 0, "won": 0}
	r["kin_runs"] = [{"uid": String(kin["uid"]), "events": [], "trust": 50.0, "stats": ran}]
	var scr: Control = load("res://scripts/ui/results.gd").new()
	main.add_child(scr)
	scr.show_result(r)
	var all := _texts(scr)
	ok(all.contains("#3") and all.contains("of 3 teams"), "results: the place, big")
	for w in ["DAMAGE", "KNOCKS", "ASSISTS", "HEALING"]:
		ok(all.contains(w), "results: the %s number" % w)
	var row := all.contains("Ally") and all.contains("210 damage") and all.contains("4 assists")
	ok(row, "results: the squadmate's row")
	ok(_has_summons(scr, 4), "results: your Boki's summons")
	var gone := not all.contains("Times downed") and not all.contains("Armor")
	ok(gone, "results: the old stat clutter is gone")
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			dir = a.substr(12)
	if dir != "":
		await _shot(main, dir + "/results_card.png")
	print("MATCHSUM DONE, failures: ", bad)
	main.get_tree().quit()

func _shot(main: Node, path: String) -> void:
	for i in 120:
		await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT %s" % path)
