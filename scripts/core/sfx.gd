extends Node
## Plays the synthesized sound effects (made by tools/gen_sfx.py). Positional sounds fade with distance
## from the camera focus, and far ones are also muffled (they go through a low-passed bus), so a fight
## across the map stays soft. The buses, their effects and the ducks are in SfxMix (scripts/core/sfx_mix.gd).

const NAMES := [
	"splash",
	"swim",
	"drip",
	"smg",
	"rifle",
	"thump",
	"boom",
	"hit",
	"crit",
	"kill",
	"knock",
	"hurt",
	"dash",
	"jump",
	"land",
	"grab",
	"throw",
	"kinhit",
	"skill",
	"kin_happy",
	"kin_unsure",
	"kin_alert",
	"recall",
	"pickup",
	"catch",
	"warn",
	"portal",
	"revive",
	"click",
	"reload",
	"shield",
	"cloak",
	"heal",
	"fall",
	"plant",
	"harvest",
	"ping",
	"glide",
	"build",
	"unlock",
	"whoosh",
	"step0",
	"step1",
	"step2",
	"hover",
	"zap",
	"bond",
	"ult",
	"combo",
	"swap",
	"horn",
	"rail",
	"train_hit",
	"revive_hum",
	"revive_done",
	"scan_pop",
	"wisp_hum",
	"swipe",
	"cleave",
	"charge",
	"k_normal",
	"k_fire",
	"k_water",
	"k_grass",
	"k_spore",
	"k_electric",
	"k_ice",
	"k_rock",
	"k_psychic",
	"k_flying",
	"k_dragon",
	"k_dark",
	"k_ghost",
	"k_poison",
	"k_bug",
	"k_steel",
	"k_fairy",
	"k_crystal",
	"k_sound",
	"shotgun",
	"sniper",
	"hit_heavy",
	"slash_hit",
	"armor_hit",
	"armor_break",
	"knock_confirm",
	"extract_ok",
	"elim_confirm",
	"ab_throw",
	"ab_rail",
	"ab_charge",
	"ab_blast",
	"ab_leap",
	"ab_slam",
	"ab_wall",
	"ab_shield_hit",
	"ab_guard",
	"ab_parry",
	"ab_plant",
	"ab_tether",
	"ab_blink",
	"ab_whirr",
	"ab_stun",
	"ab_slow",
	"ab_hit",
	"ab_ready",
	"pay_deadeye",
	"pay_flashpoint",
	"pay_called",
	"pay_slam",
	"pay_cashin",
	"pay_rage",
	"level_up",
	"hero_blowout",
	"hero_skewer",
	"dr_anchor",
	"as_ignite",
	"pay_rockfall",
	"pay_collapse",
	"rustle",
	"squeak",
	"key_get",
	"lock_rattle",
	"reset_a",
	"reset_b",
	"reset_c",
	"break_wood",
	"break_clay",
	"break_metal",
	"keg_fuse",
	"keg_blast"
]
const POOL := 24
const SAMPLE := "ping"  # the sound play_sample() puts through a bus
## The squad cues (you or a squadmate downs or finishes a rival): one dedicated voice, so footsteps and
## the combat crowd never steal it, and no gap or stack cap thins it.
const CUES := ["knock_confirm", "elim_confirm"]
## Sounds that only exist as several takes (monster voices, little pops); one is picked at random.
const VOICES := [
	"v_skitter",
	"v_spitter",
	"v_brute",
	"v_bomber",
	"v_sentinel",
	"v_glimmer",
	"v_warden",
	"v_bl_skitter",
	"v_bl_warden",
	"die_small",
	"die_big",
	"step_grass",
	"step_stone",
	"step_snow",
	"step_wood",
	"step_water_light",
	"step_water_medium",
	"step_water_heavy",
	"step_metal_light",
	"step_metal_medium",
	"step_metal_heavy"
]
## The shortest gap before the same sound can play again, so a crowd doesn't machine-gun it.
const MIN_GAP := {
	"scan_pop": 150,
	"scan_pop_fine": 150,
	"scan_pop_rare": 150,
	"scan_fail": 150,
	"scan_call": 200,
	"boki_yawn": 400,
	"break_wood": 40,
	"tell_foe": 120,
	"break_clay": 40,
	"break_metal": 40,
	"keg_fuse": 80,
	"keg_blast": 100,
	"reset_a": 120,
	"reset_b": 120,
	"reset_c": 120,
	"pay_deadeye": 120,
	"pay_flashpoint": 150,
	"pay_called": 120,
	"pay_slam": 150,
	"pay_cashin": 120,
	"pay_rage": 150,
	"pay_rockfall": 150,
	"pay_collapse": 150,
	"ab_hit": 60,
	"squeak": 80,
	"rustle": 120,
	"ab_shield_hit": 70,
	"ab_stun": 150,
	"ab_slow": 120,
	"hit": 45,
	"crit": 60,
	"hit_heavy": 70,
	"slash_hit": 60,
	"armor_hit": 70,
	"armor_break": 200,
	"hurt": 120,
	"kinhit": 60,
	"die_small": 90,
	"die_big": 150,
	"land": 80,
	"step0": 60,
	"step1": 60,
	"step2": 60,
	"training_dummy_hit": 70
}
## On top of that, at most STACK_MAX of one sound start within STACK_MS, each extra one a little quieter.
## A Boki type's impact ki_<type> is the take set of its cast cue k_<type> (BokiImpact), with its own gap and cap.
const IMPACT_PREFIX := "ki_"
const IMPACT_PREFIX_OF := "k_"
const IMPACT_GAP := 90
const STACK_MAX := 3
const STACK_MS := 90
const STACK_DB := 3.5
## The explosion category: the generic blast sounds (a Boki's burst or rider, an area hit, an ability blast) sit
## this far under every call's own level, so a blast reads as a thump in the mix rather than the loudest thing
## on screen. BLAST_PEAK_DB is the agreed ceiling for a blast's file peak plus this gain (checked in
## --tender-combo-check).
const BLAST := ["boom", "ab_blast", "ab_slam"]
const BLAST_DB := -7.0
const BLAST_PEAK_DB := -6.0
## Distance falloff, sized to the match view (the wide camera, ~37 m across, so ~18.5 m to the side edge): what you
## can see you can hear. Full volume within NEAR metres, then a gentle roll-off (SPREAD is the metres per
## doubling-ish step: 1 + (d - NEAR) / SPREAD); muffled beyond FAR (just past the side edge); silent past hear_range
## (30 m: ~10 m off screen, fading from 0.7 of it). Docs: AUDIO.md "Falloff".
const NEAR := 5.5
const SPREAD := 8.0
const FAR := 19.0
## Sounds behind terrain (see SfxOcclusion) go through the SFXMuffled bus (SfxMix.OCCLUDED_HZ / OCCLUDED_DB).
var occlusion := SfxOcclusion.new()
## A positional one-shot plays from a 3D voice placed where it happens, so the camera pans it: you hear which
## side a footstep or a landing is on. Its level stays this file's own falloff (_distance_db), so Godot's
## attenuation and distance low-pass are off. PAN: how hard it pans (x the project's 3d_panning_strength, 0.5).
const PAN := 2.0
## While you are downed or out the world goes dull: the SFXWorld bus (everything but SfxMix.CLEAR, and the far
## and occluded buses that feed it) is low-passed and ducked, ramped in and out (from SfxMix.MUFFLE_OPEN_HZ).
const MUFFLE_HZ := 1200.0  # Hz: the low-pass cutoff while muffled
const MUFFLE_DB := -6.0  # dB: the duck on the world bus while muffled
const MUFFLE_S := 0.3  # s: ramp in / out
var skip: Array = []  # sounds left out for now (ArchKit.run_own: the shared cast sounds under a Hero's own)
var last_take := {}
var recent := {}  # sound -> start times (ms) still inside the stacking window

