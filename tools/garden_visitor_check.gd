extends RefCounted
## --garden-visitor-check (GARDEN_MODERN.md 5 rank 6, scripts/home/garden_visitor.gd): wild visitors.
## The suit rule: a toy it likes in the zone, two residents of its type group, its theme in the zone's
## group, and a rigged model. On the real farm (base_mode, Bramblebank, three Boki and a dig patch): one
## visitor comes, only one at a time, it is in the zone's kins and the Dash lineup, it is saved and
## reloaded as it was, and it stays one garden day then goes home (one away card line, then a wait).
## Three favourite meals make it ask to stay as a new Boki when the zone has room, else leave an egg.
## Never touches the real save.

const DT := 0.25             # s of farm time per step
const LOOK_S := 5.0          # s of farm time between looks, so the check does not wait minutes
const COME_S := 40.0         # s of farm time a suiting zone has to bring a visitor (chance 1)
const OUT_S := 60.0          # s for the third meal's outcome to play out
const DAY_S := 300.0         # one garden day (care.json care_day_s)

var bad := 0
var main: Node
var home

func ok(cond: bool, what: String) -> void:
	print("VISITOR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _fresh(species: Array) -> void:
	var d := Save.fresh()
	for i in species.size():
		(d["roster"] as Array).append(Save.new_kin(species[i], "R%d" % i))
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	Save.d = d
	HomeLayout.ensure(d)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_suit_part()
	var rules: Dictionary = Content.rules("farm_build")
	rules["base_mode"] = true
	var vr: Dictionary = Content.rules("garden_visitor")
	var tuned := [vr["chance"], vr["check_s"]]
	vr["chance"] = 1.0
	vr["check_s"] = LOOK_S
	_fresh(["burrlet", "glomwort", "pebbit"])
	Save.d["layout"]["deco"].append({"id": "toy_dig", "u": 990001, "px": 30.0, "pz": 30.0})
	home = await main._hb_home()
	home.ppos = Vector3(-500, 0, -500)
	await _stay_part()
	await _join_part()
	await _egg_part()
	rules["base_mode"] = false
	vr["chance"] = tuned[0]
	vr["check_s"] = tuned[1]
	home.queue_free()
	await main.get_tree().process_frame
	print("VISITOR DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _suit_part() -> void:
	_fresh(["burrlet", "glomwort", "pebbit"])
	var zone := "bramblebank"
	ok(GardenVisitor.suits(zone, "mossgrade", ["toy_dig"]), "a toy it likes and two residents of its group suit it")
	ok(not GardenVisitor.suits(zone, "mossgrade", []), "no toy: it does not come")
	ok(not GardenVisitor.suits(zone, "mossgrade", ["toy_ball"]), "a toy it does not like: it does not come")
	ok(not GardenVisitor.suits(zone, "puddlet", ["toy_dig"]), "a species of another zone's group does not come")
	ok(not GardenVisitor.suits("glasswater", "mossgrade", ["toy_dig"]), "the zone's group must hold its theme")
	Save.d["roster"][1]["zone"] = "glasswater"
	ok(not GardenVisitor.suits(zone, "mossgrade", ["toy_dig"]),
		"one resident of the group is not enough (another zone's do not count)")
	Save.d["roster"][1].erase("zone")
	BokiRig.enabled = false
	ok(GardenVisitor.pick(zone, ["toy_dig"]) == "", "a species with no rigged model never visits")
	BokiRig.enabled = true
	var sp := GardenVisitor.pick(zone, ["toy_dig"])
	ok(sp != "" and BokiRig.has(sp) and GardenVisitor.suits(zone, sp, ["toy_dig"]),
		"the pick suits and has a model (%s)" % sp)
	var r := GardenVisitor.begin(zone, sp, 1000.0)
	ok(not GardenVisitor.expired(1000.0 + DAY_S - 1.0) and GardenVisitor.expired(1000.0 + DAY_S),
		"it stays one garden day")
	ok(GardenVisitor.in_zone(zone) == r and GardenVisitor.in_zone("glasswater").is_empty(),
		"it is in its own zone only")
	ok(GardenZones.out_here().has(r) and not KinBox.farm().has(r), "it walks the zone but is not one of your Boki")
	var back: Dictionary = JSON.parse_string(JSON.stringify(Save.d))
	Save.d = back
	var kept := GardenVisitor.in_zone(zone)
	ok(kept.get("uid") == r["uid"] and kept.has("visitor") and kept.has("species"), "it round-trips through the save")
	ok(Save.migrate(back) and GardenVisitor.rec().get("uid") == r["uid"],
		"a save with a visitor still upgrades and keeps it")

func _step(secs: float, until := Callable()) -> void:
	var t := 0.0
	while t < secs and not (until.is_valid() and until.call()):
		home._move_kin(DT)
		t += DT
		if int(t / DT) % 400 == 0:
			await main.get_tree().process_frame

func _wild() -> Array:
	return home.kins.filter(func(k): return k["rec"].has("visitor"))

func _stay_part() -> void:
	ok(GardenVisitor.rec().is_empty(), "no visitor to begin with")
	await _step(COME_S, func(): return not GardenVisitor.rec().is_empty())
	var r := GardenVisitor.rec()
	ok(not r.is_empty() and _wild().size() == 1, "a visitor wandered into Bramblebank")
	ok(GardenVisitor.suits("bramblebank", String(r.get("species", "")), ["toy_dig"]),
		"the one that came suits the zone")
	await _step(60.0)
	ok(_wild().size() == 1 and GardenVisitor.rec() == r, "only one visitor at a time")
	var k: Dictionary = _wild()[0]
	k["rec"]["needs"]["energy"] = 100.0
	ok(home.hrace.entrants().has(k), "it is in the Dash lineup as one more Boki")
	var lines := CareJournal.arrival()
	ok(lines.any(func(l): return "is visiting" in l), "the away card says who is here: %s" % [lines])
	ok(not CareJournal.arrival().any(func(l): return "is visiting" in l), "it says so once")
	Save.d["visitor"]["t"] = float(Save.d["visitor"]["t"]) - DAY_S
	await _step(10.0, func(): return GardenVisitor.rec().is_empty())
	ok(GardenVisitor.rec().is_empty() and _wild().is_empty(), "after one garden day it went home")
	ok(CareJournal.arrival().any(func(l): return "went home" in l), "the away card says it left")
	var next := float(Save.d["visitor"]["next"])
	await _step(60.0)
	ok(GardenVisitor.rec().is_empty(), "the next one waits")
	Save.d["visitor"]["next"] = 0.0
	await _step(COME_S, func(): return not GardenVisitor.rec().is_empty())
	ok(not GardenVisitor.rec().is_empty() and next > 0.0, "then another can come")
	Save.d["visitor"]["t"] = float(Save.d["visitor"]["t"]) - DAY_S
	var away := CareJournal.arrival()      # you were away over the day
	ok(GardenVisitor.rec().is_empty() and away.any(func(l): return "went home" in l),
		"a stay that ran out while you were away is told on arrival")
	Save.d["visitor"]["next"] = 0.0
	home._spawn_kin()      # the zone loads again: its visitor is not there

## Feeds the visitor its favourite three times, as the feed list does.
func _feed_three() -> void:
	var r := GardenVisitor.rec()
	var f := String(r["likes"]["food"])
	var bag := "crops" if Data.CROPS.has(f) else "items"
	Save.d[bag][f] = 3
	for i in 3:
		home._care_feed(r, f)
		await _step(5.0)
		if i == 1:
			ok(int(Save.d["visitor"]["fed"]) == 2, "two favourites counted")

func _come() -> void:
	await _step(COME_S, func(): return not GardenVisitor.rec().is_empty())

func _join_part() -> void:
	await _come()
	var r := GardenVisitor.rec()
	var uid := String(r["uid"])
	var roster: int = Save.d["roster"].size()
	var dup := KinBox.dup_on_farm(r)
	ok(not r.is_empty() and GardenZones.room("bramblebank") > 0, "a visitor with room in the zone")
	ok(String(r["likes"]["food"]) != "" and r["known"].has("food"), "its favourite is shown in the feed list")
	await _feed_three()
	await _step(OUT_S, func(): return GardenVisitor.rec().is_empty())
	var joined := Save.kin(uid)
	ok(not joined.is_empty() and Save.d["roster"].size() == roster + 1 and not joined.has("visitor"),
		"it asked to stay and is a new Boki")
	ok(joined["zone"] == "bramblebank" and joined["origin"]["how"] == "visitor", "it lives in the zone")
	ok(Save.d["dex"][joined["species"]]["caught"], "its kind is caught in the Field Book")
	var here: bool = not home.kins.filter(func(k): return k["rec"] == joined).is_empty()
	ok(_wild().is_empty() and here != dup, "it stays on the farm, or sleeps in the Burrow as a repeat (%s)" % dup)
	ok(CareJournal.arrival().any(func(l): return "asked to stay" in l), "the away card says it stayed")
	Save.d["visitor"]["next"] = 0.0

func _egg_part() -> void:
	for sp in ["burrlet", "glomwort", "burrlet"]:
		Save.d["roster"].append(Save.new_kin(sp, "Extra"))
	home._spawn_kin()
	ok(GardenZones.room("bramblebank") <= 0, "the zone is full (%d out)" % GardenZones.residents("bramblebank").size())
	await _come()
	var r := GardenVisitor.rec()
	var sp := String(r.get("species", ""))
	var roster: int = Save.d["roster"].size()
	var eggs: int = Incubator.count()
	await _feed_three()
	await _step(OUT_S, func(): return GardenVisitor.rec().is_empty())
	ok(GardenVisitor.rec().is_empty() and _wild().is_empty() and Save.d["roster"].size() == roster,
		"with no room it left and did not join")
	var egg: Dictionary = (Incubator.shelf() + Incubator.eggs()).back() if Incubator.count() > eggs else {}
	ok(Incubator.count() == eggs + 1 and egg.get("sp") == sp, "it left an egg of its kind (%s)" % sp)
	ok(CareJournal.arrival().any(func(l): return "left a" in l and "Egg" in l), "the away card says it left an egg")
