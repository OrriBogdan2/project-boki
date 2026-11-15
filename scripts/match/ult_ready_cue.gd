class_name UltReadyCue
extends RefCounted
## The chime that tells you your ultimate (R, HeroUlt) is back, so you don't have to watch its icon. Only
## for your own hunter: a rival's or a teammate's ultimate coming back stays silent. A match that starts
## with R ready says nothing; R coming back while you're down waits until you're up (and still ready).
## A UI cue ("ui" level, docs/AUDIO.md), set a little further down if a knock or kill callout just played.
## Settings > Audio > Sounds turns it off (ult_ready_cue). Match.step ticks it.

const SOUND := "ui_ult_ready"
const VOL_DB := -3.0            # dB: under the knock and kill callouts, about the "Ability ready again" cue's level
const UNDER_CALLOUT_DB := -6.0  # dB more while a combat callout is still sounding
const CALLOUT_MS := 700         # ms: how long after a knock_confirm or kill the chime stays ducked
const CALLOUTS := ["knock_confirm", "kill"]

var plays := 0                  # chimes played this match (--match-audio-check reads it)
var _was_ready := true          # true at the start, so a match that opens with R ready stays quiet
var _owed := false              # R came back while you couldn't hear it yet (down or out)

## Watches your hunter's R once per step and plays the chime the step it comes back (or once you're up).
func tick(m: Match) -> void:
	var p: Hunter = m.player
	if p == null or p.ak == null:
		return
	var is_ready := HeroUlt.ready(p.ak)
	if is_ready and not _was_ready:
		_owed = true
	_was_ready = is_ready
	if not is_ready:
		_owed = false
	elif _owed and not p.downed and not p.out:
		_owed = false
		_play()

func _play() -> void:
	if not bool(Settings.get_v("ult_ready_cue")):
		return
	plays += 1
	Sfx.play(SOUND, null, VOL_DB + (UNDER_CALLOUT_DB if _callout_sounding() else 0.0), 0.0)

func _callout_sounding() -> bool:
	var now := Time.get_ticks_msec()
	for sound in CALLOUTS:
		if now - int(Sfx.last_played.get(sound, -CALLOUT_MS)) < CALLOUT_MS:
			return true
	return false
