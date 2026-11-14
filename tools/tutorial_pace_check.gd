extends "res://tools/new_player_flow_check.gd"
## --tutorial-pace-check (ADVISORY: pace flags never fail it; only a stall in the run does): how long each beat of a new
## player's first finished expedition takes at human pace. It is --new-player-flow-check (title to the first finished
## expedition on a fresh save) with TutorialDrive in human mode, and a ledger. Per beat it prints
##   PACE row | beat | kind | seconds | reading s | idle s | worst wait s | note
## kind: sim = game seconds at human pace (the tutorial course); wall = the screen's own animation seconds plus
## reading and reaction; est = from the game's data (the farm tutorial's swings, the walk to the dock).
## Flags: a beat over BEAT_MAX_S, any wait over WAIT_MAX_S with nothing to do. The write-up is docs/TUTORIAL_PACE.md.

const BEAT_MAX_S := 45.0  # s: a beat longer than this is flagged
const WAIT_MAX_S := 5.0  # s: a wait with nothing to do longer than this is flagged
const SEED := 11  # the driver's misses are the same every run
const CLICK_S := 0.6  # s a click on a button takes
const WALK_FARM_S := 8.0  # s of walking to the next place on the farm
const UI_STEP_S := 3.0  # s to open a build menu or a stall tab and pick something
const DETOUR := 1.3  # path length over straight line, for the walk to the dock
const KNOCK_S := 1.75  # s of the seven knocks in the hatch, which are action, not waiting
const UI_STAGES := [
	"title",
	"prologue",
	"hatch: card and look",
	"hatch: egg pick and knocks",
	"hatch: its look and naming",
	"first Relic",
	"tutorial match: load",
	"results",
	"farm: first arrival",
	"first expedition: start",
	"first expedition: pre-match countdown",
	"first expedition: results"
]
## Farm tutorial step -> [walks, menu picks, tool, the house's cost line that sets the swings (one swing a unit)]:
## what the player does beyond reading the hint.
const FARM_ACT := {
	"hob": [1, 0, "", ""],
	"axe": [0, 0, "", ""],
	"chop": [1, 0, "axe", "wood"],
	"stone": [1, 0, "pickaxe", "stone"],
	"house": [1, 2, "", ""],
	"hammer": [0, 0, "hammer", "labour"],
	"task": [0, 1, "", ""],
	"feed": [1, 2, "", ""],
	"crop": [1, 2, "", ""],
	"buy": [1, 1, "", ""],
	"sell": [1, 1, "", ""],
	"expedition": [1, 0, "", ""]
}

var rows: Array = []
var read_seen := {}  # text -> true: a line is read once
var stage_read := 0.0
var stage_worst := 0.0  # s: the longest single wait in the stage
var stage_wall_t0 := 0


func run(m: Node) -> void:
	main = m
	tree = main.get_tree()
	Save.no_write = true
	Save.d = Save.fresh()
	main.get_window().size = Vector2i(1280, 720)
	TutorialDrive.human = true
	TutorialDrive.beats = {}
	TutorialDrive._rng.seed = SEED
	await _title()
	await _prologue()
	await _hatch()
	var home = await _tutorial_match()
	await _farm_tutorial(home)
	await _second_relic(home)
	await _first_expedition(home)
	TutorialDrive.human = false
	_report()
	tree.quit(1 if bad > 0 else 0)


# ------------------------------------------------------------------ the ledger
func _row(beat: String, kind: String, secs: float, read: float, idle: float, worst: float, note := "") -> void:
	rows.append([beat, kind, secs, read, idle, worst, note])


## Nothing is asserted here: a failed check of the flow is noted, a stall quits the run (in _wait).
func ok(cond: bool, what: String) -> void:
	print("PACE %s %s" % ["ok  " if cond else "note: flow check failed:", what])


