extends RefCounted
## --roster-check: the roster (docs/boki/ROSTER.md; array G of briefs/boki-art/ROSTER_100.html) is whole.
## Every species in content/kin_v2 loads through the grammar (KinLib): the live ones, and the data-only ones
## (no model yet, never spawned). There are TARGET_TOTAL with no clashing display names, every family link
## points at a real species one stage down the same line, each live kin has home data in content/kin and
## draws, the mystery egg hatches a live Ermink, and every rideable (a large kin whose mount speed is at
## least RIDEABLE_SPEED) is a grown or final form. Never touches the save.

const HATCH := preload("res://scripts/ui/hatch.gd")
const TARGET_TOTAL := 124
const RIDEABLE_SPEED := 1.1      # x; slower large kin have another big-Boki role (RIDING_SPEC.md)
const RIDEABLE_MIN := 4          # riding has to exist; any number past that is fine

var bad := 0

## Prints a ROSTER ok or FAIL line and counts failures.
func ok(cond: bool, what: String) -> void:
	print("ROSTER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## Runs the check and quits with 1 on any failure.
func run(main: Node) -> void:
	var names := {}
	var evolves := {}       # id -> true when some form evolves from it
	for id in KinLib.roster_ids():
		var k := KinLib.entry(id)
		var key := k.display_name.to_lower()
		ok(not names.has(key), "%s: name %s is not used by %s" % [id, k.display_name, names.get(key, "anyone")])
		names[key] = id
		_check_links(k)
		evolves[String(k.roster.get("from", ""))] = true
	var sizes := {"small": 0, "medium": 0, "large": 0, "rideable": 0}
	for id in KinLib.kin_ids():
		var k: KinSpec = KinLib.kin(id)
		ok(Data.KIN.has(id), "%s is in Data.KIN" % id)
		ok(FileAccess.file_exists("res://content/kin/%s.json" % id), "%s has home data" % id)
		var cls := _size_class(k)
		sizes[cls] += 1
		if cls == "rideable":
			ok(int(k.roster.get("stage", 0)) >= 2 or not evolves.has(id), "rideable %s is a grown or final form" % id)
		var n := Models.kin(id, Save.new_kin(id))
		var kind := "model" if n.find_child("BokiRig", true, false) else "placeholder"
		ok(_mesh_count(n) > 0, "%s draws (%s)" % [id, kind])
		n.free()
	ok(KinLib.kin(HATCH.MYSTERY) != null, "the mystery egg's %s is live" % HATCH.MYSTERY)
	var total := KinLib.roster_ids().size()
	ok(total == TARGET_TOTAL, "%d species (want %d): %d live, %d data-only" % [
		total, TARGET_TOTAL, KinLib.kin_ids().size(), total - KinLib.kin_ids().size()])
	var rideable := int(sizes["rideable"])
	ok(rideable >= RIDEABLE_MIN, "rideables: %d (want at least %d)" % [rideable, RIDEABLE_MIN])
	print("ROSTER sizes: small %d, medium %d, large %d, rideable %d" % [
		sizes["small"], sizes["medium"], sizes["large"], rideable])
	print("ROSTER DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A first form starts its own line; a later one evolves from the form one stage down the same line.
func _check_links(k: KinSpec) -> void:
	var r := k.roster
	ok(not r.is_empty(), "%s has a roster entry" % k.id)
	if r.is_empty():
		return
	var stage := int(r["stage"])
	if stage == 1:
		ok(r["line"] == k.id and r["from"] == "", "%s starts its own line" % k.id)
		return
	var prev := KinLib.entry(String(r["from"]))
	ok(prev != null and int(prev.roster.get("stage", 0)) == stage - 1 and prev.roster.get("line") == r["line"],
		"%s evolves from %s, one stage down line %s" % [k.id, r["from"], r["line"]])

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
