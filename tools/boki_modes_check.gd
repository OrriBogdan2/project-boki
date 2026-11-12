extends RefCounted
## --boki-modes-check: every Boki is found in exactly one mode (BokiModes,
## docs/design/SERIES_BOKI_MODES.md). Every game species and every listed line has one valid mode,
## rarity and difficulty gate; the Expedition spawn pools (wild spots, rare spots) never yield another
## mode's Boki, even when a species is moved to another mode; draws follow the rarity tickets; Heart
## Raid's difficulty ladder opens rares on Hard and very rares on Nightmare. Never touches the save.

const DRAWS := 20000
const RAID_GATES := {"common": "normal", "rare": "hard", "very_rare": "nightmare"}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOKIMODES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	_one_mode_each()
	_expedition_pools()
	_moved_species_leaves()
	_raid_gates()
	print("BOKIMODES DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _one_mode_each() -> void:
	var r := BokiModes.rules()
	var unlisted: Array = Data.KIN.keys().filter(func(sp): return BokiModes.of(sp).is_empty())
	ok(unlisted.is_empty(), "every game species has a mode %s" % str(unlisted))
	var seen := {}
	var twice: Array = []
	var invalid: Array = []
	for line in r["lines"]:
		var entry: Dictionary = r["lines"][line]
		var kin := String(entry.get("kin", ""))
		if kin != "" and seen.has(kin): twice.append(kin)
		seen[kin] = true
		var mode: Dictionary = r["modes"].get(String(entry["mode"]), {})
		var valid: bool = not mode.is_empty() and r["tickets"].has(entry["rarity"])
		if not valid or not (mode["difficulties"] as Array).has(entry["min_difficulty"]): invalid.append(line)
	ok(twice.is_empty(), "no species sits on two lines %s" % str(twice))
	ok(invalid.is_empty(), "every line has a known mode, rarity and difficulty %s" % str(invalid))
	ok(r["lines"].size() >= 100, "the file lists the whole Bokidex (%d lines)" % r["lines"].size())
	var eggs: Array = Data.MOBS.keys().filter(func(b): return Data.MOBS[b].has("egg"))
	var off: Array = eggs.filter(func(b): return not _very_rare(String(Data.MOBS[b]["egg"])))
	ok(off.is_empty(), "each lair boss's egg hatches an Expedition very rare %s" % str(off))
	var gates_off: Array = r["lines"].keys().filter(func(line): return _raid_gate_off(r["lines"][line]))
	ok(gates_off.is_empty(), "Heart Raid lines are gated by rarity (Normal, Hard, Nightmare) %s" % str(gates_off))

func _expedition_pools() -> void:
	for site in ["wild", "rare_spot"]:
		var pool := BokiModes.site_pool("expedition", site)
		var foreign: Array = pool.filter(func(sp): return BokiModes.of(sp)["mode"] != "expedition")
		var egg_kin: Array = pool.filter(func(sp): return Data.is_rare(sp))
		var what := "the %s pool is %d Expedition Boki %s" % [site, pool.size(), str(foreign)]
		ok(pool.size() >= 10 and foreign.is_empty(), what)
		ok(egg_kin.is_empty(), "no boss-egg kin at the %s spots %s" % [site, str(egg_kin)])
	var got := _draw_counts(BokiModes.site_pool("expedition", "rare_spot"), 7)
	var per := {}
	for tier in ["rare", "very_rare"]:
		var ids: Array = got.keys().filter(func(sp): return BokiModes.of(sp)["rarity"] == tier)
		var n := 0
		for sp in ids: n += int(got[sp])
		per[tier] = float(n) / maxf(1.0, ids.size())
	var odds := "%.0f vs %.0f draws each" % [per["very_rare"], per["rare"]]
	ok(per["rare"] > 2.0 * per["very_rare"], "a very rare is drawn less often than a rare (%s)" % odds)

## A species moved to another mode in the rules drops out of every Expedition pool and draw.
func _moved_species_leaves() -> void:
	var sp := "kindlewren"
	var entry := BokiModes.of(sp)
	entry["mode"] = "heart_raid"
	var drawn := {}
	for site in ["wild", "rare_spot"]:
		drawn.merge(_draw_counts(BokiModes.site_pool("expedition", site), 3))
	var what := "a Heart Raid Boki is never drawn in an Expedition (%d draws)" % DRAWS
	ok(not drawn.has(sp) and not drawn.is_empty(), what)
	entry["mode"] = "expedition"

## Heart Raid's pool by difficulty, on three species moved there for the test.
func _raid_gates() -> void:
	var moved := {"kindlewren": "common", "kestrike": "rare", "scaldamus": "very_rare"}
	var saved := {}
	for sp in moved:
		saved[sp] = BokiModes.of(sp).duplicate()
		var rarity := String(moved[sp])
		BokiModes.of(sp).merge({"mode": "heart_raid", "rarity": rarity, "min_difficulty": RAID_GATES[rarity]}, true)
	var all_tiers := ["common", "rare", "very_rare"]
	ok(BokiModes.pool("heart_raid", all_tiers, "normal") == ["kindlewren"], "Normal: commons only")
	ok(BokiModes.pool("heart_raid", all_tiers, "hard").size() == 2, "Hard: + rares")
	ok(BokiModes.pool("heart_raid", all_tiers, "nightmare").size() == 3, "Nightmare: + very rares")
	for sp in saved:
		BokiModes.of(sp).merge(saved[sp], true)

func _very_rare(sp: String) -> bool:
	return BokiModes.of(sp).get("mode") == "expedition" and BokiModes.of(sp).get("rarity") == "very_rare"

func _raid_gate_off(entry: Dictionary) -> bool:
	return entry["mode"] == "heart_raid" and RAID_GATES[entry["rarity"]] != entry["min_difficulty"]

func _draw_counts(pool: Array, seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var got := {}
	for i in DRAWS:
		var sp := BokiModes.draw(pool, rng)
		got[sp] = int(got.get(sp, 0)) + 1
	return got
