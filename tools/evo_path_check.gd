extends RefCounted
## --evo-path-check (GARDEN_MODERN.md section 3, docs/decisions/0022): the path meter in EvoPath. Replays the
## four worked examples of section 3.3 with exact pip sources, then ties, caps, the Evolve prompt (level,
## Stayleaf, missing art), the Ink preview, the toy habit tally, the card block, and the table itself.
## Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("EVOPATH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A Boki of `species` (built as a Zapple and renamed: the middle forms have no Data.KIN entry yet).
func _boki(species: String, level: int, stats: Dictionary, extra := {}) -> Dictionary:
	var rec := Save.new_kin("zapple", "P-" + species)
	rec["species"] = species
	rec["level"] = level
	for s in Care.STATS:
		rec["stats"][s] = int(stats.get(s, 20))
	for t in rec["traits"]:
		rec["traits"][t] = 0.5
	rec["lean"] = {}
	rec["path"] = []
	rec["stay"] = false
	rec.merge(extra, true)
	return rec

## pips(rec) as "stat3 lean2|tokens2" per end, for exact comparison.
func _read(rec: Dictionary) -> String:
	var ends := []
	for list in EvoPath.pips(rec):
		ends.append(" ".join(list.map(func(p): return "%s%d" % [p["source"], p["count"]])))
	return "|".join(ends)

