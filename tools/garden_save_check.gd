extends RefCounted
## --garden-save-check: every field the Boki garden put on the save survives a save and a load in a
## fresh process, and a v11 save made on main before the garden (tools/fixtures/pre_garden_save.json)
## migrates with sane defaults and runs through the garden readers without a crash.
## Parent: builds the garden save, writes it, starts the child (--garden-save-load) and relays its lines.
## Child: loads the file with Save.load_from and compares it with the fields the parent wrote.
## Prints GSAVE ok/FAIL lines and "GSAVE DONE, failures: N". Never touches a real save file.

const FIXTURE := "res://tools/fixtures/pre_garden_save.json"
const FILE_ARG := "--garden-save-file="
const WANT_EXT := ".want"      # beside the save: the garden fields as the parent wrote them
## Boki record keys the garden added or leans on (trust is older, but the garden now moves it).
const KEYS := ["trust", "bonds", "lean", "journal", "known", "bond_seen", "extra_care", "drift", "mentor",
		"gifts", "lineage"]
const TOY_IDS := ["toy_ball", "toy_post"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("GSAVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(host: Node, which := "all") -> void:
	Save.no_write = true
	if which == "load":
		_child(host)
		return
	var path := ProjectSettings.globalize_path("user://garden_save_check.json")
	Save.d = _garden()
	Save.register_all()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(Save.d))
	f.close()
	f = FileAccess.open(path + WANT_EXT, FileAccess.WRITE)
	f.store_string(JSON.stringify(_fields(Save.d)))
	f.close()
	var out: Array = []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--"]
	args.append_array(["--no-save", "--garden-save-load", FILE_ARG + path])
	var rc := OS.execute(OS.get_executable_path(), args, out, true)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + WANT_EXT)
	var lines := Array((String(out[0]) if out.size() > 0 else "").split("\n"))
	for line in lines:
		if line.begins_with("GSAVE ok") or line.begins_with("GSAVE FAIL"):
			print(line)
			bad += 1 if line.begins_with("GSAVE FAIL") else 0
	var loaded := lines.any(func(l): return l.begins_with("GSAVE LOADED"))
	ok(rc == 0 and loaded, "the fresh process loaded and compared the save (exit %d)" % rc)
	_old_save()
	print("GSAVE DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ the full garden save
## A save with every garden field set to a value no default would give.
func _garden() -> Dictionary:
	var d := Save.fresh()
	var a := Save.new_kin("cindle", "Ash", 11)
	var b := Save.new_kin("puddlet", "Bri", 12)
	var c := Save.new_kin("cindle", "Cy", 13)
	for r in [a, b, c]:
		Care.ensure(r)
	a["trust"] = 77.5
	a["bonds"] = {b["uid"]: 0.8, c["uid"]: -0.6}
	b["bonds"] = {a["uid"]: 0.8}
	a["lean"] = {"fire": 2.5, "water": 0.5}
	a["journal"] = [{"t": 1000.0, "food": "emberberry", "n": 3, "lean": "fire"}, {"t": 1100.0, "words": "won the Dash"}]
	a["known"] = ["food", "play"]
	a["bond_seen"] = 2
	a["extra_care"] = 120.0
	a["drift"] = {"day": 3, "moved": {"power": 0.05}}
	a["mentor"] = {"gifted": true}
	c["gifts"] = {"lean": 0, "habit": 2}
	c["lineage"] = {"parents": [a["uid"], b["uid"]]}
	d["roster"] = [a, b, c]
	d["active"] = a["uid"]
	d["away_seen"] = 5000.0
	d["egg"] = {"sp": "cindle", "gift": {"lean": "fire"}, "minded": true}
	var L := HomeLayout.fresh()
	for i in TOY_IDS.size():
		L["deco"].append({"u": 900 + i, "id": TOY_IDS[i], "x": 4 + i, "z": 5, "r": 0})
	L["deco"].append({"u": 910, "id": SnackPatch.ID, "x": 8, "z": 8, "r": 0, SnackPatch.RIPE_KEY: 4242.0})
	L["uid"] = 910
	d["layout"] = L
	return d

## The garden fields of a save as JSON text, the same on both sides of a save and load.
func _fields(d: Dictionary) -> Dictionary:
	var out := {"away_seen": d.get("away_seen"), "egg": d.get("egg")}
	for r in d["roster"]:
		for k in KEYS:
			out["%s.%s" % [r["name"], k]] = r.get(k)
	for e in HomeLayout.of(d)["deco"]:
		if TOY_IDS.has(e["id"]) or e["id"] == SnackPatch.ID:
			out["deco.%s" % e["id"]] = [float(e["x"]), float(e["z"]), float(e.get(SnackPatch.RIPE_KEY, 0.0))]
	return out

func _child(host: Node) -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with(FILE_ARG):
			path = String(a).trim_prefix(FILE_ARG)
	Save.load_from(path)
	HomeLayout.ensure(Save.d)      # what the home screen does with the layout it opens
	var want: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + WANT_EXT))
	var got := _fields(Save.d)
	for key in want:
		ok(JSON.stringify(got.get(key), "", true) == JSON.stringify(want[key], "", true),
			"%s came back" % key)
	ok(not Save.d.has("base_mode"), "base_mode lives in farm_build.json, not in the save")
	print("GSAVE LOADED")
	host.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ a save from before the garden
