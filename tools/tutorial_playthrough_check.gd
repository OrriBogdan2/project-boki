extends "res://tools/new_player_flow_check.gd"
## --tutorial-playthrough-check: ABSOLUTE gate check (not "new red vs main"). A new player's first run on a fresh
## save (prologue, hatch, starter pick, "Learn to fight"), then the tutorial course played by TutorialDrive. The
## starter is Vex, or `-- --starter=archer|juggernaut|gunslinger` (Lace, Kael). Fails when any step takes longer
## than STEP_LIMIT_S of game time, or the course does not reach its end (the lift and the results). Prints one
## "TUTPLAY step <id> <seconds>" row per step. The screens before and after the course
## are --new-player-flow-check's, so a stall there fails too. Seconds are game time, the same on any box.
## Also the Mask line (lore.json mask_line, DECISIONS 'Identity and Masks'): on screen once, when the first Relic
## waits by your face, and on no other screen of the run.

const STEP_LIMIT_S := 40.0  # s of game time one step may take (the flow check's own limit is 45)
const TIME_SCALE := 4.0  # prologue, hatch and Relic screens wait out real-time tweens (33 s); game time unchanged

const STARTERS := {"Lace": "archer", "Kael": "juggernaut", "Vex": "gunslinger"}  # the tutorial's starter pick

var step_id := ""
var step_s := 0.0
var rows: Array = []
var stalled := false
var line_seen := 0


func run(m: Node) -> void:
	main = m
	tree = main.get_tree()
	Save.no_write = true
	Save.d = Save.fresh()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--starter="):
			starter = a.substr(10)
	ok(starter in STARTERS.values(), "the starter is Lace, Kael or Vex (%s)" % starter)
	main.get_window().size = Vector2i(1280, 720)
	Engine.time_scale = TIME_SCALE
	var t0 := Time.get_ticks_msec()
	await _prologue()
	_took("prologue", t0)
	await _hatch()
	_took("hatch", t0)
	# (back to 1x before the match: its load is real work, not tweens, and at 4x a loaded box burned the 60 s
	# stall budget in 15 s of wall clock; the course itself is stepped by m.step(Match.DT), so scale-free)
	Engine.time_scale = 1.0
	await _tutorial_match()
	_end()
	_took("course", t0)
	ok(line_seen == 1, "the Mask line shows exactly once, at the first Relic (%d times)" % line_seen)
	Engine.time_scale = 1.0
	if not stalled:
		await _garden()
		_took("garden", t0)
	print("TUTPLAY STEPS: " + ", ".join(rows))
	print("TUTPLAY DONE, failures: %d" % bad)
	tree.quit(1 if bad > 0 else 0)


## The garden tutorial, start to finish, with --tutorial-dead-air-check's farm player (a fresh save with the starter
## hatched, every Hob step shown and done, the house hammered up, the crop planted, watered and picked). Its checks
## (no step without a hint or marker for over its GAP_MAX, no two prompts at once, every step reached its end) count
## as failures here, so a garden step that never finishes fails the gate too.
func _garden() -> void:
	var da = load("res://tools/tutorial_dead_air_check.gd").new()
	da.main = main
	await da._farm(STARTERS.find_key(starter), starter)
	ok(da.bad == 0, "the garden tutorial plays to its end with no stall (%d dead-air failures)" % da.bad)
	print("TUTPLAY garden steps %d, done %s" % [FarmTutorial.steps().size(), FarmTutorial.state().get("done", false)])


## One call per sim step of the course: closes a step's row when the next one starts, and ends the run at once on a
## step that outlasts its limit (the course would otherwise run on to the flow check's whole-course cap).
func _course_tick(m: Match) -> void:
	if stalled:
		return
	var id: String = m.tut.id()
	if id != step_id:
		_count_line("tutorial step '%s'" % id, 0)
		_close_step()
		step_id = id
		step_s = 0.0
	step_s += Match.DT
	if step_s > STEP_LIMIT_S:
		stalled = true
		ok(false, "step '%s' did not finish in %.0f s (stuck at game time %.0f s)" % [id, STEP_LIMIT_S, m.time])
		_close_step()
		print("TUTPLAY STEPS: " + ", ".join(rows))
		print("TUTPLAY DONE, failures: %d" % bad)
		tree.quit(1)


## Wall-clock seconds since the start, by phase: where a slow (loaded) box spends the suite's 1200 s.
func _took(phase: String, t0: int) -> void:
	var s := (Time.get_ticks_msec() - t0) / 1000.0
	var up := Time.get_ticks_msec() / 1000.0  # (since the engine started: the boot before run() shows too)
	print(
		"TUTPLAY time %s at %.0f s (wall clock, %.0f s uptime, %d frames)" % [phase, s, up, Engine.get_process_frames()]
	)


func _close_step() -> void:
	if step_id == "":
		return
	print("TUTPLAY step %s %.1f" % [step_id, step_s])
	rows.append("%s %.1f" % [step_id, step_s])

## The Mask line is shown only at the put-on prompt: one label there, none on any other screen.
func _before_act(what: String) -> void:
	_count_line(what, 1 if what == "put the Relic on" else 0)

func _count_line(where: String, want: int) -> void:
	var line := String(Content.rules("lore")["mask_line"])
	ok(line == "This Relic holds a fallen Hunter. Put it on, and you become them.", "the Mask line's words: " + line)
	var n := _labels_with(tree.root, line)
	line_seen += n
	ok(n == want, "the Mask line shows %d time(s) before '%s', want %d" % [n, where, want])

func _labels_with(node: Node, text: String) -> int:
	var n := 1 if node is Label and (node as Label).text == text and (node as Label).is_visible_in_tree() else 0
	for c in node.get_children():
		n += _labels_with(c, text)
	return n
