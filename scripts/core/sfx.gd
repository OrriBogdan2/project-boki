extends Node
## Plays the synthesized sound effects (made by tools/gen_sfx.py). Positional sounds fade with distance
## from the camera focus, and far ones are also muffled (they go through a low-passed bus), so a fight
## across the map stays soft. The SFX bus has a gentle compressor, a touch of room reverb and a
## limiter, so a crowd of sounds blends together instead of piling up into peaks.

const NAMES := ["splash", "swim", "drip", "smg", "rifle", "thump", "boom", "hit", "crit", "kill", "knock", "hurt", "dash", "jump", "land", "grab",
	"throw", "kinhit", "skill", "kin_happy", "kin_unsure", "kin_alert", "recall", "pickup", "catch", "warn", "portal",
	"revive", "click", "reload", "shield", "cloak", "heal", "fall", "plant", "harvest", "ping", "glide", "build", "unlock", "whoosh", "step0", "step1", "step2", "hover", "zap", "bond", "ult", "combo", "swap", "horn", "rail", "train_hit", "revive_hum", "revive_done", "scan_pop",
	"swipe", "cleave", "charge", "k_venom", "k_spore", "k_gravity", "k_prism", "k_lunar", "k_echo",
	"shotgun", "sniper", "hit_heavy", "slash_hit", "armor_hit", "armor_break", "knock_confirm", "extract_ok",
	"ab_throw", "ab_rail", "ab_charge", "ab_blast", "ab_leap", "ab_slam", "ab_wall", "ab_shield_hit", "ab_guard", "ab_parry",
	"ab_plant", "ab_tether", "ab_blink", "ab_whirr", "ab_stun", "ab_slow", "ab_hit", "ab_ready",
	"pay_deadeye", "pay_flashpoint", "pay_called", "pay_slam", "pay_cashin", "pay_rage", "level_up",
	"hero_blowout", "hero_skewer", "dr_anchor", "as_ignite", "pay_rockfall", "pay_collapse",
	"rustle", "squeak", "key_get", "lock_rattle", "reset_a", "reset_b", "reset_c",
	"break_wood", "break_clay", "break_metal", "fuse_hiss"]
const POOL := 24
## Sounds that only exist as several takes (monster voices, little pops); one is picked at random.
const VOICES := ["v_skitter", "v_spitter", "v_brute", "v_bomber", "v_sentinel", "v_glimmer", "v_warden", "die_small", "die_big",
	"step_grass", "step_stone", "step_snow", "step_wood"]
## The shortest gap before the same sound can play again, so a crowd doesn't machine-gun it.
const MIN_GAP := {"break_wood": 40, "break_clay": 40, "break_metal": 40, "fuse_hiss": 80,
	"reset_a": 120, "reset_b": 120, "reset_c": 120, "pay_deadeye": 120, "pay_flashpoint": 150, "pay_called": 120, "pay_slam": 150, "pay_cashin": 120, "pay_rage": 150, "pay_rockfall": 150, "pay_collapse": 150, "ab_hit": 60, "squeak": 80, "rustle": 120, "ab_shield_hit": 70, "ab_stun": 150, "ab_slow": 120, "hit": 45, "crit": 60, "hit_heavy": 70, "slash_hit": 60, "armor_hit": 70, "armor_break": 200, "hurt": 120, "kinhit": 60, "die_small": 90, "die_big": 150, "land": 80, "land_light": 80, "land_medium": 80, "land_heavy": 80, "step0": 60, "step1": 60, "step2": 60}
## On top of that, at most STACK_MAX of one sound start within STACK_MS, each extra one a little quieter.
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
## Distance falloff: full volume within NEAR metres, then a gentle roll-off; muffled beyond FAR.
const NEAR := 3.5
const FAR := 9.0
var skip: Array = []      # sounds left out for now (ArchKit.run_own: the shared cast sounds under a Hero's own)
var last_take := {}
var recent := {}          # sound -> start times (ms) still inside the stacking window

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next := 0
var listener := Vector3.ZERO   # set by the camera each frame
var hear_range := 22.0
var sound_reach := {}       # sound -> metres it carries, past hear_range (content/sfx/<group>.json "reach")
var last_played := {}
var rng := RandomNumberGenerator.new()

