extends RefCounted
## --audio-settings-check: Settings > Audio sliders change what is heard. Each of Master, Music, Sound effects
## and Ambience is set through Settings.set_v and the matching bus's volume_db is asserted: at the title
## screen, in a match and on the farm once they have loaded (and after their music/ambience have started).
## Also: a saved settings.cfg is applied at boot (a child game process is started on the same user dir and
## reports the bus volumes it ends up with), and an unfocused window is muted only when asked to.

const BUSES := {"master": "Master", "music": "Music", "sfx": "SFX", "ambience": "Ambience"}
const PROBE := "--audio-boot-probe"
const SAVED := {"master": 0.3, "music": 0.4, "sfx": 0.5, "ambience": 0.6}
const TOL := 0.05      # dB

var main: Node
var fails := 0
var n := 0

func ok(cond: bool, what: String) -> void:
	n += 1
	printerr("AUDIOSET %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	if Array(OS.get_cmdline_user_args()).has(PROBE):
		_probe()
		return
	await _sliders("title")
	for screen in ["match", "home"]:
		Save.d["music"] = Save.d.get("music", [])
		var opts := {}
		if screen == "match":
			opts = {"autoplay": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true}
		Game.goto(screen, opts)
		for i in 30:
			await main.get_tree().process_frame
		await _sliders(screen)
		await _stays(screen)
	Settings.set_v("master", 1.0)
	Settings.set_v("mute_unfocused", false)
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	Settings.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(not AudioServer.is_bus_mute(0), "unfocused: the window stays audible when 'mute when unfocused' is off")
	_boot_with_saved_cfg()
	print("AUDIOSET %d checks, %d failed" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _db(bus: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))

func _sliders(where: String) -> void:
	for key in BUSES:
		for lin in [0.25, 1.0, 0.5]:
			Settings.set_v(key, lin, false)
			var want := linear_to_db(lin)
			var got := _db(BUSES[key])
			var what := "%s: %s slider %.2f -> %s bus" % [where, key, lin, BUSES[key]]
			ok(absf(got - want) < TOL, "%s %.1f dB (want %.1f)" % [what, got, want])
	# the same through the Settings > Audio page's own sliders (the order they are listed in)
	Overlay.tab = "Audio"
	Overlay.open_settings()
	var sliders := Overlay.find_children("*", "HSlider", true, false)
	ok(sliders.size() >= 4, "%s: the Audio page has its volume sliders (%d)" % [where, sliders.size()])
	for i in mini(4, sliders.size()):
		var key: String = BUSES.keys()[i]
		(sliders[i] as HSlider).value = 0.35
		var moved := absf(_db(BUSES[key]) - linear_to_db(0.35)) < TOL
		ok(moved, "%s: dragging the %s slider moves the %s bus (%.1f dB)" % [where, key, BUSES[key], _db(BUSES[key])])
	await _mouse_drag(where, sliders)
	Overlay.close()
	# every other bus still sends where it should (Music/SFX/Ambience -> Master), so a slider reaches the speakers
	for b in ["Music", "SFX", "Ambience"]:
		var send := AudioServer.get_bus_send(AudioServer.get_bus_index(b))
		ok(send == &"Master", "%s: %s bus sends to Master" % [where, b])

## Nothing writes a bus back later: with the screen running for a few seconds (music and ambience fading in)
## the levels the sliders set are still the ones on the buses.
func _stays(where: String) -> void:
	for key in BUSES:
		Settings.set_v(key, 0.2, false)
	await main.get_tree().create_timer(3.0).timeout
	for key in BUSES:
		var still := absf(_db(BUSES[key]) - linear_to_db(0.2)) < TOL
		ok(still, "%s: after a few seconds %s is still at %.1f dB" % [where, BUSES[key], _db(BUSES[key])])

## A real mouse press on the Music slider's track (not a script write), as a player does it.
func _mouse_drag(where: String, sliders: Array) -> void:
	if sliders.size() < 2:
		return
	var sl: HSlider = sliders[1]
	Settings.set_v("music", 1.0, false)
	sl.value = 1.0
	await main.get_tree().process_frame
	var vp := sl.get_viewport()
	for fade in main.find_children("*", "ColorRect", true, false):      # (the boot fade takes clicks in a real window)
		(fade as ColorRect).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var in_canvas := sl.get_global_transform_with_canvas() * Vector2(sl.size.x * 0.1, sl.size.y * 0.5)
	var pos := vp.get_final_transform() * in_canvas
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	vp.push_input(mv)
	await main.get_tree().process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await main.get_tree().process_frame
	var what := "%s: a mouse click near the left of the Music slider turns the Music bus down" % where
	ok(_db("Music") < -12.0, "%s (%.1f dB)" % [what, _db("Music")])

## A saved settings.cfg is what the game boots with: write one, start the game again on the same user dir.
func _boot_with_saved_cfg() -> void:
	var cf := ConfigFile.new()
	for k in SAVED:
		cf.set_value("s", k, SAVED[k])
	cf.save(Settings.PATH)
	var out := []
	var args := ["--headless", "--", "--audio-settings-check", PROBE]
	if OS.has_feature("editor"):
		args = ["--path", ProjectSettings.globalize_path("res://")] + args
	var code := OS.execute(OS.get_executable_path(), args, out, true)
	var text := "".join(out)
	ok(code == 0, "boot probe ran (exit %d)" % code)
	for key in BUSES:
		var want := linear_to_db(SAVED[key])
		var got := _parse(text, BUSES[key])
		var what := "saved cfg: %s=%.1f boots with %s bus" % [key, SAVED[key], BUSES[key]]
		ok(absf(got - want) < TOL, "%s %.1f dB (want %.1f)" % [what, got, want])

func _parse(text: String, bus: String) -> float:
	for line in text.split("\n"):
		if line.begins_with("AUDIOBOOT %s " % bus):
			return float(line.split(" ")[2])
	return 999.0

func _probe() -> void:
	for f in 20:
		await main.get_tree().process_frame
	for b in BUSES.values():
		print("AUDIOBOOT %s %.3f" % [b, _db(b)])
	main.get_tree().quit()
