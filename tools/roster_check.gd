extends RefCounted
## --roster-check: the species roster (docs/boki/ROSTER_50.md) is whole and live. Every kin in content/kin_v2
## loads through the grammar (KinLib), there are exactly 50 with no clashing display names, each has home data
## in content/kin, no game text or data says Ermink (it is Minkee; only the id stays `ermink`), and the big ones
## split into the 4-6 rideables the owner capped (a rideable is a large kin whose mount speed is at least
## RIDEABLE_SPEED; the other large kin have non-ridden roles kept in the doc).
## Never touches the save.

const TARGET_TOTAL := 91      # the 50 of ROSTER_50.md plus 41 early-zone Meshy species (zone_sync.py)
const RIDEABLE_SPEED := 1.1      # x; slower large kin have another big-Boki role (ROSTER_50.md)
const RIDEABLE_MIN := 4
const RIDEABLE_MAX := 6      # the owner capped mounts at about 6
const OLD_NAME := "Ermink"      # the name Minkee replaced; matched by case, the id stays `ermink`

var bad := 0

## Prints a ROSTER ok or FAIL line and counts failures.
func ok(cond: bool, what: String) -> void:
	print("ROSTER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## Runs the check and quits with 1 on any failure.
func run(main: Node) -> void:
	var names := {}
	var sizes := {"small": 0, "medium": 0, "large": 0, "rideable": 0}
	for id in KinLib.kin_ids():
		var k: KinSpec = KinLib.kin(id)
		var key := k.display_name.to_lower()
		ok(not names.has(key), "%s: name %s is not used by %s" % [id, k.display_name, names.get(key, "anyone")])
		names[key] = id
		ok(Data.KIN.has(id), "%s is in Data.KIN" % id)
		ok(FileAccess.file_exists("res://content/kin/%s.json" % id), "%s has home data" % id)
		sizes[_size_class(k)] += 1
		var n := Models.kin(id, Save.new_kin(id))
		var drawn := n.find_child("BokiRig", true, false) or n.find_child("M3d", true, false)
		var kind := "model" if drawn else "placeholder"
		ok(_mesh_count(n) > 0, "%s draws (%s)" % [id, kind])
		n.free()
	ok(KinLib.kin("ermink").display_name == "Minkee", "ermink is shown as Minkee")
	var stale := _old_name_hits("res://content") + _old_name_hits("res://scripts")
	ok(stale.is_empty(), "no text says %s (%s)" % [OLD_NAME, ", ".join(stale)])
	var total := KinLib.kin_ids().size()
	ok(total == TARGET_TOTAL, "%d species (want %d)" % [total, TARGET_TOTAL])
	var rideable := int(sizes["rideable"])
	var want := "%d-%d" % [RIDEABLE_MIN, RIDEABLE_MAX]
	ok(rideable >= RIDEABLE_MIN and rideable <= RIDEABLE_MAX, "rideables: %d (want %s)" % [rideable, want])
	print("ROSTER sizes: small %d, medium %d, large %d, rideable %d" % [
		sizes["small"], sizes["medium"], sizes["large"], rideable])
	print("ROSTER DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## small, medium, large (a heavy mount) or rideable (a fast mount).
func _size_class(k: KinSpec) -> String:
	if k.size == "large" and float(k.mount.get("speed", 1.0)) >= RIDEABLE_SPEED:
		return "rideable"
	return k.size

func _mesh_count(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += _mesh_count(ch)
	return c

## The .json and .gd files under `dir` whose text still carries OLD_NAME.
func _old_name_hits(dir: String) -> Array:
	var hits: Array = []
	for f in DirAccess.get_files_at(dir):
		var path := dir.path_join(f)
		if f.get_extension() in ["json", "gd"] and FileAccess.get_file_as_string(path).contains(OLD_NAME):
			hits.append(path)
	for sub in DirAccess.get_directories_at(dir):
		hits += _old_name_hits(dir.path_join(sub))
	return hits
