class_name DropData
extends RefCounted
## content/rules/drop.json: the opening drop's numbers. A leaf class, so the drop's classes can read it in
## their static setup whatever order they load in.

static var rules: Dictionary = _load()

static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/drop.json"))
	assert(parsed is Dictionary, "content/rules/drop.json did not parse")
	return parsed
