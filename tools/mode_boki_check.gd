extends RefCounted
## --mode-boki-check (docs/design/MODE_BOKI.md, content/rules/mode_boki.json): every species in the game
## (Data.KIN) is listed in exactly one mode, once; every mode has a COMMON, RARE and VERY RARE tier with
## species in each; each rarer tier sits behind a higher difficulty gate than the one before; the
## legendaries (Data.is_rare) are Expedition's separate per-match roll, under the owner's 30% cap;
## ModeBoki.mode_of and tier answer what the file says.

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
