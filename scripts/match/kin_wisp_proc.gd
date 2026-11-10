class_name KinWispProc
extends RefCounted
## The sound pair to the wisp's proc look: a carried Boki's on-shot passive (KinSpec carry.on_shot, put on a shot
## by Hunter._kin_riders) while it rides as a wisp makes a very short, quiet chirp from its species' own voice
## (KinVoice.cue), pitched by body size and placed on the wisp. Rivals near you hear theirs too, quieter.
## Mix level: docs/AUDIO.md "Wisp proc chirp".

const EVERY_S := 0.8       # s: at most one chirp per wisp
const OWN_DB := -20.0      # dB: your wisp, a quiet tick under the gun
const RIVAL_DB := -26.0    # dB: another hunter's wisp, before distance
const DUCK_S := 0.35       # s after its hunter's ability cast in which the chirp gives way
const DUCK_DB := -8.0      # dB: how far it gives way
const SIZE_PITCH := {"small": 1.3, "medium": 1.0, "large": 0.78}     # small bodies chirp higher

## One proc of this hunter's carried wisp. Returns the sound it played ("" when it stayed quiet).
static func proc(h: Hunter) -> String:
	var k: Kin = h.kin
	if k == null or not k.wisp or k.ks == null or k.ks.carry_on_shot.is_empty() or not h.kin_carry_on():
		return ""
	var now: float = h.m.time
	if now >= k.proc_at and now - k.proc_at < EVERY_S:
		return ""
	k.proc_at = now
	var cue := KinVoice.cue(k.species, "happy")
	h.m.sfx(cue, k.pos, level_db(h), float(SIZE_PITCH.get(k.ks.size, 1.0)) * Unique.voice(k.rec))
	return cue

## How loud this hunter's chirp is: yours over a rival's, and under any ability it just cast.
static func level_db(h: Hunter) -> float:
	var db := OWN_DB if h == h.m.player else RIVAL_DB
	return db + (DUCK_DB if h.m.time - h.cast_at < DUCK_S else 0.0)
