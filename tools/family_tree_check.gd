extends RefCounted
## --family-tree-check (GARDEN_MODERN.md section 5 rank 8): the Family tab reads the saved lineage. A bred
## grandchild shows both generations (parents, grandparents, with name and type), wild-caught Boki show "wild",
## a parent you no longer have shows by name, the mentor's gift and the nest items used at the egg are listed,
## clicking an ancestor you own opens its card, a wild visitor's egg shows the visitor as a
## parent, and all of it survives a save round trip.
## Never touches the real save.

var bad := 0
var opened: Array = []

func ok(cond: bool, what: String) -> void:
	print("FAMILYTREE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _wild(sp: String, nick: String) -> Dictionary:
	var k := Save.new_kin(sp, nick)
	Save.d["roster"].append(k)
	return k

func _bred(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var k := Care.breed(a, b, rng)
	Save.d["roster"].append(k)
	return k

func _names(slots: Array) -> Array:
	return slots.map(func(s): return String(s["name"]))

func _buttons(n: Node, out: Array = []) -> Array:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_buttons(c, out)
	return out

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var a := _wild("cindle", "Ash")
	var b := _wild("puddlet", "Bri")
	var c := _wild("burrlet", "Cob")
	var d := _wild("cindle", "Dew")
	# ---- wild-caught: no parents recorded
	var wp: Array = FamilyView.parents(a)
	ok(wp.size() == 2 and wp.all(func(s): return s["state"] == FamilyView.WILD), "a wild-caught Boki: two wild parents")
	ok(FamilyView.grandparents(a).all(func(g): return g.is_empty()), "and nothing further back")
	# ---- a bred child of wild parents, a grandchild with one wild parent, and one with four known grandparents
	var kid := _bred(a, b, rng)
	var grand := _bred(kid, c, rng)
	var kid2 := _bred(c, d, rng)
	var great := _bred(kid, kid2, rng)
	var kp: Array = FamilyView.parents(kid)
	var type: String = String(Data.KIN["cindle"]["type"]).capitalize()
	ok(_names(kp) == ["Ash", "Bri"] and kp[0]["type"] == type, "a child shows both parents with name and type")
	var gp: Array = FamilyView.grandparents(grand)
	ok(_names(FamilyView.parents(grand)) == [kid["name"], "Cob"], "the grandchild: the child and a wild Boki")
	ok(_names(gp[0]) == ["Ash", "Bri"], "grandparents through the child: Ash and Bri")
	var all_wild: bool = gp[1].size() == 2 and gp[1].all(func(s): return s["state"] == FamilyView.WILD)
	ok(all_wild, "grandparents through the wild-caught parent show wild")
	var gg: Array = FamilyView.grandparents(great)
	var four: bool = _names(gg[0]) == ["Ash", "Bri"] and _names(gg[1]) == ["Cob", "Dew"]
	ok(four, "four known grandparents: Ash, Bri, Cob, Dew")
	ok(gg[0][0]["rec"]["uid"] == a["uid"], "an ancestor is the saved Boki itself (read by uid)")
	# ---- a parent you no longer have shows by name; its parents are unknown
	Save.d["roster"].erase(kid2)
	var lost: Dictionary = FamilyView.parents(great)[1]
	var lost_grand: Array = FamilyView.grandparents(great)[1]
	ok(lost["state"] == FamilyView.GONE and lost["name"] == kid2["name"], "a parent no longer owned: by name")
	ok(_names(lost_grand) == ["unknown", "unknown"], "and its parents show unknown")
	# ---- an older save: parent names only, no uids
	var old := Save.new_kin("cindle", "Oldie")
	old["lineage"] = {"parents": [], "names": ["Ash", "Bri"], "gen": 1}
	var by_name: Array = FamilyView.parents(old)
	var found: bool = _names(by_name) == ["Ash", "Bri"] and by_name[0]["state"] == FamilyView.OWNED
	ok(found, "names without uids find the one Boki")
	# ---- the mentor's gift and the nest items used
	Save.d["items"]["heirloom_thread"] = 2
	Save.d["items"]["likeness_locket"] = 1
	Save.d["items"]["lullaby_shell"] = 1
	NestItems.add_threads(2)
	NestItems.wear("species", String(a["uid"]))
	NestItems.wear("habit", String(b["uid"]))
	var egg := {}
	NestItems.lay(egg, a, b)
	var gift := {"from": "Moss", "kind": "habit", "quirk": String(Unique.QUIRK_NAMES.keys()[0])}
	var baby := Care.breed(a, b, rng, String(egg.get("sp", "")), NestItems.inherit_n(egg))
	Mentor.apply(baby, gift)
	NestItems.hatched(baby, egg, a, b)
	Save.d["roster"].append(baby)
	var said: Array = FamilyView.passed(baby)
	var listed: bool = said.size() == 4 and said[0].contains("Moss") and said[1] == "Heirloom Thread ×2"
	ok(listed, "the mentor's gift and the Threads are listed")
	ok(said.has("Likeness Locket") and said.has("Lullaby Shell"), "the Locket and the Shell are listed")
	ok(FamilyView.passed(kid).is_empty(), "a baby hatched with nothing placed lists nothing")
	# ---- the tab opens the card of an ancestor you own
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	FamilyView.fill(great, left, right, m.get_tree(), func(k): opened.append(k["uid"]))
	var live := _buttons(left) + _buttons(right)
	var enabled := live.filter(func(bt): return not bt.disabled)
	ok(live.size() == 6 and enabled.size() == 3, "6 ancestor cells, the 3 you still own are clickable")
	enabled[0].pressed.emit()
	ok(opened == [kid["uid"]], "clicking an owned ancestor opens its card")
	left.free()
	right.free()
	# ---- a wild visitor's egg: the wild parent shows with its species, zone and day; an old egg shows wild only
	var from := {"sp": "cindle", "zone": "hushwood", "day": 12}
	var vegg := Incubator.add("cindle", "", from)
	ok(Incubator.find(String(vegg["id"])).get("visitor") == from, "a cradled egg keeps who left it")
	Incubator.find(String(vegg["id"]))["heat"] = Incubator.HEAT_NEED
	var vbaby := Incubator.hatch(rng)
	var vp: Array = FamilyView.parents(vbaby)
	var states: Array = vp.map(func(s): return s["state"])
	ok(states == [FamilyView.VISITOR, FamilyView.WILD], "the visitor's baby: the visitor and a wild parent")
	var shown: bool = vp[0]["note"] == "wild visitor, Hushwood, day 12" and vp[0]["rec"]["species"] == "cindle"
	ok(shown, "its species, zone and day")
	var line := "hatched from the egg a wild Vespyx left in Hushwood on day 12"
	ok(Incubator.born_line(vbaby, "") == line, "one memory line tells the day")
	var oegg := Incubator.add("cindle", "")
	Incubator.find(String(oegg["id"]))["heat"] = Incubator.HEAT_NEED
	var obaby := Incubator.hatch(rng)
	var old_wild: bool = FamilyView.parents(obaby).all(func(s): return s["state"] == FamilyView.WILD)
	ok(old_wild, "an egg without the data shows wild only")
	ok(Incubator.born_line(obaby, "").begins_with("hatched from a Rare Egg"), "and keeps the boss-egg line")
	Save.d["roster"].append(vbaby)
	# ---- save round trip
	var back: Dictionary = JSON.parse_string(JSON.stringify(Save.d))
	Save.migrate(back)
	var keep := Save.d
	Save.d = back
	var b2: Dictionary = Save.kin(String(baby["uid"]))
	var g2: Dictionary = Save.kin(String(grand["uid"]))
	ok(FamilyView.passed(b2) == said, "round trip: gift and nest items read back the same")
	var g2s: Array = FamilyView.grandparents(g2)
	var same: bool = _names(g2s[0]) == ["Ash", "Bri"] and g2s[1][0]["state"] == FamilyView.WILD
	ok(same, "round trip: both generations, wild parents")
	var vback: Dictionary = FamilyView.parents(Save.kin(String(vbaby["uid"])))[0]
	ok(vback["note"] == "wild visitor, Hushwood, day 12", "round trip: the visitor parent")
	Save.d = keep
	print("FAMILYTREE done, %d failed" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
