extends RefCounted
## --results-ways-check: how a match ends for you under Limited Ways Out (scripts/match/ways_result.gd,
## docs/decisions/0051, spec task 5). Placing among the squads (ties, a squad that left, a mate still in),
## placement pay and its cap, the `how` and `place` fields of a real match's result, Game.apply_result paying
## the gems once and only to a squad that did not leave, and the results screen's few lines. Never touches the save.

var bad := 0
const MAJOR := {"egg": {"sp": "zapple"}, "goods": {"heartwood": 2, "starstone": 2}}

## A stand-in Hunter: the placing only reads team, out, extracted and the died_at meta.
class H extends Node:
	var team := 0
	var out := false
	var extracted := false
	var lvl := 2

func ok(cond: bool, what: String) -> void:
	print("RESULTSWAYS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _h(team: int, out := false, died := -1.0, left := false, lvl := 2) -> H:
	var h := H.new()
	h.lvl = lvl
	h.team = team
	h.out = out
	h.extracted = left
	if died >= 0.0: h.set_meta("died_at", died)
	return h

## A finished match's result with the plain fields filled in.
func _res(extra: Dictionary) -> Dictionary:
	var r := {"extracted": false, "why": "test", "caught": [], "seeds": {}, "kin_runs": [], "tier": 0, "time": 400}
	r.merge(extra, true)
	return r

func _texts(n: Node, into: Array) -> Array:
	if n is Label: into.append((n as Label).text)
	for c in n.get_children(): _texts(c, into)
	return into

func _has(texts: Array, part: String) -> bool:
	return texts.any(func(t): return String(t).contains(part))

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_placing()
	_pay_and_lines()
	_other_seat()
	_real_match(main)
	_apply()
	_hiding()
	await _screen(main)
	print("RESULTSWAYS DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _placing() -> void:
	# squads 1, 2: out early; 3: still standing; 4: left by a seat; 0 (ours): out at 100
	var hs: Array = [_h(0, true, 100.0), _h(1, true, 50.0), _h(1, true, 90.0), _h(2, true, 80.0), _h(3)]
	hs.append(_h(4, false, -1.0, true))
	var p := WaysResult.placing(hs, 0, 100.0)
	ok(
		p.get("place", 0) == 3 and p.get("squads", 0) == 5,
		"out at 100 with one still standing and one gone: 3rd of 5 (%s)" % p
	)
	ok(
		WaysResult.placing(hs, 1, 100.0).get("place", 0) == 4,
		"a squad is over when its last Hunter is out: team 1 (50, 90) is 4th"
	)
	ok(WaysResult.placing(hs, 4, 100.0).is_empty(), "a squad that left by a seat has no place")
	var mate: Array = [_h(0, true, 60.0), _h(0, false, -1.0, true), _h(1)]
	ok(WaysResult.placing(mate, 0, 70.0).is_empty(), "one Hunter of ours out the door: no place for the squad")
	var alive: Array = [_h(0, true, 60.0), _h(0), _h(1, true, 20.0), _h(2)]
	ok(
		WaysResult.placing(alive, 0, 80.0).get("place", 0) == 2,
		"we give up with a mate still in: we place by now (80), under the one standing"
	)
	var fall: Array = [_h(0, true, 720.0), _h(1, true, 720.0), _h(2, true, 720.0)]
	ok(WaysResult.placing(fall, 0, 720.0).get("place", 0) == 1, "the islands fall on everyone at once: a tie")

func _pay_and_lines() -> void:
	var pays := [[1, 40], [4, 30], [9, 5], [10, 0]].map(func(c): return WaysResult.pay(c[0], 10) == c[1])
	ok(pays.all(func(b): return b), "placement pay: 5 per squad below, at most 40, nothing for last")
	ok(WaysResult.pay(1, 1) == 0, "alone in the match: no pay")
	ok(
		[1, 2, 3, 11, 13, 21].map(WaysResult.ordinal) == ["1st", "2nd", "3rd", "11th", "13th", "21st"],
		"ordinals"
	)
	for how in ["lair", "heart_early", "uplink", "heart_final"]:
		var line := WaysResult.how_line({"extracted": true, "how": how, "where": "Outpost Two"})
		ok(line != "" and not line.contains("%s"), "how '%s' reads: %s" % [how, line.strip_edges()])
	ok(
		WaysResult.how_line({"extracted": true, "how": "uplink", "where": "Outpost Two"}).contains("Outpost Two"),
		"the uplink line names the outpost"
	)
	ok(
		WaysResult.how_line({"extracted": false, "place": 3, "squads": 10}).begins_with("Your squad placed 3rd of 10"),
		"a lost run says its placing"
	)
	ok(WaysResult.how_line({"extracted": false}) == "", "no place, no how: nothing said")
	ok(
		WaysResult.reward_line(MAJOR) == "Heart reward: a Rare Egg, 2 Heartwood, 2 Starstone.",
		"the major reward line"
	)
	ok(
		WaysResult.reward_line({"egg": {}, "goods": {"heartwood": 1}}) == "Heart reward: 1 Heartwood.",
		"the minor reward line"
	)

## The results screen names the other Heart seat and what it would have paid; no line for any other way out.
func _other_seat() -> void:
	var early := WaysResult.other_line("heart_early")
	var final := WaysResult.other_line("heart_final")
	ok(early.contains("final seat (10:00") and early.contains("150 gems") and early.contains("Rare Egg"),
		"the early exit says the final seat would have paid the major set: %s" % early)
	ok(final.contains("early seat") and final.contains("40 gems") and not final.contains("Egg"),
		"the final exit says the early seat would have paid the minor set: %s" % final)
	ok(WaysResult.other_line("uplink") == "" and WaysResult.other_line("") == "", "no line for other ways out")

## A real match: the player's squad is wiped second of three; the result carries place and no how.
func _real_match(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 1, "tier": 0, "length": 1e9, "seed": 7302, "no_drop": true, "heart": true,
		"god": true})
	m.set_process(false)
	var bots: Array = m.hunters.filter(func(h): return h != m.player)
	for o in bots: o.ctrl = "idle"
	m.eliminate(bots[0], null, "test")
	m.step(Match.DT * 60.0)
	m.eliminate(m.player, null, "test")
	m.player.set_meta("died_why", "test")
	var p := WaysResult.placing(m.hunters, m.player.team, m.time)
	ok(
		p.get("place", 0) == 2 and p.get("squads", 0) == 3,
		"a real match: second of three after one squad went first (%s)" % p
	)
	m._extract(bots[1], "heart_final", "the Heart")
	ok(
		WaysResult.placing(m.hunters, m.player.team, m.time).get("place", 0) == 2,
		"a squad leaving by a seat after us still ranks above us"
	)
	m.result = {"extracted": false, "why": "test"}
	m._finish()
	var r: Dictionary = Game.last_result
	ok(
		r.get("place", 0) == 2 and r.get("squads", 0) == 3 and not r.has("placed"),
		"_finish writes place and squads (the old stub 'placed' is gone)"
	)
	m.queue_free()

func _apply() -> void:
	Save.d = Save.fresh()
	var g0 := int(Save.d["gems"])
	var out := Game.apply_result(_res({"place": 3, "squads": 10}))
	ok(
		int(out.get("place_gems", 0)) == 35 and int(Save.d["gems"]) == g0 + 35,
		"apply_result pays 35 gems to 3rd of 10 (%d)" % (int(Save.d["gems"]) - g0)
	)
	g0 = int(Save.d["gems"])
	out = Game.apply_result(_res({"extracted": true, "how": "heart_early", "place": 3, "squads": 10, "gems": 40}))
	ok(
		not out.has("place_gems") and int(Save.d["gems"]) == g0 + 40,
		"a squad that left gets its seat's gems and no placement pay"
	)
	g0 = int(Save.d["gems"])
	out = Game.apply_result(_res({"tutorial": true, "place": 1, "squads": 4}))
	ok(not out.has("place_gems") and int(Save.d["gems"]) == g0, "the tutorial pays no placement")
	out = Game.apply_result(_res({}))
	ok(not out.has("place_gems"), "no place in the result (a match with no squads to rank): no pay")

## A squad all still at run level 1 at the end is paid nothing and the screen says why; one that levelled is paid.
func _hiding() -> void:
	var hs: Array = [_h(0, true, 100.0, false, 1), _h(0, true, 90.0, false, 1), _h(1, true, 50.0)]
	ok(WaysResult.placing(hs, 0, 100.0).get("hid", false), "a squad all at level 1 hid")
	hs[1].lvl = 2
	var levelled := WaysResult.placing(hs, 0, 100.0)
	ok(not levelled.get("hid", true), "one Hunter past level 1 and the squad levelled")
	Save.d = Save.fresh()
	var g0 := int(Save.d["gems"])
	var out := Game.apply_result(_res({"place": 1, "squads": 10, "hid": true}))
	ok(not out.has("place_gems") and int(Save.d["gems"]) == g0, "a hiding squad placing 1st of 10 gets no gems")
	out = Game.apply_result(_res({"place": 1, "squads": 10, "hid": false}))
	ok(int(out.get("place_gems", 0)) == 40, "a levelled squad is paid as before")
	var line := WaysResult.hid_line(_res({"place": 1, "squads": 10, "hid": true}))
	ok(line.contains("never levelled"), "the line says why")
	ok(WaysResult.hid_line(_res({"place": 1, "hid": false})) == "", "no line for a levelled squad")
	ok(WaysResult.hid_line(_res({"extracted": true, "hid": true})) == "", "no line for a squad that left")

func _screen(main: Node) -> void:
	Save.d = Save.fresh()
	var r := _res({"place": 3, "squads": 10})
	var scr: Control = load("res://scripts/ui/results.gd").new()
	main.add_child(scr)
	scr.show_result(r)
	var t := _texts(scr, [])
	ok(
		_has(t, "Your squad placed 3rd of 10") and _has(t, "Placement pay: 35 gems"),
		"the lost screen shows the placing and the pay"
	)
	ok(not _has(t, "never levelled"), "a levelled squad's screen has no hiding line")
	scr.queue_free()
	Save.d = Save.fresh()
	scr = load("res://scripts/ui/results.gd").new()
	main.add_child(scr)
	scr.show_result(_res({"place": 3, "squads": 10, "hid": true}))
	t = _texts(scr, [])
	ok(_has(t, "No placement pay: your squad never levelled up."), "the hiding screen says why")
	ok(not _has(t, "Placement pay:"), "and shows no pay")
	scr.queue_free()
	Save.d = Save.fresh()
	var rw := _res({"extracted": true, "how": "heart_final", "where": "the Heart", "gems": 150,
		"heart": MAJOR.merged({"seeds": {}, "gems": 150, "trust": 20.0})})
	scr = load("res://scripts/ui/results.gd").new()
	main.add_child(scr)
	scr.show_result(rw)
	t = _texts(scr, [])
	ok(
		_has(t, "You held the Heart ring and left") and _has(t, "Heart reward: a Rare Egg, 2 Heartwood, 2 Starstone."),
		"the final seat screen shows how you left and the reward"
	)
	ok(not _has(t, "Placement pay") and not _has(t, "placed"), "and no placing")
	scr.queue_free()
	ok(_has(t, "The early seat (the Gate) would have paid: 40 gems"), "and what the early seat would have paid")
	scr.queue_free()
	Save.d = Save.fresh()
	scr = load("res://scripts/ui/results.gd").new()
	main.add_child(scr)
	scr.show_result(_res({"extracted": true, "how": "heart_early", "where": "the Heart", "gems": 40,
		"heart": {"egg": {}, "goods": {"heartwood": 1}, "seeds": {}, "gems": 40, "trust": 6.0}}))
	t = _texts(scr, [])
	ok(_has(t, "You left through the Heart Gate") and _has(t, "Heart reward: 1 Heartwood."), "the early seat screen")
	ok(_has(t, "The final seat (10:00, one squad) would have paid: 150 gems"), "...says what the final would have paid")
	scr.queue_free()
	await main.get_tree().process_frame
