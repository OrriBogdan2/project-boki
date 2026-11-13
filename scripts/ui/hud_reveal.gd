class_name HudReveal
extends RefCounted
## Show only what is needed (DECISIONS 2026-11-08, design review 11-10 fix 8): each HUD group has a
## reveal stage in content/rules/hud_reveal.json. A group shows from its match number ("from_match"),
## or once its first event has happened ("first", remembered in Save.d.hud_reveal), or while Tab
## (the scoreboard key) is held. Everything shows outside expeditions (duel, training, tutorial,
## arena), with Settings "Show full HUD", and on saves from before the reveal (no "hud_reveal" key).
##   if HudReveal.on(m, "feed"): ...       # draw the group
##   HudReveal.see("seat_pips")            # its first event happened: it stays from now on

const RULES_PATH := "res://content/rules/hud_reveal.json"
static var _groups: Dictionary = {}

static func groups() -> Dictionary:
	if _groups.is_empty():
		var p = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_groups = p.get("groups", {}) if typeof(p) == TYPE_DICTIONARY else {}
	return _groups

## The expedition this match is for the save: 1 for the first.
static func match_no() -> int:
	return int(Save.d.get("matches", 0)) + 1

## Whether `key` draws now.
static func on(m: Match, key: String) -> bool:
	if not staged(m) or Input.is_action_pressed("scores"):
		return true
	var seen: Dictionary = Save.d["hud_reveal"]
	if seen.has(key):
		return true
	var g: Dictionary = groups().get(key, {})
	var from := int(g.get("from_match", 1))
	return from > 0 and match_no() >= from

## Whether this match stages the HUD at all.
static func staged(m: Match) -> bool:
	if Settings.get_v("hud_full") or not Save.d.has("hud_reveal"):
		return false
	if m.duel or m.tut:
		return false
	return not (m.opts.get("training", false) or m.opts.get("tutorial", false) or m.opts.get("arena", false))

## A group's first event happened: it shows from now on (this save).
static func see(key: String) -> void:
	if Save.d.has("hud_reveal"):
		Save.d["hud_reveal"][key] = true
