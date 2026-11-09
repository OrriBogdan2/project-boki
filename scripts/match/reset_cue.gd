class_name ResetCue
extends RefCounted
## The one reset cue (content/rules/reset_cue.json): every path that hands an ability back on a condition (a
## takedown, Sable's empowered hit, Sparkle's Blowout, a Kael knock, Cinder's knock refund...) calls play() with
## its path id. Your own reset: a short bright flash on the matching HUD slot (ResetPop), a small glint on your
## body (no burst or ring: resets stay quiet in the world) and the reset sound, once even when two resets land
## in the same moment (a knock refreshes the dash and a kit slot together). A teammate's: the glint only, silent.
## A rival's: nothing. CombatBus.reset_cue tells the checks.

const RULES_PATH := "res://content/rules/reset_cue.json"
static var _rules: Dictionary = {}
static var _sound_at := -100000   # ms (Time.get_ticks_msec) when the reset sound last played

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _rules

## The HUD slots path `path` flashes ([] for a path the rules don't list).
static func slots(path: String) -> Array:
	return rules()["paths"].get(path, [])

## `h` just got an ability back by reset path `path` (a key of the rules' "paths").
static func play(h: Hunter, path: String) -> void:
	if h == null or h.m == null:
		return
	var me: Hunter = h.m.player
	if not h.is_local():
		if me != null and h.team == me.team:
			_glint(h)
		return
	_glint(h)
	var now := Time.get_ticks_msec()
	if now - _sound_at >= int(rules()["sound_gap_ms"]):
		_sound_at = now
		Sfx.play_reset_cue(Sfx.RESET_CUE_DB - (float(rules()["assist_softer_db"]) if path == "assist" else 0.0))
	if h.m.hud:
		for id in slots(path):
			h.m.hud.ability_feedback(String(id), "reset")
	CombatBus.reset_cue.emit(h, path)

## A small white-gold star on the chest for a moment (the pooled Fx.flash), riding no ring or burst.
static func _glint(h: Hunter) -> void:
	var g: Dictionary = rules()["glint"]
	if h.m.fx:
		var at := h.pos + Vector3(0, float(g["height"]), 0)
		h.m.fx.flash(at, Color(String(g["color"])), float(g["size"]), float(g["time"]))
