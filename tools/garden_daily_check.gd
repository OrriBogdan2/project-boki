extends RefCounted
## --garden-daily-check: today's wishes and the away gifts (content/rules/garden_daily.json).
##   away 1 h, 8 h and 72 h give 0, 3 and 3 gifts and never lower any need or stat; toys train a quarter as fast,
##   at most 3 points a Boki and never past the level cap; patch overflow fills the feeder bowl.
##   wishes: three a day from the Boki's low needs, granted by the need coming back up (trust, a snack),
##   all three give gems once, and a new day starts fresh without taking anything.
## Never touches the real save.

const HOUR := 3600.0

var bad := 0


## The home screen as ZoneAway.card sees it: it records which panels the arrival asked for.
class HomeStub:
	extends RefCounted
	var visit := {}
	var shown: Array = []

	func _show_when_free(_lines: Array, title := "While you were away") -> void:
		shown.append(title)


func ok(cond: bool, what: String) -> void:
	print("DAILY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _save(boki: int) -> Dictionary:
	var d := Save.fresh()
	for i in boki:
		var k := Save.new_kin("zapple", "Pip%d" % i)
		Care.ensure(k)
		d["roster"].append(k)
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(d)
	return d


func _snap() -> Dictionary:
	var out := {}
	for rec in Save.d["roster"]:
		out[rec["uid"]] = [(rec["needs"] as Dictionary).duplicate(), (rec["stats"] as Dictionary).duplicate()]
	return out


func _never_lower(before: Dictionary) -> bool:
	for rec in Save.d["roster"]:
		for part in 2:
			var was: Dictionary = before[rec["uid"]][part]
			var now: Dictionary = rec["needs"] if part == 0 else rec["stats"]
			for key in was:
				if float(now[key]) < float(was[key]):
					return false
	return true


func _gifts() -> void:
	var now := 1.0e9
	for case in [[1.0, 0], [8.0, 3], [72.0, 3]]:
		_save(3)
		var before := _snap()
		var lines := GardenAway.arrive(now - float(case[0]) * HOUR, now)
		var n := lines.filter(func(l): return "saved you a snack" in String(l)).size()
		ok(n == int(case[1]), "%d h away gives %d gifts (got %d)" % [int(case[0]), int(case[1]), n])
		ok(_never_lower(before), "%d h away never lowers a need or a stat" % int(case[0]))
	ok(GardenAway.arrive(0.0, now).is_empty(), "the first arrival has nothing to give")


func _toy_stat(rec: Dictionary) -> int:
	var total := 0
	for key in rec["stats"]:
		total += int(rec["stats"][key])
	return total


func _toys() -> void:
	var now := 1.0e9
	var d := _save(2)
	(d["roster"][1] as Dictionary)["stats"] = {"power": 0, "guard": 0, "speed": 0, "focus": 0}
	HomeLayout.of(d)["deco"].append({"id": "toy_ball", "u": 1, "x": 0, "y": 0, "r": 0})
	var a: Dictionary = d["roster"][0]
	var b: Dictionary = d["roster"][1]
	var a0 := _toy_stat(a)
	GardenAway.arrive(now - 270.0, now)
	ok(_toy_stat(a) == a0, "4.5 min away trains nothing: a quarter rate of 90 s a point is under one point")
	GardenAway.arrive(now - 720.0, now)
	ok(_toy_stat(a) == a0 + 2, "12 min away trains 2 points at a quarter rate (got %d)" % (_toy_stat(a) - a0))
	var b0 := _toy_stat(b)
	GardenAway.arrive(now - 72.0 * HOUR, now)
	var got := _toy_stat(b) - b0
	ok(got == 1, "same day: the toys' day cap (3) leaves 1 of the 3 points (got %d)" % got)
	var next_day := now + 2.0 * 86400.0  # a new farm day: the toys' day cap starts over
	b0 = _toy_stat(b)
	GardenAway.arrive(next_day - 72.0 * HOUR, next_day)
	var toy_cap := int(GardenAway.rules()["toy_cap"])
	ok(_toy_stat(b) - b0 == toy_cap, "72 h trains the %d points a Boki can get, no more" % toy_cap)
	var cap := Care.stat_cap(b)
	b["stats"]["speed"] = cap + 4
	GardenAway.arrive(now - 72.0 * HOUR, now)
	ok(int(b["stats"]["speed"]) == cap + 4, "a stat already past the cap is left alone, never lowered")


func _patch() -> void:
	var now := 1.0e9
	var d := _save(1)
	var bowl := {"id": "f1", "kind": "trough", "food": [], "auto": false}
	d["feeders"] = [bowl]
	var grow := float(SnackPatch.rules()["grow_secs"])
	var patch := {"id": SnackPatch.ID, "u": 2, "x": 0, "y": 0, "r": 0, "t": now - 6.0 * grow}
	HomeLayout.of(d)["deco"].append(patch)
	var snacks: Array = SnackPatch.rules()["snacks"]
	var made := int(GardenAway.rules()["patch_overflow_max"]) * snacks.size()
	var crops := 0
	for s in snacks:
		crops += int(d["crops"].get(s, 0))
	GardenAway.arrive(now - 72.0 * HOUR, now)
	var held := 0
	for s in snacks:
		held += int(d["crops"].get(s, 0))
	var in_bowl := Econ.fill(bowl)
	ok(in_bowl > 0, "patch overflow went to the feeder bowl (%d in it)" % in_bowl)
	var said := "nothing is lost: %d snacks made, %d in the bowl, %d in the pantry"
	ok(held - crops + in_bowl == made, said % [made, in_bowl, held - crops])
	ok(SnackPatch.ripe(patch, now), "one batch still waits ripe on the patch")


func _wishes() -> void:
	var now := 1.0e9
	var d := _save(4)
	for rec in d["roster"]:
		rec["needs"]["food"] = 20.0
		rec["needs"]["joy"] = 30.0
	var w := GardenWishes.today(now)
	var list: Array = w["list"]
	ok(list.size() == 3, "three wishes a day (got %d)" % list.size())
	ok(GardenWishes.today(now)["list"] == list, "the same three all day")
	var low := func(x): return Care.need(GardenWishes._rec(String(x["uid"])), String(x["need"])) < 60.0
	ok(list.all(low), "each wish is for a low need")
	ok(GardenWishes.check(now).is_empty(), "nothing is granted while the needs stay low")
	var gems := int(d["gems"])
	var kibble := int(d["items"].get("kibble", 0))
	var rec := GardenWishes._rec(String(list[0]["uid"]))
	var trust := float(rec.get("trust", 0.0))
	rec["needs"][list[0]["need"]] = 90.0
	var lines := GardenWishes.check(now)
	ok(lines.size() == 1 and list[0]["done"], "raising one need grants that one wish")
	var gift_trust := trust + float(GardenWishes.rules()["trust"])
	ok(float(rec["trust"]) == gift_trust and int(d["items"]["kibble"]) == kibble + 1, "it gave trust and a small item")
	ok(int(d["gems"]) == gems, "one wish gives no gems")
	for i in [1, 2]:
		GardenWishes._rec(String(list[i]["uid"]))["needs"][list[i]["need"]] = 90.0
	lines = GardenWishes.check(now)
	var bonus := int(GardenWishes.rules()["bonus_gems"])
	ok(int(d["gems"]) == gems + bonus, "all three give %d gems" % bonus)
	GardenWishes.check(now)
	ok(int(d["gems"]) == gems + bonus and int(d["items"]["kibble"]) == kibble + 3, "granted wishes pay once")
	var tomorrow := GardenWishes.today(now + 86400.0)
	ok(int(tomorrow["day"]) == int(w["day"]) + 1 and not tomorrow["bonus"], "a new day picks fresh wishes")
	var skipped := _save(2)
	skipped["roster"][0]["needs"]["food"] = 10.0
	var before := _snap()
	var start_gems := int(skipped["gems"])
	GardenWishes.today(now)
	GardenWishes.today(now + 86400.0 * 5)
	ok(_never_lower(before) and int(skipped["gems"]) == start_gems, "missing days costs nothing")
	var lone := _save(1)
	start_gems = int(lone["gems"])
	lone["roster"][0]["needs"]["food"] = 10.0
	var one := GardenWishes.today(now + 86400.0 * 9)
	ok((one["list"] as Array).size() == 1, "one low need, one wish (a short list is fine)")
	GardenWishes._rec(String(one["list"][0]["uid"]))["needs"]["food"] = 95.0
	GardenWishes.check(now + 86400.0 * 9)
	ok(int(lone["gems"]) == start_gems, "a short list gives no all-three gems")


## One return through the real arrival path (the same calls home.gd makes), with every clock `back` seconds
## earlier (negative: later, as if the device clock had moved back). Returns the card lines.
func _return(back: float) -> Array:
	var now := Time.get_unix_time_from_system()
	Work.ensure()["seen"] = now - back
	Save.d["away_seen"] = now - back
	var marks := {}
	for id in GardenZones.ids():
		marks[id] = now - back
	Save.d["away_zone"] = marks
	for rec in Save.d["roster"]:
		rec["needs_t"] = now - back
	var lines := CareJournal.arrival(Work.catch_up())
	Econ.catch_up_all()
	return lines


func _load_save() -> Dictionary:
	var d := _save(2)
	var rocky := Save.new_kin("pebbit", "Rocky")
	Care.ensure(rocky)
	d["roster"].append(rocky)
	Work.assign(rocky, 1)
	HomeLayout.of(d)["deco"].append({"id": "lumber_camp", "u": 1, "x": 0, "y": 0, "r": 0})
	d["mats"] = {"wood": 0, "stone": 0}
	return d


## The farm runs itself while away, capped: 2 h, 24 h and 7 days back credit the same capped wood and the gifts,
## once; a return is one plain line and never lowers a need; a clock moved backwards credits nothing.
func _load() -> void:
	var cap := int(Work.ASSIGN["lumber_camp"]["cap"])
	for case in [["2 h", 2.0 * HOUR, 1], ["24 h", 24.0 * HOUR, 3], ["7 days", 168.0 * HOUR, 3]]:
		var d := _load_save()
		var lines := _return(float(case[1]))
		var gifts := lines.filter(func(l): return "saved you a snack" in String(l)).size()
		var made := Work.mat("wood")
		ok(made == cap, "%s back: the camp made %d wood, its cap (got %d)" % [case[0], cap, made])
		ok(gifts == int(case[2]), "%s back: %d gifts (got %d)" % [case[0], int(case[2]), gifts])
		ok((d["roster"] as Array).size() == 3, "%s back: nobody left the roster" % case[0])
		var line := BaseCard.away_line(lines)
		print("DAILY %s line: %s" % [case[0], line])
		ok(line != "" and line.length() <= 120, "%s back: one plain line (%d chars)" % [case[0], line.length()])
		var low := line.to_lower()
		ok("starv" not in low and "lost" not in low, "%s back: the line never says lost or starved" % case[0])
		var wood := Work.mat("wood")
		var again := _return(0.0)
		ok(Work.mat("wood") == wood and again.is_empty(), "%s back: credited once (then %s)" % [case[0], again])
	var d := _load_save()
	_return(HOUR)
	var wood := Work.mat("wood")
	var snacks := int(d["crops"].get("kibble", 0))
	for gap in [-3.0 * HOUR, -400.0 * 86400.0]:
		var lines := _return(gap)
		var said := "a clock %d h back credits nothing (%s)" % [int(gap / HOUR), lines]
		ok(lines.is_empty() and Work.mat("wood") == wood, said)
		ok(int(d["crops"].get("kibble", 0)) == snacks, "a clock moved back gives no gifts")
	_return(HOUR)
	ok(Work.mat("wood") > wood, "and the next real hour away still counts (%d wood)" % Work.mat("wood"))
	_load_return_card()


## The garden's return is the HUD line: no panel over the Boki, and no zone name as the line.
func _load_return_card() -> void:
	var d := _load_save()
	d["zones"]["cinderstep"] = {"open": true}
	var back := 7.0 * 24.0 * HOUR
	var now := Time.get_unix_time_from_system()
	Work.ensure()["seen"] = now - back
	var stub := HomeStub.new()
	ZoneAway.card(stub)
	var line := BaseCard.away_line(BaseCard.away)
	print("DAILY two zones line: ", line)
	ok(stub.shown.is_empty(), "7 days back in the garden opens no panel over the Boki (%s)" % [stub.shown])
	ok(line.begins_with("While you were away: +24 wood"), "with two zones open the line is a fact, not a zone name")
	FarmUnlocks.rules()["base_mode"] = false
	Work.ensure()["seen"] = now - back
	ZoneAway.card(stub)
	ok(stub.shown == ["While you were away"], "a classic home keeps its one return card (%s)" % [stub.shown])
	FarmUnlocks.rules()["base_mode"] = true


func run(m: Node) -> void:
	Save.no_write = true
	var rules: Dictionary = FarmUnlocks.rules()
	rules["base_mode"] = true
	_gifts()
	_toys()
	_patch()
	_wishes()
	_load()
	rules["base_mode"] = false
	print("DAILY DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