var streams := {}
var players: Array[AudioStreamPlayer] = []  # the one-shot voices with no position (UI)
var spots: Array[AudioStreamPlayer3D] = []  # ...and the placed ones
var voice_all: Array = []  # players then spots: the index SfxVoices rank and sound use
var last_voice = null  # the one-shot voice started last (tooling reads its level)
var next := 0
var voices := SfxVoices.new(POOL * 2)  # who keeps a voice when the pool or the loops are full (plain, then placed)
var cue_voice: AudioStreamPlayer
var cue_plays := {}  # cue name -> times played (--knock-sfx-check)
var listener := Vector3.ZERO  # set by the camera each frame
var hear_range := 30.0  # m: silent beyond this (a sound's own "reach" overrides it)
var sound_reach := {}  # sound -> metres it carries, past hear_range (content/sfx/<group>.json "reach")
var last_played := {}
## --sfx-silence-audit only (null = off): play() and loop_start() append [name, pos, found].
var cue_log = null
var rng := RandomNumberGenerator.new()

## A one-shot started: where (null for UI), its dB before distance and pitch. SfxCast and the audio checks listen.
signal played(sname: String, at: Variant, vol_db: float, pitch: float)
var music: Array[AudioStreamPlayer] = []  # two players so tracks can crossfade
var music_i := 0
var music_name := ""
var ambs: Array[AudioStreamPlayer] = []  # the main ambience bed: two players, so a new bed crossfades over the old
var amb_i := 0  # which of the two is the current bed
var amb_name := ""
var _amb_rate := 1.0  # gain per second the beds move at, from the last play_ambience's fade
const AMB_DB := -14.0  # dB: the main bed at full
const AMB_DUCK_DB := -9.0  # dB the Ambience bus sinks by at the height of a fight
var mix: SfxMix
var cue_db := {}  # sound -> dB the mix pass adds (content/rules/sfx_cues.json, tools/loudness_report.py)
var duck_rules := {}  # content/rules/sfx_mix.json "duck": depths, holds and the way back
var _muffle_tw: Tween
var _muffle_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mix = SfxMix.new(self)
	for i in 2:
		music.append(_silent_player("Music"))
		ambs.append(_silent_player("Ambience"))
	for n in NAMES + VOICES + SfxKits.NAMES + VVSfx.NAMES:  # (VVSfx: Sparkle and Vex)
		var takes: Array = []
		var s = load("res://audio/%s.wav" % n) if ResourceLoader.exists("res://audio/%s.wav" % n) else null
		if s:
			takes.append(s)
		for i in range(1, 5):
			var path := "res://audio/%s_%d.wav" % [n, i]
			if ResourceLoader.exists(path):
				takes.append(load(path))
		if takes.size() == 1:
			streams[n] = takes[0]
		elif takes.size() > 1:
			streams[n] = takes
	_load_sets()
	_load_mix()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
		var s := AudioStreamPlayer3D.new()
		s.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		s.attenuation_filter_db = 0.0
		s.max_db = 6.0
		s.panning_strength = PAN
		add_child(s)
		spots.append(s)
	voice_all.append_array(players)
	voice_all.append_array(spots)
	cue_voice = AudioStreamPlayer.new()
	cue_voice.bus = "SFX"
	add_child(cue_voice)


