class_name ClassUnlock
extends RefCounted
## Relic unlocks and mastery (docs/decisions/0005; internally Hunters, archetypes and the save key "classes").
## A new save wears Vex first (the one starter, taken before the egg pick) and plays the tutorial as Vex. After
## the first finished expedition (the tutorial) it picks 1 of 3 as the second Relic: Kael, Cinder or Meeko
## ("second_picks"). Every other Relic opens through its own challenge (content/rules/class_unlock.json "unlock"),
## counted across every expedition whoever you play. A done challenge never opens a Hunter by itself: it is
## unlocked by holding the button on the Relics screen (HoldUnlock calls unlock()). Each Hunter also has
## mastery goals, counted only while you play it; each one done is a mastery level and a cosmetic reward.
## Nothing here ever changes stats or abilities. Locked Hunters stay playable in the Arena and the
## training area; only the pickers that set your expedition Hunter ask this file.
##
## Save.d["classes"] = {all: bool, picks: [the creation pick], open: [ids], bonus: [starters that open after the
## first expedition (old saves)], second: [the second-Relic choices still to pick from], second_ready: bool (the
## first expedition is done, so the pick is on offer), fresh: [just opened, not announced], told: int (ready unlocks
## already announced), reveal: [ids], seen: [ids], stats: {stat: n} (every expedition),
## hunters: {id: {stat: n}} (expeditions played as that Hunter)}. No "classes" key reads as all open.
# "mask" in code = "Relic" in game, owner 2026-11-07 (also the setting key demo_all_masks)

const RULES_PATH := "res://content/rules/class_unlock.json"
static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _rules

## A new save: nothing is open, the starter pick is still to make.
static func fresh() -> Dictionary:
	return {"all": false, "picks": [], "open": [], "told": 0, "reveal": [], "seen": [],
			"stats": {}, "hunters": {}}

## A save from before Hunter unlocks had every Hunter, so it keeps them all.
static func legacy() -> Dictionary:
	var c := fresh()
	c["all"] = true
	c["open"] = []
	return c

## v5 -> v6 (Save._migrate_5_to_6).
static func migrate(data: Dictionary) -> void:
	if typeof(data.get("classes")) != TYPE_DICTIONARY:
		data["classes"] = legacy()

## A v6 save from the first unlock flow (one starter, free picks, account XP) keeps every Hunter it had
## open or played and drops the old keys.
static func upgrade_early_v6(c: Dictionary, played_now: String) -> void:
	if not c.has("early_used") and not c.has("starter"):
		return
	var open_list: Array = c.get("open", [])
	var starter := String(c.get("starter", ""))
	for id in ["gunslinger", starter, played_now]:      # (Vex: every save had him before the starter pick)
		if Arch.exists(id) and not open_list.has(id):
			open_list.append(id)
	c["open"] = open_list
	c["picks"] = [starter] if Arch.exists(starter) else open_list.slice(0, 1)
	for old_key in ["starter", "early_used", "xp"]:
		c.erase(old_key)
	if typeof(c.get("stats")) != TYPE_DICTIONARY:
		c["stats"] = {}
	if typeof(c.get("hunters")) != TYPE_DICTIONARY:
		c["hunters"] = {}

static func state() -> Dictionary:
	var c = Save.d.get("classes")
	if typeof(c) != TYPE_DICTIONARY:
		return {}
	upgrade_early_v6(c, String(Save.d.get("arch", "")))
	var picked_before: bool = not c.has("bonus") and not (c.get("picks", []) as Array).is_empty()
	if picked_before and not (c["open"] as Array).has("gunslinger"):
		(c["open"] as Array).append("gunslinger")      # (a save from before the first-Hunter pick: Vex was always open)
	return c

## Settings > Demo > "All masks open": every Relic pickable while offline. The save's unlocks are not touched.
static func demo_all() -> bool:
	return bool(Settings.get_v("demo_all_masks")) and not Net.online()

## Whether every Hunter is open on this save (an old save, admin mode, or the offline demo setting).
static func all_open() -> bool:
	var c := state()
	return c.is_empty() or bool(c.get("all", false)) or Game.modding() or demo_all()

