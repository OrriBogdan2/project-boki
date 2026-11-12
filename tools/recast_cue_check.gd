extends "res://tools/archetype_check.gd"
## --recast-cue-check: every two-step ability reports its open recast to RecastCue (DECISIONS 2026-11-08 "two-step
## abilities must be obvious and in your face"): after the first step the kit's recast_window() names the slot,
## a time left and a total, the world spot for the marker, and the local hunter's cue state carries it (so the slot
## pulse, "<KEY> AGAIN", the ring and the marker draw). Then: a timed window that runs out leaves "EXPIRED", an early
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
	await _payoffs()
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

## Dolm's dash left alone: the window runs out and the slot shows EXPIRED (never closes silently). Ostra's
## seed no longer runs out (it waits at full size for the recast), so a timed, non-auto window stands in.
func _expired() -> void:
	var s := setup("dolm", 6.0)
	var m: Match = s[0]
	var P: Hunter = s[1]
	aim_at(P, s[2].pos)
	_first(m, P, "dash")
	var w := _open(m, P, "dash")
	step(m, float(w.get("left", 0.0)) + 0.3)
	ok("dolm dash: an unused window shows EXPIRED", String(P.ak.cue.get("exp_slot", "")) == "dash"
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

# ------------------------------------------------------------------ the payoff sounds
## [hero, payoff, its own sound]: Vex's rifle has none but the shared combo chime (every payoff plays it).
const PAYOFFS := [
	["thief", "Sable's Marks cash-in", "pay_cashin"],
	["gunslinger", "Vex's Daze + rifle", "combo"],
	["mage", "Sparkle's Static Blowout", "hero_blowout"],
	["rimewright", "Neve's Chill Shatter on a knock", "rime_splinter"],
	["ostra", "Motley's full Brimseed pop on a foe", "pay_collapse"],
	["archer", "Lace's wall stun", "pay_called"],
	["gil", "Gil's Beach", "pay_flashpoint"],
	["ashwick", "Cinder's Flashover", "lw_blaze"],
	["tender", "Meeko's full Kindle", "tend_kindled"],
]

var _before := {}
var _heard := {}               # sound -> {n: times it started, db: its voice's volume}
var _meter: RefCounted         # sfx_set_check's wav measure, for the level of a file

## Steps `secs`, noting each sound that starts (Sfx.last_played moves) and the volume of its pool voice.
func _listen(m: Match, secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		t += DT
		_note()

func _note() -> void:
	for k in Sfx.last_played:
		if int(Sfx.last_played[k]) == int(_before.get(k, -1)):
			continue
		_before[k] = Sfx.last_played[k]
		var st = Sfx.streams.get(k)
		var db := -99.0
		for p in Sfx.players:
			if p.playing and ((st is Array and p.stream in st) or (not st is Array and p.stream == st)):
				db = maxf(db, p.volume_db)
		var e: Dictionary = _heard.get(k, {"n": 0, "db": db})
		e["n"] += 1
		_heard[k] = e

## File RMS (dBFS) of the quietest take of `sname`; 0 if it has no file.
func _rms(sname: String) -> float:
	var worst := 0.0
	for path in _meter._takes(sname):
		worst = minf(worst, float(_meter._measure(path)["rms"]))
	return worst

## The lowest level a payoff may have: the impact category less its tolerance (content/rules/sfx_levels.json).
func _floor() -> float:
	var lv: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/sfx_levels.json"))
	return float(lv["cats"]["impact"]) - float(lv["tolerance_db"])

func _payoffs() -> void:
	_meter = load("res://tools/sfx_set_check.gd").new()
	var lo := _floor()
	for c in PAYOFFS:
		var s := setup(String(c[0]), 6.0)
		var m: Match = s[0]
		_before = Sfx.last_played.duplicate()
		_heard = {}
		Sfx.listener = (s[2] as Hunter).pos      # nothing for the distance: the voice volume is the call's
		_land(String(c[0]), s)
		_listen(m, 1.0)
		var snd := String(c[2])
		var got: Dictionary = _heard.get(snd, {"n": 0, "db": -99.0})
		var level := _rms(snd) + float(got["db"])
		ok("%s: %s plays once" % [c[1], snd], int(got["n"]) == 1, str(_heard.keys()))
		ok("%s: %s is audible (%.1f dB, floor %.1f)" % [c[1], snd, level, lo], level >= lo)
		await done(m)
	_static_payoff_fx(lo)

## Every sound a kit's payoff_fx names exists and plays at the same floor (they play at 0 dB).
func _static_payoff_fx(lo: float) -> void:
	var rx := RegEx.create_from_string("payoff_fx\\([^\\n]*?\"([a-z]+_[a-z_0-9]+)\"")
	for f in DirAccess.get_files_at("res://scripts/arch/kits"):
		if not f.ends_with(".gd"): continue
		for hit in rx.search_all(FileAccess.get_file_as_string("res://scripts/arch/kits/" + f)):
			var snd := hit.get_string(1)
			var level := _rms(snd)
			ok("%s: payoff_fx %s has a file at the floor (%.1f dB)" % [f, snd, level], level != 0.0 and level >= lo)

## Sets up and lands the one payoff of `hero` on the target `s[2]` (setup()'s array), listening as it goes.
func _land(hero: String, s: Array) -> void:
	var m: Match = s[0]
	var P: Hunter = s[1]
	var T: Hunter = s[2]
	match hero:
		"thief":
			var K := P.ak as ThiefKit
			K.add_mark(T, 2, true)
			K.primed_on = T
			K.on_deal(T, 10.0, {"src": "shot"})
		"gunslinger":
			(P.ak as GunslingerKit).daze(T, 2.0)
			T.hurt(10.0, P, {"src": "shot"})
		"mage":
			var K := P.ak as MageKit
			K.sparks[T.get_instance_id()] = {"e": T, "n": 4, "t": 3.0}
			K._wire_hit(T, 10.0)
		"rimewright":
			(P.ak as RimewrightKit).add_chill(T)
			T.hurt(20000.0, P, {"src": "shot"})      # the knock: a Shatter a beat later
		"ostra":
			var K := P.ak as OstraKit
			K.use_e()
			_listen(m, 0.5)
			K.seed["pos"] = T.pos
			K.seed["t"] = K.seed["grow"]
			K.e_recast()
		"archer":
			_lace_pin(s)
		"gil":
			var K := P.ak as GilKit
			for mk in ["a", "b", "c"]:
				K._mark(T, mk, Color.WHITE)
		"ashwick":
			var K := P.ak as AshwickKit
			K.stoke(T)
			K.stoke(T)
		"tender":
			(P.ak as TenderKit).add_kindle(T, 5)

## Lace's Heavy Shot, fully drawn, into a wall behind the foe: the pin.
func _lace_pin(s: Array) -> void:
	var m: Match = s[0]
	var P: Hunter = s[1]
	var T: Hunter = s[2]
	var W: World = m.world
	var kind: PackedByteArray = W.kind
	var level: PackedByteArray = W.level
	for dz in range(-3, 4):
		for dx in range(2, 5):
			var i: int = W.idx(int(T.pos.x) + dx, int(T.pos.z) + dz)
			kind[i] = World.T_GROUND
			level[i] = int(s[5]) if dx < 3 else int(s[5]) + 3
	W.kind = kind
	W.level = level
	var K := P.ak as ArcherKit
	K.ch_rmb = 2.0
	K.cd["rmb"] = 0.0
	var hold := func():
		P.inp["sec_hold"] = true
		aim_at(P, T.pos)
	hold.call()
	K.press_rmb()
	_listen(m, 1.3, hold)
	P.inp["sec_hold"] = false
