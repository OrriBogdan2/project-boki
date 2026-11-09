extends RefCounted
## --journal-check: the Boki journal and the one "While you were away" card (GARDEN.md 2 and 9.7).
##   feed 3 snacks, leave, come back: the card lists the feed and the lean change, once
##   the journal keeps its last 20 lines, shows on the Boki card, and never says lost, starved or sick

var fails := 0

func ok(cond: bool, what: String) -> void:
	print("JOURNAL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1

func run(m: Node) -> void:
	Save.no_write = true
	var rec := Save.new_kin("zapple", "Pip")
	rec["likes"] = {"food": "sweetbun", "hates": "tonicbrew", "play": "fetch"}
	Save.d["roster"] = [rec]
	Save.d.erase("away_seen")
	Care.ensure(rec)
	ok((rec["journal"] as Array).is_empty(), "a new Boki starts with an empty journal")
	CareJournal.arrival()      # the last arrival
	for i in 3:
		rec["needs"]["food"] = 20.0
		Care.feed(rec, "kibble")
	var ember := Save.new_kin("zapple", "Ash")
	ember["likes"] = rec["likes"]
	Save.d["roster"].append(ember)
	Care.ensure(ember)
	ember["lean"] = {"fire": 2.0}      # what an element snack does once leans exist
	CareJournal.fed(ember, "kibble", {})
	var card := CareJournal.arrival()      # coming back
	print("JOURNAL card: ", card)
	ok(card.has("Pip: ate 3 × Boki kibble"), "the card lists the three snacks as one line")
	ok(card.has("Ash: ate Boki kibble: Fire lean up"), "and the lean change")
	ok(CareJournal.arrival().is_empty(), "the next arrival has nothing new (one card, once)")
	CareJournal.note(rec, "trained power at the yard: +3")
	ok(CareJournal.arrival().has("Pip: trained power at the yard: +3"), "other happenings use the same journal")
	var worst := " ".join(card).to_lower()
	ok(not ("lost" in worst or "starv" in worst or "sick" in worst), "no line says lost, starved or sick")
	for i in 30:
		CareJournal.fed(rec, "kibble" if i % 2 == 0 else "sweetbun", {})
		(rec["journal"].back() as Dictionary)["t"] = float(i)      # so the next meal is a new line
	ok((rec["journal"] as Array).size() == CareJournal.KEEP, "the journal keeps the last %d lines" % CareJournal.KEEP)
	var old := Save.new_kin("zapple", "Old")
	old.erase("journal")
	Care.ensure(old)
	ok((old["journal"] as Array).is_empty(), "an older Boki record gets a journal")
	var box := VBoxContainer.new()
	CareJournal.card(rec, box)
	var shown := box.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	ok(shown.size() > CareJournal.KEEP, "the Boki card shows its journal")
	box.free()
	print("JOURNAL DONE, failures: %d" % fails)
	m.get_tree().quit(1 if fails > 0 else 0)
