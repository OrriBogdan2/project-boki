class_name FarmTutorial
extends RefCounted
## The guided farm tutorial (content/rules/farm_tutorial.json; the screen side is FarmGuide). Five short
## steps on a new farm: chop trees, place the house, feed, grow a crop, head out. What the cut steps taught
## (stone, hammer, a job, the Market, Hob) is a one-time hint now (FarmHints, FirstTimeHint).
## With base_mode on (FarmUnlocks) the four steps of rules()["base"] run instead: meet your Boki, feed it,
## place a toy and watch it play, head out or stay.
## State is Save.d.tutorial.ft:
##   did      step id -> true for the steps done
##   done / skipped   finished, or skipped (a skip still gets the house, the starter food and the end gems;
##                    the axe and pickaxe come with a new save)
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

## The base's tutorial instead of the farm's (farm_build.json base_mode).
static func base() -> bool:
	return FarmUnlocks.base_mode()

static func steps() -> Array:
	return rules()["base"]["steps"] if base() else rules()["steps"]

## Does the tutorial show a Skip? Always in the base; on the farm the option says.
static func skippable() -> bool:
	return base() or bool(option("skippable"))

static func step_def(id: String) -> Dictionary:
	for s in steps():
		if String(s["id"]) == id:
			return s
	return {}

static func did(id: String) -> bool:
	return bool((state()["did"] as Dictionary).get(id, false))

static func done_count() -> int:
	return steps().filter(func(s): return did(String(s["id"]))).size()

## Can this step be the active one yet? Its "needs" are done; the last step waits for everything; without
## the free_order option each step also waits for the one before it.
static func available(id: String) -> bool:
	var list := steps()
	for i in list.size():
		var def: Dictionary = list[i]
		if String(def["id"]) != id:
			continue
		var before := list.slice(0, i)
		if bool(def.get("needs_all", false)) or not bool(option("free_order")):
			return before.all(func(s): return did(String(s["id"])))
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
			return "place"
		"feed":
			return "fill" if not Econ.feeders().is_empty() else "place"
		"crop":
			return _crop_stage()
		"toy":
			return "watch" if toy_spot().x != INF else "place"
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

static func toy_spot() -> Vector3:
	for e in HomeLayout.of(Save.d).get("deco", []):
		if HomeToys.rules()["toys"].has(String(e.get("id", ""))):
			return HomeLayout.deco_center(e)
	return Vector3.INF

static func hint_text(id: String) -> String:
	var s := step_def(id)
	if s.is_empty():
		return ""
	var raw := String((s["hints"] as Dictionary).get(stage(id), ""))
	var txt := raw.replace("{build}", Settings.key_cap("build"))
	txt = txt.replace("{food}", Care.food_name(String(food().keys()[0])))
	txt = txt.replace("{house_cost}", FarmSites.cost_text(FarmSites.build_cost("house")))
	return txt.replace("{interact}", Settings.key_cap("interact")).replace("{details}", Settings.key_cap("details"))

## What the spotlight lights for this step's current stage: {"hub": bar button id}, or {}.
static func spot(id: String) -> Dictionary:
	return (step_def(id).get("spot", {}) as Dictionary).get(stage(id), {})

static func world_text(id: String) -> String:
	var s := step_def(id)
	return "" if s.is_empty() else String((s["world"] as Dictionary).get(stage(id), ""))

# ------------------------------------------------------------------ progress
## A thing happened on the farm: swing (a hammer), task (a Boki pinned to a job), hob (talked), buy, sell,
## portal. The portal is the last step; the rest were steps once and are one-time hints now, so doing the
## thing means its hint is no longer needed (FirstTimeHint).
## In the base: meet (you walked up to your Boki), play (a Boki began on a toy), stay (you chose to stay).
static func event(what: String) -> void:
	var hint := {"swing": "hammer", "task": "task", "hob": "hob", "buy": "buy", "sell": "sell"}
	if hint.has(what):
		FirstTimeHint.mark(String(hint[what]))
	if not active():
		return
	detect()
	if base():
		var id := String({"meet": "meet", "play": "toy", "portal": "out", "stay": "out"}.get(what, ""))
		if id != "" and available(id):
			mark(id)
	elif what == "portal" and available("expedition"):
		mark("expedition")

## Looks at the farm for steps that need no hook. A later step done means the earlier ones are too.
static func detect() -> void:
	if not active():
		return
	if base():
		if Save.d["roster"].any(func(r): return not (r.get("lean", {}) as Dictionary).is_empty()):
			mark("meet")      # fed, so it has been met
			mark("eat")
		return
	var cost := FarmSites.build_cost("house")
	var wood := int(cost.get("wood", 0))
	if FarmSites.have("wood") >= wood and wood > 0:
		mark("chop")
	if not FarmHob.house_entry().is_empty():
		mark("chop")
		mark("house")
	if Econ.feeders().any(func(f): return Econ.fill(f) > 0):
		mark("feed")
	if Progress.stat("harvested") > 0 and not HomeLayout.fixtures(Save.d, "farm").is_empty():
		mark("crop")

static func mark(id: String) -> void:
	var st := state()
	if bool((st["did"] as Dictionary).get(id, false)) or step_def(id).is_empty():
		return
	st["did"][id] = true
	if done_count() >= steps().size():
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

## Skipping loses nothing a player needs: the starter food and the end gems are given (FarmGuide.skip also
## puts the house up, or in the base a toy
## down). Returns the gems granted.
static func skip() -> int:
	give_food()
	var gems := finish()
	state()["skipped"] = true
	Save.save_game()
	return gems

## The starter food: the base's is a typed one, so its meal shows the lean.
static func food() -> Dictionary:
	return rules()["base"]["start_food"] if base() else rules()["start_food"]

## Starter food, once, when the tutorial's feeding step is reached (or skipped past).
static func give_food() -> void:
	var st := state()
	if bool(st["gift"]):
		return
	st["gift"] = true
	var meal := food()
	for k in meal:
		Save.d["items"][k] = int(Save.d["items"].get(k, 0)) + int(meal[k])
