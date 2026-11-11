class_name HomeVoice
extends RefCounted
## The garden's Boki voices (docs/AUDIO.md): every cry, chirp, sulk, sleepy breath and munch at home goes
## through say(). A cue plays through Sfx at the Boki's position, so it fades with distance and is dropped
## beyond earshot. At most MAX_VOICES sound at once, and one Boki speaks at most once per SELF_GAP_MS.
## sulk_edge() makes a need falling to urgent a sulk; KinWants answers a want met with a chirp.

const MAX_VOICES := 3       # Boki voices sounding at once
const VOICE_MS := 1400      # ms a cue is counted as sounding (the takes are 0.5-1.4 s)
const SELF_GAP_MS := 1200   # ms before the same Boki may speak again (a feed also pets: one chirp)
const SULK_DB := -9.0       # dB: a sulk is quieter than a chirp
const URGENT_BELOW := 18.0  # need points under which a want is urgent: the moment it falls there, one sulk

static var _until: Array[int] = []        # when each sounding voice ends (ms)
static var _last := {}                    # uid -> when that Boki last spoke (ms)

## A mood ("happy", "alert", "unsure", "sleepy", "hurt") or a plain cue ("boki_eat") for a Boki's record.
## pos null is the player's own action (a pet, a feed): always in earshot.
static func say(rec: Dictionary, what: String, pos, vol_db := -8.0, pitch_var := 0.15) -> void:
	var now := Time.get_ticks_msec()
	var uid := String(rec.get("uid", ""))
	if now - int(_last.get(uid, -SELF_GAP_MS)) < SELF_GAP_MS:
		return
	if pos != null and Vector2(pos.x - Sfx.listener.x, pos.z - Sfx.listener.z).length() > Sfx.hear_range:
		return
	while not _until.is_empty() and _until[0] <= now:
		_until.pop_front()
	if _until.size() >= MAX_VOICES:
		return
	_until.append(now + VOICE_MS)
	_last[uid] = now
	var cue := what if what.begins_with("boki_") else KinVoice.cue(String(rec["species"]), what)
	Sfx.play(cue, pos, vol_db, pitch_var, Unique.voice(rec))

## Called each frame for every Boki at home with its want ("" for none): a need falling to urgent is one sulk.
static func sulk_edge(k: Dictionary, want: String) -> void:
	var urgent := want != "" and Care.need(k["rec"], want) < URGENT_BELOW
	if urgent and not k.get("sulking", false):
		say(k["rec"], "unsure", k["pos"], SULK_DB)
	k["sulking"] = urgent
