class_name HudGroups
extends RefCounted
## What a new player's HUD holds back (DECISIONS 2026-11-08 "UI is too much": about 5 groups at once, the rest
## appears when it first matters or while Tab is held). Two groups so far; the timeline that found them is in
## docs/HUD.md ("First real match: the HUD over time"). Veterans see the HUD as before.

const NEW_PLAYER_MATCHES := 3      # expeditions a save has played before the whole HUD shows by itself

static func new_player() -> bool:
	return int(Save.d.get("matches", 0)) < NEW_PLAYER_MATCHES

## The top-right counters (squads left, kills, knocks, gems): not before the first kill, knock or gem.
static func counters_shown(p: Hunter, hold: bool) -> bool:
	return not new_player() or hold or (p != null and p.kills + p.knocks + p.gems > 0)

## The "Your kit" card (every ability and its words) at the start of a match: new players have the slots
## and their keys; the words are on hover. The training room keeps it.
static func kit_card_shown(m: Match) -> bool:
	return not new_player() or m.opts.get("training", false)
