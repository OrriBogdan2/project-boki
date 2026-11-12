extends RefCounted
## --save-compat-check: every golden file in tests/fixtures/saves/ still loads and keeps its data
## (docs/SAVES.md). Save slots go through Save.load_from; settings.cfg, feedback.json and warm_stamp.json
## are read the way their owners read them. Fails on a load error, a newer-version mark, a lost field, or
## a golden for a format the game no longer writes. Never touches the real save.
## --save-golden-capture --out=<dir>: writes fresh goldens from the current build's own writers
## (run it with a temporary XDG_DATA_HOME).

const DIR := "res://tests/fixtures/saves"
## Fields a load rewrites on purpose (Unmasked.migrate, Care.migrate_habits, register_all); a golden
## may differ from the loaded save there and only there.
const LOAD_REWRITES := ["look", "habit", "serial", "ot", "edition", "dna", "ivs"]
## A save from an older format: only what its migration keeps (names, counts, numbers) is compared.
const MIGRATED_KEYS := ["name", "gems", "cls", "matches", "extracts"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SAVECOMPAT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node, which := "check") -> void:
	Save.no_write = true
	if which == "capture":
		_capture(_arg("--out="))
	else:
		_check()
	print("SAVECOMPAT DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

static func _arg(prefix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with(prefix):
			return String(a).substr(prefix.length())
	return ""

# ------------------------------------------------------------------ check
func _check() -> void:
	var names := Array(DirAccess.get_files_at(DIR)).filter(func(n): return not String(n).ends_with(".import"))
	names.sort()
	var seen := {"save": 0, "settings": 0, "feedback": 0, "warm_stamp": 0}
	for n in names:
		var p := "%s/%s" % [DIR, n]
		if n.begins_with("save_v"):
			_check_save(p, n)
			seen["save"] += 1
		elif n == "settings.cfg":
			_check_settings(p)
			seen["settings"] += 1
		elif n == "feedback.json":
			_check_feedback(p)
			seen["feedback"] += 1
		elif n == "warm_stamp.json":
			_check_warm_stamp(p)
			seen["warm_stamp"] += 1
		else:
			ok(false, "%s is not a golden this check knows (docs/SAVES.md)" % n)
	for k in seen:
		ok(int(seen[k]) > 0, "a %s golden exists" % k)
	ok(FileAccess.file_exists("%s/save_v%d_farm.json" % [DIR, Save.VERSION]),
			"a golden for the current version (v%d) exists: add one with the migration (docs/SAVES.md)" % Save.VERSION)

func _check_save(p: String, n: String) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	ok(parsed is Dictionary and not (parsed as Dictionary).is_empty(), "%s parses" % n)
	if not parsed is Dictionary:
		return
	var raw: Dictionary = parsed
	var v := int(raw.get("v", 0))
	ok(Save.MIGRATIONS.has(v) or v == Save.VERSION, "%s: its version v%d still has an upgrade path" % [n, v])
	Save.load_from(p)
	ok(not Save.newer and int(Save.d["v"]) == Save.VERSION, "%s loads and is v%d" % [n, Save.VERSION])
	ok(not FileAccess.file_exists(p + ".bak-v%d" % v), "%s: loading wrote nothing" % n)
	var kin_n := (raw["roster"] as Array).size()
	ok((Save.d["roster"] as Array).size() == kin_n, "%s keeps all %d kin" % [n, kin_n])
	var lost := []
	if v == Save.VERSION:
		for k in raw:
			_lost(raw[k], Save.d.get(k), k, lost)
	else:
		for k in MIGRATED_KEYS:
			if raw.has(k):
				_lost(raw[k], Save.d.get(k), k, lost)
		for i in (raw["roster"] as Array).size():
			for k in ["name", "level", "species"]:
				if raw["roster"][i].has(k):
					_lost(raw["roster"][i][k], Save.d["roster"][i].get(k), "roster.%d.%s" % [i, k], lost)
	ok(lost.is_empty(), "%s loses nothing%s" % [n, "" if lost.is_empty() else ": " + str(lost.slice(0, 6))])
	Save.d = Save.fresh()

## Every leaf of `before` that `after` lacks or holds differently, as a path (LOAD_REWRITES excepted).
func _lost(before, after, path: String, out: Array) -> void:
	if before is Dictionary:
		if not after is Dictionary:
			out.append(path)
			return
		for k in before:
			if not LOAD_REWRITES.has(String(k)):
				_lost(before[k], after.get(k), "%s.%s" % [path, k], out)
	elif before is Array:
		if not after is Array or (after as Array).size() < (before as Array).size():
			out.append(path)
			return
		for i in (before as Array).size():
			_lost(before[i], after[i], "%s.%d" % [path, i], out)
	elif before != after:
		out.append(path)

func _check_settings(p: String) -> void:
	var cf := ConfigFile.new()
	ok(cf.load(p) == OK, "settings.cfg loads")
	var known := Settings.DEFAULTS.keys() + Settings.REMOVED
	var unknown := Array(cf.get_section_keys("s")).filter(
			func(k): return not known.has(k) and not String(k).begins_with("keys"))
	ok(unknown.is_empty(), "settings.cfg: only keys Settings knows (a rename needs a migration) %s" % [unknown])
	var v: Dictionary = {}
	for k in Settings.DEFAULTS:
		v[k] = cf.get_value("s", k, Settings.DEFAULTS[k])
	ok(is_equal_approx(float(v["master"]), 0.5) and v["quality"] == "high" and bool(v["dash_to_cursor"]),
			"settings.cfg keeps the values the golden was written with")
	var keys: Dictionary = v.get("keys", {})
	ok(not keys.is_empty() and int(v.get("keys_v", 0)) == Settings.KEYS_V, "settings.cfg keeps its key bindings")
	ok(int(cf.get_value("save", "slot", 0)) == 2, "settings.cfg keeps the last save slot")

func _check_feedback(p: String) -> void:
	var st = JSON.parse_string(FileAccess.get_file_as_string(p))
	ok(st is Dictionary and (st["minutes"] as Dictionary).size() == 1 and (st["done"] as Array).size() == 1,
			"feedback.json keeps minutes and answered versions")
	var q: Dictionary = st["queue"][0]
	ok(q["scores"] == {"combat": 4.0, "boki": 5.0} and String(q["note"]) == "golden note" and q.has("version"),
			"feedback.json keeps the queued answer")
	var was := Feedback.path
	Feedback.path = p
	var back: Dictionary = Feedback._load()
	Feedback.path = was
	ok(back["queue"] == st["queue"] and back["done"] == st["done"], "Feedback reads the golden as it was written")

func _check_warm_stamp(p: String) -> void:
	var st = JSON.parse_string(FileAccess.get_file_as_string(p))
	ok(st is Dictionary and ["id", "parts", "files", "unix", "keys"].all(func(k): return st.has(k)),
			"warm_stamp.json keeps id, parts, files, unix and keys")
	ok((st["keys"] as Array).size() == 2 and int(st["files"]) >= 0, "warm_stamp.json keeps its warm keys")

# ------------------------------------------------------------------ capture
func _capture(out: String) -> void:
	ok(out != "" and DirAccess.make_dir_recursive_absolute(out) == OK, "capture: --out=<dir> is writable")
	var farm := BaseDemo.save()
	farm["name"] = "Golden"
	farm["profile"] = {"id": Save.new_id("p"), "name": "Golden"}
	farm["gems"] = 1234
	farm["matches"] = 17
	farm["extracts"] = 5
	farm["items"] = {"tonic": 3}
	farm["seeds"] = {"tidebloom": 4}
	_write(out + "/save_v%d_fresh.json" % Save.VERSION, JSON.stringify(Save.fresh()))
	_write(out + "/save_v%d_farm.json" % Save.VERSION, JSON.stringify(farm))
	Settings.v["master"] = 0.5
	Settings.v["quality"] = "high"
	Settings.v["dash_to_cursor"] = true
	Settings.v["keys"] = {"jump": ["key:%d" % KEY_J]}
	Settings.v["keys_v"] = Settings.KEYS_V
	Settings.save()
	var cf := ConfigFile.new()
	cf.load(Settings.PATH)
	cf.set_value("save", "slot", 2)
	cf.save(Settings.PATH)
	_write(out + "/settings.cfg", FileAccess.get_file_as_string(Settings.PATH))
	Feedback.path = out + "/feedback.json"
	Feedback.poster = func(_body, _done): pass
	Feedback.submit(Save, {"combat": 4.0, "boki": 5.0}, "golden note")
	Feedback.finish()
	Feedback.minutes()
	WarmStamp.save({"a": true, "b": true})
	_write(out + "/warm_stamp.json", FileAccess.get_file_as_string(WarmStamp.PATH))

func _write(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	ok(f != null, "capture: wrote %s" % p.get_file())
	if f:
		f.store_string(text)
