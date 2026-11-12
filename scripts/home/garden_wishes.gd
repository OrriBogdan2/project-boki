class_name GardenWishes
extends RefCounted
## Today's wishes (GARDEN_MODERN.md section 5, rank 1; numbers in content/rules/garden_daily.json). Each garden day
## three needs of your Boki (the same four KinWants shows as bubbles) become wishes on one card. A wish is granted
## when that need is back up, however it got there; it gives trust and a small item, all of them give gems.
## Missing a day costs nothing: the next day picks fresh ones.
## Save.d["wishes"] = {day, list: [{uid, need, done}], bonus, seen (on the arrival card today)}.

static var _check_in := 0.0
const CHECK_EVERY := 1.0       # seconds between looks at the wishes

static func rules() -> Dictionary:
	return Content.rules("garden_daily")["wishes"]

## The garden day number for a unix time: the local calendar day.
static func day_of(now: float) -> int:
	var bias := int(Time.get_time_zone_from_system()["bias"]) * 60
	return floori((now + bias) / float(Content.rules("garden_daily")["day_s"]))

## Today's wishes, picked the first time they are asked for in a day.
static func today(now: float) -> Dictionary:
	var day := day_of(now)
	var w: Dictionary = Save.d.get("wishes", {})
	if int(w.get("day", -1)) != day:
		w = {"day": day, "list": _pick(day), "bonus": false}
		Save.d["wishes"] = w
	return w

## Up to `count` wishes: Boki with a need under pick_below, a different Boki each while there are enough.
static func _pick(day: int) -> Array:
	var r := rules()
	var rng := RandomNumberGenerator.new()
	rng.seed = day
	var cands: Array = []
	for rec in Save.d["roster"]:
		if KinBox.is_boxed(rec):
			continue
		for n in r["needs"]:
			if Care.need(rec, String(n)) < float(r["pick_below"]):
				cands.append({"uid": String(rec["uid"]), "need": String(n), "done": false})
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = cands[i]
		cands[i] = cands[j]
		cands[j] = t
	var out: Array = []
	for pass_same in [false, true]:
		for c in cands:
			if out.size() < int(r["count"]) and not out.has(c) \
					and (pass_same or not out.any(func(o): return o["uid"] == c["uid"])):
				out.append(c)
	return out

static func _rec(uid: String) -> Dictionary:
	for rec in Save.d["roster"]:
		if String(rec["uid"]) == uid:
			return rec
	return {}

## Grants every wish whose need is back up. Returns the lines to show (a toast each).
static func check(now: float) -> Array:
	var r := rules()
	var w := today(now)
	var out: Array = []
	for wish in w["list"]:
		var rec := _rec(String(wish["uid"]))
		if wish["done"] or rec.is_empty() or Care.need(rec, String(wish["need"])) < float(r["wish_to"]):
			continue
		wish["done"] = true
		rec["trust"] = clampf(float(rec.get("trust", 0.0)) + float(r["trust"]), 0.0, 100.0)
		Save.add_item(String(r["item"]), int(r["item_n"]))
		CareJournal.note(rec, "had its wish granted")
		var item := Care.food_name(String(r["item"]))
		out.append("%s's wish came true: trust up, +%d %s" % [rec["name"], int(r["item_n"]), item])
	var list: Array = w["list"]
	if not w["bonus"] and list.size() == int(r["count"]) and list.all(func(x): return x["done"]):
		w["bonus"] = true
		Save.d["gems"] = int(Save.d["gems"]) + int(r["bonus_gems"])
		out.append("All of today's wishes came true: +%d gems" % int(r["bonus_gems"]))
	return out

## Every frame (home.gd): looks at the wishes now and then and toasts what came true.
static func tick(h: Node, d: float) -> void:
	_check_in -= d
	if _check_in > 0.0 or not FarmUnlocks.base_mode() or not h.visit.is_empty():
		return
	_check_in = CHECK_EVERY
	for line in check(Time.get_unix_time_from_system()):
		h._toast(line)

## The wishes for the arrival card: the open ones as lines, once a garden day (the first arrival), none after that
## or once all are granted. The tip about the rewards goes on the first card only.
static func card_lines() -> Array:
	var w := today(Time.get_unix_time_from_system())
	if w.get("seen", false) or w["bonus"]:
		return []
	w["seen"] = true
	var r := rules()
	var out: Array = []
	for wish in w["list"]:
		var rec := _rec(String(wish["uid"]))
		if not wish["done"]:
			out.append(String(r["ask"][wish["need"]]) % (rec["name"] if not rec.is_empty() else "A Boki"))
	if not out.is_empty() and not Save.d.get("wishes_told", false):
		Save.d["wishes_told"] = true
		out.append(String(r["tip"]) % [int(r["count"]), int(r["bonus_gems"])])
	return out
