extends RefCounted
## --boki-xp-curve-check: the Boki XP curve (Game.xp_need, content/rules/garden_xp.json "curve", docs/GARDEN_XP.md).
## XP from level L to L + 1 is round(18 x L^1.5). Two hours of expeditions (the lead Boki's 40 + 40 per win +
## 10 per knock) bring each starter to Lv 5, where its first form comes; a v20 save keeps each Boki's share of
## the way to its next level. The save is never written.

const STARTERS := ["cindle", "puddlet", "burrlet"]
const FIRST_LEVEL := 5           # the level the starters evolve at (evolve.json)
const SESSION_RUNS := 4          # expeditions in two hours (about 30 min each with the garden between)
const SESSION_KNOCKS := 2        # knocks per expedition

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
	_migrate()
	Save.d = old
	print("XPC %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## The formula, a few values, and every level costing more than the one before.
func _curve() -> void:
	var want := {1: 18, 2: 51, 4: 144, 5: 201, 10: 569}
	var wrong: Array = []
	for lv in want:
		if Game.xp_need(lv) != want[lv]:
			wrong.append("%d: %d" % [lv, Game.xp_need(lv)])
	ok(wrong.is_empty(), "curve: round(18 x L^1.5) at Lv 1, 2, 4, 5, 10 (wrong: %s)" % str(wrong))
	var rising := true
	for lv in range(1, Evo.cap() - 1):
		rising = rising and Game.xp_need(lv + 1) > Game.xp_need(lv)
	ok(rising, "curve: every level costs more than the one before (1 to %d)" % Evo.cap())

## Two hours of expeditions (lost, won, lost, won; 2 knocks each): a starter reaches Lv 5 and evolves, and
## it is not ready after one expedition.
func _session() -> void:
	for sp in STARTERS:
		var line: Dictionary = Evo.rules()["lines"][sp]
		var early := Save.new_kin(sp)
		Evo.ensure(early)
		Game.add_xp(early, 40 + SESSION_KNOCKS * 10, {})
		ok(Evo.next_for(early, "level") == "", "session: %s is not ready after one expedition (Lv %d)" % [sp, early["level"]])
		var rec := Save.new_kin(sp)
		Evo.ensure(rec)
		for i in SESSION_RUNS:
			Game.add_xp(rec, 40 + (40 if i % 2 == 1 else 0) + SESSION_KNOCKS * 10, {})
		ok(int(line["level"]) == FIRST_LEVEL and int(rec["level"]) >= FIRST_LEVEL,
			"session: %s evolves at Lv %d and is Lv %d after 2 h" % [sp, int(line["level"]), int(rec["level"])])

## v20 -> v21: a Boki keeps its share of the way to the next level; levels and 0 XP stay put.
func _migrate() -> void:
	var half := {"species": "cindle", "level": 4, "xp": 100}
	var fresh := {"species": "puddlet", "level": 10, "xp": 0}
	var lost := {"species": "burrlet", "level": 2, "xp": 90}
	var data := {"v": 20, "roster": [half, fresh], "lost_kin": [{"rec": lost}]}
	ok(Save.MIGRATIONS.get(20, "") == "_migrate_20_to_21", "migrate: the save has a 20 -> 21 step")
	ok(Save.migrate(data) and int(data["v"]) == Save.VERSION, "migrate: a v20 save upgrades to v%d" % Save.VERSION)
	var want := roundi(0.5 * Game.xp_need(4))
	var kept: bool = int(half["level"]) == 4 and int(fresh["level"]) == 10 and int(fresh["xp"]) == 0
	ok(absi(int(half["xp"]) - want) <= 1 and kept,
		"migrate: Lv 4 with 100 of 200 XP now has %d of %d, levels unchanged" % [int(half["xp"]), Game.xp_need(4)])
	ok(int(lost["xp"]) < Game.xp_need(2), "migrate: a lost Boki's XP stays under its level's cost (%d)" % int(lost["xp"]))
