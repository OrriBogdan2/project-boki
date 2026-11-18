extends RefCounted
## --garden-daily-check: today's wishes and the away gifts (content/rules/garden_daily.json).
##   away 1 h, 8 h and 72 h give 0, 3 and 3 gifts and never lower any need or stat; toys train a quarter as fast,
##   at most 3 points a Boki and never past the level cap; patch overflow fills the feeder bowl.
##   wishes: three a day from the Boki's low needs, granted by the need coming back up (trust, a snack),
##   all three give gems once, and a new day starts fresh without taking anything.
## Never touches the real save.

const HOUR := 3600.0

var bad := 0

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
	var patch := {"id": SnackPatch.ID, "u": 2, "x": 0, "y": 0, "r": 0, SnackPatch.RIPE_KEY: now - 6.0 * grow}
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

func run(m: Node) -> void:
	Save.no_write = true
	var rules: Dictionary = FarmUnlocks.rules()
	rules["base_mode"] = true
	_gifts()
	_toys()
	_patch()
	_wishes()
	rules["base_mode"] = false
	print("DAILY DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
