extends RefCounted
## --kit-drill-check: the first-time kit drill (KitDrill). Every Hunter gets a line, key and call-out per slot
## from its own JSON, the slice Hunters their own text and the rest a generic one; a recast reads "<KEY> AGAIN"
## and a hold says so; the steps advance on the player's presses; in the Training Area the banner shows once
## and a skip or a finished drill is saved so it never returns. Kael's own drill (clip.drill): combo, LMB hold,
## RMB tap and hold, the chain and its pull, the Riposte guard against a dummy that swings, Rampage; one line each.

var bad := 0
const ONE_LINE := 72        # chars: a step line fits the banner on one line (DECISIONS 11-08, shorter tutorials)
const OPTS := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"training": true, "practice": true}

func ok(cond: bool, what: String) -> void:
	print("KITDRILL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var tree := main.get_tree()
	_text()
	_steps()
	await _area(main, tree, false, "gunslinger")
	await _area(main, tree, true, "gunslinger")
	await _area(main, tree, false, "archer")
	await _area(main, tree, false, "juggernaut")
	print("KITDRILL %s" % ("FAIL %d" % bad if bad > 0 else "OK"))
	tree.quit(1 if bad > 0 else 0)

func _text() -> void:
	for id in Arch.ids():
		var plan := KitDrill.steps(id)
		var every := _slots(plan) == KitDrill.SLOTS
		for st in plan:
			every = every and String(st["line"]).length() > 3 and String(st["key"]) != "?"
			every = every and String(st["line"]).length() <= ONE_LINE and not "\n" in String(st["line"])
		ok(every, "%s: a one-line line and a key for every slot" % id)
		if id in KitDrill.SLICE:
			for st in plan:
				print("KITDRILL   [%s] %s  %s" % [st["key"], st["line"], KitDrill.callout(st, 0)])
	ok(KitDrill.how("juggernaut", "e") == "again", "juggernaut E is a recast (its chain: press E again)")
	ok(KitDrill.how("gunslinger", "dash") == "hold", "gunslinger dash has a hold")
	ok(KitDrill.how("juggernaut", "lmb") == "", "LMB is a plain press unless the JSON says hold")
	_vex_lines()
	var holds := KitDrill.how("archer", "lmb") == "hold" and KitDrill.how("archer", "rmb") == "hold"
	ok(holds, "Lace: the draw and the Heavy Shot are holds")
	var draw: String = KitDrill.line("archer", "lmb").to_lower()
	var wall: String = KitDrill.line("archer", "rmb").to_lower()
	ok(draw.contains("hold") and draw.contains("gold"), "Lace's draw line: hold, then let go on the gold flash")
	ok(wall.contains("hold") and wall.contains("wall"), "Lace's Heavy Shot line: hold, and the wall pin")
	var cue := KitDrill.callout(KitDrill.steps("archer")[0], 0)
	ok(cue == "HOLD %s, not just a tap" % Settings.key_cap("fire"), "Lace's draw call-out names the key")
	var kael := KitDrill.steps("juggernaut")
	var jug: Dictionary = kael.filter(func(st): return st["slot"] == "e")[0]
	ok(KitDrill.callout(jug, 1) == "%s AGAIN" % jug["key"], "after the first press the call-out is '<KEY> AGAIN'")
	var hows := kael.map(func(st): return "%s.%s" % [st["slot"], st["how"]])
	var want := ["lmb.combo", "lmb.hold", "rmb.tap", "rmb.hold", "e.again", "x.block", "dash."]
	ok(hows == want, "Kael's drill: LMB combo and hold, RMB tap and hold, E and E again, R guard, Shift (%s)" % [hows])
	var tap := "TAP %s, don't hold it" % Settings.key_cap("secondary")
	ok(KitDrill.callout(kael[2], 0) == tap, "Kael's RMB tap call-out")
	ok(String(kael[4]["key"]) == Settings.key_cap("signature"), "keys come from the bindings")
	ok(not KitDrill.line("juggernaut", "e").begins_with("Try "), "a slice Hunter's line is its own text")
	ok(KitDrill.line("tender", "e").begins_with("Try "), "a Hunter outside the slice gets the generic line")

## Vex's drill (DECISIONS 'Starter masks'): held fire with no reload, the launcher's knock, the still
## charge and recoil of the beam, the target zone, tap vs hold on the dash with fire through it.
func _vex_lines() -> void:
	var want := {"lmb": ["hold", "no reload", "refills"], "rmb": ["launcher", "knocks"],
			"e": ["stand still", "0.6s", "recoil"], "x": ["zone", "cursor"], "dash": ["tap", "hold", "firing"]}
	for slot in want:
		var text := KitDrill.line("gunslinger", slot).to_lower()
		var miss: Array = want[slot].filter(func(w): return not text.contains(w))
		ok(miss.is_empty(), "Vex's %s line names %s (missing %s)" % [slot, want[slot], miss])
	ok(KitDrill.how("gunslinger", "lmb") == "hold", "Vex: LMB is a hold step (full-auto)")
	var cue := KitDrill.callout(KitDrill.steps("gunslinger")[0], 0)
	ok(cue == "HOLD %s, not just a tap" % Settings.key_cap("fire"), "Vex's fire call-out names the key")

func _steps() -> void:
	var k := KitDrill.new()
	k.m = Match.new()
	k.start("juggernaut")
	k.on_press("secondary")
	ok(k.step == 0, "the wrong key does not advance")
	_walk(k, "juggernaut")
	_walk(k, "archer")      # Lace: a tap on her draw does not count, a hold does
	_walk(k, "gunslinger")      # Vex: a tap of fire does not count, holding the trigger does
	k.m.free()
	k.free()

func _walk(k: KitDrill, hunter: String) -> void:
	k.start(hunter)
	if KitDrill.how(hunter, "lmb") == "hold":
		k.on_press("fire")
		ok(k.step == 0, "%s: a tap on LMB does not finish its hold" % hunter)
	for st in k.plan:
		var n: int = {"again": 2, "combo": KitDrill.COMBO_N}.get(st["how"], 1)
		for i in n:
			ok(k.step < k.plan.size() and k.plan[k.step]["slot"] == st["slot"], "step %s is open" % st["slot"])
			if st["how"] == "hold":
				k.on_held(st["action"], KitDrill.HOLD_S)
			else:
				k.on_press(st["action"])
			if i < n - 1:
				var open: bool = k.presses == i + 1 and k.plan[k.step]["slot"] == st["slot"]
				ok(open, "%s %s: press %d does not finish it" % [st["slot"], st["how"], i + 1])
	ok(k.step == k.plan.size() and k.done_t >= 0.0, "%s: the last step ends the drill" % hunter)

func _area(main: Node, tree: SceneTree, skip: bool, hunter: String) -> void:
	var d := Save.fresh()
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["cls"] = Arch.weight(hunter)
	d["arch"] = hunter
	d["classes"] = ClassUnlock.legacy()
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	await m.start(OPTS.duplicate())
	m.set_process(false)
	for i in 3: await tree.process_frame
	var kd := Practice.of(m).get_node_or_null(KitDrill.NAME) as KitDrill
	var tag := "%s %s" % [hunter, "skip" if skip else "finish"]
	ok(kd != null and _slots(kd.plan) == KitDrill.SLOTS, "%s: the first visit gets the drill" % tag)
	if kd != null:
		if skip:
			kd.finish()
		else:
			for st in kd.plan:
				if st["how"] == "hold": kd.on_held(st["action"], KitDrill.HOLD_S)
				elif st["how"] == "block": _swing(m, kd)
				else:
					for i in KitDrill.COMBO_N: kd.on_press(st["action"])
		ok(bool(Save.d["tutorial"].get(KitDrill.SAVE_KEY, false)), "%s: the save key is set" % tag)
	m.queue_free()
	await tree.process_frame
	var again := Match.new()
	main.add_child(again)
	await again.start(OPTS.duplicate())
	again.set_process(false)
	ok(Practice.of(again).get_node_or_null(KitDrill.NAME) == null, "%s: never shown again" % tag)
	again.queue_free()

## The slots a plan teaches, in SLOTS order.
func _slots(plan: Array) -> Array:
	return KitDrill.SLOTS.filter(func(sl): return plan.any(func(st): return st["slot"] == sl))

## Kael's guard step in the Training Grounds: a dummy in reach swings; unguarded it hurts and the step stays,
## the Riposte pressed (the real guard up) and its swing lands into the guard, blocked: the step is done.
func _swing(m: Match, kd: KitDrill) -> void:
	var at := kd.step
	var d: Hunter = m.arena.dummies[0]["h"]
	m.player.pos = d.pos + Vector3(1.5, 0, 0)
	var hp := m.player.hp + m.player.armor
	kd.tick_swing(KitDrill.SWING_EVERY - KitDrill.SWING_WIND + 0.01)
	ok(kd.swinger == d, "a dummy in reach winds up a swing")
	kd.tick_swing(KitDrill.SWING_WIND)
	ok(m.player.hp + m.player.armor < hp and kd.step == at, "unguarded, its swing hurts and the guard step stays")
	kd.on_press("hunter_ult")
	(m.player.ak as JuggernautKit).riposte.start()
	ok(kd.swinger == d and kd.swing_t <= KitDrill.SWING_INTO, "the guard pressed: it swings into it")
	hp = m.player.hp + m.player.armor
	kd.tick_swing(KitDrill.SWING_INTO)
	var blocked := m.player.hp + m.player.armor == hp
	ok(blocked and kd.step == at + 1, "the swing is blocked (no damage) and the step is done")