signal new_track(name: String)
var music: Array[AudioStreamPlayer] = []   # two players so tracks can crossfade
var music_i := 0
var music_name := ""
var amb: AudioStreamPlayer
var amb_name := ""
var music_bus := 0
var _duck_fx: AudioEffectAmplify     # the Music bus's ducking stage (see duck)
var _duck_tw: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bn in ["Music", "SFX", "Ambience", "SFXFar"]:
		AudioServer.add_bus()
		var bi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, bn)
		AudioServer.set_bus_send(bi, "SFX" if bn == "SFXFar" else "Master")
	music_bus = AudioServer.get_bus_index("Music")
	_setup_mix()
	for i in 2:
		var mp := AudioStreamPlayer.new(); mp.bus = "Music"; mp.volume_db = -80.0
		add_child(mp); music.append(mp)
	amb = AudioStreamPlayer.new(); amb.bus = "Ambience"; amb.volume_db = -80.0
	add_child(amb)
	for n in NAMES + VOICES + SfxKits.NAMES + VVSfx.NAMES:      # (VVSfx: Sparkle and Vex)
		var takes: Array = []
		var s = load("res://audio/%s.wav" % n) if ResourceLoader.exists("res://audio/%s.wav" % n) else null
		if s: takes.append(s)
		for i in range(1, 5):
			var path := "res://audio/%s_%d.wav" % [n, i]
			if ResourceLoader.exists(path):
				takes.append(load(path))
		if takes.size() == 1:
			streams[n] = takes[0]
		elif takes.size() > 1:
			streams[n] = takes
	_load_reach()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)

## Heavy sounds that carry further than hear_range (a gatling you hear coming): each sound set lists them
## under "reach" (metres). Past FAR they still go through the muffled bus, so what carries is the low end.
func _load_reach() -> void:
	for f in DirAccess.get_files_at("res://content/sfx"):
		if not f.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/" + f))
		if d is Dictionary:
			for sname in (d as Dictionary).get("reach", {}):
				sound_reach[sname] = float(d["reach"][sname])

## The effects on the buses: SFX gets a soft compressor, a little room and a limiter; far-away sounds
## are low-passed on their way into it; the master has a last safety limiter.
func _setup_mix() -> void:
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
	var far := AudioServer.get_bus_index("SFXFar")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 1800.0
	AudioServer.add_bus_effect(far, lp)
	var mlim := AudioEffectHardLimiter.new()
	mlim.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, mlim)
	# the music gives way a little whenever the action is loud (keyed off the SFX bus), so gunfire
	# and hits stay on top of a full fight score without the score having to be quiet
	var side := AudioEffectCompressor.new()
	side.sidechain = &"SFX"
	side.threshold = -26.0
	side.ratio = 2.5
	side.attack_us = 15000.0
	side.release_ms = 350.0
	AudioServer.add_bus_effect(music_bus, side)
	# the music ducks under big moments on its own bus, so it works for one track or for layers
	_duck_fx = AudioEffectAmplify.new()
	AudioServer.add_bus_effect(music_bus, _duck_fx)
	var mlim2 := AudioEffectHardLimiter.new()
	mlim2.ceiling_db = -1.5
	AudioServer.add_bus_effect(music_bus, mlim2)

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
		st = ResourceLoader.load_threaded_get(path)     # waits only if the worker isn't done yet
	if st == null:
		st = load(path)
	if st is AudioStreamOggVorbis:
		st.loop = true
	return st

## Crossfades to another music track ("home", "match", "title"), or to silence with "".
var music_lock := ""
var _music_tw: Tween      # a track picked in the music list plays until cleared

func play_music(name: String, fade := 1.5) -> void:
	if name == music_name:
		return
	if not layers.is_empty():
		_stop_layers(fade)
	music_name = name
	if name != "" and not Save.d.get("music", []).has(name):
		# first time hearing this one: it joins the music list
		if not Save.d.has("music"): Save.d["music"] = []
		Save.d["music"].append(name)
		Save.save_game()
		new_track.emit(name)
	var old := music[music_i]
	music_i = 1 - music_i
	var nw := music[music_i]
	# a fade still running would keep pushing its track back up, so it stops here
	if _music_tw and _music_tw.is_valid():
		_music_tw.kill()
	var tw := create_tween().set_parallel(true)
	_music_tw = tw
	tw.tween_property(old, "volume_db", -80.0, fade).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(old.stop)
	if name != "":
		nw.stream = _loop_stream("res://audio/music_%s.ogg" % name)
		nw.volume_db = -40.0
		nw.play()
		tw.tween_property(nw, "volume_db", -9.0, fade).set_trans(Tween.TRANS_SINE)

func play_ambience(name: String) -> void:
	if name == amb_name:
		return
	if name != "match":
		clear_amb_layers()
	amb_name = name
	if name == "":
		create_tween().tween_property(amb, "volume_db", -80.0, 1.0)
		return
	amb.stream = _loop_stream("res://audio/amb_%s.ogg" % name)
	amb.volume_db = -40.0
	amb.play()
	create_tween().tween_property(amb, "volume_db", -14.0, 2.0)

