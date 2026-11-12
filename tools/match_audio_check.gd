extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel).
## And the glider: each state (open, glide, dive, overheat, fold) plays its cue once, yours and another player's.
## Sound zones (owner's reverb ask): the room send is on inside a zone and off outside, and every zone
## the maps place names a real preset.

var main: Node
var fails := 0
var n := 0
const SETTLE := 4.0            # s: longer than the slowest match fade (the score's stems, 1.2s)

func ok(cond: bool, what: String) -> void:
	n += 1
	print("MATCHAUDIO %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.d["music"] = Save.d.get("music", [])
	Game.goto("match", {"autoplay": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"demo_kin": "cindle"})
	for i in 6:
		await main.get_tree().process_frame
	var m: Match = main.current
	m.set_process(false)
	var P: Hunter = m.player
	var k: Kin = P.kin
	ok(k != null, "setup: the player has a Boki")
	if k == null:
		main.get_tree().quit(1)
		return
	var key := "rescue%d" % k.get_instance_id()
	# the Boki goes down beside you and you run into it: the rescue's hum starts and follows the carry
	k.pos = P.pos + Vector3(0.6, 0, 0)
	k.state = "active"
	k.fly = {}
	k.go_down()
	_step(m, 0.4)
	ok(k.rescue_on and Sfx.loop_on(key), "a rescue under way has its hum (rescue_on %s)" % k.rescue_on)
	# the owner stops ticking mid-channel (frozen, or its node gone): the held loop stops by itself
	await main.get_tree().create_timer(0.5).timeout
	ok(not Sfx.loop_on(key), "a held loop nobody asks for any more stops within %d ms" % Sfx.HOLD_MS)
	_step(m, 0.2)
	ok(k.rescue_on and Sfx.loop_on(key), "...and comes back while the rescue goes on")
	# the old leak: a looping file through the one-shot pool plays once now
	Sfx.play("revive_hum", P.pos)
	var once := Sfx.players.filter(func(p): return p.playing and Sfx.loops_forever(p.stream))
	ok(once.is_empty(), "a one-shot of a looping file does not loop (%d looping pool voices)" % once.size())
	Sfx.loop_start("boxhum_check", "revive_hum", P.pos)       # (as a deathbox revive does, keyed)
	ok(Sfx.match_voices() >= 2, "setup: the match has several voices going (%d)" % Sfx.match_voices())
	_ult_cues(m, P)
	await _glider(P, "yours")
	var other: Hunter = m.hunters.filter(func(x): return x != P and not x.out)[0]
	other.remote = true
	other.pos = P.pos + Vector3(8, 0, 0)
	await _glider(other, "another player's")
	other.remote = false
	# the weather bed (AmbBeds) is up, and the end-of-match fade below takes it away with the rest
	m.music_dir.beds.tick(m, P)
	ok(Sfx.amb_layers.has("gust"), "the match's weather bed starts (amb layers: %s)" % str(Sfx.amb_layers.keys()))
	_belt_items(m, P)
	# going down muffles the world bus (a low-pass and a duck, 0.3 s ramp); a revive lifts it
	m.player.hp = 1.0                    # the low-health line: the milder filter, the heartbeat stays clear
	m.player.armor = 0.0
	m.music_dir.tick(m, 0.0)
	await main.get_tree().create_timer(Sfx.MUFFLE_S + 0.2).timeout
	var low := Sfx.muffle_state()
	ok(low.fx and is_equal_approx(low.db, Sfx.LOW_HP_DB) and is_equal_approx(low.hz, Sfx.LOW_HP_HZ),
		"under 25%% health: a mild low-pass and duck (%s)" % low)
	ok(Sfx._bus_for(null, "heartbeat" in Sfx.CLEAR) != "SFXWorld", "...and the heartbeat skips the world bus")
	m.player.hp = m.player.max_hp
	m.player.armor = m.player.max_armor
	await _muffle_step(m, true)
	var dull := Sfx.muffle_state()
	ok(dull.fx and is_equal_approx(dull.db, Sfx.MUFFLE_DB) and is_equal_approx(dull.hz, Sfx.MUFFLE_HZ),
		"downed: the world bus is low-passed and ducked (%s)" % dull)
	var bus := AudioServer.get_bus_index("SFXWorld")
	ok(Sfx._bus_for(null, true) != "SFXWorld" and Sfx._bus_for(null, false) == "SFXWorld",
		"the Wisp hum, pings and Boki voices skip the world bus")
	await _muffle_step(m, false)
	var clear := Sfx.muffle_state()
	ok(not clear.fx and is_zero_approx(clear.db) and is_equal_approx(clear.hz, Sfx.MUFFLE_OPEN_HZ),
		"revived: the muffle is off again (%s)" % clear)
	await _muffle_step(m, true)
	ok(Sfx.muffle_state().fx and bus >= 0, "downed again: muffled")
	await _duck_check(m)
	_check_zones(P.pos)
	# extract mid-channel and go home
	m.result = {"extracted": true, "why": "extract"}
	m._finish()
	for i in 6:
		await main.get_tree().process_frame
	if not _on_farm():
		Game.goto("home")
		for i in 6:
			await main.get_tree().process_frame
	ok(_on_farm(), "back on the farm (%s)" % main.current)
	ok(not Sfx.loop_on(key) and not Sfx.loop_on("boxhum_check"), "no keyed match loop is left")
	await main.get_tree().create_timer(Sfx.MUFFLE_S + 0.2).timeout
	ok(not Sfx.muffle_state().fx, "leaving the match while downed turns the muffle off")
	await main.get_tree().create_timer(SETTLE).timeout
	ok(Sfx.room == "", "the match's sound zones are gone with it")
	var farm_beds := 0      # HomeAmbience's own beds, still up on the farm
	for n in Sfx.amb_layers:
		if not n in ["abyss", "ruins"] and (Sfx.amb_layers[n]["p"] as AudioStreamPlayer).playing:
			farm_beds += 1
	var left := Sfx.match_voices() - farm_beds
	ok(left == 0, "after the fades nothing the match started is playing (%d, %d farm beds)" % [left, farm_beds])
	print("MATCHAUDIO DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## An ultimate is heard before it is seen: a rival's cue carries 40 m (not 70) with the rival tag, yours has the
## ally tag, all through the match's own pool voices (so the match leaving tears them down with the rest).
func _ult_cues(m: Match, P: Hunter) -> void:
	var rivals := m.hunters.filter(func(x): return x != P and x.team != P.team and x.ak != null)
	ok(not rivals.is_empty(), "setup: a rival Hunter with a kit")
	if rivals.is_empty():
		return
	var R: Hunter = rivals[0]
	Sfx.listener = P.pos
	R.pos = P.pos + Vector3(40, 0, 0)
	Sfx.last_played.clear()
	UltCue.cast(R.ak)
	var heard := Sfx.last_played.has(R.arch + "_ult_cue") and Sfx.last_played.has("ult_tag_foe")
	ok(heard and not Sfx.last_played.has("ult_tag_ally"),
			"a rival's ultimate 40 m away is heard, with the rival tag (%s)" % [Sfx.last_played.keys()])
	R.pos = P.pos + Vector3(70, 0, 0)
	Sfx.last_played.clear()
	UltCue.cast(R.ak)
	ok(Sfx.last_played.is_empty(), "...and 70 m away it is out of earshot")
	Sfx.last_played.clear()
	UltCue.cast(P.ak)
	heard = Sfx.last_played.has("ult_tag_ally") and Sfx.last_played.has(P.arch + "_ult_cue")
	ok(heard, "your own team's cue has the ally tag")

## Walks one hunter's glider through open, fast glide, dive, overheat and fold, setting the state a
## step at a time and ticking its GliderSfx directly. A cue plays once: its last-played stamp is set on
## the change of state and stays clear while the state just goes on.
func _glider(h: Hunter, who: String) -> void:
	var g := h.glider_snd
	var wind := "glider_wind%d" % h.get_instance_id()
	var burn := "glider_burn%d" % h.get_instance_id()
	h.gliding = false
	h.dropping = false
	h.glide_fuel = 1.0
	_set_speed(h, 0.0, 0.0)
	g.tick(h)
	for cue in ["glider_snap", "glider_dive", "glider_crackle", "glider_fold", "glider_hiss"]:
		ok(Sfx.ensure(cue), "%s: %s is a sound on file" % [who, cue])
	h.gliding = true
	_once(g, h, "glider_snap", who + " glider: opening plays the snap once")
	ok(Sfx.loop_on(wind), "%s glider: the wind loop runs" % who)
	var slow_pitch := _pitch(wind)
	var slow_vol := float(Sfx.loops[wind]["vol"])
	_set_speed(h, 24.0, -5.0)
	g.tick(h)
	var swells := _pitch(wind) > slow_pitch and float(Sfx.loops[wind]["vol"]) > slow_vol
	ok(swells, "%s glider: the wind pitches and swells with speed" % who)
	if h.remote:
		ok(Sfx.loops[wind]["pos"] != null, "another player's glider: the wind is positional")
	_set_speed(h, 6.0, -HunterMove.dive_vy)
	h.glide_dive.on = true
	_once(g, h, "glider_dive", who + " glider: the dive plays its whoosh once")
	h.glide_dive.on = false
	_set_speed(h, 6.0, -5.0)
	g.tick(h)
	var hiss := "glider_hiss%d" % h.get_instance_id()
	h.glide_fuel = 0.3
	g.tick(h)
	var faint := float(Sfx.loops[hiss]["vol"]) if Sfx.loop_on(hiss) else 0.0
	h.glide_fuel = 0.05
	g.tick(h)
	var near := float(Sfx.loops[hiss]["vol"]) if Sfx.loop_on(hiss) else 0.0
	var swelled := faint != 0.0 and near > faint
	ok(h.remote or swelled, "%s glider: the heat hiss swells toward overheat (%.1f -> %.1f dB)" % [who, faint, near])
	ok(not h.remote or not Sfx.loop_on(hiss), "another player's glider: no heat hiss (the heat is not synced)")
	h.glide_fuel = 0.0
	g.net_hot = true
	_once(g, h, "glider_crackle", who + " glider: overheating plays the crackle once")
	ok(Sfx.loop_on(burn), "%s glider: the burn loop runs while overheated" % who)
	h.glide_fuel = 1.0
	g.net_hot = false
	g.tick(h)
	ok(not g.hot, "%s glider: cooled, no longer burning" % who)
	h.gliding = false
	_once(g, h, "glider_fold", who + " glider: folding plays the fold once")
	await main.get_tree().create_timer(0.5).timeout
	var running := Sfx.loop_on(wind) or Sfx.loop_on(burn) or Sfx.loop_on(hiss)
	ok(not running, "%s glider: all loops stop once the glider is folded" % who)

func _set_speed(h: Hunter, flat: float, vy: float) -> void:
	h.vel = Vector3(flat, vy, 0)
	h.net_vel = h.vel

func _pitch(key: String) -> float:
	return (Sfx.loops[key]["p"] as AudioStreamPlayer).pitch_scale

## The state just changed: one tick plays `cue`; a second tick in the same state does not play it again.
func _once(g: GliderSfx, h: Hunter, cue: String, what: String) -> void:
	Sfx.last_played.erase(cue)
	g.tick(h)
	var first := Sfx.last_played.has(cue)
	Sfx.last_played.erase(cue)
	g.tick(h)
	ok(first and not Sfx.last_played.has(cue), what)
## Every belt item makes its own start cue at the user; the tonic and the armour kit loop while they channel and
## then play their end cue, or the cancel cue when spilt (BeltSfx, content/rules/belt_sfx.json).
func _belt_items(m: Match, P: Hunter) -> void:
	Sfx.listener = P.pos
	for id in BeltSfx.items():
		var start := BeltSfx.cue(id, "start")
		Sfx.last_played.erase(start)
		UtilityBelt.set_slot(P, 0, id, 3, 0)
		UtilityUse.start(P, 0, id)
		ok(Sfx.last_played.has(start), "belt %s: heard at its start cue %s" % [id, start])
		if not BeltSfx.cue(id, "loop").is_empty():
			_belt_channel(m, P, id)
		_step(m, 0.3)
		P.drink_t = 0.0
		P.kit_t = 0.0
		P.hp = P.max_hp
		Sfx.loop_stop(BeltSfx.loop_key(P, id))

func _belt_channel(m: Match, P: Hunter, id: String) -> void:
	var key := BeltSfx.loop_key(P, id)
	_step(m, 0.1)
	ok(Sfx.loop_on(key), "belt %s: loops while it channels" % id)
	Sfx.last_played.erase(BeltSfx.cue(id, "end"))
	_step(m, UtilityUse.channel(id, "time") + 0.1)
	ok(not Sfx.loop_on(key) and Sfx.last_played.has(BeltSfx.cue(id, "end")), "belt %s: ends with its end cue" % id)
	UtilityBelt.set_slot(P, 0, id, 3, 0)
	P.hp = P.max_hp - 10.0          # (hurt enough to drink, never near a down: the match runs around it)
	P.armor = 0.0
	UtilityUse.start(P, 0, id)
	_step(m, 0.1)
	Sfx.last_played.erase(BeltSfx.cue(id, "cancel"))
	P.stun_t = 1.0
	_step(m, 0.1)
	var spilt := not Sfx.loop_on(key) and Sfx.last_played.has(BeltSfx.cue(id, "cancel"))
	ok(spilt, "belt %s: a spill plays its cancel cue" % id)
	P.stun_t = 0.0
## Downs (or revives) the player and lets the match's audio director and the ramp run.
func _muffle_step(m: Match, down: bool) -> void:
	m.player.downed = down
	m.music_dir.tick(m, 0.0)
	await main.get_tree().create_timer(Sfx.MUFFLE_S + 0.2).timeout
## Ducking: a rival's ult cast in earshot dips the music and ambience buses;
## a knock in earshot dips them too; the dip is gone again after the hold and about a second.
func _duck_check(m: Match) -> void:
	var P: Hunter = m.player
	var rival: Hunter = null
	for h: Hunter in m.hunters:
		if h != P and h.team != P.team and rival == null: rival = h
	ok(rival != null, "setup: a rival Hunter to cast")
	if rival == null:
		return
	Sfx.listener = P.pos
	rival.pos = P.pos + Vector3(8, 0, 0)
	var mus := Sfx._duck_fx[0]
	CombatBus.ability_used.emit(rival, "check_x", "ultimate")
	await main.get_tree().create_timer(0.4).timeout
	var rules: Dictionary = Sfx.duck_rules
	var amb: AudioEffectAmplify = Sfx._duck_fx[1]
	var depth := float(rules["ult_db"])
	ok(mus.volume_db <= depth + 0.5 and amb.volume_db <= depth + 0.5,
		"a rival's ult dips the score and the ambience (%.1f / %.1f dB, rule %.1f)"
		% [mus.volume_db, amb.volume_db, depth])
	var back := float(rules["ult_hold_s"]) + float(rules["back_s"]) + 0.3
	await main.get_tree().create_timer(back).timeout
	ok(mus.volume_db > -0.5 and amb.volume_db > -0.5,
		"...and both are back about a second after the cast (%.1f dB)" % mus.volume_db)
	rival.pos = P.pos + Vector3(float(rules["range_m"]) + 20.0, 0, 0)
	CombatBus.ability_used.emit(rival, "check_x", "ultimate")
	await main.get_tree().create_timer(0.4).timeout
	ok(mus.volume_db > -0.5, "a rival's ult out of earshot does not duck (%.1f dB)" % mus.volume_db)
	rival.pos = P.pos + Vector3(8, 0, 0)
	Juice.knock(m, rival, P)
	await main.get_tree().create_timer(0.3).timeout
	ok(mus.volume_db < -3.0, "a knock call in earshot dips them (%.1f dB)" % mus.volume_db)
	await main.get_tree().create_timer(float(rules["knock_hold_s"]) + float(rules["back_s"]) + 0.3).timeout

func _step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

func _on_farm() -> bool:
	var sc: Script = main.current.get_script() if is_instance_valid(main.current) else null
	return sc != null and sc.resource_path.ends_with("home/home.gd")

func _check_zones(at: Vector3) -> void:
	var inside := at + Vector3(30, 0, 0)
	Sfx.set_room_zones([{"at": [inside.x, inside.z], "r": 5, "preset": "arch"}])
	Sfx.move_listener(at)
	ok(Sfx.room == "" and _step_bus(at) == "SFXWorld", "outside a zone the sound plays dry (%s)" % _step_bus(at))
	Sfx.move_listener(inside)
	var wet := _step_bus(inside)
	ok(Sfx.room == "arch" and wet == String(Sfx.ROOM_BUS), "inside a zone it goes through the room send (%s)" % wet)
	var bi := AudioServer.get_bus_index(Sfx.ROOM_BUS)
	ok(AudioServer.is_bus_effect_enabled(bi, 0), "...and the send's reverb is on")
	Sfx.move_listener(inside + Vector3(5.5, 0, 0))
	ok(Sfx.room == "arch", "just past the edge it holds on (no flutter)")
	Sfx.move_listener(at)
	ok(Sfx.room == "" and _step_bus(at) == "SFXWorld", "leaving the zone is dry again (%s)" % _step_bus(at))
	ok(not AudioServer.is_bus_effect_enabled(bi, 0), "...and the send's reverb is off")
	Sfx.move_listener(inside)
	ok(Sfx.room == "arch" and Sfx._bus_for(null, true) == "SFX", "a clear sound (no position) stays dry inside a zone")
	Sfx.set_room_zones([])
	for id in ["hollowcrown", "skyreach"]:
		var zones: Array = World.load_layout(id).get("sound_zones", [])
		var known := zones.all(func(z): return z["preset"] in Sfx.ROOMS)
		ok(not zones.is_empty() and known, "%s places sound zones with known presets (%d)" % [id, zones.size()])

## The bus a footstep at pos lands on.
func _step_bus(pos: Vector3) -> String:
	Sfx.last_played.erase("step0")
	Sfx.recent.erase("step0")
	Sfx.play("step0", pos, 0.0, 0.0)
	return String(Sfx.players[(Sfx.next + Sfx.POOL - 1) % Sfx.POOL].bus)
