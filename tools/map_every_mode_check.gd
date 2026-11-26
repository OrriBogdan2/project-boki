extends RefCounted
## --map-every-mode-check: M opens the full map in every mode with a world (Training Grounds, Test Zone, the duel
## room, a 3-team expedition) and M or Esc closes it; the tutorials keep it shut. A real M key event goes
## through the viewport; the map is drawn a few frames. Grep the output for SCRIPT ERROR as well. Never writes a save.
## --map-every-mode-shots --shots-dir=<dir> (GPU): the map open in the Training Grounds and the Test Zone, as PNGs.

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("MAPMODES %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(mn: Node, shots := false) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	if shots:
		await _shots()
		return
	var modes := {
		"Training Grounds": Match.arena_opts(),
		"Test Zone": TestZone.opts(),
		"duel room": Match.duel_opts(),
		"expedition": {"teams": 3, "squad": 3, "tier": 0, "seed": 3},
	}
	for tag in modes:
		await _mode(tag, modes[tag], true)
	await _mode("tutorial", TutorialResume.opts(), false)
	print("MAPMODES DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _mode(tag: String, o: Dictionary, allowed: bool) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)
	while m.hud == null or m.hud.full_map == null:
		await main.get_tree().process_frame
	await main.get_tree().process_frame
	m.hud.close_map()  # (an expedition starts with the plan map open)
	await _key(KEY_M)
	ok(m.hud.map_open() == allowed, "%s: M %s the map" % [tag, "opens" if allowed else "leaves shut"])
	if allowed:
		for i in 3:
			await main.get_tree().process_frame
		ok(m.hud.full_map.rect.size.x > 0.0, "%s: the map was drawn" % tag)
		if m.arena:
			ok(not m.arena.layer.visible, "%s: the practice keys and meter step aside" % tag)
			ok(not PracticeMap.rows(m).is_empty(), "%s: the legend lists the practice tools" % tag)
		await _key(KEY_M)
		ok(not m.hud.map_open(), "%s: M again closes it" % tag)
		if m.arena:
			ok(m.arena.layer.visible, "%s: the practice keys and meter are back" % tag)
		await _key(KEY_M)
		await _key(KEY_ESCAPE)
		ok(not m.hud.map_open(), "%s: Esc closes it" % tag)
	m.queue_free()
	await main.get_tree().process_frame


func _key(code: Key) -> void:
	await main.get_tree().process_frame
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await main.get_tree().process_frame


func _shots() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for tag in {"training": Match.arena_opts(), "test_zone": TestZone.opts()}:
		var m := Match.new()
		main.add_child(m)
		m.start({"training": Match.arena_opts(), "test_zone": TestZone.opts()}[tag])
		while m.hud == null or m.hud.full_map == null:
			await main.get_tree().process_frame
		var fade = main.get("fade")
		if fade != null:
			await fade.reveal(0.01)
		m.set_process(false)
		for i in 30:
			m.step(Match.DT)
			m.cam.snap(m.player.pos)
			await main.get_tree().process_frame
		await _key(KEY_M)
		for i in 10:
			await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("map_%s.png" % tag))
		m.queue_free()
		await main.get_tree().process_frame
	print("MAPMODES shots in ", dir)
	main.get_tree().quit(0)