## A player on `bus_name`, silent until something fades it up.
func _silent_player(bus_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	p.volume_db = -80.0
	add_child(p)
	return p


## Each sound set's categories (they pick the bus, SfxMix.learn) and its heavy sounds that carry further than
## hear_range (a gatling you hear coming), under "reach" (metres). Past FAR they still go through the muffled
## bus, so what carries is the low end.
func _load_sets() -> void:
	for f in DirAccess.get_files_at("res://content/sfx"):
		if not f.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/" + f))
		if d is Dictionary:
			mix.learn((d as Dictionary).get("sounds", {}))
			for sname in (d as Dictionary).get("reach", {}):
				sound_reach[sname] = float(d["reach"][sname])


## The mix pass (docs/AUDIO.md): per-cue dB to land each category on its loudness target, and the ducking rules.
func _load_mix() -> void:
	var cues = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/sfx_cues.json"))
	cue_db = (cues as Dictionary).get("cues", {})
	var rules = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/sfx_mix.json"))
	duck_rules = (rules as Dictionary).get("duck", {})


func set_bus(bus_name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))


## Starts loading tracks on a worker thread ("music_match", "amb_match"), e.g. while a loading
## screen comes up, so starting them later doesn't read and parse the file on the main thread.
var _prefetched := {}


func prefetch(names: Array) -> void:
	for n in names:
		var path := "res://audio/%s.ogg" % n
		if _prefetched.has(path) or ResourceLoader.has_cached(path) or not ResourceLoader.exists(path):
			continue
		if ResourceLoader.load_threaded_request(path, "", false) == OK:
			_prefetched[path] = true


func _loop_stream(path: String) -> AudioStream:
	var st = null
	if _prefetched.has(path):
		_prefetched.erase(path)
		st = ResourceLoader.load_threaded_get(path)  # waits only if the worker isn't done yet
	if st == null:
		st = load(path)
	if st is AudioStreamOggVorbis:
		st.loop = true
	return st


## Crossfades to another music track ("home", "match", "title"), or to silence with "".
var music_lock := ""
var _music_tw: Tween  # a track picked in the music list plays until cleared


func play_music(name: String, fade := 1.5) -> void:
	if name == music_name:
		return
	if not layers.is_empty():
		_stop_layers(fade)
	music_name = name
	if Data.MUSIC.has(name) and not Save.d.get("music", []).has(name):
		# first time hearing one of the house's records: it joins the music list
		if not Save.d.has("music"):
			Save.d["music"] = []
		Save.d["music"].append(name)
		Save.save_game()
	var old := music[music_i]
	music_i = 1 - music_i
	var nw := music[music_i]
	# a fade still running would keep pushing its track back up, so it stops here
	if _music_tw and _music_tw.is_valid():
		_music_tw.kill()
	var tw := create_tween().set_parallel(true)
	_music_tw = tw
	tw.tween_property(old, "volume_db", -80.0, fade).set_trans(Tween.TRANS_SINE)
	if name != "":
		nw.stream = _loop_stream("res://audio/music_%s.ogg" % name)
		nw.volume_db = -40.0
		nw.play()
		tw.tween_property(nw, "volume_db", -9.0, fade).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(old.stop)  # after both fades: chained before the fade-in, it waited for the fade-out


## Crossfades the main ambience bed to audio/amb_<name>.ogg ("home", "match", a map region's bed), or to
## silence with "", over `fade` seconds (_process moves both players). The new bed takes the quieter
## player (a stopped one sits at -80 dB), so at most two beds ever sound, even when asked mid-fade.
func play_ambience(name: String, fade := 2.0) -> void:
	if name == amb_name:
		return
	amb_name = name
	_amb_rate = db_to_linear(AMB_DB) / fade
	if name == "":
		return
	var st := _loop_stream("res://audio/amb_%s.ogg" % name)
	amb_i = 0 if ambs[0].volume_db <= ambs[1].volume_db else 1
	for i in ambs.size():
		if ambs[i].playing and ambs[i].stream == st:
			amb_i = i  # back to a bed still fading out: it just turns round
	var nw := ambs[amb_i]
	if not nw.playing or nw.stream != st:
		nw.stream = st
		nw.volume_db = -80.0
		nw.play()


