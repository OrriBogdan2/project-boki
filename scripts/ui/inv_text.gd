class_name InvText
extends RefCounted
## The words on inventory hover cards, as [[text, colour, size?]] lines (the first is the title).
## A piece of gear is compared with what you wear in its slot: only the numbers that change,
## green when better and red when worse (GearCompare).

const INK := Color("f3eee2")
const MUTED := Color("a9b0bf")
const GOOD := Color("8fe0a0")
const BAD := Color("ff6a5a")
const SMALL := 12

## "Glove 1  ·  Q", "Armor", "Boots": where worn slot `slot` is and the key that uses it.
static func slot_label(slot: int) -> String:
	if slot < 2:
		return "%s  ·  %s" % [Gear.WORN_NAMES[slot], Gloves.key_cap(slot)]
	return Gear.WORN_NAMES[slot]

## Hover card for a piece of gear (not worn yet): what it does and how it differs from what you wear.
static func compare(h: Hunter, it: Dictionary) -> Array:
	var id := String(it["id"])
	var rar := int(it["rar"])
	var slot := GearCompare.slot_for(h, it)
	var worn: Dictionary = h.gear[slot]
	var out: Array = [[Loot.name_of(it), Loot.col_of(it)]]
	out.append([Gear.stat_text(id, rar), INK])
	if worn.is_empty():
		out.append(["Goes in your empty %s slot" % slot_label(slot), MUTED, SMALL])
	else:
		var worn_name := Loot.name_of(Loot.gear(String(worn["id"]), int(worn["rar"])))
		out.append(["Instead of %s  ·  %s" % [worn_name, slot_label(slot)], MUTED, SMALL])
	var changes := GearCompare.changes(it, worn)
	for c in changes:
		out.append([c[0], GOOD if c[1] else BAD])
	if changes.is_empty():
		out.append(["Same numbers as what you wear", MUTED, SMALL])
	out.append([Gear.desc_of(id, rar), MUTED, SMALL])
	return out

## Hover card for the piece you wear in slot `slot`.
static func worn(h: Hunter, slot: int, hint: String) -> Array:
	var g: Dictionary = h.gear[slot]
	if g.is_empty():
		return [[slot_label(slot), MUTED], ["Nothing worn here. Gear you find goes in this slot.", INK, SMALL]]
	var id := String(g["id"])
	var rar := int(g["rar"])
	var it := Loot.gear(id, rar)
	return [[Loot.name_of(it), Loot.col_of(it)], [slot_label(slot), MUTED, SMALL], [Gear.stat_text(id, rar), INK],
		[Gear.desc_of(id, rar), MUTED, SMALL], [hint, MUTED, SMALL]]

## Hover card for a perk and how many of it you hold.
static func perk(id: String, n: int) -> Array:
	var pd: Dictionary = Data.PERKS[id]
	return [[pd["name"] if n < 2 else "%s  x%d" % [pd["name"], n], pd["col"]], [pd["desc"], INK]]

## The piece of gear a deathbox row stands for ({} when it is not gear): a worn-style row or a pack thing.
static func box_gear(b: Dictionary, row: Dictionary) -> Dictionary:
	var key := String(row["key"])
	if key == "gear":
		var g: Dictionary = b["gear"][int(row["i"])]
		return Loot.gear(String(g["id"]), int(g["rar"]))
	if key == "pack":
		var it: Dictionary = b["pack"][int(row["i"])]
		return it if String(it.get("t", "")) == "gear" else {}
	return {}
