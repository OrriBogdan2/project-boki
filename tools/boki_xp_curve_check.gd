extends RefCounted
## --boki-xp-curve-check: the Boki XP curve (Evo.xp_to, content/rules/evolve.json "xp", docs/GARDEN_XP.md).
## Two hours of typical play (the same gains the game gives: Evo.run_xp) bring each starter line
## (Vespyx cindle, Prismander puddlet, Mycroll burrlet) to its first evolution level and Ermink
## (the Minkee egg, evolved by Ink at any level) to level 5; later evolutions stay several sessions
## away; a Boki never evolves into a form with no model; a v12 save keeps each Boki's share of
## the way to its next level. The save is never written.

const STARTERS := ["cindle", "puddlet", "burrlet"]
const SESSION_RUNS := 4          # expeditions in two hours (about 30 min each with the garden between)
const SESSION_KNOCKS := 2        # knocks per expedition
const FIRST_LEVEL := 5           # level the starters evolve at and Ermink reaches in a session
const ELDER_SESSIONS := 8        # Lv 16 must take at least this many two-hour sessions
const GROWN_SESSIONS := 3        # a first form at Lv 8 (non-starters) must take at least this many

var bad := 0

## Prints an XPC ok or FAIL line and counts failures.
func ok(cond: bool, what: String) -> void:
	print("XPC %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## Runs the check and quits with 1 on any failure.
func run(main: Node) -> void:
	Save.no_write = true
	var old := Save.d
	Save.d = Save.fresh()
	_curve()
	_session()
	_later()
	_art_gate()
	_migrate()
	Save.d = old
	print("XPC %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## Two hours: expeditions alternate lost and won, SESSION_KNOCKS knocks each. Returns the XP gained.
func _play(rec: Dictionary, runs: int) -> int:
	var total := 0
	for i in runs:
		var xp := Evo.run_xp(i % 2 == 1, SESSION_KNOCKS, true)
		total += xp
		Evo.add_xp(rec, xp, func(): Evo.on_level(rec))
	return total

## The XP of one two-hour session.
func _session_xp() -> int:
	var lost := Evo.run_xp(false, SESSION_KNOCKS, true)
	var won := Evo.run_xp(true, SESSION_KNOCKS, true)
	return (lost + won) * SESSION_RUNS / 2

## Each level costs more than the last, and the first four levels are under a session of XP.
func _curve() -> void:
	var rising := true
	for lv in range(1, Evo.cap() - 1):
		rising = rising and Evo.xp_to(lv + 1) > Evo.xp_to(lv)
	ok(rising, "curve: every level costs more than the one before (1 to %d)" % Evo.cap())
	var to_first := Evo.xp_between(1, FIRST_LEVEL)
	ok(Evo.xp_to(1) > 0 and to_first <= _session_xp(),
		"curve: Lv 1 to %d takes %d XP, a session gives %d" % [FIRST_LEVEL, to_first, _session_xp()])

## Two hours of play: starters reach their first form's level (and not after one run), Ermink reaches 5.
func _session() -> void:
	for sp in STARTERS:
		var line: Dictionary = Evo.rules()["lines"][sp]
		var rec := Save.new_kin(sp)
		Evo.ensure(rec)
		var gained := _play(rec, SESSION_RUNS)
		ok(int(line["level"]) == FIRST_LEVEL and int(rec["level"]) >= FIRST_LEVEL,
			"session: %s evolves at Lv 5, is Lv %d after 2 h (%d XP)" % [sp, int(rec["level"]), gained])
		var early := Save.new_kin(sp)
		Evo.ensure(early)
		_play(early, 1)
		ok(Evo.next_for(early, "level") == "",
			"session: %s is not ready after one expedition (Lv %d)" % [sp, int(early["level"])])
	var minkee := Save.new_kin("ermink")
	Evo.ensure(minkee)
	_play(minkee, SESSION_RUNS)
	var by_ink: bool = Evo.next_for(minkee, "item", "ink_ember") == "flarmink"
	var by_level: bool = Evo.next_for(minkee, "level") != ""
	ok(int(minkee["level"]) >= FIRST_LEVEL and not by_level and by_ink,
		"session: Ermink is Lv %d after 2 h, waits for an Ink, never a level" % int(minkee["level"]))

## Later evolutions stay out: Elder (Lv 16) and non-starter first forms (Lv 8) take many sessions.
func _later() -> void:
	var elder: int = Evo.xp_between(1, 16)
	ok(elder >= ELDER_SESSIONS * _session_xp(),
		"later: Lv 16 is %d XP, %.1f sessions (min %d)" % [elder, float(elder) / _session_xp(), ELDER_SESSIONS])
	var short: Array = []
	for sp in Evo.rules()["lines"]:
		var line: Dictionary = Evo.rules()["lines"][sp]
		var near: bool = Evo.xp_between(1, int(line.get("level", 99))) < GROWN_SESSIONS * _session_xp()
		if line.has("level") and not STARTERS.has(sp) and near:
			short.append(sp)
	ok(short.is_empty(), "later: other level lines are %d+ sessions away (short: %s)" % [GROWN_SESSIONS, str(short)])

## A starter at its level takes the form only when the model exists; without one it keeps waiting.
func _art_gate() -> void:
	for sp in STARTERS:
		var rec := Save.new_kin(sp)
		rec["level"] = FIRST_LEVEL
		Evo.ensure(rec)
		var to := Evo.next_for(rec, "level")
		Evo.on_level(rec)
		var expect: String = to if Evo.has_art(to) else sp
		var shown := "%s -> %s (model: %s), is %s" % [sp, to, str(Evo.has_art(to)), rec["species"]]
		ok(to != "" and rec["species"] == expect, "art gate: at Lv %d %s" % [FIRST_LEVEL, shown])

## v12 -> v13: a Boki keeps its share of the way to the next level; old levels and 0 XP stay put.
func _migrate() -> void:
	var half := {"species": "cindle", "level": 4, "xp": 200}
	var fresh := {"species": "puddlet", "level": 10, "xp": 0}
	var lost := {"species": "burrlet", "level": 2, "xp": 150}
	var data := {"v": 12, "roster": [half, fresh], "lost_kin": [{"rec": lost}]}
	var step: bool = Save.MIGRATIONS.get(12, "") == "_migrate_12_to_13"
	ok(Save.VERSION >= 13 and step, "migrate: the save has a 12 -> 13 step")
	ok(Save.migrate(data) and int(data["v"]) == Save.VERSION, "migrate: a v12 save upgrades to v%d" % Save.VERSION)
	var want := roundi(0.5 * Evo.xp_to(4))
	var kept: bool = int(half["level"]) == 4 and int(fresh["level"]) == 10 and int(fresh["xp"]) == 0
	ok(absi(int(half["xp"]) - want) <= 1 and kept,
		"migrate: Lv 4 with 200 of 400 XP now has %d of %d, levels unchanged" % [int(half["xp"]), Evo.xp_to(4)])
	ok(int(lost["xp"]) < Evo.xp_to(2),
		"migrate: a lost Boki's XP stays under its level's cost (%d of %d)" % [int(lost["xp"]), Evo.xp_to(2)])
