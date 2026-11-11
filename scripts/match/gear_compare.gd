class_name GearCompare
extends RefCounted
## What changes if you put a piece of gear on in place of what you wear: only the numbers that move.
## Every gear stat is better when higher, and a glove's cooldown is better when lower, so a change is
## good (green) or bad (red) by its sign alone.

## The slot `it` would be worn in on `h`: the one it replaces (Gear.slot_on).
static func slot_for(h, it: Dictionary) -> int:
	return Gear.slot_on(h, String(it["id"]))

## The changes from `worn` (a {id, rar} slot, or {} when empty) to `it`, as [[text, is_better]].
static func changes(it: Dictionary, worn: Dictionary) -> Array:
	var out: Array = []
	var id := String(it["id"])
	var now := _stats(worn)
	var next := _stats_of(id, int(it["rar"]))
	for stat in Gear.ALL[id]["stats"].keys() + now.keys():
		var delta := float(next.get(stat, 0.0)) - float(now.get(stat, 0.0))
		var text := Gear.stat_label(String(stat), delta)
		var line := [text, delta > 0.0]
		if text != "" and not out.has(line):
			out.append(line)
	if not worn.is_empty() and Gear.active(id) and Gear.active(String(worn["id"])):
		var cd := Gear.cd_of(id, int(it["rar"])) - Gear.cd_of(String(worn["id"]), int(worn["rar"]))
		if int(round(cd)) != 0:
			out.append(["%+ds cooldown" % int(round(cd)), cd < 0.0])
	return out

static func _stats(worn: Dictionary) -> Dictionary:
	if worn.is_empty():
		return {}
	return _stats_of(String(worn["id"]), int(worn["rar"]))

static func _stats_of(id: String, rar: int) -> Dictionary:
	var out := {}
	var st: Dictionary = Gear.ALL[id]["stats"]
	for s in st:
		out[s] = float(Gear.pack_bonus(rar, float(st[s]))) if s == "pack" else float(st[s]) * Gear.mult(rar)
	return out
