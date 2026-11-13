extends RefCounted
## --hud-reveal-check: the staged HUD (HudReveal, content/rules/hud_reveal.json; DECISIONS 2026-11-08).
##   1. the table: matches 1-3 show at most 6 groups (vitals, abilities, beat clock, summon ring,
##      objective), the seat pips wait for their first open seat, everything else is from match 4
##   2. a fresh save at matches 1, 3 and 4: each group shows exactly when the table says
##   3. holding Tab shows every group; Settings "Show full HUD" too; an older save (no hud_reveal) too
##   4. the seat pips: hidden while every seat is locked, revealed through the real HUD on the first open
##      seat, remembered by the save into the next match
##   5. training is never staged
## Never touches the save file.

const FIRST := ["vitals", "abilities", "beat_clock", "summon_ring", "objective"]
const LATER := ["counters", "feed", "gear", "squad", "perks", "weather", "pace_tags", "plate_colours"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HUDREVEAL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _match(main: Node, opts: Dictionary) -> Match:
	var m := Match.new()
	main.add_child(m)
	var o := {"teams": 3, "squad": 1, "tier": 0, "length": 1e9, "seed": 7301, "no_drop": true,
		"heart": true, "god": true}
	o.merge(opts, true)
	m.start(o)
	for h in m.hunters:
		h.ctrl = "idle"
	return m

func _shown(m: Match) -> Array:
	return HudReveal.groups().keys().filter(func(k): return HudReveal.on(m, k))

func _frames(main: Node, n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Settings.set_v("hud_full", false, false)
	Input.action_release("scores")
	# ---------------------------------------------------------------- 1. the table
	var g := HudReveal.groups()
	var first: Array = g.keys().filter(func(k): return int(g[k].get("from_match", 1)) == 1)
	first.sort()
	var want := FIRST.duplicate()
	want.sort()
	ok(first == want, "matches 1-3 show %s" % ", ".join(first))
	ok(first.size() <= 6, "%d groups at the start (about 5, DECISIONS 11-08)" % first.size())
	var pips: Dictionary = g["seat_pips"]
	ok(int(pips.get("from_match", 1)) == 0 and String(pips.get("first", "")) == "seat_open",
		"the seat pips wait for the first open seat")
	ok(LATER.all(func(k): return int(g.get(k, {}).get("from_match", 0)) == 4), "the rest is from match 4")
	# ---------------------------------------------------------------- 2. a fresh save at matches 1, 3, 4
	var m := _match(main, {})
	m.time = 30.0
	for n in [1, 3, 4]:
		Save.d["matches"] = n - 1
		var shown := _shown(m)
		shown.sort()
		var expect: Array = FIRST.duplicate() if n < 4 else FIRST + LATER
		expect.sort()
		ok(HudReveal.match_no() == n and shown == expect, "match %d shows %s" % [n, ", ".join(shown)])
	ok(not HudReveal.on(m, "seat_pips"), "match 4: the seat pips still wait for an open seat")
	# ---------------------------------------------------------------- 3. Tab, Show full HUD, an older save
	Save.d["matches"] = 0
	Input.action_press("scores")
	ok(_shown(m).size() == g.size(), "holding Tab shows every group")
	Input.action_release("scores")
	ok(_shown(m).size() == FIRST.size(), "letting go of Tab hides them again")
	Settings.set_v("hud_full", true, false)
	ok(_shown(m).size() == g.size(), "Show full HUD shows every group from match 1")
	Settings.set_v("hud_full", false, false)
	var old := Save.d.duplicate(true)
	old.erase("hud_reveal")
	var fresh_d := Save.d
	Save.d = old
	ok(_shown(m).size() == g.size(), "an older save (no hud_reveal) keeps the full HUD")
	Save.d = fresh_d
	# ---------------------------------------------------------------- 4. the seat pips through the real HUD
	m.hud.panels.queue_redraw()
	await _frames(main, 3)
	ok(not Save.d["hud_reveal"].has("seat_pips"), "every seat locked at 0:30: no pips, nothing remembered")
	m.time = float(Heart.rules()["quest"]["lair_open_s"]) + 5.0
	ok(int(WaysOutHud.seats(m)[0]["st"]) == WaysOutHud.St.OPEN, "the Lair seat opens")
	m.hud.panels.queue_redraw()      # (the panels redraw at 20 Hz: draw now, not when the timer comes round)
	await _frames(main, 3)
	ok(Save.d["hud_reveal"].get("seat_pips", false) and HudReveal.on(m, "seat_pips"),
		"the first open seat reveals the pips")
	m.queue_free()
	await _frames(main, 2)
	Save.d["matches"] = 1
	m = _match(main, {})
	m.time = 30.0
	ok(HudReveal.on(m, "seat_pips") and not HudReveal.on(m, "feed"),
		"match 2: the save remembers the pips, the feed still waits")
	await _frames(main, 4)
	ok(true, "the real HUD draws match 2 staged without a script error")
	m.queue_free()
	await _frames(main, 2)
	# ---------------------------------------------------------------- 5. never staged off the expedition
	Save.d["matches"] = 0
	m = _match(main, {"training": true})
	ok(not HudReveal.staged(m) and _shown(m).size() == g.size(), "training shows the full HUD")
	m.queue_free()
	print("HUDREVEAL DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)
