class_name LevelGrowth
extends RefCounted
## Quiet growth: every level a hunter reaches makes them a little tougher (max health) and their
## abilities a little stronger (ability power), with no banner. Levels 2-6 grow at the full rate,
## levels 7-10 at half (content/rules/level_growth.json). The level badge flashes and its tooltip
## shows the totals (LevelGrowth.tip). Weapon growth is separate: WeaponPath on even levels.
##
##   LevelGrowth.hp_pct(lvl) / ap_pct(lvl)   the total share gained by that level (0 at level 1)
##   LevelGrowth.apply(h)                    brings a hunter's max health up to their level's growth
##   LevelGrowth.ap(h)                       the ability power multiplier (1.0 at level 1)
##   LevelGrowth.xp(k)                       an XP gain from the file's "xp" block (docs/LEVEL_PACE.md)

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/level_growth.json"))
		_rules = d if d is Dictionary else {}
	return _rules

## How much XP one source gives (k: a key of the "xp" block, e.g. "knock").
static func xp(k: String) -> float:
	return float((rules().get("xp", {}) as Dictionary).get(k, 0.0))

## The rate a single level adds (k = "hp" or "ap"): full up to level 6, half from level 7.
static func step(k: String, lvl: int) -> float:
	if lvl < 2:
		return 0.0
	var r := float(rules().get(k, 0.0))
	return r * float(rules().get("half_k", 0.5)) if lvl >= int(rules().get("half_from", 7)) else r

static func _total(k: String, lvl: int) -> float:
	var t := 0.0
	for l in range(2, lvl + 1):
		t += step(k, l)
	return t

static func hp_pct(lvl: int) -> float:
	return _total("hp", lvl)

static func ap_pct(lvl: int) -> float:
	return _total("ap", lvl)

## Ability power from the levels a hunter has actually gained (apply() records them): a level set
## straight on the hunter (practice, tests) grows nothing, the same as its health.
static func ap(h) -> float:
	return 1.0 + ap_pct(int(h.get_meta("growth_lvl", 1))) if h is Hunter else 1.0

## Max health from levels, kept on the hunter as "growth_hp" so it never stacks; the new health is
## added to the bar too (levelling up never costs you health).
static func apply(h) -> void:
	h.set_meta("growth_lvl", int(h.lvl))
	var want := float(h.cdat.get("hp", 0.0)) * hp_pct(int(h.lvl))
	var had := float(h.get_meta("growth_hp", 0.0))
	if absf(want - had) < 0.01:
		return
	h.max_hp += want - had
	h.hp = clampf(h.hp + maxf(0.0, want - had), 1.0, h.max_hp)
	h.set_meta("growth_hp", want)

## A class change resets max health: forget the growth so apply() adds it again.
static func reset(h) -> void:
	if not h.has_meta("growth_lvl"):
		return
	h.set_meta("growth_hp", 0.0)
	var want := float(h.cdat.get("hp", 0.0)) * hp_pct(int(h.get_meta("growth_lvl")))
	h.max_hp += want
	h.hp += want
	h.set_meta("growth_hp", want)

## The level badge tooltip line: what your levels have added so far.
static func tip(h) -> String:
	var l := int(h.get_meta("growth_lvl", 1))
	if l < 2:
		var hp_gain := roundi(step("hp", 2) * 100.0)
		var ap_pct := roundi(step("ap", 2) * 100.0)
		var half_from := int(rules().get("half_from", 7))
		return "Each level: +%d%% max health, +%d%% ability power (half from level %d)" % [hp_gain, ap_pct, half_from]
	return "From levels: +%d%% max health, +%d%% ability power" % [roundi(hp_pct(l) * 100.0), roundi(ap_pct(l) * 100.0)]
