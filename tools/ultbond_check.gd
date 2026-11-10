extends RefCounted
## --ultbond-check: the keys and the bond/merge loop.
##   keys     R hunter ultimate and X merge are the defaults; old saves move (merge R/X/T -> X, X -> R for the
##            hunter ultimate; reload and the Boki ability key are dropped) and genuine custom binds stay
##   press    R casts the hunter ultimate, X merges, G sends out and calls back, nothing is bound to reload
##   bond     KinBond.add clamps to a full bar; from_ult pays the best event of one cast, not per event or target
##   release  the second merge press fires the ultimate: afterglow for the hunter, the Boki lands pumped and rests
##            the short time; a timeout has neither
##   cap      stat-based damage while merged is at most merge_forms.json damage_cap
## Never touches the save.

var bad := 0
var main: Node
var m: Match

func ok(cond: bool, what: String) -> void:
	print("ULTBOND %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _key(k: int) -> String:
	return "key:%d" % k

func _fresh() -> Hunter:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"demo_kin": "pebbit", "weapon": "rifle", "cls": "medium"})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	return m.player

func _glowing(h: Hunter) -> bool:
	return float(h.get_meta("afterglow_t", 0.0)) > 0.0

func _run_for(secs: float) -> void:
	var t := 0.0
	while t < secs:
		for mob in m.mobs:
			mob.queue_free()
		m.mobs.clear()
		m.step(Match.DT)
		t += Match.DT

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_keys()
	_migration()
	await _presses()
	_bond()
	_release()
	_cap()
	print("ULTBOND DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ keys
func _keys() -> void:
	Settings.reset_all()
	var gone := ["reload", "kin_ability"]
	ok(not gone.any(InputMap.has_action) and not Settings.ACTIONS.any(func(a): return a[0] in gone),
		"no action is bound to reload, and the Boki ability has no key")
	ok(Settings.slots("hunter_ult")[0] == _key(KEY_R),
		"R is the hunter ultimate by default (%s)" % str(Settings.slots("hunter_ult")))
	ok(Settings.slots("ultimate") == [_key(KEY_X), ""],
		"X alone is Merge by default (%s)" % str(Settings.slots("ultimate")))
	ok(Settings.key_cap("hunter_ult") == "R" and Settings.key_cap("ultimate") == "X",
		"the key caps follow the binds (%s, %s)" % [Settings.key_cap("hunter_ult"), Settings.key_cap("ultimate")])
	ok(Settings.slots("emote")[0] == _key(KEY_Y), "the Emote wheel moved to Y (%s)" % str(Settings.slots("emote")))
	ok(Settings.slots("talk")[0] == _key(KEY_T) and Settings.slots("details")[0] == _key(KEY_C),
		"the home keys Talk and Details stay on T and C")
	ok(Settings.conflicts(_ev(KEY_X), "ultimate").is_empty(),
		"nothing else in a match is on X (%s)" % str(Settings.conflicts(_ev(KEY_X), "ultimate")))
	ok(Settings.conflicts(_ev(KEY_R), "hunter_ult").is_empty(), "R is shared only with the build-mode rotate")

func _ev(k: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k as Key
	e.pressed = true
	return e

func _migration() -> void:
	var old := {"keys": {"ultimate": [_key(KEY_R), _key(KEY_X)]}, "keys2_v": 1, "keys3_v": 0}
	KeyMigrate.run(old)
	ok(old["keys"].is_empty() and int(old["keys4_v"]) == 1,
		"old default merge [R, X] goes back to the defaults (X merge, R hunter ult): %s" % str(old["keys"]))
	var old_kit := {"ultimate": [_key(KEY_T)], "hunter_ult": [_key(KEY_X)], "reload": [_key(KEY_R)],
		"kin_ability": [_key(KEY_C)]}
	var saved_old := {"keys": old_kit, "keys2_v": 1, "keys3_v": 1, "keys4_v": 0}
	KeyMigrate.run(saved_old)
	ok(saved_old["keys"].is_empty(), "the old default kit moves to the new one: %s" % str(saved_old["keys"]))
	var pinned := {"keys": {"ultimate": [_key(KEY_R)], "tonic": [_key(KEY_X)]}, "keys2_v": 1, "keys3_v": 0}
	KeyMigrate.run(pinned)
	var pk: Dictionary = pinned["keys"]
	ok(pk["ultimate"] == [] and pk["hunter_ult"] == [] and pk["tonic"] == [_key(KEY_X)],
		"X bound elsewhere stays there and Merge starts unbound: %s" % str(pinned["keys"]))
	var custom_keys := {"ultimate": [_key(KEY_F)], "hunter_ult": [_key(KEY_Z)], "dash": [_key(KEY_R)],
		"reload": [_key(KEY_Q)]}
	var custom := {"keys": custom_keys, "keys2_v": 1, "keys3_v": 0}
	KeyMigrate.run(custom)
	var ck: Dictionary = custom["keys"]
	var kept: bool = ck["ultimate"] == [_key(KEY_F)] and ck["hunter_ult"] == [_key(KEY_Z)]
	kept = kept and ck["dash"] == [_key(KEY_R)]
	ok(kept and not ck.has("reload"),
		"custom binds are kept, the reload bind is dropped: %s" % str(custom["keys"]))
	var r_taken := {"keys": {"dash": [_key(KEY_R)]}, "keys2_v": 1, "keys3_v": 0}
	KeyMigrate.run(r_taken)
	ok(r_taken["keys"]["hunter_ult"] == [] and r_taken["keys"]["dash"] == [_key(KEY_R)],
		"R custom-bound to another action: the hunter ultimate starts unbound")
	var x_taken := {"keys": {"base": [_key(KEY_X)]}, "keys2_v": 1, "keys3_v": 0}
	KeyMigrate.run(x_taken)
	ok(x_taken["keys"]["ultimate"] == [] and x_taken["keys"]["base"] == [_key(KEY_X)],
		"X custom-bound to another action: Merge starts unbound, no clash (%s)" % str(x_taken["keys"]))
	var y_taken := {"keys": {"map": [_key(KEY_Y)]}, "keys2_v": 1, "keys3_v": 0}
	KeyMigrate.run(y_taken)
	var yk: Dictionary = y_taken["keys"]
	ok(yk["emote"] == [] and yk["map"] == [_key(KEY_Y)] and not yk.has("ultimate"),
		"Y custom-bound to another action: Emote starts unbound (%s)" % str(y_taken["keys"]))
	var merge_y := {"keys": {"ultimate": [_key(KEY_Y)]}, "keys2_v": 1, "keys3_v": 0}
	KeyMigrate.run(merge_y)
	ok(merge_y["keys"]["ultimate"] == [_key(KEY_Y)] and merge_y["keys"]["emote"] == [],
		"Merge saved on exactly Y: Merge keeps it, Emote starts unbound (%s)" % str(merge_y["keys"]))
	var emote_t := {"keys": {"emote": [_key(KEY_T)]}, "keys2_v": 1, "keys3_v": 0}
	KeyMigrate.run(emote_t)
	var ek: Dictionary = emote_t["keys"]
	ok(not ek.has("emote") and not ek.has("ultimate"), "a saved old-default Emote on T moves to Y")
	var twice := custom.duplicate(true)
	KeyMigrate.run(twice)
	ok(twice == custom, "the migration runs once")
	var oldsep := {"keys": {"separate": [_key(KEY_X)]}, "keys2_v": 0, "keys3_v": 0}
	KeyMigrate.run(oldsep)
	ok(oldsep["keys"]["separate"] == [_key(KEY_Z)] and not oldsep["keys"].has("hunter_ult"),
		"Separate still moves from X to Z")

# ------------------------------------------------------------------ what the keys do
func _press(action: String) -> void:
	Input.action_press(action)
	m._gather_input()
	await main.get_tree().process_frame
	Input.action_release(action)
	await main.get_tree().process_frame

func _presses() -> void:
	var P := _fresh()
	P.kin.stow()
	P.lvl = int(Hunter.ULT_AT[0])
	P.ult = 1.0
	await _press("ultimate")
	ok(bool(m.pending_input["ult"]), "X queues the Merge")
	_run_for(float(MergeForm.data()["xform_s"]) + 0.12)
	ok(KinMerge.active(P), "X merges you with your Boki")
	P = _fresh()
	P.lvl = int(Hunter.ULT_AT[0])
	var has_own := P.ak != null and P.ak.has_ult()        # the default medium (Vex) has one: Cinderfall
	P.lvl = 1
	ok(not HunterKeys.ult_pressed(P), "R before level %d does nothing" % int(Hunter.ULT_AT[0]))
	P.lvl = int(Hunter.ULT_AT[0])
	P.ak.cd["x"] = 0.0
	await _press("hunter_ult")
	ok(has_own and float(P.ak.cd["x"]) > 0.0 and not m.pending_input["ult"] and not KinMerge.active(P),
		"R casts the hunter ultimate, not the Merge (cooldown %.1f)" % float(P.ak.cd.get("x", 0.0)))
	P = _fresh()
	Input.action_press("throw")
	m._gather_input()
	await main.get_tree().process_frame
	Input.action_release("throw")
	m._gather_input()
	ok(bool(m.pending_input["throw"]), "a G tap queues the send-out / call-back order")
	var k: Kin = P.kin
	KinCommand.tap(P)
	var sent := k.state != "shoulder"
	k.state = "active"        # landed and out (the test arena aim can drop it in the void)
	k.global_position = P.global_position + Vector3(8, 0, 0)
	KinCommand.tap(P)
	var back := ["returning", "flying_home", "shoulder"]
	ok(sent and k.state in back, "G sends the Boki out, and calls it back (%s)" % k.state)
	k.state = "active"
	Input.action_press("throw")
	for i in 10:
		KinCommand.poll(P, 0.05, false)
	var wheel_open := KinWheel.is_open(P)
	Input.action_release("throw")
	KinCommand.poll(P, 0.05, false)
	ok(wheel_open and not KinWheel.is_open(P) and P.inp.has("wheel_pick"),
		"holding G opens the order wheel, letting go picks")
	ok(KinCommand.order(P, "guard") and k.cmd == "guard", "a wheel order is applied (the Boki is told to guard)")
	await _quick_orders(P)

## The quick order keys (KinKeys) give the same orders as the wheel, from the match's input step.
func _quick_orders(P: Hunter) -> void:
	var k: Kin = P.kin
	for o in [["kin_return", "return"], ["kin_hold", "guard"]]:
		P.inp.erase("wheel_pick")
		Input.action_press(o[0])
		m._gather_input()
		Input.action_release(o[0])
		var picked := String(P.inp.get("wheel_pick", ""))
		KinCommand.apply_pick(P)
		var cap := Settings.key_cap(o[0])
		ok(picked == o[1] and k.cmd == o[1], "%s gives the %s order (picked '%s', now %s)" % [cap, o[1], picked, k.cmd])
		await main.get_tree().process_frame

# ------------------------------------------------------------------ the bond hook
func _bond() -> void:
	var P := _fresh()
	P.kin.stow()
	var rules := KinBond.rules()
	var shares_ok := is_equal_approx(float(rules["hit"]), 0.6) and is_equal_approx(float(rules["knock"]), 0.7)
	shares_ok = shares_ok and is_equal_approx(float(rules["kill"]), 0.8)
	ok(shares_ok,
		
		"bond_from_ult is hit 0.6, knock 0.7, kill 0.8 (%s)" % str(rules))
	P.ult = 0.0
	ok(is_equal_approx(KinBond.add(P, 0.25, "test"), 0.25) and is_equal_approx(P.ult, 0.25),
		"add puts a share of the bar in (%.2f)" % P.ult)
	var got := KinBond.add(P, 5.0, "test")
	ok(is_equal_approx(P.ult, 1.0) and is_equal_approx(got, 0.75),
		"add clamps to a full bar (%.2f, took %.2f)" % [P.ult, got])
	ok(KinBond.add(P, 0.1, "test") == 0.0 and KinBond.add(P, -1.0, "test") == 0.0,
		"a full bar or a negative share adds nothing")
	P.ult = 0.0
	ok(KinBond.from_ult(P, "hit", "") == 0.0 and P.ult == 0.0, "a cast with no id pays nothing")
	KinBond.from_ult(P, "hit", "c1")
	KinBond.from_ult(P, "hit", "c1")
	ok(is_equal_approx(P.ult, 0.6), "a second hit of the same cast adds nothing (%.2f)" % P.ult)
	KinBond.from_ult(P, "kill", "c1")
	ok(is_equal_approx(P.ult, 0.8), "a kill after a hit tops up to the kill's share (%.2f)" % P.ult)
	KinBond.from_ult(P, "knock", "c1")
	ok(is_equal_approx(P.ult, 0.8), "a worse event after a better one adds nothing")
	P.ult = 0.0
	KinBond.from_ult(P, "knock", "c2")
	ok(is_equal_approx(P.ult, 0.7), "a new cast starts again (%.2f)" % P.ult)
	P.ult = 0.0
	KinBond.from_ult(P, "kill", "c3")
	KinBond.from_ult(P, "kill", "c3")
	ok(is_equal_approx(P.ult, 0.8), "two kills in one cast pay once (%.2f)" % P.ult)
	P.ult = 0.0
	ok(KinBond.from_ult(P, "bogus", "c4") == 0.0 and P.ult == 0.0, "an unknown kind pays nothing")
	P.ult = 0.0
	var seen := [0.0]
	var cb := func(_h, amount: float, _why: String): seen[0] += amount
	CombatBus.bond_gained.connect(cb)
	KinBond.add(P, 0.2, "ult_hit")
	CombatBus.bond_gained.disconnect(cb)
	ok(is_equal_approx(seen[0], 0.2), "an ultimate's share announces itself (bond_gained)")

# ------------------------------------------------------------------ release and timeout
func _merged() -> Hunter:
	var P := _fresh()
	P.kin.stow()
	P.ult = 1.0
	KinMerge.press(P)
	_run_for(float(MergeForm.data()["xform_s"]) + 0.12)
	return P

func _release() -> void:
	var P := _merged()
	var k: Kin = P.kin
	ok(KinMerge.active(P) and not _glowing(P), "setup: merged, no afterglow yet")
	var kit := MergeKit.of(P)
	kit.age = 2.0
	P.shield = 0.0
	P.inp["ult"] = true
	_run_for(float(Content.merge_form("titan")["r"]["end"]) + 0.5)
	var ag := MergeRelease.rules()
	ok(not KinMerge.active(P), "the second press releases: the merge is over")
	var glow_ok := is_equal_approx(float(ag["secs"]), 3.0) and is_equal_approx(float(ag["move_speed"]), 0.15)
	glow_ok = glow_ok and is_equal_approx(float(ag["shield_frac"]), 0.08)
	ok(glow_ok,
		
		"afterglow data: 3s, +15% speed, 8%% max health shield (%s)" % str(ag))
	ok(_glowing(P) and P.buff("move_speed") >= 0.15 - 0.001,
		"the hunter has the afterglow: +%.0f%% speed" % (P.buff("move_speed") * 100.0))
	ok(P.shield >= P.max_hp * 0.08 - 0.5 and P.shield_t > 0.0,
		"...and a shield of 8%% max health (%.1f of %.1f)" % [P.shield, P.max_hp])
	ok(k.resting() and k.rest_t <= 6.0 and k.rest_t > 4.0, "the Boki rests about 6s (%.1fs)" % k.rest_t)
	ok(k.state != "shoulder" and k.state != "fused" and k.flat_dist(P) < 8.0 and k.cmd == "follow",
		"...landed beside you, following, not stowed (state %s, %.1fm)" % [k.state, k.flat_dist(P)])
	ok(P.merge_cd >= 5.0, "Merge waits for the rest (%.1fs)" % P.merge_cd)
	_run_for(3.3)
	ok(not _glowing(P) and P.buff("move_speed") == 0.0, "the afterglow lasts about 3s")
	_run_for(3.0)
	ok(not k.resting(), "the Boki is rested after the short rest")
	# a timeout: no burst, no afterglow, no pumped rest
	P = _merged()
	k = P.kin
	P.merge_st["t"] = 0.05
	_run_for(0.3)
	ok(not KinMerge.active(P) and not _glowing(P) and P.buff("move_speed") == 0.0,
		"a timeout ends without the afterglow")
	ok(k.resting() and k.rest_t > MergeRelease.rest_s() and k.cmd == "follow",
		"...and the Boki rests longer than after a release (%.1fs, state %s)" % [k.rest_t, k.state])
	ok(absf(P.merge_cd - MergeRelease.timeout_rest_s()) < 0.5,
		"...with the timeout rest as the spent window (%.1fs)" % P.merge_cd)

# ------------------------------------------------------------------ the damage cap
func _cap() -> void:
	var P := _merged()
	var cap := float(MergeForm.data()["damage_cap"])
	ok(is_equal_approx(cap, 0.2), "damage_cap is +20%% (merge_forms.json: %.2f)" % cap)
	P.add_buff("damage", 0.35, 5.0)
	ok(P.gear_stat("dmg") <= cap + 0.0001,
		"merged with a +35%% buff: the stat bonus stays at +%.0f%% (%.2f)" % [cap * 100.0, P.gear_stat("dmg")])
	ok(is_equal_approx(KinMerge.cap_damage(P, 0.05, 0.3), cap), "gear +5% plus +30% from the merge caps at +20%")
	ok(is_equal_approx(KinMerge.cap_damage(P, 0.25, 0.1), 0.25), "gear and perks you had on their own are never cut")
	ok(float(KinParts.OWNER_STATS["damage"][3]) >= 0.35, "a Boki's own damage passive roll is not shrunk by the cap")
	var Q := _fresh()
	Q.add_buff("damage", 0.35, 5.0)
	ok(Q.gear_stat("dmg") > cap, "outside a merge the buff is not capped (%.2f)" % Q.gear_stat("dmg"))
