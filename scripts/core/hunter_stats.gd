class_name HunterStats
extends RefCounted
## How you do with each Hunter, for the Stats tab on the Relics screen (HunterStatsView). Read from the
## per-Hunter tallies ClassUnlock keeps (`classes.hunters[id]`, filled by ClassUnlock.after_match);
## docs/decisions/0022. "Got out" is an expedition you escaped the islands from.

## One row: {id, matches, knocks, revives, damage, dmg_matches, outs}. `dmg_matches`: the matches whose
## damage was counted (a save from before v12 never kept damage).
static func row(id: String) -> Dictionary:
	var t: Dictionary = (ClassUnlock.state().get("hunters", {}) as Dictionary).get(id, {})
	var played := int(t.get("matches", 0))
	return {"id": id, "matches": played, "knocks": int(t.get("knocks", 0)), "revives": int(t.get("revives", 0)),
			"damage": int(t.get("damage", 0)), "dmg_matches": played - int(t.get("old_matches", 0)),
			"outs": int(t.get("extracts", 0))}

## Every Hunter you own or have played, most played first (unplayed ones last, in the usual order).
static func rows() -> Array:
	var out: Array = []
	var ids := Arch.ids()
	for a in ids:
		var r := row(String(a))
		if int(r["matches"]) > 0 or ClassUnlock.is_open(String(a)):
			out.append(r)
	out.sort_custom(func(x, y): return int(x["matches"]) > int(y["matches"]) \
			or (x["matches"] == y["matches"] and ids.find(x["id"]) < ids.find(y["id"])))
	return out

## The rows added up (id "").
static func totals(rs: Array) -> Dictionary:
	var sum := {"id": "", "matches": 0, "knocks": 0, "revives": 0, "damage": 0, "dmg_matches": 0, "outs": 0}
	for r in rs:
		for k in sum:
			if k != "id": sum[k] = int(sum[k]) + int(r[k])
	return sum

## Damage per match, or -1 when no match counted its damage yet.
static func per_match(r: Dictionary) -> int:
	return int(round(float(r["damage"]) / float(r["dmg_matches"]))) if int(r["dmg_matches"]) > 0 else -1

## v11 -> v12 (Save._migrate_11_to_12): matches and damage weren't tallied per Hunter. Each Hunter the
## save played gets the fewest matches it can have had (its get-outs, at least 1), none of them with damage.
static func migrate(data: Dictionary) -> void:
	var c = data.get("classes")
	if typeof(c) != TYPE_DICTIONARY or typeof(c.get("hunters")) != TYPE_DICTIONARY:
		return
	for id in c["hunters"]:
		var t = c["hunters"][id]
		if typeof(t) != TYPE_DICTIONARY or t.has("matches"):
			continue
		t["matches"] = maxi(1, int(t.get("extracts", 0)))
		t["old_matches"] = t["matches"]
