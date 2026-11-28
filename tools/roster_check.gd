extends RefCounted
## --roster-check: the roster (docs/boki/ROSTER.md) is whole. Every species in content/kin loads through the
## grammar (KinLib): the live ones and the data-only ones (no model yet, never spawned). There are TARGET_TOTAL
## with no clashing display names, every family link points at a real species one stage down the same line, each
## live kin has home data in content/kin_home and draws, and any large kin with mount settings counts as rideable
## (DECISIONS 2026-11-08: the 4-6 cap is loosened; the ride code reads mount speed as a plain multiplier, so no
## minimum speed is needed). Never touches the save.

const TARGET_TOTAL := 141  # 50 roster + 39 evolved forms with a model (11-18) + data-only entries
const BODY_PLAY := 0.95  # the scale Kin draws a model at (kin.gd), times the rig frame's "top" and the data's fit
const MAX_HEIGHT := 1.2  # m in the world: no Boki towers over a hunter
const MIN_GROWTH := 1.0  # an evolved form drawn at least as tall as the form it comes from

var bad := 0


## Prints a ROSTER ok or FAIL line and counts failures.
func ok(cond: bool, what: String) -> void:
	print("ROSTER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


## Runs the check and quits with 1 on any failure.
func run(main: Node) -> void:
	var names := {}
	for id in KinLib.roster_ids():
		var k := KinLib.entry(id)
		var key := k.display_name.to_lower()
		ok(not names.has(key), "%s: name %s is not used by %s" % [id, k.display_name, names.get(key, "anyone")])
		names[key] = id
		_check_links(k)
	var sizes := {"small": 0, "medium": 0, "large": 0, "rideable": 0}
	for id in KinLib.kin_ids():
		var k: KinSpec = KinLib.kin(id)
		ok(Data.KIN.has(id), "%s is in Data.KIN" % id)
		ok(FileAccess.file_exists("res://content/kin_home/%s.json" % id), "%s has home data" % id)
		sizes[_size_class(k)] += 1
		var n := Models.kin(id, Save.new_kin(id))
		var kind := "model" if n.find_child("BokiRig", true, false) else "placeholder"
		ok(_mesh_count(n) > 0, "%s draws (%s)" % [id, kind])
		n.free()
	var total := KinLib.roster_ids().size()
	ok(
		total == TARGET_TOTAL,
		(
			"%d species (want %d): %d live, %d data-only"
			% [total, TARGET_TOTAL, KinLib.kin_ids().size(), total - KinLib.kin_ids().size()]
		)
	)
	var rideable := int(sizes["rideable"])
	print(
		(
			"ROSTER sizes: small %d, medium %d, large %d, rideable %d"
			% [sizes["small"], sizes["medium"], sizes["large"], rideable]
		)
	)
	_evolved_sizes()
	_src_notes()
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
	ok(
		prev != null and int(prev.roster.get("stage", 0)) == stage - 1 and prev.roster.get("line") == r["line"],
		"%s evolves from %s, one stage down line %s" % [k.id, r["from"], r["line"]]
	)


## small, medium, large (no mount settings) or rideable (a large kin that may be ridden, at any mount speed).
func _size_class(k: KinSpec) -> String:
	if k.size == "large" and not k.mount.is_empty():
		return "rideable"
	return k.size


func _mesh_count(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += _mesh_count(ch)
	return c


## A species' height in the world (m): the rig frame's top, the model fit and the draw scale.
func _drawn_height(id: String) -> float:
	return float(BokiRig.FRAME[id]["top"]) * float(Unique.base_size(id)["fit"]) * BODY_PLAY


## No Boki is drawn taller than MAX_HEIGHT, and an evolved form with a fitted size is not shorter than its parent.
func _evolved_sizes() -> void:
	for id in BokiRig.FRAME:
		ok(_drawn_height(id) <= MAX_HEIGHT, "%s is %.2f m tall (max %.1f)" % [id, _drawn_height(id), MAX_HEIGHT])
	var lines: Dictionary = Evo.rules()["lines"]
	for from in lines:
		for o in lines[from]["into"]:
			var to := String(o["id"])
			if not (BokiRig.FRAME.has(from) and BokiRig.FRAME.has(to)) or Unique.base_size(to)["fit"] == 1.0:
				continue
			ok(
				_drawn_height(to) >= _drawn_height(from) * MIN_GROWTH,
				"%s (%.2f m) is not shorter than %s (%.2f m)" % [to, _drawn_height(to), from, _drawn_height(from)]
			)


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
