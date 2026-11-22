extends RefCounted
## --first-objective-check: the first expedition's "next step" line and pin (FirstObjective, ObjectiveTracker).
##   1. only a real expedition of a save that has not got out of one gets it; a save that extracted is not taught
##   2. find -> knock out -> scan -> leave, read from the world (distance, the Boki's state, a capsule in the box)
##   3. the pin is on the wild Boki, then on the outpost; the uplink's own waypoint keeps the running outpost
##   4. the leave step follows the outpost: far, wake time, start, hold the yard, back, lift
##   5. a finished step ticks and chimes once; a step that goes back (the Boki got away) does not tick
##   6. getting out saves the flag (and no further match has it); dying does not
##   7. every line fits the card at 1280x720
## Never touches the real save.

var bad := 0
var m: Match
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FOBJ %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_gate()
	_walk()
	_leave()
	_finish()
	print("FOBJ DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _gate() -> void:
	Save.d = Save.fresh()
	var o := {"teams": 2, "squad": 1}
	ok(FirstObjective.for_match(null, o) != null, "a fresh save's expedition gets it")
	var none := func(k: String) -> bool: return FirstObjective.for_match(null, {k: true}) == null
	ok(["tutorial", "duel", "arena", "training", "autoplay"].all(none), "tutorial, duel, arena, ...: none")
	var old := {"tutorial": {}, "extracts": 3}
	FirstObjective.migrate(old)
	var young := {"tutorial": {}, "extracts": 0}
	FirstObjective.migrate(young)
	ok(old["tutorial"].get(FirstObjective.KEY, false) and not young["tutorial"].has(FirstObjective.KEY),
			"a save that has got out is not taught; one that has not is")
	Save.d["tutorial"][FirstObjective.KEY] = true
	ok(FirstObjective.for_match(null, o) == null, "once done, no match has it")
	Save.d = Save.fresh()
	Save.d["stats"]["caught"] = 1
	var caught := FirstObjective.for_match(null, o)
	ok(caught != null and caught._captured, "a save that has caught a Boki starts at leave")

func _fresh() -> void:
	if m:
		m.queue_free()
	Save.d = Save.fresh()
	Save.d["tutorial"]["move"] = true
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4243, "no_drop": true, "weapon": "rifle",
			"cls": "medium", "demo_kin": "cindle"})
	m.set_process(false)
	m.player.riding = false
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for k: Kin in m.kins:
		if k.owner_h == null:
			k.queue_free()
	m.kins = m.kins.filter(func(k: Kin) -> bool: return k.owner_h != null)
	for h in m.hunters:
		if h.team != m.player.team:
			h.ctrl = "idle"
			h.teleport(m.player.pos + Vector3(300.0, 0, 300.0))
	for i in 10:
		m.step(Match.DT)

func _wild(dx: float, dazed := false) -> Kin:
	var at: Vector3 = m.player.pos + Vector3(dx, 0, 0)
	var k := m.spawn_wild(Save.new_kin("puddlet", "", 77), Vector3(at.x, m.world.ground_at(at.x, at.z), at.z), dazed)
	return k

## Lets the objective look at the world once.
func _look() -> void:
	m.objective._look = 0.0
	m.objective.tick(Match.DT)

func _walk() -> void:
	_fresh()
	var o := m.objective
	var P := m.player
	ok(o != null and o.step == "find", "a fresh expedition starts on find")
	ok(o.text() == "Find a wild Boki" and o.target_pos() == Vector3.INF, "no wild Boki yet: the line, no pin")
	var far := _wild(60.0)
	_look()
	ok(o.step == "find" and o.target == far, "a wild Boki far off: find")
	ok(o.target_pos().is_equal_approx(far.pos), "the pin is on it")
	ok(o.label() == "Wild Boki" and o.ticked == "", "the pin says what it is")
	P.teleport(far.pos - Vector3(10.0, 0, 0))
	_look()
	ok(o.step == "knock" and o.text() == "Knock it out" and o.ticked == "Found a wild Boki" and o.ticked_t > 0.0,
			"close to it: knock it out, find ticked (%s)" % o.text())
	P.teleport(far.pos - Vector3(22.0, 0, 0))
	_look()
	ok(o.step == "knock", "a little farther: it does not flip back at once")
	far.state = "dazed"
	_look()
	ok(o.step == "scan" and o.text().contains(Settings.key_cap("interact")) and o.text().begins_with("Scan"),
			"knocked out: scan it, with the interact key (%s)" % o.text())
	far.state = "wild"
	P.teleport(far.pos - Vector3(60.0, 0, 0))
	var ticks := o.ticked_t
	_look()
	ok(o.step == "find" and o.ticked_t <= ticks, "it woke and ran: back to find, nothing ticked")
	far.state = "dazed"
	P.teleport(far.pos - Vector3(3.0, 0, 0))
	_look()
	P.caught.append({"uid": "x", "species": "puddlet"})
	_look()
	ok(o.step == "leave" and o.ticked.begins_with("Scanned"), "a capsule in the box: leave, scan ticked")
	far.dead = true
	_look()
	ok(o.step == "leave", "leave sticks even when the Boki is gone")
	var near_a := _wild(5.0)
	var near_b := _wild(40.0)
	m.objective._captured = false
	P.caught.clear()
	_look()
	ok(o.target == near_a, "two wild Boki: the nearer one is named")
	near_b.state = "dazed"
	_look()
	ok(o.target == near_b and o.step == "scan", "a knocked-out one far off leads the pin (someone else's knock)")
	_fit()

