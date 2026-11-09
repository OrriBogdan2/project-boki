class_name Tuning
## The shared movement and feel numbers in content/rules/tuning.json, read once.

static var _all: Dictionary = {}

## One system's numbers, e.g. Tuning.of("lace")["perfect_window_s"].
static func of(section: String) -> Dictionary:
	if _all.is_empty():
		_all = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/tuning.json"))
	return _all[section]