## Sinks the Ambience bus by k (0..1) of AMB_DUCK_DB; MusicDir passes how much of a fight is on.
func duck_ambience(k: float) -> void:
	mix.amb_duck.volume_db = AMB_DUCK_DB * clampf(k, 0.0, 1.0)


## Softens the music and the ambience for a moment, e.g. under a big slow-motion beat or an enemy ult
## (eased in fast, held for `seconds`, back in duck_rules["back_s"], never a sudden drop).
func duck(seconds: float, depth_db := -8.0) -> void:
	mix.duck(seconds, depth_db, float(duck_rules["attack_s"]), float(duck_rules["back_s"]))


## A dip for something loud at pos (kind "ult" or "knock", the depth and hold in content/rules/sfx_mix.json),
## only when it is within hearing of the camera.
func duck_for(kind: String, pos: Vector3) -> void:
	if Vector2(pos.x - listener.x, pos.z - listener.z).length() <= float(duck_rules["range_m"]):
		duck(float(duck_rules[kind + "_hold_s"]), float(duck_rules[kind + "_db"]))


## Switches the downed / out muffle on the world bus (SfxMix.muffle_fx plus a duck), eased over MUFFLE_S.
## Off is also what a match leaving does (reset_scene_audio).
func set_muffle(on: bool) -> void:
	if on == _muffle_on:
		return
	_muffle_on = on
	var bus := AudioServer.get_bus_index("SFXWorld")
	if _muffle_tw and _muffle_tw.is_valid():
		_muffle_tw.kill()
	if on:
		AudioServer.set_bus_effect_enabled(bus, 0, true)
	var tw := create_tween().set_parallel(true)
	_muffle_tw = tw
	tw.tween_property(mix.muffle_fx, "cutoff_hz", MUFFLE_HZ if on else SfxMix.MUFFLE_OPEN_HZ, MUFFLE_S)
	tw.tween_method(
		func(db: float): AudioServer.set_bus_volume_db(bus, db),
		AudioServer.get_bus_volume_db(bus),
		MUFFLE_DB if on else 0.0,
		MUFFLE_S
	)
	if not on:
		tw.chain().tween_callback(AudioServer.set_bus_effect_enabled.bind(bus, 0, false))


## Tooling (--match-audio-check): the muffle as the bus has it right now.
func muffle_state() -> Dictionary:
	var bus := AudioServer.get_bus_index("SFXWorld")
	return {
		"fx": AudioServer.is_bus_effect_enabled(bus, 0),
		"db": AudioServer.get_bus_volume_db(bus),
		"hz": mix.muffle_fx.cutoff_hz
	}


# ------------------------------------------------------------------ layered music
## The expedition's score is four stems of one piece (tools/compose.py LAYERS), all playing in step;
## what's happening decides how loud each is (scripts/match/music_dir.gd sets the levels).
var layers := {}  # stem -> AudioStreamPlayer
var layer_want := {}  # stem -> 0..1
const LAYER_DB := -9.0  # a stem at full, the same level a single track plays at
const LAYER_IN := 1.2  # seconds to fade a stem in, and out
const LAYER_OUT := 3.0
const LAYER_UNDER := 0.5  # seconds a stem takes to fall away while a sting plays over it
const STING_DB := -6.0
const STING_CUT := 0.15  # seconds: a sting still ringing when its scene ends fades this fast
signal stung(which: String)  # a sting started ("extract", "out", "last", "home")
var _sting_p: AudioStreamPlayer


## A short musical sting (audio/sting_<name>.ogg, tools/compose.py) over the score, one at a time:
## a new one replaces one still ringing. The layered stems fall away fast while it plays.
func sting(which: String) -> void:
	var path := "res://audio/sting_%s.ogg" % which
	if not ResourceLoader.exists(path):
		return
	if _sting_p == null:
		_sting_p = AudioStreamPlayer.new()
		_sting_p.bus = "Music"
		_sting_p.volume_db = STING_DB
		add_child(_sting_p)
	stung.emit(which)
	_sting_p.stream = load(path)
	_sting_p.volume_db = STING_DB
	_sting_p.play()


func sting_on() -> bool:
	return _sting_p != null and _sting_p.playing


func _cut_sting() -> void:
	if sting_on():
		var tw := create_tween()
		tw.tween_property(_sting_p, "volume_db", -60.0, STING_CUT)
		tw.tween_callback(_sting_p.stop)


