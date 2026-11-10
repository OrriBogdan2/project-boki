class_name BokiWispCosmetics
extends RefCounted
## The Boki wisp's cosmetic line (DECISIONS 2026-11-09): a trail, a sparkle colour and an orbit style, picked
## by id from content/rules/boki_wisp_cosmetics.json and saved in Save.d["look"]["boki_wisp"]. They change
## only the sparkles and the orbit (BokiWispLook, KinWisp), never the critter outline or the sparkle count.
## Only your own Boki wear yours; other players' wisps show the defaults (nothing is synced).

const LINES := ["trail", "sparkle", "orbit"]
const PATH := "res://content/rules/boki_wisp_cosmetics.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data

## id -> entry of one line, in file order.
static func options(line: String) -> Dictionary:
	return data()[line]["options"]

static func default_id(line: String) -> String:
	return String(data()[line]["default"])

## The id this player wears on a line (the default for none or an unknown one).
static func equipped(line: String) -> String:
	var id := String(Save.d.get("look", {}).get("boki_wisp", {}).get(line, ""))
	return id if options(line).has(id) else default_id(line)

## Wear an option from now on. False for an id the line does not have.
static func equip(line: String, id: String) -> bool:
	if not options(line).has(id):
		return false
	if not Save.d.has("look"):
		Save.d["look"] = Unmasked.default_look()
	if not Save.d["look"].get("boki_wisp") is Dictionary:
		Save.d["look"]["boki_wisp"] = {}
	Save.d["look"]["boki_wisp"][line] = id
	return true

## The entries a hunter's Boki wisps wear: this player's picks for the local hunter, the defaults for anyone else.
static func worn(h: Hunter) -> Dictionary:
	var out := {}
	for line in LINES:
		var id := equipped(line) if h != null and h.is_local() else default_id(line)
		out[line] = options(line)[id]
	return out

## The sparkle colour of a worn set, given the Boki's glow colour.
static func sparkle_colour(worn_set: Dictionary, glow: Color, lighten: float) -> Color:
	var spec := String(worn_set["sparkle"]["color"])
	return glow.lightened(lighten) if spec == "own" else Color(spec)

## v11 -> v12: a save with a look gets the picks (the defaults), so the field is there from now on.
static func migrate(save: Dictionary) -> void:
	if not save.get("look") is Dictionary or save["look"].get("boki_wisp") is Dictionary:
		return
	var picks := {}
	for line in LINES:
		picks[line] = default_id(line)
	save["look"]["boki_wisp"] = picks
