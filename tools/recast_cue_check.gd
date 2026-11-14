extends "res://tools/archetype_check.gd"
## --recast-cue-check: every two-step ability reports its open recast to RecastCue (DECISIONS 2026-11-08 "two-step
## abilities must be obvious and in your face"): after the first step the kit's recast_window() names the slot,
## a time left and a total, the world spot for the marker, and the local hunter's cue state carries it (so the slot
## pulse, "<KEY> AGAIN" and the ring draw; the world marker and foe badge are rings, no text: DECISIONS
## 2026-11-11). Then: a timed window that runs out leaves "EXPIRED", an early
## press is buffered (~0.15s) into the window, and the marks/stacks/Daze reach the foe badges. Last the split: the
## kit's own world copy of that state hides on the owner's screen (the badge carries it) and shows to everyone else.


## A stand-in for the HUD: its canvas, and every text a cue draws is recorded.
class StubHud:
	extends Node
	var c := Control.new()
	var big: Font = null
	var texts: Array[String] = []

	func _arc(at: Vector2, rad: float, frac: float, col: Color, w: float) -> void:
		c.draw_arc(at, rad, 0.0, TAU * frac, 24, col, w, true)

	func _ctext(_at: Vector2, text: String, _size: int, _col: Color, _font: Font) -> void:
		texts.append(text)


const WAIT := 4.0  # s the first step gets to open its window (Rimelock's late crack comes last)

## [hero, slot]: each recast kit, from a fresh setup with the target 6m east; first() takes the first step.
const CASES := [
	["thief", "e"],
	["tender", "e"],
	["ostra", "e"],
	["rimewright", "e"],
	["rimewright", "x"],
	["juggernaut", "e"],
	["mage", "x"],
	["ashwick", "x"],
	["bulwark", "lmb"],
	["dolm", "dash"],
	["gil", "e"]
]
const RUN_OUT := 18.0  # s a window left alone gets to close (Brimseed: 6.5s grow + 10s at full, the longest)


