class_name KillSteal
extends RefCounted
## A stolen kill is announced (decision 0048: XP and kill bonuses follow the last hit). When a rival
## squad dealt over STEAL_SHARE of a monster's health and someone else lands the last hit, and the
## monster carries a kill bonus (a lair boss, a Boon monster from xp.json, a Camp Chief), the feed
## names the stealer and the robbed squad gets a toast. The rewards already follow the last hit
## (XpRules, HuntBoon, Lairs, Camps); this only makes the steal visible. The host decides from
## Mob.damage_by, and the "mobdead" event carries the robbed team so every game shows the line.
##
## Public API:
##   KillSteal.robbed(mb, by) -> int     the squad that lost the kill to `by` (-1: not a steal)
##   KillSteal.callout(m, mb, by, team)  the feed line and the robbed squad's toast

const STEAL_SHARE := 0.5      # share of max hp a rival squad must have dealt for the kill to count as stolen
const COL := Color("ff9a4a")  # the robbed squad's toast


static func robbed(mb: Mob, by) -> int:
	var h = by.owner_h if by is Kin else by
	if not (h is Hunter) or not _has_bonus(mb):
		return -1
	for t in mb.damage_by:
		if int(t) != h.team and float(mb.damage_by[t]) > mb.max_hp * STEAL_SHARE:
			return int(t)
	return -1


static func callout(m, mb: Mob, by, team: int) -> void:
	var h = by.owner_h if by is Kin else by
	if team < 0 or not (h is Hunter):
		return
	var what := "the Camp Chief" if mb.has_meta("chief") else String(mb.md["name"])
	m.add_feed("%s stole %s from %s" % [h.pname, what, m.truce.squad_name(team)])
	if m.hud and m.player and m.player.team == team:
		m.hud.toast("STOLEN  ·  %s took %s" % [h.pname, what], COL)


static func _has_bonus(mb: Mob) -> bool:
	return mb is Boss or mb.has_meta("chief") or String(mb.mkind) in HuntBoon.rules()["from"]
