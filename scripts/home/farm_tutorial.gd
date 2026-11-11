class_name FarmTutorial
extends RefCounted
## The guided garden tutorial (content/rules/farm_tutorial.json "base"; the screen side is FarmGuide). Four
## steps on a new garden: meet your Boki, feed it and watch it change, place a toy and watch it play, head
## out or stay.
## State is Save.d.tutorial.ft:
##   did      step id -> true for the steps done
##   done / skipped   finished, or skipped (no gems or items change hands; the tools are still handed over)
##   gift     the starter food was handed out
## Old saves never see it: the v8 migration marks them done, and so does tutorial.day1_done (the flag
## every test save and the new-game shortcuts already set). A save part-way through the retired twelve-step
## farm tutorial has its old step ids in `did`: migrate() keeps what maps, drops the rest.

static func rules() -> Dictionary:
	return Content.rules("farm_tutorial")

static func option(key: String):
	return rules()["options"][key]

## A save part-way through the retired twelve-step tutorial (axe, chop, ... expedition): its step ids mean
## nothing now, so the new four steps start from the first one. A finished or skipped tutorial stays so.
static func migrate(data: Dictionary) -> void:
	var tut = data.get("tutorial")
	var ft = tut.get("ft") if typeof(tut) == TYPE_DICTIONARY else null
	if typeof(ft) != TYPE_DICTIONARY or typeof(ft.get("did")) != TYPE_DICTIONARY:
		return
	var ids: Array = steps().map(func(s): return String(s["id"]))
	for id in (ft["did"] as Dictionary).keys():
		if not ids.has(String(id)):
			(ft["did"] as Dictionary).erase(id)

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
	return rules()["base"]["steps"]

static func step_def(id: String) -> Dictionary:
	for s in steps():
		if String(s["id"]) == id:
			return s
	return {}

static func did(id: String) -> bool:
	return bool((state()["did"] as Dictionary).get(id, false))

static func done_count() -> int:
	return steps().filter(func(s): return did(String(s["id"]))).size()

## Can this step be the active one yet? Each step also waits for the one before it.
static func available(id: String) -> bool:
	var list := steps()
	for i in list.size():
		if String(list[i]["id"]) == id:
			return list.slice(0, i).all(func(s): return did(String(s["id"])))
	return false

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
	if id != "toy":
		return "go"
	return "watch" if toy_spot().x != INF else "place"

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

static func world_text(id: String) -> String:
	var s := step_def(id)
	return "" if s.is_empty() else String((s["world"] as Dictionary).get(stage(id), ""))

# ------------------------------------------------------------------ progress
## A thing happened on the farm: meet (you walked up to your Boki), play (a Boki began on a toy), portal
## (you headed out), stay (you chose to stay).
static func event(what: String) -> void:
	if not active():
		return
	var ids := {"meet": "meet", "play": "toy", "portal": "out", "stay": "out"}
	var id := ids.get(what, "") as String
	detect()
	if id != "" and available(id):
		mark(id)

## Looks at the farm for steps that need no hook: a fed Boki has been met.
static func detect() -> void:
	if not active():
		return
	if Save.d["roster"].any(func(r): return not (r.get("lean", {}) as Dictionary).is_empty()):
		mark("meet")
		mark("eat")

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

## Skipping: no gems or items granted or taken. FarmGuide puts a toy down and the starter food is handed over.
static func skip() -> void:
	var st := state()
	st["done"] = true
	st["skipped"] = true
	Save.save_game()

## The starter food: a typed one, so its meal shows the lean.
static func food() -> Dictionary:
	return rules()["base"]["start_food"]

## Starter food, once, when the tutorial's feeding step is reached (or skipped past).
static func give_food() -> void:
	var st := state()
	if bool(st["gift"]):
		return
	st["gift"] = true
	var meal := food()
	for k in meal:
		Save.d["items"][k] = int(Save.d["items"].get(k, 0)) + int(meal[k])
