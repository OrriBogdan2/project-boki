extends RefCounted
## --ways-hints-check: the first-time Ways Out hints (WaysHints, content/rules/heart.json "hints").
##   1. nothing before its moment; then the Blight's first close, a quest seat opening and the Heart
##      waking each put their one line in the message lane, once per save (a second match stays quiet)
##   2. none with tips off, and none in a match with no Heart (the tutorial)
##   3. every line fits the lane on one line at 1280x720
var bad := 0
var main: Node
var m: Match

func ok(cond: bool, what: String) -> void:
	print("WAYSHINT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Settings.set_v("tips", true, false)
	for id in ["tide", "quest", "heart"]:
		Save.d["tutorial"].erase("ways_" + id)
	_moments()
	_again()
	_quiet()
	_fit()
	print("WAYSHINT DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _match(o: Dictionary) -> Match:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)
	m.player.dropping = false
	m.player.riding = false      # (landed: the ship has dropped everyone)
	if m.exits.seats:
		m.exits.seats.build()
	return m

func _real() -> Dictionary:
	return {"teams": 2, "squad": 1, "tier": 0, "length": 1000.0, "seed": 4242, "demo_kin": "cindle"}

func _lane_has(text: String) -> bool:
	var lane: MsgLane = m.hud.msgs
	return lane._shown.any(func(e): return e["text"] == text) or lane._waiting.any(func(e): return e["text"] == text)

func _text(id: String) -> String:
	return String(Heart.rules()["hints"][id])

func _shows(id: String) -> bool:
	m._tips()
	return _lane_has(_text(id)) and bool(Save.d["tutorial"].get("ways_" + id, false))

func _moments() -> void:
	_match(_real())
	m._tip_t = 2.0
	m.time = Heart.r("tide_start_s") - 5.0
	ok(WaysHints.due(m).is_empty(), "before the Blight closes: no Ways Out hint")
	m.time = Heart.r("tide_start_s") + 1.0
	ok(_shows("tide"), "the Blight's first close: its line in the lane, kept in the save")
	ok(WaysHints.due(m).is_empty(), "the tide line is seen: nothing else due yet")
	ok(_text("tide") == "The Blight is closing. Get inside the circle.", "the tide line is the owner's one line")
	ok(WaysHints.arrow_due(m), "the edge arrow is up with the tide line")
	m.time += WaysHints.ARROW_S + 1.0
	ok(not WaysHints.arrow_due(m), "and gone ARROW_S later")
	m.time -= WaysHints.ARROW_S + 1.0
	m.exits.seats.lair._force(QuestSeat.S.OPEN, "check")
	ok(_shows("quest"), "a quest seat opens: its line")
	m.heart._force(Heart.S.CHARGING, "check")
	ok(_shows("heart"), "the Heart wakes: its line")
	var n: int = m.hud.msgs.count()
	m._tips()
	ok(m.hud.msgs.count() == n and WaysHints.due(m).is_empty(), "each shows once")

func _again() -> void:
	_match(_real())
	ok(not WaysHints.arrow_due(m), "a new match starts with no arrow")
	m.time = Heart.r("tide_start_s") + 1.0
	m.exits.seats.lair._force(QuestSeat.S.OPEN, "check")
	m.heart._force(Heart.S.CHARGING, "check")
	ok(WaysHints.due(m).is_empty(), "the next match: all three seen, none again (once per save)")

func _quiet() -> void:
	for id in ["tide", "quest", "heart"]:
		Save.d["tutorial"].erase("ways_" + id)
	_match(_real())
	m._tip_t = 2.0
	m.time = Heart.r("tide_start_s") + 1.0
	Settings.set_v("tips", false, false)
	m._tips()
	ok(not _lane_has(_text("tide")) and not Save.d["tutorial"].has("ways_tide"), "tips off: no line, still unseen")
	Settings.set_v("tips", true, false)
	_match({"tutorial": true, "teams": 1, "squad": 1, "seed": 4242})
	ok(m.heart == null and WaysHints.due(m).is_empty(), "the tutorial (no Heart): none")

func _fit() -> void:
	var widest := 1280.0 * MsgLane.WIDE
	for id: String in Heart.rules()["hints"]:
		if id.begins_with("_"):
			continue
		var w := UI.big.get_string_size(_text(id), HORIZONTAL_ALIGNMENT_LEFT, -1, MsgLane.PX[MsgLane.NORMAL]).x
		ok(w + 2.0 <= widest, "%s fits the lane on one line at 1280x720 (%d of %d px)" % [id, w, widest])
