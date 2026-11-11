class_name HazardHint
extends RefCounted
## The first-time hint about each kind of terrain hazard (TerrainHazards): the first time the player
## nears one, one HUD line says what it does and, if their lead Boki walks it
## safely, that they can cross (the second Boki is retired and swap_kin has no key, so only the lead
## counts; perks and items grant no immunity yet).
## Once per kind per save (Match._tip keeps the flag in Save.d["tutorial"]), never in the tutorial
## match, quiet with tips off.

const FLAG := "hazard_"
const LEAD := "%s keeps you safe: cross it."

## Says the line for `kind` if the player has not seen it. Returns whether it showed.
static func say(m: Match, tz: TerrainHazards, kind: String) -> bool:
	var seen: Dictionary = Save.d["tutorial"]
	if m.hud == null or m.opts.get("tutorial", false) or not Settings.get_v("tips") or seen.get(FLAG + kind, false):
		return false
	var line := String(TerrainHazards.kind_def(kind)["tip"])
	var lead := m.player.kin as Kin
	if lead != null and TerrainHazards.kin_guards(lead, kind):
		line += " " + LEAD % _name(lead)
	m._tip(FLAG + kind, line)
	return true

static func _name(k: Kin) -> String:
	return String(k.rec.get("name", k.sp.get("name", "Your Boki")))
