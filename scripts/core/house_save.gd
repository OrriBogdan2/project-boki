class_name HouseSave
extends RefCounted
## Save-side half of the empty house: the v10 -> v11 migration. A house used to start furnished, with the
## journal and the gramophone fixed to the back wall. Now it starts empty and every piece can be moved or
## stored. A save that has played keeps what its house had (and the journal and gramophone become pieces
## standing where they stood); a save that has not starts with those two in storage.

const OLD_START := [["bed", 1, 1], ["rug", 4, 4], ["table", 6, 1], ["chair", 6, 2], ["lamp", 0, 6], ["stove", 9, 1],
	["kin_bed", 8, 6], ["plant", 9, 6]]
const OLD_FIXED := [["journal", 7, 0], ["gramophone", 8, 0]]

static func migrate(data: Dictionary) -> void:
	if typeof(data.get("decor")) != TYPE_DICTIONARY:
		data["decor"] = {}
	if typeof(data.get("furniture")) != TYPE_DICTIONARY:
		data["furniture"] = {}
	if (data.get("roster", []) as Array).is_empty():
		for id in ["journal", "gramophone"]:
			data["furniture"][id] = maxi(1, int(data["furniture"].get(id, 0)))
		return
	var decor: Dictionary = data["decor"]
	if typeof(decor.get("house")) != TYPE_ARRAY:
		decor["house"] = OLD_START.map(func(p): return {"id": p[0], "x": p[1], "z": p[2], "r": 0})
	for p in OLD_FIXED:
		decor["house"].append({"id": p[0], "x": p[1], "z": p[2], "r": 0})
