extends RefCounted
## --evo-check: evolution by species (Evo, content/rules/evolve.json, docs/decisions/0024).
## Each condition (level, Ink, trade) evolves the Boki, a branch follows its leading affinity, a Boki
## never evolves into a species without art and does once the art exists, levels stop at the cap,
## a v11 save keeps its levels and forms, bosses and the wild drop Inks, and bred babies are 50/50
## female and male whatever their parents are. Test lines are put into the loaded rules and taken
## out again; the save is never written.

const SEX_BABIES := 600           # babies bred per parent pair: enough for a 50/50 split to show
const SEX_SLACK := 0.07           # how far from half the split may land (about 3.4 standard errors)
const INK_RUNS := 4000            # expeditions rolled for the wild Ink rate
const INK_SLACK := 0.015          # how far from the data's rate the rolled one may land

var bad := 0
var _added: Array = []

## Prints an EVO ok or FAIL line and counts failures.
func ok(cond: bool, what: String) -> void:
	print("EVO %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A test line in the loaded rules (removed at the end).
func _line(sp: String, line: Dictionary) -> void:
	var lines: Dictionary = Evo.rules()["lines"]
	_added.append([sp, lines.get(sp)])
	lines[sp] = line

func _kin(sp: String, lv: int) -> Dictionary:
	var rec := Save.new_kin(sp)
	rec["level"] = lv
	Evo.ensure(rec)
	return rec

## Runs the check and quits with 1 on any failure.
func run(main: Node) -> void:
	Save.no_write = true
	var old := Save.d
	Save.d = Save.fresh()
	_data()
	_level()
	_item()
	_trade()
	_art_gate()
	_cap()
	_migrate()
	_inks()
	_sex()
	var lines: Dictionary = Evo.rules()["lines"]
	for a in _added:
		if a[1] == null: lines.erase(a[0])
		else: lines[a[0]] = a[1]
	Save.d = old
	print("EVO %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## Every line in the data is well formed: a level for level lines, a real Ink, a real affinity.
func _data() -> void:
	var lines: Dictionary = Evo.rules()["lines"]
	var wrong: Array = []
	for sp in lines:
		var into: Array = lines[sp].get("into", [])
		if into.is_empty(): wrong.append(sp)
		for o in into:
			var id := String(o.get("id", ""))
			if id == "" or id != id.to_lower(): wrong.append(sp)
			var ink := String(Goods.good(String(o.get("item", ""))).get("kind", ""))
			if o.has("item") and ink != "ink": wrong.append(sp)
			if o.has("path") and not Evo.AFF.has(String(o["path"])): wrong.append(sp)
			var by_level: bool = not o.has("item") and not o.get("trade", false)
			if by_level and int(lines[sp].get("level", 0)) < 2: wrong.append(sp)
	ok(wrong.is_empty() and lines.size() > 0,
		"every evolution line in evolve.json is well formed (%d lines; wrong: %s)" % [lines.size(), str(wrong)])
	ok(Evo.cap() == 100, "the level cap is 100 (%d)" % Evo.cap())
	var erm: Array = lines.get("ermink", {}).get("into", [])
	var jar: Array = lines.get("jarmit", {}).get("into", [])
	ok(erm.size() == 9 and jar.size() == 3, "Ermink has 9 Ink forms and Jarmit 3 Ink branches")

## Level: it evolves at its own level, not before; a branch follows its leading affinity.
func _level() -> void:
	_line("pebbit", {"level": 10, "into": [{"id": "cindle"}]})
	var rec := _kin("pebbit", 9)
	var ev := Evo.on_level(rec)
	ok(rec["species"] == "pebbit" and String(ev.get("kind", "")) != "form",
		"level: a Boki below its evolve level stays (level 9 of 10)")
	rec["level"] = 10
	var forms := (rec["forms"] as Array).size()
	ev = Evo.on_level(rec)
	var grew: bool = (rec["forms"] as Array).size() == forms + 1 and rec["was"] == ["pebbit"]
	ok(rec["species"] == "cindle" and String(ev.get("kind", "")) == "form" and grew,
		"level: at its evolve level it evolves (%s, was %s)" % [rec["species"], str(rec["was"])])
	var said := Evo.describe(ev, rec)
	ok(String(ev.get("to", "")) == String(Data.KIN["cindle"]["name"]) and said.contains(String(ev["to"])),
		"level: the event names the new species: %s" % said)
	_line("glintmole", {"level": 5,
		"into": [{"id": "burrlet", "path": "fierce"}, {"id": "puddlet", "path": "swift"}]})
	var sw := _kin("glintmole", 5)
	Evo.add(sw, "swift", 500.0)
	Evo.on_level(sw)
	var fi := _kin("glintmole", 5)
	Evo.add(fi, "fierce", 500.0)
	Evo.on_level(fi)
	ok(sw["species"] == "puddlet" and fi["species"] == "burrlet",
		"level: a branch follows the leading affinity (swift %s, fierce %s)" % [sw["species"], fi["species"]])

## Item: only the right Ink, used from the goods, evolves it; it's used up only when it works.
func _item() -> void:
	_line("zapple", {"into": [{"id": "wisplet", "item": "ink_lunar"}, {"id": "kestrike", "item": "ink_storm"}]})
	var rec := _kin("zapple", 99)
	Evo.on_level(rec)
	ok(rec["species"] == "zapple", "item: an Ink line never evolves by level")
	ok(Evo.use_ink(rec, "ink_lunar").is_empty() and rec["species"] == "zapple",
		"item: no Ink in the goods, no evolution")
	Goods.give("good:ink_ember")
	ok(Evo.use_ink(rec, "ink_ember").is_empty() and Goods.have("good:ink_ember") == 1,
		"item: the wrong Ink does nothing and is kept")
	Goods.give("good:ink_storm")
	var ev := Evo.use_ink(rec, "ink_storm")
	var said := Evo.describe(ev, rec)
	ok(rec["species"] == "kestrike" and Goods.have("good:ink_storm") == 0 and said.contains("Storm Ink"),
		"item: the Storm Ink picks its branch and is used up: %s" % said)

## Trade: a trade line evolves only when traded.
func _trade() -> void:
	_line("selenfin", {"into": [{"id": "thrumbird", "trade": true}]})
	var rec := _kin("selenfin", 60)
	Evo.on_level(rec)
	ok(rec["species"] == "selenfin" and Evo.try_evolve(rec, "item", "ink_tide").is_empty(),
		"trade: a trade line never evolves by level or Ink")
	var ev := Evo.try_evolve(rec, "trade")
	ok(rec["species"] == "thrumbird" and String(ev.get("how", "")) == "trade",
		"trade: traded, it evolves (%s)" % rec["species"])

## The art gate: never into a species without data, model and framing; it waits, then evolves.
func _art_gate() -> void:
	var real := _kin("cindle", 60)
	Evo.on_level(real)
	ok(real["species"] == "cindle" and not Evo.has_art("vespox"),
		"art gate: a level-60 Vespyx waits, Vespox has no model yet")
	var no_art := ""
	for id in Data.KIN:
		if no_art == "" and not BokiRig.FRAME.has(id):
			no_art = id
	ok(no_art != "" and not Evo.has_art(no_art) and Evo.has_art("cindle"),
		"art gate: a species with data but no rig framing (%s) has no art; Vespyx does" % no_art)
	_line("hivara", {"level": 8, "into": [{"id": no_art}]})
	var rec := _kin("hivara", 20)
	Evo.on_level(rec)
	ok(rec["species"] == "hivara", "art gate: it doesn't evolve into %s (no art) past its level" % no_art)
	Save.d["roster"] = [rec]
	ok(Evo.catch_up(Save.d["roster"]).is_empty() and rec["species"] == "hivara",
		"art gate: loading changes nothing while the art is missing")
	_line("hivara", {"level": 8, "into": [{"id": "cindle"}]})     # the art lands
	var evs := Evo.catch_up(Save.d["roster"])
	var queued := (rec.get("pending_evo", []) as Array).size()
	ok(rec["species"] == "cindle" and evs.size() == 1 and queued == 1,
		"art gate: once the art exists it evolves on load, and home plays it")
	Save.d["roster"] = []

## The cap: levels stop at 100, and generated kin too.
func _cap() -> void:
	var rec := _kin("pebbit", 99)
	Evo.level_up(rec)
	Evo.level_up(rec)
	ok(int(rec["level"]) == 100, "cap: level-ups stop at 100 (%d)" % int(rec["level"]))
	var wild := _kin("rimeshrew", 140)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	Evo.simulate(wild, rng)
	ok(int(wild["level"]) == 100, "cap: a generated kin stops at 100 too (%d)" % int(wild["level"]))

## Save v11 -> v12: levels and forms kept, over-cap levels come down, old form names kept.
func _migrate() -> void:
	var four := ["fierce", "fierce", "swift", "fierce"]
	var a := {"species": "cindle", "name": "Ash", "level": 18, "forms": four.duplicate(), "muts": []}
	var b := {"species": "puddlet", "name": "Dew", "level": 130, "forms": [], "muts": []}
	var lost := {"species": "burrlet", "name": "Moss", "level": 9, "forms": ["steadfast", "steadfast"],
		"muts": []}
	var data := {"v": 11, "roster": [a, b], "lost_kin": [{"rec": lost}]}
	Evo.migrate(data)
	Evo.migrate(data)          # twice is the same as once
	ok(int(a["level"]) == 18 and a["forms"] == four and int(b["level"]) == 100,
		"migrate: levels and forms kept, 130 comes down to the cap (%d, %d)" % [int(a["level"]), int(b["level"])])
	var names := [Evo.form_name(a), Evo.form_name(b), Evo.form_name(lost)]
	ok(names == ["Cindrend", "Prismander", "Burrward"] and a["was"] == [],
		"migrate: old form names kept %s" % str(names))
	ok(Save.VERSION == 12 and Save.MIGRATIONS.get(11, "") == "_migrate_11_to_12",
		"migrate: the save is version 12 with an 11 -> 12 step")
	_line("cindle", {"level": 16, "into": [{"id": "pebbit"}]})
	var ev := Evo.on_level(a)
	var on: bool = Evo.form_name(a) == String(Data.KIN["pebbit"]["name"]) and String(ev.get("from", "")) == "Cindrend"
	ok(a["species"] == "pebbit" and on,
		"migrate: an old form evolves on, from %s to %s" % [ev.get("from", ""), Evo.form_name(a)])

## Inks: a boss of an Ink's type gives its Ink to its killer; the wild gives one now and then.
func _inks() -> void:
	var types := ["ember", "tide", "bloom", "storm", "frost", "shadow", "lunar", "prism", "wyrm"]
	var missing: Array = []
	for t in types:
		var named := Goods.name_of("good:ink_" + t) == String(t).capitalize() + " Ink"
		if String(Goods.good("ink_" + t).get("kind", "")) != "ink" or not named: missing.append(t)
	ok(missing.is_empty(), "inks: all nine Inks are market goods named '<Type> Ink' (missing: %s)" % str(missing))
	var boss_inks: Array = []
	for bid in Data.BOSSES:
		if Data.MOBS[bid].has("ink"):
			boss_inks.append(bid)
			var ink := String(Data.MOBS[bid]["ink"])
			ok(types.has(ink), "inks: %s drops a real Ink (%s)" % [bid, ink])
	ok(boss_inks.has("serpent"),
		"inks: the Sky Serpent (Wyrm) drops the Wyrm Ink (bosses with an Ink: %s)" % str(boss_inks))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var got := Goods.on_result(1, rng, {"ink_wyrm": 1, "bosses": 1})
	ok(got.has("good:ink_wyrm") and Goods.have("good:ink_wyrm") >= 1,
		"inks: the killer's ink_wyrm stat comes home as a Wyrm Ink (%s)" % str(got))
	var wild := 0
	for i in INK_RUNS:
		for key in Goods.on_result(0, rng):
			if String(Goods.good(Goods.id_of(key)).get("kind", "")) == "ink": wild += 1
	var rate := float(wild) / INK_RUNS
	var want := float(Goods.rules()["finds"]["ink"])
	ok(absf(rate - want) < INK_SLACK and want <= 0.1,
		"inks: wild Inks are rare, %.3f per expedition (data %.2f)" % [rate, want])

## Bred babies roll their own sex, 50/50, whatever their parents' sexes.
func _sex() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for pair in [["f", "f"], ["m", "m"], ["f", "m"]]:
		var a := _kin("cindle", 10)
		a["dna"]["sex"] = pair[0]
		var b := _kin("cindle", 10)
		b["dna"]["sex"] = pair[1]
		var f := 0
		for i in SEX_BABIES:
			if String(Care.breed(a, b, rng)["dna"]["sex"]) == "f": f += 1
		var share := float(f) / SEX_BABIES
		ok(absf(share - 0.5) < SEX_SLACK,
			"sex: babies of %s+%s parents are %.0f%% female (50/50)" % [pair[0], pair[1], share * 100.0])
