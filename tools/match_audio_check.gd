extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel).
## The ultimate-ready chime (UltReadyCue; your E's tick too, _e_tick): once per R coming back, only for you
## (never a rival's or a teammate's R), never on a match's first look, held while you're down until you're up,
## and set lower under a kill callout.
## And the abyss (tools/gen_sfx_abyss.py, AbyssSfx): a scripted walk off a Hollow Crown rim plays the whoosh
## then, with the glider, the catch (and the strain loop while it is overheated), or, without it, the fall-out;
## yours is 2D (heard with the listener 80 m away), a teammate's is positional (the fall-out carries further).
## Hunter callouts (HunterBarks): who hears which bark, the 6 s cooldown and the setting.
## And the glider: each state (open, glide, dive, overheat, fold) plays its cue once, yours and another player's.
## And Motley's hover hum (no footsteps): held while he moves, swelling and rising with speed, gone when still.
## And the mix (SfxMix): each kind of sound is on its own bus, a big event dips Music and Ambience about 6 dB
## and they recover; then the autoplay match runs LOUD_S and each bus's peak meter is reported (MATCHAUDIO BUS).
## And TellCue: a rival's ground telegraph plays tell_foe where it lands, sized by its area; not yours, an
## ally's, an ultimate's, an aim mark's or a telegraph that is only being refreshed.
## And a broken cast's wind-up sound ends within 0.1 s, one interrupt per kit (tools/match_audio_interrupts.gd).
## Footsteps (StepReach): a rival's heard at 15 m, not at its reach + 5 m, a sneaking rival's carry less, a
## teammate's quieter than a rival's, your own one level wherever the camera is.
## And the carry cues (CarrySfx): the swap's two notes in order, a claim's lock-in, a steal heard by its owner, the
## thief and a squad nearby but not across the map, and one take per burst (MIN_GAP).
## And a broken cast's wind-up sound ends within 0.1 s, one interrupt per kit (tools/match_audio_interrupts.gd).

