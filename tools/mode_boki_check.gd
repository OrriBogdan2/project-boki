extends RefCounted
## --mode-boki-check (docs/design/MODE_BOKI.md, content/rules/mode_boki.json): every species in the game
## (Data.KIN) is listed in exactly one mode, once; every mode has a COMMON, RARE and VERY RARE tier with
## species in each; each rarer tier sits behind a higher difficulty gate than the one before; the
## legendaries (Data.is_rare) are Expedition's separate per-match roll, under the owner's 30% cap;
## ModeBoki.mode_of and tier answer what the file says; the "live" flag is off in the file, and ModeBoki.offer
## leaves a pool alone while it is off and cuts it to the mode's species (and open tiers) once on.

const LEGENDARY_CAP := 0.3     # owner 2026-11-09: a legendary in under 30% of matches

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MODE_BOKI %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	var seen := {}             # species -> ["mode/tier", ...]
	for mode_id in ModeBoki.modes():
		var mode: Dictionary = ModeBoki.modes()[mode_id]
		var tiers: Dictionary = mode.get("tiers", {})
		var last_gate := -1
		for t in ModeBoki.TIERS:
			var row: Dictionary = tiers.get(t, {})
			var listed: Array = row.get("species", [])
			ok(not listed.is_empty(), "%s has %s species" % [mode_id, t])
			var gate := int(row.get("gate", -1))
			var above := row.has("gate") and gate > last_gate
			ok(above, "%s %s gate %d is above the tier before (%d)" % [mode_id, t, gate, last_gate])
			last_gate = gate
			for sp in listed:
				seen[sp] = seen.get(sp, []) + ["%s/%s" % [mode_id, t]]
		for sp in mode.get("legendary", {}).get("species", []):
			seen[sp] = seen.get(sp, []) + ["%s/%s" % [mode_id, ModeBoki.LEGENDARY]]
	for sp in Data.KIN:
		var where: Array = seen.get(sp, [])
		ok(where.size() == 1, "%s is in exactly one mode %s" % [sp, where])
	for sp in seen:
		ok(Data.KIN.has(sp), "%s is a species in the game" % sp)
	_legendary_part()
	for sp in Data.KIN:
		var where: Array = seen.get(sp, [""])
		var read := "%s/%s" % [ModeBoki.mode_of(sp), ModeBoki.tier(sp)]
		ok(read == String(where[0]), "%s: mode_of and tier read the file" % sp)
	var none := ModeBoki.mode_of("no_such_boki") + ModeBoki.tier("no_such_boki")
	ok(none == "", "an unlisted species has no mode")
	_live_part()
	print("MODE_BOKI DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

func _legendary_part() -> void:
	var leg: Dictionary = ModeBoki.modes()["expedition"].get("legendary", {})
	var rares: Array = Data.KIN.keys().filter(func(sp): return Data.is_rare(String(sp)))
	var listed: Array = leg.get("species", [])
	var same := listed.size() == rares.size() and rares.all(func(sp): return listed.has(sp))
	ok(same, "Expedition's legendaries are the rare kin %s" % [rares])
	var p := float(leg.get("per_match", 0.0))
	var pct := [p * 100.0, LEGENDARY_CAP * 100.0]
	ok(p > 0.0 and p < LEGENDARY_CAP, "a legendary rolls in %.0f%% of matches (under %.0f%%)" % pct)

func _gated(sp: String, mode_id: String, level: int) -> bool:
	var row: Dictionary = ModeBoki.modes()[mode_id]["tiers"][ModeBoki.tier(sp)]
	return ModeBoki.mode_of(sp) == mode_id and level >= int(row["gate"])

func _live_part() -> void:
	var rules: Dictionary = Content.rules("mode_boki")
	ok(rules.get("live", true) == false, "the live flag is off in the file")
	var wild: Array = Data.common_kin()
	ok(ModeBoki.offer(wild, "expedition", 0) == wild, "flag off: the Expedition pool is untouched")
	ok(ModeBoki.offer(wild, "garden_visitors", 3) == wild, "flag off: the visitor pool is untouched")
	rules["live"] = true
	for lvl in Data.TIERS.size():
		var got: Array = ModeBoki.offer(wild, "expedition", lvl)
		var own := got.all(func(sp): return _gated(sp, "expedition", lvl))
		ok(not got.is_empty() and own, "flag on: Expedition level %d offers %d of its own" % [lvl, got.size()])
	var meadow: Array = ModeBoki.offer(wild, "expedition", 0)
	var hollow: Array = ModeBoki.offer(wild, "expedition", 2)
	var sizes := [meadow.size(), hollow.size()]
	ok(sizes == [18, 29], "flag on: The Meadow offers 18, The Hollow 29 %s" % [sizes])
	_visitor_part(wild)
	var rng := RandomNumberGenerator.new()
	var drawn := {}
	for i in 200:
		drawn[ModeBoki.draw(wild, "expedition", 0, rng)] = true
	ok(drawn.keys().all(func(sp): return meadow.has(sp)), "flag on: draw stays inside the offer")
	rules["live"] = false
	ok(ModeBoki.offer(wild, "expedition", 0) == wild, "flag off again: the pool is back as it was")

func _visitor_part(wild: Array) -> void:
	var listed := []
	for t in ModeBoki.modes()["garden_visitors"]["tiers"].values():
		listed += t["species"]
	var all_open := ModeBoki.offer(wild, "garden_visitors", 3)
	var same := all_open.size() == listed.size() and listed.all(func(sp): return all_open.has(sp))
	ok(same, "flag on: garden visitors offer only their %d once every zone is open" % listed.size())
	ok(ModeBoki.offer(wild, "garden_visitors", 0).is_empty(), "flag on: no visitor before a zone is open")
	var first: Array = ModeBoki.offer(wild, "garden_visitors", 1)
	ok(first.size() == 3, "flag on: one zone open offers the 3 common visitors (%d)" % first.size())
