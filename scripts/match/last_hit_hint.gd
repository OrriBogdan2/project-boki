class_name LastHitHint
extends RefCounted
## The two first-time hints about kill XP (DECISIONS 2026-11-10: a monster's XP goes to the squad
## that lands the last hit, KillXp). The first kill by the player's squad says who gets paid (or, when a
## squadmate's kill paid the player nothing for standing too far, that XP is shared nearby); the
## first monster the player hurt that a rival squad finished says why they got nothing. Each shows
## once per save on the usual hint card (Match._tip; the flags sit in Save.d["tutorial"], an open
## dictionary, so old saves just lack them); never in the tutorial match or with tips off.

const KILL_FLAG := "last_hit_xp"
const KILL_TEXT := "Last hit on a monster gives XP to you and teammates nearby."
const STOLEN_FLAG := "last_hit_stolen"
const STOLEN_TEXT := "They landed the last hit, so they got its XP."
const SHARE_FLAG := "xp_share"
const SHARE_TEXT := "Stay near your squad: kill XP is shared within %d m."  # KillXp.SHARE_R


## `mb` died to `by` (a Hunter, or a Boki whose owner gets the credit). Runs on the host
## (Match.on_mob_dead) and on each client (the "mobdead" event), so every player gets their hints.
static func kill(m: Match, mb: Mob, by: Ent) -> void:
	var killer: Hunter = by.owner_h if by is Kin else by as Hunter
	if killer == null or m.player == null or m.opts.get("tutorial", false) or not Settings.get_v("tips"):
		return
	if killer.team == m.player.team:
		if killer != m.player and m.player.flat_dist(mb) > KillXp.SHARE_R:  # (a squadmate's kill paid you nothing)
			m._tip(SHARE_FLAG, SHARE_TEXT % int(KillXp.SHARE_R))
		else:
			m._tip(KILL_FLAG, KILL_TEXT)
	elif mb.player_hurt:
		m._tip(STOLEN_FLAG, STOLEN_TEXT)
