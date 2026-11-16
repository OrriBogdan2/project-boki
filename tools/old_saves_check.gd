extends RefCounted
## --old-saves-check (AGENTS.md: old saves must load; docs/decisions/0060-garden-save-chain.md): saves written
## by the 0.24.2, 0.24.3 and 0.24.4 games (tools/fixtures/save_chain/<version>.json) load on this game.
## Each fixture holds three Boki (two with forms, one at level 130: set by hand, Evo.cap() is 100), a gem
## count, items, a breeding-nest egg, an Incubator egg and a Rare Egg on the shelf. 0.24.2 and 0.24.3 are
## save v11, 0.24.4 is v12 (there is no 0.24.2 tag; the 0.24.1 tree wrote the same v11 format as 0.24.3, so it
## stands in). They come from running that tree's own Save/Care/Evo/Incubator code. For each one: the file
## loads through Save.load_from (the .bak copy of the old file is kept), nothing is lost, the garden fields
## are added (Bramblebank open, every Boki lives there), a save and reload keeps it, and the garden (hub and
## Bramblebank) opens with every Boki that lives there. Reads the fixtures; the scratch file it loads from
## lives in user:// and is removed again (use a temp XDG_DATA_HOME).

const FIXTURES := ["v0.24.2", "v0.24.3", "v0.24.4"]
const DIR := "res://tools/fixtures/save_chain/"
const SCRATCH := "user://old_saves_check.json"

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("OLDSAVES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	Save.no_write = false      # the load keeps the .bak copy; save_game() is never called here
	Content.rules("farm_build")["base_mode"] = true
	for tag in FIXTURES:
		var text := FileAccess.get_file_as_string(DIR + tag + ".json")
		var old: Dictionary = JSON.parse_string(text)
		_load_part(tag, text, old)
		_reload_part(tag, old)
		await _garden_part(m, tag, old)
	_clean()
	Save.no_write = true
	print("OLDSAVES DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

func _write(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _clean() -> void:
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("old_saves_check"):
			DirAccess.remove_absolute("user://" + f)

func _by_uid(recs: Array) -> Dictionary:
	var out := {}
	for r in recs:
		out[String(r["uid"])] = r
	return out

func _load_part(tag: String, text: String, old: Dictionary) -> void:
	_clean()
	Save.no_write = false
	_write(SCRATCH, text)
	Save.load_from(SCRATCH)
	var d: Dictionary = Save.d
	var from := int(old["v"])
	var t := tag + ": "
	ok(int(d["v"]) == Save.VERSION and not Save.newer, t + "v%d upgrades to v%d" % [from, Save.VERSION])
	var kept := FileAccess.get_file_as_string(SCRATCH + ".bak-v%d" % from)
	ok(kept == text, t + "the old file is kept as .bak-v%d" % from)
	ok(int(d["gems"]) == int(old["gems"]) and int(d["matches"]) == int(old["matches"]) and d["name"] == old["name"],
		t + "gems, matches and the Hunter's name are kept")
	var items_kept: bool = (old["items"] as Dictionary).keys().all(
		func(k): return int(d["items"].get(k, 0)) == int(old["items"][k]))
	ok(items_kept, t + "every item count is kept")
	_boki_part(t, d, old)
	_eggs_part(t, d, old)
	var start := GardenZones.start()
	var zone_ids: Array = (d["zones"] as Dictionary).keys()
	ok(GardenZones.is_open(start) and zone_ids == [start], t + "%s is open and the others are locked" % start)

func _boki_part(t: String, d: Dictionary, old: Dictionary) -> void:
	var now := _by_uid(d["roster"])
	ok(now.size() == (old["roster"] as Array).size() and String(d["active"]) == String(old["active"]),
		t + "every Boki is still on the roster and the partner is the same")
	for was in old["roster"]:
		var rec: Dictionary = now.get(String(was["uid"]), {})
		var who := "%s the %s" % [was["name"], was["species"]]
		if rec.is_empty():
			ok(false, t + who + " is missing")
			continue
		ok(rec["species"] == was["species"] and rec["name"] == was["name"] and rec["dna"] == was["dna"]
			and is_equal_approx(float(rec["trust"]), float(was["trust"])) and int(rec["xp"]) == int(was["xp"]),
			t + who + ": species, name, inborn rolls, trust and xp are kept")
		var want := mini(int(was["level"]), Evo.cap())
		ok(int(rec["level"]) == want, t + who + ": level %d (was %d, cap %d)" % [rec["level"], was["level"], Evo.cap()])
		ok(rec.get("zone") == GardenZones.start() and rec.get("bonds") is Dictionary and rec.has("was"),
			t + who + ": has a zone, bonds and an evolution record")
		ok(String(rec.get("form_name", "")) != "" or (was.get("forms", []) as Array).is_empty(),
			t + who + ": a Boki with forms keeps a form name (%s)" % rec.get("form_name", ""))

func _eggs_part(t: String, d: Dictionary, old: Dictionary) -> void:
	var nest: Dictionary = d.get("egg", {})
	ok(nest.get("a") == old["egg"]["a"] and nest.get("b") == old["egg"]["b"] and nest.get("sp") == old["egg"]["sp"],
		t + "the breeding-nest egg is kept")
	var cradle := Incubator.eggs()
	ok(cradle.size() == 1 and cradle[0]["sp"] == old["incubator"]["eggs"][0]["sp"], t + "the Incubator egg is kept")
	var shelf := Incubator.shelf()
	ok(shelf.size() == 1 and shelf[0]["id"] == old["rare_eggs"][0]["id"], t + "the Rare Egg is kept")

## Save, then load again: what the old save held and what the migration added both survive.
func _reload_part(tag: String, old: Dictionary) -> void:
	var first: Dictionary = Save.d
	_write(SCRATCH, JSON.stringify(first))
	Save.load_from(SCRATCH)
	var d: Dictionary = Save.d
	var rows := func(x: Dictionary) -> Array:
		return (x["roster"] as Array).map(func(r): return [r["uid"], int(r["level"]), r["zone"]])
	var same: bool = int(d["v"]) == Save.VERSION and int(d["gems"]) == int(first["gems"])
	same = same and d["zones"] == first["zones"] and d["items"].size() == first["items"].size()
	same = same and rows.call(d) == rows.call(first) and rows.call(d).size() == (old["roster"] as Array).size()
	ok(same, tag + ": a save and reload keeps it all")

## The garden opens on the migrated save: the hub, then Bramblebank with every Boki that lives there.
func _garden_part(m: Node, tag: String, old: Dictionary) -> void:
	_clean()
	_write(SCRATCH, FileAccess.get_file_as_string(DIR + tag + ".json"))
	Save.no_write = true      # the running game never writes a save while the garden is open here
	Save.load_from(SCRATCH)
	var waits = load("res://tools/garden_zones_check.gd").new()
	var out := (Save.d["roster"] as Array).size()
	var cap := KinBox.farm().size()
	Game.goto("home", {"zone": GardenZones.HUB})
	var hub = await waits._arrived(m, null)
	ok(hub != null, tag + ": the hub opens")
	if hub == null:
		return
	Game.goto("home", {"zone": GardenZones.start()})
	var zone = await waits._arrived(m, hub)
	ok(zone != null and zone.kins.size() == cap and cap == mini(out, KinBox.farm_cap()),
		tag + ": %s opens with its %d Boki out of %d" % [GardenZones.start(), cap, (old["roster"] as Array).size()])
