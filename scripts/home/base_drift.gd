class_name BaseDrift
extends RefCounted
## Trait drift (briefs/design/GARDEN.md section 3, lever 3), on only with farm_build.json base_mode: who a Boki
## lives with slowly shapes it. Once per in-game day at home (BaseLife.step calls day()), each Boki's four traits
## move a small step toward the average of its friends (base life bonds at or above friend_at); rivals and
## strangers do not pull. A trait moves at most week_cap per drift week, and crossing a band writes a journal line
## ("Pip is getting braver"). Young Boki get the full step and cap, Grown ones only adult_share of both.
## Tuning: content/rules/base_drift.json. Optional Boki key rec["drift"] = {day, moved}.

const TRAITS := ["bravery", "loyalty", "temper", "curiosity"]

## One in-game day for these Boki records (the ones at home).
static func day(recs: Array) -> void:
	var R := Content.rules("base_drift")
	var friend_at := float(Content.rules("base_life")["friend_at"])
	var before: Array = recs.map(func(r): return (r["traits"] as Dictionary).duplicate())
	for i in recs.size():
		var friends: Array = []
		for j in recs.size():
			if j != i and BaseLife.bond(recs[i], recs[j]) >= friend_at:
				friends.append(before[j])
		_drift(recs[i], before[i], friends, R)

static func _drift(rec: Dictionary, was: Dictionary, friends: Array, R: Dictionary) -> void:
	var drift: Dictionary = rec.get("drift", {"day": 0, "moved": {}})
	rec["drift"] = drift
	if int(drift["day"]) >= int(R["week_days"]):
		drift["day"] = 0
		drift["moved"] = {}
	drift["day"] = int(drift["day"]) + 1
	_follow_friends(rec, was, friends, R)
	_zone_pull(rec, R)

static func _follow_friends(rec: Dictionary, was: Dictionary, friends: Array, R: Dictionary) -> void:
	if friends.is_empty():
		return
	var drift: Dictionary = rec["drift"]
	var age := age_share(rec, R)
	for t in TRAITS:
		var mean := 0.0
		for f in friends:
			mean += float(f.get(t, 0.5))
		mean /= friends.size()
		var left := maxf(0.0, float(R["week_cap"]) * age - float(drift["moved"].get(t, 0.0)))
		var by := clampf((mean - float(was.get(t, 0.5))) * float(R["step"]) * age, -left, left)
		drift["moved"][t] = float(drift["moved"].get(t, 0.0)) + absf(by)
		rec["traits"][t] = clampf(float(was.get(t, 0.5)) + by, 0.05, 0.95)
		_band_line(rec, t, float(was.get(t, 0.5)), float(rec["traits"][t]), R)

## How much of the step and weekly cap this Boki gets: 1 while young (young_stages), adult_share once Grown.
static func age_share(rec: Dictionary, R: Dictionary) -> float:
	return 1.0 if (R["young_stages"] as Array).has(Care.stage_name(rec)) else float(R["adult_share"])

## A journal line when the trait moved into another band (same line shape as CareJournal.note).
static func _band_line(rec: Dictionary, which: String, from: float, to: float, R: Dictionary) -> void:
	var cuts: Array = R["bands"]
	var a := cuts.filter(func(c): return from >= float(c)).size()
	var b := cuts.filter(func(c): return to >= float(c)).size()
	if a == b:
		return
	var lines: Array = rec.get("journal", [])
	var word: String = R["words"][which][0 if b > a else 1]
	lines.append({"t": Time.get_unix_time_from_system(), "words": "is getting " + word})
	rec["journal"] = lines.slice(maxi(0, lines.size() - 20))

## Living in a zone nudges its matching trait on, per_day, and not past stop_at (garden_zones.json trait_pull).
static func _zone_pull(rec: Dictionary, R: Dictionary) -> void:
	var zone := GardenZones.info(GardenZones.here)
	if zone.is_empty() or GardenZones.zone_of(rec) != GardenZones.here:
		return
	var P: Dictionary = GardenZones.rules()["trait_pull"]
	var way := -1.0 if zone.get("trait_low", false) else 1.0
	var goal := float(P["stop_at"]) if way > 0.0 else 1.0 - float(P["stop_at"])
	var now := float(rec["traits"].get(zone["trait"], 0.5))
	var by := minf(float(P["per_day"]), maxf(0.0, (goal - now) * way))
	rec["traits"][zone["trait"]] = now + by * way
	_band_line(rec, zone["trait"], now, now + by * way, R)
