class_name TrainRuns
extends RefCounted
## Limited runs (the stat economy, briefs/design/GARDEN_MODERN_BALANCE.md): garden contests ("race": every
## game GardenPrizes pays) and training ("drill": the Training post drill and the training lap) have a few
## charges a day plus one more of each per match played (a few a day, banked up to bank_max). A run pays
## stat bites into the bag, never raw points; with no charge left a game still plays, as a friendly that
## pays nothing. Rules: content/rules/care.json train_runs.
## State is lazy (Save.d train_runs = {day, earned, <kind>: charges}) and needs no migration.


static func rules() -> Dictionary:
	return Content.rules("care")["train_runs"]


static func _now(now: float) -> float:
	return Time.get_unix_time_from_system() if now < 0.0 else now


## Today's charges. A new day tops each kind up to its daily count (banked extra ones stay).
static func state(now := -1.0) -> Dictionary:
	var st: Dictionary = Save.d.get_or_add("train_runs", {})
	var day := GardenWishes.day_of(_now(now))
	if int(st.get("day", -1)) != day:
		st["day"] = day
		st["earned"] = 0
		var daily: Dictionary = rules()["daily"]
		for kind in daily:
			st[kind] = maxi(int(st.get(kind, 0)), int(daily[kind]))
	return st


static func left(kind: String, now := -1.0) -> int:
	return int(state(now).get(kind, 0))


## Uses one charge of `kind`; false (and nothing used) when none is left.
static func spend(kind: String, now := -1.0) -> bool:
	var st := state(now)
	if int(st.get(kind, 0)) <= 0:
		return false
	st[kind] = int(st[kind]) - 1
	return true


## A finished match earns one more of each kind, at most match_max_day times a day. Returns charges added.
static func after_match(now := -1.0) -> int:
	var r := rules()
	var st := state(now)
	if int(st["earned"]) >= int(r["match_max_day"]):
		return 0
	st["earned"] = int(st["earned"]) + 1
	var added := 0
	for kind in r["per_match"]:
		var to := mini(int(st.get(kind, 0)) + int(r["per_match"][kind]), int(r["bank_max"]))
		added += maxi(0, to - int(st.get(kind, 0)))
		st[kind] = maxi(to, int(st.get(kind, 0)))
	return added


## "Races left today: 2"
static func line(kind: String, now := -1.0) -> String:
	return "%s left today: %d" % [String(rules()["names"][kind]), left(kind, now)]


## What a run with no charge says: it still played, it paid nothing.
static func empty_line(kind: String) -> String:
	var nm := String(rules()["names"][kind]).to_lower()
	return "No %s left today: this one was for fun. Play a match to earn one, or come back tomorrow" % nm


## Pays a finished drill or training lap of `stat` (grades: great/good/miss): with a charge and at least one
## hit, stat bites of that stat go to the bag (one, two when every mark was great, +dojo with a Dojo).
## Returns {charged, bites, id, text}: text is the result line the toast or card shows.
static func pay_drill(stat: String, grades: Array) -> Dictionary:
	var b: Dictionary = rules()["drill_bites"]
	var hits := grades.filter(func(g): return g != "miss").size()
	var out := {"charged": false, "bites": 0, "id": GardenItems.bite_for(stat), "text": ""}
	if hits == 0:
		out["text"] = "No marks hit, no run used. Try again after a rest  ·  " + line("drill")
		return out
	if not spend("drill"):
		out["text"] = empty_line("drill")
		return out
	out["charged"] = true
	var perfect := grades.size() > 0 and grades.all(func(g): return g == "great")
	var n := int(b["perfect"]) if perfect else int(b["hit"])
	if Save.has_building("dojo"):
		n += int(b["dojo"])
	out["bites"] = n
	Save.add_item(String(out["id"]), n)
	var shown := "%d %s" % [n, GardenItems.item_name(String(out["id"]))]
	out["text"] = "+%s in your bag (give it from Feed)  ·  %s" % [shown, line("drill")]
	return out
