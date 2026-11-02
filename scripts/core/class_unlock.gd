class_name ClassUnlock
extends RefCounted
## Hunter unlocks (docs/decisions/0005; player-facing these are "Hunters", internally archetypes and
## the save key "classes"). A new save picks 1 starting Hunter at character creation. The next unlocks
## come early: each "early" goal in content/rules/class_unlock.json, done in order, is a free pick of any
## locked Hunter. After that a Hunter is ready when its own goal is done and the account level is
## reached. Nothing opens by itself: a ready Hunter is unlocked by holding the button on the Hunters
## screen (HoldUnlock calls unlock()). Account XP is earned from expeditions (after_match). Saves that
## predate this keep every Hunter open (Save._migrate_5_to_6). Locked Hunters stay playable in the
## Arena and the Training Grounds, so nothing there asks this file; only the pickers that set your
## expedition Hunter do.
##
## Save.d["classes"] = {all: bool, starter: id or "", open: [ids], early_used: int (free picks spent),
## told: int (unlocks already announced), reveal: [ids waiting for the reveal moment], seen: [ids
## revealed], xp: int}. A save with no "classes" key counts as all open; missing keys read as 0 / [].

const RULES_PATH := "res://content/rules/class_unlock.json"
static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _rules

## A new save: no starter chosen yet, the default Hunter open so nothing is ever empty-handed.
static func fresh() -> Dictionary:
	return {"all": false, "starter": "", "open": [Arch.default_for("medium")], "early_used": 0, "told": 0,
			"reveal": [], "seen": [], "xp": 0}

## Old saves keep everything.
static func legacy() -> Dictionary:
	return {"all": true, "starter": "", "open": [], "early_used": 0, "told": 0, "reveal": [], "seen": [], "xp": 0}

static func migrate(data: Dictionary) -> void:
	if typeof(data.get("classes")) != TYPE_DICTIONARY:
		data["classes"] = legacy()

static func state() -> Dictionary:
	var c = Save.d.get("classes")
	return c if typeof(c) == TYPE_DICTIONARY else {}

## Whether every Hunter is open on this save (an old save, or admin mode).
static func all_open() -> bool:
	var c := state()
	return c.is_empty() or bool(c.get("all", false)) or Game.modding()

static func is_open(id: String) -> bool:
	return all_open() or (state().get("open", []) as Array).has(id)

static func open_ids() -> Array:
	return Arch.ids().filter(func(a): return is_open(a))

static func starters() -> Array:
	return (rules().get("starters", []) as Array).filter(func(a): return Arch.exists(String(a)))

## A new save still has to pick its starter.
static func needs_starter() -> bool:
	return not all_open() and String(state().get("starter", "")) == ""

static func starter() -> String:
	return String(state().get("starter", ""))

## Picks the starting Hunter (once). Returns false for one outside the starter set, or if one is already picked.
static func choose_starter(id: String) -> bool:
	if not starters().has(id) or not needs_starter():
		return false
	var c := state()
	c["starter"] = id
	c["open"] = [id]
	c["seen"] = [id]
	c["reveal"] = []
	return true

## An open Hunter of this weight (internal: the Try-on rack and old callers): `want` if it is open and fits, else the
## first open one, else "".
static func fix(want: String, weight: String) -> String:
	if Arch.exists(want) and Arch.weight(want) == weight and is_open(want):
		return want
	for a in Arch.of_class(weight):
		if is_open(String(a)): return String(a)
	return ""

# ---- account XP and level
static func xp() -> int:
	return int(state().get("xp", 0))

static func xp_cost(level: int) -> int:
	var x: Dictionary = rules()["xp"]
	return int(x["level_base"]) + int(x["level_step"]) * (level - 1)

## [level, xp into the level, xp the level takes] for a total.
static func level_of(total: int) -> Array:
	var lv := 1
	var left := total
	var cap := int(rules()["xp"]["max_level"])
	while lv < cap and left >= xp_cost(lv):
		left -= xp_cost(lv)
		lv += 1
	return [lv, left, xp_cost(lv)]

static func level() -> int:
	return int(level_of(xp())[0])

static func add_xp(n: int) -> void:
	var c := state()
	if not c.is_empty() and n > 0:
		c["xp"] = int(c.get("xp", 0)) + n

## The XP an expedition result is worth (also shown on the results screen).
static func xp_for(r: Dictionary) -> int:
	var x: Dictionary = rules()["xp"]
	var s: Dictionary = r.get("stats", {})
	var n := int(x["match"])
	if r.get("extracted", false): n += int(x["extract"])
	n += mini(int(s.get("mobs", 0)) * int(x["mob"]), int(x["mob_cap"]))
	n += mini(int(r.get("knocks", 0)) * int(x["knock"]), int(x["knock_cap"]))
	n += int(s.get("bosses", 0)) * int(x["boss"])
	if r.get("extracted", false): n += (r.get("caught", []) as Array).size() * int(x["caught"])
	return n

# ---- goals
static func entry(id: String) -> Dictionary:
	return (rules()["classes"] as Dictionary).get(id, {})

static func stat(k: String) -> int:
	if k == "best_lvl": return int(Save.d.get("stats", {}).get("best_lvl", 0))
	if k == "matches": return int(Save.d.get("matches", 0))
	return Progress.stat(k)

