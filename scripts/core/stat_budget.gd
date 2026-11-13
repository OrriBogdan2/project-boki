class_name StatBudget
extends RefCounted
## Caps and diminishing gains for a Boki's four trained stats (decision 0022, GARDEN_MODERN.md 2.2).
## Numbers: content/rules/care.json stat_budget. rec.stat_frac holds each stat's part-way progress to its
## next point; rec.loose holds points a respec set free (one pool), which go back into any stat at loose_rate and
## skip the bands.

static func rules() -> Dictionary:
	return Content.rules("care")["stat_budget"]

static func ensure(rec: Dictionary) -> void:
	if not rec.has("stat_frac"):
		rec["stat_frac"] = {}
	if not rec.has("loose"):
		rec["loose"] = 0

static func cap(rec: Dictionary) -> int:
	var r := rules()
	return mini(int(r["cap_max"]), int(r["cap_base"]) + int(rec.get("level", 1)) * int(r["cap_per_level"]))

static func total(rec: Dictionary) -> int:
	var t := 0
	for s in rec["stats"]:
		t += int(rec["stats"][s])
	return t

## Points still open to stat s: under its own cap and the shared total. Never negative (old saves may be over).
static func room(rec: Dictionary, s: String) -> int:
	return maxi(0, mini(cap(rec) - int(rec["stats"].get(s, 0)), int(rules()["total_cap"]) - total(rec)))

## The share of a gain that counts for the next point of a stat holding `points`.
static func share(points: int) -> float:
	for b in rules()["bands"]:
		if points < int(b[0]):
			return float(b[1])
	return float(rules()["bands"][-1][1])

## Adds n units of training to stat s; returns whole points gained.
static func add(rec: Dictionary, s: String, n: int) -> int:
	ensure(rec)
	var gained := 0
	var loose := int(rec["loose"])
	for i in n:
		if room(rec, s) <= 0:
			rec["stat_frac"][s] = 0.0
			break
		if loose > 0:
			var g := mini(loose, mini(int(rules()["loose_rate"]), room(rec, s)))
			loose -= g
			rec["stats"][s] = int(rec["stats"][s]) + g
			gained += g
			continue
		var f := float(rec["stat_frac"].get(s, 0.0)) + share(int(rec["stats"][s]))
		if f >= 0.999:
			f = 0.0
			rec["stats"][s] = int(rec["stats"][s]) + 1
			gained += 1
		rec["stat_frac"][s] = f
	rec["loose"] = loose
	return gained

## How many more single-unit gains (plays) until stat s's next point; 0 when it cannot grow.
static func plays_to_next(rec: Dictionary, s: String) -> int:
	if room(rec, s) <= 0:
		return 0
	if int(rec.get("loose", 0)) > 0:
		return 1
	var left := 1.0 - float(rec.get("stat_frac", {}).get(s, 0.0))
	return ceili(left / share(int(rec["stats"][s])) - 0.001)

## What a stat counts for on an expedition.
static func match_points(rec: Dictionary, s: String) -> int:
	return mini(int(rec["stats"][s]), int(rules()["expedition_stat_points"]))
