class_name GardenTutorial
extends RefCounted
## The garden-first home tutorial (content/rules/garden_tutorial.json; docs/decisions/0005-garden-first.md).
## A new player's home starts with their Boki, not a resource loop: meet it, pet it, feed it, play
## fetch, give it something that changes it, a tiny training game, then head out together. Building
## and farming (FarmTutorial, Hob's blueprints, the Goals card, chopping and mining) stay out of the way
## until `farm_open()`: after a few expeditions, or as soon as the player talks to Hob once this
## tutorial is over. The screen side is GardenGuide (owned by FarmGuide).
## State is Save.d.tutorial.gt:
##   on      this save is a garden-first save (set once at the hatch; older saves never have it)
##   did     step id -> true for the steps done
##   done    finished
##   farm    building and farming are open
##   m0      Save.d.matches when the tutorial finished (expeditions are counted from there)
##   gift    the gift is in hand (given at the give step)
##   food    the starter food was handed out

static func rules() -> Dictionary:
	return Content.rules("garden_tutorial")

static func option(key: String):
	return rules()["options"][key]

## Called by the hatch on a brand-new save: this save starts garden-first.
static func begin() -> void:
	Save.d["tutorial"]["gt"] = {"on": true, "did": {}, "done": false, "farm": false, "m0": 0, "gift": false, "food": false}

static func state() -> Dictionary:
	var tut: Dictionary = Save.d.get("tutorial", {})
	var gt = tut.get("gt")
	return gt if typeof(gt) == TYPE_DICTIONARY else {}

## Is this a garden-first save (the farm is gated until farm_open)?
static func garden_save() -> bool:
	if "--skip-tutorial" in OS.get_cmdline_user_args():
		return false
	var tut: Dictionary = Save.d.get("tutorial", {})
	return bool(state().get("on", false)) and not bool(tut.get("day1_done", false))

## Is the tutorial running right now?
static func active() -> bool:
	if not garden_save() or Save.d["roster"].is_empty():
		return false
	return not bool(state().get("done", false))

static func steps() -> Array:
	return rules()["steps"]

static func step_def(id: String) -> Dictionary:
	for s in steps():
		if String(s["id"]) == id:
			return s
	return {}

static func did(id: String) -> bool:
	return bool((state().get("did", {}) as Dictionary).get(id, false))

static func done_count() -> int:
	return (state().get("did", {}) as Dictionary).size()

## The step to show: strictly in order ("" when none is left or the tutorial is off).
static func current() -> String:
	if not active():
		return ""
	for s in steps():
		if not did(String(s["id"])):
			return String(s["id"])
	return ""

static func index_of(id: String) -> int:
	var list := steps()
	for i in list.size():
		if String(list[i]["id"]) == id:
			return i
	return -1

static func gift_def() -> Dictionary:
	return rules()["gifts"].get(String(option("gift")), {})

static func fill(raw: String) -> String:
	var rec := Save.active_kin()
	var g := gift_def()
	return raw.replace("{name}", String(rec.get("name", "your Boki"))) \
		.replace("{gift}", String(g.get("name", "gift"))) \
		.replace("{interact}", Settings.key_cap("interact")).replace("{play}", Settings.key_cap("play")) \
		.replace("{stat}", String(Care.STATS.get(train_stat(rec), {}).get("name", "")))

static func hint_text(id: String) -> String:
	var s := step_def(id)
	return "" if s.is_empty() else fill(String(s.get("hint", "")))

static func world_text(id: String) -> String:
	var s := step_def(id)
	return "" if s.is_empty() else fill(String(s.get("world", "")))

# ------------------------------------------------------------------ progress
## Something happened at home: pet, feed, play, give, train, portal (the expedition screen opened).
## Only the current step counts, so the order holds.
static func event(what: String) -> void:
	if not active():
		return
	var id := "out" if what == "portal" else what
	if current() == id:
		mark(id)

static func mark(id: String) -> void:
	var st := state()
	if st.is_empty() or did(id) or step_def(id).is_empty():
		return
	st["did"][id] = true
	if (st["did"] as Dictionary).size() >= steps().size():
		finish()
	Save.save_game()

static func finish() -> void:
	var st := state()
	if st.is_empty() or bool(st.get("done", false)):
		return
	st["done"] = true
	st["m0"] = int(Save.d.get("matches", 0))