static func _progress(g: Dictionary) -> Dictionary:
	if g.is_empty():
		return {"have": 0, "need": 1, "frac": 1.0, "done": true}
	var need := maxi(1, int(g["target"]))
	var have := mini(stat(String(g["stat"])), need)
	return {"have": have, "need": need, "frac": float(have) / float(need), "done": have >= need}

## {have, need, frac, done} for a Hunter's own goal.
static func goal_progress(id: String) -> Dictionary:
	return _progress(entry(id).get("goal", {}))

static func goal_text(id: String) -> String:
	return String(entry(id).get("goal", {}).get("text", ""))

static func level_needed(id: String) -> int:
	return int(entry(id).get("level", 1))

## Both halves of a Hunter's own goal met: the goal is done and the account is high enough.
static func earned(id: String) -> bool:
	return bool(goal_progress(id)["done"]) and level() >= level_needed(id)

# ---- the early unlocks: free picks of any locked Hunter
static func early() -> Array:
	return rules().get("early", [])

## How many early goals are done, counted in order (the second only counts once the first is done).
static func early_done() -> int:
	var n := 0
	for g in early():
		if not bool(_progress(g)["done"]): break
		n += 1
	return n

## Free picks waiting to be spent (early goals done, minus the ones used).
static func free_picks() -> int:
	if all_open() or needs_starter(): return 0
	return maxi(0, early_done() - int(state().get("early_used", 0)))

## The next early goal still to do: {text, have, need, frac, done, index}, or {} once they are all done.
static func next_early() -> Dictionary:
	var i := early_done()
	if i >= early().size(): return {}
	var out := _progress(early()[i])
	out["text"] = String(early()[i].get("text", ""))
	out["index"] = i
	return out

## Can it be unlocked now (by holding)? A free pick works on any locked Hunter.
static func can_unlock(id: String) -> bool:
	return Arch.exists(id) and not is_open(id) and not needs_starter() and (free_picks() > 0 or earned(id))

## How many unlocks the player could take right now (each Hunter's own goal, plus the free picks).
static func ready_count() -> int:
	if all_open() or needs_starter(): return 0
	var own := Arch.ids().filter(func(a): return not is_open(String(a)) and earned(String(a))).size()
	var others := Arch.ids().filter(func(a): return not is_open(String(a))).size() - own
	return own + mini(free_picks(), others)

## "locked" (nothing done), "progress" (some of the goal done, or done and waiting on the level),
## "ready" (hold to unlock), "open".
static func status(id: String) -> String:
	if is_open(id): return "open"
	if can_unlock(id): return "ready"
	if float(goal_progress(id)["frac"]) > 0.0: return "progress"
	return "locked"

## What it takes, in one line, for a locked Hunter's card.
static func requirement(id: String) -> String:
	if is_open(id): return ""
	if can_unlock(id): return "Ready: hold to unlock it on the Hunters screen"
	var gp := goal_progress(id)
	var lv := level_needed(id)
	var own := "%s (%d/%d) · account level %d%s" % [goal_text(id), int(gp["have"]), int(gp["need"]), lv,
			"" if level() >= lv else " (you are %d)" % level()]
	var ne := next_early()
	if not ne.is_empty() and not needs_starter():
		return "%s (%d/%d) for a free pick, or %s" % [String(ne["text"]), int(ne["have"]), int(ne["need"]), own]
	return own

## Unlocks a ready Hunter (the end of the hold). Its own goal is used when it is met; otherwise a free
## pick is spent. Queues nothing: the hold plays its own reveal. Returns false if it isn't ready.
static func unlock(id: String) -> bool:
	if not can_unlock(id):
		return false
	var c := state()
	if not earned(id):
		c["early_used"] = int(c.get("early_used", 0)) + 1
	(c["open"] as Array).append(id)
	if not c.has("seen"): c["seen"] = []
	if not (c["seen"] as Array).has(id): (c["seen"] as Array).append(id)
	c["told"] = mini(int(c.get("told", 0)), ready_count())
	return true

## Unlocks that became ready since the player was last told (the farm's toast); marks them told.
static func take_news() -> int:
	var c := state()
	if c.is_empty() or all_open(): return 0
	var n := ready_count() - int(c.get("told", 0))
	c["told"] = ready_count()
	return maxi(0, n)

## Called with a finished match (Game.apply_result): XP, the best level, then what became ready.
## Returns {xp, level_before, level_after, ready: n unlocks you can take now, new: n of them not yet
## announced} for the results screen.
static func after_match(r: Dictionary) -> Dictionary:
	var before := level()
	var gained := xp_for(r)
	add_xp(gained)
	if r.has("lvl"):
		var st: Dictionary = Save.d.get("stats", {})
		st["best_lvl"] = maxi(int(st.get("best_lvl", 0)), int(r["lvl"]))
		Save.d["stats"] = st
	return {"xp": gained, "level_before": before, "level_after": level(), "ready": ready_count(), "new": maxi(0,
			ready_count() - int(state().get("told", 0)))}

# ---- the reveal moment
static func pending_reveal() -> Array:
	return (state().get("reveal", []) as Array).duplicate()

## Marks one class's reveal as played.
static func reveal_done(id: String) -> void:
	var c := state()
	if c.is_empty(): return
	(c["reveal"] as Array).erase(id)
	if not (c["seen"] as Array).has(id): (c["seen"] as Array).append(id)
