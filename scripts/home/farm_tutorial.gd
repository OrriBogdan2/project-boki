class_name FarmTutorial
extends RefCounted
## The guided farm tutorial (content/rules/farm_tutorial.json; the screen side is FarmGuide). Four short steps
## on a new base (farm_build.json base_mode on): meet your Boki, feed it, place a toy and watch it play, head
## out or stay.
## State is Save.d.tutorial.ft:
##   did      step id -> true for the steps done
##   done / skipped   finished, or skipped (no gems or items change hands; the tools are still handed over)
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
	if not FarmUnlocks.base_mode():      # the toy step needs the Base tab
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
	return steps().filter(func(s): return did(String(s["id"]))).size()

## Can this step be the active one yet? Its "needs" are done.
static func available(id: String) -> bool:
	for def in steps():
		if String(def["id"]) == id:
			return (def.get("needs", []) as Array).all(func(n): return did(String(n)))
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
	return txt.replace("{interact}", Settings.key_cap("interact")).replace("{details}", Settings.key_cap("details"))

## What the spotlight lights for this step's current stage: {"hub": bar button id, "world": true}, or {}.
static func spot(id: String) -> Dictionary:
	return (step_def(id).get("spot", {}) as Dictionary).get(stage(id), {})

static func world_text(id: String) -> String:
	var s := step_def(id)
	return "" if s.is_empty() else String((s["world"] as Dictionary).get(stage(id), ""))

# ------------------------------------------------------------------ progress
## A thing happened on the base: meet (you walked up to your Boki), play (a Boki began on a toy), portal (you
## headed out), stay (you chose to stay).
static func event(what: String) -> void:
	if not active():
		return
	var id := {"meet": "meet", "play": "toy", "portal": "out", "stay": "out"}.get(what, "") as String
	detect()
	if id != "" and available(id):
		mark(id)

## Looks at the base for steps that need no hook: a fed Boki has been met.
static func detect() -> void:
	if active() and Save.d["roster"].any(func(r): return not (r.get("lean", {}) as Dictionary).is_empty()):
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

## Skipping: no gems are granted or taken. FarmGuide puts a toy down and the starter food is handed over.
static func skip() -> void:
	var st := state()
	st["done"] = true
	st["skipped"] = true
	Save.save_game()

## The starter food: a typed one, so its meal shows the lean.
static func food() -> Dictionary:
	return rules()["start_food"]

## Starter food, once, when the tutorial's feeding step is reached (or skipped past).
static func give_food() -> void:
	var st := state()
	if bool(st["gift"]):
		return
	st["gift"] = true
	var meal := food()
	for k in meal:
		Save.d["items"][k] = int(Save.d["items"].get(k, 0)) + int(meal[k])
