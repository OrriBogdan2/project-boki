extends "res://tools/new_player_flow_check.gd"
## --fresh-run-log [--shots-dir=<dir>]: the new-player flow (prologue, hatch, first Relic, the match tutorial,
## the farm tutorial) on a fresh save, as a player who looks before acting: at every screen and step it
## waits HOLD_S s doing nothing and prints one line per second: the prompt text on show, whether the
## world marker and the edge arrow are on screen, and the idle time. Ends with every gap over GAP_S s
## with no prompt, every second the marker was hidden and every text over WALL_CHARS characters.
## A real renderer also gets a shot per step (<dir>/NN_<what>.png). Reads like --new-player-flow-check,
## which it extends; it asserts nothing itself.

const HOLD_S := 10.0  # s a screen or farm step is looked at before acting
const GAP_S := 8.0  # s: the longest a player may go with no prompt on show
const WALL_CHARS := 110  # a prompt text longer than this is a wall of words
const SHOW_CHARS := 140  # characters of a prompt the log prints (a longer one shows its length)
const GAP_LOG := "FRESH GAPS"

var shots_dir := ""
var shot_n := 0
var gaps: Array = []
var walls := {}
var hidden: Array = []
var _last_step := ""


func run(m: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots_dir = String(a).substr(12)
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	await super.run(m)


# the parts of the flow past the farm tutorial are not part of this log
func _second_relic(_home) -> void:
	pass


func _first_expedition(_home) -> void:
	pass


func _skip_paths() -> void:
	print(GAP_LOG + " " + str(gaps))
	print("FRESH HIDDEN MARKER seconds: " + str(hidden))
	print("FRESH WALLS: " + str(walls))
	_end()


func _shot(what: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	shot_n += 1
	var file := "%02d_%s.png" % [shot_n, what.replace(" ", "_")]
	main.get_viewport().get_texture().get_image().save_png(shots_dir.path_join(file))


func _fresh_log(where: String, sec: int, prompt: String, marker: String, idle: float) -> void:
	var shown := prompt.replace("\n", " / ")
	if shown.length() > SHOW_CHARS:
		shown = "%s... (%d chars)" % [shown.substr(0, SHOW_CHARS), shown.length()]
	print("FRESH %s | %3ds | prompt: %s | marker: %s | idle %.0fs" % [where, sec, shown, marker, idle])
	if prompt.length() > WALL_CHARS:
		walls[where] = prompt.length()


## The screen's own words: every visible label and button, joined.
func _screen_text(root: Node) -> String:
	var parts: Array = []
	for c in root.find_children("*", "Control", true, false):
		if c is Label and (c as Label).is_visible_in_tree() and (c as Label).text.strip_edges() != "":
			parts.append((c as Label).text.strip_edges())
		elif c is Button and (c as Button).is_visible_in_tree() and (c as Button).text.strip_edges() != "":
			parts.append("[%s]" % (c as Button).text)
	return " ".join(parts)


## A screen before the player acts: HOLD_S seconds of looking, a line each second.
func _before_act(what: String) -> void:
	var screen := "?"
	if is_instance_valid(main.current):
		screen = main.current.get_script().resource_path.get_file()
	var where := "%s/%s" % [screen, what]
	await _shot(what)
	var silent := 0.0
	var worst := 0.0
	for s in int(HOLD_S):
		var txt := _screen_text(main.current) if is_instance_valid(main.current) else ""
		silent = 0.0 if txt != "" else silent + 1.0
		worst = maxf(worst, silent)
		_fresh_log(where, s, txt, "n/a (a screen)", float(s))
		await tree.create_timer(1.0).timeout
	if worst >= GAP_S:
		gaps.append("%s: %.0f s with no text" % [where, worst])


## One sim second of the tutorial match: the step's line, the marker and the edge arrow.
func _sim_tick(m: Match, t: float) -> void:
	var tu: Tutorial = m.tut
	if tu.step < 0 or tu.step >= Tutorial.steps().size():
		return
	var key := "%d" % tu.step
	if key != _last_step:
		_last_step = key
		await _shot("match " + tu.id())
	if int(t / Match.DT) % int(1.0 / Match.DT) != 0:
		return
	var sz := m.get_viewport().get_visible_rect().size
	var has_place := tu.goal(tu.id()) != Vector3.INF
	var arrow := Vector2.ZERO
	if tu.target != Vector3.INF and m.cam != null:
		arrow = MarkerDir.off_dir(m.cam, sz, tu.target, m.player.pos)
	var marker := "none (no place)"
	if has_place:
		marker = "hidden"
		if tu.target != Vector3.INF and tu.beams_on() > 0:
			marker = "arrow" if arrow != Vector2.ZERO else "pin"
		else:
			hidden.append("%s@%.0f" % [tu.id(), t])
	var line := tu.text + ((" / " + tu.detail) if tu.detail != "" else "")
	if tu.text == "" or tu.stall_t >= GAP_S and tu.nag_t <= 0.0:
		gaps.append("match %s at %.0f s: no text or %.0f s stalled with no nag" % [tu.id(), t, tu.stall_t])
	_fresh_log("match/" + tu.id(), int(tu.t), line, marker, tu.stall_t)


## A farm step before it is done: HOLD_S s of looking at the hint line and the world marker.
func _farm_step(home, id: String) -> void:
	var g: FarmGuide = home.guide
	g.refresh()
	var cam: Camera3D = home.cam
	var place := FarmTutorial.world_text(id) != ""
	await _shot("farm " + id)
	var silent := 0.0
	for s in int(HOLD_S):
		for i in 10:
			g.tick(0.1)
		var txt: String = g.hint_lbl.text if g.hint_visible() else ""
		silent = 0.0 if txt != "" else silent + 1.0
		var marker := "none (no place)"
		if place:
			var up: bool = is_instance_valid(g.marker) and g.marker.visible
			var at := g.marker.global_position if up else Vector3.ZERO
			var view := Rect2(Vector2.ZERO, home.get_viewport().get_visible_rect().size)
			var on: bool = up and not cam.is_position_behind(at) and view.has_point(cam.unproject_position(at))
			marker = "pin" if on else "hidden or OFF SCREEN (the farm has no edge arrow)"
			if marker != "pin":
				hidden.append("farm %s@%d: %s" % [id, s, marker])
		_fresh_log("farm/" + id, s, txt, marker, float(s))
		await tree.create_timer(1.0).timeout
	if silent >= GAP_S:
		gaps.append("farm %s: %.0f s with no hint" % [id, silent])