## The Relic to send online: the demo setting is offline only, so one this save has not opened falls back to an
## open one of its weight (else the first open one).
static func online_arch(id: String) -> String:
	var opened: Array = state().get("open", [])
	if not demo_all() or opened.has(id) or opened.is_empty():
		return id
	var same := opened.filter(func(a): return Arch.weight(String(a)) == Arch.weight(id))
	return String(same[0] if not same.is_empty() else opened[0])

static func is_open(id: String) -> bool:
	return all_open() or (state().get("open", []) as Array).has(id)

static func open_ids() -> Array:
	return Arch.ids().filter(func(a): return is_open(a))

# ---- the starter pick (Vex), then the second Relic: 1 of 3 after the first expedition
static func starters() -> Array:
	return (rules().get("starters", []) as Array).filter(func(a): return Arch.exists(String(a)))

static func picks_needed() -> int:
	return int(rules().get("starter_picks", 1))

## A new save still has to make its creation pick.
static func needs_starters() -> bool:
	return not all_open() and (state().get("picks", []) as Array).is_empty()

static func picks() -> Array:
	return (state().get("picks", []) as Array).duplicate()

## Makes the starter pick (once): exactly picks_needed() different starters. Anything else is refused.
## The other starters wait in "bonus" for the first finished expedition.
static func choose_starters(ids: Array) -> bool:
	if not needs_starters() or ids.size() != picks_needed():
		return false
	var unique: Array = []
	for a in ids:
		if starters().has(String(a)) and not unique.has(String(a)):
			unique.append(String(a))
	if unique.size() != picks_needed():
		return false
	var c := state()
	c["picks"] = unique.duplicate()
	c["open"] = unique.duplicate()
	c["bonus"] = starters().filter(func(a): return not unique.has(a))
	c["second"] = second_picks().filter(func(a): return not unique.has(a))
	c["seen"] = c["open"].duplicate()
	c["reveal"] = []
	return true

## The Relics the second pick chooses from (second_picks in the rules).
static func second_picks() -> Array:
	return (rules().get("second_picks", []) as Array).filter(func(a): return Arch.exists(String(a)))

## The first expedition is done and the second Relic is still to pick.
static func second_pending() -> bool:
	var c := state()
	return bool(c.get("second_ready", false)) and not (c.get("second", []) as Array).is_empty()

## Makes the second pick (once): one of the choices opens, with its reveal queued. Anything else is refused.
static func choose_second(id: String) -> bool:
	if not second_pending() or not (state()["second"] as Array).has(id):
		return false
	var c := state()
	c["second"] = []
	c["second_ready"] = false
	(c["open"] as Array).append(id)
	(c["seen"] as Array).append(id)
	(c["reveal"] as Array).append(id)
	return true

## The first finished expedition (any finish): the rest of the starters open (old saves) and the second pick
## is on offer. Returns the ids opened.
static func open_bonus() -> Array:
	var c := state()
	c["second_ready"] = not (c.get("second", []) as Array).is_empty()
	var ids: Array = (c.get("bonus", []) as Array).duplicate()
	if ids.is_empty():
		return ids
	c["bonus"] = []
	for id in ids:
		(c["open"] as Array).append(id)
		(c["seen"] as Array).append(id)
	c["fresh"] = ids.duplicate()
	return ids

## "Vex and Kael are open now" for starters opened and not yet announced ("" when none); marks them told.
static func take_fresh() -> String:
	var c := state()
	var names: Array = (c.get("fresh", []) as Array).map(func(a): return Arch.name_of(String(a)))
	if names.is_empty():
		return ""
	c["fresh"] = []
	return "%s %s open now" % [" and ".join(names), "is" if names.size() == 1 else "are"]

## An open Hunter of this weight (internal: the Try-on rack): `want` if it is open and fits, else the
## first open one, else "".
static func fix(want: String, weight: String) -> String:
	if Arch.exists(want) and Arch.weight(want) == weight and is_open(want):
		return want
	for a in Arch.of_class(weight):
		if is_open(String(a)):
			return String(a)
	return ""

# ---- "Start here": the four Hunters a new save is pointed at (rules "start_here"), until its first matches are played
## The one-line role of a "Start here" Hunter, "" for any other Hunter or once the save has played enough matches.
static func start_role(id: String) -> String:
	var tag: Dictionary = rules().get("start_here", {})
	if int(Save.d.get("matches", 0)) >= int(tag.get("until_matches", 0)):
		return ""
	return String((tag.get("roles", {}) as Dictionary).get(id, ""))

