class_name TopChips
extends RefCounted
## The farm top bar's counters. Name and gems show from the start; each other counter shows from the first
## time you have any of it, and stays. The four building materials share one chip (their sum, broken down in
## its tooltip) that shows once any of them has. A save that had already seen the farm before this existed
## shows all. The garden (base_mode) has no gathering: there a counter shows only while it is above 0.

const MAT := Color("d8b07a")      # building materials
const COUNTERS := [
	["tonic", "tonic", "%d", Color("ff8a9a"), "Tonics: drink one (1) on an expedition to heal"],
	["crops", "seed", "%d", UI.GOOD, "Crops you've harvested"],
]
const MATERIALS := [      # [id, name, where it comes from]: the Materials chip's rows
	["wood", "Wood", "chop trees in the wild with an axe, or a Lumber Camp"],
	["stone", "Stone", "mine boulders with a pickaxe, or a Quarry"],
	["fibre", "Fibre", "from harvests and from clearing the wild"],
	["coals", "Ember Coals", "from a Kiln"],
]

static func have(id: String) -> int:
	match id:
		"tonic": return int(Save.d["items"].get("tonic", 0))
		"crops": return int(Save.d["crops"].values().reduce(func(a, b): return a + int(b), 0))
	return FarmSites.have(id)

## True when the counter shows: you have some, or had some before (the garden: only while you have some).
static func shows(id: String, count: int) -> bool:
	if count == 0 and FarmUnlocks.base_mode():
		return false
	var tut: Dictionary = Save.d["tutorial"]
	if not tut.has("chips_seen"):
		tut["chips_seen"] = {}
		for c in COUNTERS + MATERIALS:
			if tut.get("home", false):
				tut["chips_seen"][c[0]] = true
	var seen: Dictionary = tut["chips_seen"]
	if count > 0:
		seen[id] = true
	return seen.has(id)

static func add_to(row: Node) -> void:
	for c in COUNTERS:
		var n := have(String(c[0]))
		if shows(String(c[0]), n):
			row.add_child(UI.chip(String(c[1]), String(c[2]) % n, c[3], String(c[4]), 14))
	var total := 0
	var seen := false
	var tip: Array = ["Materials: wood, stone and fibre pay for buildings, Ember Coals for upgrades"]
	for mt in MATERIALS:
		var n := have(String(mt[0]))
		total += n
		seen = shows(String(mt[0]), n) or seen      # (asked for each, so each is marked seen)
		tip.append("%s  %d  ·  %s" % [mt[1], n, mt[2]])
	if seen:
		row.add_child(UI.chip("hammer", str(total), MAT, "\n".join(tip), 14))
