extends "res://tools/new_player_flow_check.gd"
## --garden-first-15-check: the first 15 minutes of a player who never extracts. A fresh save skips the
## match tutorial ("Skip the tutorial" on the naming card), takes its first Relic and lands on the garden;
## a bot then raises, plays, races and breeds there for 15 minutes of garden time and never opens a match.
## Every second it asks what is on screen to guide the player: the tutorial line, the world marker, the
## interact prompt, a Boki's want bubble, or a Goals row that can be done at home. A stretch with none of
## them is a gap: each 10 s window with no guidance is listed, and a gap of GAP_FAIL_S or more fails.
## Never touches the real save.

const STEP_S := 0.05      # s of garden time per step
const WINDOW_S := 10.0      # s: a window with no guidance at all is logged
const REACT_S := 8.0      # s a player takes to do what a prompt says
const RACE_MAX_S := 120.0      # s of race time a run may take
const GAP_FAIL_S := 20.0      # s with no guidance that fails the check
## Goals rows that need a match are no guidance for a player who stays home.
const HOME_SOURCES := ["first_day", "garden", "milestone", "level"]

var sim_s := 900.0      # s of garden time played (15 minutes)
var home
var clock := 0.0      # s of garden time played so far
var log_rows: Array = []      # one text row per 10 s window with no guidance
var gap_s := 0.0      # s since guidance was last on screen
var worst_gap := 0.0
var empty_windows := 0
var ranges: Array = []      # the same windows as [from, to] pairs, touching ones merged

func run(m: Node) -> void:
	main = m
	tree = main.get_tree()
	Save.no_write = true
	Save.d = Save.fresh()
	Content.rules("farm_build")["base_mode"] = true
	main.get_window().size = Vector2i(1280, 720)
	await _skip_to_garden()
	await _play()
	print("G15 gaps: worst %.1f s, %d windows without guidance" % [worst_gap, empty_windows])
	for r in log_rows:
		print("G15 no guidance " + String(r))
	_verdicts()
	print("G15 DONE, failures: %d" % bad)
	tree.quit(1 if bad > 0 else 0)

func _verdicts() -> void:
	ok(_is_screen("home.gd") and int(Save.d.get("matches", 0)) == 0, "the play never left the garden for a match")
	var what := "never %.0f s without a prompt, goal or target (worst %.1f s)"
	ok(worst_gap < GAP_FAIL_S, what % [GAP_FAIL_S, worst_gap])

## A new player who skips the match tutorial on the naming card: eggs, name, first Relic, garden.
func _skip_to_garden() -> void:
	Save.d["tutorial"].merge({"intro": true, "prologue": true})
	Save.d["look"] = Unmasked.default_look()
	await main.show_screen("hatch", {})
	var hx = main.current
	await _wait(func(): return hx.stage == "pick", "a new player reaches the eggs")
	hx.chosen = 0
	hx.stage = "name"
	hx._show_name()
	_press(hx, "Skip the tutorial")
	await _relic(hx)
	await _wait(func(): return _is_screen("home.gd"), "'Skip the tutorial' goes straight to the garden")
	home = main.current
	await _wait(func(): return home.panel_host != null, "the garden builds")
	home._close_panel()
	home.set_process(false)      # the bot steps the garden itself, 20 steps a second of garden time

## What is on screen to guide the player now: the names of the kinds, empty for nothing.
func guidance() -> Array:
	var out: Array = []
	var g = home.guide
	if is_instance_valid(g.hint_box) and g.hint_box.visible:
		out.append("tutorial line")
	if is_instance_valid(g.marker) and g.marker.visible:
		out.append("world marker")
	for k in home.kins:
		var bub = k.get("bubble")
		if is_instance_valid(bub) and bub.visible:
			out.append("want bubble")
			break
	if is_instance_valid(g.tracker) and g.tracker.visible:
		for r in GoalTracker.lines():
			if r["source"] in HOME_SOURCES and int(r["have"]) < int(r["need"]):
				out.append("goal: " + String(r["text"]))
				break
	return out

func _play() -> void:
	var t := 0.0
	var window_t := 0.0
	var window_empty := true
	var next_look := 0.0
	var last_kinds := ""
	var next_act := REACT_S
	while t < sim_s:
		home._process(STEP_S)
		t += STEP_S
		clock = t
		if t < next_look:
			continue
		next_look += 1.0
		var seen := guidance()
		if t >= next_act:
			next_act = t + REACT_S
			_act()
		var kinds := ", ".join(seen)
		if kinds != last_kinds:
			print("G15 %4.0f s  %s" % [t, kinds if kinds != "" else "(nothing)"])
			last_kinds = kinds
		if seen.is_empty():
			gap_s += 1.0
		else:
			gap_s = 0.0
			window_empty = false
		worst_gap = maxf(worst_gap, gap_s)
		window_t += 1.0
		if window_t >= WINDOW_S:
			if window_empty:
				empty_windows += 1
				_log_window(t - WINDOW_S, t)
			window_t = 0.0
			window_empty = true
		if int(t) % 5 == 0:
			await tree.process_frame

## The player does the next thing the garden asks of them: the tutorial step, else the first open Goals line.
func _act() -> void:
	var rec: Dictionary = home.kins[0]["rec"]
	if FarmTutorial.active():
		match FarmTutorial.current():
			"meet": FarmTutorial.event("meet")
			"eat": home._after_feed(home.kins[0], "emberberry", Care.feed(rec, "emberberry"))
			"toy": _place_toy()
			"out": FarmTutorial.event("stay")
		return
	for r in GardenFirstDay.rows():
		if r["done"]:
			continue
		var rules: Array = GardenFirstDay.rules()["rows"]
		var line: Dictionary = rules.filter(func(l): return l["text"] == r["text"])[0]
		match String(line["id"]):
			"feed": GardenFirstDay.mark("feed", home)
			"race": _race()
		return

func _race() -> void:
	home.hrace.solo(home.kins[0]["rec"])      # a lone Boki runs the Training post
	var t := 0.0
	while home.hrace.run != null and t < RACE_MAX_S:
		home.hrace.tick(0.1)
		t += 0.1

func _place_toy() -> void:
	var lay := HomeLayout.ensure(Save.d)
	var at := HomeLayout.LANDING
	var toy := {"u": HomeLayout._next_uid(lay), "id": "toy_ball", "x": int(at.x) - 3, "z": int(at.z) - 6, "r": 0}
	(lay["deco"] as Array).append(toy)
	home._sync_fixtures()

## Adds the window [from, to] to the log; windows that touch run together as one range.
func _log_window(from: float, to: float) -> void:
	if not log_rows.is_empty() and is_equal_approx(float(ranges[-1][1]), from):
		ranges[-1][1] = to
		log_rows[-1] = "%.0f-%.0f s" % [ranges[-1][0], to]
	else:
		ranges.append([from, to])
		log_rows.append("%.0f-%.0f s" % [from, to])