var main: Node
var fails := 0
var n := 0
const SETTLE := 4.0            # s: longer than the slowest match fade (the score's stems, 1.2s)
const LOUD_S := 12.0           # s of autoplay match the bus meters are read over
const REPEAT_GAP_MS := 200     # ms of real time between two chimes: past Sfx.STACK_MS, so not stacked
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
	var p_v: Hunter = m.player
	var k: Kin = p_v.kin
	ok(k != null, "setup: the player has a Boki")
	if k == null:
		main.get_tree().quit(1)
		return
	var key := "rescue%d" % k.get_instance_id()
	# the Boki goes down beside you and you run into it: the rescue's hum starts and follows the carry
	k.pos = p_v.pos + Vector3(0.6, 0, 0)
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
	Sfx.play("revive_hum", p_v.pos)
	var once := Sfx.players.filter(func(p): return p.playing and Sfx.loops_forever(p.stream))
	ok(once.is_empty(), "a one-shot of a looping file does not loop (%d looping pool voices)" % once.size())
	Sfx.loop_start("boxhum_check", "revive_hum", p_v.pos)       # (as a deathbox revive does, keyed)
	ok(Sfx.match_voices() >= 2, "setup: the match has several voices going (%d)" % Sfx.match_voices())
	_shields(m, p_v)
	_barks(m, p_v)
	await _ult_chime(m, p_v)
	_ult_cues(m, p_v)
	_buses()
	await _muffle(m, p_v)
	await _big_event_duck(p_v)
	_tell_cues(m, p_v)
	_steps(m, p_v)
	await _carry(m, p_v)
	await _glider(p_v, "yours")
	await _hover(p_v, "yours")
	var other: Hunter = m.hunters.filter(func(x): return x != p_v and not x.out)[0]
	await load("res://tools/match_audio_interrupts.gd").new().run(self, m, p_v, other)
	other.remote = true
	other.pos = p_v.pos + Vector3(8, 0, 0)
	await _glider(other, "another player's")
	await _hover(other, "another player's")
	other.remote = false
	await _loudness(m)
	# the weather bed (AmbBeds) is up, and the end-of-match fade below takes it away with the rest
	m.music_dir.beds.tick(m, p_v)
	ok(Sfx.amb_layers.has("gust"), "the match's weather bed starts (amb layers: %s)" % str(Sfx.amb_layers.keys()))
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
	ok(not Sfx.mix.muffle_state().on, "the world is clear again once the match is left")
	var left := Sfx.match_voices()      # the farm's own beds are not counted (Sfx.MATCH_BEDS)
	ok(left == 0, "after the fades nothing the match started is playing (%d)" % left)
	print("MATCHAUDIO DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _ult_chime(m: Match, p_v: Hunter) -> void:
	var mate: Hunter = null
	var rival: Hunter = null
	for h in m.hunters:
		if h != p_v and h.team == p_v.team: mate = h
		elif h.team != p_v.team: rival = h
	ok(p_v.ak != null and not p_v.ak.x_def().is_empty() and mate != null and rival != null,
		"setup: you have an R, a teammate and a rival")
	if mate == null or rival == null or p_v.ak == null:
		return
	p_v.ctrl = "local"          # (a bot could cast it the step it's back; you hold no keys here)
	p_v.ak.cd["e"] = 99.0       # (E's own tick is _e_tick's; kept out of the R rows)
	var fresh := UltReadyCue.new()
	for h in [p_v, mate, rival]:
		h.lvl = maxi(h.lvl, int(Hunter.ULT_AT[0]))
		h.ak.cd["x"] = 0.0
	fresh.tick(m)
	ok(fresh.plays == 0, "a match's first look at an R already ready is quiet")
	var cue: UltReadyCue = m.ult_cue
	_step(m, 0.1)
	var before := cue.plays
	p_v.ak.cd["x"] = 0.8
	mate.ak.cd["x"] = 0.3
	rival.ak.cd["x"] = 0.3
	_step(m, 0.5)
	ok(HeroUlt.ready(mate.ak) and HeroUlt.ready(rival.ak) and cue.plays == before,
		"a teammate's and a rival's R coming back stays quiet (%d chimes)" % (cue.plays - before))
	_step(m, 0.5)
	ok(cue.plays == before + 1, "your R coming back chimes once (%d)" % (cue.plays - before))
	_step(m, 1.0)
	ok(cue.plays == before + 1, "...and only once while it stays ready (%d)" % (cue.plays - before))
	var e_down := cue.e_plays
	m.knock(p_v, rival, {})
	p_v.ak.cd["x"] = 0.3
	p_v.ak.cd["e"] = 0.3        # (E back while you're down too: _e_tick checks it stayed quiet)
	_step(m, 0.6)
	ok(p_v.downed and HeroUlt.ready(p_v.ak) and cue.plays == before + 1, "back while you're down: no chime yet")
	m.revive_hunter(p_v, mate)
	_step(m, 0.1)
	ok(cue.plays == before + 2, "...it plays once you're up (%d)" % (cue.plays - before))
	await _wait_real_ms(REPEAT_GAP_MS)
	Sfx.play("kill")
	p_v.ak.cd["x"] = 0.05
	_step(m, 0.1)
	var want := UltReadyCue.VOL_DB + UltReadyCue.UNDER_CALLOUT_DB
	var under := Sfx.players.filter(func(p): return p.playing and p.stream == Sfx.streams[UltReadyCue.SOUND])
	ok(cue.plays == before + 3 and under.any(func(p): return is_equal_approx(p.volume_db, want)),
		"right after a kill callout it plays %.0f dB down" % UltReadyCue.UNDER_CALLOUT_DB)
	_e_tick(m, p_v, e_down)
	p_v.ctrl = "bot"

## Your E back: an E that came back while you were down (_ult_chime's knock) stays quiet once you're up; its own
## tick once; with R back the same step, R first and E at least GAP later.
func _e_tick(m: Match, p_v: Hunter, e_down: int) -> void:
	var cue: UltReadyCue = m.ult_cue
	p_v.ak.cd["x"] = 99.0
	_step(m, UltReadyCue.MUTE_BACK + 0.2)     # (past the revive above)
	ok(cue.e_plays == e_down, "an E back while you're down stays quiet when you're up (%d)" % (cue.e_plays - e_down))
	p_v.ak.cd["e"] = 99.0
	_step(m, 0.1)
	var e0 := cue.e_plays
	p_v.ak.cd["e"] = 0.05
	_step(m, 0.3)
	var heard := Sfx.last_played.has(UltReadyCue.E_SOUND)
	ok(cue.e_plays == e0 + 1 and heard, "your E coming back ticks once (%d)" % (cue.e_plays - e0))
	var r0 := cue.plays
	p_v.ak.cd["e"] = 0.05
	p_v.ak.cd["x"] = 0.05
	_step(m, 0.15)
	ok(cue.plays == r0 + 1 and cue.e_plays == e0 + 1, "E and R back together: R first, E waits")
	_step(m, 0.3)
	ok(cue.e_plays == e0 + 2, "...then E, %.1f s on" % UltReadyCue.GAP)
## A hit on a shield plays that material's thunk, the hit that takes the last of it plays its crack and clears the
## material; a rival's shield is heard only near, yours always; the shield running out clears the material too.
func _shields(m: Match, p: Hunter) -> void:
	var r: Hunter = m.hunters.filter(func(x): return x != p and x.team != p.team)[0]
	p.inv_t = 0.0
	p.hp = p.max_hp        # the ult-ready part revived you low; three breaks must not down you
	for kind in ["ward", "cloak", "molten"]:
		p.shield = 30.0
		p.shield_kind = "" if kind == "ward" else kind
		for part in ["hit", "break"]:
			var cue := "shield_%s_%s" % [kind, part]
			ok(Sfx.ensure(cue), "%s is a sound on file" % cue)
			Sfx.last_played.clear()
			p.hurt(10.0 if part == "hit" else 40.0, r, {})
			var shield_cues := Sfx.last_played.keys().filter(func(k): return k.begins_with("shield_"))
			ok(shield_cues == [cue], "your %s shield: a hit plays %s (%s)" % [kind, cue, shield_cues])
		ok(p.shield_kind == "" and p.shield <= 0.0, "...and the break clears the material")
	Sfx.listener = p.pos
	r.shield = 30.0
	r.shield_kind = "molten"
	r.pos = p.pos + Vector3(70, 0, 0)
	Sfx.last_played.clear()
	r.hurt(10.0, p, {})
	ok(Sfx.last_played.is_empty(), "a rival's shield 70 m away is out of earshot")
	r.pos = p.pos + Vector3(5, 0, 0)
	r.hurt(10.0, p, {})
	ok(Sfx.last_played.has("shield_molten_hit"), "...and 5 m away its thunk is heard")
	r.shield_t = 0.01
	r.sim(0.1)
	ok(r.shield <= 0.0 and r.shield_kind == "", "a shield that runs out clears the material")

## An ultimate is heard before it is seen: a rival's cue carries 40 m (not 70) with the rival tag, yours has the
## ally tag, all through the match's own pool voices (so the match leaving tears them down with the rest).
func _ult_cues(m: Match, p: Hunter) -> void:
	var rivals := m.hunters.filter(func(x): return x != p and x.team != p.team and x.ak != null)
	ok(not rivals.is_empty(), "setup: a rival Hunter with a kit")
	if rivals.is_empty():
		return
	var r: Hunter = rivals[0]
	Sfx.listener = p.pos
	r.pos = p.pos + Vector3(40, 0, 0)
	Sfx.last_played.clear()
	UltCue.cast(r.ak)
	var heard := Sfx.last_played.has(r.arch + "_ult_cue") and Sfx.last_played.has("ult_tag_foe")
	ok(heard and not Sfx.last_played.has("ult_tag_ally"),
			"a rival's ultimate 40 m away is heard, with the rival tag (%s)" % [Sfx.last_played.keys()])
	r.pos = p.pos + Vector3(70, 0, 0)
	Sfx.last_played.clear()
	UltCue.cast(r.ak)
	ok(Sfx.last_played.is_empty(), "...and 70 m away it is out of earshot")
	Sfx.last_played.clear()
	UltCue.cast(p.ak)
	heard = Sfx.last_played.has("ult_tag_ally") and Sfx.last_played.has(p.arch + "_ult_cue")
	ok(heard, "your own team's cue has the ally tag")

## Each kind of sound plays on its own bus, set up in one place (SfxMix.BUSES).
func _buses() -> void:
	for bn in SfxMix.BUSES:
		var bi := AudioServer.get_bus_index(bn)
		var to := StringName(SfxMix.BUSES[bn])
		ok(bi > 0 and AudioServer.get_bus_send(bi) == to, "bus %s sends to %s" % [bn, to])
	var want := {"kin_happy": "Boki", "click": "UI", "ashwick_hurt": "Voice", "v_brute": "Voice", "rifle": "SFX"}
	for sname in want:
		ok(Sfx.mix.bus_for(sname, false, false) == StringName(want[sname]), "%s plays on %s" % [sname, want[sname]])
	ok(Sfx.mix.bus_for("kin_happy", false, true) == &"SFXFar", "a far sound of any kind is low-passed")
	ok(Sfx.mix.bus_for("kin_happy", true, true) == &"SFXMuffled", "...and one behind terrain through the muffled one")

## A rival's ult tag dips Music and Ambience together by about 6 dB, and they are back within the recovery;
## your own team's tag does not dip them.
func _big_event_duck(p: Hunter) -> void:
	var r: Dictionary = Sfx.mix.rules["big_event"]
	Sfx.last_played.clear()
	Sfx.play("ult_tag_foe", p.pos)
	await main.get_tree().create_timer(float(r["in_s"]) + 0.1).timeout
	var amb_fx := AudioServer.get_bus_effect(AudioServer.get_bus_index("Ambience"), 0) as AudioEffectAmplify
	var dip := Sfx.mix.event_db()
	ok(dip <= -5.0 and dip >= -7.0 and is_equal_approx(amb_fx.volume_db, dip),
			"a rival's ult dips Music and Ambience about 6 dB (%.1f / %.1f dB)" % [dip, amb_fx.volume_db])
	await main.get_tree().create_timer(float(r["hold_s"]) + float(r["recover_s"]) + 0.1).timeout
	var back := Sfx.mix.event_db()
	ok(back > -0.2 and amb_fx.volume_db > -0.2, "...and they are back after %.1f s (%.2f dB)" % [r["recover_s"], back])
	Sfx.play("ult_tag_ally", p.pos)
	await main.get_tree().create_timer(0.2).timeout
	ok(Sfx.mix.event_db() > -0.2, "your own team's ult tag does not dip them")

## The match runs on its own for LOUD_S; each bus's peak meter (max and mean, dBFS) is reported. Only the
## master limiter is asserted (nothing past its ceiling); the levels are for reading.
## Down or out dulls the SFX bus hard, under the low-health line a little; the UI bus (pings, the heartbeat) stays
## clear; a revive or a heal lifts it.
func _muffle(m: Match, p: Hunter) -> void:
	var room := SfxMix.Muffle
	p.hp = p.max_hp
	p.armor = p.max_armor
	p.downed = true
	await _muffle_step(m, SfxMix.MUFFLE_HZ[room.DOWN], SfxMix.MUFFLE_DB[room.DOWN], "downed")
	ok(Sfx.mix.bus_for("ping", false, false) == &"UI" and Sfx.mix.bus_for("ping", false, false) != &"SFX",
		"pings go through the UI bus, so the muffle skips them")
	p.downed = false
	await _muffle_step(m, SfxMix.MUFFLE_HZ[room.OFF], SfxMix.MUFFLE_DB[room.OFF], "revived")
	p.hp = 1.0
	p.armor = 0.0
	await _muffle_step(m, SfxMix.MUFFLE_HZ[room.LOW_HP], SfxMix.MUFFLE_DB[room.LOW_HP], "under the low-health line")
	p.hp = p.max_hp
	p.armor = p.max_armor
	await _muffle_step(m, SfxMix.MUFFLE_HZ[room.OFF], SfxMix.MUFFLE_DB[room.OFF], "healed")

func _muffle_step(m: Match, hz: float, db: float, what: String) -> void:
	m.music_dir.tick(m, 0.0)
	await main.get_tree().create_timer(SfxMix.MUFFLE_S + 0.2).timeout
	var st := Sfx.mix.muffle_state()
	ok(is_equal_approx(st.hz, hz) and is_equal_approx(st.db, db) and st.on == (hz < 20000.0),
		"%s: the SFX bus low-pass %.0f Hz, duck %.0f dB (%s)" % [what, hz, db, st])

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
func _tell_cues(m: Match, p: Hunter) -> void:
	var r_v: Hunter = m.hunters.filter(func(x): return x != p and x.team != p.team and x.ak != null)[0]
	Sfx.listener = p.pos
	r_v.pos = p.pos + Vector3(40, 0, 0)                 # past hearing: only a cue at the landing spot can be heard
	var spot := p.pos + Vector3(3, 0, 0)
	var circle := func(who: Hunter, r: float) -> bool:
		AimKit.clear(who)
		return _tell(func(): AimKit.circle(who, "tell_check", {"at": spot, "r": r, "all": true}))
	ok(circle.call(r_v, 1.0), "a rival's circle 40 m off, landing 3 m from you, is heard where it lands")
	var small := _last_voice()
	circle.call(r_v, 4.0)
	var big := _last_voice()
	ok(big.volume_db > small.volume_db + 3.0 and big.pitch_scale < small.pitch_scale,
			"...a bigger area is louder and lower (%.1f dB / %.2f vs %.1f dB / %.2f)" % [
				big.volume_db, big.pitch_scale, small.volume_db, small.pitch_scale])
	AimKit.clear(r_v)
	var lane := {"from": p.pos + Vector3(-30, 0, 0), "dir": Vector2(1, 0), "len": 60.0, "width": 2.0, "all": true}
	ok(_tell(func(): AimKit.lane(r_v, "tell_lane", lane)), "a rival's lane is heard at its middle (starting 30 m off)")
	AimKit.clear(r_v)
	ok(circle.call(r_v, 2.0), "a rival's AimKit area everyone sees is heard when it starts")
	ok(not _tell(func(): AimKit.circle(r_v, "tell_check", {"at": spot, "r": 2.0, "all": true})),
			"...and not again while the kit refreshes it")
	ok(not _tell(func(): AimKit.lane(r_v, "tell_aim", {"from": spot, "len": 4.0})), "a rival's own-aim lane is silent")
	ok(not _tell(func(): AimKit.circle(r_v, "x_check", {"at": spot, "r": 2.0, "all": true})),
			"a rival's ultimate area is silent (UltCue has it)")
	ok(not circle.call(p, 2.0), "your own telegraph is silent")
	var team: int = r_v.team
	r_v.team = p.team
	ok(not circle.call(r_v, 2.0), "an ally's telegraph is silent")
	r_v.team = team
	AimKit.clear(r_v)

## Runs `cast` with the gap and stacking windows clear; whether it played tell_foe.
func _tell(cast: Callable) -> bool:
	Sfx.last_played.clear()
	Sfx.recent.clear()
	cast.call()
	return Sfx.last_played.has("tell_foe")

func _last_voice() -> AudioStreamPlayer:
	return Sfx.players[posmod(Sfx.next - 1, Sfx.POOL)]

## Footsteps by distance, both the foot's contact step and the surface step (Juice.footstep).
func _steps(m: Match, p: Hunter) -> void:
	var r: Hunter = m.hunters.filter(func(x): return x != p and x.team != p.team)[0]
	var far := StepReach.RIVAL_M + 5.0
	Sfx.listener = p.pos
	ok(not is_nan(_step_db(r, p, 15.0, true)) and not is_nan(_step_db(r, p, 15.0, false)),
			"a rival's footsteps (contact and surface) are heard 15 m away, seen or not (unseen %s)" % r.unseen)
	ok(is_nan(_step_db(r, p, far, true)) and is_nan(_step_db(r, p, far, false)),
			"...and not at their reach + 5 m (%.0f m)" % far)
	r.crouch = true
	var sneak := StepReach.reach(r)
	ok(sneak < StepReach.RIVAL_M and is_nan(_step_db(r, p, 15.0, true)) and is_nan(_step_db(r, p, 15.0, false)),
			"a sneaking rival's steps carry %.0f m, not %.0f m: not heard 15 m away" % [sneak, StepReach.RIVAL_M])
	ok(not is_nan(_step_db(r, p, sneak - 2.0, true)), "...but heard %.0f m away" % (sneak - 2.0))
	r.crouch = false
	var rival := _step_db(r, p, 10.0, true)
	var team := r.team
	r.team = p.team
	var mate := _step_db(r, p, 10.0, true)
	r.team = team
	ok(mate < rival - 3.0, "a teammate's step 10 m away is quieter than a rival's (%.1f vs %.1f dB)" % [mate, rival])
	var own_near := _step_db(p, p, 0.0, true)
	Sfx.listener = p.pos + Vector3(15, 0, 0)
	var own_far := _step_db(p, p, 0.0, true)
	Sfx.listener = p.pos
	ok(not is_nan(own_near) and is_equal_approx(own_near, own_far),
			"your own step plays at one level wherever the camera is (%.1f / %.1f dB)" % [own_near, own_far])

## The level (dB) of one step of h placed `d` m from p_v along x (h == p_v: where p_v stands), NAN when nothing played.
## contact: the foot's plain step (StepReach.contact), else the surface step (Juice.footstep).
func _step_db(h: Hunter, p: Hunter, d: float, contact: bool) -> float:
	if h != p:
		h.pos = p.pos + Vector3(d, 0, 0)
	Sfx.last_played.clear()
	Sfx.recent.clear()
	if contact:
		StepReach.contact(h)
	else:
		Juice.footstep(h)
	if not Sfx.last_played.keys().any(func(k): return String(k).contains("step")):
		return NAN
	return Sfx.players[(Sfx.next - 1 + Sfx.POOL) % Sfx.POOL].volume_db
## Hunter callouts: yours (ult back, low health, a knock, your Boki down) only for you, a 6 s cooldown per Hunter,
## a teammate's "Boki down" heard 40 m away at the teammate, a rival's never, nothing with the setting off.
func _barks(m: Match, p: Hunter) -> void:
	m.barks = HunterBarks.new()
	var b := m.barks
	var bark_of := func(h: Hunter, kind: String): return "%s_call_%s" % [h.arch, kind]
	Sfx.listener = p.pos
	p.lvl = maxi(p.lvl, int(Hunter.ULT_AT[0]))
	p.ak.cd["x"] = 5.0
	b.tick(m)
	ok(b.plays.is_empty(), "no bark while your ultimate is cooling down (%s)" % [b.plays])
	p.ak.cd["x"] = 0.0
	Sfx.last_played.clear()
	b.tick(m)
	var heard := Sfx.last_played.has(bark_of.call(p, "ult"))
	ok(b.plays == [["ult", p.nid]] and heard, "your ultimate back: one bark (%s)" % [b.plays])
	b.knock_landed(m)
	ok(b.plays.size() == 1, "a knock 0 s later stays quiet (the 6 s cooldown)")
	m.time += HunterBarks.COOLDOWN_S + 0.1
	b.knock_landed(m)
	ok(b.plays.back() == ["knock", p.nid], "...and barks once the cooldown is over")
	m.time += HunterBarks.COOLDOWN_S + 0.1
	var hp := p.hp
	p.hp = p.max_hp * 0.2
	b.tick(m)
	m.time += HunterBarks.COOLDOWN_S + 0.1
	b.tick(m)
	var low_pct := int(HunterBarks.LOW_SHARE * 100)
	ok(b.plays.count(["low", p.nid]) == 1, "low health: one bark per drop under %d%%" % low_pct)
	p.hp = hp
	m.time += HunterBarks.COOLDOWN_S + 0.1
	Sfx.last_played.clear()
	KinNet.on_event(m, ["kcmd", "down", p.kin.nid, p.pos.x, p.pos.y, p.pos.z, ""])
	heard = Sfx.last_played.has(bark_of.call(p, "boki"))
	ok(b.plays.has(["boki", p.nid]) and heard, "your Boki down: you call it")
	ok(b.plays.back() == ["alert", p.nid] and Sfx.last_played.has(HunterBarks.ALERT), "...and hear the UI alert")
	ok(Sfx.last_played.has("boki_downed"), "...and its own cry at the spot")
	Sfx.last_played.clear()
	m.time += 1.0
	var n_alerts := b.plays.count(["alert", p.nid])
	KinNet.on_event(m, ["kcmd", "down", p.kin.nid, p.pos.x, p.pos.y, p.pos.z, ""])
	ok(b.plays.count(["alert", p.nid]) == n_alerts and not Sfx.last_played.has(HunterBarks.ALERT),
			"a second down 1 s later: no second alert")
	ok(Sfx.last_played.has("boki_downed"), "...but the cry still sounds")
	m.time += HunterBarks.ALERT_GAP_S
	b.boki_down(m, p.kin)
	ok(b.plays.count(["alert", p.nid]) == n_alerts + 1, "a down after the gap: the alert sounds again")
	var voiced := func(x): return x.team != p.team and x.ak != null and Sfx.ensure(bark_of.call(x, "boki"))
	var other: Hunter = m.hunters.filter(voiced)[0]
	var team := other.team
	var theirs := Kin.new()
	theirs.owner_h = other
	other.pos = p.pos + Vector3(40, 0, 0)
	var before := b.plays.size()
	b.boki_down(m, theirs)
	ok(b.plays.size() == before, "a rival's Boki down: nothing (%s)" % [b.plays])
	other.team = p.team
	Sfx.last_played.clear()
	b.boki_down(m, theirs)
	ok(b.plays.back() == ["tick", other.nid] and Sfx.last_played.has(HunterBarks.TICK), "a teammate's Boki: a tick")
	ok(not Sfx.last_played.has(bark_of.call(other, "boki")) and not Sfx.last_played.has(HunterBarks.ALERT),
			"...no call, no alert")
	ok(HunterBarks.TICK_DB <= HunterBarks.ALERT_DB - 6.0, "...and the tick is well under your own alert")
	var up := Sfx.last_played.size()
	KinNet.on_event(m, ["kcmd", "scoop", p.kin.nid, p.pos.x, p.pos.y, p.pos.z, ""])
	ok(Sfx.last_played.has("boki_revive"), "your Boki back up: the soft revive cue (%d cues before)" % up)
	Settings.v["hunter_barks"] = false
	m.time += HunterBarks.COOLDOWN_S + 0.1
	before = b.plays.size()
	b.knock_landed(m)
	b.boki_down(m, theirs)
	Settings.v.erase("hunter_barks")
	ok(b.plays.size() == before, "Hunter callouts off: no bark (%s)" % [b.plays])
	other.team = team
	theirs.free()
## Carry 2 in, 1 out: the swap key, a claim and a steal, through the real paths (Hunter.swap_kin, Life.take_item,
## KinTrack.register, which every game runs for a catch online).
func _carry(m: Match, p_v: Hunter) -> void:
	var pairs := m.hunters.filter(func(x): return x != p_v and not x.out and x.kin and not x.kin.dead)
	if not pairs.is_empty() and (pairs[0].kin2 == null or pairs[0].kin2.dead):
		# main retired two Boki at the start (Match.TWO_KIN): a second one comes back out of a box (give_kin)
		var r2: Dictionary = (pairs[0].kin.rec as Dictionary).duplicate()
		r2["uid"] = "carry_check_2"
		m.give_kin(pairs[0], r2)
	ok(not pairs.is_empty() and pairs[0].kin2 != null, "setup: a bot carries two Boki")
	if pairs.is_empty():
		return
	var B: Hunter = pairs[0]
	Sfx.listener = B.pos
	Sfx.last_played.clear()
	B.swap_kin(true)
	var first := Sfx.last_played.has("carry_swap_out") and not Sfx.last_played.has("carry_swap_in")
	await main.get_tree().create_timer(CarrySfx.SWAP_GAP_S + 0.1).timeout
	ok(first and Sfx.last_played.has("carry_swap_in") and not Sfx.last_played.has("swap"),
			"swap: the outgoing Boki's chirp, then the incoming one's (%s)" % [Sfx.last_played.keys()])
	var R: Hunter = m.hunters.filter(func(x): return x.team != p_v.team)[0]
	var rec := {"species": p_v.kin.species, "uid": "carry_check", "name": "Check"}
	Sfx.listener = p_v.pos
	var got := _from_box(m, p_v, p_v, rec)
	ok(got == ["carry_claim"], "claim: a capsule from a box of your own team locks in (%s)" % [got])
	var wild := m.kins.filter(func(k): return is_instance_valid(k) and k.owner_h == null and not k.dead \
			and k.lost_from == "")
	ok(not wild.is_empty(), "setup: a wild Boki to claim")
	if not wild.is_empty():
		p_v.caught.clear()
		Sfx.last_played.clear()
		Capture.complete(m, p_v, wild[0])
		ok(Sfx.last_played.has("carry_claim") and p_v.caught.size() == 1,
				"claim: a scan that lands locks in (%s)" % [Sfx.last_played.keys()])
	got = _from_box(m, p_v, R, rec)
	ok(got == ["carry_take"], "steal: taking from a rival's box plays the sly take (%s)" % [got])
	Sfx.last_played.clear()
	R.pos = p_v.pos + Vector3(60, 0, 0)
	KinTrack.register(R, rec, p_v)
	got = Sfx.last_played.keys()
	ok(got == ["carry_stolen"], "steal: the owner hears the sting, flat, 60 m from the thief (%s)" % [got])
	for d in [25.0, 40.0]:
		R.pos = p_v.pos + Vector3(d, 0, 0)
		Sfx.last_played.clear()
		CarrySfx.stolen(m, R, B)
		var hears: bool = d < float(Sfx.sound_reach["carry_take"])
		ok(Sfx.last_played.has("carry_take") == hears,
				"steal: a squad %.0f m from the thief %s the take" % [d, "hears" if hears else "does not hear"])
	R.pos = p_v.pos + Vector3(2, 0, 0)
	Sfx.last_played.clear()
	Sfx.recent.erase("carry_take")
	for i in 3:
		CarrySfx.stolen(m, R, B)
	ok((Sfx.recent.get("carry_take", []) as Array).size() == 1, "voice cap: three takes at once play one")
	R.remove_meta(KinTrack.META)

## Takes `rec` out of a box `dropper` left and returns the carry cues it played.
func _from_box(m: Match, h: Hunter, dropper: Hunter, rec: Dictionary) -> Array:
	h.caught.clear()
	Sfx.last_played.clear()
	var b := {"owner": dropper, "team": dropper.team, "pos": h.pos, "gems": 0, "seeds": {}, "caught": [rec.duplicate()],
		"node": null}
	Life.take_item(m, h, b, {"key": "caught", "i": 0})
	h.caught.clear()
	return Sfx.last_played.keys().filter(func(n): return String(n).begins_with("carry_"))

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

## Motley floats with no feet (HoverHum): his hum holds while he drifts, swells and rises with his speed and
## stops once he is still; a Hunter with feet has no hum. `h` wears his sounds for the test.
func _hover(h: Hunter, who: String) -> void:
	var was := h.arch
	var key := HoverHum.key(h)
	h.arch = "ostra"
	h.unseen = false
	h.crouch = false
	_set_speed(h, h.base_speed * 0.3, 0.0)
	HoverHum.tick(h)
	var on := Sfx.loop_on(key)
	ok(on, "%s hover: Motley drifting hums" % who)
	var slow_db := float(Sfx.loops[key]["vol"]) if on else 0.0
	var slow_pitch := _pitch(key) if on else 0.0
	_set_speed(h, h.base_speed, 0.0)
	HoverHum.tick(h)
	var fast_db := float(Sfx.loops[key]["vol"]) if on else 0.0
	ok(on and fast_db > slow_db and _pitch(key) > slow_pitch,
		"%s hover: the hum swells and rises with speed (%.1f -> %.1f dB)" % [who, slow_db, fast_db])
	if h.remote:
		ok(on and Sfx.loops[key]["pos"] != null, "another player's hover: the hum is positional")
	_set_speed(h, 0.0, 0.0)
	HoverHum.tick(h)
	await main.get_tree().create_timer(0.5).timeout
	ok(not Sfx.loop_on(key), "%s hover: still, the hum stops" % who)
	h.arch = "gunslinger"
	_set_speed(h, h.base_speed, 0.0)
	HoverHum.tick(h)
	ok(not Sfx.loop_on(key), "%s hover: a Hunter with feet has no hum" % who)
	h.arch = was
	_set_speed(h, 0.0, 0.0)

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

## Waits ms of wall-clock time. Sfx spaces and stacks repeats in real ms, and a SceneTreeTimer is no
## measure of that: its first frame's delta also counts the match steps run before it was made, so
## create_timer(0.2) could end ~80 ms after the last chime, inside Sfx.STACK_MS (the chime came out a
## stacked 3.5 dB quieter and the gate went red at random).
func _wait_real_ms(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await main.get_tree().process_frame


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
	var p: Hunter = am.player
	var other: Hunter = null
	for o in am.hunters:
		if o != p:
			o.ctrl = "idle"
			o.teleport(Vector3(-500, 50, -500))
			other = o
	for mb in am.mobs:
		mb.queue_free()
	am.mobs.clear()
	var rim := _rim(am.world)
	ok(am.map_name == "The Hollow Crown" and not rim.is_empty(), "abyss: a rim on %s" % am.map_name)
	if not rim.is_empty():
		var jump := _walk(am, p, rim, false, false)
		ok(jump.find("abyss_whoosh") == 0 and jump.has("abyss_fallout") and not jump.has("abyss_catch"),
			"a walk off the rim: whoosh, then the fall-out %s" % [jump])
		var glide := _walk(am, p, rim, true, false)
		ok(glide.find("abyss_whoosh") == 0 and glide.find("abyss_catch") == 1 and not glide.has("abyss_fallout"),
			"...gliding: whoosh, then the catch %s" % [glide])
		var hot := _walk(am, p, rim, true, true)
		ok(hot.find("abyss_catch") == 1 and hot.has("strain"),
			"...an overheated glider lifting: the catch and the strain loop %s" % [hot])
		_teammate(am, other, rim)
	am.queue_free()
	for i in 3:
		await main.get_tree().process_frame

## The player on the island 2 m in from the lip, walking out and falling; scripts the glider when asked
## (cold: overheated). Returns the abyss sounds in the order first heard ("strain" if its loop ran).
## The listener is 80 m away, so only a 2D sound is heard.
func _walk(am: Match, p: Hunter, rim: Dictionary, glide: bool, cold: bool) -> Array:
	var dv: Vector2 = rim["dir"]
	var start: Vector2 = rim["lip"] - dv * 2.0
	p.out = false
	p.teleport(Vector3(start.x, rim["y"], start.y))
	p.grounded = true
	p.vel = Vector3.ZERO
	p.gliding = false
	p.glide_fuel = 1.0
	p.hp = p.max_hp
	Sfx.listener = p.pos + Vector3(80, 0, 0)
	Sfx.last_played.clear()
	Sfx.recent.clear()
	am.opts["god"] = true          # a fall-out puts you back instead of ending the run
	var heard := []
	var key := "abyss_strain%d" % p.get_instance_id()
	var t := 0.0
	var done := func() -> bool:
		return heard.has("abyss_fallout") or (heard.has("abyss_catch") and (not cold or heard.has("strain")))
	while t < WALK_S and not done.call():
		p.inp["move"] = dv
		if glide and heard.has("abyss_whoosh"):
			p.inp["glide"] = true
			p.inp["glide_btn"] = true
			if cold:
				p.glide_fuel = 0.0
		am.step(Match.DT)
		t += Match.DT
		for n_v in ABYSS_NAMES:
			if Sfx.last_played.has(n_v) and not heard.has(n_v):
				heard.append(n_v)
		if Sfx.loop_on(key) and not heard.has("strain"):
			heard.append("strain")
	p.inp["glide"] = false
	p.inp["glide_btn"] = false
	p.inp["move"] = Vector2.ZERO
	Sfx.loop_stop(key)
	return heard

## A teammate (a remote hunter, its fall in the snapshots) falling past the lip: positional,
## and the fall-out carries further.
func _teammate(_am: Match, o: Hunter, rim: Dictionary) -> void:
	var out_at: Vector2 = rim["lip"] + Vector2(rim["dir"]) * 3.0
	var heard := {}
	for case in [["whoosh", 5.0], ["whoosh", 36.0], ["fallout", 30.0], ["fallout", 60.0]]:
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
	ok(heard["whoosh 5"] and not heard["whoosh 36"],
		"a teammate's whoosh is positional: heard at 5 m, not at 36 m (past the 30 m hearing range) %s" % [heard])
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
