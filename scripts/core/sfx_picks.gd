class_name SfxPicks
extends RefCounted
## The sound tester's state (Settings > Audio > Sound tester; docs/SFX_LIBRARY.md). The tester slots are the ones
## in content/rules/sfx_pack.json with "tester": true; their candidate clips ship in the itch build only, as
## audio/sfxtest/<slot>_<letter>.wav, cut from the private pack (never in git). Trying a letter swaps that slot's
## cue stream in Sfx at once, so the match plays it where the cue plays; locking it keeps it in user://sfx_picks.json
## ({slot: letter}) and shows it on the tester page, so the owner can read the letters out. Locked picks come back
## at every start. "" is the build's own sound.

const FILE := "user://sfx_picks.json"
const MANIFEST := "res://content/rules/sfx_pack.json"

static var clip := "res://audio/sfxtest/%s_%s.wav"  ## a slot's letter clip (slot, letter); a check points it elsewhere
static var list: Array = []  ## slots(), once read
static var trying := {}  ## slot -> the letter heard now
static var locked := {}  ## slot -> the letter kept in FILE
static var _shipped := {}  ## cue -> the stream the build shipped (null: none), while a clip stands in for it


## The tester slots in manifest order: {slot, label, cue, mode, pick (the build's own letter), letters (the clips
## this build has)}.
static func slots() -> Array:
	if list.is_empty():
		var doc = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		for s in (doc as Dictionary)["slots"]:
			if not s.get("tester", false):
				continue
			var letters := []
			for c in s["candidates"]:
				if ResourceLoader.exists(clip % [s["slot"], c["letter"]]):
					letters.append(String(c["letter"]))
			var entry: Dictionary = s.duplicate()
			entry.erase("candidates")
			entry["letters"] = letters
			list.append(entry)
	return list


## Whether a clip stands in for `cue` right now.
static func active(cue: String) -> bool:
	return _shipped.has(cue)


## Hear `letter` ("" = the build's own) for a slot: the cue plays it from now on.
static func choose(slot: Dictionary, letter: String) -> void:
	var cue := String(slot["cue"])
	trying[slot["slot"]] = letter
	if letter == "":
		if _shipped.has(cue):
			var own = _shipped[cue]
			if own == null:
				Sfx.streams.erase(cue)
			else:
				Sfx.streams[cue] = own
			_shipped.erase(cue)
		return
	if not _shipped.has(cue):
		_shipped[cue] = Sfx.streams.get(cue) if Sfx.ensure(cue) else null
	Sfx.streams[cue] = load(clip % [slot["slot"], letter])


## Keep what is being heard for the slot (or drop the pick when it is the build's own).
static func lock(slot: Dictionary) -> void:
	var letter := String(trying.get(slot["slot"], ""))
	if letter == "":
		locked.erase(slot["slot"])
	else:
		locked[slot["slot"]] = letter
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(locked, " "))


## Called once as Sfx starts: the picks kept earlier play again.
static func load_locked() -> void:
	if not FileAccess.file_exists(FILE):
		return
	var kept = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not kept is Dictionary:
		return
	for s in slots():
		var letter := String((kept as Dictionary).get(s["slot"], ""))
		if letter in s["letters"]:
			locked[s["slot"]] = letter
			choose(s, letter)
