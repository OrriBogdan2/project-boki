extends RefCounted
## --keybind-check: two keys per action (Settings > Controls). Merge ships on X, the hunter ultimate on R, and there is no reload key; a
## second key can be set, cleared and saved; a key already in use is caught and can be swapped;
## nothing else is on X in a match (the arena/duel reset is Backspace, separating from the drop is
## Z); glove 2 and play share V on purpose (a match key and a home key). With --shots-dir=<dir>, screenshots of
## the Controls page and of the clash warning.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("KEYS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _key(k: int) -> InputEventKey:
	var e := InputEventKey.new(); e.physical_keycode = k; e.pressed = true
	return e

func run(main: Node) -> void:
	var tree := main.get_tree()
	var S = Settings
	S.reset_all()
	ok(S.slots("ultimate") == ["key:%d" % KEY_X, ""], "Merge ships on X (%s, prompt '%s')" % [str(S.slots("ultimate")), S.key_caps("ultimate")])
	ok(S.slots("separate")[0] == "key:%d" % KEY_Z, "separating from the drop moved to Z")
	var xs: Array = S.conflicts(_key(KEY_X), "ultimate")
	ok(xs.is_empty(), "nothing else rebindable is on X (%s)" % str(xs))
	# a second key: set, saved, cleared
	S.rebind("util1", _key(KEY_KP_1), 1)
	ok(S.slots("util1") == ["key:%d" % KEY_1, "key:%d" % KEY_KP_1] and InputMap.action_get_events("util1").size() == 2,
			"a second key for utility slot 1 works (%s)" % S.binding_text("util1"))
	ok((S.v["keys"]["util1"] as Array).size() == 2, "and is saved")
	S.clear_bind("util1", 1)
	ok(S.slots("util1") == ["key:%d" % KEY_1, ""], "and clears")
	S.clear_bind("util1", 0)
	ok(S.slots("util1") == ["", ""] and S.binding_text("util1") == "unbound", "clearing the main key leaves it unbound")
	var mb := InputEventMouseButton.new(); mb.button_index = MOUSE_BUTTON_XBUTTON1; mb.pressed = true
	S.rebind("util1", mb, 1)
	ok(S.slots("util1") == ["", "mouse:%d" % MOUSE_BUTTON_XBUTTON1],
			"a mouse button works as a second key (%s)" % S.binding_text("util1"))
	S.reset_all()
	# V: glove 2 in a match, play fetch at home. Different places, so they share it on purpose
	ok(S.slots("gear2")[0] == "key:%d" % KEY_V and S.slots("play")[0] == "key:%d" % KEY_V,
			"glove 2 ships on V, and V still plays fetch at home")
	var vg: Array = S.conflicts(_key(KEY_V), "gear2")
	var vp: Array = S.conflicts(_key(KEY_V), "play")
	ok(vg.is_empty() and vp.is_empty(),
			"glove 2 (match) and play (home) are separate contexts: no clash between them (%s %s)" % [str(vg), str(vp)])
	var vd: Array = S.conflicts(_key(KEY_V), "dash")
	ok(vd.any(func(x): return x[0] == "gear2") and vd.any(func(x): return x[0] == "play"), "giving another action V still warns about both (%s)" % str(vd))
	# clashes: F is interact's
	var cf: Array = S.conflicts(_key(KEY_F), "ultimate")
	ok(cf.size() == 1 and cf[0][0] == "interact", "giving the ultimate F is caught: it's Interact's (%s)" % str(cf))
	S.swap_bind("ultimate", 0, _key(KEY_F), "interact", 0)
	ok(S.slots("ultimate")[0] == "key:%d" % KEY_F and S.slots("interact")[0] == "key:%d" % KEY_X, "swapping gives Interact the ultimate's old key (ult %s, interact %s)" % [S.binding_text("ultimate"), S.binding_text("interact")])
	S.reset_all()
	# (the move of old saves to the new defaults is --ultbond-check)
	# the arena and duel resets are on Backspace now
	var ar := FileAccess.get_file_as_string("res://scripts/match/arena.gd")
	var du := FileAccess.get_file_as_string("res://scripts/match/duel.gd")
	ok(not ar.contains("KEY_X:") and ar.contains("KEY_BACKSPACE:") and not du.contains("KEY_X") and du.contains("KEY_BACKSPACE"), "the arena and duel resets moved to Backspace")
	# the Controls page, and the clash warning
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shot = a.substr(12)
	Overlay.tab = "Controls"
	Overlay.open_settings()
	for i in 20: await tree.process_frame
	if shot != "":
		tree.root.get_texture().get_image().save_png(shot + "/keybinds_controls.png")
	Overlay.listening = "ultimate"; Overlay.listening_slot = 0
	Overlay._finish_rebind(_key(KEY_F))
	for i in 20: await tree.process_frame
	ok(Overlay.has_meta("bind_conflict") and is_instance_valid(Overlay.get_meta("bind_conflict")), "the binding page warns about the clash and offers a swap")
	if shot != "":
		tree.root.get_texture().get_image().save_png(shot + "/keybinds_conflict.png")
	S.reset_all()
	print("KEYS DONE, failures: %d" % bad)
	tree.quit()
