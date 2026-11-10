class_name HeartSfx
extends RefCounted
## The Heart loop's sounds (tools/gen_sfx_heart.py, content/sfx/heart.json). It watches the Heart's state each
## tick and cues what changed, so the host and a client (whose state arrives by "ht" events) hear the same:
##   charging   heart_charge  a rising hum at the Heart, pitch up with the charge (carries 70 m)
##   taken      heart_take    the taker's sting; heart_reveal for everyone else (map-wide); the gate wakes
##   carried    heart_beat    the carrier's own heartbeat loop
##   delivered  heart_extract at the gate
## Held loops use Sfx.loop_hold, so they end on their own when the match stops ticking.

const CHARGE_KEY := "heart_charge"
const BEAT_KEY := "heart_beat"
const HUM_PITCH := Vector2(0.7, 1.6)   # playback speed of the charge hum at 0 % and 100 % charged
const HUM_DB := -4.0
const BEAT_DB := -3.0
const GATE_DB := 0.0

var cues: Array = []                   # every one-shot cue in order, for the check
var _h: Heart
var _state := ""

func _init(heart: Heart) -> void:
	_h = heart

func update() -> void:
	var m := _h.m
	if _h.state != _state:
		if _state != "":
			_on_change(_h.state)
		_state = _h.state
	if _state == "charging":
		var f := clampf(_h.charge / maxf(Heart.r("charge_s"), 0.01), 0.0, 1.0)
		Sfx.loop_hold(CHARGE_KEY, "heart_charge", _h.site, HUM_DB, lerpf(HUM_PITCH.x, HUM_PITCH.y, f))
	if _state == "carried" and _h.carrier == m.player:
		Sfx.loop_hold(BEAT_KEY, "heart_beat", null, BEAT_DB)

func _on_change(to: String) -> void:
	if to == "carried":
		_cue("heart_take" if _h.carrier == _h.m.player else "heart_reveal", null, 0.0)
		_cue("heart_gate_open", _h.gate, GATE_DB)
	elif to == "cooling":
		_cue("heart_extract", _h.gate, GATE_DB)

func _cue(sname: String, at, vol: float) -> void:
	cues.append(sname)
	_h.m.sfx(sname, at, vol)
