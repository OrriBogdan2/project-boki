extends RefCounted
## --care-prompt-check: standing next to a Boki on the farm shows one line over it (InteractPrompt) with the
## four care actions, pet, feed, play and pick up, each with its live key (Settings.key_cap). What a tap
## of the interact key would do now (pet or feed) is lit and the other greyed: Feed is greyed with no food.
## Pick up (holding the key, HomeCarry) is lit while you could lift it, greyed with another in your arms. Nothing else is shown with it. Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CAREPROMPT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## The care line's entries as "<key> <label>" with "~" in front of a greyed one, in order.
func _shown(p: InteractPrompt) -> Array:
	var out: Array = []
	for one in p._more.get_children():
		var row: HBoxContainer = one.get_child(0)
		var cap: Label = row.get_child(0).get_child(0)
		var what: Label = row.get_child(1)
		out.append("%s%s %s" % ["~" if one.modulate.a < 1.0 else "", cap.text, what.text])
	return out

func _needs(k: Dictionary, food: float) -> void:
	for n in Care.NEEDS:
		k["rec"]["needs"][n] = 80.0
	k["rec"]["needs"]["food"] = food
	k["rec"]["needs_t"] = Time.get_unix_time_from_system() + 9999.0

func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	var first := Save.new_kin("zapple", "Pip")
	first["starter"] = true
	d["roster"].append(first)
	d["active"] = first["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(d)
	var home = await main._hb_home()
	home._close_panel()     # the welcome card
	var k: Dictionary = home.kins[0]
	var p: InteractPrompt = home.prompt
	var f := Settings.key_cap("interact")
	var r := Settings.key_cap("play")
	_needs(k, 80.0)
	home.ppos = k["pos"] + Vector3(0.8, 0, 0)
	home._find_interact()
	ok(home.interact.get("kind", "") == "kin", "next to the Boki it is the target")
	var line := _shown(p)
	var want := ["%s Pet" % f, "~%s Feed" % f, "%s Play" % r, "%s Hold: Pick up" % f]
	ok(p.visible and line == want, "content: pet, feed, play, pick up with their keys, pet lit (%s)" % [line])
	ok(not p.line.visible and not p.ring.visible and not p._note.visible, "one line: no verb row, ring or note")
	var over: Vector2 = home.cam.unproject_position(k["node"].global_position + Vector3.UP * HomePrompt.CARE_LINE_M)
	var mid := p.position + Vector2(p.size.x * 0.5, p.size.y)
	ok(mid.distance_to(over) < 2.0, "it sits over the Boki (%s vs %s)" % [mid, over])
	_needs(k, 10.0)
	Save.d["crops"].clear()
	Save.d["items"].clear()
	home._find_interact()
	line = _shown(p)
	ok(line == ["%s Pet" % f, "~%s Feed (no food)" % f, "%s Play" % r, "%s Hold: Pick up" % f],
		"hungry with no food: Feed is greyed, the key pets it (%s)" % [line])
	Save.d["items"][String(Care.FOODS.keys()[0])] = 2
	home._find_interact()
	line = _shown(p)
	ok(line == ["~%s Pet" % f, "%s Feed" % f, "%s Play" % r, "%s Hold: Pick up" % f],
		"with food it lights Feed (%s)" % [line])
	home.carry.k = {"rec": k["rec"]}     # another Boki in your arms
	home._find_interact()
	ok(_shown(p)[3] == "~%s Hold: Pick up" % f, "arms full: Pick up is greyed (%s)" % [_shown(p)])
	home.carry.k = k
	home._find_interact()
	ok(_shown(p)[3] == "%s Hold: Let go" % f, "this one in your arms: Let go (%s)" % [_shown(p)])
	home.carry.k = {}
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_J
	var was: InputEvent = InputMap.action_get_events("play")[0].duplicate()
	Settings.rebind("play", ev)
	home._find_interact()
	ok(_shown(p).has("J Play"), "rebinding play changes its key at once (%s)" % [_shown(p)])
	Settings.rebind("play", was)
	print("CARE-PROMPT-CHECK: %s" % ("PASS" if bad == 0 else "%d FAIL" % bad))
	Save.no_write = false
	main.get_tree().quit(0 if bad == 0 else 1)
