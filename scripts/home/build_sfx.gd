class_name BuildSfx
extends RefCounted
## The build and decorate cues (docs/AUDIO.md), shared by the farm's build mode (HomeBuild) and the house's
## decorating (Decorate): pick up, rotate, place (a thunk by material), move, store and blocked. They are soft
## UI sounds (category "ui", content/sfx/build.json), played non-positionally.

const RULES := "res://content/rules/build_sfx.json"

## While true the cues for picking up, placing, moving and storing stay silent, so a turn or a store done as
## "pick it up, then put it down" makes only its own sound. Rotate and blocked always play.
static var quiet := false
static var _rules := {}
static var _knock_spot := ""
static var _knock_ms := -100000

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	return _rules

static func _cue(sname: String) -> void:
	Sfx.play(sname, null, float(rules()["cue_db"]))

static func picked() -> void:
	if not quiet:
		_cue("build_pick")

static func rotated() -> void:
	_cue("build_rotate")

static func stored() -> void:
	if not quiet:
		_cue("build_store")

## The cue name for putting piece id down: a moved piece is set down softly, a new one thunks by its material.
static func placed_name(id: String, moved: bool) -> String:
	if moved:
		return "build_move"
	return "build_place_" + ("stone" if (rules()["stone"] as Array).has(id) else "wood")

static func placed(id: String, moved: bool) -> void:
	if not quiet:
		_cue(placed_name(id, moved))

## A dull knock for an attempt that can't be done. spot names where the ghost sits (cell and turn): trying again
## there within knock_quiet_s stays silent, so a held key or a drummed click doesn't repeat it.
static func blocked(spot: String) -> void:
	var now := Time.get_ticks_msec()
	if spot == _knock_spot and now - _knock_ms < int(float(rules()["knock_quiet_s"]) * 1000.0):
		return
	_knock_spot = spot
	_knock_ms = now
	_cue("build_blocked")