# ---- counting: what one expedition adds
## The counts one finished expedition adds ({stat: n}): its result plus the feats HunterFeats recorded.
static func match_counts(r: Dictionary) -> Dictionary:
	var out := {}
	var ms: Dictionary = r.get("stats", {})
	for k in ms:
		if typeof(ms[k]) == TYPE_INT:
			out[k] = int(ms[k])
	var escaped := bool(r.get("extracted", false))
	out["knocks"] = int(r.get("knocks", 0))
	out["revives"] = int(r.get("revives", 0))
	out["extracts"] = 1 if escaped else 0
	out["close_out"] = 1 if escaped and int(r.get("downs", 0)) > 0 else 0
	out["best_haul"] = (r.get("haul", []) as Array).size() if escaped else 0
	out["caught"] = (r.get("caught", []) as Array).size() if escaped else 0
	return out

## Adds one expedition's counts to a tally: totals add up, best_ stats keep the best.
static func tally(into: Dictionary, counts: Dictionary) -> void:
	for k in counts:
		var n := int(counts[k])
		if String(k).begins_with("best_"):
			into[k] = maxi(int(into.get(k, 0)), n)
		elif n != 0:
			into[k] = int(into.get(k, 0)) + n

static func account_stat(k: String) -> int:
	return int((state().get("stats", {}) as Dictionary).get(k, 0))

static func hunter_stat(id: String, k: String) -> int:
	return int((state().get("hunters", {}) as Dictionary).get(id, {}).get(k, 0))

static func _progress(have_raw: int, target: int) -> Dictionary:
	var need := maxi(1, target)
	var have := mini(have_raw, need)
	return {"have": have, "need": need, "frac": float(have) / float(need), "done": have >= need}

# ---- unlock challenges
static func challenge(id: String) -> Dictionary:
	return (rules().get("unlock", {}) as Dictionary).get(id, {})

static func challenge_text(id: String) -> String:
	return String(challenge(id).get("text", ""))

static func tier(id: String) -> String:
	return String(challenge(id).get("tier", ""))

## {have, need, frac, done} for a Hunter's unlock challenge.
static func challenge_progress(id: String) -> Dictionary:
	var ch := challenge(id)
	return _progress(account_stat(String(ch.get("stat", ""))), int(ch.get("target", 1)))

## How many Hunters must be open before this one's challenge can unlock it (0: none).
static func open_needed(id: String) -> int:
	return int(challenge(id).get("after", 0))

## Can it be unlocked now (by holding)?
static func can_unlock(id: String) -> bool:
	if not Arch.exists(id) or is_open(id) or needs_starters() or is_bonus(id):
		return false
	return bool(challenge_progress(id)["done"]) and open_ids().size() >= open_needed(id)

## Waiting to open after the first expedition (an old save's starter, or one of the second Relic's choices).
static func is_bonus(id: String) -> bool:
	return (state().get("bonus", []) as Array).has(id) or (state().get("second", []) as Array).has(id)

static func ready_count() -> int:
	if all_open() or needs_starters():
		return 0
	return Arch.ids().filter(func(a): return can_unlock(String(a))).size()

## "locked" (nothing done yet), "progress" (some of it, or done but waiting on other Hunters),
## "ready" (hold to unlock) or "open".
static func status(id: String) -> String:
	if is_open(id):
		return "open"
	if can_unlock(id):
		return "ready"
	if float(challenge_progress(id)["frac"]) > 0.0:
		return "progress"
	return "locked"

## What it takes, in one line with its counter, for a locked Hunter's card.
static func requirement(id: String) -> String:
	if is_open(id):
		return ""
	if (state().get("second", []) as Array).has(id):
		var names := second_picks().map(func(a): return Arch.name_of(String(a), true))
		return "One of %s opens after your first expedition" % ", ".join(names)
	if is_bonus(id):
		return "Opens after your first expedition"
	if can_unlock(id):
		return "Ready: hold to unlock it on the Relics screen"
	var gp := challenge_progress(id)
	var line := "%s (%d/%d)" % [challenge_text(id), int(gp["have"]), int(gp["need"])]
	if open_ids().size() < open_needed(id):
		line += ", once %d Relics are open" % open_needed(id)
	return line

