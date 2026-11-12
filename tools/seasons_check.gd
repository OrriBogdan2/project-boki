extends RefCounted
## --seasons-check: garden seasons (scripts/home/garden_seasons.gd, content/rules/garden_seasons.json,
## GARDEN_MODERN.md 5 rank 9).
##   1. the data: five zones, each twist resolves for the zone's game, each snack is a real crop the patch lacks
##   2. rotation by date: a season lasts `weeks` weeks of the weekly-event clock, goes round in list order, wraps
##   3. the twist applies to the in-season game (the weekly format wins for its own game) and reaches the Runs
##   4. the snack patch grows the season snack only in its season
##   5. the in-season game's Crown gives the keepsake once a season; other games' Crowns do not
## Never touches the real save.

const WEEK := 604800.0

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SEASONS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_data()
	_rotation()
	_twists()
	_snacks()
	_keepsake()
	print("SEASONS DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

func _seasons() -> Array:
	return GardenSeasons.rules()["seasons"]

## The first week at or after `from` whose season is `zone`.
func _week_of(zone: String, from := 0) -> int:
	var w := from
	while GardenSeasons.season(w)["zone"] != zone:
		w += 1
	return w

func _data() -> void:
	var zones := {}
	for s in _seasons():
		zones[s["zone"]] = true
		var tw := GardenSeasons.twist(s["game"], _week_of(s["zone"]))
		ok(tw.get("id", "") == s["twist"] and tw["game"] == s["game"], "%s: twist %s is a %s twist" % [
				s["zone"], s["twist"], s["game"]])
		var crop: bool = Data.CROPS.has(s["snack"]) and not SnackPatch.rules()["snacks"].has(s["snack"])
		var what := "%s: snack %s is a crop the patch lacks" % [s["zone"], s["snack"]]
		ok(crop and GardenPrizes.ids().has(s["game"]), what)
	ok(zones.size() == 5 and _seasons().size() == 5, "five zones take turns")

func _rotation() -> void:
	var weeks := int(GardenSeasons.rules()["weeks"])
	var t := float(Time.get_unix_time_from_datetime_string("2026-11-11T12:00:00"))
	var w := BaseRace.week_now(t)
	ok(w == int(t / WEEK), "the date maps to the weekly-event week (%d)" % w)
	var start := w - w % weeks
	var first := GardenSeasons.season(start)
	var held := true
	for i in weeks:
		held = held and GardenSeasons.season(start + i) == first
	ok(held, "one season holds for %d weeks" % weeks)
	var i0 := _seasons().find(first)
	var next := GardenSeasons.season(start + weeks)
	ok(next == _seasons()[(i0 + 1) % _seasons().size()], "then the next zone in the list (%s -> %s)" % [
			first["zone"], next["zone"]])
	ok(GardenSeasons.season(start + weeks * _seasons().size()) == first, "and it wraps round after every zone")
	var day_before := GardenSeasons.season(BaseRace.week_now(start * WEEK - 1.0))
	ok(day_before != first, "the second before the season starts belongs to the last one")

func _twists() -> void:
	for s in _seasons():
		var w := _week_of(s["zone"])
		while BaseRace.twist(w)["game"] == s["game"]:
			w = _week_of(s["zone"], w + 1)
		var tw := BaseRace.tweak(s["game"], w)
		ok(tw.get("id", "") == s["twist"], "%s season: %s plays %s" % [s["zone"], s["game"], s["twist"]])
		var off := true
		for g in GardenPrizes.ids():
			if g != s["game"] and g != BaseRace.twist(w)["game"]:
				off = off and BaseRace.tweak(g, w).is_empty()
		ok(off, "%s season: games neither in season nor this week's play as usual" % s["zone"])
	var clash := 0
	while BaseRace.twist(clash)["game"] != GardenSeasons.season(clash)["game"]:
		clash += 1
	ok(BaseRace.tweak(BaseRace.twist(clash)["game"], clash) == BaseRace.twist(clash), "the weekly format wins its game")
	_runs()

## The season twists reach the games' own Runs.
func _runs() -> void:
	var water := 0
	for st in BaseRace.stretches(GardenSeasons.twist("dash", _week_of("bramblebank"))):
		water += 1 if st["kind"] == "water" else 0
	ok(water == 2, "Bramblebank: the Dash has two water stretches")
	var a := _rec("A")
	var b := _rec("B")
	var rng := RandomNumberGenerator.new()
	var shove := BaseShove.Run.new([a, b], 0, rng, GardenSeasons.twist("shove", _week_of("cinderstep")))
	ok(is_equal_approx(shove.wobble, 0.95), "Cinderstep: Stump Shove rocks harder (wobble %.2f)" % shove.wobble)
	var volley := BaseVolley.Run.new([a, b], 0, rng, GardenSeasons.twist("volley", _week_of("glasswater")))
	ok(volley.to_win == 7, "Glasswater: Spark Volley is first to 7")
	ok(GardenSeasons.twist("seek", _week_of("hushwood")).get("night", false), "Hushwood: the Seek is at night")

func _rec(n: String) -> Dictionary:
	var k := Save.new_kin("zapple", n)
	Care.ensure(k)
	return k

func _snacks() -> void:
	var grow := float(SnackPatch.rules()["grow_secs"])
	for s in _seasons():
		var d := Save.fresh()
		var e := {"id": SnackPatch.ID, "x": 0, "z": 0, "t": 0.0}
		d["layout"] = HomeLayout.fresh()
		d["layout"]["deco"] = [e]
		var t := _week_of(s["zone"]) * WEEK + 3600.0
		e["t"] = t - grow
		var got := SnackPatch.harvest(d, t)
		var others := true
		for o in _seasons():
			if o["snack"] != s["snack"]:
				others = others and not got.slice(0, 5).has(o["snack"])      # the sixth is the rotating extra
		var four: Array = SnackPatch.rules()["snacks"]
		ok(got.size() == four.size() + 2 and got[four.size()] == s["snack"] and int(d["crops"][s["snack"]]) >= 1,
				"%s season: the patch grows %s" % [s["zone"], s["snack"]])
		ok(others, "%s season: no other season's snack" % s["zone"])

## Crowns three cup rounds in `game` at time t; returns the Crown's result.
func _crown(me: Dictionary, game: String, t: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var res := {}
	for foe_power in [19, 21, 23]:
		var foe := _rec("F")
		foe["stats"] = {"power": foe_power, "guard": foe_power, "speed": foe_power, "focus": foe_power}
		res = GardenPrizes.settle(game, me, foe, true, t, rng)
	return res

func _keepsake() -> void:
	Save.d = Save.fresh()
	var me := _rec("Crowned")
	me["stats"] = {"power": 20, "guard": 20, "speed": 20, "focus": 20}
	var hush: Dictionary = _seasons().filter(func(s): return s["zone"] == "hushwood")[0]
	var t := _week_of("hushwood") * WEEK + 60.0
	var res := _crown(me, "seek", t)
	var rows := GardenPrizes.rows(res)
	var shown: bool = rows.any(func(r): return String(r[0]).ends_with(hush["keepsake"]["name"]))
	ok(res["crown"] and res["keepsake"] == hush["keepsake"]["name"] and shown, "Hushwood season: the Seek Crown " +
			"gives the %s and the card shows it" % hush["keepsake"]["name"])
	ok(me["keepsakes"].has(hush["keepsake"]["id"]), "the Boki keeps it (rec.keepsakes)")
	var again := _crown(me, "seek", t + WEEK)
	ok(again["crown"] and again["keepsake"] == "", "a second Crown the same season: ribbon again, no keepsake")
	var other := _crown(me, "dash", t)
	ok(other["crown"] and other["keepsake"] == "", "a Crown in a game out of season: no keepsake")
	var v := VBoxContainer.new()
	PrizeBoard.add_ribbons(v, me)
	ok(v.get_child_count() == 3, "the Boki card lists two ribbons and the keepsake")
	v.free()
