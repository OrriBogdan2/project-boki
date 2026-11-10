extends RefCounted
## --first-match-guide-check: the "what to do next" line in a save's first two Extractions.
##   1. the save flag: only real Extractions count, two get the guide, the third does not, old saves migrate
##   2. a walk through the triggers: land, rank, send, chest, a squad, the Blight, an exit; each line shows
##      once, one at a time, clears on its trigger or its time, and never touches the player's input
##   3. every line fits the banner lane in at most two lines at 1280x720
var bad := 0
var m: Match
var main: Node
var g: FirstMatchGuide

func ok(cond: bool, what: String) -> void:
	print("FMGUIDE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_save_flag()
	_walk()
	print("FMGUIDE DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _save_flag() -> void:
	Save.d["first_guide"] = 0
	var o := {"teams": 2, "squad": 1}
	var skipped := ["tutorial", "duel", "training"].all(func(k: String): return _skips(k))
	ok(skipped and int(Save.d["first_guide"]) == 0, "tutorial, duel and training get no guide and do not count")
	var first := FirstMatchGuide.for_match(null, o)
	var second := FirstMatchGuide.for_match(null, o)
	ok(first != null and second != null, "the first two Extractions get the guide")
	var third := FirstMatchGuide.for_match(null, o)
	ok(third == null and int(Save.d["first_guide"]) == 2, "the third does not; the flag stays at 2")
	var old := {"matches": 5}
	FirstMatchGuide.migrate(old)
	var young := {"matches": 1}
	FirstMatchGuide.migrate(young)
	var kept := {"matches": 5, "first_guide": 0}
	FirstMatchGuide.migrate(kept)
	ok(int(old["first_guide"]) == 2 and int(young["first_guide"]) == 1, "an old save skips it; one match in: one more")
	ok(int(kept["first_guide"]) == 0, "the field is never overwritten")
	ok(int(Save.fresh()["first_guide"]) == 0, "a new save starts at 0")

func _skips(key: String) -> bool:
	return FirstMatchGuide.for_match(null, {key: true}) == null

func _tick(secs: float) -> void:
	var t := 0.0
	while t < secs:
		g.tick(0.1)
		t += 0.1

func _walk() -> void:
	Save.d["first_guide"] = 0
	m = Match.new()
	main.add_child(m)
	var o := {"teams": 2, "squad": 1, "tier": 0, "length": 1000.0, "seed": 4242, "demo_kin": "cindle"}
	m.start(o)
	m.set_process(false)
	g = m.guide
	var p: Hunter = m.player
	ok(g != null and int(Save.d["first_guide"]) == 1, "a real Extraction gets the guide and is counted")
	for h in m.hunters:
		if h != p:
			h.pos = p.pos + Vector3(300, 0, 0)
	p.skill_pts = 1
	m.time = 0.0
	if m.chests.is_empty():
		m.chests.append({"open": false, "pos": p.pos, "prog": 0.0})
	var move0: Vector2 = p.inp["move"]
	p.dropping = true
	_tick(0.2)
	ok(g.id == "land" and g.line.begins_with("Pick a landing spot"), "dropping: pick a landing spot (%s)" % g.line)
	p.dropping = false
	_tick(0.2)
	ok(g.line == "", "landed: the line clears and a quiet gap follows")
	_tick(1.5)
	ok(g.id == "rank" and g.line.contains("Rank up"), "a skill point: rank an ability (%s)" % g.line)
	p.skill_pts = 0
	_tick(0.2)
	ok(g.line == "", "ranked: it clears")
	_tick(1.6)
	ok(g.id == "send" and g.line.contains("Send"), "your Boki is with you: send it (%s)" % g.line)
	p.kin.st_throws += 1
	_tick(0.2)
	ok(g.line == "", "sent: it clears")
	_tick(1.6)
	ok(g.id == "chest" and g.line.contains("chest"), "a chest to open: loot it (%s)" % g.line)
	p.add_stat("chests")
	_tick(0.2)
	ok(g.line == "", "opened: it clears")
	var foe: Hunter = null
	for h in m.hunters:
		if h != p and h.team != p.team:
			foe = h
	_tick(1.6)
	foe.pos = p.pos + Vector3(10, 0, 0)
	_tick(0.2)
	ok(g.id == "squad" and g.line.contains("squad"), "another squad close by: fight or avoid (%s)" % g.line)
	foe.pos = p.pos + Vector3(300, 0, 0)
	_tick(0.2)
	ok(g.line == "", "they are gone: it clears")
	foe.pos = p.pos + Vector3(10, 0, 0)
	_tick(2.0)
	ok(g.line == "", "a line shows only once a match")
	m.time = m.length * 0.7
	_tick(1.6)
	ok(g.id == "blight" and g.line.contains("Blight"), "the match is closing: the Blight line (%s)" % g.line)
	_tick(12.0)
	ok(g.id == "" or g.id == "exit", "it clears after its time")
	_tick(1.6)
	ok(g.id == "exit" and g.line.contains("exit"), "then: go to an exit (%s)" % g.line)
	var spots: Array = m.exits.spots()
	p.pos = spots[0]
	_tick(0.2)
	ok(g.line == "", "at an exit: it clears")
	ok(p.inp["move"] == move0, "the guide never touched the player's input")
	p.extracted = true
	g.shown.clear()
	g.id = ""
	_tick(0.2)
	ok(g.line == "", "after extracting nothing shows")
	p.extracted = false
	if m.skydrop:
		m.skydrop.planning = false      # (the ship waits for you to plan the drop, and the match with it)
	g._gap = 0.0
	m.step(Match.DT)
	ok(g.line != "" or g.shown.size() > 0, "Match.step ticks the guide")
	_fit()

func _fit() -> void:
	var w: float = TutorialHud.lanes(Vector2(1280, 720))["banner"].size.x - 28.0
	for row: Array in FirstMatchGuide.rules()["lines"]:
		var txt := TutorialText.fill(String(row[1]), m.player).replace("%s", "Cindle")
		var fit := TutorialText.wrap(m.hud.big, txt, int(720 * 0.085 * 0.42), w, 2)
		var n: int = fit["lines"].size()
		ok(n <= 2 and int(fit["px"]) >= 12, "%s fits the banner lane (%d lines, %d px)" % [row[0], n, fit["px"]])
