extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel).
## The ultimate-ready chime (UltReadyCue): once per R coming back, only for you (never a rival's or a
## teammate's R), never on a match's first look, held while you're down until you're up, and set lower
## under a kill callout.
## And the glider: each state (open, glide, dive, overheat, fold) plays its cue once, yours and another player's.
## And the mix (SfxMix): each kind of sound is on its own bus, a big event dips Music and Ambience about 6 dB
## and they recover; then the autoplay match runs LOUD_S and each bus's peak meter is reported (MATCHAUDIO BUS).
## Footsteps (StepReach): a rival's heard at 15 m, not at its reach + 5 m, a sneaking rival's carry less, a
## teammate's quieter than a rival's, your own one level wherever the camera is.
## And the carry cues (CarrySfx): the swap's two notes in order, a claim's lock-in, a steal heard by its owner, the
## thief and a squad nearby but not across the map, and one take per burst (MIN_GAP).

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
	var once := Sfx.players.filter(func(p): return p.playing and Sfx.loops_forever(p.stream))
	ok(once.is_empty(), "a one-shot of a looping file does not loop (%d looping pool voices)" % once.size())
	Sfx.loop_start("boxhum_check", "revive_hum", P.pos)       # (as a deathbox revive does, keyed)
	ok(Sfx.match_voices() >= 2, "setup: the match has several voices going (%d)" % Sfx.match_voices())
	await _ult_chime(m, P)
	_ult_cues(m, P)
	_buses()
	await _big_event_duck(P)
	_steps(m, P)
	_shields(m, P)
	await _carry(m, P)
	await _glider(P, "yours")
	var other: Hunter = m.hunters.filter(func(x): return x != P and not x.out)[0]
	other.remote = true
	other.pos = P.pos + Vector3(8, 0, 0)
	await _glider(other, "another player's")
	other.remote = false
	# going down muffles the world bus (a low-pass and a duck, 0.3 s ramp); a revive lifts it
	m.player.hp = 1.0                    # the low-health line: the milder filter, the heartbeat stays clear
	m.player.armor = 0.0
	m.music_dir.tick(m, 0.0)
	await main.get_tree().create_timer(Sfx.MUFFLE_S + 0.2).timeout
	var low := Sfx.muffle_state()
	ok(low.fx and is_equal_approx(low.db, Sfx.LOW_HP_DB) and is_equal_approx(low.hz, Sfx.LOW_HP_HZ),
		"under 25%% health: a mild low-pass and duck (%s)" % low)
	ok(Sfx._bus_for(null, "heartbeat") != &"SFXWorld", "...and the heartbeat skips the world bus")
	m.player.hp = m.player.max_hp
	m.player.armor = m.player.max_armor
	await _muffle_step(m, true)
	var dull := Sfx.muffle_state()
	ok(dull.fx and is_equal_approx(dull.db, Sfx.MUFFLE_DB) and is_equal_approx(dull.hz, Sfx.MUFFLE_HZ),
		"downed: the world bus is low-passed and ducked (%s)" % dull)
	var bus := AudioServer.get_bus_index("SFXWorld")
	ok(Sfx._bus_for(null, "wisp_hum") != &"SFXWorld" and Sfx._bus_for(null, "hit") == &"SFXWorld",
		"the Wisp hum, pings and Boki voices skip the world bus")
	await _muffle_step(m, false)
	var clear := Sfx.muffle_state()
	ok(not clear.fx and is_zero_approx(clear.db) and is_equal_approx(clear.hz, Sfx.MUFFLE_OPEN_HZ),
		"revived: the muffle is off again (%s)" % clear)
	await _muffle_step(m, true)
	ok(Sfx.muffle_state().fx and bus >= 0, "downed again: muffled")
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
	await main.get_tree().create_timer(Sfx.MUFFLE_S + 0.2).timeout
	ok(not Sfx.muffle_state().fx, "leaving the match while downed turns the muffle off")
	await main.get_tree().create_timer(SETTLE).timeout
	var left := Sfx.match_voices()      # the farm's own beds are not counted (Sfx.MATCH_BEDS)
	ok(left == 0, "after the fades nothing the match started is playing (%d)" % left)
	print("MATCHAUDIO DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

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

## A hit on a shield plays that material's thunk, the hit that takes the last of it plays its crack and clears the
## material; a rival's shield is heard only near, yours always; the shield running out clears the material too.
func _shields(m: Match, P: Hunter) -> void:
	var R: Hunter = m.hunters.filter(func(x): return x != P and x.team != P.team)[0]
	P.inv_t = 0.0
	P.hp = P.max_hp        # the ult-ready part revived you low; three breaks must not down you
	for kind in ["ward", "cloak", "molten"]:
		P.shield = 30.0
		P.shield_kind = "" if kind == "ward" else kind
		for part in ["hit", "break"]:
			var cue := "shield_%s_%s" % [kind, part]
			ok(Sfx.ensure(cue), "%s is a sound on file" % cue)
			Sfx.last_played.clear()
			P.hurt(10.0 if part == "hit" else 40.0, R, {})
			var shield_cues := Sfx.last_played.keys().filter(func(k): return k.begins_with("shield_"))
			ok(shield_cues == [cue], "your %s shield: a hit plays %s (%s)" % [kind, cue, shield_cues])
		ok(P.shield_kind == "" and P.shield <= 0.0, "...and the break clears the material")
	Sfx.listener = P.pos
	R.shield = 30.0
	R.shield_kind = "molten"
	R.pos = P.pos + Vector3(70, 0, 0)
	Sfx.last_played.clear()
	R.hurt(10.0, P, {})
	ok(Sfx.last_played.is_empty(), "a rival's shield 70 m away is out of earshot")
	R.pos = P.pos + Vector3(5, 0, 0)
	R.hurt(10.0, P, {})
	ok(Sfx.last_played.has("shield_molten_hit"), "...and 5 m away its thunk is heard")
	R.shield_t = 0.01
	R.sim(0.1)
	ok(R.shield <= 0.0 and R.shield_kind == "", "a shield that runs out clears the material")

## Downs (or revives) the player and lets the match's audio director and the ramp run.
func _muffle_step(m: Match, down: bool) -> void:
	m.player.downed = down
	m.music_dir.tick(m, 0.0)
	await main.get_tree().create_timer(Sfx.MUFFLE_S + 0.2).timeout

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
	var want := {"kin_happy": "Boki", "click": "UI", "ashwick_hurt": "Voice", "v_brute": "Voice", "rifle": "SFXWorld",
			"wisp_hum": "SFX"}
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
	return Sfx.players[(Sfx.next - 1 + Sfx.POOL) % Sfx.POOL].volume_db

## Carry 2 in, 1 out: the swap key, a claim and a steal, through the real paths (Hunter.swap_kin, Life.take_item,
## KinTrack.register, which every game runs for a catch online).
func _carry(m: Match, P: Hunter) -> void:
	var pairs := m.hunters.filter(func(x): return x != P and not x.out and x.kin and x.kin2 and not x.kin2.dead)
	ok(not pairs.is_empty(), "setup: a bot brought two Boki")
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
	var R: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	var rec := {"species": P.kin.species, "uid": "carry_check", "name": "Check"}
	Sfx.listener = P.pos
	var got := _from_box(m, P, P, rec)
	ok(got == ["carry_claim"], "claim: a capsule from a box of your own team locks in (%s)" % [got])
	var wild := m.kins.filter(func(k): return is_instance_valid(k) and k.owner_h == null and not k.dead \
			and k.lost_from == "")
	ok(not wild.is_empty(), "setup: a wild Boki to claim")
	if not wild.is_empty():
		P.caught.clear()
		Sfx.last_played.clear()
		Capture.complete(m, P, wild[0])
		ok(Sfx.last_played.has("carry_claim") and P.caught.size() == 1,
				"claim: a scan that lands locks in (%s)" % [Sfx.last_played.keys()])
	got = _from_box(m, P, R, rec)
	ok(got == ["carry_take"], "steal: taking from a rival's box plays the sly take (%s)" % [got])
	Sfx.last_played.clear()
	R.pos = P.pos + Vector3(60, 0, 0)
	KinTrack.register(R, rec, P)
	got = Sfx.last_played.keys()
	ok(got == ["carry_stolen"], "steal: the owner hears the sting, flat, 60 m from the thief (%s)" % [got])
	for d in [25.0, 40.0]:
		R.pos = P.pos + Vector3(d, 0, 0)
		Sfx.last_played.clear()
		CarrySfx.stolen(m, R, B)
		var hears: bool = d < float(Sfx.sound_reach["carry_take"])
		ok(Sfx.last_played.has("carry_take") == hears,
				"steal: a squad %.0f m from the thief %s the take" % [d, "hears" if hears else "does not hear"])
	R.pos = P.pos + Vector3(2, 0, 0)
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