func _begin(stage: String) -> void:
	_end()
	stage_name = stage
	stage_read = 0.0
	stage_worst = 0.0
	stage_wall_t0 = Time.get_ticks_msec()


## A UI stage: its wall seconds are the screen's own waits, plus the reading and reaction on what showed up.
func _end() -> void:
	if stage_name in UI_STAGES:
		var wall := (Time.get_ticks_msec() - stage_wall_t0) / 1000.0
		wall -= KNOCK_S if stage_name == "hatch: egg pick and knocks" else 0.0
		var secs := wall + stage_read
		_row(stage_name, "wall", secs, stage_read, secs, stage_worst)
	stage_name = ""


## Waits as the base does, then reads whatever new text the screen put up, and reacts.
func _wait(cond: Callable, what: String, secs := STALL_S) -> bool:
	if what.begins_with("the skipped prologue"):
		_prologue_watched()
	var t0 := Time.get_ticks_msec()
	var got: bool = await super._wait(cond, what, secs)
	stage_worst = maxf(stage_worst, (Time.get_ticks_msec() - t0) / 1000.0)
	if is_instance_valid(main.current) and not _is_screen("home.gd") and not main.current is Match:
		stage_read += _read_new(main.current) / TutorialDrive.READ_WPS + TutorialDrive.REACT_S + CLICK_S
	return got


## The prologue is watched through (nobody knows yet that a key skips it): its shots' own durations.
func _prologue_watched() -> void:
	var s := 0.0
	if not is_instance_valid(main.current) or not "shots" in main.current:
		return  # (no prologue on screen: nothing to watch)
	for shot in main.current.shots:
		s += float(shot["dur"])
	stage_read += s
	stage_worst = maxf(stage_worst, s)  # (a key skips it, but nothing says so)


## Words on the screen that were not read yet (labels, not buttons).
func _read_new(root: Node) -> int:
	var words := 0
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		var txt := ""
		if c is RichTextLabel:
			txt = (c as RichTextLabel).get_parsed_text()
		elif c is Label:
			txt = (c as Label).text
		if txt != "" and c.is_visible_in_tree() and not read_seen.has(txt):
			read_seen[txt] = true
			words += txt.split(" ", false).size()
	return words


func _title() -> void:
	_begin("title")
	await main.show_screen("title", {})
	await _wait(func(): return is_instance_valid(main.current), "the title opens")


# ------------------------------------------------------------------ the farm and the expedition
func _do_step(id: String) -> void:
	var words: int = FarmTutorial.hint_text(id).split(" ", false).size()
	var read := words / TutorialDrive.READ_WPS + TutorialDrive.REACT_S
	var act: Array = FARM_ACT.get(id, [1, 1, "", 0])
	var swings := int(FarmSites.build_cost("house").get(String(act[3]), 0))
	var work := swings * (HunterTool.period(String(act[2])) if act[2] != "" else 0.0)
	var did := float(act[0]) * WALK_FARM_S + float(act[1]) * UI_STEP_S + work
	_row(
		"farm: " + id,
		"est",
		read + did,
		read,
		read,
		0.0,
		"%d walks, %d menu picks, %d swings" % [act[0], act[1], swings]
	)
	super._do_step(id)


