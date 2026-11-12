class_name GardenAway
extends RefCounted
## What coming back to the garden brings (GARDEN_MODERN.md section 5, rank 3; numbers in garden_daily.json).
## One small gift per gift_every_h away (gift_max at most), toys that trained a quarter as fast as at home
## (toy_cap points a Boki at most), and snack-patch batches beyond the one on the patch going to the feeder
## bowl. It only ever adds: no need, stat or item goes down, and a short trip gives nothing.

static func rules() -> Dictionary:
	return Content.rules("garden_daily")["away"]

## The lines for the "While you were away" card; `since` is the last arrival's time (0 for the first).
static func arrive(since: float, now: float) -> Array:
	if since <= 0.0 or now <= since:
		return []
	var out: Array = _gifts(now - since, now)
	if FarmUnlocks.base_mode():
		out.append_array(_toys(now - since, now))
		out.append_array(_patch_overflow(now))
	return out

static func gift_count(gone_s: float) -> int:
	var r := rules()
	return clampi(floori(gone_s / (float(r["gift_every_h"]) * 3600.0)), 0, int(r["gift_max"]))

## Each gift is a snack its Boki's leading lean loves, from a different Boki when there are several.
static func _gifts(gone_s: float, now: float) -> Array:
	var roster: Array = Save.d["roster"].filter(func(r): return not KinBox.is_boxed(r))
	var out: Array = []
	if roster.is_empty():
		return out
	for i in gift_count(gone_s):
		var rec: Dictionary = roster[(int(now) + i) % roster.size()]
		var food := String(Evo.AFF[Evo.leading(rec)]["food"])
		Save.d["crops"][food] = int(Save.d["crops"].get(food, 0)) + 1
		var words := "saved you a snack: %s" % Care.food_name(food)
		CareJournal.note(rec, words, now)
		out.append("%s %s" % [rec["name"], words])
	return out

## Points a Boki trains at a toy on the layout while away: the toy it fancies most, a quarter rate, capped.
static func _toys(gone_s: float, now: float) -> Array:
	var r := rules()
	var points := mini(floori(gone_s * float(r["toy_rate"]) / float(r["toy_cycle_s"])), int(r["toy_cap"]))
	var defs: Dictionary = HomeToys.rules()["toys"]
	var owned: Array = HomeLayout.of(Save.d)["deco"].map(func(e): return String(e["id"]))
	owned = owned.filter(func(id): return defs.has(id))
	var out: Array = []
	if points <= 0 or owned.is_empty():
		return out
	for rec in Save.d["roster"]:
		if KinBox.is_boxed(rec):
			continue
		Care.ensure(rec)
		owned.sort_custom(func(a, b): return HomeToys.weight(rec, a) > HomeToys.weight(rec, b))
		var stat := String(defs[owned[0]]["stat"])
		var room := Care.stat_cap(rec) - int(rec["stats"].get(stat, 0))
		if room <= 0:
			continue      # add_stat clamps, so a stat already past the cap must not go through it
		var gained := Care.add_stat(rec, stat, mini(room, points))
		if gained > 0:
			var words := "trained %s at the toys: +%d" % [String(Care.STATS[stat]["name"]).to_lower(), gained]
			CareJournal.note(rec, words, now)
			out.append("%s %s" % [rec["name"], words])
	return out

## The patch keeps one ripe batch; the batches it grew beyond that while you were out fill the feeder bowl, and
## what does not fit stays in the pantry, so nothing is lost.
static func _patch_overflow(now: float) -> Array:
	var e := SnackPatch.entry(Save.d)
	if e.is_empty() or not e.has(SnackPatch.RIPE_KEY):
		return []
	var grow := float(SnackPatch.rules()["grow_secs"])
	var batches := mini(floori((now - float(e[SnackPatch.RIPE_KEY])) / grow) - 1, int(rules()["patch_overflow_max"]))
	if batches <= 0:
		return []
	e[SnackPatch.RIPE_KEY] = now - grow
	var bowl := 0
	for snack in SnackPatch.rules()["snacks"]:
		Save.d["crops"][snack] = int(Save.d["crops"].get(snack, 0)) + batches
		var left := batches
		for f in Econ.feeders():
			var put := Econ.put_in(f, String(snack), left)
			left -= put
			bowl += put
	var made := batches * (SnackPatch.rules()["snacks"] as Array).size()
	return ["The snack patch grew %d extra snacks: %d in the feeder bowl, the rest in the pantry" % [made, bowl]]
