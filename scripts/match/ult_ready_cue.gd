class_name UltReadyCue
extends RefCounted
## The chime that tells you your ultimate (R, HeroUlt) is back, so you don't have to watch its icon. Only
## for your own hunter: a rival's or a teammate's ultimate coming back stays silent. A match that starts
## with R ready says nothing; R coming back while you're down waits until you're up (and still ready).
## A UI cue ("ui" level, docs/AUDIO.md), set a little further down if a knock or kill callout just played.
## Settings > Audio > Sounds turns it off (ult_ready_cue). Match.step ticks it.
## Your E coming back gets its own quieter tick (ready_e, a higher note): only once you're up, and an E that came
## back while you were down or in your first MUTE_BACK seconds back stays quiet. The E tick and the R chime are
## never within GAP of each other: the later one waits (R first when both are due).

const SOUND := "ui_ult_ready"
const VOL_DB := -3.0            # dB: under the knock and kill callouts, about the "Ability ready again" cue's level
const UNDER_CALLOUT_DB := -6.0  # dB more while a combat callout is still sounding
const CALLOUT_MS := 700         # ms: how long after a knock_confirm or kill the chime stays ducked
const CALLOUTS := ["knock_confirm", "kill"]
const E_SOUND := "ready_e"
const E_VOL_DB := -7.0          # dB: under the R chime, a tap rather than a chime
const GAP := 0.3                # s: at least this between two cues
const MUTE_BACK := 1.0          # s: an E back in your first second up again (a respawn, a revive) stays quiet

var plays := 0                  # chimes played this match (--match-audio-check reads it)
var e_plays := 0                # E ticks played this match
var _was_ready := true          # true at the start, so a match that opens with R ready stays quiet
var _owed := false              # R came back while you couldn't hear it yet (down or out)
var _e_was := true              # as _was_ready, for E
var _e_owed := false            # E is back and not yet ticked
var _cue_at := -9.0             # match time of the last cue (GAP)
var _e_at := -9.0               # match time of the last E tick
var _up_at := -9.0              # match time you were last up again after being down or out
var _was_up := true

## Watches your hunter's R once per step and plays the chime the step it comes back (or once you're up).
func tick(m: Match) -> void:
	var p: Hunter = m.player
	if p == null or p.ak == null:
		return
	var is_ready := HeroUlt.ready(p.ak)
	if is_ready and not _was_ready:
		_owed = true
	_was_ready = is_ready
	var up := not p.downed and not p.out
	if up and not _was_up:
		_up_at = m.time
	_was_up = up
	if not is_ready:
		_owed = false
	elif _owed and up and m.time - _e_at >= GAP:
		_owed = false
		_cue_at = m.time
		_play()
		return
	_tick_e(m, p, up, m.time - _cue_at >= GAP)

## E: owed the step it comes back while you're up (and past MUTE_BACK), ticked once the GAP allows.
func _tick_e(m: Match, p: Hunter, up: bool, spaced: bool) -> void:
	var e_ready := not p.ak.e_def().is_empty() and float(p.ak.cd.get("e", 0.0)) <= 0.0
	if e_ready and not _e_was:
		_e_owed = up and m.time - _up_at >= MUTE_BACK
	_e_was = e_ready
	if not e_ready or not up:
		_e_owed = false
	elif _e_owed and spaced:
		_e_owed = false
		_cue_at = m.time
		_e_at = m.time
		e_plays += 1
		Sfx.play(E_SOUND, null, E_VOL_DB, 0.0)

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
