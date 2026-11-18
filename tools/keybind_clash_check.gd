extends RefCounted
## The clash cases of --keybind-check: defaults never clash, a clash is found and swapped, "Keep both"
## is only for actions that never run in the same place (garden vs match), and an old save with two
## actions on one key keeps both and shows them as a clash.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("KEYS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _key(k: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	return e


func _clashing(S, action: String, slot: int) -> bool:
	var code: String = S.slots(action)[slot]
	return S.holders(code, action).any(func(h): return not S.can_share(h[0], action))


func _keep_both_buttons() -> Array:
	var layer: Control = Overlay.get_meta("bind_conflict")
	return layer.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text == "Keep both")


## The rules, no UI: returns the number of failed cases.
func rules(S) -> int:
	var clean := true
	for a in S.ACTIONS:
		for i in 2:
			if _clashing(S, a[0], i):
				clean = false
				print("KEYS default clash: ", a[0], " ", i)
	ok(clean, "the shipped defaults have no clash")
	ok(
		S.can_share("play", "gear2") and not S.can_share("dash", "play") and not S.can_share("fire", "gear2"),
		"only a home action and a match action may share a key"
	)
	var f := _key(KEY_F)
	var cx: Array = S.conflicts(f, "jump")
	ok(cx.size() == 1 and cx[0][0] == "interact", "binding jump to F clashes with Interact (%s)" % str(cx))
	var vu: Array = S.conflicts(_key(KEY_V), "ultimate")
	var vnames: Array = vu.map(func(h): return h[0])
	var v_held: int = S.holders("key:%d" % KEY_V, "ultimate").size()
	ok(
		vu.size() == 2 and vnames.has("gear2") and vnames.has("push_to_talk") and v_held == 3,
		"V for fuse clashes with glove 2 and push to talk, not with play (home) (%s)" % str(vu)
	)
	var jump0: String = S.slots("jump")[0]
	S.swap_bind("jump", 0, f, cx)
	var swapped: bool = S.slots("jump")[0] == "key:%d" % KEY_F and S.slots("interact")[0] == jump0
	ok(
		swapped and not _clashing(S, "jump", 0) and not _clashing(S, "interact", 0),
		"Swap leaves both rows clear (jump %s, interact %s)" % [S.binding_text("jump"), S.binding_text("interact")]
	)
	S.reset_all()
	# an old save: dash on F next to Interact on F, from before clashes were shown
	S.v["keys"] = {"dash": ["key:%d" % KEY_F]}
	S.v["keys4_v"] = 1
	S.v["keys5_v"] = 1
	KeyMigrate.run(S.v)
	S.apply("keys")
	ok(
		S.slots("dash")[0] == "key:%d" % KEY_F and S.slots("interact")[0] == "key:%d" % KEY_F,
		"the old save keeps both bindings (%s, %s)" % [S.binding_text("dash"), S.binding_text("interact")]
	)
	ok(_clashing(S, "dash", 0) and _clashing(S, "interact", 0), "and both rows count as a clash")
	S.reset_all()
	return bad


## The Controls page: both rows red with Swap, and Keep both only across places.
func page(tree: SceneTree, S) -> int:
	Overlay.listening = "ultimate"
	Overlay.listening_slot = 0
	Overlay._finish_rebind(_key(KEY_F))
	for i in 5:
		await tree.process_frame
	ok(
		Overlay.bind_hot.size() == 2 and Overlay.bind_hot.any(func(h): return h[0] == "interact"),
		"both rows are marked while the clash waits (%s)" % str(Overlay.bind_hot)
	)
	ok(_keep_both_buttons().is_empty(), "two actions of the same place get no 'Keep both'")
	(Overlay.get_meta("bind_conflict") as Control).queue_free()
	await tree.process_frame
	var talk_ev := _key(int(String(S.slots("talk")[0]).substr(4)))
	Overlay.listening = "emote"
	Overlay.listening_slot = 0
	Overlay._finish_rebind(talk_ev)
	for i in 5:
		await tree.process_frame
	var kb := _keep_both_buttons()
	ok(kb.size() == 1, "an action in another place gets 'Keep both'")
	if kb.size() == 1:
		(kb[0] as Button).pressed.emit()
	for i in 5:
		await tree.process_frame
	ok(
		S.slots("emote")[0] == S.slots("talk")[0] and not _clashing(S, "emote", 0),
		"keeping both leaves the key on both, no clash (%s)" % S.binding_text("emote")
	)
	S.reset_all()
	return bad
