class_name ArmorXp
extends RefCounted
## Armour progress (docs/ARMOUR_PARITY.md "Progress"): the damage a Hunter deals to and takes from
## rival Hunters fills it, as in the source; monsters and Boki build none, and none of it is level XP.
## The rates and the source's thresholds live in content/rules/armor_xp.json; the thresholds are
## scaled from source damage points to ours by the two games' base health.

const RULES_PATH := "res://content/rules/armor_xp.json"
static var _r: Dictionary = _load()
## Progress needed to reach each tier, in our damage points (index = tier, Common 0).
static var thresholds: Array = _scaled()
## The chunk a knock adds, in our damage points.
static var knock: float = round(float(_r["knock_source_damage"]) * scale())

static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	assert(parsed is Dictionary, "content/rules/armor_xp.json did not parse")
	return parsed

## Our damage points per source damage point.
static func scale() -> float:
	return float(_r["our_health"]) / float(_r["source_health"])

static func _scaled() -> Array:
	var out: Array = [0.0]
	for t in _r["thresholds_source"]:
		out.append(round(float(t) * scale()))
	return out

## Progress per point of damage dealt, by what was hit.
static func rate(target: Ent) -> float:
	if target is Hunter:
		return float(_r["dealt"])
	return float(_r["boki"] if target is Kin else _r["monster"])

## Credits `d` damage from `credit` to `target` on both sides; returns the Hunters whose tier went up.
static func on_damage(credit: Ent, target: Ent, d: float) -> Array:
	var up: Array = []
	if not (credit is Hunter) or target == credit or target.team == credit.team:
		return up
	if target is Hunter:
		var t := target as Hunter
		if not t.remote and t.armor_gain(d * float(_r["taken"])) >= 0:
			up.append(t)
		if t.downed:      # finishing a downed rival builds nothing
			return up
	if not credit.remote and credit.armor_gain(d * rate(target)) >= 0:
		up.append(credit)
	return up