## Softens the music for a moment, e.g. under a big slow-motion beat (eased, never a sudden drop).
func duck(seconds: float, depth_db := -8.0) -> void:
	if _duck_fx == null:
		return
	if _duck_tw and _duck_tw.is_valid():
		_duck_tw.kill()
	var tw := create_tween()
	_duck_tw = tw
	tw.tween_property(_duck_fx, "volume_db", minf(depth_db, _duck_fx.volume_db), 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(seconds)
	tw.tween_property(_duck_fx, "volume_db", 0.0, 0.8).set_trans(Tween.TRANS_SINE)

# ------------------------------------------------------------------ layered music
## The expedition's score is four stems of one piece (tools/compose.py LAYERS), all playing in step;
## what's happening decides how loud each is (scripts/match/music_dir.gd sets the levels).
var layers := {}          # stem -> AudioStreamPlayer
var layer_want := {}      # stem -> 0..1
const LAYER_DB := -9.0    # a stem at full, the same level a single track plays at
const LAYER_IN := 1.2     # seconds to fade a stem in, and out
const LAYER_OUT := 3.0

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
## stops. The layered score and the abyss / ruins beds fade out (the title asks for the "match" wind that
## is already the current ambience, an early return, so it would never clear them), every keyed loop
## stops, and a pool voice still ringing is cut. The single tracks and the main ambience are left to the
## next screen's play_music / play_ambience, which crossfade them.
func reset_scene_audio(fade := 1.2) -> void:
	if not layers.is_empty():
		_stop_layers(fade)
		music_name = ""
	if not amb_layers.is_empty():
		clear_amb_layers(fade)
	for key in loops.keys():
		loop_stop(key)
	for p in players:
		p.stop()

## How many players that never end on their own are still sounding (a looping pool voice, keyed loops,
## score stems and beds): 0 once a match's reset_scene_audio has run and the fades are done
## (--match-audio-check). A pool one-shot ends by itself, so a farm footstep doesn't count.
func match_voices() -> int:
	var n := 0
	for p in players:
		if p.playing and loops_forever(p.stream):
			n += 1
	for key in loops:
		if is_instance_valid(loops[key]["p"]): n += 1
	for c in get_children():
		if c is AudioStreamPlayer and c.playing and not c in players and not c in music and c != amb:
			n += 1          # also a stem or bed or loop still fading out
	return n

func _stop_layers(fade: float) -> void:
	for st in layers:
		var p: AudioStreamPlayer = layers[st]
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, fade).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(p.queue_free)
	layers = {}
	layer_want = {}

## Extra ambience beds on top of the main one (wind over the abyss, ruins), each faded to a level
## by where you are; created on first use, stopped by clear_amb_layers.
var amb_layers := {}      # name -> {p, want}

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
	for n in amb_layers:
		var ap: AudioStreamPlayer = amb_layers[n]["p"]
		var full := db_to_linear(-12.0)
		var ac := move_toward(db_to_linear(ap.volume_db), float(amb_layers[n]["want"]) * full, full * delta / 2.5)
		ap.volume_db = linear_to_db(maxf(ac, 0.0001))
	if layers.is_empty():
		return
	for st in layers:
		var p: AudioStreamPlayer = layers[st]
		var cur := db_to_linear(p.volume_db)
		var tgt := float(layer_want.get(st, 0.0)) * db_to_linear(LAYER_DB)
		var rate := db_to_linear(LAYER_DB) * delta / (LAYER_IN if tgt > cur else LAYER_OUT)
		cur = move_toward(cur, tgt, rate)
		p.volume_db = linear_to_db(maxf(cur, 0.0001))

var _step_i := 0
func step(pos = null, vol := -16.0) -> void:
	_step_i = (_step_i + 1) % 3
	play("step%d" % _step_i, pos, vol, 0.12)

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
	# a soft inverse-distance roll-off (about -8 dB by 10 m), easing to silence at the edge of hearing
	var db := -20.0 * log(1.0 + maxf(0.0, dist - NEAR) / 5.0) / log(10.0)
	var edge := 1.0 - smoothstep(hr * 0.7, hr, dist)
	return db + linear_to_db(maxf(edge, 0.001))

## A free voice from the pool, so a new sound doesn't cut one that's still ringing (the oldest if all are busy).
func _voice(pos) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = null
	for k in POOL:
		var c := players[(next + k) % POOL]
		if not c.playing:
			p = c
			next = (next + k + 1) % POOL
			break
	if p == null:
		p = players[next]
		next = (next + 1) % POOL
	var far := pos != null and Vector2(pos.x - listener.x, pos.z - listener.z).length() > FAR
	p.bus = "SFXFar" if far else "SFX"
	return p

