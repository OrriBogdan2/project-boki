extends RefCounted
## --trait-drift-check (GARDEN.md section 3, lever 3): a timid Boki living 7 in-game days with three brave
## friends moves toward them by the capped weekly amount and no more, brave rivals do not pull, the next week
## allows more, crossing a band writes one journal line, and on the real farm (base_mode on, the day clock
## wrapping) the same drift happens once a day. Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("DRIFT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _rec(species: String, who: String, bravery: float) -> Dictionary:
	var rec := Save.new_kin(species, who)
	for t in BaseDrift.TRAITS:
		rec["traits"][t] = 0.5
	rec["traits"]["bravery"] = bravery
	return rec

func _brave(rec: Dictionary) -> float:
	return float(rec["traits"]["bravery"])

func _bond_all(rec: Dictionary, others: Array, by: float) -> void:
	for o in others:
		BaseLife.add_bond(rec, o, by)

func _days(recs: Array, n: int) -> void:
	for i in n:
		BaseDrift.day(recs)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	var R := Content.rules("base_drift")
	var cap := float(R["week_cap"])
	var friend := float(Content.rules("base_life")["friend_at"])
	var timid := _rec("zapple", "Pip", 0.1)
	var braves := [_rec("cindle", "Ash", 0.9), _rec("burrlet", "Moss", 0.9), _rec("basaltoad", "Crag", 0.9)]
	_bond_all(timid, braves, friend + 0.2)
	var group := [timid] + braves
	var left := float(R["step"]) * 0.8
	_days(group, 1)
	ok(is_equal_approx(_brave(timid), 0.1 + left), "one day with three brave friends: %.3f" % _brave(timid))
	_days(group, 6)
	var moved := _brave(timid) - 0.1
	ok(is_equal_approx(moved, cap), "7 days move it exactly the weekly cap %.2f (moved %.3f)" % [cap, moved])
	ok(is_equal_approx(timid["traits"]["loyalty"], 0.5), "traits the friends share with it do not move")
	_days(group, 1)
	ok(_brave(timid) - 0.1 > cap + 0.001, "the next week allows more (%.3f)" % _brave(timid))

	var shy := _rec("zapple", "Wren", 0.1)
	var foes := [_rec("cindle", "Rex", 0.9), _rec("burrlet", "Bo", 0.9), _rec("basaltoad", "Gus", 0.9)]
	_bond_all(shy, foes, -0.9)
	_days([shy] + foes, 7)
	ok(is_equal_approx(_brave(shy), 0.1), "three brave rivals do not pull (%.3f)" % _brave(shy))
	ok(shy.get("journal", []).is_empty(), "no journal line when nothing moved")

	var edge := _rec("zapple", "Fen", 0.32)
	var pal := _rec("cindle", "Ash2", 0.9)
	_bond_all(edge, [pal], friend + 0.2)
	_days([edge, pal], 1)
	var lines: Array = edge.get("journal", [])
	ok(lines.size() == 1 and lines[0]["words"] == "is getting braver", "crossing a band writes one line: %s" % [lines])
	_days([edge, pal], 1)
	ok(edge["journal"].size() == 1, "staying in the band writes nothing more")
	ok(_brave(pal) < 0.9 and _brave(pal) > 0.85, "the brave friend drifts back toward it a little")

	await _farm()
	print("DRIFT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The real farm: BaseLife.step calls the drift when the day clock wraps.
func _farm() -> void:
	var rules: Dictionary = Content.rules("farm_build")
	rules["base_mode"] = true
	var d := Save.fresh()
	var recs := [_rec("zapple", "Pip", 0.1), _rec("cindle", "Ash", 0.9)]
	recs += [_rec("burrlet", "Moss", 0.9), _rec("basaltoad", "Crag", 0.9)]
	recs[0]["starter"] = true
	d["roster"] = recs
	d["active"] = recs[0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(d)
	var friend := float(Content.rules("base_life")["friend_at"])
	_bond_all(recs[0], [recs[1], recs[2]], friend + 0.3)
	BaseLife.add_bond(recs[0], recs[3], -0.9)
	var home = await main._hb_home()
	home.ppos = Vector3(-500, 0, -500)
	var mean := 0.9
	var want := 0.1
	for i in 3:
		want += (mean - want) * float(Content.rules("base_drift")["step"])
		home.day_t = 0.95
		home.life.step(0.2)
		home.day_t = 0.05
		home.life.step(0.2)
	var got := _brave(recs[0])
	ok(absf(got - want) < 0.01, "farm: 3 day wraps drift Pip to %.3f, rival ignored (got %.3f)" % [want, got])
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
