class_name KinWispProc
extends RefCounted
## The sound pair to the wisp's proc look (WispProc): each cue a carried Boki's always-on passive gives (a heal,
## a shield soak, a damage bonus, a run boost) also makes one very short, quiet chirp from that species' own voice
## (KinVoice.cue), pitched by body size and placed on the wisp. A rival's wisp chirps too, quieter, and only
## within the sound's reach (Sfx distance falloff). Mix level: docs/AUDIO.md "Wisp proc chirp".

const EVERY_S := 0.8       # s: at most one chirp per wisp (the look may cue every 0.5 s)
const OWN_DB := -20.0      # dB: your wisp, a quiet tick under the gun
const RIVAL_DB := -26.0    # dB: another hunter's wisp, before distance
const DUCK_S := 0.35       # s after its hunter's ability cast in which the chirp gives way
const DUCK_DB := -8.0      # dB: how far it gives way
const SIZE_PITCH := {"small": 1.3, "medium": 1.0, "large": 0.78}     # small bodies chirp higher

static var played := 0     # chirps played this run (the check counts them)
static var last_cue := ""

## One proc cue of this wisp (WispProc._play calls it). Returns the sound it played ("" when it stayed quiet).
static func chirp(k: Kin) -> String:
	var h: Hunter = k.owner_h
	if h == null or not k.wisp or k.ks == null:
		return ""
	var now: float = k.m.time
	if now >= k.proc_at and now - k.proc_at < EVERY_S:
		return ""
	k.proc_at = now
	var cue := KinVoice.cue(k.species, "happy")
	k.m.sfx(cue, k.global_position, level_db(h), pitch(k))
	played += 1
	last_cue = cue
	return cue

static func pitch(k: Kin) -> float:
	return float(SIZE_PITCH.get(k.ks.size, 1.0)) * Unique.voice(k.rec)

## How loud this hunter's chirp is: yours over a rival's, and under any ability it just cast.
static func level_db(h: Hunter) -> float:
	var db := OWN_DB if h == h.m.player else RIVAL_DB
	return db + (DUCK_DB if h.m.time - h.cast_at < DUCK_S else 0.0)