## pos: world position, or null for UI sounds. Repeats of one sound within 30ms are merged, and a
## burst of the same sound is capped and stacked quieter.
func play(sname: String, pos = null, vol_db := 0.0, pitch_var := 0.07, pitch := 1.0) -> void:
	if sname in skip or (not streams.has(sname) and not _lazy(sname)):
		return
	var now := Time.get_ticks_msec()
	var gap: int = 260 if sname.begins_with("v_") else int(MIN_GAP.get(sname, SfxKits.MIN_GAP.get(sname, 30)))
	if sname.contains("step_"): gap = 25         # footsteps: several people can walk at once
	if now - int(last_played.get(sname, -1000)) < gap:
		return
	var v := vol_db + _distance_db(pos, float(sound_reach.get(sname, 0.0))) + (BLAST_DB if sname in BLAST else 0.0)
	if is_nan(v):
		return
	var times: Array = recent.get(sname, [])
	while not times.is_empty() and now - int(times[0]) > STACK_MS:
		times.pop_front()
	if times.size() >= STACK_MAX:
		return
	v -= STACK_DB * times.size()
	times.append(now)
	recent[sname] = times
	last_played[sname] = now
	var p := _voice(pos)
	var st = streams[sname]
	if st is Array:
		# a different take from last time
		var arr: Array = st
		var i := rng.randi_range(0, arr.size() - 1)
		if arr.size() > 1 and i == int(last_take.get(sname, -1)):
			i = (i + 1) % arr.size()
		last_take[sname] = i
		st = arr[i]
	p.stream = _once(st)
	p.volume_db = v
	p.pitch_scale = pitch * (1.0 + rng.randf_range(-pitch_var, pitch_var))
	p.play()

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
const RESET_CUE_DB := -3.0       # dB: bright, so it sits a little under the combat sounds' level
func play_reset_cue(vol_db := RESET_CUE_DB) -> void:
	var v := String(Settings.get_v("reset_cue"))
	play("reset_" + (v if v in RESET_CUES else "a"), null, vol_db, 0.0)

## Looping sounds that last as long as something goes on (a deathbox revive's hum): started, moved
## and re-pitched, and stopped by key. Each has its own voice outside the pool, with the same
## distance falloff as play() but its own reach (reach > 0 overrides hear_range).
var loops := {}               # key -> {p: AudioStreamPlayer, pos, vol, reach}

func loop_start(key: String, sname: String, pos = null, vol_db := 0.0, reach := 0.0) -> void:
	if loops.has(key):
		return
	var st = streams.get(sname)
	if st is Array: st = (st as Array)[0]
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	add_child(p)
	var carry := reach if reach > 0.0 else float(sound_reach.get(sname, 0.0))
	loops[key] = {"p": p, "pos": pos, "vol": vol_db, "reach": carry}
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
func loop_hold(key: String, sname: String, pos = null, vol_db := 0.0, pitch := 1.0) -> void:
	loop_start(key, sname, pos, vol_db)
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
	p.volume_db = -80.0 if is_nan(v) else v
	var far: bool = L["pos"] != null and Vector2(L["pos"].x - listener.x, L["pos"].z - listener.z).length() > FAR
	p.bus = "SFXFar" if far else "SFX"

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
	var p := _voice(pos)
	p.stream = st
	p.volume_db = v
	p.pitch_scale = 1.0 + rng.randf_range(-pitch_var, pitch_var)
	p.play()

## A kit sound not in NAMES (each hero branch adds its own, e.g. pin_* and bjorn_*): loaded from
## audio/<name>.wav (and its takes <name>_1..4.wav) the first time it plays, so new kit sounds need no
## edit to the shared list.
var _lazy_miss := {}
func _lazy(sname: String) -> bool:
	if _lazy_miss.has(sname):
		return false
	var takes: Array = []
	var paths: Array = ["res://audio/%s.wav" % sname]
	for i in range(1, 5):
		paths.append("res://audio/%s_%d.wav" % [sname, i])
	for path in paths:
		if ResourceLoader.exists(path):
			takes.append(load(path))
	if takes.is_empty():
		_lazy_miss[sname] = true
		return false
	streams[sname] = takes[0] if takes.size() == 1 else takes
	return true

## Whether a sound exists (loading it on first ask, as play does).
func ensure(sname: String) -> bool:
	return streams.has(sname) or _lazy(sname)
