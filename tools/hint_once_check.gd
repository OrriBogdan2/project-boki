extends RefCounted
## --hint-once-check: every first-time hint shows once per save. Three short bot matches on one save, each
## armed with the same triggers (a keg close by, the hero ultimate ready, the Blight's tide, a quest seat, the
## Heart, a knock); every line that reaches the message lane is recorded. Between matches the save is written
## and read back through the real load path.
##   1. the first match shows each hint line; no line shows twice in one match
##   2. the next two matches show none of them again (the knock card is the one exception: its showings are
##      counted in the save, KnockTip rules "showings", and it stops for good at that count)
##   3. every seen flag survives the save and load between matches
##   4. a hint that was acted on (a keg already broken, the ultimate already cast) never comes back either

const MATCHES := 3
const SAVE_PATH := "user://hint_once_check.json"  # the save round trip; never the real slot
const FIGHT_S := 3.0  # s: past FirstUltHint.HOLD_S, so the fight's first hits no longer hold the line back

var bad := 0
var lines_by_match: Array = []  # per match: every line that reached the lane, in order
var flags_before: Array = []  # seen flags at the end of the previous match


func ok(cond: bool, what: String) -> void:
	print("HINTONCE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Settings.set_v("tips", true, false)
	for i in MATCHES:
		var m := _start(main, 4300 + i)
		lines_by_match.append(_play(m))
		m.queue_free()
		_save_and_load(i)
	_judge()
	DirAccess.remove_absolute(SAVE_PATH)
	print("HINTONCE DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)


func _start(main: Node, seed_n: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1000.0, "seed": seed_n, "demo_kin": "cindle"})
	m.set_process(false)
	m.player.dropping = false
	m.player.riding = false  # (landed: the ship has dropped everyone)
	m.exits.seats.build()
	for h in m.hunters:
		if h != m.player:
			h.ctrl = "idle"
	return m


## One match's moments in order; returns every line the lane showed.
func _play(m: Match) -> Array:
	var seen: Array = []
	var p := m.player
	m._tip_t = 20.0
	m.time = 100.0
	_tick(m, seen)  # move, ability
	m._add_break("keg", p.pos + Vector3(3.0, 0.0, 0.0))
	_tick(m, seen)  # a keg close by
	_arm_ult(m)
	_tick(m, seen)
	m.time = Heart.r("tide_start_s") + 1.0
	m.exits.seats.lair._force(QuestSeat.S.OPEN, "hint-once")
	m.heart._force(Heart.S.CHARGING, "hint-once")
	for i in 3:  # one Ways Out line per frame (tide, quest, Heart)
		_tick(m, seen)
	_knock(m, seen)
	return seen


## The hero ultimate ready after a fight's first hits have passed.
func _arm_ult(m: Match) -> void:
	var p := m.player
	p.lvl = int(Hunter.ULT_AT[0])
	p.ak.cd["x"] = 0.0
	var foe: Hunter = m.hunters.filter(func(h: Hunter): return h.team != p.team)[0]
	CombatBus.hit_landed.emit(foe, p, 1.0, ["primary"])
	m.time += FIGHT_S


## The first knock: the card (twice in a row asks for one), then the down hint.
func _knock(m: Match, seen: Array) -> void:
	var foe: Hunter = m.hunters.filter(func(h: Hunter): return h.team != m.player.team)[0]
	if m.ktip:
		m.ktip.note(foe, 10.0, {})
	m.knock(m.player, foe, {})
	if m.ktip:
		m.ktip.on_knock()
	_tick(m, seen)


func _tick(m: Match, seen: Array) -> void:
	m._tips()
	var lane: MsgLane = m.hud.msgs
	for e: Dictionary in lane._shown + lane._waiting:
		seen.append(String(e["text"]))
	lane.clear()


## The save written and read back, as the game does between sessions.
func _save_and_load(n: int) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(Save.d))
	f.close()
	var flags: Dictionary = Save.d["tutorial"].duplicate()
	Save.load_from(SAVE_PATH)
	var back: Dictionary = Save.d["tutorial"]
	var lost: Array = flags.keys().filter(func(k): return not back.has(k) or back[k] != flags[k])
	ok(
		lost.is_empty(),
		"after match %d the save and load keeps every seen flag (%d)%s" % [n + 1, flags.size(), _names(lost)]
	)


func _judge() -> void:
	for i in MATCHES:
		for l: String in lines_by_match[i]:
			print("HINTONCE line match %d: %s" % [i + 1, l])
	var knock_lines: Array = []
	var first: Array = lines_by_match[0]
	ok(first.size() >= 6, "match 1 showed the first-time hints (%d lines)" % first.size())
	var earlier: Array = []
	for i in MATCHES:
		var lines: Array = lines_by_match[i]
		var again: Array = lines.filter(func(l: String): return lines.count(l) > 1 or (i > 0 and earlier.has(l)))
		again = again.filter(func(l: String): return not l.begins_with("That was mostly"))
		ok(again.is_empty(), "match %d: %d lines, none a repeat%s" % [i + 1, lines.size(), _names(again)])
		var cards: Array = lines.filter(func(l: String): return l.begins_with("That was mostly"))
		ok(cards.size() <= 1, "match %d: the knock card at most once (%d)" % [i + 1, cards.size()])
		knock_lines.append_array(cards)
		earlier.append_array(lines)
	ok(_ult_line(first), "the first ultimate line showed in match 1")
	ok(first.any(func(l: String): return l.contains("Only kegs explode")), "the keg line showed in match 1")
	ok(not Save.d["tutorial"].is_empty() and Save.d["tutorial"].has("keg"), "the keg flag is in the save")
	var showings := int(KnockTip.rules()["showings"])
	ok(
		knock_lines.size() == showings,
		"the knock card showed %d times for %d showings" % [knock_lines.size(), showings]
	)
	ok(
		int(Save.d["tutorial"].get(KnockTip.SAVE_KEY, 0)) == showings,
		"the knock count in the save stopped at %d" % showings
	)
	var third: Array = lines_by_match[MATCHES - 1]
	ok(not third.any(func(l: String): return l.begins_with("That was mostly")), "match 3: no knock card")


func _ult_line(lines: Array) -> bool:
	return lines.any(func(l: String): return l.contains(" is ready: "))


func _names(list: Array) -> String:
	var once: Array = []
	for x in list:
		if not once.has(x):
			once.append(x)
	return "" if once.is_empty() else ": " + " | ".join(once.map(func(x): return str(x)))
