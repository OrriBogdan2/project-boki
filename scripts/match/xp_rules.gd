class_name XpRules
extends RefCounted
## Who earns level XP and how much (content/rules/xp.json, docs/decisions/0048-camps-and-xp.md).
## XP is a kill reward: a monster's kill and a knock pay the killer's squad within share_r of the
## killer, in full to each. Each game pays only the Hunters it owns (levels sync from their owner).
##
## Public API:
##   XpRules.pay_squad(m, by, xp)   pays xp to the killer (a Boki's kill is its Hunter's) and squad in range
##   XpRules.knock_xp(victim, by) -> float   what knocking this Hunter pays (by: the knocker, for the level gap)
##   XpRules.kill_xp(mb) -> float   what killing this monster pays (0 for a lair boss: Lairs pays it)
##   XpRules.paid_xp(m, mb, credit) -> float   what this kill pays credit's squad (kill_xp, comeback included)
##   XpRules.comeback_k(m, team) -> float   camp XP multiplier for a squad 2+ levels under the top squad
##   XpRules.pace_level(t) -> int   the level a squad that plays camps and objectives well has at match second t

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/xp.json"))
		_rules = d if d is Dictionary else {}
	return _rules

## Pays the killer and each squadmate (alive or downed) within share_r of the killer.
static func pay_squad(m, by, xp: float) -> void:
	var h = by.owner_h if by is Kin else by
	if not (h is Hunter) or xp <= 0.0:
		return
	var r := float(rules()["share_r"])
	for o: Hunter in m.hunters:
		if o.team == h.team and not o.remote and not o.out and not o.extracted and o.flat_dist(h.pos) <= r:
			o.gain_xp(xp)

## Comeback XP (decision 0048, spec 6.5): a squad whose average run level is comeback.gap or more
## under the top squad still in the match gets comeback.k on camp monster XP; 1.0 for everyone else.
## Only camps pay it (paid_xp, from Match.on_mob_dead): no bonus from time and none from hitting Hunters.
static func comeback_k(m, team: int) -> float:
	var sums := {}            # team -> [level sum, Hunters, any still in]
	for h: Hunter in m.hunters:
		var s: Array = sums.get(h.team, [0.0, 0, false])
		sums[h.team] = [s[0] + h.lvl, s[1] + 1, s[2] or not h.out]
	if not sums.has(team):
		return 1.0
	var top := 0.0
	for t in sums:
		if sums[t][2]: top = maxf(top, sums[t][0] / sums[t][1])
	var c: Dictionary = rules()["comeback"]
	return float(c["k"]) if top - sums[team][0] / sums[team][1] >= float(c["gap"]) else 1.0

static func pace_level(t: float) -> int:
	var lv := 0
	for from_s in rules()["pace_at_s"]:
		if t >= float(from_s):
			lv += 1
	return maxi(lv, 1)

## What knocking victim pays, bent by the gap to the knocker by (6.5): more per level the victim is
## above them, half when the victim is below_gap or more under them.
static func knock_xp(victim: Hunter, by: Hunter = null) -> float:
	var k: Dictionary = rules()["knock"]
	var xp := float(k["base"]) + float(k["per_level"]) * victim.lvl
	if by == null:
		return xp
	var gap := victim.lvl - by.lvl
	if gap > 0:
		xp += float(k["per_level_above"]) * gap
	elif -gap >= int(k["below_gap"]):
		xp *= float(k["below_k"])
	return xp

## What killing mb pays credit's squad: kill_xp, times comeback_k on a camp monster; 0 unless a Hunter.
static func paid_xp(m, mb: Mob, credit) -> float:
	if not (credit is Hunter):
		return 0.0
	return kill_xp(mb) * (comeback_k(m, credit.team) if Camps.is_camp(mb) else 1.0)

static func kill_xp(mb: Mob) -> float:
	if mb is Boss:
		return 0.0
	if mb.has_meta("camp"):
		var kind := "chief" if mb.has_meta("chief") else mb.mkind
		return float(rules()["camp_mob"].get(kind, rules()["stray"]))
	return float(rules()["stray"])
