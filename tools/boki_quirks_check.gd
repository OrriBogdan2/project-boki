extends RefCounted
## --boki-quirks-check: species details from the Bokidex (BokiQuirks, content/rules/boki_quirks.json).
## The data loads with every quirk and sex note, and every species in the game finds its quirk by its
## display name; the hatch-time sex roll keeps each kind's female share (all-female, nearly all
## female, born male, half and half) and is the same for the same seed, through Save.new_kin and
## Care.breed; a fast eater gets hungry faster; rain lifts or sinks the moods of the kinds that care;
## a rain-sensing Boki warns once before rain and stays quiet when none is coming; the Field Book page
## shows the quirk and the sex note, where it's found and its rarity ("?" for both until it's met), and
## the boss-egg kinds close the book. Never touches the save.

const SEEDS := 4000      # hatches rolled per kind for the share checks

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("QUIRKS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## Enough of Home for FarmChatter's rain warning: the weather, and who said what.
class FakeHome extends RefCounted:
	var raining := false
	var rain_next := true
	var weather_t := 10.0
	var said: Array = []
	func _say(k: Dictionary, line: String, _delay: float, _direct: bool) -> void:
		said.append([String(k["rec"]["species"]), line])

func _female_share(species: String) -> float:
	var fem := 0
	for i in SEEDS:
		if BokiQuirks.sex_for(species, 5000 + i) == "f": fem += 1
	return float(fem) / SEEDS

func run(main: Node) -> void:
	Save.no_write = true
	_data()
	_sexes()
	_rare_trait()
	_care()
	_rain_warning()
	_field_book(main)
	print("QUIRKS DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _data() -> void:
	var d := BokiQuirks.data()
	ok((d.get("quirk", {}) as Dictionary).size() == 120 and (d.get("sexNote", {}) as Dictionary).size() == 18,
		"the data file loads: 120 quirks, 18 sex notes")
	var missing := Data.KIN.keys().filter(func(sp): return BokiQuirks.quirk(sp) == "")
	ok(missing.is_empty(), "every species in the game has a quirk %s" % str(missing))
	ok(BokiQuirks.key("basaltoad") == "rampartoad", "a species is looked up by its display name")
	ok(BokiQuirks.sex_note("hivara") != "" and BokiQuirks.sex_note("zapple") == "",
		"sex notes only where the kind is unusual")

func _sexes() -> void:
	ok(_female_share("hivara") == 1.0 and _female_share("mossgrade") == 1.0, "all-female kinds only hatch females")
	var march := _female_share("marchleaf")
	ok(march > 0.92 and march < 0.98, "a nearly-all-female kind hatches about 95%% female (%.1f%%)" % (100.0 * march))
	ok(_female_share("limpetor") == 0.0, "a kind born male always hatches male")
	var even := _female_share("zapple")
	ok(absf(even - 0.5) < 0.03, "other kinds stay half and half (%.1f%% female)" % (100.0 * even))
	var same := true
	for i in 300:
		if BokiQuirks.sex_for("zapple", i) != Unique.sex_for_seed(i): same = false
		if BokiQuirks.sex_for("marchleaf", i) != BokiQuirks.sex_for("marchleaf", i): same = false
	ok(same, "the roll is the same for the same seed, and unchanged for half-and-half kinds")
	var all_f := true
	for i in 40:
		if Unique.sex(Save.new_kin("hivara")) != "f": all_f = false
	ok(all_f, "Save.new_kin hatches an all-female kind female")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var a := Save.new_kin("hivara")
	var b := Save.new_kin("hivara")
	var bred := true
	for i in 20:
		if Unique.sex(Care.breed(a, b, rng, "hivara")) != "f": bred = false
	ok(bred, "Care.breed keeps the kind's sexes after inheriting looks")

## Marchleaf's Nightmark: about 4% at hatch, from the seed, only that kind, kept by save and load.
func _rare_trait() -> void:
	var hits := 0
	var same := true
	for i in 10000:
		var t := BokiQuirks.rare_trait_for("marchleaf", 7000 + i)
		if t == "nightmark": hits += 1
		elif t != "": same = false
		if BokiQuirks.rare_trait_for("marchleaf", 7000 + i) != t: same = false
	ok(hits >= 300 and hits <= 500 and same,
		"Nightmark: %.1f%% of 10k seeded Marchleaf hatches, the same each time" % (hits / 100.0))
	ok(BokiQuirks.rare_trait_for("zapple", 1) == "" and not Save.new_kin("zapple").has("rare"),
		"other kinds roll no rare trait")
	var found: Dictionary = {}
	for i in 400:
		var m := Save.new_kin("marchleaf")
		found[String(m["rare"])] = m
	ok(found.has("nightmark") and found.has("") and BokiQuirks.has_trait(found["nightmark"], "nightmark")
		and BokiQuirks.rare_of(found["nightmark"])["name"] == "Nightmark" and BokiQuirks.rare_of(found[""]).is_empty(),
		"Save.new_kin rolls it at hatch (%s) and the card finds its badge text" % str(found.keys()))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var a := Save.new_kin("marchleaf")
	var kid := Care.breed(a, Save.new_kin("marchleaf"), rng, "marchleaf")
	ok(kid.has("rare"), "Care.breed rolls it for the baby too")
	var round_trip: Variant = JSON.parse_string(JSON.stringify({"roster": [found["nightmark"].duplicate(true)]}))
	ok(String(round_trip["roster"][0]["rare"]) == "nightmark", "the trait survives a save and load")
	var old: Dictionary = found["nightmark"].duplicate(true)      # an older save: Marchleaf with no roll yet
	old.erase("rare")
	var plain := Save.new_kin("zapple")
	var save_data := {"roster": [old, plain]}
	BokiQuirks.migrate(save_data)
	var rolled := String(old.get("rare", "?"))
	BokiQuirks.migrate(save_data)
	var expect := BokiQuirks.rare_trait_for("marchleaf", int(old["dna"]["seed"]))
	ok(old.has("rare") and String(old["rare"]) == rolled and rolled == expect
		and not plain.has("rare"), "an older save's Marchleaf rolls once on load (from its seed) and keeps it")

## How much food a new Boki of this kind loses in ten awake minutes.
func _food_drop(species: String) -> float:
	var rec := Save.new_kin(species)
	rec["needs"]["food"] = 90.0
	Care.tick(rec, 600.0)
	return 90.0 - Care.need(rec, "food")

## Joy after ten minutes in the rain minus joy after ten dry ones.
func _rain_mood(species: String, sleeping := false) -> float:
	var wet := Save.new_kin(species)
	wet["needs"]["joy"] = 50.0
	var dry := wet.duplicate(true)
	Care.tick(wet, 600.0, sleeping, true)
	Care.tick(dry, 600.0, sleeping, false)
	return Care.need(wet, "joy") - Care.need(dry, "joy")

func _care() -> void:
	var fast := _food_drop("rimeshrew")
	var usual := _food_drop("zapple")
	ok(absf(fast - 2.0 * usual) < 0.01, "a Rimeshrew gets hungry twice as fast (%.1f vs %.1f)" % [fast, usual])
	var joy := {}
	for sp in ["goliathite", "burrlet", "zapple"]:
		joy[sp] = _rain_mood(sp)
	ok(joy["goliathite"] < -1.0 and joy["burrlet"] > 1.0 and absf(joy["zapple"]) < 0.01,
		"rain sinks an Effigeetle's mood, lifts a Mycroll's, leaves others alone %s" % str(joy))
	ok(_rain_mood("goliathite", true) == 0.0, "a Boki asleep or indoors doesn't feel the rain")

func _rain_warning() -> void:
	var h := FakeHome.new()
	var usual := {"rec": Save.new_kin("zapple")}
	var senser := {"rec": Save.new_kin("kestrike")}
	ok(not FarmChatter._rain_warning(h, [usual]), "a Boki that can't sense rain says nothing")
	var warned := FarmChatter._rain_warning(h, [usual, senser])
	ok(warned and h.said.size() == 1 and h.said[0][0] == "kestrike" and h.said[0][1] != "",
		"a Kestrike warns that rain is coming: %s" % str(h.said))
	ok(not FarmChatter._rain_warning(h, [senser]), "it warns only once before each rain")
	h.raining = true
	FarmChatter._rain_warning(h, [senser])
	h.raining = false
	h.rain_next = false
	ok(not FarmChatter._rain_warning(h, [senser]), "no warning when the next turn stays dry")
	h.rain_next = true
	h.weather_t = 60.0
	ok(not FarmChatter._rain_warning(h, [senser]), "no warning while the rain is still far off")
	h.weather_t = 5.0
	ok(FarmChatter._rain_warning(h, [senser]), "it warns again before the next rain")

func _field_book(main: Node) -> void:
	var v := VBoxContainer.new()
	main.add_child(v)
	DexView.detail(v, "hivara", main.get_tree(), Callable())
	var texts: Array = v.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	ok(texts.has(BokiQuirks.quirk("hivara")) and texts.has(BokiQuirks.sex_note("hivara")),
		"the Field Book page shows its quirk and sex note")
	var unmet: Array = texts.filter(func(t): return t == "?")
	ok(unmet.size() >= 2 or FieldBook.form_seen("hivara"), "an unmet Boki's page shows ? for found in and rarity")
	v.queue_free()
	var book: Array = FieldBook.entries()
	var tail_rare: bool = book.slice(-3).all(func(s): return Data.is_rare(s))
	ok(tail_rare and not Data.is_rare(book[0]), "the boss-egg Boki are the last entries in the book")
	ok(DexFound.tier("pebbit") == 0 and DexFound.tier("hivara") == 2, "wild is Common, Rare Egg is Very rare")
	var wild_at := DexFound.found_in("pebbit")
	var egg_at := DexFound.found_in("hivara")
	ok(wild_at.begins_with("Expedition, The Hollow Crown: ") and egg_at.contains("Thornhive"),
		"found in: the mode and map, then regions (wild) or the boss's lair: %s | %s" % [wild_at, egg_at])
