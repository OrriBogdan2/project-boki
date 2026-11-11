extends RefCounted
## --home-hatch-check: the nest egg's hatch at home is a small moment (GARDEN.md 6, HomeHatchWatch).
##   1. far from ready: the egg is calm and nobody is sent for
##   2. in the last 20 s the egg wobbles and the Boki at home walk over (no panel opens, you stay free)
##   3. a ready egg with 3 Boki at home: at least 2 stand round it when the hatch starts
##   4. a key press rushes the hatching on, then the hatch card comes up
##   5. you far away: the egg stays ready for you, nothing hatches on its own

var main: Node
var bad := 0
var home = null

func ok(cond: bool, what: String) -> void:
	print("HOMEHATCH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	if main.fade:
		main.fade.reveal(0.05)
	await _calm_then_wobble()
	await _gather_and_hatch()
	await _player_away()
	print("HOMEHATCH DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A farm with three Boki (two of them the egg's parents) and an egg that is ready in `secs`.
func _farm(secs: float) -> void:
	var d := Save.fresh()
	for n in ["Pip", "Drip", "Moss"]:
		var k := Save.new_kin(["zapple", "puddlet", "burrlet"][d["roster"].size()], n)
		k["level"] = 6
		k["trust"] = 60.0
		d["roster"].append(k)
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["matches"] = 0
	var ready_at := Time.get_unix_time_from_system() + secs
	d["egg"] = {"a": d["roster"][0]["uid"], "b": d["roster"][1]["uid"], "m": 99, "t": ready_at}
	Save.d = d
	HomeLayout.ensure(Save.d)
	if home:
		home.queue_free()
		await main.get_tree().process_frame
	home = await main._hb_home()
	home._close_panel()
	await _wait(func(): return home.hwatch != null and home.kins.size() >= 3 and is_instance_valid(home.nest), 10.0)
	home.ppos = home.NEST_AT + Vector3(0, 0, 4.0)

func _calm_then_wobble() -> void:
	await _farm(120.0)
	await _wait(func(): return false, 1.0)
	ok(home.hwatch.watchers.is_empty(), "two minutes out: nobody is sent for")
	var greeter: Dictionary = home.kins[2]
	greeter["called_t"] = 3.0      # running over to say hello (KinWelcome), as when you come home to the egg
	Save.d["egg"]["t"] = Time.get_unix_time_from_system() + 12.0
	var peak := [0.0]
	await _wait(func():
		peak[0] = maxf(peak[0], absf(home.nest.get_node("Shell").rotation.z))
		return peak[0] > 0.0, 6.0)
	ok(peak[0] > 0.0, "12 s out: the egg wobbles (peak %.2f)" % peak[0])
	ok(not home.hwatch.watchers.has(greeter), "a Boki busy saying hello is not sent for yet")
	var w: Array = home.hwatch.watchers
	await _wait(func(): return w.size() >= 3 or home.hwatch.left() <= 0.0, 11.0)
	ok(w.size() == 3 and w.has(greeter) and home.hwatch.left() > 0.0,
		"before it is ready all 3 are sent to watch, the greeter once its hello is done (%d)" % w.size())
	ok(home.panel_open == "" and not home.building_now, "you are not held: no panel, no cutscene yet")

func _gather_and_hatch() -> void:
	await _farm(0.0)
	var roster0: int = Save.d["roster"].size()
	await _wait(func(): return home.hwatch._hatching != null, 25.0)
	ok(home.hwatch._hatching != null, "a ready egg hatches by itself with you near")
	ok(home.hwatch.gathered >= 2, "at least 2 of 3 Boki gathered before the hatch (%d)" % home.hwatch.gathered)
	var born: bool = Save.d["roster"].size() == roster0 + 1 and Save.d["egg"].is_empty()
	ok(born, "the baby joins the roster and the nest is empty")
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	var t0 := Time.get_ticks_msec()
	Input.parse_input_event(ev)
	await _wait(func(): return home.panel_open == "reveal", 12.0)
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	var card: bool = home.panel_open == "reveal" and took < 4.5
	ok(card, "a key press rushes the hatching on, then the card (%.1f s; unskipped over 8)" % took)

func _player_away() -> void:
	await _farm(0.0)
	home.ppos = home.NEST_AT + Vector3(0, 0, 14.0)
	await _wait(func(): return home.hwatch._hatching != null, 14.0)
	ok(home.hwatch._hatching == null and not Save.d["egg"].is_empty(), "you far away: the egg waits ready for you")

func _wait(cond: Callable, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await main.get_tree().process_frame
