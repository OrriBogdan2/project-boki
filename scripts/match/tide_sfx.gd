class_name TideSfx
extends RefCounted
## The Blight tide's sounds (tools/gen_sfx_tide.py, content/sfx/tide.json): the wall closing on the Heart is
## heard before it is seen, because it decides who gets out. HeartSfx.update calls update every tick, so the
## host and a client (the tide is a function of match time) hear the same:
##   onset   tide_onset   the tide starts (stage -1 to 0): a rising swell, flat, with the score ducked under it
##   front   tide_rumble  a held loop placed on the wall's nearest point to you; Sfx's distance roll-off makes it
##                        rise as the ring closes on you, and a far one plays through the muffled bus
##   close   tide_warn    a short sting as each new close stage begins (Heart.tide_stage), flat, score ducked
## Nothing sounds for a stage you joined in; the loop lapses by itself when you are out or have extracted.

const FRONT_KEY := "tide_rumble"
const ONSET_DB := -2.0
const WARN_DB := -3.0
const FRONT_DB := 0.0
const DUCK_ONSET := Vector2(3.0, -8.0)    # seconds held, dB: the score under the swell
const DUCK_WARN := Vector2(1.0, -5.0)

var cues: Array = []                      # every one-shot cue in order, for the check
var _h: Heart
var _stage := -2                          # -2 until the first tick

func _init(heart: Heart) -> void:
	_h = heart

func update() -> void:
	var m := _h.m
	var st := Heart.tide_stage(m)
	if _stage == -2:
		_stage = st
	elif st > _stage:
		_cue("tide_onset" if _stage == -1 else "tide_warn")
		_stage = st
	var p := m.player
	if st < 0 or p == null or p.out or p.extracted:
		return
	var out := Vector2(p.pos.x - _h.site.x, p.pos.z - _h.site.z)
	out = out.normalized() * Heart.tide_r(m) if out.length() > 0.01 else Vector2.RIGHT * Heart.tide_r(m)
	var wall := Vector3(_h.site.x + out.x, p.pos.y, _h.site.z + out.y)
	Sfx.loop_hold(FRONT_KEY, "tide_rumble", wall, FRONT_DB)

func _cue(cue: String) -> void:
	cues.append(cue)
	var onset := cue == "tide_onset"
	Sfx.play(cue, null, ONSET_DB if onset else WARN_DB, 0.0)
	var duck := DUCK_ONSET if onset else DUCK_WARN
	Sfx.duck(duck.x, duck.y)
