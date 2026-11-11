extends RefCounted
## --stat-cause-check: play trains a stat and says why (GARDEN.md 3, lever 2).
##   a toy use and a race each write a cause line; the Boki card shows the four bars, the cap mark and
##   the last change with its cause under each stat; the cap still holds; no letter grades.

var fails := 0

func ok(cond: bool, what: String) -> void:
	print("STATCAUSE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1

func _labels(box: Control) -> Array:
	return box.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)

func run(m: Node) -> void:
	Save.no_write = true
	var rec := Save.new_kin("zapple", "Pip")
	Care.ensure(rec)
	var box := VBoxContainer.new()
	StatBudgetView.fill(box, rec)
	ok(_labels(box).count("No training yet") == 4, "before any play the card says so under all four stats")
	box.free()
	ok(StatCause.gain(rec, "speed", 2, "race") == 2, "a race trains Speed by 2")
	ok(StatCause.gain(rec, "power", 3, "toy") == 3, "a toy trains Power by 3")
	ok((rec["journal"] as Array).size() == 2, "each gain wrote one journal line")
	var now := Time.get_unix_time_from_system()
	var race_line := StatCause.last(rec, "speed", now + 300.0)
	var toy_line := StatCause.last(rec, "power", now + 10.0)
	ok(race_line == "+2 Speed from the race, 5 min ago", "the race line reads '%s'" % race_line)
	ok(toy_line == "+3 Power from a toy, just now", "the toy line reads '%s'" % toy_line)
	ok(StatCause.last(rec, "guard") == "", "a stat with no gain has no line")
	StatCause.gain(rec, "speed", 1, "drill")
	var drill_line := StatCause.last(rec, "speed", now + 7260.0)
	ok(drill_line == "+1 Speed from yard training, 2 h ago", "the latest change for a stat wins")
	box = VBoxContainer.new()
	StatBudgetView.fill(box, rec)
	var shown := _labels(box)
	for st in Care.STATS:
		ok(shown.has(String(Care.STATS[st]["name"])), "the card has a %s bar" % st)
	var cap := Care.stat_cap(rec)
	var starts := func(head: String) -> bool: return shown.any(func(t): return String(t).begins_with(head))
	ok(starts.call("+1 Speed from yard training"), "the card shows the Speed cause")
	ok(starts.call("+3 Power from a toy"), "the card shows the Power cause")
	ok(starts.call("3  ·  "), "the card shows the points on the Power row")
	ok(shown.any(func(t): return String(t).to_lower().contains("cap %d" % cap)), "the card names the level cap")
	var grades := ["S", "A", "B", "C", "D", "E"]
	ok(not shown.any(func(t): return grades.has(t) or String(t).contains("Grade")), "no letter grades")
	box.free()
	rec["stats"]["focus"] = Care.stat_cap(rec)
	var before := (rec["journal"] as Array).size()
	var capped := StatCause.gain(rec, "focus", 4, "toy")
	ok(capped == 0 and (rec["journal"] as Array).size() == before, "at the cap nothing gains and no line is written")
	for i in 30:
		StatCause.gain(rec, "guard", 1, "toy")
	var kept: int = (rec["journal"] as Array).size()
	ok(kept == CareJournal.KEEP, "the journal keeps the last %d lines" % CareJournal.KEEP)
	var old := Save.new_kin("zapple", "Old")
	old.erase("journal")
	ok(StatCause.last(old, "speed") == "", "an older record without a journal reads as no change")
	print("STATCAUSE DONE, failures: %d" % fails)
	m.get_tree().quit(1 if fails > 0 else 0)
