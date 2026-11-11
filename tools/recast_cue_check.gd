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
extends RefCounted
## --recast-cue-check: every recast kit answers ArchKit.recast_left() / recast_slot() from its own state: 0 before
## the first cast, open (> 0, on the right HUD slot) once the ability is out, 0 again after the recast press.
## DECISIONS 2026-11-08 "two-step abilities must be obvious"; the cue itself is scripts/ui/recast_cue.gd.

var main: Node
var fails := 0
var n := 0
var ak = null

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("RECASTCHECK %-50s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	await _e_kits()
	await _x_kits()
	await _lmb_and_dash()
	print("RECASTCHECK DONE, %d checks, failures: %d" % [n, fails])

## Opens the window with `open` (a Callable on the kit), waits `wait` s, then asserts open on `slot`; `close` ends it.
func _cycle(arch: String, label: String, slot: String, open: Callable, wait: float,
		close: Callable, wait2 := 0.3) -> void:
	var r: Array = ak.setup(arch, 8.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: ArchKit = P.ak
	ok("%s: closed before the cast" % label, K.recast_left() == 0.0)
	open.call(P, K, m)
	ak.step(m, wait)
	ok("%s: open on slot %s" % [label, slot], K.recast_left() > 0.0 and K.recast_slot() == slot,
			"left %.2f slot %s" % [K.recast_left(), K.recast_slot()])
	close.call(P, K, m)
	ak.step(m, wait2)
	ok("%s: closed after the recast" % label, K.recast_left() == 0.0, "left %.2f" % K.recast_left())
	m.queue_free()

func _e(_P: Hunter, K: ArchKit, _m: Match) -> void:
	K.cd["e"] = 0.0
	K.use_e()

func _x(P: Hunter, K: ArchKit, _m: Match) -> void:
	K.cd["x"] = 0.0
	ak.aim_at(P, P.pos + Vector3(8, 0, 0))
	HunterKeys.ult_pressed(P)

func _again(P: Hunter, _K: ArchKit, _m: Match) -> void:
	HunterKeys.ult_pressed(P)

func _e_kits() -> void:
	var press_e := func(_P, K, _m): K.use_e()
	await _cycle("thief", "thief Shadow Knife", "k1", _e, 1.0, press_e)
	await _cycle("ostra", "ostra Brimseed", "k1", _e, 1.0, press_e)
	await _cycle("tender", "tender Hearthlight", "k1", _e, 1.0, press_e)
	await _cycle("rimewright", "rimewright Rink Wall", "k1", _e, 1.0, press_e)

func _x_kits() -> void:
	await _cycle("mage", "mage Kitefall", "x", _x, 1.0, _again)
	await _cycle("ashwick", "ashwick Flue Flight", "x", _x, 0.3, _again)
	await _cycle("rimewright", "rimewright Rimelock", "x", _x, 0.6, _again)

## A press of the attack key, released after 0.1 s.
func _lmb(P: Hunter, _K: ArchKit, m: Match) -> void:
	P.inp["fire"] = true
	ak.step(m, 0.1)
	P.inp["fire"] = false

func _hop(_P: Hunter, K: ArchKit, _m: Match) -> void:
	K.on_dash(false)

func _lmb_and_dash() -> void:
	await _cycle("bulwark", "bulwark hammer recall", "primary", _lmb, 1.0, _lmb, 1.5)
	await _cycle("dolm", "dolm Rock Hop", "dash", _hop, 0.35, _hop, 1.5)
