class_name MoveRules
extends RefCounted
## content/rules/hunter_move.json, parsed once. It names no other game class, so reading it in a static init
## (GlideSpike's) is safe whichever script GDScript compiles first. It used to live in HunterMove, which
## mentions Hunter: when Hunter's chain reached GlideSpike before HunterMove's static init had run, GlideSpike
## read an empty dict ("Invalid access to ... 'glide_spike'") and every check that boots a match came back red.

static var _data: Dictionary = _load()

static func data() -> Dictionary:
	return _data

static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/hunter_move.json"))
	assert(parsed is Dictionary, "content/rules/hunter_move.json did not parse")
	return parsed
