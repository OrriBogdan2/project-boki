extends "res://tools/new_player_flow_check.gd"
## --tutorial-playthrough-check: ABSOLUTE gate check (not "new red vs main"). A new player's first run on a fresh
## save (prologue, hatch, starter pick, "Learn to fight"), then the tutorial course played by TutorialDrive. Fails
## when any step takes longer than STEP_LIMIT_S of game time, or the course does not reach its end (the lift and
## the results). Prints one "TUTPLAY step <id> <seconds>" row per step. The screens before and after the course
## are --new-player-flow-check's, so a stall there fails too. Seconds are game time, the same on any box.
## Options: `--fps=N` caps the frame rate and runs the course on the match's own frame loop (the driver acts once
## per drawn frame, so at 30 fps an input is held for two sim steps and at 144 a frame may run none);
## `--window=WxH` sizes the window (default 1280x720). Without `--fps` the course is stepped one sim step a call.

const STEP_LIMIT_S := 40.0      # s of game time one step may take (the flow check's own limit is 45)

var step_id := ""
var step_s := 0.0
var rows: Array = []
var stalled := false
var last_time := -1.0

func run(m: Node) -> void:
	main = m
	tree = main.get_tree()
	Save.no_write = true
	Save.d = Save.fresh()
	var window := Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fps="):
			Engine.max_fps = int(a.substr(6))
			frame_loop = true
		elif a.begins_with("--window="):
			var wh := a.substr(9).split("x")
			window = Vector2i(int(wh[0]), int(wh[1]))
	main.get_window().size = window
	print("TUTPLAY CASE fps cap %d, window %dx%d" % [Engine.max_fps, window.x, window.y])
	await _prologue()
	await _hatch()
	await _tutorial_match()
	_end()
	print("TUTPLAY STEPS: " + ", ".join(rows))
	print("TUTPLAY DONE, failures: %d" % bad)
	tree.quit(1 if bad > 0 else 0)

## One call per sim step (or drawn frame) of the course: closes a step's row when the next one starts, and ends the
## run at once on a step that outlasts its limit (the course would otherwise run on to the whole-course cap).
func _course_tick(m: Match) -> void:
	if stalled:
		return
	var id: String = m.tut.id()
	if id != step_id:
		_close_step()
		step_id = id
		step_s = 0.0
	step_s += m.time - last_time if last_time >= 0.0 else 0.0
	last_time = m.time
	if step_s > STEP_LIMIT_S:
		stalled = true
		ok(false, "step '%s' did not finish in %.0f s (stuck at game time %.0f s)" % [id, STEP_LIMIT_S, m.time])
		_close_step()
		print("TUTPLAY STEPS: " + ", ".join(rows))
		print("TUTPLAY DONE, failures: %d" % bad)
		tree.quit(1)

func _close_step() -> void:
	if step_id == "":
		return
	print("TUTPLAY step %s %.1f" % [step_id, step_s])
	rows.append("%s %.1f" % [step_id, step_s])
