class_name ReadyCues
extends RefCounted
## The quiet "it's back" cues for the local player's key tools, each on its own pitch: E, the ultimate (R, the
## richest), the Boki's ability and a dash charge once all were spent. HudSlot.ab_slot calls watch() every
## time a slot is drawn, so one hook serves every hero and only the owner's own bar ever reaches it (a
## teammate's or enemy's cooldown has no slot here). Silent in the first seconds of a match, while down and
## in the first second back from the dead; never two within GAP (the later one waits its turn). Each cue
## also goes out as CombatBus.ready_cue.

const CUE_OF := {"k1": "ready_e", "x": "ready_ult", "kin_ab": "ready_boki", "dash": "ready_dash"}   # slot id -> sound
const QUIET_DB := -8.0          # dB: well under the ui level, so a cue never covers the combat music
const MUTE_START := 5.0         # s: no cues this early in a match (the drop, the opening gear-up)
const MUTE_BACK := 1.0          # s: none this soon after the slots are back on screen (a respawn)
const GAP := 0.3                # s: at least this between two cues; a slot back inside it waits for a later draw

static var _cooling := {}       # "<hud id>:<slot id>" -> true while that slot is on a cooldown being counted
static var _seen := {}          # match id -> HudPanels.draws when one of these slots was last drawn
static var _back := {}          # match id -> match time they were drawn again after a redraw without them
static var _cue_at := {}        # match id -> match time of the last cue

## True when `H` is the match HUD (the farm's dash slot has no match, so it has no cues).
static func in_match(H) -> bool:
	return H.get("m") is Match

## One draw of slot `id` on host `H`: remembers a cooldown running, and plays the cue the moment it ends.
static func watch(H, id: String, ready: bool, cd_secs: float) -> void:
	if not CUE_OF.has(id) or not in_match(H):
		return
	var m: Match = H.m
	var mid := m.get_instance_id()
	# a panel redraw went by without the bar (it's hidden while you're out): whatever came back meanwhile stays quiet
	if HudPanels.draws - int(_seen.get(mid, -9)) > 1:
		_back[mid] = m.time
	_seen[mid] = HudPanels.draws
	var key := "%d:%s" % [H.get_instance_id(), id]
	if not ready:
		if cd_secs > 0.0:
			_cooling[key] = true
		return
	if not _cooling.has(key) or m.time - float(_cue_at.get(mid, -GAP)) < GAP:
		return
	_cooling.erase(key)
	var p: Hunter = m.player
	var muted := m.time < MUTE_START or m.time - float(_back[mid]) < MUTE_BACK
	if p == null or not p.is_local() or p.downed or p.out or muted:
		return
	_cue_at[mid] = m.time
	Sfx.play(String(CUE_OF[id]), null, QUIET_DB, 0.0)
	CombatBus.ready_cue.emit(p, String(CUE_OF[id]))
