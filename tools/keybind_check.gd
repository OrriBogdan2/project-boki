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

const RX := "(?:is_action_(?:just_)?(?:pressed|released)|get_action_strength|get_axis)\\(\"(\\w+)\"(?:, \"(\\w+)\")?"

## Every action name a script reads (is_action_*, get_axis).
func _used_actions(dir: String, out: Dictionary) -> void:
	var rx := RegEx.create_from_string(RX)
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		for m in rx.search_all(FileAccess.get_file_as_string(dir + "/" + f)):
			for g in [1, 2]:
				if m.get_string(g) != "":
					out[m.get_string(g)] = true
	for d in DirAccess.get_directories_at(dir):
		_used_actions(dir + "/" + d, out)

func _names() -> Array:
	return Settings.ACTIONS.map(func(a): return String(a[0]))

func _code(k: int) -> String:
	return "key:%d" % k

func _mouse(b: int) -> String:
	return "mouse:%d" % b

func _actions_and_orders(S) -> void:
	S.reset_all()
	var used := {}
	_used_actions("res://scripts", used)
	var tooling := func(n): return n.begins_with("kf_") or n.begins_with("ui_") or n == "menu"
	var missing: Array = used.keys().filter(func(n): return not tooling.call(n) and not _names().has(n))
	ok(missing.is_empty(), "every action the scripts read can be rebound in Controls (missing: %s)" % str(missing))
	ok(_names().has("crouch") and _names().has("whistle") and _names().has("rotate"), "sneak, whistle, rotate listed")
	ok(S.slots("ping") == [_mouse(MOUSE_BUTTON_MIDDLE), _mouse(MOUSE_BUTTON_XBUTTON1)], "Mouse 4 pings by default")
	ok(S.slots("dash") == [_code(KEY_SHIFT), _mouse(MOUSE_BUTTON_XBUTTON2)], "Mouse 5 is the second dash key")
	var orders: Array = [S.slots("kin_attack")[0], S.slots("kin_return")[0], S.slots("kin_hold")[0]]
	ok(orders == [_code(KEY_K), _code(KEY_N), _code(KEY_L)], "the Boki orders ship on K, N and L (%s)" % str(orders))
	var clash := _names().filter(func(n): return not S.clashes(n).is_empty())
	ok(clash.is_empty(), "no two actions share a default key (clashing: %s)" % str(clash))
	S.rebind("kin_attack", _key(KEY_G), 0)
	ok(S.clashes("kin_attack") == ["throw"] and S.clashes("throw") == ["kin_attack"], "a shared key flags both actions")
	S.rebind("signature", _key(KEY_U), 0)
	ok(S.key_cap("signature") == "U" and S.slots("signature")[0] == _code(KEY_U), "a key cap follows a rebind")
	S.reset_all()

## Old saves: custom bindings survive the new defaults, and a default that lands on a saved custom key backs off.
func _migration(S) -> void:
	var saved := {"fire": [_code(KEY_K)], "jump": [_mouse(MOUSE_BUTTON_XBUTTON2)]}
	saved["glide"] = [_code(KEY_O)]
	saved["util3"] = [_code(KEY_N)]
	var m := {"keys": saved, "keys2_v": 1, "keys3_v": 1, "keys4_v": 1, "keys5_v": 1}
	KeyMigrate.run(m)
	var ks: Dictionary = m["keys"]
	var kept: bool = ks["fire"] == [_code(KEY_K)] and ks["glide"] == [_code(KEY_O)]
	ok(m["keys6_v"] == 1 and kept, "migration keeps custom bindings")
	ok(ks["kin_attack"] == [] and ks["kin_return"] == [] and not ks.has("kin_hold"), "a taken order key starts unbound")
	ok(ks["dash"] == [_code(KEY_SHIFT)] and not ks.has("ping"), "dash backs off a taken Mouse 5, ping does not")
	var before := ks.duplicate(true)
	KeyMigrate.run(m)
	ok(m["keys"] == before, "and it runs once")
	ok(S.DEFAULTS.has("keys6_v"), "the settings carry the migration step")

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
	_actions_and_orders(S)
	_migration(S)
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
