extends RefCounted
## --ui-sfx-check: every slider, toggle and dropdown on the title, the settings tabs and the pause
## menu makes a sound (UiSfx), sliders tick throttled, and tab buttons carry the tab sound.
## It drives the real Settings widgets (Effects slider to 0, "Ultimate ready" off), and Settings writes each change
## to user://settings.cfg, so it runs itself again in a child game on a throwaway XDG_DATA_HOME: the player's (or a
## gate box's) settings file is never touched (rpc6, 11-16: sfx=0.0 and ult_ready_cue=false left behind).

var main: Node
var fails := 0
var n := 0

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	printerr("UISFX %-52s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

const CHILD := "--ui-sfx-child"

func run(main_node: Node) -> void:
	main = main_node
	if not Array(OS.get_cmdline_user_args()).has(CHILD):
		main.get_tree().quit(await _in_temp_user_dir())
		return
	Game.goto("title")
	for i in 10:
		await main.get_tree().process_frame
	Overlay.ctx = "title"
	for t in Overlay.SETTINGS_TABS:
		Overlay.tab = t
		Overlay.open_settings()
		await main.get_tree().process_frame
		_walk("settings > %s" % t, Overlay.root)
	Overlay.close()
	Overlay.open_pause("home")
	await main.get_tree().process_frame
	_walk("pause", Overlay.root)
	Overlay.close()
	_tabs_and_throttle()
	print("UISFX DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Runs this same check again as a child game with its own user dir (CheckChild), shows its output, and returns
## its exit code. The child ends with this game, however it ends.
func _in_temp_user_dir() -> int:
	var log_path := "/tmp/ui_sfx_check_%d.log" % OS.get_process_id()
	var pid := CheckChild.start("--ui-sfx-check %s" % CHILD, log_path)
	while OS.is_process_running(pid):
		await main.get_tree().create_timer(0.5).timeout
	printerr(FileAccess.get_file_as_string(log_path).strip_edges())
	var rc := OS.get_process_exit_code(pid)
	OS.execute("/bin/rm", ["-rf", log_path, log_path.get_basename() + "_data"])
	return rc

func _heard(trigger: Callable) -> bool:
	Sfx.last_played.clear()
	Sfx.recent.clear()
	trigger.call()
	return not Sfx.last_played.is_empty()

func _walk(where: String, root: Node) -> void:
	for c in root.find_children("*", "Control", true, false):
		if c is Slider:
			var s: Slider = c
			var before := s.value
			var to := s.max_value if before < s.max_value else s.min_value
			ok("%s: slider ticks" % where, _heard(func(): s.value = to))
			s.set_value_no_signal(before)
		elif c is CheckButton:
			var cb: CheckButton = c
			var was := cb.button_pressed
			ok("%s: toggle sounds" % where, _heard(func(): cb.button_pressed = not was))
			cb.set_pressed_no_signal(was)
		elif c is OptionButton:
			var ob: OptionButton = c
			var pick := func(): ob.item_selected.emit(0)
			ok("%s: dropdown sounds" % where, ob.item_count == 0 or _heard(pick))

func _tabs_and_throttle() -> void:
	var t := UI.tabs(["A", "B"], "A", func(_n): pass)
	main.add_child(t)
	var tab_btns := t.find_children("*", "Button", true, false)
	var tab_snd := func(b: Node) -> bool: return b.get_meta("snd") == "ui_tab"
	ok("tab buttons carry the tab sound", tab_btns.size() == 2 and tab_btns.all(tab_snd))
	var s := HSlider.new()
	s.step = 0.01
	main.add_child(s)
	Sfx.last_played.clear()
	Sfx.recent.clear()
	for i in 20:
		s.value = i * 0.05
	var ticks: int = Sfx.recent.get("hover", []).size()
	ok("slider ticks are throttled", ticks == 1, str(ticks))
	t.queue_free()
	s.queue_free()
