extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel).
## The ultimate-ready chime (UltReadyCue): once per R coming back, only for you (never a rival's or a
## teammate's R), never on a match's first look, held while you're down until you're up, and set lower
## under a kill callout.
## Hunter callouts (HunterBarks): who hears which bark, the 6 s cooldown and the setting.
## And the abyss (tools/gen_sfx_abyss.py, AbyssSfx): a scripted walk off a Hollow Crown rim plays the whoosh
## then, with the glider, the catch (and the strain loop while it is overheated), or, without it, the fall-out;
## yours is 2D (heard with the listener 80 m away), a teammate's is positional (the fall-out carries further).
## And the glider: each state (open, glide, dive, overheat, fold) plays its cue once, yours and another player's.
## And TellCue: a rival's ground telegraph plays tell_foe where it lands, sized by its area; not yours, an
## ally's, an ultimate's, an aim mark's or a telegraph that is only being refreshed.
## Downed or out the world bus is muffled (and leaving the match lifts it); positional one-shots pan (a placed
## voice at the sound), UI ones stay plain.
## And the mix (SfxMix): each kind of sound is on its own bus, a big event dips Music and Ambience about 6 dB
## and they recover; then the autoplay match runs LOUD_S and each bus's peak meter is reported (MATCHAUDIO BUS).
## Footsteps (StepReach): a rival's heard at 15 m, not at its reach + 5 m, a sneaking rival's carry less, a
## teammate's quieter than a rival's, your own one level wherever the camera is.
## And the region beds: each region of the map has its own bed, another region crossfades it in over
## MusicDir.BED_FADE (never more than two beds), it holds over the void, and a fight sinks the Ambience bus.

var main: Node
var fails := 0
var n := 0
const SETTLE := 4.0            # s: longer than the slowest match fade (the score's stems, 1.2s)
const LOUD_S := 12.0           # s of autoplay match the bus meters are read over
const WALK_S := 8.0            # s: the longest an abyss walk is run
const ABYSS_NAMES := ["abyss_whoosh", "abyss_catch", "abyss_fallout"]

