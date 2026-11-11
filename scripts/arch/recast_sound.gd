class_name RecastSound
extends RefCounted
## The recast sound language (DECISIONS 2026-11-08, two-step abilities), the same for every Hunter: the caster
## hears recast_open as a recast window opens and recast_tick TICK_LEAD before it closes. Both are UI sounds
## (no position, so only the caster hears them) pitched by slot, so two windows sound different. It reads
## ArchKit.recast_window() each step; a window whose time left jumps back up (Dolm's next hop) is a new window.

const TICK_LEAD := 0.5         # s before a window closes that the warning tick plays
const RENEW := 0.05            # s: a jump up in the time left bigger than this starts a new window
const OPEN_DB := 0.0           # dB at the call: the files already sit at the ui loudness (sfx_levels.json)
const TICK_DB := -2.0          # dB: the tick a little under the chime
## Pitch scale per slot: the root, a major third down, a minor third up and a fourth up.
const PITCH := {"e": 1.0, "x": 0.8, "dash": 1.19, "lmb": 1.335}

## The local hunter's kit, each step: the open edge and the tick. k.recast_heard keeps the last window and the plays.
static func track(k: ArchKit) -> void:
	var w := k.recast_window()
	var heard := k.recast_heard
	var slot := String(w.get("slot", ""))
	var left := float(w.get("left", 0.0))
	var was := float(heard["left"])
	if slot != "" and (slot != String(heard["slot"]) or left > was + RENEW):
		_play(heard, "recast_open", slot, OPEN_DB)
	elif slot != "" and left <= TICK_LEAD and was > TICK_LEAD:
		_play(heard, "recast_tick", slot, TICK_DB)
	heard["slot"] = slot
	heard["left"] = left

static func _play(heard: Dictionary, sname: String, slot: String, vol_db: float) -> void:
	heard[sname] = int(heard[sname]) + 1
	Sfx.play(sname, null, vol_db, 0.0, float(PITCH.get(slot, 1.0)))
