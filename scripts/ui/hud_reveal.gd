class_name HudReveal
extends RefCounted
## What a new player's match HUD holds back until it matters (docs/HUD.md "First real match"). In a real Extraction
## for a save under HudGroups.NEW_PLAYER_MATCHES expeditions, the weapon card (with the belt row above it) waits for
## the first shot, hit taken or pickup, and the squads/players-left counters wait for the first fight or Tab. Each
## test reads a count that only goes up, so a block that has appeared stays for the match. Everyone else (veterans,
## the tutorial, training, duels, the arena) sees the whole HUD as before. Draws nothing.

static func newcomer(m: Match) -> bool:
	if not HudGroups.new_player():
		return false
	for skip in ["tutorial", "duel", "arena", "training"]:
		if m.opts.get(skip, false):
			return false
	return true

## Has the first fight started (a shot, a hit taken, a kill, knock or gem)?
static func fought(p: Hunter) -> bool:
	return p.ammo < int(p.wpn["mag"]) or p.swing_at > -9.0 or p.dmg_taken > 0.0 or p.kills + p.knocks + p.gems > 0

## The weapon card and the belt row above it.
static func weapon_shown(m: Match, p: Hunter) -> bool:
	return not newcomer(m) or fought(p) or not p.pack.is_empty()

## The squads and players left (and under them your own numbers).
static func counters_shown(m: Match) -> bool:
	return not newcomer(m) or MapDetail.holding() or fought(m.player)
