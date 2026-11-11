class_name HomePrompt
extends RefCounted
## What the farm's interact prompt (InteractPrompt) shows for Home's target `it`: a short verb, what it
## works on, and a detail line. A line that only informs (you can't use it yet) has no verb.

const CARE_LINE_M := 2.4      # m above a Boki's feet where its care line sits (over its want bubble)

static func item(h: Node, it: Dictionary) -> Dictionary:
	if not h.visit.is_empty():
		return _visiting(h, it)
	match it["kind"]:
		"ferry": return {"verb": "Ride", "who": "Ferry"}
		"set_down": return {"verb": "Set down", "who": h.carry.kin["rec"]["name"]}
		"plot": return _plot(h, it)
		"pot": return {"verb": "Cook"}
		"rack": return {"verb": "Open", "who": "Glider skins"}
		"stall": return {"verb": "Shop"}
		"portal": return {"verb": "Embark", "who": "Expedition"}
		"house": return {"verb": "Enter", "who": "House"}
		"lot":
			var nm: String = Data.BUILDINGS[it["b"]]["name"]
			return _building(it["b"], nm) if h.lots[it["b"]]["built"] else {"verb": "Build", "who": nm}
		"bridge": return {"verb": "Build", "who": "Bridge", "note": "to %s" % Data.ISLES[it["isle"]]["name"]}
		"kin": return care(h, it["k"])
		"egg": return {"verb": "Hatch" if h._egg_ready() else "Warm", "who": h._egg_label()}
		"yard": return {"verb": "Train", "who": "Partner"}
		"race": return h.race.prompt()
		"nook": return {"verb": "Pair", "who": "Nook", "note": "two Boki for an egg"}
		"incubator": return h.hinc.prompt()
		"burrow": return {"verb": "Open", "who": "Boki Burrow", "note": "%d asleep inside" % KinBox.boxed().size()}
		"hob", "site": return h.hob.label(it)
		"feeder", "grave", "graveyard", "place": return h.hecon.label(it)
		"station":
			if it["id"] == "job_board":
				return {"verb": "Open", "who": "Job Board"}
			return {"verb": "Assign", "who": HomeLayout.CATALOG[it["id"]]["name"], "note": "a Boki works here"}
		"wild": return h.hg.label(it)
	return {}

## The care line over a Boki you stand next to: pet (or what it needs soothing with), feed, play and
## pick up, each with its key; what can't be done now is greyed. The interact key does the one lit.
static func care(h: Node, k: Dictionary) -> Dictionary:
	var rec: Dictionary = k["rec"]
	var pond: bool = h.POND_EDGE.x > -100.0
	var act := KinWants.action(rec, pond)
	var soothes := act not in ["feed", "lift"]
	var hungry_empty := Care.want(rec) == "food" and KinWants.best_food(rec) == ""
	return {"more": [
		["interact", KinWants.prompt(rec, pond)["verb"] if soothes else "Pet", soothes],
		["interact", "Feed (no food)" if hungry_empty else "Feed", act == "feed"],
		["play", "Play", not k.has("fetch")],
		["interact", "Pick up", act == "lift" and h.carry.can_lift(k)]]}

static func _visiting(h: Node, it: Dictionary) -> Dictionary:
	match it["kind"]:
		"kin":
			var rec: Dictionary = it["k"]["rec"]
			if h.petted.has(rec["uid"]):
				return {"note": "%s is happy you came" % rec["name"]}
			return {"verb": "Pet", "who": rec["name"]}
		"house": return {"verb": "Gift", "who": "House"}
		"portal", "ferry": return {"verb": "Go home"}
		"plot": return {"verb": "Look", "who": "%s's crops" % h.visit.get("name", "Their")}
	return {"verb": "Look"}

static func _plot(h: Node, it: Dictionary) -> Dictionary:
	var d: Dictionary = Save.d[it["arr"]][it["i"]]
	if d["crop"] == "":
		return {"verb": "Plant", "who": "Plot"}
	var nm: String = Data.CROPS[d["crop"]]["name"]
	if int(d["stage"]) >= int(Data.CROPS[d["crop"]]["grow"]):
		return {"verb": "Harvest", "who": nm}
	if it["arr"] == "plots" and FarmWater.plot_near(Save.d, it["i"]):
		return {"verb": "Check", "who": nm, "note": "the water nearby tends it (%s)" % h._grow_left(it["arr"], d)}
	if float(d.get("wt", 0.0)) <= 0.0:
		return {"verb": "Water", "who": nm}
	if int(d.get("wet", 2)) < 2:
		return {"verb": "Water", "who": nm, "note": "the rain only soaked it"}
	return {"verb": "Check", "who": nm, "note": "watered, growing (%s)" % h._grow_left(it["arr"], d)}

static func _building(b: String, nm: String) -> Dictionary:
	match b:
		"hall": return {"verb": "Open", "who": nm, "note": "your trophies"}
		"cottage", "cottage2": return {"verb": "Peek", "who": nm}
		"armory": return {"verb": "Open", "who": nm, "note": "%d stored" % Econ.armory().size()}
	return {"verb": "Visit", "who": nm}
