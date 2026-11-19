class_name KinAck
extends RefCounted
## A Boki answers a command in its own voice (docs/AUDIO.md): one species cry per send, recall or wheel order,
## so the command is heard even with the Boki off-screen. Only its owner hears it (always, at full level), and
## teammates close enough to be in earshot. A Boki answers at most once per GAP_S, so a spammed key stays quiet.
## The cry is the species' own mood voice (KinVoice) at the Boki's own pitch: no new sound family.

const GAP_S := 1.2           # s of match time before the same Boki answers another command
const VOL_DB := -8.0         # dB: under the command's own whoosh

## The mood each command answers with: an eager call for a send, a chase or a guard, a glad one for coming home.
const MOODS := {
	"send": "alert", "chase": "alert", "guard": "alert",
	"recall": "happy", "return": "happy", "follow": "happy",
}

## The cry for `cmd` ("send", "recall" or a wheel order id). True if it sounded.
static func say(k: Kin, cmd: String) -> bool:
	var me: Hunter = k.m.player
	if me == null or k.owner_h == null or k.m.time < k.ack_at:
		return false
	var cue := KinVoice.cue(k.species, String(MOODS[cmd]))
	var pitch := Unique.voice(k.rec)
	if k.owner_h == me:
		k.m.sfx(cue, null, VOL_DB, pitch, true)
	elif k.team == me.team and Vector2(k.pos.x - Sfx.listener.x, k.pos.z - Sfx.listener.z).length() <= Sfx.hear_range:
		k.m.sfx(cue, k.pos, VOL_DB, pitch)
	else:
		return false
	k.ack_at = k.m.time + GAP_S
	return true
