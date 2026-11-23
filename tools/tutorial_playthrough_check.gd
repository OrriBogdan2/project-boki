extends "res://tools/new_player_flow_check.gd"
## --tutorial-playthrough-check: ABSOLUTE gate check (not "new red vs main"). A new player's first run on a fresh
## save (prologue, hatch, starter pick, "Learn to fight"), then the tutorial course played by TutorialDrive. Fails
## when any step takes longer than STEP_LIMIT_S of game time, or the course does not reach its end (the lift and
## the results). Prints one "TUTPLAY step <id> <seconds>" row per step. The screens before and after the course
## are --new-player-flow-check's, so a stall there fails too. Seconds are game time, the same on any box.

const STEP_LIMIT_S := 40.0  # s of game time one step may take (the flow check's own limit is 45)
const TIME_SCALE := 4.0  # the hatch and Relic screens wait out real-time tweens (33 s); game time is unchanged

var step_id := ""
var step_s := 0.0
var rows: Array = []
var stalled := false


func run(m: Node) -> void:
	main = m
	tree = main.get_tree()
	Save.no_write = true
	Save.d = Save.fresh()
	main.get_window().size = Vector2i(1280, 720)
	Engine.time_scale = TIME_SCALE
	var t0 := Time.get_ticks_msec()
	await _prologue()
	_took("prologue", t0)
	await _hatch()
	_took("hatch", t0)
	await _tutorial_match()
	_end()
	_took("course", t0)
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
	await da._farm("Lace", "archer")
	ok(da.bad == 0, "the garden tutorial plays to its end with no stall (%d dead-air failures)" % da.bad)
	print("TUTPLAY garden steps %d, done %s" % [FarmTutorial.steps().size(), FarmTutorial.state().get("done", false)])


## One call per sim step of the course: closes a step's row when the next one starts, and ends the run at once on a
## step that outlasts its limit (the course would otherwise run on to the flow check's whole-course cap).
func _course_tick(m: Match) -> void:
	if stalled:
		return
	var id: String = m.tut.id()
	if id != step_id:
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
	print("TUTPLAY time %s at %.0f s (wall clock, %d frames)" % [phase, s, Engine.get_process_frames()])


func _close_step() -> void:
	if step_id == "":
		return
	print("TUTPLAY step %s %.1f" % [step_id, step_s])
	rows.append("%s %.1f" % [step_id, step_s])
