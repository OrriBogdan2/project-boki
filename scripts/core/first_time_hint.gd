class_name FirstTimeHint
extends RefCounted
## One-time contextual hints: one short line the first time something matters (a chest key in hand, a
## skill point, a house short of stone), then never again on that save. They took over the tutorial
## steps that were cut. The words are content/rules/hints.json ("match" and "farm" groups); which ones
## a save has had is Save.d.tutorial.hints {id: true}. Callers decide when (MatchHints, FarmHints) and
## how to show it (a match toast, a farm toast); this only makes sure it happens once and words it.

static func rules() -> Dictionary:
	return Content.rules("hints")

## Every hint id of a group ("match" or "farm").
static func ids(group: String) -> Array:
	return (rules().get(group, {}) as Dictionary).keys()

static func _seen() -> Dictionary:
	var tut: Dictionary = Save.d["tutorial"]
	if typeof(tut.get("hints")) != TYPE_DICTIONARY:
		tut["hints"] = {}
	return tut["hints"]

## Has this save had the hint already (shown, or the thing it teaches was done first)?
static func seen(id: String) -> bool:
	return bool(_seen().get(id, false))

## Marks a hint as not needed any more without showing it (the player did the thing on their own).
static func mark(id: String) -> void:
	if id != "":
		_seen()[id] = true

## The hint's line with the player's own keys and Boki name ("" for an unknown id).
static func text(id: String) -> String:
	var raw := ""
	for g in ["match", "farm"]:
		raw = String((rules()[g] as Dictionary).get(id, raw))
	if raw.contains("{rank}"):
		raw = raw.replace("{rank}", TutorialText.rank_combo())
	if raw.contains("{boki}"):
		raw = raw.replace("{boki}", String(Save.active_kin().get("name", "your Boki")))
	for action in ["dash", "crouch", "interact", "throw", "secondary", "build"]:
		raw = raw.replace("{%s}" % action, Settings.key_cap(action))
	return raw

## Shows the hint through toast(text) if this save has not had it; then never again. True if shown.
static func show(id: String, toast: Callable) -> bool:
	if seen(id):
		return false
	var line := text(id)
	if line == "":
		return false
	mark(id)
	toast.call(line)
	return true

## Save v11 -> v12: a save that finished (or skipped) a tutorial already met what that tutorial's cut
## steps taught, so it gets none of their hints; a save still in the farm tutorial keeps them.
static func migrate(data: Dictionary) -> void:
	var tut: Dictionary = data.get("tutorial", {})
	var seen: Dictionary = tut.get("hints", {}) if typeof(tut.get("hints")) == TYPE_DICTIONARY else {}
	var ft = tut.get("ft")
	var ft_done: bool = typeof(ft) == TYPE_DICTIONARY and bool(ft.get("done", false))
	var farm_over: bool = bool(tut.get("day1_done", false)) or ft_done
	for group in [["match", bool(tut.get("match", false))], ["farm", farm_over]]:
		if group[1]:
			for id in ids(String(group[0])):
				seen[id] = true
	tut["hints"] = seen
	data["tutorial"] = tut
