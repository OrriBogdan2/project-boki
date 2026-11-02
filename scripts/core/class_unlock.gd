class_name ClassUnlock
extends RefCounted
## Class unlocks (docs/decisions/0004). A new save picks one starter class; the rest open through
## play: a goal per class plus an account level, both from content/rules/class_unlock.json. Account
## XP is earned from expeditions (after_match). Saves that predate this keep every class open
## (Save._migrate_5_to_6). Locked classes stay playable in the Arena and the Training Grounds, so
## nothing there asks this file; only the pickers that set your expedition class do.
##
## Save.d["classes"] = {all: bool, starter: id or "", open: [ids], reveal: [ids waiting for the
## reveal moment], seen: [ids revealed], xp: int}. A save with no "classes" key counts as all open.

const RULES_PATH := "res://content/rules/class_unlock.json"
static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _rules

## A new save: no starter chosen yet, the default class open so nothing is ever empty-handed.
static func fresh() -> Dictionary:
	return {"all": false, "starter": "", "open": [Arch.default_for("medium")], "reveal": [], "seen": [], "xp": 0}

## Old saves keep everything.
static func legacy() -> Dictionary:
	return {"all": true, "starter": "", "open": [], "reveal": [], "seen": [], "xp": 0}

static func migrate(data: Dictionary) -> void:
	if typeof(data.get("classes")) != TYPE_DICTIONARY:
		data["classes"] = legacy()

static func state() -> Dictionary:
	var c = Save.d.get("classes")
	return c if typeof(c) == TYPE_DICTIONARY else {}

## Whether every class is open on this save (an old save, or admin mode).
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

## Picks the starting class (once). Returns false for a class outside the starter set, or if one is already picked.
static func choose_starter(id: String) -> bool:
	if not starters().has(id) or not needs_starter():
		return false
	var c := state()
	c["starter"] = id
	c["open"] = [id]
	c["seen"] = [id]
	c["reveal"] = []
	return true

## An open class of this weight: `want` if it is open and fits, else the first open one, else "".
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
	return Progress.stat(k)

## {have, need, frac, done} for a class's goal.
static func goal_progress(id: String) -> Dictionary:
	var g: Dictionary = entry(id).get("goal", {})
	if g.is_empty():
		return {"have": 0, "need": 1, "frac": 1.0, "done": true}
	var need := maxi(1, int(g["target"]))
	var have := mini(stat(String(g["stat"])), need)
	return {"have": have, "need": need, "frac": float(have) / float(need), "done": have >= need}

static func goal_text(id: String) -> String:
	return String(entry(id).get("goal", {}).get("text", ""))

static func level_needed(id: String) -> int:
	return int(entry(id).get("level", 1))

## Both halves met: the goal is done and the account is high enough.
static func earned(id: String) -> bool:
	return bool(goal_progress(id)["done"]) and level() >= level_needed(id)

## "locked" (nothing done), "progress" (some of it done), "open".
static func status(id: String) -> String:
	if is_open(id): return "open"
	if earned(id) or float(goal_progress(id)["frac"]) > 0.0 or level() > 1: return "progress"
	return "locked"

## What it takes, in one line, for a locked class's card.
static func requirement(id: String) -> String:
	if is_open(id): return ""
	var gp := goal_progress(id)
	var lv := level_needed(id)
	return "%s (%d/%d) · account level %d%s" % [goal_text(id), int(gp["have"]), int(gp["need"]), lv, "" if level() >= lv else " (you are %d)" % level()]

## Opens every class whose goal and level are met; returns the newly opened ones (queued for the reveal).
static func refresh() -> Array:
	var c := state()
	var out: Array = []
	if c.is_empty() or all_open() or needs_starter():
		return out
	for a in Arch.ids():
		var id: String = a
		if not is_open(id) and earned(id):
			(c["open"] as Array).append(id)
			(c["reveal"] as Array).append(id)
			out.append(id)
	return out

## Called with a finished match (Game.apply_result): XP, the best level, then any unlocks.
## Returns {xp, level_before, level_after, unlocked: [ids]} for the results screen.
static func after_match(r: Dictionary) -> Dictionary:
	var before := level()
	var gained := xp_for(r)
	add_xp(gained)
	if r.has("lvl"):
		var st: Dictionary = Save.d.get("stats", {})
		st["best_lvl"] = maxi(int(st.get("best_lvl", 0)), int(r["lvl"]))
		Save.d["stats"] = st
	var opened := refresh()
	return {"xp": gained, "level_before": before, "level_after": level(), "unlocked": opened}

# ---- the reveal moment
static func pending_reveal() -> Array:
	return (state().get("reveal", []) as Array).duplicate()

## Marks one class's reveal as played.
static func reveal_done(id: String) -> void:
	var c := state()
	if c.is_empty(): return
	(c["reveal"] as Array).erase(id)
	if not (c["seen"] as Array).has(id): (c["seen"] as Array).append(id)
