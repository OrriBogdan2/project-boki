class_name ReadyCues
extends RefCounted
## The quiet "it's back" cues for the local player's key tools: the ultimate (R), the Boki's ability
## and a dash charge once all were spent. HudSlot.ab_slot calls watch() every time a slot is drawn, so
## one hook serves every hero and only the owner's own bar ever reaches it (a teammate's or enemy's
## cooldown has no slot here). Silent in the first seconds of a match and while down; each cue also
## goes out as CombatBus.ready_cue.

const CUE_OF := {"x": "ready_ult", "kin_ab": "ready_boki", "dash": "ready_dash"}   # slot id -> sound
const QUIET_DB := -8.0          # dB: well under the ui level, so a cue never covers the combat music
const MUTE_START := 5.0         # s: no cues this early in a match (the drop, the opening gear-up)

static var _cooling := {}       # "<hud id>:<slot id>" -> true while that slot is on a cooldown being counted

## True when `H` is the match HUD (the farm's dash slot has no match, so it has no cues).
static func in_match(H) -> bool:
	return H.get("m") is Match

## One draw of slot `id` on host `H`: remembers a cooldown running, and plays the cue the moment it ends.
static func watch(H, id: String, ready: bool, cd_secs: float) -> void:
	if not CUE_OF.has(id) or not in_match(H):
		return
	var key := "%d:%s" % [H.get_instance_id(), id]
	if not ready:
		if cd_secs > 0.0:
			_cooling[key] = true
		return
	if not _cooling.erase(key):
		return
	var p: Hunter = H.m.player
	if p == null or not p.is_local() or p.downed or p.out or float(H.m.time) < MUTE_START:
		return
	Sfx.play(String(CUE_OF[id]), null, QUIET_DB, 0.0)
	CombatBus.ready_cue.emit(p, String(CUE_OF[id]))