## Starts a group's stems together (music_<group>_<stem>.ogg); `want` gives each stem's starting
## level. Crossfades out whatever was playing.
func play_layers(group: String, want: Dictionary, fade := 1.5) -> void:
	if music_name == group and not layers.is_empty():
		set_layers(want)
		return
	play_music("", fade)
	music_name = group
	for st in want:
		var path := "res://audio/music_%s_%s.ogg" % [group, st]
		if not ResourceLoader.exists(path):
			continue
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.stream = _loop_stream(path)
		p.volume_db = -60.0
		add_child(p)
		layers[st] = p
	for st in layers:
		(layers[st] as AudioStreamPlayer).play()
	set_layers(want)


func set_layers(want: Dictionary) -> void:
	for st in want:
		layer_want[st] = clampf(float(want[st]), 0.0, 1.0)


## A match leaving the tree (extract, death, quit, a rematch; Match._exit_tree): everything it started
## stops. The layered score and the abyss / ruins beds fade out (play_ambience never clears them), the
## fight ducking lets go, every keyed loop stops, and a pool voice still ringing is cut. The single tracks
## and the main ambience bed are left to the next screen's play_music / play_ambience, which crossfade them.
func reset_scene_audio(fade := 1.2) -> void:
	_cut_sting()
	if not layers.is_empty():
		_stop_layers(fade)
		music_name = ""
	if not amb_layers.is_empty():
		clear_amb_layers(fade)
	duck_ambience(0.0)
	set_muffle(false)
	for key in loops.keys():
		loop_stop(key)
	for p in voice_all:
		p.stop()
	voices.friends.resize(0)


## How many players that never end on their own are still sounding (a looping pool voice, keyed loops,
## score stems and beds): 0 once a match's reset_scene_audio has run and the fades are done
## (--match-audio-check). A pool one-shot ends by itself, so a farm footstep doesn't count.
func match_voices() -> int:
	var n := 0
	for p in voice_all:
		if p.playing and loops_forever(p.stream):
			n += 1
	for key in loops:
		if is_instance_valid(loops[key]["p"]):
			n += 1
	var own := []  # the farm's garden beds belong to the farm, not to a match (MATCH_BEDS are the match's)
	for nm in amb_layers:
		if not nm in MATCH_BEDS:
			own.append(amb_layers[nm]["p"])
	for c in get_children():
		if not c is AudioStreamPlayer:
			continue  # (the placed voices are 3D: counted above)
		var ours: bool = c in players or c in music or c in ambs or c in own
		if c.playing and not ours:
			n += 1  # also a stem or bed or loop still fading out
	return n


func _stop_layers(fade: float) -> void:
	for st in layers:
		var p: AudioStreamPlayer = layers[st]
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, fade).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(p.queue_free)
	layers = {}
	layer_want = {}


## Extra ambience beds on top of the main one (wind over the abyss, ruins, the garden's time-of-day
## and pond beds), each faded to a level by where you are; created on first use, freed once faded
## to nothing, stopped together by clear_amb_layers.
var amb_layers := {}  # name -> {p, want}
const MATCH_BEDS := ["abyss", "ruins"]  # MusicDir's beds; other amb_layers are the farm's


func amb_layer(name: String, level: float) -> void:
	if not amb_layers.has(name):
		if level <= 0.001 or not ResourceLoader.exists("res://audio/amb_%s.ogg" % name):
			return
		var p := AudioStreamPlayer.new()
		p.bus = "Ambience"
		p.stream = _loop_stream("res://audio/amb_%s.ogg" % name)
		p.volume_db = -60.0
		add_child(p)
		p.play()
		amb_layers[name] = {"p": p, "want": 0.0}
	amb_layers[name]["want"] = clampf(level, 0.0, 1.0)


func clear_amb_layers(fade := 1.0) -> void:
	for n in amb_layers:
		var p: AudioStreamPlayer = amb_layers[n]["p"]
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, fade)
		tw.tween_callback(p.queue_free)
	amb_layers = {}


func _process(delta: float) -> void:
	if not loops.is_empty():
		_drop_stale_holds()
		voices.cull_loops(loops, listener)
	for n in amb_layers.keys():
		var ap: AudioStreamPlayer = amb_layers[n]["p"]
		var full := db_to_linear(-12.0)
		var ac := move_toward(db_to_linear(ap.volume_db), float(amb_layers[n]["want"]) * full, full * delta / 2.5)
		ap.volume_db = linear_to_db(maxf(ac, 0.0001))
		if ac <= 0.0001 and float(amb_layers[n]["want"]) <= 0.0:
			ap.queue_free()
			amb_layers.erase(n)
	for i in ambs.size():
		_amb_ramp(ambs[i], i == amb_i and amb_name != "", delta)
	if layers.is_empty():
		return
	for st in layers:
		var p: AudioStreamPlayer = layers[st]
		var cur := db_to_linear(p.volume_db)
		var tgt := float(layer_want.get(st, 0.0)) * db_to_linear(LAYER_DB)
		var secs := LAYER_IN
		if tgt <= cur:
			secs = LAYER_UNDER if sting_on() else LAYER_OUT
		var rate := db_to_linear(LAYER_DB) * delta / secs
		cur = move_toward(cur, tgt, rate)
		p.volume_db = linear_to_db(maxf(cur, 0.0001))


