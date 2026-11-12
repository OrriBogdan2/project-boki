extends RefCounted
## --tut-first-breed-check: the first-breeding prompt (FirstBreed). On a fixture save with two Grown friends:
##   1. the gates: a ready pair is found; each missing gate gets its own plain line
##   2. the save flag: the v13 -> v14 migration marks a save that already bred, and leaves others alone
##   3. in the world: one of the pair leads to the Nook, stops and looks back when you fall behind, the card
##      opens when you arrive (what breeding is, the preview, one "Pair them"), the button leaves an egg,
##      and the prompt never shows again; a pair that is not ready is never led
## Never touches the real save.

var main: Node
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("FIRSTBREED %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _kin(sp: String, nick: String, lv: int) -> Dictionary:
	var k := Save.new_kin(sp, nick)
	k["level"] = lv
	k["trust"] = 60.0
	Care.ensure(k)
	return k

func _save(lv_b: int) -> Dictionary:
	var d := Save.fresh()
	var a := _kin("zapple", "Pip", 8)
	a["starter"] = true
	d["active"] = a["uid"]
	d["roster"] = [a, _kin("cindle", "Ash", lv_b)]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true, "home": true}
	return d

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_gates()
	_migration()
	await _world()
	print("FIRSTBREED DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _gates() -> void:
	Save.d = _save(8)
	var r: Array = Save.d["roster"]
	ok(FirstBreed.ready_pair(r).size() == 2 and FirstBreed.missing_line(r) == "",
			"two Grown friends are a ready pair, nothing missing")
	r[1]["level"] = 3
	ok(FirstBreed.ready_pair(r).is_empty() and FirstBreed.missing_line(r).contains("Grown"),
			"a Youngling: '%s'" % FirstBreed.missing_line(r))
	r[1]["level"] = 8
	r[1]["trust"] = 10.0
	ok(FirstBreed.missing_line(r).contains("friends"), "not friends: '%s'" % FirstBreed.missing_line(r))
	r[1]["trust"] = 60.0
	r[0]["bred_t"] = Time.get_unix_time_from_system()
	ok(FirstBreed.missing_line(r).contains("resting"), "just laid an egg: '%s'" % FirstBreed.missing_line(r))
	r[0].erase("bred_t")
	Save.d["egg"] = {"a": r[0]["uid"], "b": r[1]["uid"]}
	ok(FirstBreed.missing_line(r).contains("egg") and FirstBreed.ready_pair(r).is_empty(),
			"an egg in the nest: '%s'" % FirstBreed.missing_line(r))
	Save.d["egg"] = {}
	ok(FirstBreed.missing_line([r[0]]).contains("Grown"),
			"one Boki alone still gets a line: '%s'" % FirstBreed.missing_line([r[0]]))

func _migration() -> void:
	var old := {"v": 13, "tutorial": {}, "roster": [{"uid": "x"}], "egg": {}}
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION and not old["tutorial"].has(FirstBreed.SEEN),
			"a v13 save that never bred is not marked")
	var bred := {"v": 13, "tutorial": {}, "roster": [{"uid": "x", "parents": ["A", "B"]}], "egg": {}}
	ok(Save.migrate(bred) and bool(bred["tutorial"].get(FirstBreed.SEEN, false)),
			"a v13 save with a bred Boki is marked seen")
	var egged := {"v": 13, "tutorial": {}, "roster": [], "egg": {"a": "x", "b": "y"}}
	ok(Save.migrate(egged) and bool(egged["tutorial"].get(FirstBreed.SEEN, false)),
			"a v13 save with an egg in the nest is marked seen")

func _home(lv_b: int):
	Save.d = _save(lv_b)
	HomeLayout.ensure(Save.d)
	var home = await main._hb_home()
	var t0 := Time.get_ticks_msec()
	while home.panel_host == null and Time.get_ticks_msec() - t0 < 60000:
		await main.get_tree().process_frame
	home._close_panel()
	return home

