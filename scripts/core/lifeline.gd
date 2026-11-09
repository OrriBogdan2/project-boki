class_name Lifeline
## The economy floor (owner decision, ROADMAP §2 "Nobody can be locked out"): a player must never sit
## at zero Boki and zero gems with no way to play. The floors, cheapest first:
##   1. the Shelter (at the market stall): stray commons to adopt at a low price, restocked daily.
##   2. a stray: with no Boki at all on your roster (lost, starved, at the Ransom House), a stray
##      common Boki turns up at the farm. You can't empty your roster on purpose (your last Boki can't
##      be released, given up or handed on), so the only way to a stray is losing one: no gems are made from it.
## Scarce, rare and limited-edition Boki are never part of the floor: only commons.
##
## On the save (optional; an older save without it reads as "never used"):
##   Save.d["floor"] = {strays: n, last_m: matches at the last stray}

static func _st() -> Dictionary:
	if typeof(Save.d.get("floor", null)) != TYPE_DICTIONARY:
		Save.d["floor"] = {"strays": 0, "last_m": -1}
	return Save.d["floor"]

## Every Boki you have anywhere: the roster (farm and Burrow). Boki at the Ransom House or held by
## rivals aren't yours to play with right now.
static func boki_count() -> int:
	return (Save.d.get("roster", []) as Array).size()

static func gems() -> int:
	return int(Save.d.get("gems", 0))

## Can this save go on an expedition with its own Boki?
static func can_play_own() -> bool:
	return boki_count() > 0

## Can this save play at all? (A save with no Boki gets a stray at the farm, see check.)
static func can_play() -> bool:
	return can_play_own()

## Is this save at the floor: no Boki and no gems to buy one?
static func stuck() -> bool:
	return boki_count() == 0 and gems() < Shelter.cheapest()

## Has this save started (hatched its first Boki, or played)? Before that the starter flow is its floor.
static func started() -> bool:
	return bool(Save.d.get("tutorial", {}).get("hatched", false)) or boki_count() > 0 or int(Save.d.get("matches", 0)) > 0

## Applies the floor rules. Call it when you get home (after apply_result) and when a save is opened.
## Returns what happened: [{kind: "stray", rec}] (empty when nothing was needed).
static func check() -> Array:
	var out: Array = []
	if Save.d.is_empty() or not Save.d.has("roster") or not started():
		return out
	if boki_count() == 0:
		var st := _st()
		var rec := stray()
		st["strays"] = int(st["strays"]) + 1
		st["last_m"] = int(Save.d.get("matches", 0))
		out.append({"kind": "stray", "rec": rec})
	return out

## A stray common Boki turns up at the farm. It's yours.
static func stray() -> Dictionary:
	var pool: Array = Data.common_kin()
	var sp := String(pool[randi() % pool.size()])
	var rec := Save.new_kin(sp)
	rec["trust"] = 25.0
	rec["origin"] = {"how": "stray", "where": {"place": "home"}, "t": int(Time.get_unix_time_from_system())}
	Save.remember(rec, "stray", "wandered onto your farm when you had nobody", 0.0)
	Save.d["roster"].append(rec)
	if Save.kin(str(Save.d.get("active", ""))).is_empty():
		Save.d["active"] = rec["uid"]
	Save.register(rec)
	KinBox.route_new(rec)
	Care.dex_got(rec)
	return rec
