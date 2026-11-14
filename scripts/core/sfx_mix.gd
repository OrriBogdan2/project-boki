class_name SfxMix
extends RefCounted
## The audio buses, set up in one place, and the two ducks. Music, Ambience and UI go straight to the
## master; Voice (hurt and death voices, monster cries) and Boki go into SFX, so they share its glue
## compressor, room and limiter but can be levelled on their own; far sounds of any kind go through
## SFXFar (low-passed) into SFX, ones behind terrain through SFXMuffled (duller still).
## Which bus a sound plays on comes from its category in its sound set
## (content/rules/audio_mix.json). Big events (a rival's ult, the Heart opening, a steal) dip Music and
## Ambience together and let them come back over a second.

## Name -> the bus it sends to. In creation order: Godot only sends to a bus created before.
const BUSES := {"Music": "Master", "SFX": "Master", "Ambience": "Master", "SFXFar": "SFX",
	"SFXMuffled": "SFX", "Voice": "SFX", "Boki": "SFX", "UI": "Master"}
## Sounds behind terrain (Sfx.occlusion) go through SFXMuffled: a low-pass and a small gain drop.
const OCCLUDED_HZ := 700.0
const OCCLUDED_DB := -4.0
const RULES := "res://content/rules/audio_mix.json"

var rules: Dictionary
var bus_of_sound := {}           # sound name -> bus, from the sound sets' categories
var big_sounds := {}             # sound name -> true: these dip Music and Ambience (big_event)
var _host: Node                  # Sfx, which owns the tweens
var _duck_fx: AudioEffectAmplify     # Music: Sfx.duck's stage (slow-motion beats, a catch)
var _duck_tw: Tween
var _event_fx: Array[AudioEffectAmplify] = []    # Music and Ambience: the big-event stage
var _event_tw: Tween

func _init(host: Node) -> void:
	_host = host
	rules = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	for sname in rules["big_event"]["sounds"]:
		big_sounds[sname] = true
	for bn in BUSES:
		AudioServer.add_bus()
		var bi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, bn)
		AudioServer.set_bus_send(bi, BUSES[bn])
	_sfx_effects()
	_music_effects()
	var amb_fx := AudioEffectAmplify.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Ambience"), amb_fx)
	_event_fx.append(amb_fx)

## A sound set's sounds and their categories (content/sfx/<group>.json "sounds").
func learn(sounds: Dictionary) -> void:
	var by_cat: Dictionary = rules["bus_of_category"]
	for sname in sounds:
		if by_cat.has(sounds[sname]):
			bus_of_sound[sname] = by_cat[sounds[sname]]

## The bus a sound plays on: behind terrain (muffled) is SFXMuffled, far (past Sfx.FAR from the listener)
## is SFXFar, else its kind's bus.
func bus_for(sname: String, muffled: bool, far: bool) -> StringName:
	if muffled:
		return &"SFXMuffled"
	if far:
		return &"SFXFar"
	if bus_of_sound.has(sname):
		return bus_of_sound[sname]
	for pre in rules["voice_prefixes"]:
		if sname.begins_with(pre):
			return &"Voice"
	return &"SFX"

## SFX gets a soft compressor, a little room and a limiter; far sounds are low-passed on their way in;
## the master has a last safety limiter.
func _sfx_effects() -> void:
	var sfx := AudioServer.get_bus_index("SFX")
	var comp := AudioEffectCompressor.new()
	comp.threshold = -18.0
	comp.ratio = 3.0
	comp.attack_us = 8000.0
	comp.release_ms = 180.0
	AudioServer.add_bus_effect(sfx, comp)
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.35
	rv.damping = 0.75
	rv.spread = 0.6
	rv.hipass = 0.25
	rv.predelay_msec = 18.0
	rv.dry = 1.0
	rv.wet = 0.1
	AudioServer.add_bus_effect(sfx, rv)
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -2.0
	AudioServer.add_bus_effect(sfx, lim)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 1800.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFXFar"), lp)
	var muf := AudioServer.get_bus_index("SFXMuffled")
	var mlp := AudioEffectLowPassFilter.new()
	mlp.cutoff_hz = OCCLUDED_HZ
	AudioServer.add_bus_effect(muf, mlp)
	AudioServer.set_bus_volume_db(muf, OCCLUDED_DB)
	var mlim := AudioEffectHardLimiter.new()
	mlim.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, mlim)

func _music_effects() -> void:
	var music := AudioServer.get_bus_index("Music")
	# the music gives way a little whenever the action is loud (keyed off the SFX bus), so gunfire
	# and hits stay on top of a full fight score without the score having to be quiet
	var side := AudioEffectCompressor.new()
	side.sidechain = &"SFX"
	side.threshold = -26.0
	side.ratio = 2.5
	side.attack_us = 15000.0
	side.release_ms = 350.0
	AudioServer.add_bus_effect(music, side)
	_duck_fx = AudioEffectAmplify.new()
	AudioServer.add_bus_effect(music, _duck_fx)
	var event_fx := AudioEffectAmplify.new()
	AudioServer.add_bus_effect(music, event_fx)
	_event_fx.append(event_fx)
	var mlim2 := AudioEffectHardLimiter.new()
	mlim2.ceiling_db = -1.5
	AudioServer.add_bus_effect(music, mlim2)

## Softens the music for a moment, e.g. under a big slow-motion beat (eased, never a sudden drop).
func duck(seconds: float, depth_db: float) -> void:
	if _duck_tw and _duck_tw.is_valid():
		_duck_tw.kill()
	var tw := _host.create_tween()
	_duck_tw = tw
	tw.tween_property(_duck_fx, "volume_db", minf(depth_db, _duck_fx.volume_db), 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(seconds)
	tw.tween_property(_duck_fx, "volume_db", 0.0, 0.8).set_trans(Tween.TRANS_SINE)

## A big event was heard: Music and Ambience dip together and recover; a second one restarts the hold.
func big_event() -> void:
	var r: Dictionary = rules["big_event"]
	if _event_tw and _event_tw.is_valid():
		_event_tw.kill()
	var tw := _host.create_tween().set_parallel()
	_event_tw = tw
	for fx in _event_fx:
		tw.tween_property(fx, "volume_db", float(r["dip_db"]), float(r["in_s"])).set_trans(Tween.TRANS_SINE)
		tw.tween_property(fx, "volume_db", 0.0, float(r["recover_s"])).set_trans(Tween.TRANS_SINE) \
			.set_delay(float(r["in_s"]) + float(r["hold_s"]))

## The big-event dip right now on Music and Ambience, in dB (0 = none).
func event_db() -> float:
	return _event_fx[0].volume_db
