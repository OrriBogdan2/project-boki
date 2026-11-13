class_name XpRules
extends RefCounted
## Who earns level XP and how much (content/rules/xp.json, docs/decisions/0048-camps-and-xp.md).
## XP is a kill reward: a monster's kill and a knock pay the killer's squad within share_r of the
## killer, in full to each. Each game pays only the Hunters it owns (levels sync from their owner).
##
## Public API:
##   XpRules.pay_squad(m, by, xp)   pays xp to the killer (a Boki's kill is its Hunter's) and squad in range
##   XpRules.knock_xp(victim) -> float   what knocking this Hunter pays
##   XpRules.kill_xp(mb) -> float   what killing this monster pays (0 for a lair boss: Lairs pays it)

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

static func knock_xp(victim: Hunter) -> float:
	var k: Dictionary = rules()["knock"]
	return float(k["base"]) + float(k["per_level"]) * victim.lvl

static func kill_xp(mb: Mob) -> float:
	if mb is Boss:
		return 0.0
	if mb.has_meta("camp"):
		var kind := "chief" if mb.has_meta("chief") else mb.mkind
		return float(rules()["camp_mob"].get(kind, rules()["stray"]))
	return float(rules()["stray"])