func ok(cond: bool, what: String) -> void:
	n += 1
	print("MATCHAUDIO %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.d["music"] = Save.d.get("music", [])
	await _abyss()
	Game.goto("match", {"autoplay": true, "teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
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
	var once := Sfx.voice_all.filter(func(p): return p.playing and Sfx.loops_forever(p.stream))
	ok(once.is_empty(), "a one-shot of a looping file does not loop (%d looping pool voices)" % once.size())
	Sfx.loop_start("boxhum_check", "revive_hum", P.pos)       # (as a deathbox revive does, keyed)
	ok(Sfx.match_voices() >= 2, "setup: the match has several voices going (%d)" % Sfx.match_voices())
	await _ult_chime(m, P)
	_ult_cues(m, P)
	_tell_cues(m, P)
	_buses()
	await _big_event_duck(P)
	_steps(m, P)
	await _region_beds(m, P)
	_barks(m, P)
	await _glider(P, "yours")
	var other: Hunter = m.hunters.filter(func(x): return x != P and not x.out)[0]
	other.remote = true
	other.pos = P.pos + Vector3(8, 0, 0)
	await _glider(other, "another player's")
	other.remote = false
	await _loudness(m)
	_panned(m, P)
	# going down muffles the world bus (a low-pass and a duck, 0.3 s ramp); a revive lifts it
	await _muffle_step(m, true)
	var dull := Sfx.muffle_state()
	ok(dull.fx and is_equal_approx(dull.db, Sfx.MUFFLE_DB) and is_equal_approx(dull.hz, Sfx.MUFFLE_HZ),
		"downed: the world bus is low-passed and ducked (%s)" % dull)
	var bus := AudioServer.get_bus_index("SFXWorld")
	var clear_kinds: bool = Sfx._bus_for(null, "wisp_hum") == &"SFX" and Sfx._bus_for(null, "ping") == &"UI"
	ok(clear_kinds and Sfx._bus_for(null, "kin_happy") == &"Boki" and Sfx._bus_for(null, "rifle") == &"SFXWorld",
		"the Wisp hum, pings and Boki voices skip the world bus")
	await _muffle_step(m, false)
	var clear := Sfx.muffle_state()
	ok(not clear.fx and is_zero_approx(clear.db) and is_equal_approx(clear.hz, SfxMix.MUFFLE_OPEN_HZ),
		"revived: the muffle is off again (%s)" % clear)
	await _muffle_step(m, true)
	ok(Sfx.muffle_state().fx and bus >= 0, "downed again: muffled")
	await _duck_check(m)
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
	var sunk := Sfx.mix.amb_duck.volume_db
	ok(sunk == 0.0, "the farm's ambience is not left sunk by the fight (%.1f dB)" % sunk)
	await main.get_tree().create_timer(Sfx.MUFFLE_S + 0.2).timeout
	ok(not Sfx.muffle_state().fx, "leaving the match while downed turns the muffle off")
	await main.get_tree().create_timer(SETTLE).timeout
	var left := Sfx.match_voices()      # the farm's own beds are not counted (Sfx.MATCH_BEDS)
	ok(left == 0, "after the fades nothing the match started is playing (%d)" % left)
	print("MATCHAUDIO DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _play(sname: String, pos = null) -> void:
	Sfx.last_played.clear()
	Sfx.recent.clear()
	Sfx.play(sname, pos, 0.0, 0.0)

func _quiet() -> void:
	for p in Sfx.voice_all:
		p.stop()

func _ult_chime(m: Match, P: Hunter) -> void:
	var mate: Hunter = null
	var rival: Hunter = null
	for h in m.hunters:
		if h != P and h.team == P.team: mate = h
		elif h.team != P.team: rival = h
	ok(P.ak != null and not P.ak.x_def().is_empty() and mate != null and rival != null,
		"setup: you have an R, a teammate and a rival")
	if mate == null or rival == null or P.ak == null:
		return
	P.ctrl = "local"          # (a bot could cast it the step it's back; you hold no keys here)
	var fresh := UltReadyCue.new()
	for h in [P, mate, rival]:
		h.lvl = maxi(h.lvl, int(Hunter.ULT_AT[0]))
		h.ak.cd["x"] = 0.0
	fresh.tick(m)
	ok(fresh.plays == 0, "a match's first look at an R already ready is quiet")
	var cue: UltReadyCue = m.ult_cue
	_step(m, 0.1)
	var before := cue.plays
	P.ak.cd["x"] = 0.8
	mate.ak.cd["x"] = 0.3
	rival.ak.cd["x"] = 0.3
	_step(m, 0.5)
	ok(HeroUlt.ready(mate.ak) and HeroUlt.ready(rival.ak) and cue.plays == before,
		"a teammate's and a rival's R coming back stays quiet (%d chimes)" % (cue.plays - before))
	_step(m, 0.5)
	ok(cue.plays == before + 1, "your R coming back chimes once (%d)" % (cue.plays - before))
	_step(m, 1.0)
	ok(cue.plays == before + 1, "...and only once while it stays ready (%d)" % (cue.plays - before))
	m.knock(P, rival, {})
	P.ak.cd["x"] = 0.3
	_step(m, 0.6)
	ok(P.downed and HeroUlt.ready(P.ak) and cue.plays == before + 1, "back while you're down: no chime yet")
	m.revive_hunter(P, mate)
	_step(m, 0.1)
	ok(cue.plays == before + 2, "...it plays once you're up (%d)" % (cue.plays - before))
	await main.get_tree().create_timer(0.2).timeout      # (Sfx spaces repeats in real ms)
	Sfx.play("kill")
	P.ak.cd["x"] = 0.05
	_step(m, 0.1)
	var want := UltReadyCue.VOL_DB + UltReadyCue.UNDER_CALLOUT_DB
	var under := Sfx.players.filter(func(p): return p.playing and p.stream == Sfx.streams[UltReadyCue.SOUND])
	ok(cue.plays == before + 3 and under.any(func(p): return is_equal_approx(p.volume_db, want)),
		"right after a kill callout it plays %.0f dB down" % UltReadyCue.UNDER_CALLOUT_DB)
	P.ctrl = "bot"

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

func _tell_cues(m: Match, P: Hunter) -> void:
	var R: Hunter = m.hunters.filter(func(x): return x != P and x.team != P.team and x.ak != null)[0]
	Sfx.listener = P.pos
	R.pos = P.pos + Vector3(40, 0, 0)                 # past hearing: only a cue at the landing spot can be heard
	var spot := P.pos + Vector3(3, 0, 0)
	ok(_tell(func(): R.ak.tele_circle(spot, 1.0, Color.RED, 0.5)),
			"a rival's circle 40 m off, landing 3 m from you, is heard where it lands")
	var small = _last_voice()
	_tell(func(): R.ak.tele_circle(spot, 4.0, Color.RED, 0.5))
	var big = _last_voice()
	ok(big.volume_db > small.volume_db + 3.0 and big.pitch_scale < small.pitch_scale,
			"...a bigger area is louder and lower (%.1f dB / %.2f vs %.1f dB / %.2f)" % [
				big.volume_db, big.pitch_scale, small.volume_db, small.pitch_scale])
	ok(_tell(func(): R.ak.tele_lane(P.pos + Vector3(-30, 0, 0), Vector2(1, 0), 60.0, 2.0, Color.RED, 0.5)),
			"a rival's lane is heard at its middle (starting 30 m off)")
	ok(_tell(func(): AimKit.circle(R, "tell_check", {"at": spot, "r": 2.0, "all": true})),
			"a rival's AimKit area everyone sees is heard when it starts")
	ok(not _tell(func(): AimKit.circle(R, "tell_check", {"at": spot, "r": 2.0, "all": true})),
			"...and not again while the kit refreshes it")
	ok(not _tell(func(): AimKit.lane(R, "tell_aim", {"from": spot, "len": 4.0})), "a rival's own-aim lane is silent")
	ok(not _tell(func(): AimKit.circle(R, "x_check", {"at": spot, "r": 2.0, "all": true})),
			"a rival's ultimate area is silent (UltCue has it)")
	R.ak.fuse = {"t": 1.0}
	ok(not _tell(func(): R.ak.tele_circle(spot, 2.0, Color.RED, 0.5)), "...and so is the R fuse ring")
	R.ak.fuse = {}
	ok(not _tell(func(): P.ak.tele_circle(spot, 2.0, Color.RED, 0.5)), "your own telegraph is silent")
	var team: int = R.team
	R.team = P.team
	ok(not _tell(func(): R.ak.tele_circle(spot, 2.0, Color.RED, 0.5)), "an ally's telegraph is silent")
	R.team = team
	AimKit.clear(R)

## Runs `cast` with the gap and stacking windows clear; whether it played tell_foe.
func _tell(cast: Callable) -> bool:
	Sfx.last_played.clear()
	Sfx.recent.clear()
	cast.call()
	return Sfx.last_played.has("tell_foe")

func _last_voice():
	return Sfx.last_voice      # (a placed one-shot plays on a 3D spot, not the plain pool)

## Each kind of sound plays on its own bus, set up in one place (SfxMix.BUSES).
func _buses() -> void:
	for bn in SfxMix.BUSES:
		var bi := AudioServer.get_bus_index(bn)
		var to := StringName(SfxMix.BUSES[bn])
		ok(bi > 0 and AudioServer.get_bus_send(bi) == to, "bus %s sends to %s" % [bn, to])
	var want := {"kin_happy": "Boki", "click": "UI", "ashwick_hurt": "Voice", "v_brute": "Voice", "rifle": "SFXWorld"}
	for sname in want:
		ok(Sfx.mix.bus_for(sname, false, false) == StringName(want[sname]), "%s plays on %s" % [sname, want[sname]])
	ok(Sfx.mix.bus_for("kin_happy", false, true) == &"SFXFar", "a far sound of any kind is low-passed")
	ok(Sfx.mix.bus_for("kin_happy", true, true) == &"SFXMuffled", "...and one behind terrain through the muffled one")

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

## Footsteps by distance, both the foot's contact step and the surface step (Juice.footstep).
func _steps(m: Match, P: Hunter) -> void:
	var R: Hunter = m.hunters.filter(func(x): return x != P and x.team != P.team)[0]
	var far := StepReach.RIVAL_M + 5.0
	Sfx.listener = P.pos
	_quiet()      # (the ult cues above left far voices ringing)
	ok(not is_nan(_step_db(R, P, 15.0, true)) and not is_nan(_step_db(R, P, 15.0, false)),
			"a rival's footsteps (contact and surface) are heard 15 m away, seen or not (unseen %s)" % R.unseen)
	ok(is_nan(_step_db(R, P, far, true)) and is_nan(_step_db(R, P, far, false)),
			"...and not at their reach + 5 m (%.0f m)" % far)
	R.crouch = true
	var sneak := StepReach.reach(R)
	ok(sneak < StepReach.RIVAL_M and is_nan(_step_db(R, P, 15.0, true)) and is_nan(_step_db(R, P, 15.0, false)),
			"a sneaking rival's steps carry %.0f m, not %.0f m: not heard 15 m away" % [sneak, StepReach.RIVAL_M])
	ok(not is_nan(_step_db(R, P, sneak - 2.0, true)), "...but heard %.0f m away" % (sneak - 2.0))
	R.crouch = false
	var rival := _step_db(R, P, 10.0, true)
	var team := R.team
	R.team = P.team
	var mate := _step_db(R, P, 10.0, true)
	R.team = team
	ok(mate < rival - 3.0, "a teammate's step 10 m away is quieter than a rival's (%.1f vs %.1f dB)" % [mate, rival])
	var own_near := _step_db(P, P, 0.0, true)
	Sfx.listener = P.pos + Vector3(15, 0, 0)
	var own_far := _step_db(P, P, 0.0, true)
	Sfx.listener = P.pos
	ok(not is_nan(own_near) and is_equal_approx(own_near, own_far),
			"your own step plays at one level wherever the camera is (%.1f / %.1f dB)" % [own_near, own_far])

## The level (dB) of one step of h placed `d` m from P along x (h == P: where P stands), NAN when nothing played.
## contact: the foot's plain step (StepReach.contact), else the surface step (Juice.footstep).
func _step_db(h: Hunter, P: Hunter, d: float, contact: bool) -> float:
	if h != P:
		h.pos = P.pos + Vector3(d, 0, 0)
	Sfx.last_played.clear()
	Sfx.recent.clear()
	if contact:
		StepReach.contact(h)
	else:
		Juice.footstep(h)
	if not Sfx.last_played.keys().any(func(k): return String(k).contains("step")):
		return NAN
	return Sfx.last_voice.volume_db

## Each region's own bed, the crossfade between two of them, the two-bed cap and the fight ducking. The
## match is held still: the case moves the player and ticks MusicDir itself (its clock with it), and puts
## every Hunter back where it stood (the listener stays there for the glider's cues).
func _region_beds(m: Match, P: Hunter) -> void:
	var w: World = m.world
	var stood := m.hunters.map(func(h): return h.pos)
	ok(m.biomes != null and w.regions.size() >= 9, "setup: an authored map with its regions (%d)" % w.regions.size())
	if m.biomes == null:
		return
	for R in w.regions:
		var bed := String(R.get("bed", ""))
		var on_file := ResourceLoader.exists("res://audio/amb_%s.ogg" % bed)
		ok(on_file, "region %s has its own bed on file (%s)" % [R["id"], bed])
	var spots := {}
	for rid in ["crown", "thorn", "frostgate", "lark"]:
		spots[rid] = _region_spot(m, rid)
	P.dropping = false
	_bed_at(m, P, spots["crown"])
	ok(Sfx.amb_name == "heart", "the Crown plays the Heart's hum (%s)" % Sfx.amb_name)
	await _wait(MusicDir.BED_FADE + 0.4)
	ok(_beds_on() == 1 and _bed_db("heart") > Sfx.AMB_DB - 0.5,
			"...alone and at full after the crossfade (%d beds)" % _beds_on())
	_bed_at(m, P, spots["thorn"])
	ok(Sfx.amb_name == "woods", "into Thornwood: the bed swaps to the wood's insects (%s)" % Sfx.amb_name)
	await _wait(MusicDir.BED_FADE * 0.5)
	var rising := _bed_db("woods")
	var falling := _bed_db("heart")
	ok(_beds_on() == 2 and rising < Sfx.AMB_DB - 2.0 and falling < Sfx.AMB_DB - 2.0 and minf(rising, falling) > -40.0,
			"halfway through the crossfade both beds sound, neither at full (woods %.1f, heart %.1f dB)"
			% [rising, falling])
	await _wait(MusicDir.BED_FADE * 0.5 + 0.4)
	ok(_beds_on() == 1 and _bed_db("woods") > Sfx.AMB_DB - 0.5,
			"...and after %.0f s only the wood's bed is left" % MusicDir.BED_FADE)
	var most := 0
	for rid in ["frostgate", "lark", "crown"]:      # three regions in a second, as on a fast glide
		_bed_at(m, P, spots[rid])
		most = maxi(most, _beds_on())
		await _wait(0.3)
		most = maxi(most, _beds_on())
	ok(most <= 2 and _bed_db("heart") > -80.0 and Sfx.amb_name == "heart",
			"three regions in a second: at most two beds at once (%d), the last one rising" % most)
	_bed_at(m, P, Vector3(-8, 0, -8))
	ok(Sfx.amb_name == "heart", "off the islands the last bed holds (%s)" % Sfx.amb_name)
	var bus := AudioServer.get_bus_index("Ambience")
	var stages := range(AudioServer.get_bus_effect_count(bus)).map(func(i): return AudioServer.get_bus_effect(bus, i))
	ok(Sfx.mix.amb_duck in stages, "the fight ducking stage sits on the Ambience bus")
	P.pos = spots["crown"]
	for h in m.hunters:
		if h != P:
			h.pos = P.pos + Vector3(60, 0, 0)       # no rival in sight: only the fight moves the beds
	P.hurt_at = m.time
	_tick(m, 1.0)
	var sink: float = Sfx.mix.amb_duck.volume_db
	ok(sink <= Sfx.AMB_DUCK_DB + 0.5, "a fight sinks the beds (%.1f dB)" % sink)
	_tick(m, MusicDir.FIGHT_HOLD + 5.0)
	var up: float = Sfx.mix.amb_duck.volume_db
	ok(up > -0.5, "...and they come back once it is over (%.1f dB)" % up)
	P.hurt_at = m.time
	_tick(m, 1.0)      # left sunk on purpose: the match leaving must let go of it (checked on the farm)
	for i in m.hunters.size():
		m.hunters[i].pos = stood[i]

## A standing spot in the region: its first island's point of interest.
func _region_spot(m: Match, rid: String) -> Vector3:
	var R: Dictionary = m.world.regions.filter(func(x): return x["id"] == rid)[0]
	for I in m.world.islands:
		if I["id"] in R["islands"]:
			var at := Vector3(I["poi_at"].x + 0.5, 0, I["poi_at"].y + 0.5)
			ok(m.biomes.hot.region_at(at) >= 0, "setup: a spot in %s" % rid)
			return at
	return Vector3.INF

## Stands the player at `at` and lets MusicDir look round at once.
func _bed_at(m: Match, P: Hunter, at: Vector3) -> void:
	P.pos = at
	m.music_dir.amb_t = 0.0
	m.music_dir.tick(m, 0.05)

## Moves the match clock and MusicDir on together, a twentieth of a second at a time.
func _tick(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.time += 0.05
		m.music_dir.tick(m, 0.05)
		t += 0.05

func _wait(secs: float) -> void:
	await main.get_tree().create_timer(secs).timeout

## The volume (dB) of the main bed player sounding audio/amb_<bed>.ogg; -80 if none is.
func _bed_db(bed: String) -> float:
	for ap in Sfx.ambs:
		if ap.playing and ap.stream.resource_path.ends_with("/amb_%s.ogg" % bed):
			return ap.volume_db
	return -80.0

func _beds_on() -> int:
	return Sfx.ambs.filter(func(ap): return ap.playing).size()

## Hunter callouts: yours (ult back, low health, a knock, your Boki down) only for you, a 6 s cooldown per Hunter,
## a teammate's "Boki down" heard 40 m away at the teammate, a rival's never, nothing with the setting off.
func _barks(m: Match, P: Hunter) -> void:
	m.barks = HunterBarks.new()
	var B := m.barks
	var bark_of := func(h: Hunter, kind: String): return "%s_call_%s" % [h.arch, kind]
	Sfx.listener = P.pos
	P.hp = P.max_hp      # (the parts above leave you hurt: no "low" bark here)
	P.lvl = maxi(P.lvl, int(Hunter.ULT_AT[0]))
	P.ak.cd["x"] = 5.0
	B.tick(m)
	ok(B.plays.is_empty(), "no bark while your ultimate is cooling down (%s)" % [B.plays])
	P.ak.cd["x"] = 0.0
	Sfx.last_played.clear()
	B.tick(m)
	var heard := Sfx.last_played.has(bark_of.call(P, "ult"))
	ok(B.plays == [["ult", P.nid]] and heard, "your ultimate back: one bark (%s)" % [B.plays])
	B.knock_landed(m)
	ok(B.plays.size() == 1, "a knock 0 s later stays quiet (the 6 s cooldown)")
	m.time += HunterBarks.COOLDOWN_S + 0.1
	B.knock_landed(m)
	ok(B.plays.back() == ["knock", P.nid], "...and barks once the cooldown is over")
	m.time += HunterBarks.COOLDOWN_S + 0.1
	var hp := P.hp
	P.hp = P.max_hp * 0.2
	B.tick(m)
	m.time += HunterBarks.COOLDOWN_S + 0.1
	B.tick(m)
	var low_pct := int(HunterBarks.LOW_SHARE * 100)
	ok(B.plays.count(["low", P.nid]) == 1, "low health: one bark per drop under %d%%" % low_pct)
	P.hp = hp
	m.time += HunterBarks.COOLDOWN_S + 0.1
	Sfx.last_played.clear()
	KinNet.on_event(m, ["kcmd", "down", P.kin.nid, P.pos.x, P.pos.y, P.pos.z, ""])
	heard = Sfx.last_played.has(bark_of.call(P, "boki"))
	ok(B.plays.back() == ["boki", P.nid] and heard, "your Boki down: you call it")
	var voiced := func(x): return x.team != P.team and x.ak != null and Sfx.ensure(bark_of.call(x, "boki"))
	var other: Hunter = m.hunters.filter(voiced)[0]
	var team := other.team
	var theirs := Kin.new()
	theirs.owner_h = other
	other.pos = P.pos + Vector3(40, 0, 0)
	var before := B.plays.size()
	B.boki_down(m, theirs)
	ok(B.plays.size() == before, "a rival's Boki down: no call (%s)" % [B.plays])
	other.team = P.team
	Sfx.last_played.clear()
	B.boki_down(m, theirs)
	ok(B.plays.back() == ["boki", other.nid] and Sfx.last_played.has(bark_of.call(other, "boki")),
			"a teammate's Boki down 40 m away: the squad hears the teammate call it")
	ok(B.plays.all(func(p): return p[0] == "boki" or p[1] == P.nid), "only \"Boki down\" is heard from another Hunter")
	Settings.v["hunter_barks"] = false
	m.time += HunterBarks.COOLDOWN_S + 0.1
	before = B.plays.size()
	B.knock_landed(m)
	B.boki_down(m, theirs)
	Settings.v.erase("hunter_barks")
	ok(B.plays.size() == before, "Hunter callouts off: no bark (%s)" % [B.plays])
	other.team = team
	theirs.free()

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

## A sound with a place plays on a voice placed there, so the camera pans it; a UI sound on a plain voice.
func _panned(m: Match, P: Hunter) -> void:
	_quiet()
	Sfx.listener = P.pos
	var at := P.pos + Vector3(6.0, 0, 0)
	_play("land", at)
	var v = Sfx.last_voice
	ok(m.get_viewport().get_camera_3d() != null and v is AudioStreamPlayer3D
		and (v as AudioStreamPlayer3D).position.is_equal_approx(at),
		"a sound 6 m to your side plays placed there (%s)" % v)
	_play("click")
	ok(Sfx.last_voice is AudioStreamPlayer and not Sfx.last_voice is AudioStreamPlayer3D,
		"a UI sound (no place) plays on a plain voice")
	_quiet()

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
	var mus := Sfx.mix._duck_fx[0]
	CombatBus.ability_used.emit(rival, "check_x", "ultimate")
	await main.get_tree().create_timer(0.4).timeout
	var rules: Dictionary = Sfx.duck_rules
	var amb: AudioEffectAmplify = Sfx.mix._duck_fx[1]
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

# ---------------------------------------------------------------- the abyss
func _abyss() -> void:
	var am := Match.new()
	main.add_child(am)
	await am.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	am.set_process(false)
	for i in 30:
		am.step(Match.DT)
	var P: Hunter = am.player
	var other: Hunter = null
	for o in am.hunters:
		if o != P:
			o.ctrl = "idle"
			o.teleport(Vector3(-500, 50, -500))
			other = o
	for mb in am.mobs:
		mb.queue_free()
	am.mobs.clear()
	var rim := _rim(am.world)
	ok(am.map_name == "The Hollow Crown" and not rim.is_empty(), "abyss: a rim on %s" % am.map_name)
	if not rim.is_empty():
		var jump := _walk(am, P, rim, false, false)
		ok(jump.find("abyss_whoosh") == 0 and jump.has("abyss_fallout") and not jump.has("abyss_catch"),
			"a walk off the rim: whoosh, then the fall-out %s" % [jump])
		var glide := _walk(am, P, rim, true, false)
		ok(glide.find("abyss_whoosh") == 0 and glide.find("abyss_catch") == 1 and not glide.has("abyss_fallout"),
			"...gliding: whoosh, then the catch %s" % [glide])
		var hot := _walk(am, P, rim, true, true)
		ok(hot.find("abyss_catch") == 1 and hot.has("strain"),
			"...an overheated glider lifting: the catch and the strain loop %s" % [hot])
		_teammate(am, other, rim)
	am.queue_free()
	for i in 3:
		await main.get_tree().process_frame

## The player on the island 2 m in from the lip, walking out and falling; scripts the glider when asked
## (cold: overheated). Returns the abyss sounds in the order first heard ("strain" if its loop ran).
## The listener is 80 m away, so only a 2D sound is heard.
func _walk(am: Match, P: Hunter, rim: Dictionary, glide: bool, cold: bool) -> Array:
	var dv: Vector2 = rim["dir"]
	var start: Vector2 = rim["lip"] - dv * 2.0
	P.out = false
	P.teleport(Vector3(start.x, rim["y"], start.y))
	P.grounded = true
	P.vel = Vector3.ZERO
	P.gliding = false
	P.glide_fuel = 1.0
	P.hp = P.max_hp
	Sfx.listener = P.pos + Vector3(80, 0, 0)
	Sfx.last_played.clear()
	Sfx.recent.clear()
	am.opts["god"] = true          # a fall-out puts you back instead of ending the run
	var heard := []
	var key := "abyss_strain%d" % P.get_instance_id()
	var t := 0.0
	var done := func() -> bool:
		return heard.has("abyss_fallout") or (heard.has("abyss_catch") and (not cold or heard.has("strain")))
	while t < WALK_S and not done.call():
		P.inp["move"] = dv
		if glide and heard.has("abyss_whoosh"):
			P.inp["glide"] = true
			P.inp["glide_btn"] = true
			if cold:
				P.glide_fuel = 0.0
		am.step(Match.DT)
		t += Match.DT
		for n in ABYSS_NAMES:
			if Sfx.last_played.has(n) and not heard.has(n):
				heard.append(n)
		if Sfx.loop_on(key) and not heard.has("strain"):
			heard.append("strain")
	P.inp["glide"] = false
	P.inp["glide_btn"] = false
	P.inp["move"] = Vector2.ZERO
	Sfx.loop_stop(key)
	return heard

## A teammate (a remote hunter, its fall in the snapshots) falling past the lip: positional,
## and the fall-out carries further.
func _teammate(am: Match, o: Hunter, rim: Dictionary) -> void:
	var out_at: Vector2 = rim["lip"] + Vector2(rim["dir"]) * 3.0
	var heard := {}
	for case in [["whoosh", 5.0], ["whoosh", 30.0], ["fallout", 30.0], ["fallout", 60.0]]:
		o.remote = true
		o.out = false
		o.net_t = -1.0
		o.pos = Vector3(out_at.x, rim["y"] - 3.0, out_at.y)
		o.vel = Vector3(0, -8, 0)
		o.grounded = false
		o.update_lip()
		o.abyss_sfx = AbyssSfx.new()
		Sfx.listener = o.pos + Vector3(case[1], 0, 0)
		Sfx.last_played.clear()
		Sfx.recent.clear()
		o.abyss_sfx.tick(o, Match.DT)
		if case[0] == "fallout":
			o.out = true
			o.below_lip = false
			o.abyss_sfx.tick(o, Match.DT)
		heard["%s %d" % case] = Sfx.last_played.has("abyss_" + String(case[0]))
	o.remote = false
	ok(heard["whoosh 5"] and not heard["whoosh 30"],
		"a teammate's whoosh is positional: heard at 5 m, not at 30 m %s" % [heard])
	ok(heard["fallout 30"] and not heard["fallout 60"],
		"...their fall-out carries further: heard at 30 m, not at 60 m")

## A lipped rim: {lip: the lip's edge (x, z), dir: out over the void, y: the island's height there};
## a tile with void for two tiles beyond it and three tiles of flat ground behind it.
func _rim(w: World) -> Dictionary:
	for z in range(4, w.h - 4):
		for x in range(4, w.w - 4):
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _flat(w, x, z, d, -3, 0) and _void(w, x, z, d, 1, 2):
					var lip := Vector2(x + 0.5 + 0.5 * d.x, z + 0.5 + 0.5 * d.y)
					return {"lip": lip, "dir": Vector2(d), "y": w.ground_at(x + 0.5, z + 0.5)}
	return {}

func _flat(w: World, x: int, z: int, d: Vector2i, from: int, to: int) -> bool:
	var y := w.ground_at(x + 0.5, z + 0.5)
	for k in range(from, to + 1):
		var i := w.idx(x + d.x * k, z + d.y * k)
		var gy := w.ground_at(x + 0.5 + d.x * k, z + 0.5 + d.y * k)
		if w.kind[i] != World.T_GROUND or w.sheer.has(i) or w.stairs.has(i) or absf(gy - y) > 0.01:
			return false
	return true

func _void(w: World, x: int, z: int, d: Vector2i, from: int, to: int) -> bool:
	for k in range(from, to + 1):
		if w.kind[w.idx(x + d.x * k, z + d.y * k)] != World.T_VOID:
			return false
	return true
