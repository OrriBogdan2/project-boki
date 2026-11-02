class_name GearSave
extends RefCounted
## Save-side half of the gear model: the v4 -> v5 migration (weapons stored in the armory become
## scrap, gloves become gear items, the loadout moves to five gear slots) and what an extracted
## haul turns into on the farm (materials, on top of the gear itself going to the armory).

const OLD_SCRAP := [1, 1, 2, 4, 7]       # what a stored weapon of each rarity breaks down into

## Upgrades a v4 save in place. Old weapons (and anything the old loadout held) are scrapped, so
## nothing is lost: the scrap buys the same armory and backpack upgrades it always did.
static func migrate(data: Dictionary) -> void:
	var scrap := int(data.get("scrap", 0))
	for key in ["armory", "raid_out"]:
		var out: Array = []
		for it in data.get(key, []):
			if typeof(it) != TYPE_DICTIONARY:
				continue
			match String(it.get("t", "")):
				"weapon":
					scrap += int(OLD_SCRAP[clampi(int(it.get("rar", 0)), 0, 4)]) + (2 if String(it.get("el", "")) != "" else 0) + (5 if String(it.get("uq", "")) != "" else 0)
				"glove":
					it["t"] = "gear"
					out.append(it)
				_:
					out.append(it)
		data[key] = out
	data["scrap"] = scrap
	var by_uid := {}
	for key in ["armory", "raid_out"]:
		for it in data[key]: by_uid[String((it as Dictionary).get("uid", ""))] = it
	# the old glove loadout is re-keyed by where each piece really goes now (an old passive "glove" may be
	# armor or boots today); a second piece for a slot that is taken just stays in the armory, never lost
	var lo_new := {}
	var lo: Dictionary = data.get("loadout", {})
	var lo_keys: Array = lo.keys()
	lo_keys.sort()
	for k in lo_keys:
		if not ["glove0", "glove1"].has(String(k)) or not by_uid.has(String(lo[k])):
			continue
		var nk := "gear%d" % Gear.slot_of(String((by_uid[String(lo[k])] as Dictionary).get("id", "")))
		if not lo_new.has(nk):
			lo_new[nk] = lo[k]
	data["loadout"] = lo_new
	# the weapon you carry is your archetype's signature now
	var sg := Arch.signature(String(data.get("arch", "")))
	if sg != "":
		data["weapon"] = sg

## Farm materials from an extracted haul: every piece of gear brought home also gives parts
## (content/rules/gear.json "extract_mats", by rarity). Returns {"wood": n, "stone": n, "scrap": n}
## and adds them to the save.
static func extract_mats(haul: Array) -> Dictionary:
	var tab: Array = GearDrops.rules().get("extract_mats", [])
	var got := {"wood": 0, "stone": 0, "scrap": 0}
	for it in haul:
		if String((it as Dictionary).get("t", "")) != "gear" or tab.is_empty():
			continue
		var row: Dictionary = tab[clampi(int(it.get("rar", 0)), 0, tab.size() - 1)]
		for k in got:
			got[k] = int(got[k]) + int(row.get(k, 0))
	Work.add_mat("wood", int(got["wood"]))
	Work.add_mat("stone", int(got["stone"]))
	Save.d["scrap"] = int(Save.d.get("scrap", 0)) + int(got["scrap"])
	return got