func _leave() -> void:
	_fresh()
	var o := m.objective
	var P := m.player
	o._captured = true
	_look()
	var x := o.exit_spot()
	ok(not x.is_empty() and o.step == "leave", "leave names the Uplink outpost")
	ok(o.target_pos().is_equal_approx(x["pos"]) and not o.exit_pinned(), "the pin is on the idle outpost")
	x["state"] = "idle"
	x["open_at"] = m.time + 90.0
	var wait := o.text()
	ok(wait.begins_with("Go to the outpost") and wait.contains("1:30"), "not awake yet: its wake time (%s)" % wait)
	x["open_at"] = 0.0
	P.teleport(x["pos"] + Vector3(30.0, 0, 0))
	ok(o.text() == "Go to the outpost", "awake and far: go there")
	P.teleport(x["pos"] + Vector3(2.0, 0, 0))
	ok(o.text().begins_with("Start the uplink") and o.text().contains(Settings.key_cap("interact")),
			"in the yard: start the uplink (%s)" % o.text())
	x["state"] = "charging"
	x["team"] = P.team
	x["contested"] = false
	x["prog"] = 0.42
	ok(o.text() == "Hold the yard: uplink 42%" and o.exit_pinned(), "charging, in the yard: hold it (%s)" % o.text())
	P.teleport(x["pos"] + Vector3(30.0, 0, 0))
	ok(o.text() == "Get back in the outpost yard", "charging, you out of the yard: get back in")
	x["contested"] = true
	ok(o.text() == "Clear the yard of rivals", "a rival in the yard: clear it")
	x["contested"] = false
	x["state"] = "open"
	ok(o.text() == "Step into the lift" and o.exit_pinned(), "the lift is open: step into it")
	_fit()

func _finish() -> void:
	_fresh()
	var P := m.player
	m.objective._captured = true
	_look()
	ok(not Save.d["tutorial"].get(FirstObjective.KEY, false), "not saved while still on the island")
	P.out = true
	m.objective.tick(Match.DT)
	ok(not Save.d["tutorial"].get(FirstObjective.KEY, false), "dying does not finish it")
	P.out = false
	P.extracted = true
	m.objective.tick(Match.DT)
	ok(Save.d["tutorial"].get(FirstObjective.KEY, false), "getting out saves it")
	ok(FirstObjective.for_match(null, {"teams": 2}) == null, "the next expedition does not have it")

## Every line fits the card.
func _fit() -> void:
	var o := m.objective
	var worst := 0.0
	o.exit_spot()["open_at"] = 0.0      # (these matches run for ever: the wake time is judged below, as 10:00)
	for id in ["find", "knock", "scan", "leave"]:
		o.step = id
		worst = maxf(worst, TextCache.width(m.hud.big, o.text(), ObjectiveTracker.LINE_PX - 2))
	for k in ["wait", "go", "start", "hold", "back", "contested", "lift"]:
		var t := String(FirstObjective.rules()["leave"][k])
		t = t.replace("%F", "F").replace("%d", "100").replace("%s", "10:00")
		worst = maxf(worst, TextCache.width(m.hud.big, t, ObjectiveTracker.LINE_PX - 2))
	ok(worst <= ObjectiveTracker.TEXT_W,
			"every line fits the card at its smaller size (%.0f of %.0f px)" % [worst, ObjectiveTracker.TEXT_W])
