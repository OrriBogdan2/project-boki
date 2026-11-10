class_name FarmTutorial
extends RefCounted
## The guided farm tutorial (content/rules/farm_tutorial.json; the screen side is FarmGuide). Short steps
## on a new farm: axe, chop trees, mine rocks, house, hammer, a job for your Boki, feed, crop (by the water),
## buy a seed, sell a crop, meet Hob, head out.
## State is Save.d.tutorial.ft:
##   did      step id -> true for the steps done
##   done / skipped   finished, or skipped (nothing is granted or taken away)
##   gift     the starter food was handed out
## Old saves never see it: the v8 migration marks them done, and so does tutorial.day1_done (the flag
## every test save and the new-game shortcuts already set).

static func rules() -> Dictionary:
	return Content.rules("farm_tutorial")

static func option(key: String):
	return rules()["options"][key]

static func state() -> Dictionary:
	var tut: Dictionary = Save.d["tutorial"]
	if typeof(tut.get("ft")) != TYPE_DICTIONARY:
		tut["ft"] = {"did": {}, "done": false, "skipped": false, "gift": false}
	return tut["ft"]

## Is the tutorial running on this save right now?
static func active() -> bool:
	if "--skip-tutorial" in OS.get_cmdline_user_args() or Save.d["roster"].is_empty():
		return false
	if bool(Save.d["tutorial"].get("day1_done", false)):
		return false
	if typeof(Save.d.get("layout")) != TYPE_DICTIONARY or not HomeLayout.fs(Save.d) or not FarmUnlocks.gated():
		return false
	return not bool(state()["done"])

static func steps() -> Array:
	return rules()["steps"]

static func step_def(id: String) -> Dictionary:
	for s in steps():
		if String(s["id"]) == id:
			return s
	return {}

static func did(id: String) -> bool:
	return bool((state()["did"] as Dictionary).get(id, false))

static func done_count() -> int:
	return (state()["did"] as Dictionary).size()

## Can this step be the active one yet? Its "needs" are done; the last step waits for everything;
## "after_built" waits for the house to stand (a pinned Boki would stop building); without the
## free_order option each step also waits for the one before it.
static func available(id: String) -> bool:
	var list := steps()
	for i in list.size():
		var def: Dictionary = list[i]
		if String(def["id"]) != id:
			continue
		var before := list.slice(0, i)
		if bool(def.get("needs_all", false)) or not bool(option("free_order")):
			return before.all(func(s): return did(String(s["id"])))
		if bool(def.get("after_built", false)) and not house_built():
			return false
		return (def.get("needs", []) as Array).all(func(n): return did(String(n)))
	return false

static func house_built() -> bool:
	var e := FarmHob.house_entry()
	return not e.is_empty() and not FarmSites.has_site(e)

## The step to show: the first one not done that can be done now ("" when none is left).
static func current() -> String:
	if not active():
		return ""
	var waiting := ""
	for s in steps():
		var id := String(s["id"])
		if did(id) or not available(id):
			continue
		if (s.get("waits", []) as Array).has(stage(id)):
			if waiting == "": waiting = id      # only waiting (a crop growing): show the next open step instead
			continue
		return id
	return waiting

## Which hint of the current step applies (the keys of a step's "hints").
static func stage(id: String) -> String:
	match id:
		"house":
			return "wait" if not FarmHob.house_entry().is_empty() else "place"
		"feed":
			return "fill" if not Econ.feeders().is_empty() else "place"
		"crop":
			return _crop_stage()
		"buy", "sell":
			return "stall" if not HomeLayout.fixtures(Save.d, "stall").is_empty() else "bar"
		"task":
			return "page" if FarmTaskGuide.page_up() else "go"
	return "go"

static func _crop_stage() -> String:
	if HomeLayout.fixtures(Save.d, "farm").is_empty():
		return "patch" if not FarmWater.tiles(Save.d).is_empty() else "patch_dry"
	var best := "plant"
	var i := -1
	for p in Save.d["plots"]:
		i += 1
		if String(p["crop"]) == "":
			continue
		if int(p["stage"]) >= int(Data.CROPS[String(p["crop"])]["grow"]):
			return "pick"
		best = "water" if float(p.get("wt", 0.0)) <= 0.0 and not FarmWater.plot_near(Save.d, i) else "grow"
	return best

