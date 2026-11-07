extends RefCounted
## --roster-check: the proposed Boki roster stubs (content/kin_v2_roster, docs/boki/ROSTER_50.md) pass the
## kin grammar against the live abilities, merges and evolution nodes, without being loaded by the game.
## Each stub is parsed as a KinSpec and its slots checked against the library under res://content. It also
## checks that no stub id or name clashes with a live kin or another stub, and prints the size counts
## (a rideable is a large kin whose mount speed is at least RIDEABLE_SPEED; the other large kin have
## non-ridden roles kept in the doc, as the grammar has no field for them yet). Never touches the save.

const ROSTER_DIR := "res://content/kin_v2_roster"
const TARGET_TOTAL := 50
const RIDEABLE_SPEED := 1.1      # x; slower large kin have another big-Boki role (ROSTER_50.md)
const RIDEABLE_MIN := 4
const RIDEABLE_MAX := 6      # the owner capped mounts at about 6

var bad := 0

## Prints a ROSTER ok or FAIL line and counts failures.
func ok(cond: bool, what: String) -> void:
	print("ROSTER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## Runs the check and quits with 1 on any failure.
func run(main: Node) -> void:
	var lib := KinGrammar.load_root("res://content", {})
	var live: Dictionary = lib["kin"]
	var names := {}
	for id in live:
		names[(live[id] as KinSpec).display_name.to_lower()] = id
	var files: Array = Array(DirAccess.get_files_at(ROSTER_DIR))
	files = files.filter(func(f): return String(f).ends_with(".json"))
	files.sort()
	var sizes := {"small": 0, "medium": 0, "large": 0, "rideable": 0}
	for f in files:
		var k := _check_file(String(f), lib, names)
		if k != null:
			sizes[_size_class(k)] += 1
	for id in live:
		sizes[_size_class(live[id])] += 1
	var total := live.size() + files.size()
	var sum_line := "%d live kin + %d roster stubs = %d species" % [live.size(), files.size(), total]
	ok(total == TARGET_TOTAL, "%s (want %d)" % [sum_line, TARGET_TOTAL])
	var rideable := int(sizes["rideable"])
	var ride_ok := rideable >= RIDEABLE_MIN and rideable <= RIDEABLE_MAX
	ok(ride_ok, "rideables: %d (want %d-%d)" % [rideable, RIDEABLE_MIN, RIDEABLE_MAX])
	var counts := [sizes["small"], sizes["medium"], sizes["large"], rideable]
	print("ROSTER sizes: small %d, medium %d, large %d, rideable %d" % counts)
	print("ROSTER DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Parses one stub, checks it against the live library and the names seen so far, and returns its spec.
func _check_file(f: String, lib: Dictionary, names: Dictionary) -> KinSpec:
	var rep := GrammarReport.new()
	rep.file = "kin_v2_roster/" + f
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(ROSTER_DIR.path_join(f))) != OK:
		ok(false, "%s is not valid JSON (line %d)" % [f, json.get_error_line()])
		return null
	var k := KinSpec.parse(json.data, rep)
	if k == null:
		ok(false, "%s does not parse as a kin" % f)
		return null
	k.check_refs(lib, rep)
	for e in rep.errors:
		print("ROSTER grammar ", e)
	ok(rep.ok(), "%s passes the kin grammar (%d errors)" % [f, rep.errors.size()])
	ok(k.id == f.get_basename(), "%s: id '%s' matches the file name" % [f, k.id])
	ok(not (lib["kin"] as Dictionary).has(k.id), "%s: id is not a live kin" % f)
	var key := k.display_name.to_lower()
	ok(not names.has(key), "%s: name %s is not used by %s" % [f, k.display_name, names.get(key, "anyone")])
	names[key] = k.id
	return k

## small, medium, large (a heavy mount) or rideable (a fast mount).
func _size_class(k: KinSpec) -> String:
	if k.size == "large" and float(k.mount.get("speed", 1.0)) >= RIDEABLE_SPEED:
		return "rideable"
	return k.size