## Moves a main-bed player toward full (the current bed) or silence at the last crossfade's rate, in
## linear gain; one that reaches silence stops, so only the beds still heard are playing.
func _amb_ramp(ap: AudioStreamPlayer, on: bool, delta: float) -> void:
	if not ap.playing:
		return
	var g := move_toward(db_to_linear(ap.volume_db), db_to_linear(AMB_DB) if on else 0.0, _amb_rate * delta)
	ap.volume_db = linear_to_db(maxf(g, 0.0001))
	if g <= 0.0:
		ap.stop()


var _step_i := 0


## A plain footstep (three takes in turn). reach: metres it carries, 0 for hear_range (see StepReach).
func step(pos = null, vol := -16.0, reach := 0.0) -> void:
	_step_i = (_step_i + 1) % 3
	play("step%d" % _step_i, pos, vol, 0.12, 1.0, reach)


func has(sname: String) -> bool:
	return streams.has(sname)


## How much quieter (dB) a sound at pos is for the listener, or NAN when it's out of earshot.
func _distance_db(pos, reach := 0.0) -> float:
	if pos == null:
		return 0.0
	var hr := reach if reach > 0.0 else hear_range
	var dist := Vector2(pos.x - listener.x, pos.z - listener.z).length()
	if dist > hr:
		return NAN
	# a soft inverse-distance roll-off (about -8 dB at the screen edge), easing to silence at the edge of hearing
	var db := -20.0 * log(1.0 + maxf(0.0, dist - NEAR) / SPREAD) / log(10.0)
	var edge := 1.0 - smoothstep(hr * 0.7, hr, dist)
	return db + linear_to_db(maxf(edge, 0.001))


## The voice for a sound at pos, of rank rk (SfxVoices.pick: a free one, else the farthest sound ranked below it), or
## null when it gets none. A sound with a place and a camera to hear it from plays on a placed voice (it pans),
## else on a plain one.
func _voice(pos, rk: float, sname: String):
	var placed: bool = pos != null and get_viewport().get_camera_3d() != null
	var base := POOL if placed else 0
	var i := voices.pick(spots if placed else players, base, next, rk, sname)
	if i < 0:
		return null
	next = (i + 1) % POOL
	voices.rank[base + i] = rk
	voices.sound[base + i] = sname
	var p = voice_all[base + i]  # the same fields on both kinds
	p.bus = _bus_for(pos, sname)
	if placed:
		(p as AudioStreamPlayer3D).position = pos
	return p


func _start(p, st: AudioStream, vol_db: float, pitch: float) -> void:
	last_voice = p
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


## Which bus a sound at pos plays on: muffled behind terrain, low-passed when far, else its own kind's bus
## (SfxMix.bus_for: the SFXWorld bus the downed muffle dulls, unless its kind or SfxMix.CLEAR keeps it clear).
## No position (a cue for you alone): its kind's bus, never muffled.
func _bus_for(pos, sname := "") -> StringName:
	if pos == null:
		return mix.bus_for(sname, false, false)
	var muffled: bool = occlusion.blocked(pos, listener)
	var far: bool = Vector2(pos.x - listener.x, pos.z - listener.z).length() > FAR
	return mix.bus_for(sname, muffled, far)


## Settings > Audio: a short sound through one bus when its slider is let go, to hear the new level.
func play_sample(bus_name: String) -> void:
	if not streams.has(SAMPLE) and not _lazy(SAMPLE):
		return
	var p = _voice(null, voices.rank_of(null, listener), SAMPLE)
	if p == null:
		return
	var st = streams[SAMPLE]
	p.stream = _once(st[0] if st is Array else st)
	p.bus = bus_name
	p.volume_db = 0.0
	p.pitch_scale = 1.0
	p.play()