func _sim(home, secs: float, until := Callable()) -> void:
	for i in int(secs / 0.05):
		for k in home.kins:
			for n in Care.NEEDS:
				k["rec"]["needs"][n] = maxf(float(k["rec"]["needs"][n]), 70.0)
		home.day_t = 0.5
		home._move_kin(0.05)
		home.hbreed.tick(0.05)
		if until.is_valid() and until.call():
			return
		if i % 100 == 0:
			await main.get_tree().process_frame

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _world() -> void:
	var home = await _home(3)
	ok(home.NEST_AT.x > -100.0 and home.hbreed != null, "the fixture farm has a Nook")
	home.hbreed.look_t = 0.0
	await _sim(home, 20.0)
	ok(home.hbreed.lead.is_empty() and home.panel_open == "",
			"a pair that is not ready is never led (%s)" % FirstBreed.missing_line(Save.d["roster"]))
	home.queue_free()
	await main.get_tree().process_frame
	home = await _home(8)
	var hb: FirstBreed = home.hbreed
	var spot: Vector3 = home.NEST_AT + FirstBreed.FRONT
	home._close_panel()      # (the farm opens with you beside the Nook: the first try already showed the card)
	Save.d["tutorial"].erase(FirstBreed.SEEN)
	hb._stop(0.0)
	home.ppos = Vector3(spot.x - 1.0, 0.0, spot.z + 12.0)
	hb.look_t = 0.0
	await _sim(home, 2.0)
	ok(not hb.lead.is_empty() and Save.d["roster"].has(hb.lead["rec"]) and not FirstBreed.seen(),
			"one of the pair starts to lead")
	if hb.lead.is_empty():
		home.queue_free()
		return
	var k: Dictionary = hb.lead
	var start := Vector3(39.5, 0.0, 29.5)      # a spot on the farm island, 8 m from the Nook
	k["pos"] = start
	k["node"].position = start
	k["vel"] = Vector3.ZERO
	home.ppos = Vector3(33.5, 0.0, 47.4)      # 19 m behind it
	await _sim(home, 5.0)
	ok(_flat(k["pos"], start) < 1.0 and not hb.lead.is_empty(),
			"when you fall behind it stops and waits (moved %.1f m)" % _flat(k["pos"], start))
	home.ppos = Vector3(start.x, 0.0, start.z + 5.5)      # you catch up
	await _sim(home, 8.0)
	ok(_flat(k["pos"], spot) < _flat(start, spot) - 2.0,
			"once you are near it walks on (%.1f m to go)" % _flat(k["pos"], spot))
	home.ppos = Vector3(start.x, 0.0, start.z + 5.5)
	ok(is_instance_valid(hb.marker) and hb.marker.visible and home.panel_open == "" and not FirstBreed.seen(),
			"the Nook is marked; nothing blocks you")
	home.ppos = Vector3(spot.x, 0.0, spot.z + 2.0)
	await _sim(home, 0.5)
	ok(home.panel_open == "Breeding" and FirstBreed.seen(), "arriving opens the card, and it is marked seen")
	var texts := _texts(home.panel_host)
	ok(texts.any(func(t): return t.begins_with("Two Grown Boki")) and texts.has("THEIR EGG")
			and texts.any(func(t): return t.contains("Pair them")),
			"the card: the one-line explanation, the preview, a Pair them button")
	_press(home.panel_host, "Pair them")
	await main.get_tree().process_frame
	ok(not Save.d["egg"].is_empty() and home.panel_open == "", "Pair them leaves an egg in the nest")
	hb.look_t = 0.0
	Save.d["egg"] = {}
	for r in Save.d["roster"]:
		r.erase("bred_t")
	await _sim(home, 3.0)
	ok(hb.lead.is_empty() and home.panel_open == "", "never shown a second time")
	home.queue_free()

func _texts(n: Node) -> Array:
	var out: Array = []
	for c in n.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	for c in n.find_children("*", "Button", true, false):
		out.append((c as Button).text)
	return out

func _press(n: Node, text: String) -> void:
	for c in n.find_children("*", "Button", true, false):
		if (c as Button).text.contains(text):
			(c as Button).pressed.emit()
			return
