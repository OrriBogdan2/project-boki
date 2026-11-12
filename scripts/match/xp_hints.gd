class_name XpHints
extends RefCounted
## The plain XP lines, each shown once per save through Match._tip (the first-time tips): the first
## monster kill that pays your squad, the first time a rival's last hit takes a kill your squad was
## fighting, and the first time a squadmate's kill pays the squad while you stood too far to share.
## Monsters pay XP to the squad of whoever lands the last hit (KillXp).

const KILL_KEY := "xp_kill"
const STEAL_KEY := "xp_steal"
const SHARE_KEY := "xp_share"
const KILL_TEXT := "Monsters give XP to whoever lands the last hit, and to teammates nearby."
const STEAL_TEXT := "They landed the last hit, so they took the XP. Finish your fights."
const SHARE_TEXT := "Stay near your squad: kill XP is shared within 30 m."    # 30 = KillXp.SHARE_R
const STEAL_WINDOW := 10.0      # s: your squad hit the monster this recently, so the kill was yours to lose

## Called from Match.on_mob_dead: `credit` is the hunter whose hit (or whose Boki's hit) finished it.
static func on_mob_dead(m: Match, mb: Mob, credit: Ent, o: Dictionary) -> void:
	if m.player == null or not m.tips_live or o.get("self", false) or not credit is Hunter:
		return
	var team: int = m.player.team
	if credit.team == team:
		if credit != m.player and m.player.flat_dist(mb) > KillXp.SHARE_R:
			m._tip(SHARE_KEY, SHARE_TEXT)
		else:
			m._tip(KILL_KEY, KILL_TEXT)
	elif m.time - float(mb.team_hit.get(team, -1e9)) <= STEAL_WINDOW:
		m._tip(STEAL_KEY, STEAL_TEXT)

## v13 -> v14: the three flags exist in every save, unseen (an old save sees each line once).
static func migrate(data: Dictionary) -> void:
	var seen: Dictionary = data.get("tutorial", {})
	seen[KILL_KEY] = bool(seen.get(KILL_KEY, false))
	seen[STEAL_KEY] = bool(seen.get(STEAL_KEY, false))
	seen[SHARE_KEY] = bool(seen.get(SHARE_KEY, false))
	data["tutorial"] = seen
