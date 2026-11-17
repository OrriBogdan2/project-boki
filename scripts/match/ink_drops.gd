class_name InkDrops
extends RefCounted
## The Inks a match drops (content/rules/ink_drops.json): a lair boss gives the Ink of its kin's type,
## camp monsters and guards rarely give a random one. It is a backpack item (Loot.ink) that goes to your
## goods when you carry it out. Like UtilityDrops it rolls on its own random stream (seeded from the
## match and the spot), so the match's other rolls stay put and a remote copy agrees.

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/ink_drops.json"))
		_rules = d if d is Dictionary else {}
	return _rules

## The Ink of a lair boss: its Rare Egg's kin's type, through the type map. "" if it has none.
static func ink_of_boss(boss_kind: String) -> String:
	var sp: Dictionary = Data.KIN.get(String(Data.MOBS.get(boss_kind, {}).get("egg", "")), {})
	return String((rules()["type_ink"] as Dictionary).get(String(sp.get("theme", "")), ""))

## Maybe drops one Ink at a table's spot. ctx "boss" = the boss kind (its own Ink). Returns {kind: "ink", id} or {}.
static func roll(m, table: String, at: Vector3, ctx := {}) -> Dictionary:
	var ch := float((rules()["chance"] as Dictionary).get(table, 0.0))
	if ch <= 0.0:
		return {}
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%s|%s|ink" % [str(m.get("seed_val")), table, str(at.snapped(Vector3.ONE))])
	if r.randf() >= ch:
		return {}
	var id := ink_of_boss(String(ctx.get("boss", "")))
	if id == "":
		var inks: Array = rules()["inks"]
		id = String(inks[r.randi() % inks.size()])
	m.spawn_val(Loot.ink(id), GearDrops.spot(at, 4, 5, float(ctx.get("r", -1.0))) + Vector3(0, 0.5, 0))
	return {"kind": "ink", "id": id}