static func hint_text(id: String) -> String:
	var s := step_def(id)
	if s.is_empty():
		return ""
	var raw := String((s["hints"] as Dictionary).get(stage(id), ""))
	var txt := FarmTaskGuide.fill(raw).replace("{build}", Settings.key_cap("build"))
	txt = txt.replace("{house_cost}", FarmSites.cost_text(FarmSites.build_cost("house")))
	return txt.replace("{interact}", Settings.key_cap("interact")).replace("{details}", Settings.key_cap("details"))

## What the spotlight lights for this step's current stage: {"hub": bar button id, "world": true}, or {}.
static func spot(id: String) -> Dictionary:
	return (step_def(id).get("spot", {}) as Dictionary).get(stage(id), {})

static func world_text(id: String) -> String:
	var s := step_def(id)
	return "" if s.is_empty() else String((s["world"] as Dictionary).get(stage(id), ""))

# ------------------------------------------------------------------ progress
## A thing happened on the farm: swing (a hammer), task (a Boki pinned to a job), hob (talked), portal.
static func event(what: String) -> void:
	if not active():
		return
	var ids := {"swing": "hammer", "task": "task", "hob": "hob", "portal": "expedition", "buy": "buy", "sell": "sell"}
	var id := ids.get(what, "") as String
	detect()
	if id != "" and available(id):
		mark(id)

## Looks at the farm for steps that need no hook. A later step done means the earlier ones are too.
static func detect() -> void:
	if not active():
		return
	var cost := FarmSites.build_cost("house")
	var wood := int(cost.get("wood", 0))
	var stone := int(cost.get("stone", 0))
	if HomeGather.has_tool("axe"):
		mark("axe")
	if FarmSites.have("wood") >= wood and wood > 0:
		mark("axe")
		mark("chop")
	if HomeGather.has_tool("pickaxe") and FarmSites.have("stone") >= stone and stone > 0:
		mark("stone")
	if not FarmHob.house_entry().is_empty():
		mark("axe")
		mark("chop")
		mark("stone")
		mark("house")
	if house_built():
		mark("hammer")
	if Econ.feeders().any(func(f): return Econ.fill(f) > 0):
		mark("feed")
	if Progress.stat("harvested") > 0 and not HomeLayout.fixtures(Save.d, "farm").is_empty():
		mark("crop")

static func mark(id: String) -> void:
	var st := state()
	if bool((st["did"] as Dictionary).get(id, false)) or step_def(id).is_empty():
		return
	st["did"][id] = true
	if (st["did"] as Dictionary).size() >= steps().size():
		finish()
	Save.save_game()

## The last step: one reward, then the tutorial is gone. Returns the gems granted.
static func finish() -> int:
	var st := state()
	if bool(st["done"]):
		return 0
	st["done"] = true
	var gems := int(option("end_gems"))
	Save.d["gems"] = int(Save.d["gems"]) + gems
	return gems

## Skipping: nothing granted or taken. (FarmGuide puts the house down as a site when none is.)
static func skip() -> void:
	var st := state()
	st["done"] = true
	st["skipped"] = true
	Save.save_game()

## The tool a step hands over when it comes up (its "gives_tool"; the Market still sells it later).
## Returns the tool's id if it was handed over just now, else "".
static func give_step_tool(id: String) -> String:
	var tool := String(step_def(id).get("gives_tool", ""))
	if tool == "" or not bool(option("free_tools")) or HomeGather.has_tool(tool):
		return ""
	HomeGather.give_tool(tool)
	return tool

## The buy step: enough gems for one seed, so nobody is stuck at the stall. Returns the gems added.
static func give_seed_gems() -> int:
	if not bool(option("market_gems")):
		return 0
	var cheapest := 1000000
	for c in Data.CROPS:
		cheapest = mini(cheapest, int(Data.CROPS[c]["price"]))
	var add := maxi(0, cheapest - int(Save.d["gems"]))
	Save.d["gems"] = int(Save.d["gems"]) + add
	return add

## Starter food for the trough, once, when the tutorial's feeding step is reached.
static func give_food() -> void:
	var st := state()
	if bool(st["gift"]):
		return
	st["gift"] = true
	var food: Dictionary = rules()["start_food"]
	for k in food:
		Save.d["items"][k] = int(Save.d["items"].get(k, 0)) + int(food[k])