## pos: world position, or null for UI sounds. Repeats of one sound within 30ms are merged, and a
## burst of the same sound is capped and stacked quieter. reach: metres this call carries (0: the sound's own
## "reach", else hear_range). mine: your own sound played away from you (a hit tick on the one you hit), so the pool
## keeps it as it keeps your other sounds (SfxVoices). take: a given take of a sound that has several (FireSfx
## round-robins them), else a random one that isn't the last.
func play(
	sname: String, pos = null, vol_db := 0.0, pitch_var := 0.07, pitch := 1.0, reach := 0.0, mine := false, take := -1
) -> void:
	if cue_log != null:
		cue_log.append([sname, pos, not sname in skip and ensure(sname)])
	if sname in skip or (not streams.has(sname) and not _lazy(sname)):
		return
	if sname in CUES:
		cue_plays[sname] = int(cue_plays.get(sname, 0)) + 1
		cue_voice.stream = streams[sname]
		cue_voice.volume_db = vol_db
		cue_voice.pitch_scale = pitch
		cue_voice.play()
		return
	var now := Time.get_ticks_msec()
	var gap: int = 260 if sname.begins_with("v_") else int(MIN_GAP.get(sname, SfxKits.MIN_GAP.get(sname, 30)))
	if sname.begins_with(IMPACT_PREFIX):
		gap = IMPACT_GAP
	if sname.contains("step_"):
		gap = 25  # footsteps: several people can walk at once
	var rk := voices.rank_of(pos, listener, mine)
	if now - int(last_played.get(sname, -1000)) < gap:
		voices.cut.emit(sname, rk, &"gap")
		return
	var r := reach if reach > 0.0 else float(sound_reach.get(sname, 0.0))
	var v := vol_db + float(cue_db.get(sname, 0.0)) + _distance_db(pos, r) + (BLAST_DB if sname in BLAST else 0.0)
	if is_nan(v):
		return
	var times: Array = recent.get(sname, [])
	while not times.is_empty() and now - int(times[0]) > STACK_MS:
		times.pop_front()
	if times.size() >= STACK_MAX:
		voices.cut.emit(sname, rk, &"stack")
		return
	var p = _voice(pos, rk, sname)
	if p == null:
		return
	v -= STACK_DB * times.size()
	times.append(now)
	recent[sname] = times
	last_played[sname] = now
	if mix.big_sounds.has(sname):
		mix.big_event()
	_start(p, _take(sname, take), v, pitch * (1.0 + rng.randf_range(-pitch_var, pitch_var)))
	played.emit(sname, pos, vol_db, pitch)


## Starts sname on a voice at pos (placed, so it pans) at exactly vol_db and returns the voice, or null when
## it gets none. No distance falloff and no repeat gap: the caller sets the level and keeps the one voice
## (IncomingHitSfx: a flurry of hits on you is one voice). Yours (a hit on you): it ranks as your own sounds
## do, and the bus (so the downed muffle) applies.
func play_voice(sname: String, pos, vol_db: float, pitch := 1.0):
	if not streams.has(sname) and not _lazy(sname):
		return null
	var p = _voice(pos, SfxVoices.YOU, sname)
	if p != null:
		_start(p, _take(sname), vol_db, pitch)
	return p


## The stream to play for sname: take `take` of a sound that has several (FireSfx), else a different one
## from last time.
func _take(sname: String, take := -1) -> AudioStream:
	var st = streams[sname]
	if st is Array:
		var arr: Array = st
		var i: int = take % arr.size() if take >= 0 else rng.randi_range(0, arr.size() - 1)
		if take < 0 and arr.size() > 1 and i == int(last_take.get(sname, -1)):
			i = (i + 1) % arr.size()
		last_take[sname] = i
		st = arr[i]
	return _once(st)


## A pool voice is never reused while it plays, so a looping file sent through play() would sound
## forever, past the match and into the farm: owner item 103, the Boki rescue's revive_hum. One-shots
## get a copy of a looping file that plays once; a sound that should last goes through loop_hold.
var _once_of := {}


func _once(st: AudioStream) -> AudioStream:
	if not loops_forever(st):
		return st
	if not _once_of.has(st):
		var c := (st as AudioStreamWAV).duplicate() as AudioStreamWAV
		c.loop_mode = AudioStreamWAV.LOOP_DISABLED
		_once_of[st] = c
	return _once_of[st]