func _old_save() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	ok(typeof(parsed) == TYPE_DICTIONARY and int(parsed["v"]) == 11, "the fixture is a v11 save made on main")
	var gems := int(parsed["gems"])
	var names: Array = (parsed["roster"] as Array).map(func(r): return r["name"])
	var uids: Array = (parsed["roster"] as Array).map(func(r): return r["uid"])
	ok(Save.migrate(parsed) and int(parsed["v"]) == Save.VERSION, "it migrates to v%d" % Save.VERSION)
	Care.migrate_habits(parsed)
	ok(int(parsed["gems"]) == gems and (parsed["roster"] as Array).map(func(r): return r["name"]) == names
		and (parsed["roster"] as Array).map(func(r): return r["uid"]) == uids, "gems, names and ids are untouched")
	Save.d = parsed
	HomeLayout.ensure(Save.d)
	var recs: Array = parsed["roster"]
	for r in recs:
		Care.ensure(r)
		var who := String(r["name"])
		ok(r["bonds"] is Dictionary and (r["bonds"] as Dictionary).is_empty(), "%s: no friends or rivals yet" % who)
		ok(r["journal"] is Array and (r["journal"] as Array).is_empty(), "%s: an empty journal" % who)
		ok(Care.lean_total(r) == 0.0, "%s: no lean" % who)
		ok(float(r["trust"]) >= 0.0 and float(r["trust"]) <= 100.0, "%s: trust %.0f is kept" % [who, float(r["trust"])])
		var invented := ["extra_care", "drift", "mentor"].any(func(k): return r.has(k))
		ok(not invented, "%s: no optional garden keys invented" % who)
	_readers(recs)
	ok(not (Save.d.get("egg", {}) as Dictionary).has("minded"), "the old egg is not marked minded")
	ok(Mentor.take_gift().is_empty(), "no mentor on an old save, so no gift")

## The garden's readers on records that have none of its keys, with base_mode on: none may crash.
func _readers(recs: Array) -> void:
	var farm := Content.rules("farm_build")
	var was: Variant = farm["base_mode"]
	farm["base_mode"] = true
	var a: Dictionary = recs[0]
	var b: Dictionary = recs[recs.size() - 1]
	ok(BaseLife.bond(a, b) == 0.0 and BaseRace.bond(a, b) == 0.0, "an unknown bond reads as 0")
	var trusted: bool = minf(float(a["trust"]), float(b["trust"])) >= NookRules.FRIEND_TRUST
	ok(NookRules.friends(a, b) == trusted, "friends fall back to trust")
	ok(Care.lean_total(a) == 0.0 and CareJournal.text({"words": "x"}) == "x", "lean and journal read cleanly")
	KinBondMoment.due(recs.map(func(r): return {"rec": r}))
	ok(recs.all(func(r): return r.has("bond_seen")), "a missing bond_seen is filled in, not crashed on")
	farm["base_mode"] = was
