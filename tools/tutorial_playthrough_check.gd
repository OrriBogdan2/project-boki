extends "res://tools/new_player_flow_check.gd"
## --tutorial-playthrough-check: ABSOLUTE gate check (not "new red vs main"). A new player's first run on a fresh
## save (prologue, hatch, starter pick, "Learn to fight"), then the tutorial course played by TutorialDrive. The
## starter is Vex, or `-- --starter=archer|juggernaut|gunslinger` (Lace, Kael). Fails when any step takes longer
## than STEP_LIMIT_S of game time, or the course does not reach its end (the lift and the results). Prints one
## "TUTPLAY step <id> <seconds>" row per step. The screens before and after the course
## are --new-player-flow-check's, so a stall there fails too. Seconds are game time, the same on any box.
## Also the Mask line (lore.json mask_line, DECISIONS 'Identity and Masks'): on screen once, when the first Relic
## waits by your face, and on no other screen of the run.
## Options: `--fps=N` caps the frame rate and runs the course on the match's own frame loop (the driver acts once
## per drawn frame, so at 30 fps an input is held for two sim steps and at 144 a frame may run none);
## `--window=WxH` sizes the window (default 1280x720). Without `--fps` the course is stepped one sim step a call.

const STEP_LIMIT_S := 40.0  # s of game time one step may take (the flow check's own limit is 45)
const TIME_SCALE := 4.0  # the hatch and Relic screens wait out real-time tweens (33 s); game time is unchanged

const STARTERS := {"Lace": "archer", "Kael": "juggernaut", "Vex": "gunslinger"}  # the tutorial's starter pick

var step_id := ""
var step_s := 0.0
var rows: Array = []
var stalled := false
var line_seen := 0
var last_time := -1.0


func run(m: Node) -> void:
	main = m
	tree = main.get_tree()
	Save.no_write = true
	Save.d = Save.fresh()
	var window := Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--starter="):
			starter = a.substr(10)
		elif a.begins_with("--fps="):
			Engine.max_fps = int(a.substr(6))
			frame_loop = true
		elif a.begins_with("--window="):
			var wh := a.substr(9).split("x")
			window = Vector2i(int(wh[0]), int(wh[1]))
	ok(starter in STARTERS.values(), "the starter is Lace, Kael or Vex (%s)" % starter)
	main.get_window().size = window
	Engine.time_scale = TIME_SCALE
	print("TUTPLAY CASE fps cap %d, window %dx%d" % [Engine.max_fps, window.x, window.y])
	await _prologue()
	await _hatch()
	await _tutorial_match()
	_end()
	ok(line_seen == 1, "the Mask line shows exactly once, at the first Relic (%d times)" % line_seen)
	Engine.time_scale = 1.0
	if not stalled:
		await _garden()
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


## One call per sim step (or drawn frame) of the course: closes a step's row when the next one starts, and ends the
## run at once on a step that outlasts its limit (the course would otherwise run on to the whole-course cap).
func _course_tick(m: Match) -> void:
	if stalled:
		return
	var id: String = m.tut.id()
	if id != step_id:
		_count_line("tutorial step '%s'" % id, 0)
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
