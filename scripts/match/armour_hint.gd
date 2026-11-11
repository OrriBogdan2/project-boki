class_name ArmourHint
extends RefCounted
## The one first-time hint about armour: hitting other Hunters is what upgrades it. It shows once per
## save (Match._tip keeps the flag in Save.d["tutorial"], an open dictionary, so old saves just lack
## it), never in the tutorial match, and makes the armour badge on the portrait pop.

const FLAG := "armour_hint"
const TIER_UP := "Hitting other Hunters upgrades your armour."
const HIT := "Hits on Hunters upgrade your armour."

## The player's armour just went up a tier.
static func tier_up(m: Match) -> void:
	_say(m, TIER_UP)

## The player hit a rival Hunter; `xp_before` is their level XP before the hit counted. A hit that
## earned no level XP is the one place a player would not guess where the armour comes from.
static func hit(m: Match, p: Hunter, xp_before: float) -> void:
	if p.xp == xp_before:
		_say(m, HIT)

static func _say(m: Match, text: String) -> void:
	if m.hud == null or m.opts.get("tutorial", false) or not Settings.get_v("tips"):
		return
	m._tip(FLAG, text)
	ArmorHud.pop(m.hud)
