extends RefCounted
## --kit-drill-check: the first-time kit drill (KitDrill). Every Hunter gets a line, key and call-out per slot
## from its own JSON, the slice Hunters their own text and the rest a generic one; a recast reads "<KEY> AGAIN"
## and a hold says so; the steps advance on the player's presses; in the Training Area the banner shows once
## and a skip or a finished drill is saved so it never returns.

const ONE_LINE := 72        # chars: a step line fits the banner on one line (DECISIONS 11-08, shorter tutorials)
const OPTS := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"training": true, "practice": true}
var bad := 0

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
	await _recast(main, tree)
	print("KITDRILL %s" % ("FAIL %d" % bad if bad > 0 else "OK"))
	tree.quit(1 if bad > 0 else 0)

func _text() -> void:
	for id in Arch.ids():
		var plan := KitDrill.steps(id)
		var every := plan.size() == KitDrill.SLOTS.size()
		for st in plan:
			every = every and String(st["line"]).length() > 3 and String(st["key"]) != "?"
		ok(every, "%s: a line and a key for every slot" % id)
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
	var jug: Dictionary = KitDrill.steps("juggernaut")[2]
	ok(KitDrill.callout(jug, 1) == "%s AGAIN" % jug["key"], "after the first press the call-out is '<KEY> AGAIN'")
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
		var n := 2 if st["how"] == "again" else 1
		for i in n:
			ok(k.step < k.plan.size() and k.plan[k.step]["slot"] == st["slot"], "step %s is open" % st["slot"])
			if st["how"] == "hold":
				k.on_held(st["action"], KitDrill.HOLD_S)
			else:
				k.on_press(st["action"])
			if i == 0 and n == 2:
				var open: bool = k.presses == 1 and k.plan[k.step]["slot"] == st["slot"]
				ok(open, "%s: the first press of a recast does not finish it" % st["slot"])
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
	ok(kd != null and kd.plan.size() == KitDrill.SLOTS.size(), "%s: the first visit gets the drill" % tag)
	if kd != null:
		if skip:
			kd.finish()
		else:
			for st in kd.plan:
				if st["how"] == "hold": kd.on_held(st["action"], KitDrill.HOLD_S)
				else:
					kd.on_press(st["action"])
					kd.on_press(st["action"])
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
## The recast drill station (RecastDrill) as Ostra (his E is a two-step: the seed, then E again) and as Vex (no
## two-step ability). Ostra: three reps read hit, early, hit; a press inside the 0.15 s buffer before the window
## arms is a hit; the slot's cooldown is reset after each rep. (His seed has no timer: _late covers a window that
## runs out.)
func _recast(main: Node, tree: SceneTree) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("ostra"))
	m.set_process(false)
	for i in 3: await tree.process_frame
	var d := Practice.of(m).recast
	ok(d != null and not d.is_open(), "recast: the Training Grounds bar has the station, closed")
	d.toggle()
	var k := m.player.ak as OstraKit
	ok(d.plan == ["e"], "recast: Ostra has one two-step slot (E)")
	var dt := 1.0 / 60.0
	var rep := func(second_after: float):
		# casts, presses again second_after s into the seed's life (-1: never), runs until the rep is graded
		k.use_e()
		d.on_press("e")
		var t := 0.0
		var pressed := false
		while t < 20.0 and d.reps["e"]["ph"] != "cool":
			if not pressed and second_after >= 0.0 and not k.seed.is_empty() and float(k.seed["t"]) >= second_after:
				k.use_e()
				d.on_press("e")
				pressed = true
			m.step(dt)
			d.tick(dt)
			t += dt
	rep.call(0.45)
	var res: Array = d.reps["e"]["res"]
	ok(res == ["hit"], "recast: E again inside the window reads hit")
	ok(k.seed.is_empty(), "recast: and the real recast went off")
	ok(d._text.text.contains("HIT") and not d._text.text.contains("inf"), "recast: a timer-less window reads HIT only")
	_settle(m, d, dt)
	ok(String(d.reps["e"]["ph"]) == "idle" and float(k.cd["e"]) == 0.0, "recast: a finished rep resets the slot")
	rep.call(0.04)
	res = d.reps["e"]["res"]
	ok(res == ["hit", "early"], "recast: E again well before the marker reads early")
	ok(not k.seed.is_empty() and d.reps["e"]["ph"] == "cool", "recast: the seed is still out, the slot waits")
	k.use_e()      # (the real recast pops it: the slot is free again)
	_settle(m, d, dt)
	rep.call(0.45)
	res = d.reps["e"]["res"]
	ok(res == ["hit", "early", "hit"], "recast: a second clean press reads hit again")
	_settle(m, d, dt)
	ok(int(d.reps["e"]["n"]) == RecastDrill.REPS and "done" in d._text.text, "recast: three reps finish the ability")
	d.on_press("e")
	ok(d.reps["e"]["ph"] == "idle" and d.reps["e"]["n"] == RecastDrill.REPS, "recast: a fourth rep is not counted")
	d.start("ostra")
	var gate := float(k.e_def()["min_recast"])
	rep.call(gate - ArchKit.RECAST_BUFFER * 0.6)
	res = d.reps["e"]["res"]
	ok(res == ["hit"], "recast: a press inside the buffer before the window arms is a hit")
	d.toggle()
	m.queue_free()
	await tree.process_frame
	var g := Match.new()
	main.add_child(g)
	await g.start(Match.arena_opts("gunslinger"))
	g.set_process(false)
	for i in 3: await tree.process_frame
	var gd := Practice.of(g).recast
	gd.toggle()
	ok(gd.plan.is_empty() and gd._text.text == "No two-step abilities", "recast: Vex sees 'No two-step abilities'")
	gd.toggle()
	g.queue_free()
	await tree.process_frame
	await _late(main, tree)

## A two-step whose window runs out (Thief's E) unused reads late.
func _late(main: Node, tree: SceneTree) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("thief"))
	m.set_process(false)
	for i in 3: await tree.process_frame
	var d := Practice.of(m).recast
	d.toggle()
	ok(d.plan == ["e"], "recast late: the Thief has one two-step slot (E)")
	m.player.ak.use_e()
	d.on_press("e")
	var t := 0.0
	while t < RecastDrill.COOL_MAX and d.reps["e"]["ph"] != "cool":
		m.step(1.0 / 60.0)
		d.tick(1.0 / 60.0)
		t += 1.0 / 60.0
	ok(d.reps["e"]["res"] == ["late"], "recast late: a window that closes unused reads late")
	d.toggle()
	m.queue_free()
	await tree.process_frame

## Steps until the drill's slot is idle again (its window closed and the cooldown reset).
func _settle(m: Match, d: RecastDrill, dt: float) -> void:
	var t := 0.0
	while String(d.reps["e"]["ph"]) != "idle" and t < RecastDrill.COOL_MAX + 1.0:
		m.step(dt)
		d.tick(dt)
		t += dt
