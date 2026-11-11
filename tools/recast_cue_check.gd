extends "res://tools/archetype_check.gd"
## --recast-cue-check: every two-step ability reports its open recast to RecastCue (DECISIONS 2026-11-08 "two-step
## abilities must be obvious and in your face"): after the first step the kit's recast_window() names the slot,
## a time left and a total, the world spot for the marker, and the local hunter's cue state carries it (so the slot
## pulse, "<KEY> AGAIN", the ring and the marker draw). Then: a window that runs out leaves "EXPIRED", an early
## press is buffered (~0.15s) into the window, and the marks/stacks/Daze reach the foe badges.

const WAIT := 4.0              # s the first step gets to open its window (Rimelock's late crack comes last)

## [hero, slot]: each recast kit, from a fresh setup with the target 6m east; _first() takes the first step.
const CASES := [["thief", "e"], ["tender", "e"], ["ostra", "e"], ["rimewright", "e"], ["rimewright", "x"],
	["juggernaut", "e"], ["mage", "x"], ["ashwick", "x"], ["bulwark", "lmb"], ["dolm", "dash"]]

func _first(m: Match, P: Hunter, slot: String) -> void:
	match slot:
		"e": P.ak.use_e()
		"x": P.ak.cast_ult()
		"dash": P.do_dash()
		"lmb":
			P.inp["fire"] = true
			m.step(DT)
			P.inp["fire"] = false

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for c in CASES:
		await _window(String(c[0]), String(c[1]))
	await _expired()
	await _buffered()
	await _badges()
	print("RECASTCUE DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Steps until the kit reports `slot`'s window (or WAIT runs out); returns it ({} if it never opened).
func _open(m: Match, P: Hunter, slot: String) -> Dictionary:
	var t := 0.0
	while t < WAIT:
		var w := P.ak.recast_window()
		if String(w.get("slot", "")) == slot:
			return w
		m.step(DT)
		t += DT
	return {}

func _window(hero: String, slot: String) -> void:
	var s := setup(hero, 6.0)
	var m: Match = s[0]
	var P: Hunter = s[1]
	aim_at(P, (s[2] as Hunter).pos)
	_first(m, P, slot)
	var w := _open(m, P, slot)
	var at = w.get("at")
	var timed := not w.is_empty() and float(w["left"]) > 0.0 and float(w["total"]) > 0.0
	var placed := at is Vector3 and (at as Vector3).is_finite()
	ok("%s %s: reports its recast window" % [hero, slot], timed and placed, str(w))
	m.step(DT)
	var cw: Dictionary = P.ak.cue.get("w", {})
	var key := RecastCue.key_of(slot)
	ok("%s %s: the local cue carries it (slot, AGAIN key)" % [hero, slot],
			String(cw.get("slot", "")) == slot and key != "", "cue %s key %s" % [cw.get("slot", "-"), key])
	await done(m)

## Ostra's seed left alone: the window runs out and the E slot shows EXPIRED (never closes silently).
func _expired() -> void:
	var s := setup("ostra", 6.0)
	var m: Match = s[0]
	var P: Hunter = s[1]
	aim_at(P, s[2].pos)
	P.ak.use_e()
	_open(m, P, "e")
	step(m, P.ak.e_t + 0.3)
	ok("ostra e: an unused window shows EXPIRED", String(P.ak.cue.get("exp_slot", "")) == "e"
			and float(P.ak.cue.get("exp_t", 0.0)) > 0.0, str(P.ak.cue.get("exp_slot", "")))
	await done(m)

## Ostra's E again 0.1s before the 0.3s minimum: buffered, the seed pops the moment the recast arms.
func _buffered() -> void:
	var s := setup("ostra", 6.0)
	var m: Match = s[0]
	var P: Hunter = s[1]
	var K := P.ak as OstraKit
	aim_at(P, s[2].pos)
	P.ak.use_e()
	_open(m, P, "e")
	var min_t := float(K.e_def()["min_recast"])
	while not K.seed.is_empty() and float(K.seed["t"]) < min_t - ArchKit.RECAST_BUFFER * 0.6:
		m.step(DT)
	P.ak.use_e()
	var held := not K.seed.is_empty()
	step(m, ArchKit.RECAST_BUFFER)
	var popped := K.seed.is_empty()
	ok("ostra e: an early press is buffered into the window", held and popped, "held %s popped %s" % [held, popped])
	await done(m)

## Marks/stacks/Daze reach the badge list with a time left: Thief Marks, Vex's Daze, Sparkle's Sparks.
func _badges() -> void:
	for hero in ["thief", "gunslinger", "mage"]:
		var s := setup(hero, 6.0)
		var m: Match = s[0]
		var P: Hunter = s[1]
		var T: Hunter = s[2]
		match hero:
			"thief": (P.ak as ThiefKit).add_mark(T, 2, true)
			"gunslinger": (P.ak as GunslingerKit).daze(T, 2.0)
			"mage": (P.ak as MageKit).sparks[T.get_instance_id()] = {"e": T, "n": 2, "t": 3.0}
		m.step(DT)
		var marks: Array = P.ak.cue.get("marks", [])
		var mine := marks.filter(func(mk): return mk["e"] == T and float(mk["left"]) > 0.0 and float(mk["total"]) > 0.0)
		ok("%s: the foe's badge shows its mark and time left" % hero, mine.size() == 1, str(mine))
		await done(m)
