extends RefCounted
## --care-prompt-check: standing next to a Boki on the farm puts one line over it (CareLine) with the four care
## actions, pet, feed, play and pick up, each with its live key (Settings.key_cap). What a tap of the interact key
## would do now (pet or feed) is lit and the other greyed: Feed is greyed with no food. Pick up (hold the key,
## HomeCarry) is lit while you could lift it, greyed with another in your arms. Never touches the real save.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("CAREPROMPT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


## The shown line as "<words>" with "~" in front of a greyed one, in order.
func _shown(home: Node) -> Array:
	var out: Array = []
	for one in home.prompt_box.get_node("Keys").get_children():
		var what: Label = one.get_child(one.get_child_count() - 1)
		out.append("%s%s" % ["~" if one.modulate.a < 1.0 else "", what.text])
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
	home._close_panel()  # the welcome card
	var k: Dictionary = home.kins[0]
	_needs(k, 80.0)
	home.ppos = k["pos"] + Vector3(0.8, 0, 0)
	home._find_interact()
	ok(home.interact.get("kind", "") == "kin", "next to the Boki it is the target")
	ok(home.prompt_box.visible, "the prompt shows")
	var line := _shown(home)
	ok(line == ["Pet", "~Feed", "Play", "to pick up"], "content: pet, feed, play, pick up, pet lit (%s)" % [line])
	var over: Vector2 = home.cam.unproject_position(k["node"].global_position + Vector3.UP * CareLine.LINE_M)
	var mid: Vector2 = home.prompt_box.position + Vector2(home.prompt_box.size.x * 0.5, home.prompt_box.size.y)
	ok(mid.distance_to(over) < 2.0, "it sits over the Boki (%s vs %s)" % [mid, over])
	_needs(k, 10.0)
	Save.d["crops"].clear()
	Save.d["items"].clear()
	home._find_interact()
	line = _shown(home)
	ok(line == ["Pet", "~Feed (no food)", "Play", "to pick up"], "hungry with no food: Feed greyed (%s)" % [line])
	Save.d["items"][String(Care.FOODS.keys()[0])] = 2
	home._find_interact()
	line = _shown(home)
	ok(line == ["~Pet", "Feed", "Play", "to pick up"], "with food it lights Feed (%s)" % [line])
	home.carry.k = {"rec": k["rec"]}  # another Boki in your arms
	home._find_interact()
	ok(_shown(home)[3] == "~to pick up", "arms full: Pick up is greyed (%s)" % [_shown(home)])
	home.carry.k = k
	home._find_interact()
	ok(_shown(home)[3] == "to let go", "this one in your arms: Let go (%s)" % [_shown(home)])
	home.carry.k = {}
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_J
	var was: InputEvent = InputMap.action_get_events("play")[0].duplicate()
	Settings.rebind("play", ev)
	home._find_interact()
	var caps := home.prompt_box.get_node("Keys").get_child(2).get_child(0).get_child(0) as Label
	ok(caps.text == "J", "rebinding play changes its key at once (%s)" % caps.text)
	Settings.rebind("play", was)
	print("CARE-PROMPT-CHECK: %s" % ("PASS" if bad == 0 else "%d FAIL" % bad))
	Save.no_write = false
	main.get_tree().quit(0 if bad == 0 else 1)
