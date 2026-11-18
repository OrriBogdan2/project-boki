extends RefCounted
## --bus-sliders-check: Settings > Audio has one volume slider per audio bus (Settings.BUSES).
##   1. every bus exists, and the sounds with a bus of their own are routed to it
##   2. moving each slider sets its bus volume (gain = slider squared, Sfx.slider_db); letting go plays
##      the sample through that bus
##   3. the volumes survive a save and a load
##   4. an older settings file (linear volumes, no Voices or UI volume) loads with every level sounding the same,
##      Voices and UI starting where Effects was
## Prints BUSSLIDERS lines and "BUSSLIDERS DONE, failures: N". Puts the settings file back afterwards.

var main: Node
var fails := 0


func ok(what: String, cond: bool, info := "") -> void:
	print("BUSSLIDERS %-62s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	main = main_node
	var keep := ConfigFile.new()
	var had := keep.load(Settings.PATH) == OK
	_buses()
	await _sliders()
	_save_load()
	_old_file()
	if had:
		keep.save(Settings.PATH)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	Settings.load_file()
	print("BUSSLIDERS DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)


## The bus's gain as a slider position: a slider at s sounds as s squared, so this is the square root.
func _bus_slider(key: String) -> float:
	return sqrt(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Settings.BUSES[key]))))


func _buses() -> void:
	for key in Settings.BUSES:
		ok(
			"bus %s exists, setting '%s' has a default" % [Settings.BUSES[key], key],
			AudioServer.get_bus_index(Settings.BUSES[key]) >= 0 and Settings.DEFAULTS.has(key)
		)
	var far := Sfx.listener + Vector3(30, 0, 0)
	# routing is SfxMix's (a far sound goes through SFXFar first; the Boki's cries have their own Boki bus)
	var cases := [
		["v_brute", null, "Voice"],
		["v_brute", far, "SFXFar"],
		["archer_hurt", Vector3.ZERO, "Voice"],
		["kin_alert", null, "Boki"],
		["click", null, "UI"],
		["thump", Vector3.ZERO, "SFX"],
		["smg", far, "SFXFar"],
		["smg", null, "SFX"]
	]
	for c in cases:
		var got := String(Sfx._bus_for(c[1], c[0]))
		ok("%s %s plays on %s" % [c[0], "at a spot" if c[1] != null else "(no spot)", c[2]], got == c[2], got)


func _sliders() -> void:
	Overlay.ctx = "title"
	Overlay.tab = "Audio"
	Overlay.open_settings()
	await main.get_tree().process_frame
	var sliders := _find_sliders(Overlay.root)
	var keys: Array = Settings.BUSES.keys()
	ok("Settings > Audio has one slider per bus", sliders.size() == keys.size(), "%d sliders" % sliders.size())
	for i in mini(sliders.size(), keys.size()):
		var sl: HSlider = sliders[i]
		var key: String = keys[i]
		var want := 0.25 + 0.1 * i
		sl.value = want
		ok(
			"'%s' slider sets bus %s" % [key, Settings.BUSES[key]],
			is_equal_approx(_bus_slider(key), want) and is_equal_approx(float(Settings.get_v(key)), want),
			"%.3f" % _bus_slider(key)
		)
		sl.drag_ended.emit(true)
		var heard := Sfx.players.any(func(p: AudioStreamPlayer): return p.playing and p.bus == Settings.BUSES[key])
		ok("...and letting go plays the sample on %s" % Settings.BUSES[key], heard)
	Overlay.close()


func _find_sliders(n: Node) -> Array:
	var out: Array = []
	if n is HSlider:
		out.append(n)
	for c in n.get_children():
		out += _find_sliders(c)
	return out


func _save_load() -> void:
	var keys: Array = Settings.BUSES.keys()
	for i in keys.size():
		Settings.set_v(keys[i], 0.15 + 0.12 * i)
	Settings.load_file()
	for i in keys.size():
		var key: String = keys[i]
		var want := 0.15 + 0.12 * i
		Settings.apply(key)
		ok(
			"'%s' survives a save and a load" % key,
			is_equal_approx(float(Settings.get_v(key)), want) and is_equal_approx(_bus_slider(key), want),
			"%.3f" % float(Settings.get_v(key))
		)


func _old_file() -> void:
	var cf := ConfigFile.new()
	for pair in [["master", 0.6], ["music", 0.5], ["sfx", 0.4], ["ambience", 0.3], ["keys_v", Settings.KEYS_V]]:
		cf.set_value("s", pair[0], pair[1])
	cf.save(Settings.PATH)
	Settings.load_file()
	var got := [Settings.get_v("master"), Settings.get_v("music"), Settings.get_v("ambience")]
	var want := [sqrt(0.6), sqrt(0.5), sqrt(0.3)]  # audio_v 2 moves a linear level to the slider that sounds the same
	ok("an older settings file keeps its volumes (same loudness)", _all_close(got, want), str(got))
	var voices := float(Settings.get_v("voices"))
	var ui := float(Settings.get_v("ui_sounds"))
	var effects := sqrt(0.4)
	var both := is_equal_approx(voices, effects) and is_equal_approx(ui, effects)
	ok("...and Voices and UI start where Effects was", both)
	ok("...the master bus plays at the old gain", is_equal_approx(db_to_linear(Sfx.slider_db(got[0])), 0.6))


func _all_close(a: Array, b: Array) -> bool:
	for i in a.size():
		if not is_equal_approx(float(a[i]), float(b[i])):
			return false
	return true
