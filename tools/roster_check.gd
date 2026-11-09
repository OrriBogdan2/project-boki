extends RefCounted
## --roster-check: the 50-species roster (docs/boki/ROSTER_50.md) is whole and live. Every kin in content/kin_v2
## loads through the grammar (KinLib), there are exactly 50 with no clashing display names, each has home data
## in content/kin, and the big ones split into the 4-6 rideables the owner capped (a rideable is a large kin
## whose mount speed is at least RIDEABLE_SPEED; the other large kin have non-ridden roles kept in the doc).
## Never touches the save.

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
		var kind := "model" if n.find_child("BokiRig", true, false) else "placeholder"
		ok(_mesh_count(n) > 0, "%s draws (%s)" % [id, kind])
		n.free()
	var total := KinLib.kin_ids().size()
	ok(total == TARGET_TOTAL, "%d species (want %d)" % [total, TARGET_TOTAL])
	var rideable := int(sizes["rideable"])
	var want := "%d-%d" % [RIDEABLE_MIN, RIDEABLE_MAX]
	ok(rideable >= RIDEABLE_MIN and rideable <= RIDEABLE_MAX, "rideables: %d (want %s)" % [rideable, want])
	print("ROSTER sizes: small %d, medium %d, large %d, rideable %d" % [
		sizes["small"], sizes["medium"], sizes["large"], rideable])
	_src_notes()
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

## Every Hunter kit has a `src` note per ability (PARITY FIRST: [D] data, [F] footage, [O] owner, ours, [?] unknown).
func _src_notes() -> void:
	var dir := DirAccess.open("res://content/archetypes")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/archetypes/" + f))
		var src: Dictionary = d.get("src", {}) if d is Dictionary else {}
		var ours := 0
		var unk := 0
		for slot in ["lmb", "rmb", "e", "x", "dash", "passive"]:
			var v := str(src.get(slot, ""))
			ok(v != "", "%s: src note for %s" % [f, slot])
			ours += 1 if " ours" in v else 0
			unk += 1 if "[?]" in v else 0
		print("ROSTER src %s: ours %d, [?] %d" % [f.get_basename(), ours, unk])
