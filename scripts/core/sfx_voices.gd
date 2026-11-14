class_name SfxVoices
extends RefCounted
## The pool's voice budget (content/rules/sfx_voices.json, docs/AUDIO.md): which sound is worth keeping
## when a bus is full. A bigger priority is worth more; KEEP is never stolen.

const PATH := "res://content/rules/sfx_voices.json"
const FAR_CHEAP := 0        # a far footstep or far Boki chatter: first to go
const FAR_OTHER := 1        # a far sound, or a near footstep or chatter
const NEAR_OTHER := 2       # a near sound of someone else
const KEEP := 3             # your own, a warning or a recast cue, a UI sound: never stolen

static var _rules := {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_rules = parsed if parsed is Dictionary else {}
	return _rules

## Most voices sounding at once in a lane (see lane).
static func cap(lane_name: String) -> int:
	return int((rules()["cap"] as Dictionary)[lane_name])

## The cap lane a bus is in: far ("SFXFar"), behind terrain ("SFXMuffled"), else near ("SFX": the clear SFX
## bus, the SFXWorld bus the downed muffle dulls, and the kind buses of SfxMix: Voice, Boki, UI).
static func lane(bus: String) -> String:
	return bus if bus in ["SFXFar", "SFXMuffled"] else "SFX"

## dist: metres from the listener, or -1 for a sound with no place (a UI sound).
static func priority(sname: String, dist: float, far_m: float) -> int:
	var r := rules()
	if dist < 0.0 or dist <= float(r["own_m"]) or sname in r["keep"]:
		return KEEP
	var cheap := false
	for frag in r["cheap"]:
		if sname.contains(frag):
			cheap = true
			break
	if dist > far_m:
		return FAR_CHEAP if cheap else FAR_OTHER
	return FAR_OTHER if cheap else NEAR_OTHER

## The voice to give up for a new sound of priority `prio` in a lane: the lowest priority that is not above
## the new one, then the quietest, then the oldest. -1 when every voice there matters more (the new
## sound is dropped). `prios`, `born` (start time, ms) and `voices` (Sfx.voice_all: plain and placed
## players, which share these fields) are the pool's parallel arrays.
static func victim(voices: Array, prios: PackedInt32Array, born: PackedInt64Array, lane_name: String, prio: int) -> int:
	var best := -1
	for i in voices.size():
		var p = voices[i]
		if not p.playing or lane(p.bus) != lane_name or prios[i] > prio or prios[i] >= KEEP:
			continue
		if best < 0 or _cheaper(prios[i], p.volume_db, born[i], prios[best], voices[best].volume_db, born[best]):
			best = i
	return best

static func _cheaper(pa: int, va: float, ta: int, pb: int, vb: float, tb: int) -> bool:
	if pa != pb:
		return pa < pb
	if not is_equal_approx(va, vb):
		return va < vb
	return ta < tb
