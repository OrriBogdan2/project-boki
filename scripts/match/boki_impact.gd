class_name BokiImpact
extends RefCounted
## The impact sound of a Boki's ability hit: one per Boki type (content/rules/boki_impact.json, docs/AUDIO.md),
## the take set of the type's cast cue (ki_<type> -> the k_<type> files). Types are labels for identity and
## colour, so an ability's code never names a sound: the hit's attacker (a Kin) gives the type, the rule the file.
## Only a Boki's k1/k2/zone hits count (not a strike or a throw, which have their own "kinhit"). A type with no
## file falls back to the shared hit sound (play returns false and the caller plays it).

static func rules() -> Dictionary:
	return Content.rules("boki_impact")

## The impact cue of a Boki type ("" when its file is missing).
static func cue_of(type: String) -> String:
	var r := rules()
	var types: Dictionary = r.get("types", {})
	var cue := String(types.get(type, types.get(r.get("default", "normal"), "")))
	return cue if cue != "" and Sfx.ensure(cue) else ""

static func is_boki_ability_hit(by: Ent, o: Dictionary) -> bool:
	return by is Kin and String(o.get("src", "")) == "kin" and String(o.get("ab", "")) in rules().get("slots", [])

## Plays the impact of a Boki ability hit at the target; false when this is not one or the file is missing (the
## caller then plays the shared sound). Voice caps are Sfx's: the impact's own gap (Sfx.IMPACT_GAP) and its stack cap.
## db: the level of this listener's case: "you" (your Boki), "taken" (a rival's Boki hits you), "other".
static func play(m: Match, by: Ent, target: Ent, o: Dictionary, crit: bool, db_case: String) -> bool:
	if not is_boki_ability_hit(by, o):
		return false
	var cue := cue_of(String((by as Kin).sp.get("type", "")))
	if cue == "":
		return false
	var r := rules()
	var db: Dictionary = r.get("db", {})
	var level := float(db.get(db_case, -10.0))
	if crit:
		level += float(db.get("crit_up", 0.0))
	m.sfx(cue, target.pos, level, float(r.get("pitch", 1.0)))
	return true