## Gets the world ready for the current step (called a couple of times a second while it runs): the
## Boki asks for food and nothing else at the feed step, the starter food is in the bag, the gift is
## in hand. Returns a toast line or "".
static func prepare(rec: Dictionary) -> String:
	if rec.is_empty() or not active():
		return ""
	var st := state()
	var cur := current()
	var settle := float(option("settle_needs_to"))
	if index_of(cur) <= index_of("feed"):
		# before the feed step nothing at all is wanted (the interact key pets); at it, only food
		for n in (["energy", "joy", "clean"] if cur == "feed" else ["energy", "joy", "clean", "food"]):
			if Care.need(rec, n) < settle:
				Care.change(rec, n, settle - Care.need(rec, n))
	if cur == "feed":
		if not bool(st.get("food", false)):
			st["food"] = true
			var food: Dictionary = rules()["start_food"]
			for k in food:
				Save.d["items"][k] = int(Save.d["items"].get(k, 0)) + int(food[k])
			Save.save_game()
		if KinWants.best_food(rec) == "":
			Save.d["items"]["kibble"] = int(Save.d["items"].get("kibble", 0)) + 1      # never stuck: it hates what we gave
		if Care.need(rec, "food") > float(option("hungry_to")):
			Care.change(rec, "food", float(option("hungry_to")) - Care.need(rec, "food"))
	if cur == "train":
		# enough in the tank for the training game (it needs energy 20 and food 12)
		for n in ["energy", "food"]:
			if Care.need(rec, n) < 40.0:
				Care.change(rec, n, 40.0 - Care.need(rec, n))
	if cur == "give" and not bool(st.get("gift", false)):
		st["gift"] = true
		Save.save_game()
		return "You found a %s" % String(gift_def().get("name", "gift"))
	return ""

## What the interact key does on this Boki for the tutorial ("pet", "give", "train" or "" for the usual).
static func kin_use(rec: Dictionary) -> String:
	if not active() or String(rec.get("uid", "")) != String(Save.active_kin().get("uid", "")):
		return ""
	match current():
		"pet":
			return "pet"
		"give":
			return "give" if bool(state().get("gift", false)) else ""
		"train":
			return "train"
	return ""

## The prompt over the Boki for kin_use's action ("" for the usual line).
static func kin_line(rec: Dictionary) -> String:
	var use := kin_use(rec)
	if use == "":
		return ""
	return fill(String(rules()["prompts"].get(use, "")))

## The stat the training step trains: the option's, or the one with the most room if that is capped.
static func train_stat(rec: Dictionary) -> String:
	var want := String(option("train_stat"))
	if rec.is_empty():
		return want
	Care.ensure(rec)
	if int(rec["stats"].get(want, 0)) < Care.stat_cap(rec):
		return want
	var best := want
	var room := -1
	for s in Care.STATS:
		var r := Care.stat_cap(rec) - int(rec["stats"].get(s, 0))
		if r > room:
			room = r
			best = String(s)
	return best

## Gives the tutorial gift: it wears it (an accessory every Boki model shows), and it changes how it
## grows (a stat and an affinity). Returns the toast line, or "" if there was nothing to give.
static func give(rec: Dictionary) -> String:
	var st := state()
	var g := gift_def()
	if g.is_empty() or not bool(st.get("gift", false)) or bool(st.get("given", false)):
		return ""
	st["given"] = true
	var acc := String(g.get("acc", ""))
	if acc != "":
		var owned: Array = Save.d.get("accs", [])
		if not owned.has(acc):
			owned.append(acc)
		Save.d["accs"] = owned
		rec["acc"] = acc
	var stat := String(g.get("stat", ""))
	var gained := 0
	if stat != "":
		gained = Care.add_stat(rec, stat, int(g.get("n", 0)))
	if String(g.get("aff", "")) != "":
		Evo.add(rec, String(g["aff"]), float(g.get("aff_n", 0.0)))
	Care.change(rec, "joy", float(g.get("joy", 0.0)))
	Save.remember(rec, "gift", "got a %s from you" % String(g.get("name", "gift")).to_lower(), 1.5)
	mark("give")
	return String(rules()["gift_toast"]).replace("{name}", String(rec["name"])) \
		.replace("{gift}", String(g.get("name", ""))).replace("{n}", str(gained)) \
		.replace("{stat}", String(Care.STATS.get(stat, {}).get("name", stat)))

# ------------------------------------------------------------------ the farm gate
## Are building, farming and gathering open? Always on older saves; on a garden save after
## farm_after_matches expeditions past this tutorial, or once the player opened them through Hob.
static func farm_open() -> bool:
	if not garden_save():
		return true
	var st := state()
	if bool(st.get("farm", false)):
		return true
	if bool(st.get("done", false)) and int(Save.d.get("matches", 0)) - int(st.get("m0", 0)) >= int(option("farm_after_matches")):
		st["farm"] = true
		st["farm_toast"] = true      # FarmGuide says so once
		Save.save_game()
		return true
	return false

## The player asked for it (talked to Hob once this tutorial is over): building and farming open now.
static func open_farm() -> bool:
	if farm_open() or active():
		return false
	state()["farm"] = true
	Save.save_game()
	return true

## Can the farm tutorial, Hob's blueprints and the Goals card show? (Never alongside this tutorial.)
static func farm_ok() -> bool:
	return farm_open() and not active()

## The one-off "the farm is open" toast, or "".
static func take_farm_toast() -> String:
	var st := state()
	if not bool(st.get("farm_toast", false)):
		return ""
	st.erase("farm_toast")
	return String(rules()["farm_toast"])
