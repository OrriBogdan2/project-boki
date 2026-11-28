class_name PlayStyle
extends RefCounted
## How a Boki is played with decides what it becomes (briefs/design/BOKI_PLAYSTYLE_GROWTH.md, decision 0181).
## Garden activities and what it does on expeditions build its four affinities (Evo.add). The affinity in the
## lead is its leaning, and how far it leads the next one is its tier. The leaning picks the stat that takes
## the larger share of what an expedition teaches (run_growth), pips for its end of a path meter (EvoPath) and
## the body parts its mutations roll (Evo.on_level). Every number: content/rules/playstyle.json.
## rec["style_day"] = [day, garden points taken that day] and rec["run_frac"] = {stat: part of a unit still
## owed} are lazy: an older record has neither and starts from none.


static func rules() -> Dictionary:
	return Content.rules("playstyle")


## A garden activity (group: "care", "toy", "game" or "drill"; id: its row in the rules) leans the Boki, up
## to the day's cap. Returns the affinity points it took.
static func garden(rec: Dictionary, group: String, id: String, now := -1.0) -> float:
	var tune: Dictionary = rules()["garden"]
	var row: Dictionary = tune[group].get(id, {})
	var day := GardenWishes.day_of(Time.get_unix_time_from_system() if now < 0.0 else now)
	var taken: Array = rec.get("style_day", [day, 0.0])
	if int(taken[0]) != day:
		taken = [day, 0.0]
	var given := 0.0
	for aff in row:
		var points := minf(float(row[aff]), float(tune["day_cap"]) - float(taken[1]) - given)
		if points > 0.0:
			Evo.add(rec, aff, points)
			given += points
	rec["style_day"] = [day, float(taken[1]) + given]
	return given


## What an expedition taught it: affinity points for what it did there (st: the kin's match stats).
static func learn(rec: Dictionary, st: Dictionary) -> void:
	var table: Dictionary = rules()["extraction"]
	for did in table:
		for aff in table[did] as Dictionary:
			Evo.add(rec, aff, float(st.get(did, 0)) * float(table[did][aff]))


## [affinity, tier index]: its leaning and how strong it is (tier 0 = balanced, no clear leaning yet). Worn
## path tokens do not count here: they steer the form by themselves (Evo.leading, EvoPath's token pips).
static func leaning(rec: Dictionary) -> Array:
	var scores := Evo.scores(rec, false)
	var lead := Evo.top(scores)
	var next := -INF
	for aff in scores:
		if aff != lead:
			next = maxf(next, float(scores[aff]))
	var tiers: Array = rules()["tiers"]
	var at := 0
	for i in tiers.size():
		if float(scores[lead]) - next >= float(tiers[i]["at"]):
			at = i
	return [lead, at]


## The rules row of its tier.
static func tier(rec: Dictionary) -> Dictionary:
	return rules()["tiers"][leaning(rec)[1]]


## {stat: share}: how an expedition's stat units split over its four stats (the shares add up to 1).
static func focus(rec: Dictionary) -> Dictionary:
	var lean := leaning(rec)
	var top := float(rules()["tiers"][lean[1]]["focus"])
	var stats: Dictionary = rules()["stat"]
	var out := {}
	for aff in stats:
		out[stats[aff]] = top if aff == lean[0] else (1.0 - top) / float(stats.size() - 1)
	return out


## The stat growth of one expedition it went on (lead: it was the first Boki you brought). Returns
## {stat: whole points gained, lucky extras included}; parts of a unit carry over to its next expedition.
## `lucky` (if given) gets {stat: extra points} for the gains Luck made worth more.
static func run_growth(rec: Dictionary, won: bool, lead: bool, lucky := {}) -> Dictionary:
	var tune: Dictionary = rules()["run_growth"]
	var units := float(tune["extracted"] if won else tune["lost"])
	if not lead:
		units *= float(tune["second_k"])
	var owed: Dictionary = rec.get_or_add("run_frac", {})
	var shares := focus(rec)
	var out := {}
	for stat in shares:
		var due := float(owed.get(stat, 0.0)) + units * float(shares[stat])
		var whole := floori(due + 0.0001)
		owed[stat] = maxf(0.0, due - whole)
		var gained := Care.add_stat(rec, stat, whole) if whole > 0 else 0
		if gained > 0:
			var extra := Luck.bonus(rec, gained, StatBudget.room(rec, stat), true)
			rec["stats"][stat] = int(rec["stats"][stat]) + extra
			if extra > 0:
				lucky[stat] = extra
			out[stat] = gained + extra
	Luck.end_run(rec)
	return out


## Pips its leaning adds to the end of a path meter whose path is `path` (EvoPath).
static func path_pips(rec: Dictionary, path: String) -> int:
	var lean := leaning(rec)
	return int(rules()["tiers"][lean[1]]["path_pips"]) if lean[0] == path else 0


## The body parts a mutation of affinity `aff` can roll for this Boki: the affinity's parts, without its
## signature part unless the Boki is strongly of that leaning.
static func parts(rec: Dictionary, aff: String) -> Array:
	var lean := leaning(rec)
	var pool: Array = (Evo.AFF[aff]["parts"] as Array).duplicate()
	if lean[0] != aff or not bool(rules()["tiers"][lean[1]]["signature"]):
		pool.erase(String(rules()["signature"][aff]))
	return pool


## The Boki card's line: its leaning in player words and what it does to its stats.
static func line(rec: Dictionary) -> String:
	var lean := leaning(rec)
	if int(lean[1]) == 0:
		return "Balanced so far: expeditions grow all four stats evenly. Play, train and fight one way and it leans."
	var aff: Dictionary = Evo.AFF[lean[0]]
	var stat := String(Care.STATS[rules()["stat"][lean[0]]]["name"])
	var share := int(round(100.0 * float(rules()["tiers"][lean[1]]["focus"])))
	var word := String(rules()["tiers"][lean[1]]["word"])
	return "%s %s: it %s. %s takes %d%% of what expeditions teach it." % [word, aff["name"], aff["why"], stat, share]
