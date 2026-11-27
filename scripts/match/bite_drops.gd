class_name BiteDrops
extends RefCounted
## Stat bites from kills (content/rules/garden_items.json kill_drop): the pieces a player carries home and
## gives to a Boki to raise a stat (the stat economy, briefs/design/GARDEN_MODERN_BALANCE.md). Like InkDrops
## it rolls on its own random stream, seeded from the match and the spot, so the match's other rolls stay
## put and a remote copy agrees.


## Maybe drops one stat bite at a table's spot. Returns {kind: "bite", id} or {}.
static func roll(m, table: String, at: Vector3, ctx := {}) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%s|%s|bite" % [str(m.get("seed_val")), table, str(at.snapped(Vector3.ONE))])
	var id := GardenItems.kill_drop(table, r.randf(), r.randi())
	if id == "":
		return {}
	m.spawn_val(Loot.valuable(id), GearDrops.spot(at, 3, 5, float(ctx.get("r", -1.0))) + Vector3(0, 0.5, 0))
	return {"kind": "bite", "id": id}
