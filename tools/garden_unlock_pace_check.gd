extends RefCounted
## --garden-unlock-pace-check: how fast the garden zones open (briefs/design/GARDEN.md 10.3). Plays a new
## save forward day by day for two players on the real GardenZones, BlackMarket, Evo.eat and Lairs rule:
## a runner (expeditions each day, which drop Wayseeds and pay gems) and a garden-only player (never
## extracts, gems only from garden games, so only the Drift Trader's Wayseed). Each day the player feeds
## its Boki toward the zone it is working on, buys the trader's Wayseed when it can pay and wakes the
## zone when both keys are in hand. Prints the day-by-day table (median open zones) and fails unless the
## medians meet the targets in garden_zones.json pace. Assumptions: the pace block. Never touches the real save.

var bad := 0
var rng := RandomNumberGenerator.new()

func ok(cond: bool, what: String) -> void:
	print("UNLOCKPACE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## The snacks grown by the end of `day`: the start garden's patch (its four) plus its rotating extra
## after each of pace.ripenings a day, and the patch of each zone already open (zone_snacks of its
## theme). A zone's own snacks cannot lean a Boki to wake that zone.
func _grown(day: int) -> Array:
	var sp: Dictionary = SnackPatch.rules()
	var out: Array = sp["snacks"].duplicate()
	for r in (day - 1) * int(GardenZones.rules()["pace"]["ripenings"]):
		out.append(SnackPatch.extra(Save.d, {"rot": r}))
	for z in GardenZones.ids():
		if GardenZones.is_open(z):
			out.append_array(sp["zone_snacks"].get(z, []))
	return out

## The snack that leans a Boki toward this zone: a grown one (lean.json food whose type the zone lists).
func _snack(zone: String, day: int) -> String:
	var types: Array = GardenZones.info(zone)["types"]
	var foods: Dictionary = Lean.rules()["foods"]
	for f in _grown(day):
		if types.has(String(foods.get(f, ""))):
			return String(f)
	return ""

## The locked zone to work on: the one whose Wayseed is in the bag, else the one the trader holds,
## else the first locked.
func _target() -> String:
	var locked: Array = GardenZones.ids().filter(func(z): return not GardenZones.is_open(z))
	for z in locked:
		if bool(GardenZones.keys_for(z)["seed"]): return z
	for e in BlackMarket.stock():
		if BlackMarket.is_seed(String(e["key"])): return BlackMarket.id_of(String(e["key"]))
	return "" if locked.is_empty() else String(locked[0])

func _run(pace: Dictionary, day: int) -> void:
	if day == 1:
		return
	for _i in int(pace["runs_a_day"]):
		Save.d["gems"] = int(Save.d["gems"]) + int(pace["run_gems"])
		if rng.randf() >= float(pace["run_lair_p"]):
			continue
		var biomes: Array = pace["biomes"]
		var zone := GardenZones.seed_zone_for(String(biomes[rng.randi_range(0, biomes.size() - 1)]))
		if zone != "" and rng.randf() < float(GardenZones.rules()["wayseed_chance"]):
			Econ._store(Loot.valuable(GardenZones.wayseed(zone)))

func _buy_seed() -> void:
	for e in BlackMarket.stock():
		if BlackMarket.is_seed(String(e["key"])) and int(Save.d["gems"]) >= int(e["price"]):
			BlackMarket.buy(String(e["id"]))
			return

## One player played for pace.days days, or until `zones` are open: the day (1-based) each zone count was reached.
func _play(pace: Dictionary, runner: bool, phase: int, zones := 99) -> Array:
	Save.d = Save.fresh()
	var rec := Save.new_kin(Data.common_kin()[0], "Pace")
	Save.d["roster"] = [rec]
	MarketSave.skew_days = phase
	var opened: Array = [1]
	for day in range(1, int(pace["days"]) + 1):
		MarketSave.skew_days = phase + day - 1
		var open_n := GardenZones.ids().filter(func(z): return GardenZones.is_open(z)).size()
		Save.d["gems"] = int(Save.d["gems"]) + int(pace["garden_gems"]) + (open_n - 1) * int(pace["zone_gems"])
		if runner: _run(pace, day)
		_buy_seed()
		var zone := _target()
		if zone != "":
			var snack := _snack(zone, day)
			if snack != "":
				for _m in int(pace["meals"]): Evo.eat(rec, snack)
			if GardenZones.attune(zone)["ok"]: opened.append(day)
			_buy_seed()
		if opened.size() >= mini(zones, GardenZones.ids().size()):
			break
	return opened

## Per player kind: opened[k] = the day the k+1'th zone opened across `seeds` players.
func _sample(pace: Dictionary, runner: bool) -> Array:
	var days: Array = []
	for i in GardenZones.ids().size(): days.append([])
	rng.seed = 2610 if runner else 2611
	for s in int(pace["seeds"]):
		var opened := _play(pace, runner, s % int(Goods.rules()["black_market"]["wayseed_days"]))
		for k in days.size():
			days[k].append(-1 if k >= opened.size() else int(opened[k]))
	return days

## The garden-only route to Glasswater, from a fresh save at every point of the trader's week: played
## forward until the second zone opens, it is Glasswater, on the day zone2_day wants (the gems cover the
## trader's Wayseed by then: 60 of a new save and garden_gems a day against its price), and every starter
## species leans Water on the start patch's own tidebloom. The first-day reward is left out (it needs a pair).
func _route(pace: Dictionary) -> void:
	var week := int(Goods.rules()["black_market"]["wayseed_days"])
	var want := int(pace["zone2_day"]["garden"])
	for phase in week:
		var opened := _play(pace, false, phase, 2)
		var day := int(opened[1]) if opened.size() > 1 else -1
		var in_time: bool = day > 0 and day <= want and GardenZones.is_open("glasswater")
		ok(in_time, "garden-only, trader week day %d: Glasswater opens on day %d (by %d)" % [phase, day, want])
	var water := String(Lean.rules()["foods"].get("tidebloom", ""))
	var types: Array = GardenZones.info("glasswater")["types"]
	var grows: bool = SnackPatch.snacks(Save.fresh()).has("tidebloom") and types.has(water)
	ok(grows, "the start patch grows tidebloom, a %s snack Glasswater takes" % water)
	for sp in Data.common_kin():
		Save.d = Save.fresh()
		var rec := Save.new_kin(sp, "Pace")
		Save.d["roster"] = [rec]
		for _m in int(pace["meals"]): Evo.eat(rec, "tidebloom")
		ok(not GardenZones.leaner("glasswater").is_empty(), "%s leans Water on %d tidebloom" % [sp, int(pace["meals"])])

## The median of a list where -1 means never (counts as past the end).
func _median(list: Array) -> float:
	var v: Array = list.map(func(x): return 999 if int(x) < 0 else int(x))
	v.sort()
	return float(v[v.size() / 2])

func _table(pace: Dictionary, kind: String, days: Array) -> void:
	print("UNLOCKPACE %s: percent of players with the 2nd 3rd 4th 5th zone open, by day" % kind)
	for d in range(1, int(pace["days"]) + 1):
		var row := "UNLOCKPACE %s day %2d:" % [kind, d]
		for k in range(1, days.size()):
			var n := 0
			for x in days[k]:
				if int(x) > 0 and int(x) <= d: n += 1
			row += " %4d%%" % int(round(100.0 * n / float(days[k].size())))
		print(row)

func run(m: Node) -> void:
	Save.no_write = true
	var was: bool = Content.rules("farm_build")["base_mode"]
	Content.rules("farm_build")["base_mode"] = true
	var pace: Dictionary = GardenZones.rules()["pace"]
	var all: Array = pace["all_open_days"]
	_route(pace)
	for kind in ["runner", "garden"]:
		var days := _sample(pace, kind == "runner")
		_table(pace, kind, days)
		var last := days.size() - 1
		var med2 := _median(days[1])
		var med5 := _median(days[last])
		print("UNLOCKPACE %s: median day of the 2nd zone %d, of the %dth %d" % [kind, int(med2), last + 1, int(med5)])
		var want := int(pace["zone2_day"][kind])
		ok(int(med2) == want, "%s opens the second zone on day %d" % [kind, want])
		var what := "%s has all %d open by day %d to %d" % [kind, last + 1, int(all[0]), int(all[1])]
		ok(med5 >= float(all[0]) and med5 <= float(all[1]), what)
	MarketSave.skew_days = 0
	Content.rules("farm_build")["base_mode"] = was
	print("UNLOCKPACE %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	m.get_tree().quit(0 if bad == 0 else 1)