func _expect(rec: Dictionary, pips: String, win: int, what: String) -> void:
	var got := "%s -> %d" % [_read(rec), EvoPath.winner(rec)]
	ok(got == "%s -> %d" % [pips, win], "%s: %s -> end %d (got %s)" % [what, pips, win, got])

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_table()
	_examples()
	_ties_and_caps()
	_prompt()
	_inks_and_card()
	print("EVOPATH DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

func _table() -> void:
	var types: Dictionary = Lean.rules()["types"]
	var affs := GardenItems.ids().map(func(id): return GardenItems.aff_of(id))
	for sp in EvoPath.rules()["lines"]:
		var ln: Dictionary = EvoPath.rules()["lines"][sp]
		var into: Array = Evo.rules()["lines"].get(sp, {}).get("into", []).map(func(o): return String(o["id"]))
		var ends: Array = (ln["ends"] as Array).map(func(e): return String(e["form"]))
		ok(ends.size() == 2 and into == ends, "%s: two ends, evolve.json's two branches (%s)" % [sp, into])
		for e in ln["ends"]:
			var known: bool = Care.STATS.has(e["stat"]) and types.has(e["type"]) and affs.has(e["path"])
			ok(known and not (e["sports"] as Array).is_empty(),
					"%s: stat, type, token path and sports are known" % e["form"])

func _examples() -> void:
	var keep := {"lean": {"grass": Evo.LEAN_FULL}, "path": ["keepstone", "keepstone"]}
	var pip := _boki("sporcupine", 14, {"power": 46, "guard": 38}, keep)
	pip["traits"]["loyalty"] = 0.7
	_expect(pip, "stat3|lean2 tokens2 care1", 1, "Mycroll: Pip grows toward Ringrove 3 to 5")
	pip["lean"] = {"poison": Evo.LEAN_FULL}
	pip["path"] = []
	_expect(pip, "stat3 lean2|care1", 0, "Mycroll: Hush Truffle lean, stones off: Amanitusk")
	var fox := _boki("vespox", 14, {"power": 50, "speed": 30},
			{"lean": {"steel": Evo.LEAN_FULL}, "ribbons": {"tumble": {"n": 1, "week": 0}}})
	_expect(fox, "stat3 lean2 ribbons1|", 0, "Vespyx: Cinderstep, Steel, Tumble cup: Glaivyx")
	var lash := _boki("vespox", 14, {"power": 40, "speed": 50},
			{"lean": {"dark": Evo.LEAN_FULL}, "path": ["galeribbon", "galeribbon"],
			"ribbons": {"dash": {"n": 1, "week": 0}}})
	lash["traits"]["temper"] = 0.8
	_expect(lash, "care1|stat3 lean2 tokens2 ribbons1", 1, "Vespyx: hot-headed fox, Dark, Galeribbons, Dash: Lashyx")
	var tub := _boki("glassolotl", 14, {"focus": 40, "guard": 20}, {"habit": {"toy": "toy_tub"}})
	_expect(tub, "stat3 care1|", 0, "Prismander: a tub lover drifts to Chandelotl")
	tub["lean"] = {"fairy": Evo.LEAN_FULL}
	_expect(tub, "stat3 lean2 care1|", 0, "Prismander: Starfruit adds 2")
	var geo := _boki("glassolotl", 14, {"focus": 20, "guard": 40},
			{"lean": {"rock": Evo.LEAN_FULL}, "path": ["keepstone", "keepstone"], "habit": {"toy": "toy_stone"}})
	_expect(geo, "|stat3 lean2 tokens2 care1", 1, "Prismander: Cinderstep stone, Rock, Keepstones: Geodelotl")
	var chime := _boki("zapple", 6, {},
			{"lean": {"fairy": Evo.LEAN_FULL}, "ribbons": {"echo_steps": {"n": 1, "week": 0}}})
	_expect(chime, "|lean2 ribbons1", 1, "Echolop: Echo Steps ribbon and Chimegrass: Chimelop")
	var howl := _boki("zapple", 6, {}, {"lean": {"dark": Evo.LEAN_FULL}, "ribbons": {"tumble": {"n": 1, "week": 0}}})
	_expect(howl, "lean2 ribbons1|", 0, "Echolop: Hushwood Dark and a Tumble ribbon: Howlop")

func _ties_and_caps() -> void:
	var r := _boki("sporcupine", 10, {"power": 30, "guard": 30})
	_expect(r, "|", -1, "nothing at all: undecided")
	r["lean"] = {"grass": Evo.LEAN_FULL * 0.5}
	_expect(r, "|lean1", 1, "a half lean gives 1")
	r["stats"]["power"] = 31
	r["lean"] = {"grass": Evo.LEAN_FULL}
	r["path"] = ["bristlethorn"]
	_expect(r, "stat3 tokens1|lean2", 0, "4 to 2 with the stat lead")
	r["path"] = []
	r["lean"] = {"grass": Evo.LEAN_FULL * 1.5}
	_expect(r, "stat3|lean2", 0, "lean caps at 2")
	r["lean"] = {"grass": Evo.LEAN_FULL}
	r["traits"]["loyalty"] = 0.9
	_expect(r, "stat3|lean2 care1", 0, "3 to 3: the stat lead decides")
	r["stats"]["power"] = 30
	r["ribbons"] = {"shove": {"n": 4, "week": 0}}
	r["lean"] = {}
	r["traits"]["loyalty"] = 0.5
	r["path"] = ["keepstone", "keepstone", "keepstone", "keepstone"]
	_expect(r, "|tokens3 ribbons2", 1, "tokens cap at 3, ribbons at 2")
	r["path"] = []
	r["ribbons"] = {"shove": {"n": 1, "week": 0}, "tumble": {"n": 1, "week": 0}}
	_expect(r, "ribbons1|ribbons1", -1, "tied pips, tied stats: undecided")

func _prompt() -> void:
	var r := _boki("sporcupine", 35, {"power": 40, "guard": 30})
	ok(not EvoPath.due(r) and EvoPath.level(r) == 36, "level 35 Sporcupine: not due yet (evolve.json: 36)")
	r["level"] = 36
	ok(Evo.next_for(r, "level") == "" and Evo.on_level(r).get("kind", "") != "form",
			"level 36: the meter's line never evolves by level alone")
	ok(Evo.next_for(r, "path") == "amanitusk", "Evolve picks the meter's winner, not the leading affinity")
	var waits: bool = EvoPath.evolve(r).is_empty() and r["species"] == "sporcupine"
	ok(EvoPath.due(r) and EvoPath.blocked(r) == "art" and waits,
			"level 36: due, but no Amanitusk art, so it waits")
	r["stay"] = true
	ok(EvoPath.blocked(r) == "stay" and EvoPath.evolve(r).is_empty(), "a worn Stayleaf blocks Evolve")
	r["stay"] = false
	r["stats"]["guard"] = 40
	ok(EvoPath.blocked(r) == "undecided", "undecided blocks Evolve")
	ok(not EvoPath.due(_boki("pebbit", 30, {})), "a line without a branch never shows the prompt")
	var z := _boki("zapple", 16, {}, {"lean": {"fairy": Evo.LEAN_FULL}})
	ok(EvoPath.due(z) and Evo.next_for(z, "path") == "chimelop", "Echolop's line is due at its evolve.json level")

func _inks_and_card() -> void:
	var jar := _boki("jarmit", 1, {})
	ok(EvoPath.ink_previews(jar).is_empty(), "Jarmit with no Ink in the bag: no preview")
	Goods.give("good:ink_storm")
	var prev := EvoPath.ink_previews(jar)
	var one: bool = prev.size() == 1 and prev[0]["form"] == "stormit"
	ok(one and EvoPath.pips(jar).is_empty(), "a held Storm Ink previews Stormit, no pips")
	var r := _boki("sporcupine", 36, {"power": 40, "guard": 30})
	var v := VBoxContainer.new()
	EvoPathView.block(r, v, func(): pass)
	var texts := []
	var go_off := false
	for c in _all(v):
		if c is Label: texts.append((c as Label).text)
		if c is Button and (c as Button).text == "Evolve now": go_off = (c as Button).disabled
	var waits := texts.has("Art not in the game yet: it will wait.")
	ok(texts.has("?") and go_off and waits, "card: '?' silhouettes, Evolve now off while art is missing")
	ok(texts.any(func(t): return String(t).begins_with("? 3: stat lead (Power) 3")), "card lists the pip sources")
	v.free()
	var toys := HomeToys.rules()["toys"] as Dictionary
	ok(String(toys.get("toy_tub", {}).get("stat", "")) == "focus", "the splash tub trains Focus (toy habit pip)")

func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
