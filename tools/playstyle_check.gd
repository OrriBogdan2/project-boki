extends RefCounted
## --playstyle-check (briefs/design/BOKI_PLAYSTYLE_GROWTH.md, decision 0181): how a Boki is played
## with decides what it becomes. Garden play and care give 0 raw stat points and only lean it (up to a day
## cap); stats grow on expeditions, split by its leaning; two Boki of one species raised differently through
## RUNS expeditions end with different stat focus, path meter end and mutation parts. Never touches the save.

const T0 := 1800000000.0  # a fixed moment; T0 + DAY is the next garden day
const DAY := 86400.0
const RUNS := 20  # expeditions each raised Boki goes on
const ROLLS := 200  # seeded mutation rolls per Boki
const FIGHTER := {"hits": 30, "kos": 3, "skills": 4, "throws": 4, "won": 1}  # one expedition's kin stats
const SCOUT := {"hits": 6, "skills": 30, "caught": 1, "throws": 4, "won": 1}

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("PLAYSTYLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


## A Zapple (its line branches: Howlop fierce, Chimelop curious) at the level its path meter is due, with an
## even personality, no stats and no affinity.
func _rec(named: String) -> Dictionary:
	var rec := Save.new_kin("zapple", named)
	rec["uid"] = "check_" + named  # a fixed id: its luck rolls are seeded from it
	rec["level"] = EvoPath.level(rec)
	Care.ensure(rec)
	Evo.ensure(rec)
	for stat in rec["stats"]:
		rec["stats"][stat] = 0
	for trait_id in rec["traits"]:
		rec["traits"][trait_id] = 0.5
	rec["lean"] = {}
	rec["path"] = []
	return rec


func _tables() -> void:
	var r := PlayStyle.rules()
	var stats: Array = r["stat"].values()
	ok(
		r["stat"].keys() == Evo.AFF.keys() and stats.all(func(s): return Care.STATS.has(s)) and _unique(stats),
		"each of the four affinities focuses its own stat %s" % str(r["stat"])
	)
	var garden: Dictionary = r["garden"]
	var missing := []
	for toy in HomeToys.rules()["toys"]:
		if not garden["toy"].has(toy):
			missing.append(toy)
	for game in GardenPrizes.rules()["games"]:
		if not garden["game"].has(game):
			missing.append(game)
	for stat in Care.STATS:
		if not garden["drill"].has(stat):
			missing.append(stat)
	ok(missing.is_empty(), "every toy, garden game and drill has a leaning row (missing: %s)" % str(missing))
	var unknown := []
	for table in [garden["care"], garden["toy"], garden["game"], garden["drill"], r["extraction"]]:
		for id in table:
			for aff in table[id]:
				if not Evo.AFF.has(aff):
					unknown.append(aff)
	ok(unknown.is_empty(), "every row names real affinities (unknown: %s)" % str(unknown))
	var tiers: Array = r["tiers"]
	var rising := int(tiers[0]["at"]) == 0 and is_equal_approx(float(tiers[0]["focus"]), 0.25)
	for i in range(1, tiers.size()):
		var up: bool = float(tiers[i]["at"]) > float(tiers[i - 1]["at"])
		rising = rising and up and float(tiers[i]["focus"]) > float(tiers[i - 1]["focus"])
	ok(rising and float(tiers[-1]["focus"]) < 1.0, "tiers rise from an even split (0.25) to a larger focus share")
	for aff in Evo.AFF:
		var part := String(r["signature"][aff])
		var owners := Evo.AFF.keys().filter(func(a): return (Evo.AFF[a]["parts"] as Array).has(part))
		ok(owners == [aff], "%s's signature part %s is its own alone" % [aff, part])


func _unique(list: Array) -> bool:
	var seen := {}
	for v in list:
		seen[v] = true
	return seen.size() == list.size()


## A month of garden play and care, spammed: no stat point, and the leaning it builds stops at the day cap.
func _garden_gives_no_stat() -> void:
	var rec := _rec("Homebody")
	var garden: Dictionary = PlayStyle.rules()["garden"]
	var stats0: Dictionary = rec["stats"].duplicate()
	var most := 0.0
	for day in 30:
		var taken := 0.0
		for spam in 20:
			for group in ["care", "toy", "game", "drill"]:
				for id in garden[group]:
					taken += PlayStyle.garden(rec, group, id, T0 + day * DAY)
		most = maxf(most, taken)
	for spam in 20:
		for kind in ["petted", "played", "talked", "pet_win"]:
			Care.care_day(rec, kind)
	ok(rec["stats"] == stats0, "30 days of spammed play, care, toys, games and drills: 0 stat points %s" % rec["stats"])
	ok(
		is_equal_approx(most, float(garden["day_cap"])),
		"the garden leans it at most %d points a day (most taken: %.1f)" % [int(garden["day_cap"]), most]
	)
	ok(PlayStyle.run_growth(rec, true, true).size() > 0, "its first expedition grows its stats")


## One day of raising: its garden habits, then an expedition where it did `did`.
func _raise(rec: Dictionary, day: int, habits: Array, did: Dictionary) -> void:
	for habit in habits:
		PlayStyle.garden(rec, String(habit[0]), String(habit[1]), T0 + day * DAY)
	PlayStyle.learn(rec, did)
	PlayStyle.run_growth(rec, true, true)


## The share of `ROLLS` seeded mutation rolls that grow each part.
func _mutations(rec: Dictionary) -> Dictionary:
	var grown := {}
	for i in ROLLS:
		var copy := rec.duplicate(true)
		copy["muts"] = []
		copy["level"] = 38  # a mutation level (every 4 from 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var part := String(Evo.on_level(copy, rng).get("part", ""))
		grown[part] = int(grown.get(part, 0)) + 1
	return grown


func _in_pool(grown: Dictionary, aff: String) -> int:
	var n := 0
	for part in grown:
		if (Evo.AFF[aff]["parts"] as Array).has(part):
			n += int(grown[part])
	return n


func _raised_differently() -> void:
	var fighter := _rec("Fighter")
	var scout := _rec("Scout")
	var both := _rec("Both")
	var fight_habits := [["toy", "toy_post"], ["drill", "power"], ["care", "pet_win"]]
	var scout_habits := [["toy", "toy_tub"], ["drill", "focus"], ["care", "talked"]]
	for day in RUNS:
		_raise(fighter, day, fight_habits, FIGHTER)
		_raise(scout, day, scout_habits, SCOUT)
		if day % 2 == 0:
			_raise(both, day, fight_habits, FIGHTER)
		else:
			_raise(both, day, scout_habits, SCOUT)
	var f_lean := PlayStyle.leaning(fighter)
	var s_lean := PlayStyle.leaning(scout)
	ok(
		f_lean[0] == "fierce" and s_lean[0] == "curious" and int(f_lean[1]) >= 2 and int(s_lean[1]) >= 2,
		"%d expeditions: the fighter leans %s, the scout %s" % [RUNS, f_lean, s_lean]
	)
	var fs: Dictionary = fighter["stats"]
	var ss: Dictionary = scout["stats"]
	ok(
		int(fs["power"]) >= 2 * int(fs["focus"]) and int(ss["focus"]) >= 2 * int(ss["power"]),
		"stat focus diverges: fighter %s, scout %s" % [fs, ss]
	)
	var f_total := StatBudget.total(fighter)
	var s_total := StatBudget.total(scout)
	var units := RUNS * float(PlayStyle.rules()["run_growth"]["extracted"])
	ok(
		absi(f_total - s_total) <= 4 and f_total > 0 and f_total <= int(units),
		"same road, different shape: %d and %d points from %d expedition units" % [f_total, s_total, int(units)]
	)
	var f_end := EvoPath.winner(fighter)
	var s_end := EvoPath.winner(scout)
	ok(
		f_end == 0 and s_end == 1 and EvoPath.pick(fighter) != EvoPath.pick(scout),
		"evolution branch diverges: %s and %s" % [EvoPath.pick(fighter), EvoPath.pick(scout)]
	)
	var play_pips := func(rec: Dictionary, end: int) -> int:
		var n := 0
		for pip in EvoPath.pips(rec)[end]:
			if pip["source"] == "play":
				n += int(pip["count"])
		return n
	ok(
		play_pips.call(fighter, 0) > 0 and play_pips.call(fighter, 1) == 0 and play_pips.call(scout, 1) > 0,
		"the path meter counts how it plays (fighter end 0: %d pips)" % play_pips.call(fighter, 0)
	)
	var f_parts := _mutations(fighter)
	var s_parts := _mutations(scout)
	var sig: Dictionary = PlayStyle.rules()["signature"]
	ok(
		_in_pool(f_parts, "fierce") > ROLLS * 0.7 and _in_pool(s_parts, "curious") > ROLLS * 0.7,
		"mutations follow the leaning: fighter %s, scout %s" % [f_parts, s_parts]
	)
	ok(
		int(f_parts.get(sig["fierce"], 0)) > 0 and int(s_parts.get(sig["curious"], 0)) > 0,
		"a strong leaning unlocks its signature part (%s, %s)" % [sig["fierce"], sig["curious"]]
	)
	var others := func(parts: Dictionary, own: String) -> int:
		var n := 0
		for aff in sig:
			if aff != own:
				n += int(parts.get(sig[aff], 0))
		return n
	ok(
		others.call(f_parts, "fierce") == 0 and others.call(s_parts, "curious") == 0,
		"and never rolls another leaning's signature part"
	)
	var b_lean := PlayStyle.leaning(both)
	var bs: Dictionary = both["stats"]
	var b_parts := _mutations(both)
	var spread := int(bs.values().max()) - int(bs.values().min())
	ok(int(b_lean[1]) <= 1 and spread < int(fs["power"]) - int(fs["focus"]), "raised both ways it stays broad: %s" % bs)
	ok(
		int(b_parts.get(sig["fierce"], 0)) + others.call(b_parts, "fierce") == 0,
		"and grows no signature part %s" % b_parts
	)
	ok(
		PlayStyle.line(fighter).contains("Fierce") and PlayStyle.line(fighter).contains("Power"),
		"card line: %s" % PlayStyle.line(fighter)
	)
	ok(PlayStyle.line(_rec("New")).begins_with("Balanced"), "a new Boki's line: %s" % PlayStyle.line(_rec("New")))
	var worn := _rec("Worn")
	worn["path"] = ["keepstone", "keepstone", "keepstone", "keepstone"]
	ok(
		Evo.leading(worn) == "steadfast" and int(PlayStyle.leaning(worn)[1]) == 0,
		"worn path tokens steer the form but are not a leaning (it stays Balanced)"
	)


## The shares of a tier split one expedition exactly, and the long road: a devoted Boki's focus stat needs
## many expeditions to reach its cap.
func _focus_and_road() -> void:
	var tiers: Array = PlayStyle.rules()["tiers"]
	var units := float(PlayStyle.rules()["run_growth"]["extracted"])
	for i in tiers.size():
		var rec := _rec("Tier%d" % i)
		Evo.add(rec, "swift", float(tiers[i]["at"]) + 10.0)
		var shares := PlayStyle.focus(rec)
		var sum := 0.0
		for stat in shares:
			sum += float(shares[stat])
		var want := float(tiers[i]["focus"]) if i > 0 else 0.25
		ok(
			is_equal_approx(sum, 1.0) and is_equal_approx(float(shares["speed"]), want),
			"%s: Speed takes %.2f of an expedition, shares add up to %.2f" % [tiers[i]["word"], shares["speed"], sum]
		)
	var rec := _rec("Devoted")
	rec["level"] = Evo.cap()
	Evo.add(rec, "fierce", float(tiers[-1]["at"]) + 10.0)
	var runs := 0
	while int(rec["stats"]["power"]) < StatBudget.cap(rec) and runs < 500:
		PlayStyle.run_growth(rec, true, true)
		runs += 1
	ok(
		runs >= 30 and runs < 500,
		"the long road: Power 0 to %d takes %d expeditions got out of" % [StatBudget.cap(rec), runs]
	)
	var lost := _rec("Lost")
	var won := _rec("Won")
	for i in 10:
		PlayStyle.run_growth(lost, false, true)
		PlayStyle.run_growth(won, true, true)
	ok(
		(
			StatBudget.total(lost) < StatBudget.total(won)
			and StatBudget.total(won) >= int(10 * units)
			and StatBudget.total(won) <= int(15 * units)
		),  # (a lucky point is worth one more)
		"10 runs: got out %d points, did not %d" % [StatBudget.total(won), StatBudget.total(lost)]
	)


## The real result path: an expedition teaches the Boki that went (stats and leaning), and the card says so.
func _wired() -> void:
	var rec := _rec("Wired")
	Save.d["roster"] = [rec]
	Save.d["active_kin"] = rec["uid"]
	var kin_run := {"uid": rec["uid"], "events": [], "trust": float(rec["trust"]), "stats": FIGHTER}
	var result := {"extracted": true, "why": "test", "caught": [], "seeds": {}, "kin_runs": [kin_run]}
	var out := Game.apply_result(result)
	var gains: Dictionary = out["kin_gains"][0]
	var grew: Dictionary = gains["stats"]
	var total := 0
	for stat in grew:
		total += int(grew[stat])
	ok(
		total > 0 and total == StatBudget.total(rec) and float(rec["aff"]["fierce"]) > 0.0,
		"Game.apply_result: the expedition grew %s and leaned it fierce (%.1f)" % [grew, rec["aff"]["fierce"]]
	)
	var text := ResultsBokiLines.gain_text(30, 0.0, {"power": 2})
	ok(text == "+30 XP, bond unchanged, Power +2", "the results line names the stat: %s" % text)


## Lucky gains (scripts/core/luck.gd, content/rules/luck.json): the base rate, the cap, treats and toys, and that
## luck only ever speeds a gain that happened: no source, no point; the caps still hold.
func _luck() -> void:
	var r := Luck.rules()
	var rec := _rec("Lucky")
	var hits := 0
	for i in 10000:
		hits += Luck.bonus(rec, 1, 1)
	var rate := float(hits) / 10000.0
	ok(
		absf(rate - float(r["base"])) < 0.012,
		"10000 seeded rolls with no buff: %.1f%% lucky (base %d%%)" % [rate * 100.0, roundi(float(r["base"]) * 100.0)]
	)
	var from_nothing := 0
	for i in 2000:
		from_nothing += Luck.bonus(rec, 0, 5)
	ok(from_nothing == 0, "no point gained, no lucky point: luck alone gives nothing")
	var room0 := 0
	for i in 2000:
		room0 += Luck.bonus(rec, 3, 0, true)
	ok(room0 == 0, "a stat with no room left takes no lucky extra")
	var peak := 0.0
	for tier in r["tiers"]:
		rec["luck"] = {"add": float(r["tiers"][tier]), "left": 3}
		rec["luck_toy"] = true
		peak = maxf(peak, Luck.chance(rec, true))
	ok(
		(
			is_equal_approx(peak, float(r["cap"]))
			and float(r["tiers"]["rare_fav"]) > float(r["tiers"]["fav"])
			and float(r["tiers"]["fav"]) > float(r["tiers"]["rare_liked"])
			and float(r["tiers"]["rare_liked"]) > float(r["tiers"]["liked"])
		),
		(
			"tiers rise to the rare favourite; with the toy too the chance stops at %d%% (peak %.2f)"
			% [roundi(float(r["cap"]) * 100.0), peak]
		)
	)
	rec.erase("luck_toy")
	var rare_favs := 0
	for i in 2000:
		var o := {"uid": "fav%d" % i}
		rare_favs += 1 if bool(GardenItems.item(Luck.favourite(o))["effect"]["rare"]) else 0
	var share := float(rare_favs) / 2000.0
	ok(
		absf(share - float(r["rare_fav"])) < 0.05,
		"%.0f%% of Boki have a rare favourite treat (data %d%%)" % [share * 100.0, roundi(float(r["rare_fav"]) * 100.0)]
	)
	_luck_treats()


## Treats: tier, the buff that lasts a few gains, the favourite learned on the first try, the drop tables.
func _luck_treats() -> void:
	var rec := _rec("Picky")
	var fav := Luck.favourite(rec)
	var other := String(Luck.treats(false)[0] if Luck.treats(false)[0] != fav else Luck.treats(false)[1])
	ok(
		Luck.favourite(rec) == fav and Luck.tier(rec, other) == "liked",
		"its favourite treat %s is fixed; another common treat is just liked" % fav
	)
	ok(
		not (rec["known"] as Array).has("treat") and Luck.line(rec) == "",
		"nothing is known or running before it eats one"
	)
	var first := GardenItems.apply(rec, other)
	ok(
		(
			bool(first["ok"])
			and not bool(first["love"])
			and Luck.left(rec) == int(Luck.rules()["charges"])
			and Luck.line(rec).contains("next 3")
		),
		"a liked treat starts a buff: %s" % Luck.line(rec)
	)
	var weak := Luck.chance(rec)
	var loved := GardenItems.apply(rec, fav)
	ok(
		bool(loved["love"]) and bool(loved["new"]) and Luck.chance(rec) > weak and (rec["known"] as Array).has("treat"),
		"its favourite is a bigger buff and is found out on the first try"
	)
	ok(
		not bool(GardenItems.apply(rec, fav)["new"]) and AboutView.treat_short(rec).contains("Loves"),
		"the second time it is not news; the card names it"
	)
	var strong := Luck.chance(rec)
	GardenItems.apply(rec, other)
	ok(is_equal_approx(Luck.chance(rec), strong), "a weaker treat never lowers a stronger buff")
	for i in int(Luck.rules()["charges"]):
		Luck.bonus(rec, 1, 1)
	ok(
		Luck.left(rec) == 0 and is_equal_approx(Luck.chance(rec), float(Luck.rules()["base"])),
		"after its gains the buff is gone and the base chance is back"
	)
	var toy_rec := _rec("Player")
	Luck.toy_played(toy_rec)
	ok(
		Luck.chance(toy_rec, true) > Luck.chance(toy_rec) and Luck.line(toy_rec).contains("expedition"),
		"its favourite toy buffs the next expedition only"
	)
	PlayStyle.run_growth(toy_rec, true, true)
	ok(not toy_rec.has("luck_toy"), "the toy buff ends with that expedition")
	var d: Dictionary = GardenItems.rules()["treat_drop"]
	ok(
		(
			GardenItems.treat_drop(0.0, 1) in Luck.treats(true)
			and GardenItems.treat_drop(float(d["lair_rare"]) + 0.01, 1) in Luck.treats(false)
			and GardenItems.treat_drop(0.99, 0) == ""
		),
		"a lair pile holds a rare treat on the lowest rolls, a common one above, none above that"
	)
	ok(
		(
			GardenItems.kill_treat("warden", 0.0, 0) in Luck.treats(true)
			and GardenItems.kill_treat("warden", 0.09, 0) in Luck.treats(false)
			and GardenItems.kill_treat("skitter", 0.0, 0) == ""
		),
		"a warden can drop a treat (rarely a rare one), a skitter never"
	)
	var all_known := true
	for id in Luck.treats(false) + Luck.treats(true):
		all_known = (
			all_known
			and Loot.VALUABLES.get(id, {}).get("bag", false)
			and String(Loot.VALUABLES[id]["name"]) == GardenItems.item_name(id)
		)
	ok(all_known, "every luck treat is carried home as bag treasure under its own name")


## Luck on real gains: a stat never passes its cap, an expedition and a bite both report their lucky points.
func _luck_gains() -> void:
	var rec := _rec("Fed")
	rec["level"] = 1
	var cap := StatBudget.cap(rec)
	var lucky_seen := 0
	for i in 30:
		rec["luck"] = {"add": 0.4, "left": 99}
		var pv := GardenItems.apply(rec, "thumpnut")
		lucky_seen += int(pv.get("lucky", 0))
	ok(
		int(rec["stats"]["power"]) <= cap and StatBudget.total(rec) <= int(StatBudget.rules()["total_cap"]),
		"30 lucky bites: Power %d never passes its cap %d" % [int(rec["stats"]["power"]), cap]
	)
	ok(lucky_seen > 0, "a lucky bite reports its extra points (%d seen)" % lucky_seen)
	var run := _rec("Runner")
	var plain := _rec("Plain")
	var lucky := {}
	var extra := 0
	for i in 40:
		run["luck"] = {"add": 0.4, "left": 99}
		run["level"] = 12
		plain["level"] = 12
		PlayStyle.run_growth(run, true, true, lucky)
		extra += (
			int(lucky.get("power", 0))
			+ int(lucky.get("focus", 0))
			+ int(lucky.get("guard", 0))
			+ int(lucky.get("speed", 0))
		)
		lucky.clear()
		PlayStyle.run_growth(plain, true, true)
	ok(
		StatBudget.total(run) > StatBudget.total(plain) and StatBudget.total(run) <= StatBudget.cap(run) * 4,
		(
			"40 lucky expeditions: %d points against %d without luck, extras reported: %d"
			% [StatBudget.total(run), StatBudget.total(plain), extra]
		)
	)
	var text := ResultsBokiLines.gain_text(30, 0.0, {"power": 3}, {"power": 1})
	ok(text.contains("Lucky! +2 instead of +1"), "the results line shows the lucky pop: %s" % text)


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_tables()
	_garden_gives_no_stat()
	_raised_differently()
	_focus_and_road()
	_wired()
	_luck()
	_luck_gains()
	print("PLAYSTYLE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