## Unlocks a ready Hunter (the end of the hold). Returns false if it isn't ready.
static func unlock(id: String) -> bool:
	if not can_unlock(id):
		return false
	var c := state()
	(c["open"] as Array).append(id)
	if not c.has("seen"):
		c["seen"] = []
	if not (c["seen"] as Array).has(id):
		(c["seen"] as Array).append(id)
	c["told"] = mini(int(c.get("told", 0)), ready_count())
	return true

## Unlocks that became ready since the player was last told (the farm's toast); marks them told.
static func take_news() -> int:
	var c := state()
	if c.is_empty() or all_open():
		return 0
	var n := ready_count() - int(c.get("told", 0))
	c["told"] = ready_count()
	return maxi(0, n)

# ---- mastery: goals per Hunter, cosmetic rewards only
static func mastery(id: String) -> Array:
	return (rules().get("mastery", {}) as Dictionary).get(id, [])

## {have, need, frac, done} for one of a Hunter's mastery goals.
static func mastery_progress(id: String, i: int) -> Dictionary:
	var g: Dictionary = mastery(id)[i]
	return _progress(hunter_stat(id, String(g["stat"])), int(g["target"]))

## How many of a Hunter's mastery goals are done (its mastery level).
static func mastery_level(id: String) -> int:
	return _done_goals(id).size()

## The Hunter and goal that give a cosmetic reward ({id, index, goal}, or {} if none does).
static func reward_source(kind: String, reward_id: String) -> Dictionary:
	for id in (rules().get("mastery", {}) as Dictionary):
		var goals := mastery(String(id))
		for i in goals.size():
			var rw: Dictionary = goals[i]["reward"]
			if String(rw["kind"]) == kind and String(rw["id"]) == reward_id:
				return {"id": String(id), "index": i, "goal": goals[i]}
	return {}

## Whether a cosmetic reward (e.g. "glider", "paper_crane") has been earned through mastery on this save.
static func reward_earned(kind: String, reward_id: String) -> bool:
	var src := reward_source(kind, reward_id)
	return not src.is_empty() and bool(mastery_progress(String(src["id"]), int(src["index"]))["done"])

static func reward_kind_name(kind: String) -> String:
	return String((rules().get("reward_kinds", {}) as Dictionary).get(kind, kind))

# ---- after an expedition
## Called with a finished expedition (Game.apply_result): counts it for the account and for the Hunter
## played, then reports {ready: unlocks you can take now, new: of them not yet announced, mastered:
## [{id, text, reward}] goals this expedition finished} for the results screen.
static func after_match(r: Dictionary) -> Dictionary:
	var c := state()
	if c.is_empty():
		return {}
	open_bonus()
	var played := String(r.get("arch", Arch.of_save()))
	var before := _done_goals(played)
	var counts := match_counts(r)
	tally(c["stats"], counts)
	if Arch.exists(played):
		var per: Dictionary = c["hunters"]
		if typeof(per.get(played)) != TYPE_DICTIONARY:
			per[played] = {}
		tally(per[played], counts)
	var mastered: Array = []
	for i in _done_goals(played):
		if not before.has(i):
			var g: Dictionary = mastery(played)[i]
			mastered.append({"id": played, "text": String(g["text"]), "reward": g["reward"]})
	return {"ready": ready_count(), "new": maxi(0, ready_count() - int(c.get("told", 0))), "mastered": mastered}

static func _done_goals(id: String) -> Array:
	var out: Array = []
	if not Arch.exists(id):
		return out
	for i in mastery(id).size():
		if bool(mastery_progress(id, i)["done"]):
			out.append(i)
	return out

# ---- the reveal moment
static func pending_reveal() -> Array:
	return (state().get("reveal", []) as Array).duplicate()

## Marks one Hunter's reveal as played.
static func reveal_done(id: String) -> void:
	var c := state()
	if c.is_empty():
		return
	(c["reveal"] as Array).erase(id)
	if not (c["seen"] as Array).has(id):
		(c["seen"] as Array).append(id)
