extends RefCounted
## --map-hover-check: the full map (M) names what the cursor rests on.
##   1. the cursor must rest MapHover.DWELL_S on a marker before its card shows; a move to another restarts it
##   2. an extraction point reads closed (its timer), opening (its percent) and open (its lift clock), in 3 colours
##   3. every marker kind the map draws gives a card when the cursor is on it
##   (the minimap's edge ping for an open lift is in --map-clear-shots)
## Never touches the save.

var bad := 0
var fm: FullMap
var m: Match

func ok(cond: bool, what: String) -> void:
	print("MAPHOVER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	_dwell()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	while m.hud.full_map == null:
		await main.get_tree().process_frame
	fm = m.hud.full_map
	fm.open()
	fm._layout(Vector2(1280, 720))
	_exits()
	_kinds()
	print("MAPHOVER CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _dwell() -> void:
	var h := MapHover.new()
	var t0 := 10000
	var ms := int(MapHover.DWELL_S * 1000.0)
	ok(not h.rest("exit a", t0), "a cursor that just arrived shows no card")
	ok(not h.rest("exit a", t0 + ms - 50), "...nor a moment before the dwell is up")
	ok(h.rest("exit a", t0 + ms), "...but the card shows once it has rested %.1f s" % MapHover.DWELL_S)
	ok(not h.rest("exit b", t0 + ms + 10), "moving to another marker restarts the wait")
	ok(not h.rest("", t0 + ms * 3), "the card goes when the cursor leaves the marker")

func _pick_at(world: Vector3) -> Dictionary:
	var h := MapHover.new()
	h.pick(fm, fm.to_screen(world))
	return h.hit

func _exits() -> void:
	var xs: Array = m.exits.list
	ok(xs.size() >= 2, "the map has extraction points (%d)" % xs.size())
	var x: Dictionary = xs[0]
	x["state"] = "idle"
	x["open_at"] = m.time + 80.0
	var hit := _pick_at(x["pos"])
	ok(hit.get("title", "") == x["name"], "an extraction point's card is its name: %s" % hit.get("title", "?"))
	ok("opens in 1:20" in String(hit.get("line", "")), "closed: the line gives its timer: %s" % hit.get("line", "?"))
	ok(ExitMark.state(x) == "closed" and ExitMark.word(m, x) == "OPENS 1:20", "closed reads %s" % ExitMark.word(m, x))
	x["state"] = "charging"
	x["prog"] = 0.4
	x["contested"] = false
	hit = _pick_at(x["pos"])
	ok("opening, 40%" in String(hit.get("line", "")), "opening: the line gives its percent: %s" % hit.get("line", "?"))
	var opening := ExitMark.color(x)
	x["state"] = "open"
	x["t"] = 12.0
	hit = _pick_at(x["pos"])
	var line := String(hit.get("line", ""))
	ok("open" in line and "0:12" in line, "open: the line gives the lift clock: %s" % line)
	ok(ExitMark.word(m, x) == "OPEN 0:12", "open reads %s" % ExitMark.word(m, x))
	var open := ExitMark.color(x)
	x["state"] = "idle"
	x["open_at"] = 0.0
	var closed := ExitMark.color(x)
	ok(opening != open and open != closed and opening != closed, "closed, opening and open are three colours")
	x["state"] = "open"

func _kinds() -> void:
	var seen := {}
	var n := 0
	var spots: Array = []
	for sh in m.shrines: spots.append(["shrine", sh["pos"]])
	for L in m.lairs.list: spots.append(["lair", L["c"]])
	for cnd in m.spawn_plan.cands: spots.append(["spawn", cnd["pos"]])
	for lb in m.world.labels:
		if String(lb["kind"]) != "rail": spots.append(["place " + String(lb["kind"]), lb["pos"]])
	for hs in fm.hud.train_map.halts(m.skytrain): spots.append(["halt", Vector3(hs["pos"].x, 0, hs["pos"].y)])
	spots.append(["you", m.player.pos])
	for s in spots:
		var pv := fm.to_screen(s[1])
		if not fm.rect.grow(-6.0).has_point(pv):
			continue
		var hit := _pick_at(s[1])
		seen[s[0]] = seen.get(s[0], true) and not hit.is_empty()
		n += 1
	for k in seen:
		ok(seen[k], "a card for every %s on the map" % k)
	ok(n > 0, "markers checked: %d across %d kinds" % [n, seen.size()])