static func loops_forever(st: AudioStream) -> bool:
	return st is AudioStreamWAV and (st as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED


## The "reset" cue (a dash or ability is back): the variant picked in Settings > Gameplay (a, b or c),
## synthesized by tools/gen_reset_sfx.py. A UI sound for the one who got it, so it carries no position.
const RESET_CUES := ["a", "b", "c"]
const RESET_CUE_DB := -3.0  # dB: bright, so it sits a little under the combat sounds' level


func play_reset_cue(vol_db := RESET_CUE_DB) -> void:
	var v := String(Settings.get_v("reset_cue"))
	play("reset_" + (v if v in RESET_CUES else "a"), null, vol_db, 0.0)


## Looping sounds that last as long as something goes on (a deathbox revive's hum): started, moved
## and re-pitched, and stopped by key. Each has its own voice outside the pool, with the same
## distance falloff as play() but its own reach (reach > 0 overrides hear_range).
var loops := {}  # key -> {p: AudioStreamPlayer, pos, vol, reach, bus}


## bus: "SFX", or "Music" for a bed that sits under the score and ducks with it (LastAlive).
func loop_start(key: String, sname: String, pos = null, vol_db := 0.0, reach := 0.0, bus := "SFX") -> void:
	if loops.has(key):
		return
	if cue_log != null:
		cue_log.append([sname, pos, ensure(sname)])
	var st = streams.get(sname) if ensure(sname) else null
	if st is Array:
		st = (st as Array)[0]
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	var carry := reach if reach > 0.0 else float(sound_reach.get(sname, 0.0))
	var vol := vol_db + float(cue_db.get(sname, 0.0))
	loops[key] = {"p": p, "pos": pos, "vol": vol, "reach": carry, "sound": sname, "bus": bus}
	if st == null:
		return
	if st is AudioStreamWAV and (st as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		st = (st as AudioStreamWAV).duplicate()
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = int((st as AudioStreamWAV).get_length() * (st as AudioStreamWAV).mix_rate)
	p.stream = st
	_loop_level(loops[key])
	p.play()
	voices.cull_loops(loops, listener, true)


func loop_set(key: String, pos = null, pitch := 1.0) -> void:
	if not loops.has(key):
		return
	var L: Dictionary = loops[key]
	L["pos"] = pos
	(L["p"] as AudioStreamPlayer).pitch_scale = maxf(0.05, pitch)
	_loop_level(L)


func loop_stop(key: String) -> void:
	if not loops.has(key):
		return
	var p: AudioStreamPlayer = loops[key]["p"]
	loops.erase(key)
	if is_instance_valid(p):
		# a short fade so it doesn't click off
		var tw := p.create_tween()
		tw.tween_property(p, "volume_db", -60.0, 0.12)
		tw.tween_callback(p.queue_free)


## A loop that lasts only while its owner keeps asking for it, once per tick (a Boki rescue's hum): if the
## calls stop (the channel ends any way, or its node is freed mid-channel) it stops within HOLD_MS.
const HOLD_MS := 250


func loop_hold(key: String, sname: String, pos = null, vol_db := 0.0, pitch := 1.0, bus := "SFX") -> void:
	loop_start(key, sname, pos, vol_db, 0.0, bus)
	loops[key]["vol"] = vol_db
	loops[key]["held"] = Time.get_ticks_msec()
	loop_set(key, pos, pitch)


func _drop_stale_holds() -> void:
	var now := Time.get_ticks_msec()
	for key in loops.keys():
		if now - int(loops[key].get("held", now)) > HOLD_MS:
			loop_stop(key)


func loop_on(key: String) -> bool:
	return loops.has(key)


func _loop_level(L: Dictionary) -> void:
	var p: AudioStreamPlayer = L["p"]
	var v := float(L["vol"]) + _distance_db(L["pos"], float(L["reach"]))
	v = -80.0 if is_nan(v) else v
	# Set only on a change: each set on a playing voice queues new bus details in the AudioServer, and a
	# loop held every step (LastAlive's bed) piled up enough to stall a headless check's exit for minutes.
	if absf(p.volume_db - v) > 0.01:
		p.volume_db = v
	# A bed on another bus (LastAlive's on Music) stays there so it ducks with the score.
	var bus: StringName = _bus_for(L["pos"], L["sound"]) if String(L["bus"]) == "SFX" else StringName(L["bus"])
	if p.bus != bus:
		p.bus = bus


## Plays a ready-made stream (a glider skin's sound, say) with the same distance falloff as play().
func play_stream(st: AudioStream, pos = null, vol_db := 0.0, pitch_var := 0.05) -> void:
	if st == null or players.is_empty():
		return
	# the same stream twice within 80ms (a glider flicked open and shut) plays once
	var key := "#%d" % st.get_instance_id()
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(key, -1000)) < 80:
		return
	var v := vol_db + _distance_db(pos)
	if is_nan(v):
		return
	last_played[key] = now
	var p = _voice(pos, voices.rank_of(pos, listener), key)
	if p == null:
		return
	_start(p, st, v, 1.0 + rng.randf_range(-pitch_var, pitch_var))


## A kit sound not in NAMES (each hero branch adds its own, e.g. pin_* and bjorn_*): loaded from
## audio/<name>.wav (and its takes <name>_1..4.wav) the first time it plays, so new kit sounds need no
## edit to the shared list.
var _lazy_miss := {}


func _lazy(sname: String) -> bool:
	if _lazy_miss.has(sname):
		return false
	var takes: Array = []
	var file := IMPACT_PREFIX_OF + sname.trim_prefix(IMPACT_PREFIX) if sname.begins_with(IMPACT_PREFIX) else sname
	var paths: Array = ["res://audio/%s.wav" % file]
	for i in range(1, 5):
		paths.append("res://audio/%s_%d.wav" % [file, i])
	for path in paths:
		if ResourceLoader.exists(path):
			takes.append(load(path))
	if takes.is_empty():
		_lazy_miss[sname] = true
		return false
	streams[sname] = takes[0] if takes.size() == 1 else takes
	return true


## How many takes a sound has (0 when it has no file).
func take_count(sname: String) -> int:
	if not ensure(sname):
		return 0
	var st = streams[sname]
	return (st as Array).size() if st is Array else 1


## Seconds one take of a sound sounds for.
func take_len(sname: String, take: int) -> float:
	var st = streams[sname]
	if st is Array:
		st = (st as Array)[take % (st as Array).size()]
	return (st as AudioStream).get_length()


## Whether a sound exists (loading it on first ask, as play does).
func ensure(sname: String) -> bool:
	return streams.has(sname) or _lazy(sname)
