extends RefCounted
## --garden-items-check (GARDEN_MODERN.md section 1): the shaping items in content/rules/garden_items.json.
## For every item on three sample Boki, preview() changes nothing, apply() does exactly the deltas preview
## named (and nothing else), writes one journal line, and an item that can't be used changes nothing. Also:
## the three-token limit, take_off back to the bag, Stayleaf stops forms, tokens steer the form, feeding
## through Care.feed, and an old v12 save gaining the new fields. Never touches the real save.

const TRACKED := ["xp", "level", "path", "stay", "lean", "loose", "hold", "traits", "drift"]
const SPECS := [["cindle", 1, "power"], ["zapple", 5, "focus"], ["burrlet", 12, "guard"]]

var bad := 0
var main: Node
var used := {}          # item id -> times it was usable on a sample

func ok(cond: bool, what: String) -> void:
	print("GARDENITEMS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _boki(species: String, level: int, stat: String) -> Dictionary:
	var rec := Save.new_kin(species, "T-" + species)
	rec["level"] = level
	rec["stats"][stat] = 12 + level * 6 - 1       # one point under its cap
	rec["stats"]["speed"] = mini(5, 12 + level * 6)
	rec["lean"] = {"ember": 9.0} if level > 1 else {}
	return rec

func _snap(rec: Dictionary) -> String:
	var t := {}
	for k in TRACKED:
		t[k] = rec.get(k)
	t["stats"] = rec["stats"]
	return JSON.stringify(t)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_rules()
	for spec in SPECS:
		_samples(_boki(spec[0], spec[1], spec[2]))
	for id in GardenItems.ids().filter(GardenItems.fed):
		ok(used.get(id, 0) > 0 or id == "twinbun", "%s was usable on at least one sample" % id)
	_tokens_and_stay()
	_feeding()
	_migration()
	print("GARDENITEMS DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _rules() -> void:
	var seen := {}
	var fine := true
	for it in GardenItems.rules()["items"]:
		var id := String(it["id"])
		fine = fine and not seen.has(id) and it["use"] in ["eaten", "worn"] and not (it["sources"] as Array).is_empty()
		fine = fine and it.has("name") and it.has("family") and (it["effect"] as Dictionary).has("kind")
		seen[id] = true
	ok(seen.size() == 27 and fine, "27 items, unique ids, each with a name, family, use, one effect and sources")
	var q := false
	var rec := _boki("cindle", 3, "power")
	for id in GardenItems.ids():
		q = q or "?" in String(GardenItems.preview(rec, id)["text"])
	ok(not q, "no preview line hides its effect behind a question mark")

func _samples(rec: Dictionary) -> void:
	var who := String(rec["species"])
	for id in GardenItems.ids():
		var probe: Dictionary = rec.duplicate(true)
		var before := _snap(probe)
		var lines: Array = probe["journal"]
		var jn := lines.size()
		var pv := GardenItems.preview(probe, id)
		ok(_snap(probe) == before and lines.size() == jn, "%s on %s: preview changes nothing" % [id, who])
		var after := GardenItems.apply(probe, id)
		if not pv["ok"]:
			ok(_snap(probe) == before and lines.size() == jn, "%s on %s: unusable, nothing changed" % [id, who])
			continue
		used[id] = int(used.get(id, 0)) + 1
		var exact: bool = after["ok"] and JSON.stringify(after["deltas"]) == JSON.stringify(pv["deltas"])
		var moved := {}
		for key in pv["deltas"]:
			moved[key] = true
			exact = exact and JSON.stringify(GardenItems.value(probe, key)) == JSON.stringify(pv["deltas"][key][1]) \
					and JSON.stringify(pv["deltas"][key][0]) != JSON.stringify(pv["deltas"][key][1])
		for key in TRACKED:
			if not moved.has(key):
				exact = exact and JSON.stringify(probe.get(key)) == JSON.stringify(rec.get(key))
		for s in Care.STATS:
			if not moved.has("stats." + s):
				exact = exact and int(probe["stats"][s]) == int(rec["stats"][s])
		ok(exact, "%s on %s: apply does exactly the preview (%s)" % [id, who, pv["text"]])
		var named := lines.size() == jn + 1 and CareJournal.text(lines.back()).contains(GardenItems.item_name(id))
		ok(named, "%s on %s: one journal line names it" % [id, who])

func _tokens_and_stay() -> void:
	var rec := _boki("cindle", 4, "power")
	rec["aff"] = {"fierce": 0.0, "steadfast": 0.0, "curious": 0.0, "swift": 0.0}
	rec["traits"] = {"bravery": 0.5, "temper": 0.5, "loyalty": 0.5, "curiosity": 0.5}
	for i in 3:
		GardenItems.apply(rec, "galeribbon")
	var fourth: bool = GardenItems.preview(rec, "keepstone")["ok"]
	ok(rec["path"].size() == 3 and not fourth, "three tokens at most, the fourth is refused")
	ok(Evo.leading(rec) == "swift", "three Galeribbons steer the form to swift")
	Save.d["items"]["galeribbon"] = 0
	ok(GardenItems.take_off(rec, "galeribbon") and rec["path"].size() == 2 and int(Save.d["items"]["galeribbon"]) == 1,
			"taking one off frees the slot and returns it to the bag")
	ok(not GardenItems.take_off(rec, "keepstone"), "taking off what it doesn't wear does nothing")
	rec["level"] = int(Evo.rules()["lines"]["cindle"]["level"])      # its line's form level (evolve.json)
	ok(not Evo.on_level(rec.duplicate(true)).is_empty(),
			"level %d changes it (a form, or a part while the form has no art)" % rec["level"])
	GardenItems.apply(rec, "stayleaf")
	ok(Evo.on_level(rec).is_empty(), "with a Stayleaf worn it does not evolve")
	var off := GardenItems.take_off(rec, "stayleaf")
	ok(off and not rec["stay"] and not Evo.on_level(rec).is_empty(), "taken off, it evolves again")
	_aura(rec)

## Glowmoss Sprig: a worn aura, one at a time, looks only; the model grows a GardenAura that glows at night.
func _aura(rec: Dictionary) -> void:
	var stats: Dictionary = rec["stats"].duplicate()
	var pv := GardenItems.preview(rec, "glowmoss_sprig")
	ok(pv["ok"] and pv["deltas"].keys() == ["aura"], "Glowmoss Sprig previews one change: its aura")
	Save.d["items"]["glowmoss_sprig"] = 1
	var res := GardenItems.use(rec, "glowmoss_sprig")
	ok(res["ok"] and res["look"] and rec["aura"] == "glowmoss_sprig" and rec["stats"] == stats,
			"worn: rec.aura set, stats untouched, the model redraws")
	ok(not GardenItems.preview(rec, "glowmoss_sprig")["ok"], "a second one on the same Boki is refused")
	var look := Save.new_kin(String(rec["species"]), "Look")      # a plain body: only the aura differs
	look["aura"] = rec["aura"]
	var n := Models.kin(String(rec["species"]), look)
	var pt: GardenAura = n.get_node_or_null("GardenAura")
	ok(pt != null and pt.night_only and not pt.emitting, "the model wears its aura, dark until night")
	var clock: bool = HomeWork.is_night(0.97) and not HomeWork.is_night(0.5)
	ok(GardenAura.lit(null, true) and clock, "no day clock: it glows; Home lights it at night")
	n.free()
	var off := GardenItems.take_off(rec, "glowmoss_sprig")
	ok(off and rec["aura"] == "" and int(Save.d["items"]["glowmoss_sprig"]) == 1,
			"taken off, back in the bag")
	look["aura"] = rec["aura"]
	var bare := Models.kin(String(rec["species"]), look)
	ok(bare.get_node_or_null("GardenAura") == null, "no aura worn, no aura node")
	bare.free()

func _feeding() -> void:
	var rec := _boki("zapple", 3, "speed")
	Care.change(rec, "food", 100.0)           # full: a meal would be refused, an item is not
	rec["stats"]["power"] = 4
	var res := Care.feed(rec, "thumpnut")
	ok(res["ok"] and int(rec["stats"]["power"]) == 7 and not res["full"], "Care.feed: Thumpnut when full, Power 4 to 7")
	var rinse: bool = Care.feed(rec, "rinse_melon")["ok"]
	ok(rinse and Care.lean_total(rec) == 0.0, "Rinse Melon clears the lean through Care.feed")
	var tea := Care.feed(rec, "unwind_tea")
	var power: int = rec["stats"]["power"]
	ok(tea["ok"] and int(rec["loose"]) == 7 and power == 0, "Unwind Tea: all 7 Power points go loose")

func _migration() -> void:
	var old := Save.new_kin("cindle", "Old")
	for f in ["path", "stay", "loose"]:
		old.erase(f)
	var data := {"v": 12, "roster": [old]}
	var moved := Save.migrate(data) and int(data["v"]) == Save.VERSION
	var no_aura := Save.new_kin("cindle", "Older")
	no_aura.erase("aura")
	Care.ensure(no_aura)
	ok(no_aura["aura"] == "", "a Boki saved before auras loads wearing none")
	ok(moved and old["path"] == [] and old["stay"] == false and old["loose"] == 0, "a v12 save gains path, stay, loose")