func _skiff(m: Match) -> void:
	var pp: Hunter = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var jump_at: float = float(pp.ai.get("jump_at", 0.0))
	var t := 0.0
	while (pp.riding or pp.dropping or not pp.grounded) and t < DROP_S:
		pp.inp["jump"] = pp.riding and t > jump_at and int(t * 20.0) % 2 == 0
		pp.inp["move"] = _toward(pp, pp.ai.get("land", pp.pos)) if not pp.riding else Vector2.ZERO
		m.step(Match.DT)
		t += Match.DT
	pp.inp["jump"] = false
	pp.inp["move"] = Vector2.ZERO
	var ride := minf(t, jump_at)
	_row(
		"expedition: ship and drop",
		"sim",
		t,
		0.0,
		ride,
		ride,
		"on the ship until the jump (%.0f s), then the fall" % jump_at
	)
	var d: Dictionary = m.exits.of_kind("dock")[0]
	var dock: Vector3 = d["pos"]
	var walk := Vector2(dock.x - pp.pos.x, dock.z - pp.pos.z).length() * DETOUR / pp.base_speed
	var open_at: float = float(d["open_at"])
	var wait := maxf(0.0, open_at - (t + walk))
	_row(
		"expedition: walk to the skiff",
		"est",
		walk,
		0.0,
		0.0,
		0.0,
		"straight line x %.1f at run speed %.1f m/s" % [DETOUR, pp.base_speed]
	)
	_row(
		"expedition: wait for the skiff to open",
		"sim",
		wait,
		0.0,
		wait,
		wait,
		"opens at %.0f s; free to loot meanwhile" % open_at
	)
	pp.max_hp = 5000.0
	pp.hp = pp.max_hp
	while m.time < open_at + 1.0 and not pp.out:
		pp.teleport(dock + Vector3(0.3, 0, 0.3))
		pp.hp = pp.max_hp
		m.step(Match.DT)
	var t0 := m.time
	for i in int(2.5 / Match.DT):
		pp.inp["interact"] = true
		m.step(Match.DT)
	pp.inp["interact"] = false
	while d["state"] in ["called", "boarding"] and m.time - t0 < 120.0:
		pp.teleport(d["berth"])
		pp.hp = pp.max_hp
		m.step(Match.DT)
	var board := m.time - t0
	_row(
		"expedition: call and board the skiff",
		"sim",
		board,
		0.0,
		board - 2.5,
		board - 2.5,
		"hold interact 2.5 s, then Exits.CALL_T and BOARD_T"
	)
	ok(pp.extracted, "the skiff takes you out")
	_begin("first expedition: results")
	await _wait(func(): return main.current is CanvasLayer, "and the expedition ends on the results")
	_press(main.current, "Back to the farm")
	await _wait(func(): return _is_screen("home.gd"), "back on the farm")
	_end()


# ------------------------------------------------------------------ the report
func _report() -> void:
	var n := 0
	var total := 0.0
	var idle_total := 0.0
	print("PACE row | beat | kind | seconds | reading s | idle s | worst wait s | note")
	for r in _all_rows():
		n += 1
		total += float(r[2])
		idle_total += float(r[4])
		print("PACE row | %s | %s | %.1f | %.1f | %.1f | %.1f | %s" % [r[0], r[1], r[2], r[3], r[4], r[5], r[6]])
		if float(r[2]) > BEAT_MAX_S:
			print("PACE FLAG beat over %.0f s: %s (%.1f s)" % [BEAT_MAX_S, r[0], r[2]])
		if float(r[5]) > WAIT_MAX_S:
			print("PACE FLAG wait over %.0f s with nothing to do: %s (%.1f s)" % [WAIT_MAX_S, r[0], r[5]])
	print("PACE total %.0f s over %d beats, %.0f s idle (reading, waiting)" % [total, n, idle_total])
	print("PACE DONE (advisory: flags do not fail)")


## The stage rows and the course's steps in the order they happened: the course sits where the tutorial match began.
func _all_rows() -> Array:
	var out: Array = []
	for r in rows:
		out.append(r)
		if r[0] == "tutorial match: load":
			out.append_array(_course_rows())
	return out


func _course_rows() -> Array:
	var intro := Tutorial.INTRO_T
	var out: Array = [["tutorial: intro card", "sim", intro, intro, intro, 0.0, "auto-closes; any key sooner"]]
	for k in TutorialDrive.beats:
		var b: Dictionary = TutorialDrive.beats[k]
		out.append(["tutorial: " + String(b["id"]), "sim", b["secs"], b["read"], b["idle"], b["worst"], ""])
	return out
