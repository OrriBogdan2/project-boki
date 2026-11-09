extends RefCounted
## --onboarding-flow-shots --shots-dir=<dir>: a fresh player's first ten minutes on the real screens (needs a
## renderer, run through jobq --needs gpu): title, prologue, the hatch, the tutorial match, the results,
## the first farm visit and the first expedition's lobby and drop. A shot every few seconds with the
## screen and step in its name, and one FLOW line per shot. Never touches the real save.

const EVERY_UI := 3.0        # s between shots on a menu or cutscene
const EVERY_MATCH := 8.0     # s of match time between shots
const FARM_S := 20.0         # s on the first farm visit before heading out
const DROP_S := 25.0         # s of the first expedition's match to watch
const LIMIT_S := 900.0       # wall-clock guard

var main: Node
var dir := "/tmp/onboarding_flow"
var screen := ""             # the last screen Game moved to
var n := 0
var clock := 0.0             # s on this screen (match time while the match is stepped by hand)
var last_shot := -99.0
var beat := 0.0              # s since the player's last move

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Game.screen_changed.connect(func(s: String): _enter(s))
	Game.goto("title")
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < LIMIT_S and not _watched_the_drop():
		await _tick()
	print("FLOW %d shots in %s, ended on %s" % [n, dir, screen])
	main.get_tree().quit(0)

func _enter(s: String) -> void:
	screen = s
	clock = 0.0
	beat = 0.0
	last_shot = -99.0
	print("FLOW screen -> %s" % s)

func _watched_the_drop() -> bool:
	return screen == "match" and clock > DROP_S and main.current is Match and (main.current as Match).tut == null

## One frame: the player's next move on this screen, then a shot when it is time.
func _tick() -> void:
	var m := main.current as Match
	if m != null and m.player != null and screen == "match" and not (m.time == 0.0 and is_instance_valid(main._ld)):
		await _match_frame(m)
	else:
		clock += main.get_process_delta_time()
		beat += main.get_process_delta_time()
		await main.get_tree().process_frame
		_act()
	var every := EVERY_MATCH if screen == "match" else EVERY_UI
	if clock - last_shot >= every:
		last_shot = clock
		await _shot()

func _act() -> void:
	match screen:
		"title":
			if clock > 3.0:
				Game.goto("prologue")
		"hatch":
			_hatch()
		"results":
			if clock > 8.0:
				Game.goto("home")
		"home":
			if clock > 5.0 and beat > 5.0 and clock < FARM_S:
				_press(KEY_ENTER)      # the Welcome card's "Let's go"
				beat = 0.0
			elif clock > FARM_S:
				main.current._start_match()

## The hatch: the card, making yourself, the egg, the knocks, the reveal, the name, the Relic.
func _hatch() -> void:
	var h = main.current
	if h == null or not ("stage" in h) or beat < 3.0:
		return
	var stage := String(h.stage)
	var step := true
	match stage:
		"intro": h._end_intro()
		"create": h._looks_good()
		"pick":
			h._pick(0)
			h._pick(0)
			h.auto_warm = true
		"name": h._finish(String(h.egg_defs[h.chosen]["species"]), "", "", true)
		"reveal":
			for c in h.get_children():
				if c is KinReveal:
					c._go()
		"mask":
			for c in h.get_children():
				if c is MaskMoment:
					_press(KEY_ENTER)
		_: step = false
	if step:
		beat = 0.0      # (a beat on the new stage before the next move)

func _press(key: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		Input.parse_input_event(e)

## The match is stepped by hand (the tutorial's course by its driver) so a few minutes pass in a few seconds.
func _match_frame(m: Match) -> void:
	m.set_process(false)
	var tutorial := m.tut != null
	for i in 4:
		if tutorial and clock > 6.0:
			TutorialDrive.drive(m)
		for k in 2:
			m.step(Match.DT)
			clock += Match.DT
	m.cam.snap(m.player.pos)
	await main.get_tree().process_frame

func _shot() -> void:
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	n += 1
	var detail := _detail()
	var file := "%02d_%s%s.png" % [n, screen, detail]
	img.save_png(dir.path_join(file))
	print("FLOW shot %s t=%.1f" % [file, clock])

func _detail() -> String:
	var m := main.current as Match
	if screen == "match" and m != null and m.tut != null:
		return "_%s" % m.tut.id()
	if screen == "hatch" and main.current != null and "stage" in main.current:
		return "_%s" % String(main.current.stage)
	return ""
