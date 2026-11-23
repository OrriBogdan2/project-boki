extends RefCounted
## --journal-check: the Boki journal and the one "While you were away" card (GARDEN.md 2 and 9.7).
##   feed 3 snacks, leave, come back: the card lists the feed and the lean change, once
##   a long absence brings saved snacks; new forms and parts are lines; the journal keeps its last 20
##   lines, shows on the Boki card, never says lost, starved or sick, and an older record gets one

const FORBIDDEN := ["lost", "starv", "sick"]

var fails := 0

## Two zones open: the card groups lines under each zone, and arriving in one zone catches only its Boki up.
func _zones_part() -> void:
	Save.d["zones"] = {"bramblebank": {"open": true}, "glasswater": {"open": true}}
	var pip := Save.new_kin("zapple", "Pip")
	var gil := Save.new_kin("zapple", "Gil")
	gil["zone"] = "glasswater"
	Save.d["roster"] = [pip, gil]
	Save.d["active"] = ""
	CareJournal.arrival()
	CareJournal.note(pip, "won the Dash")
	CareJournal.note(gil, "splashed in a pool")
	var card := CareJournal.arrival(["3 wood from the saw"])
	ok(card == ["Bramblebank", "  3 wood from the saw", "  Pip: won the Dash",
			"Glasswater Shallows", "  Gil: splashed in a pool"],
		"with two zones open the card groups its lines by zone")
	_away_zones_part(pip, gil)
	Save.d["zones"].erase("glasswater")
	CareJournal.note(gil, "napped")
	ok(CareJournal.arrival() == ["Gil: napped"], "with one zone open the card is flat, as before")
	var long_ago := Time.get_unix_time_from_system() - 3600.0
	pip["needs_t"] = long_ago
	gil["needs_t"] = long_ago
	Econ.catch_up_all("glasswater")
	ok(float(gil["needs_t"]) > long_ago + 3000.0 and float(pip["needs_t"]) == long_ago,
		"arriving in a zone catches up only its Boki")

## Two zones open and a long absence: each zone's own first arrival gives its own Boki's gifts and toy
## training under its zone name (the shared away_seen no longer uses up the second zone's).
func _away_zones_part(pip: Dictionary, gil: Dictionary) -> void:
	Save.d.erase("away_zone")
	Save.d["zones"]["glasswater"]["open"] = true
	Care.ensure(pip)
	Care.ensure(gil)
	var gone := 3600.0 * float(GardenAway.rules()["gift_every_h"]) * 2.0 + 10.0
	Save.d["away_seen"] = float(Save.d["away_seen"]) - gone
	pip["zone"] = "bramblebank"
	GardenZones.here = "bramblebank"
	var first := CareJournal.arrival()
	var pip_gift := func(l): return String(l).begins_with("  Pip saved you a snack")
	var gil_gift := func(l): return String(l).begins_with("  Gil saved you a snack")
	ok(first.has("Bramblebank") and first.any(pip_gift),
		"the first zone's gifts sit under its name: %s" % str(first))
	ok(not first.any(func(l): return "Gil saved" in String(l)), "no gift from a Boki living in the other zone")
	GardenZones.here = "glasswater"
	var second := CareJournal.arrival()
	ok(second.has("Glasswater Shallows") and second.any(gil_gift),
		"the other zone still gets its own first-arrival gifts: %s" % str(second))
	ok(not second.any(func(l): return "Pip saved" in String(l)), "and none from the first zone's Boki")
	GardenZones.here = ""

## The card's lines without the zone names and their indent (two zones may be open).
func _plain(card: Array) -> Array:
	var names: Array = GardenZones.ids().map(func(id): return String(GardenZones.info(id)["name"]))
	return card.filter(func(l): return not l in names).map(func(l): return String(l).strip_edges())

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
	Evo.ensure(rec)
	var fierce := float(rec["aff"]["fierce"])
	for i in 3:
		rec["needs"]["food"] = 20.0
		Care.feed(rec, "emberberry")
	ok(float(rec["aff"]["fierce"]) == fierce + 3.0 * Evo.FOOD_AFF, "three Emberberries raise its Fierce lean")
	var two_gifts_s := 2.0 * 3600.0 * float(GardenAway.rules()["gift_every_h"])
	Save.d["away_seen"] = float(Save.d["away_seen"]) - two_gifts_s      # left a while ago
	var crops := int(Save.d["crops"].get("emberberry", 0))
	var card := _plain(CareJournal.arrival())      # coming back
	print("JOURNAL card: ", card)
	ok(card.has("Pip: ate 3 × Emberberry: Fierce lean up"), "the card lists the 3 snacks and the lean change")
	ok(card.has("Pip saved you a snack: Emberberry"), "a long absence brings saved snacks")
	ok(int(Save.d["crops"]["emberberry"]) == crops + 2, "the saved snacks are in the pantry")
	ok(CareJournal.arrival().is_empty(), "the next arrival has nothing new (one card, once)")
	CareJournal.evolved(rec, {"kind": "mutate", "aff": "fierce", "part": "horns"})
	CareJournal.note(rec, "trained power at the yard: +3")
	var next := _plain(CareJournal.arrival())
	var parts_too := ["Pip: grew horns", "Pip: trained power at the yard: +3"]
	ok(next == parts_too, "parts and other happenings use the same journal")
	var all := " ".join(card + next + rec["journal"].map(CareJournal.text)).to_lower()
	ok(FORBIDDEN.all(func(w): return not w in all), "no line says lost, starved or sick")
	for i in 30:
		CareJournal.fed(rec, "kibble" if i % 2 == 0 else "sweetbun", "")
		(rec["journal"].back() as Dictionary)["t"] = float(i)      # so the next meal is a new line
	ok((rec["journal"] as Array).size() == CareJournal.KEEP, "the journal keeps the last %d lines" % CareJournal.KEEP)
	var old := Save.new_kin("zapple", "Old")
	old.erase("journal")
	Care.ensure(old)
	ok((old["journal"] as Array).is_empty(), "an older Boki record gets a journal")
	var box := VBoxContainer.new()
	JournalCard.add(rec, box)
	var shown := box.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	ok(shown.size() > CareJournal.KEEP, "the Boki card shows its journal")
	box.free()
	_zones_part()
	print("JOURNAL DONE, failures: %d" % fails)
	m.get_tree().quit(1 if fails > 0 else 0)
