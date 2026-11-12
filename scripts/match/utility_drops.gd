class_name UtilityDrops
extends RefCounted
## Where utility items come from in a match besides the shops: a share of the crates, chests,
## guards and bosses also drop one (chance per GearDrops table in content/rules/equal.json
## "util_drops", the kind weighted by "util_weights"), and bots start with a spare. Its own random
## stream (seeded from the match and the spot), so the match's other rolls stay put.

static func _pick(rng: RandomNumberGenerator, skip_basics := false) -> String:
	var w: Dictionary = Equal.rules().get("util_weights", {})
	var ids: Array = w.keys()
	ids.sort()
	var tot := 0.0
	for id in ids:
		if skip_basics and (id == "tonic" or id == "armor_kit"):
			continue
		tot += float(w[id])
	var r := rng.randf() * tot
	for id in ids:
		if skip_basics and (id == "tonic" or id == "armor_kit"):
			continue
		r -= float(w[id])
		if r <= 0.0:
			return String(id)
	return "tonic"

static func chance(table: String) -> float:
	var d: Dictionary = Equal.rules().get("util_drops", {})
	return float(d.get(table, d.get("_default", 0.0)))

## Maybe drops one item from a table's spot. Returns {kind: "util", id, n} or {}.
static func roll(m, table: String, at: Vector3, _rng: RandomNumberGenerator, ctx := {}) -> Dictionary:
	var ch := chance(table)
	if ch <= 0.0:
		return {}
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%s|%s|util" % [str(m.get("seed_val")), table, str(at.snapped(Vector3.ONE))])
	if r.randf() >= ch:
		return {}
	var id := _pick(r)
	var n := 1 if UtilityBelt.max_of(id) <= 2 or r.randf() < 0.6 else 2
	var p := GearDrops.spot(at, 3, 4, float(ctx.get("r", -1.0)))
	m.drop(id, p + Vector3(0, 0.5, 0), n)
	return {"kind": "util", "id": id, "n": n}

## A bot's spare: one utility item (never the basics, which everyone has) by difficulty.
static func bot_start(h, rng: RandomNumberGenerator, diff: String) -> void:
	var n := int((Equal.rules().get("bot_util", {}) as Dictionary).get(diff, 0))
	for i in n:
		UtilityBelt.grant(h, _pick(rng, true), 1)
