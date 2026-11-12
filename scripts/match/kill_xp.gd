class_name KillXp
extends RefCounted
## XP for a kill: the Hunter who landed the last hit (Match.on_mob_dead's credit) gets the monster's
## XP, in full, and so does each squadmate within SHARE_R of the kill. Damage alone pays nothing, so a
## squad that steals the last hit takes the XP and the squad that did the work gets none. Rewards that
## hang on the credit (a lair boss's gear, perk orbs and stat) already go to the same Hunter.

const SHARE_R := 30.0      # m from the kill within which a squadmate is paid
const XP_PER_HP := 0.35    # XP per point of the monster's health (what its damage used to pay in all)
const BOSS_XP := 260.0     # a lair boss's XP

## Pays the last hit's squad for `mb`; a kill with no Hunter behind it pays nobody. Online, the host
## pays its own and bot Hunters here and tells each remote Hunter's machine with an "xp" event.
static func pay(m: Match, mb: Mob, credit: Ent) -> void:
	var killer: Hunter = credit.owner_h if credit is Kin else credit as Hunter
	if killer == null:
		return
	var xp := BOSS_XP if mb is Boss else mb.max_hp * XP_PER_HP
	for h in m.hunters:
		if h.team != killer.team or h.out or h.extracted:
			continue
		if h != killer and h.flat_dist(mb) > SHARE_R:
			continue
		if h.remote:
			m.net_event(["xp", h.nid, xp])
		else:
			h.gain_xp(xp)

## A host's "xp" event reached this machine: pay the Hunter it names if that is the local player.
static func net_in(m: Match, x: Array) -> void:
	if m.ents_by_id.get(String(x[1]), null) == m.player:
		m.player.gain_xp(float(x[2]))
