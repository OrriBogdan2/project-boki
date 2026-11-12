extends RefCounted
## --first-match-guide-check: the "what to do next" line in a save's first three Extractions.
##   1. the save flag: only real Extractions count, three get the guide, the fourth does not, old saves migrate
##   2. a walk through the triggers: land, rank, send, chest, a squad, the Blight, an exit; each line shows
##      once, one at a time, clears on its trigger or its time, and never touches the player's input
##   3. the camp lines: while the drop is planned one mid-region Small Camp is picked and "Pick a camp and ping
##      it" shows alone; after landing "Clear the camp to level up" points at the nearest live camp until
##      your squad's first clear, then never again
##   4. every line fits the banner lane in at most two lines at 1280x720
##   5. the first-ready hero ultimate hint (FirstUltHint): only when ready, never in a fight's first 2 s of
##      damage, the key from Settings.key_cap, once per save, a short line for every hero
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
	_first_ult()
	print("FMGUIDE DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _save_flag() -> void:
	Save.d["first_guide"] = 0
	var o := {"teams": 2, "squad": 1}
	var skipped := ["tutorial", "duel", "training"].all(func(k: String): return _skips(k))
	ok(skipped and int(Save.d["first_guide"]) == 0, "tutorial, duel and training get no guide and do not count")
	var first := FirstMatchGuide.for_match(null, o)
	var second := FirstMatchGuide.for_match(null, o)
	var third := FirstMatchGuide.for_match(null, o)
	ok(first != null and second != null and third != null, "the first three Extractions get the guide")
	var fourth := FirstMatchGuide.for_match(null, o)
	ok(fourth == null and int(Save.d["first_guide"]) == 3, "the fourth does not; the flag stays at 3")
	var old := {"matches": 5}
	FirstMatchGuide.migrate(old)
	var young := {"matches": 1}
	FirstMatchGuide.migrate(young)
	var kept := {"matches": 5, "first_guide": 0}
	FirstMatchGuide.migrate(kept)
	ok(int(old["first_guide"]) == 3 and int(young["first_guide"]) == 1, "an old save skips it; one match in: one more")
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
	_camp_lines(p)
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

func _camp_lines(p: Hunter) -> void:
	var D: DropSquad = m.skydrop
	ok(D != null and m.camps != null, "the match has a planned drop and camps")
	D.planning = true
	_tick(0.2)
	var pick: Dictionary = g.target()
	var rid := ""
	if not pick.is_empty() and int(pick["region"]) >= 0:
		rid = String(m.world.regions[int(pick["region"])]["id"])
	var small: bool = Camps.size_def(int(pick.get("size", 0)))["id"] == "small"
	var mid: Array = FirstMatchGuide.rules()["mid_regions"]
	ok(small and mid.has(rid), "planning: a mid region's Small Camp is picked (%s)" % rid)
	ok(g.id == "plan" and g.line == "Pick a camp and ping it", "planning: the one prompt (%s)" % g.line)
	var first_pick: int = int(pick["id"])
	g.m.camps.camps[first_pick]["state"] = Camps.State.CLEARED
	ok(g.target().is_empty() or int(g.target()["id"]) != first_pick, "a camp that is not live is no longer pointed at")
	g.m.camps.camps[first_pick]["state"] = Camps.State.LIVE
	D.planning = false
	_tick(0.2)
	ok(g.line == "", "landed: the plan line clears")
	p.pos = Vector3(pick["pos"]) + Vector3(20, 0, 0)
	_tick(1.6)
	ok(g.id == "camp" and g.line == "Clear the camp to level up", "after landing: clear the camp (%s)" % g.line)
	ok(int(g.target()["id"]) == int(m.camps.nearest_live(p.pos, INF)["id"]), "it points at the nearest live camp")
	m.camps.cleared.emit(0, p.team + 1)
	ok(not g._cleared and g.id == "camp", "a rival squad's clear does not end it")
	m.camps.cleared.emit(0, p.team)
	_tick(0.2)
	ok(g.line == "" and g._cleared, "your squad's first clear ends it")
	_tick(5.0)
	ok(g.id != "camp", "and it never comes back")
	g.shown.clear()
	g.id = ""
	g.line = ""
	g._gap = 0.0

func _fit() -> void:
	var strip := TutorialStrip.rect(Vector2(1280, 720))
	var w := strip.size.x - strip.size.y
	for row: Array in FirstMatchGuide.rules()["lines"]:
		var txt := TutorialText.fill(String(row[1]), m.player).replace("%s", "Cindle")
		var px := int(strip.size.y * 0.5)
		while px > 12 and m.hud.big.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w:
			px -= 1
		ok(px >= 12, "%s fits the one-line strip (%d px)" % [row[0], px])

# ------------------------------------------------------------------ 5. the first-ready ult hint
func _first_ult() -> void:
	var p: Hunter = m.player
	ok(p.ak != null, "the player is a hero with a kit")
	if p.ak == null:
		return
	var seen: Dictionary = Save.d["tutorial"]
	seen.erase(FirstUltHint.KEY)
	p.downed = false
	p.dropping = false
	p.lvl = int(Hunter.ULT_AT[0]) - 1
	p.ak.cd["x"] = 0.0
	m._tip_t = 2.0
	m.time = 100.0
	m._tips()
	ok(not seen.has(FirstUltHint.KEY), "below the ult level: no hint")
	p.lvl = int(Hunter.ULT_AT[0])
	p.ak.cd["x"] = 5.0
	m._tips()
	ok(not seen.has(FirstUltHint.KEY), "cooling down: no hint")
	p.ak.cd["x"] = 0.0
	var foe: Hunter = null
	for h in m.hunters:
		if h != p and h.team != p.team:
			foe = h
	CombatBus.hit_landed.emit(foe, p, 5.0, ["primary"])
	m.time = 101.0
	CombatBus.hit_landed.emit(p, foe, 5.0, ["primary"])
	m.time = 101.9
	m._tips()
	ok(not seen.has(FirstUltHint.KEY), "ready 1.9 s into a fight: held back")
	var before: int = m.hud.msgs.count()
	m.time = 102.1
	m._tips()
	ok(bool(seen.get(FirstUltHint.KEY, false)), "ready 2.1 s into the fight, still being hit: shown")
	ok(m.hud.msgs.count() == before + 1, "through the hint lane, one line")
	var want := FirstUltHint.text(p.ak)
	var cap := Settings.key_cap("hunter_ult")
	ok(want.begins_with(cap + " is ready: " + String(p.ak.x_def()["name"]) + ", "), "the key cap and name (%s)" % want)
	m._tips()
	ok(m.hud.msgs.count() == before + 1, "once per save: no second line")
	seen.erase(FirstUltHint.KEY)
	m.time = 200.0
	CombatBus.hit_landed.emit(foe, p, 5.0, ["primary"])
	m._tips()
	ok(not seen.has(FirstUltHint.KEY), "a new fight after a quiet spell holds it again")
	seen[FirstUltHint.KEY] = true
	for f in DirAccess.get_files_at("res://content/archetypes"):
		if not f.ends_with(".json"):
			continue
		var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/archetypes/" + f))
		var xd: Dictionary = json.get("x", {})
		if xd.is_empty():
			continue
		var line := FirstUltHint.short_line(String(xd.get("desc", "")))
		ok(line != "" and line.length() <= FirstUltHint.LINE_MAX + 1, "%s: a short line (%s)" % [f, line])
