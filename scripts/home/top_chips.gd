class_name TopChips
extends RefCounted
## The farm top bar's counters. Name and gems show from the start; each other counter shows from the first
## time you have any of it, and stays. A save that had already seen the farm before this existed shows all.

const MAT := Color("d8b07a")      # building materials
const COUNTERS := [
	["tonic", "tonic", "%d", Color("ff8a9a"), "Tonics: drink one (1) on an expedition to heal"],
	["crops", "seed", "%d", UI.GOOD, "Crops you've harvested"],
	["wood", "dash", "%d wood", MAT, "Wood: chop trees in the wild with an axe, or a Lumber Camp. Pays for buildings."],
	["stone", "dash", "%d stone", MAT, "Stone: mine boulders with a pickaxe, or a Quarry. Pays for buildings."],
	["fibre", "dash", "%d fibre", MAT, "Fibre: from harvests and from clearing the wild. Pays for buildings."],
	["coals", "dash", "%d coals", MAT, "Ember Coals: from a Kiln. They pay for upgrades."],
]

static func have(id: String) -> int:
	match id:
		"tonic": return int(Save.d["items"].get("tonic", 0))
		"crops": return int(Save.d["crops"].values().reduce(func(a, b): return a + int(b), 0))
	return FarmSites.have(id)

## True when the counter shows: you have some, or had some before.
static func shows(id: String, count: int) -> bool:
	var tut: Dictionary = Save.d["tutorial"]
	if not tut.has("chips_seen"):
		tut["chips_seen"] = {}
		for c in COUNTERS:
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
