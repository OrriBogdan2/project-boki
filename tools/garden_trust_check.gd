extends RefCounted
## --garden-trust-check: care raises trust and says so (content/rules/garden_trust.json). Petting, a
## Boki's habit food and winning together each raise trust by their named amount; a repeat inside the
## cooldown does nothing; trust stays at 100 or below and never drops; every raise has one plain line;
## a habit is picked at hatch from the element, and an older save record gets one on load.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("GARDEN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _gained(rec: Dictionary, from: float, amount: float) -> bool:
	return is_equal_approx(float(rec["trust"]), from + amount)

func run(m: Node) -> void:
	Save.no_write = true
	var r := Content.rules("garden_trust")
	var cool := float(r["cooldown_h"]) * float(r["hour_s"])
	var rec := Save.new_kin("cindle", "Mira")
	rec["trust"] = 40.0
	var theme := String(Data.KIN["cindle"].get("theme", ""))
	var habit := String(rec["habit"]["food"])
	var want := String(r["food_by_element"].get(theme, r["default_food"]))
	ok(habit == want or habit == rec["likes"]["food"], "habit from its element (%s -> %s)" % [theme, habit])
	var line := Care.trust_up(rec, "pet", 1000.0)
	ok(_gained(rec, 40.0, r["pet"]) and "Mira" in line, "petting raises trust and says so: '%s'" % line)
	var again := Care.trust_up(rec, "pet", 1000.0 + cool * 0.5)
	ok(again == "" and _gained(rec, 40.0, r["pet"]), "a second pet inside the hour does nothing")
	ok(Care.trust_up(rec, "pet", 1000.0 + cool) != "", "a pet after the hour counts again")
	rec["trust"] = 40.0
	line = Care.trust_up(rec, "food", 5000.0, "emberberry")
	ok(_gained(rec, 40.0, r["food"]) and "Emberberry" in line, "habit food raises trust: '%s'" % line)
	ok(Care.trust_up(rec, "food", 5001.0, "emberberry") == "", "habit food repeated inside the hour does nothing")
	rec["trust"] = 40.0
	line = Care.trust_up(rec, "win", 5000.0)
	ok(_gained(rec, 40.0, r["win"]) and "won" in line, "winning together raises trust: '%s'" % line)
	rec["trust"] = 99.5
	ok(Care.trust_up(rec, "pet", 9000.0) != "" and float(rec["trust"]) == 100.0, "trust is capped at 100")
	ok(Care.trust_up(rec, "win", 9000.0) == "" and float(rec["trust"]) == 100.0, "a full-trust Boki gets no line")
	var old := Save.new_kin("puddlet")
	old.erase("habit")
	var data := {"roster": [old]}
	Care.migrate_habits(data)
	ok(old.has("habit") and String(old["habit"]["food"]) != "", "an older save record gets its habit on load")
	print("GARDEN DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
