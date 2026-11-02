extends RefCounted
## --keybind-check: two keys per action (Settings > Controls). The ultimate ships on R and X; a
## second key can be set, cleared and saved; a key already in use is caught and can be swapped;
## old custom bindings get X as the ultimate's second key; nothing else is on X in a match (the
## arena/duel reset is Backspace, separating from the drop is Z). With --shots-dir=<dir>, screenshots of
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
	ok(S.slots("ultimate") == ["key:%d" % KEY_R, "key:%d" % KEY_X], "the ultimate ships on R and X (%s, prompt '%s')" % [str(S.slots("ultimate")), S.key_caps("ultimate")])
	ok(S.slots("separate")[0] == "key:%d" % KEY_Z, "separating from the drop moved to Z")
	var xs: Array = S.conflicts(_key(KEY_X), "ultimate")
	ok(xs.is_empty(), "nothing else rebindable is on X (%s)" % str(xs))
	# a second key: set, saved, cleared
	S.rebind("tonic", _key(KEY_KP_1), 1)
	ok(S.slots("tonic") == ["key:%d" % KEY_1, "key:%d" % KEY_KP_1] and InputMap.action_get_events("tonic").size() == 2, "a second key for Heal works (%s)" % S.binding_text("tonic"))
	ok((S.v["keys"]["tonic"] as Array).size() == 2, "and is saved")
	S.clear_bind("tonic", 1)
	ok(S.slots("tonic") == ["key:%d" % KEY_1, ""], "and clears")
	S.clear_bind("tonic", 0)
	ok(S.slots("tonic") == ["", ""] and S.binding_text("tonic") == "unbound", "clearing the main key leaves it unbound")
	var mb := InputEventMouseButton.new(); mb.button_index = MOUSE_BUTTON_XBUTTON1; mb.pressed = true
	S.rebind("tonic", mb, 1)
	ok(S.slots("tonic") == ["", "mouse:%d" % MOUSE_BUTTON_XBUTTON1], "a mouse button works as a second key (%s)" % S.binding_text("tonic"))
	S.reset_all()
	# clashes: F is interact's
	var cf: Array = S.conflicts(_key(KEY_F), "ultimate")
	ok(cf.size() == 1 and cf[0][0] == "interact", "giving the ultimate F is caught: it's Interact's (%s)" % str(cf))
	S.swap_bind("ultimate", 1, _key(KEY_F), "interact", 0)
	ok(S.slots("ultimate")[1] == "key:%d" % KEY_F and S.slots("interact")[0] == "key:%d" % KEY_X, "swapping gives Interact the ultimate's old key (ult %s, interact %s)" % [S.binding_text("ultimate"), S.binding_text("interact")])
	S.reset_all()
	# the migration for someone with their own bindings (keys2_v 0)
	S.v["keys"] = {"ultimate": ["key:%d" % KEY_R], "separate": ["key:%d" % KEY_X], "dash": ["key:%d" % KEY_SPACE]}
	S.v["keys2_v"] = 0
	S._migrate_keys2()
	ok(S.v["keys"]["ultimate"] == ["key:%d" % KEY_R, "key:%d" % KEY_X] and S.v["keys"]["separate"] == ["key:%d" % KEY_Z], "old custom bindings: X added as the ultimate's second key, separate moved to Z (%s)" % str(S.v["keys"]))
	S.v["keys"] = {"ultimate": ["key:%d" % KEY_R, "key:%d" % KEY_T]}
	S.v["keys2_v"] = 0
	S._migrate_keys2()
	ok(S.v["keys"]["ultimate"] == ["key:%d" % KEY_R, "key:%d" % KEY_T], "a second key someone already chose is kept")
	S.v["keys"] = {"dash": ["key:%d" % KEY_X]}
	S.v["keys2_v"] = 0
	S._migrate_keys2()
	ok(S.v["keys"]["ultimate"] == ["key:%d" % KEY_R] and S.v["keys"]["dash"] == ["key:%d" % KEY_X], "X used by another action and no saved ultimate: the ultimate is pinned to R so X fires only the other action (%s)" % str(S.v["keys"]))
	S.reset_all()
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
	Overlay.listening = "ultimate"; Overlay.listening_slot = 1
	Overlay._finish_rebind(_key(KEY_F))
	for i in 20: await tree.process_frame
	ok(Overlay.has_meta("bind_conflict") and is_instance_valid(Overlay.get_meta("bind_conflict")), "the binding page warns about the clash and offers a swap")
	if shot != "":
		tree.root.get_texture().get_image().save_png(shot + "/keybinds_conflict.png")
	S.reset_all()
	print("KEYS DONE, failures: %d" % bad)
	tree.quit()
