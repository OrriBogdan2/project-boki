extends RefCounted
## --zone-affinity-check: each zone loves two species types and one nature (garden_zones.json loves). A Boki
## living in a zone that suits it recovers joy faster and its toys give one more point now and then; one in
## a zone it does not suit loses nothing and gains nothing; its card says "loves <zone>". Simulates three days
## of a Water Boki in Glasswater and in Hushwood.

const DAYS := 3
const PLAYS_A_DAY := 100     # toy sessions in one simulated day
const TICK_S := 1200.0       # seconds of at-home time a day is ticked for the joy it keeps

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("AFFINITY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Content.rules("farm_build")["base_mode"] = true
	_data_part()
	_three_days_part()
	GardenZones.here = ""
	Content.rules("farm_build")["base_mode"] = false
	print("AFFINITY %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	m.get_tree().quit(0 if bad == 0 else 1)

## Every zone loves two different lean types and one nature that exists.
func _data_part() -> void:
	var types: Array = Content.rules("lean")["types"].keys()
	var natures: Array = Care.NATURES.values()
	var sound := true
	for id in GardenZones.ids():
		var loved: Dictionary = GardenZones.info(id).get("loves", {})
		var pair: Array = loved.get("types", [])
		sound = sound and pair.size() == 2 and pair[0] != pair[1] and pair.all(func(t): return types.has(t)) \
			and natures.has(loved.get("nature", ""))
	ok(sound, "all %d zones love two types and one nature" % GardenZones.ids().size())

## A Water Boki (a nature neither zone favours), lived through three days in each zone.
func _three_days_part() -> void:
	var gain := {}
	var joy := {}
	var plain_joy := 0.0
	for zone in ["glasswater", "hushwood"]:
		GardenZones.here = zone
		var rec := Save.new_kin("puddlet", "Pip")
		rec["traits"] = {"bravery": 0.9, "loyalty": 0.8, "temper": 0.1, "curiosity": 0.1}      # Valiant
		rec["zone"] = zone
		rec["lean"] = {"water": 12.0}      # a Water Boki
		seed(11)
		gain[zone] = 0
		joy[zone] = 0.0
		for day in DAYS:
			rec["needs"] = {"food": 90.0, "clean": 90.0, "energy": 90.0, "joy": 50.0}
			Care.tick(rec, TICK_S)
			joy[zone] += Care.need(rec, "joy")
			for i in PLAYS_A_DAY:
				gain[zone] += GardenZones.train_gain(rec, 1)
		if zone == "hushwood":
			var away := Save.new_kin("puddlet", "Fen")
			away["traits"] = rec["traits"]
			away["lean"] = rec["lean"]
			away["zone"] = "glasswater"      # lives elsewhere: gets nothing in the zone you are in
			away["needs"] = {"food": 90.0, "clean": 90.0, "energy": 90.0, "joy": 50.0}
			Care.tick(away, TICK_S)
			plain_joy = Care.need(away, "joy") * DAYS
	var wet: Array = GardenZones.info("glasswater")["loves"]["types"]
	var dark: Array = GardenZones.info("hushwood")["loves"]["types"]
	ok(wet.has("water") and not dark.has("water"), "Glasswater loves Water, Hushwood does not")
	var g: int = gain["glasswater"]
	var h: int = gain["hushwood"]
	ok(g > h, "3 days of toys: %d points in Glasswater vs %d in Hushwood" % [g, h])
	ok(h >= DAYS * PLAYS_A_DAY, "a Boki in a zone it dislikes never loses stats (%d of %d)" % [h, DAYS * PLAYS_A_DAY])
	var jg: float = joy["glasswater"]
	var jh: float = joy["hushwood"]
	ok(jg > jh, "joy recovers faster in Glasswater (%.0f vs %.0f)" % [jg, jh])
	ok(is_equal_approx(jh, plain_joy), "a Boki in a zone it dislikes keeps the usual joy")
	var rec := Save.new_kin("puddlet", "Pip")
	rec["zone"] = "glasswater"
	rec["lean"] = {"water": 12.0}
	GardenZones.here = "glasswater"
	var bonus: float = float(GardenZones.rules()["affinity"]["stat_bonus"])
	ok(is_equal_approx(ZoneAffinity.stat_bonus(rec), bonus), "the data knob is the bonus (%.0f%%)" % (bonus * 100.0))
	ok(ZoneAffinity.joy_per_min(rec) > 0.0, "it gains joy of its own there")
	ok(ZoneAffinity.line(rec) == "loves Glasswater Shallows", "the card says '%s'" % ZoneAffinity.line(rec))
	rec["zone"] = "hushwood"
	rec["traits"] = {"bravery": 0.9, "loyalty": 0.8, "temper": 0.1, "curiosity": 0.1}      # Valiant
	GardenZones.here = "hushwood"
	var extra := ZoneAffinity.joy_per_min(rec) + ZoneAffinity.stat_bonus(rec)
	ok(extra == 0.0, "nothing extra in a zone it does not suit")
	ok(ZoneAffinity.line(rec) == "", "no card line in a zone that does not suit it")
	rec["traits"] = {"bravery": 0.1, "loyalty": 0.1, "temper": 0.8, "curiosity": 0.9}      # Mischievous
	ok(ZoneAffinity.suits(rec), "its nature (%s) suits Hushwood though it leans Water" % Care.nature(rec))
