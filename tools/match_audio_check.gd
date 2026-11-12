extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel).
## And the glider: each state (open, glide, dive, overheat, fold) plays its cue once, yours and another player's.
## And the mix (SfxMix): each kind of sound is on its own bus, a big event dips Music and Ambience about 6 dB
## and they recover; then the autoplay match runs LOUD_S and each bus's peak meter is reported (MATCHAUDIO BUS).

var main: Node
var fails := 0
var n := 0
const SETTLE := 4.0            # s: longer than the slowest match fade (the score's stems, 1.2s)
const LOUD_S := 12.0           # s of autoplay match the bus meters are read over

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
	_buses()
	await _big_event_duck(P)
	await _glider(P, "yours")
	var other: Hunter = m.hunters.filter(func(x): return x != P and not x.out)[0]
	other.remote = true
	other.pos = P.pos + Vector3(8, 0, 0)
	await _glider(other, "another player's")
	other.remote = false
	await _loudness(m)
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
	await main.get_tree().create_timer(SETTLE).timeout
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

## Each kind of sound plays on its own bus, set up in one place (SfxMix.BUSES).
func _buses() -> void:
	for bn in SfxMix.BUSES:
		var bi := AudioServer.get_bus_index(bn)
		var to := StringName(SfxMix.BUSES[bn])
		ok(bi > 0 and AudioServer.get_bus_send(bi) == to, "bus %s sends to %s" % [bn, to])
	var want := {"kin_happy": "Boki", "click": "UI", "ashwick_hurt": "Voice", "v_brute": "Voice", "rifle": "SFX"}
	for sname in want:
		ok(Sfx.mix.bus_for(sname, false) == StringName(want[sname]), "%s plays on %s" % [sname, want[sname]])
	ok(Sfx.mix.bus_for("kin_happy", true) == &"SFXFar", "a far sound of any kind goes through the muffled bus")

## A rival's ult tag dips Music and Ambience together by about 6 dB, and they are back within the recovery;
## your own team's tag does not dip them.
func _big_event_duck(P: Hunter) -> void:
	var r: Dictionary = Sfx.mix.rules["big_event"]
	Sfx.last_played.clear()
	Sfx.play("ult_tag_foe", P.pos)
	await main.get_tree().create_timer(float(r["in_s"]) + 0.1).timeout
	var amb_fx := AudioServer.get_bus_effect(AudioServer.get_bus_index("Ambience"), 0) as AudioEffectAmplify
	var dip := Sfx.mix.event_db()
	ok(dip <= -5.0 and dip >= -7.0 and is_equal_approx(amb_fx.volume_db, dip),
			"a rival's ult dips Music and Ambience about 6 dB (%.1f / %.1f dB)" % [dip, amb_fx.volume_db])
	await main.get_tree().create_timer(float(r["hold_s"]) + float(r["recover_s"]) + 0.1).timeout
	var back := Sfx.mix.event_db()
	ok(back > -0.2 and amb_fx.volume_db > -0.2, "...and they are back after %.1f s (%.2f dB)" % [r["recover_s"], back])
	Sfx.play("ult_tag_ally", P.pos)
	await main.get_tree().create_timer(0.2).timeout
	ok(Sfx.mix.event_db() > -0.2, "your own team's ult tag does not dip them")

## The match runs on its own for LOUD_S; each bus's peak meter (max and mean, dBFS) is reported. Only the
## master limiter is asserted (nothing past its ceiling); the levels are for reading.
func _loudness(m: Match) -> void:
	var names: Array = ["Master"] + SfxMix.BUSES.keys()
	var top := {}
	var sum := {}
	var frames := 0
	m.set_process(true)
	var until := Time.get_ticks_msec() + int(LOUD_S * 1000.0)
	while Time.get_ticks_msec() < until:
		await main.get_tree().process_frame
		frames += 1
		for bn in names:
			var bi := AudioServer.get_bus_index(bn)
			var pk := maxf(AudioServer.get_bus_peak_volume_left_db(bi, 0),
					AudioServer.get_bus_peak_volume_right_db(bi, 0))
			top[bn] = maxf(float(top.get(bn, -200.0)), pk)
			sum[bn] = float(sum.get(bn, 0.0)) + db_to_linear(pk)
	m.set_process(false)
	for bn in names:
		var mean := linear_to_db(maxf(sum[bn] / frames, 1e-10))
		print("MATCHAUDIO BUS %-8s max %6.1f dBFS  mean %6.1f dBFS" % [bn, top[bn], mean])
	var peak := float(top["Master"])
	ok(peak <= 0.0, "a match capture (%.0f s) stays under full scale on the master (%.1f dBFS)" % [LOUD_S, peak])

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

func _step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

func _on_farm() -> bool:
	var sc: Script = main.current.get_script() if is_instance_valid(main.current) else null
	return sc != null and sc.resource_path.ends_with("home/home.gd")
