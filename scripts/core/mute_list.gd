class_name MuteList
extends RefCounted
## Who you have muted this session: their lobby chat lines, voice frames and squad pings are dropped
## for you only. Kept by player name, in memory only: nothing is sent, saved or carried to the next run.

static var _names := {}      # player name -> true

static func has(who: String) -> bool:
	return _names.has(who)

## Flips the mute on `who`; returns whether they are muted now.
static func toggle(who: String) -> bool:
	if _names.erase(who):
		return false
	_names[who] = true
	return true

static func clear() -> void:
	_names.clear()
