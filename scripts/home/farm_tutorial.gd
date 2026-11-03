class_name FarmTutorial
extends RefCounted
## The guided farm tutorial (content/rules/farm_tutorial.json; the screen side is FarmGuide). Short steps
## on a new farm: axe, chop a tree, house, hammer, a job for your Boki, feed, crop, meet Hob, head out.
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
	for s in steps():
		var id := String(s["id"])
		if not did(id) and available(id):
			return id
	return ""

## Which hint of the current step applies (the keys of a step's "hints").
static func stage(id: String) -> String:
	match id:
		"house":
			return "wait" if not FarmHob.house_entry().is_empty() else "place"
		"feed":
			return "fill" if not Econ.feeders().is_empty() else "place"
		"crop":
			return _crop_stage()
	return "go"

static func _crop_stage() -> String:
	if HomeLayout.fixtures(Save.d, "farm").is_empty():
		return "patch"
	var best := "plant"
	for p in Save.d["plots"]:
		if String(p["crop"]) == "":
			continue
		if int(p["stage"]) >= int(Data.CROPS[String(p["crop"])]["grow"]):
			return "pick"
		best = "water" if float(p.get("wt", 0.0)) <= 0.0 else "grow"
	return best

static func hint_text(id: String) -> String:
	var s := step_def(id)
	if s.is_empty():
		return ""
	var raw := String((s["hints"] as Dictionary).get(stage(id), ""))
	return raw.replace("{build}", Settings.key_cap("build")).replace("{interact}", Settings.key_cap("interact"))

static func world_text(id: String) -> String:
	var s := step_def(id)
	return "" if s.is_empty() else String((s["world"] as Dictionary).get(stage(id), ""))

# ------------------------------------------------------------------ progress
## A thing happened on the farm: swing (a hammer), task (a Boki pinned to a job), hob (talked), portal.
static func event(what: String) -> void:
	if not active():
		return
	var id := {"swing": "hammer", "task": "task", "hob": "hob", "portal": "expedition"}.get(what, "") as String
	detect()
	if id != "" and available(id):
		mark(id)

## Looks at the farm for steps that need no hook. A later step done means the earlier ones are too.
static func detect() -> void:
	if not active():
		return
	var wood := int(FarmSites.build_cost("house").get("wood", 0))
	if HomeGather.has_tool("axe"):
		mark("axe")
	if FarmSites.have("wood") >= wood and wood > 0:
		mark("axe")
		mark("chop")
	if not FarmHob.house_entry().is_empty():
		mark("axe")
		mark("chop")
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

## Starter food for the trough, once, when the tutorial's feeding step is reached.
static func give_food() -> void:
	var st := state()
	if bool(st["gift"]):
		return
	st["gift"] = true
	var food: Dictionary = rules()["start_food"]
	for k in food:
		Save.d["items"][k] = int(Save.d["items"].get(k, 0)) + int(food[k])