## The first step of `slot` (also the shots' way in: tools/recast_cue_shots.gd).
static func first(m: Match, pp: Hunter, slot: String) -> void:
	match slot:
		"e":
			pp.ak.use_e()
		"x":
			pp.ak.cast_ult()
		"dash":
			pp.do_dash()
		"lmb":
			pp.inp["fire"] = true
			m.step(DT)
			pp.inp["fire"] = false


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	await _first_hint()
	for c in CASES:
		await _window(String(c[0]), String(c[1]))
	await _expired()
	await _buffered()
	await _badges()
	await _world_plain()
	await _split()
	print("RECASTCUE DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


## Steps until the kit reports `slot`'s window (or WAIT runs out); returns it ({} if it never opened).
func _open(m: Match, pp: Hunter, slot: String) -> Dictionary:
	var t := 0.0
	while t < WAIT:
		var w := pp.ak.recast_window()
		if String(w.get("slot", "")) == slot:
			return w
		m.step(DT)
		t += DT
	return {}


func _window(hero: String, slot: String) -> void:
	var s := setup(hero, 6.0)
	var m: Match = s[0]
	var pp: Hunter = s[1]
	aim_at(pp, (s[2] as Hunter).pos)
	first(m, pp, slot)
	var w := _open(m, pp, slot)
	var at = w.get("at")
	var timed := not w.is_empty() and float(w["left"]) > 0.0 and float(w["total"]) > 0.0
	var placed := at is Vector3 and (at as Vector3).is_finite()
	ok("%s %s: reports its recast window" % [hero, slot], timed and placed, str(w))
	var verb := RecastHint.verb(pp.ak, slot)
	ok("%s %s: the hint has the kit's own verb" % [hero, slot], verb != RecastHint.FALLBACK_VERB, verb)
	m.step(DT)
	var cw: Dictionary = pp.ak.cue.get("w", {})
	var key := RecastCue.key_of(slot)
	ok(
		"%s %s: the local cue carries it (slot, AGAIN key)" % [hero, slot],
		String(cw.get("slot", "")) == slot and key != "",
		"cue %s key %s" % [cw.get("slot", "-"), key]
	)
	if float(w.get("left", 0.0)) >= float(w.get("total", 0.0)) and hero == "bulwark":
		await done(m)  # the hammer lies until called back (lmb.lie_t 0): no timer, nothing runs out
		return
	# left alone: the closing ticks play and the slot shows EXPIRED for about 0.6s (never closes silently)
	var ticks := 0
	var exp_t := 0.0
	var t := 0.0
	while t < RUN_OUT and String(pp.ak.recast_window().get("slot", "")) == slot:
		ticks = maxi(ticks, int(pp.ak.cue.get("tick", 0)))
		m.step(DT)
		t += DT
	m.step(DT)
	ticks = maxi(ticks, int(pp.ak.cue.get("tick", 0)))
	exp_t = float(pp.ak.cue.get("exp_t", 0.0))
	ok("%s %s: the warning ticks play before it closes" % [hero, slot], ticks >= 1, "ticks %d" % ticks)
	ok(
		"%s %s: unused, the slot shows EXPIRED ~0.6s" % [hero, slot],
		(
			String(pp.ak.cue.get("exp_slot", "")) == slot
			and exp_t > 0.4
			and exp_t <= RecastCue.EXPIRED_T
			and absf(RecastCue.EXPIRED_T - 0.6) < 0.05
		),
		"exp %s %.2f after %.2fs" % [pp.ak.cue.get("exp_slot", "-"), exp_t, t]
	)
	await done(m)


## The first recast window of a save says "<KEY> AGAIN to <verb>" once (RecastHint); a kit with no recast never does.
func _first_hint() -> void:
	Save.d = Save.fresh()
	var s := setup("gunslinger", 6.0)
	var m: Match = s[0]
	var pp: Hunter = s[1]
	aim_at(pp, (s[2] as Hunter).pos)
	pp.ak.use_e()
	step(m, 1.5)
	ok(
		"gunslinger: a kit with no recast never opens the hint",
		pp.ak.recast_window().is_empty() and not Save.d["tutorial"][RecastHint.FLAG],
		str(Save.d["tutorial"])
	)
	await done(m)
	s = setup("thief", 6.0)
	m = s[0]
	pp = s[1]
	aim_at(pp, (s[2] as Hunter).pos)
	ok("thief: a new save has not seen it", not Save.d["tutorial"][RecastHint.FLAG])
	pp.ak.use_e()
	_open(m, pp, "e")
	m.step(DT)
	var want := "%s AGAIN to blink" % Settings.key_cap("signature")
	ok("thief e: the first window sets the flag", Save.d["tutorial"][RecastHint.FLAG], str(Save.d["tutorial"]))
	ok("the line is the key and the kit's own verb", RecastHint.line(pp.ak, "e") == want, RecastHint.line(pp.ak, "e"))
	ok("and it never repeats in this save", RecastHint.opened(pp.ak, pp.ak.recast_window()) == "")
	await done(m)
	var old := {"matches": 4, "tutorial": {}}
	RecastHint.migrate(old)
	var young := {"matches": 0}
	RecastHint.migrate(young)
	var kept := {"matches": 4, "tutorial": {RecastHint.FLAG: false}}
	RecastHint.migrate(kept)
	ok(
		"an old save that has played skips it; a new one sees it; the field is kept",
		(
			old["tutorial"][RecastHint.FLAG]
			and not young["tutorial"][RecastHint.FLAG]
			and not kept["tutorial"][RecastHint.FLAG]
		)
	)


## Dolm's dash left alone: the window runs out and the slot shows EXPIRED (never closes silently). Ostra's
## seed no longer runs out (it waits at full size for the recast), so a timed, non-auto window stands in.
func _expired() -> void:
	var s := setup("dolm", 6.0)
	var m: Match = s[0]
	var pp: Hunter = s[1]
	aim_at(pp, s[2].pos)
	first(m, pp, "dash")
	var w := _open(m, pp, "dash")
	step(m, float(w.get("left", 0.0)) + 0.3)
	ok(
		"dolm dash: an unused window shows EXPIRED",
		String(pp.ak.cue.get("exp_slot", "")) == "dash" and float(pp.ak.cue.get("exp_t", 0.0)) > 0.0,
		str(pp.ak.cue.get("exp_slot", ""))
	)
	await done(m)


## Ostra's E again 0.1s before the 0.3s minimum: buffered, the seed pops the moment the recast arms.
func _buffered() -> void:
	var s := setup("ostra", 6.0)
	var m: Match = s[0]
	var pp: Hunter = s[1]
	var kk := pp.ak as OstraKit
	aim_at(pp, s[2].pos)
	pp.ak.use_e()
	var w := _open(m, pp, "e")
	ok(
		"ostra e: no world marker on the seed, the slot still pulses",
		not bool(w.get("marker", true)) and String(w.get("slot", "")) == "e",
		str(w)
	)
	var min_t := float(kk.e_def()["min_recast"])
	while not kk.seed.is_empty() and float(kk.seed["t"]) < min_t - ArchKit.RECAST_BUFFER * 0.6:
		m.step(DT)
	pp.ak.use_e()
	var held := not kk.seed.is_empty()
	step(m, ArchKit.RECAST_BUFFER)
	var popped := kk.seed.is_empty()
	ok("ostra e: an early press is buffered into the window", held and popped, "held %s popped %s" % [held, popped])
	await done(m)


## Marks/stacks/Daze reach the badge list with a time left: Thief Marks, Vex's Daze, Sparkle's Sparks.
func _badges() -> void:
	for hero in ["thief", "gunslinger", "mage"]:
		var s := setup(hero, 6.0)
		var m: Match = s[0]
		var pp: Hunter = s[1]
		var tt: Hunter = s[2]
		match hero:
			"thief":
				(pp.ak as ThiefKit).add_mark(tt, 2, true)
			"gunslinger":
				(pp.ak as GunslingerKit).daze(tt, 2.0)
			"mage":
				(pp.ak as MageKit).sparks[tt.get_instance_id()] = {"e": tt, "n": 2, "t": 3.0}
		m.step(DT)
		var marks: Array = pp.ak.cue.get("marks", [])
		var mine := marks.filter(
			func(mk): return mk["e"] == tt and float(mk["left"]) > 0.0 and float(mk["total"]) > 0.0
		)
		ok("%s: the foe's badge shows its mark and time left" % hero, mine.size() == 1, str(mine))
		await done(m)


## The world marker and the foe badge draw no key and no word: only a count may show (DECISIONS 2026-11-11).
func _world_plain() -> void:
	var hh := StubHud.new()
	main.add_child(hh)
	hh.add_child(hh.c)
	var open := RecastCue.window("e", 2.0, 3.0, Vector3.ZERO)
	var late := RecastCue.window("e", 0.3, 3.0, Vector3.ZERO, false)
	var mk := RecastCue.mark(null, 0, 2.0, 3.0, false)
	var counted := RecastCue.mark(null, 3, 2.0, 3.0, true)
	hh.c.draw.connect(
		func():
			RecastCue._marker(hh, Vector2(50, 50), open, Color.WHITE)
			RecastCue._marker(hh, Vector2(50, 50), late, Color.WHITE)
			RecastCue._badge(hh, Vector2(100, 50), mk, Color.WHITE)
			RecastCue._badge(hh, Vector2(100, 50), counted, Color.WHITE)
	)
	hh.c.queue_redraw()
	for i in 3:
		await main.get_tree().process_frame
	ok("world marker and badge: no key letter, no word (only the count 3)", hh.texts == ["3"], str(hh.texts))
	hh.queue_free()


## On the owner's screen the badge carries the foe's state, so the kit's world copy of it hides there: Sable's Mark
## pips, Sparkle's Static marker (its count and pips, the Live ring when full; the sparks on the body stay), Neve's
## frost glow. Seen by anyone else (the same kit not local) the world art shows.
func _split() -> void:
	for hero in ["thief", "mage", "rimewright"]:
		var s := setup(hero, 6.0)
		var m: Match = s[0]
		var pp: Hunter = s[1]
		var tt: Hunter = s[2]
		var key := tt.get_instance_id()
		match hero:
			"thief":
				(pp.ak as ThiefKit).add_mark(tt, 3, true)
			"mage":
				(pp.ak as MageKit).sparks[key] = {"e": tt, "n": int(pp.ak.res_def()["max"]), "t": 3.0}
			"rimewright":
				(pp.ak as RimewrightKit).fan_hits[key] = {"t": tt, "n": 5, "left": 3.0}
		m.step(DT)
		var badge := (pp.ak.cue.get("marks", []) as Array).any(func(mk): return mk["e"] == tt)
		ok(
			"%s: the owner reads the foe's badge, the kit's world copy hides" % hero,
			badge and not _world_art(m, pp, tt),
			"badge %s art %s" % [badge, _world_art(m, pp, tt)]
		)
		pp.ctrl = "idle"
		m.step(DT)
		ok("%s: anyone else sees the kit's world art on the foe" % hero, _world_art(m, pp, tt))
		await done(m)


## Whether the kit's own state art on T shows this step.
func _world_art(m: Match, pp: Hunter, tt: Hunter) -> bool:
	var key := tt.get_instance_id()
	match pp.arch:
		"thief":
			var pip: Dictionary = (pp.ak as ThiefKit).pips.get(key, {})
			return not pip.is_empty() and (pip["node"] as Node3D).visible
		"mage":
			var mk: Dictionary = VVFx.of(m).markers.get("vs%d" % key, {})
			return not mk.is_empty() and ((mk["node"] as Node3D).get_node("Pips") as Node3D).visible
		"rimewright":
			return pp.ak.lk().showing("frost%d" % key)
	return false
