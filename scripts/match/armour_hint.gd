class_name ArmourHint
extends RefCounted
## The one first-time hint about armour (DECISIONS 2026-11-10: hits on Hunters build armour, level
## XP comes from monster kills). The first time the player's damage to a Hunter fills armour
## progress, Match._tip shows the line next to the armour readout (Hud.tip "armor" spot, drawn by
## ArmorHud.note) and the badge pops. Once per save (the flag sits in Save.d["tutorial"], an open
## dictionary, so old saves just lack it); never in the tutorial match or with tips off.

const FLAG := "armour_not_xp"
const TEXT := "Hits on Hunters build armour. XP comes from monster kills."


## `credit` dealt damage to `target` that went into armour progress.
static func hit(m: Match, credit: Ent, target: Ent) -> void:
	if credit != m.player or not target is Hunter or m.hud == null or m.opts.get("tutorial", false):
		return
	if not Settings.get_v("tips") or Save.d["tutorial"].get(FLAG, false):
		return
	m._tip(FLAG, TEXT, "armor")
	ArmorHud.pop(m.hud)
