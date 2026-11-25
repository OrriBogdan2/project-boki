class_name HudReveal
extends RefCounted
## Show only what is needed (DECISIONS 2026-11-08, design review 11-10 fix 8): each HUD group has a
## reveal stage in content/rules/hud_reveal.json. A group shows from its match number ("from_match"),
## or once its first event has happened ("first", remembered in Save.d.hud_reveal), or while Tab
## (the scoreboard key) is held. Everything shows outside expeditions (duel, training, tutorial,
## arena), with Settings "Show full HUD", and on saves from before the reveal (no "hud_reveal" key).
## Groups marked "every_match" (the kit card, your own numbers) count the save's expeditions in every match type
## instead. The only HUD reveal gate: HudGroups only counts what is on screen.
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
	if groups().get(key, {}).get("every_match", false):
		return reached(key)
	if not staged(m) or Input.is_action_pressed("scores"):
		return true
	var seen: Dictionary = Save.d["hud_reveal"]
	if seen.has(key):
		return true
	return reached(key)

## Whether the save has played up to the group's from_match (0: never by the match number alone).
static func reached(key: String) -> bool:
	var from := int(groups().get(key, {}).get("from_match", 1))
	return from > 0 and match_no() >= from

## The staged groups (Tab, Show full HUD and the match type open them), not the every_match ones.
static func staged_keys() -> Array:
	return groups().keys().filter(func(k): return not groups()[k].get("every_match", false))

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


## A new player in a staged match (before newcomer_goal's match): ExtractGoal points them only at the newcomer seats.
static func newcomer(m: Match) -> bool:
	return staged(m) and not reached("newcomer_goal")

## Your own kills, knocks and gems (AliveCounter's quieter row): before own_numbers' match, not before the first
## kill, knock or gem, or while Tab / the map key is held (`hold`). The squads/players left above it always show.
static func own_numbers_shown(p: Hunter, hold: bool) -> bool:
	return reached("own_numbers") or hold or (p != null and p.kills + p.knocks + p.gems > 0)

## Does this player get the button card at all (Settings tips, not a recording, not the tutorial, alive)? Before
## kit_card's match a player has the slots and their keys and the words on hover; the training room keeps the card.
static func kit_wanted(hud, p: Hunter) -> bool:
	return Settings.get_v("tips") and not Record.clean() and not hud.m.opts.get("tutorial", false) \
			and not p.out and not hud.guide_hidden and (reached("kit_card") or hud.m.opts.get("training", false))

## Seconds after landing the kit card stays up (Hud._draw_kit); the training room keeps it.
static func kit_s(m: Match) -> float:
	return float(groups()["kit_card"]["show_s"]) if not m.opts.get("training", false) else 1e9

## True once the Ways Out strip has something to tell: a seat is open, in use, taken or lost, or one opens within
## seat_pips' lead_s. Always for a player who is out (the "Ways out left" line is theirs). Every match type.
static func ways_out_shown(m: Match) -> bool:
	var p: Hunter = m.player
	if p == null or p.out or p.extracted:
		return true
	var lead := float(groups()["seat_pips"]["lead_s"])
	for s in WaysOutHud.seats(m):
		if int(s["st"]) != WaysOutHud.St.LOCKED or float(s["t"]) <= lead:
			return true
	return false
