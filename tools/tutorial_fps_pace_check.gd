extends RefCounted
## --tutorial-fps-pace-check: the stabilize sprint's gate (DECISIONS 11-19, a tutorial playthrough that must finish).
## The full match course (a bot plays it through Match's own frame loop and TutorialDrive) and the garden tutorial
## (tools/farm_tutorial_fps_pace.gd) are each played at a fixed 30 fps and at 60 fps (Engine.max_fps; one drawn frame
## is judged at a time, as a player sees it). Per step it logs the game time, and fails on:
##   - a step longer than its budget (BUDGET_S, else BUDGET_DEFAULT_S)
##   - a span over GAP_S with no prompt (banner, hint line in the lane, or a marker)
##   - a banner step (not a hint-only one) with any drawn frame where the objective banner is not up: a slim strip
##     (TutorialStrip) at the top-centre, on screen, no taller than HEIGHT_FRAC and out of the play box
## `--starter=archer|juggernaut|gunslinger` picks the hunter (default gunslinger). One "FPSPACE row" per step is
## printed in the table docs/TUTORIAL_PACE.md section 6 keeps.

const FPS := [30, 60]
const GAP_S := 8.0  # s: the longest a step may go with no prompt on screen
const BUDGET_DEFAULT_S := 12.0  # s of game time a step may take unless BUDGET_S says otherwise
const BUDGET_S := {"pack": 30.0, "defend": 15.0}  # step id -> s: the fights wait on a cooldown or a wave
const MAX_T := 240.0  # s of game time before a course counts as stuck
const WALL_CAP_S := 400.0  # s of CheckClock a course may take
const SCREEN := Vector2(1920, 1080)  # px: the screen the strip is laid out on
const TOP_BAND := 0.2  # of the screen height: the strip stays inside this top band (it never reaches the play)

var bad := 0
var arch := "gunslinger"
var rows: Array = []  # every row of every round, for the table
var garden_rows: Array = []


func ok(cond: bool, what: String) -> void:
	print("FPSPACE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--starter="):
			arch = a.substr(10)
	Save.no_write = true
	var quality_was = Settings.v.get("quality", "auto")
	Settings.v["quality"] = "low"
	Settings.apply("quality")
	for fps in FPS:
		await _course(main, int(fps))
	Settings.v["quality"] = quality_was
	Settings.apply("quality")
	for fps in FPS:
		var g = load("res://tools/farm_tutorial_fps_pace.gd").new()
		await g.round_at(main, int(fps))
		bad += g.bad
		garden_rows.append_array(g.rows)
	for r in rows + garden_rows:
		print("FPSPACE row | " + " | ".join(r))
	print("FPSPACE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## Whether the match's objective banner is up this frame: a banner step has its line, and the strip's rect (dropping
## in for TutorialStrip.POP_T, then still) is on the screen, no taller than HEIGHT_FRAC, inside the top band.
static func banner_up(m: Match, sz := SCREEN) -> bool:
	var tu: Tutorial = m.tut
	if tu.intro or tu.text == "" or m.hud == null or not m.hud.visible:
		return false
	var r := TutorialStrip.shown(sz, tu.card_t)
	return (
		Rect2(Vector2.ZERO, sz).intersects(r)
		and r.size.y <= sz.y * TutorialStrip.HEIGHT_FRAC + 0.5
		and r.size.x <= sz.x * TutorialStrip.WIDTH_FRAC + 0.5
		and r.end.y <= sz.y * TOP_BAND
	)


## A prompt of any kind is up: the banner, a line in the message lane, or the step's marker.
static func prompt_up(m: Match, sz := SCREEN) -> bool:
	var tu: Tutorial = m.tut
	if tu.intro or banner_up(m, sz) or not m.hud.msgs.texts().is_empty():
		return true
	return tu.target != Vector3.INF and tu.label != "" and tu.beams_on() > 0


func _course(main: Node, fps: int) -> void:
	seed(7)
	Save.d = Save.fresh()
	var tree := main.get_tree()
	var m := Match.new()
	main.add_child(m)
	m.start(
		{
			"tutorial": true,
			"teams": 1,
			"squad": 1,
			"tier": 0,
			"length": 1500.0,
			"demo_kin": "cindle",
			"cls": Arch.weight(arch),
			"arch": arch,
			"weapon": Arch.signature(arch),
			"tut_test": true
		}
	)
	Engine.max_fps = fps
	m.set_process(true)
	var tu: Tutorial = m.tut
	var wall0 := CheckClock.own_msec()
	var frames := 0
	var cur := ""
	var row := {}
	var last_t := m.time
	var order: Array = []
	while m.time < MAX_T and not m.player.extracted and CheckClock.own_msec() - wall0 < WALL_CAP_S * 1000.0:
		await tree.process_frame
		frames += 1
		var dt := m.time - last_t
		last_t = m.time
		if tu.step < 0 or tu.step >= Tutorial.steps().size():
			continue
		var id := tu.id()
		if id != cur:
			if not row.is_empty():
				_close(row, fps)
			cur = id
			order.append(id)
			row = {"id": id, "t": 0.0, "frames": 0, "miss": 0, "gap": 0.0, "worst": 0.0}
			row["strip"] = not TutorialHints.quiet(id)
		row["t"] += dt
		row["frames"] += 1
		if row["strip"] and not banner_up(m):
			row["miss"] += 1
		row["gap"] = 0.0 if prompt_up(m) else float(row["gap"]) + dt
		row["worst"] = maxf(float(row["worst"]), float(row["gap"]))
	if not row.is_empty():
		_close(row, fps)
	Engine.max_fps = 0
	var fin := "%d fps: the course finishes (%d steps in %.0f s of play, %d frames)"
	ok(m.player.extracted, fin % [fps, order.size(), m.time, frames])
	m.queue_free()
	await tree.process_frame


func _close(row: Dictionary, fps: int) -> void:
	var id: String = row["id"]
	var budget: float = float(BUDGET_S.get(id, BUDGET_DEFAULT_S))
	var kind := "banner" if row["strip"] else "hint-only"
	var tag := "match %d fps %s" % [fps, id]
	ok(float(row["t"]) <= budget, "%s: %.1f s, budget %.0f s" % [tag, row["t"], budget])
	ok(float(row["worst"]) <= GAP_S, "%s: longest span with no prompt %.1f s (<= %.0f s)" % [tag, row["worst"], GAP_S])
	if row["strip"]:
		var up := "%s: the banner is up on all %d frames (%d without)"
		ok(int(row["miss"]) == 0, up % [tag, row["frames"], row["miss"]])
	rows.append(
		[
			"match",
			str(fps),
			id,
			kind,
			"%.1f" % row["t"],
			"%.0f" % budget,
			"%d/%d" % [row["miss"], row["frames"]],
			"%.1f" % row["worst"]
		]
	)
