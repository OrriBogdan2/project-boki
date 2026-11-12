class_name BokiLifeSfx
extends RefCounted
## A Boki's own sounds for the moments of its life (docs/AUDIO.md): a munch as it eats, a sleepy breath as it
## dozes off, its cry as it leaps into a Fusion and as it goes down. Each plays through Sfx at the Boki, so the
## takes rotate (never the same take twice running), pitched by the Boki's voice roll. Home plays them softer
## than a match, and a Boki voices one cue at a time: a cue that comes while its last one still sounds is dropped.

const CUES := {"eat": "boki_eat", "nap": "boki_sleep", "fuse": "boki_fuse", "down": "boki_downed"}
const MATCH_DB := -4.0       # dB: the level of a Boki's other calls in a fight (kin_happy, recall)
const HOME_DB := -10.0       # dB: the garden is quiet and full of Boki, so meals and naps stay soft
const PITCH_VAR := 0.07      # the usual random pitch spread (Match.sfx), on top of the Boki's own voice

static var heard := {}       # event -> times its cue started, for the checks
static var _until := {}      # Boki key -> Time.get_ticks_msec() when its last cue stops sounding

## `event` (a CUES key) happens to a Boki in a match, yours or another player's.
static func in_match(k: Kin, event: String) -> void:
	_play(str(k.get_instance_id()), k.rec, event, k.pos, MATCH_DB)

## `event` (a CUES key) happens to a Boki at home (an entry of Home.kins).
static func at_home(k: Dictionary, event: String) -> void:
	var rec: Dictionary = k["rec"]
	_play(String(rec["uid"]), rec, event, k["pos"], HOME_DB)

static func _play(who: String, rec: Dictionary, event: String, pos: Vector3, vol_db: float) -> void:
	var sname: String = CUES[event]
	var now := Time.get_ticks_msec()
	if now < int(_until.get(who, 0)) or not Sfx.ensure(sname):
		return
	var pitch := Unique.voice(rec)
	_until[who] = now + int(1000.0 * _length_s(sname) / pitch)
	heard[event] = int(heard.get(event, 0)) + 1
	Sfx.play(sname, pos, vol_db, PITCH_VAR, pitch)

## Seconds a cue lasts at pitch 1 (the takes of one cue are made the same length, tools/gen_sfx_boki.py).
static func _length_s(sname: String) -> float:
	var st: Variant = Sfx.streams[sname]
	return ((st[0] if st is Array else st) as AudioStream).get_length()
