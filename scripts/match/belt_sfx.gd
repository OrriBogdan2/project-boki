class_name BeltSfx
extends RefCounted
## The sounds of the belt items, one row per item id in content/rules/belt_sfx.json (never by effect
## type): "start" when it is used, "loop" while it channels, "end" when the channel finishes, "cancel"
## when it is spilt. Positional at the Hunter and carried to fight range (content/sfx/belt.json "reach"),
## so a rival drinking a tonic or popping smoke is heard.

const RULES := "res://content/rules/belt_sfx.json"
const VOL_DB := -2.0           # dB at the Hunter; the files are levelled to their category

static var _items: Dictionary = {}

static func items() -> Dictionary:
	if _items.is_empty():
		_items = (JSON.parse_string(FileAccess.get_file_as_string(RULES)) as Dictionary)["items"]
	return _items

## The sound id for item `id` and kind ("start", "loop", "end", "cancel"), or "" when it has none.
static func cue(id: String, kind: String) -> String:
	return String((items().get(id, {}) as Dictionary).get(kind, ""))

static func play(h: Hunter, id: String, kind: String) -> void:
	var c := cue(id, kind)
	if c != "":
		h.m.sfx(c, h.pos, VOL_DB)

static func loop_key(h: Hunter, id: String) -> String:
	return "belt%d_%s" % [h.get_instance_id(), id]

## Called every step while a channel runs (on) or may just have been spilt: keeps the loop going, and
## when it stops without a finish (the finish stops it first) plays the cancel cue.
static func channel(h: Hunter, id: String, on: bool) -> void:
	var key := loop_key(h, id)
	if on:
		Sfx.loop_hold(key, cue(id, "loop"), h.pos, VOL_DB)
	elif Sfx.loop_on(key):
		Sfx.loop_stop(key)
		play(h, id, "cancel")
