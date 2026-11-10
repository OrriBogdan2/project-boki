extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel),
## and movement sounds (MoveSfx): a remote Hunter's footstep plays placed at it (panned), an enemy's louder than yours,
## quieter in a fight, out to the step reach and silent past it or while crouched; landings are placed.
## Hunter foley: every Hunter has its foley row and sounds, it plays under a run step and a dash, louder the
## faster it moves, heard out to the step reach, and a crowd of 30 starts no more than the voice cap.

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
	_footsteps(m, P)
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
	var once := Sfx.voices().filter(func(p): return p.playing and Sfx.loops_forever(p.stream))
	ok(once.is_empty(), "a one-shot of a looping file does not loop (%d looping pool voices)" % once.size())
	Sfx.loop_start("boxhum_check", "revive_hum", P.pos)       # (as a deathbox revive does, keyed)
	ok(Sfx.match_voices() >= 2, "setup: the match has several voices going (%d)" % Sfx.match_voices())
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
	ok(Sfx.match_voices() == 0, "after the fades nothing the match started is playing (%d)" % Sfx.match_voices())
	print("MATCHAUDIO DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _footsteps(m: Match, P: Hunter) -> void:
	var e: Hunter = null
	for h in m.hunters:
		if h.team != P.team and e == null: e = h
	ok(e != null and _cam(m) != null, "setup: an enemy Hunter and a camera to hear from")
	if e == null:
		return
	var reach := float(MoveSfx.rules()["step_reach_m"])
	e.unseen = false
	e.crouch = false
	var mine = _probe(P, P.pos, func(): MoveSfx.footstep(P))
	var theirs = _step_of(P, e, Vector3(6.0, 0, 0))
	ok(theirs is AudioStreamPlayer3D, "an enemy's footstep 6 m away plays placed at it, so it pans (%s)" % theirs)
	if theirs is AudioStreamPlayer3D and mine != null:
		var want := MoveSfx.pitch(e.arch)
		var off := absf(theirs.pitch_scale / want - 1.0)
		ok(off < 0.09, "...at its height's pitch (%.2f vs %.2f)" % [theirs.pitch_scale, want])
	var base := float(MoveSfx.rules()["step_db"])
	var calm_e := MoveSfx.level(e, base)
	var own := MoveSfx.level(P, base)
	ok(calm_e > own, "an enemy's step is set louder than yours so you hear it coming (%.1f vs %.1f dB)" % [calm_e, own])
	e.hurt_at = m.time
	ok(MoveSfx.level(e, base) < calm_e, "...and drops while it fights (%.1f dB)" % MoveSfx.level(e, base))
	e.hurt_at = -9.0
	ok(_step_of(P, e, Vector3(0, 0, reach - 1.0)) != null, "...heard just inside the step reach (%.0f m)" % reach)
	ok(_step_of(P, e, Vector3(0, 0, reach + 1.0)) == null, "...silent past it")
	e.crouch = true
	ok(_step_of(P, e, Vector3(3.0, 0, 0)) == null, "...and silent while it sneaks (crouched)")
	e.crouch = false
	var landed = _probe(P, P.pos + Vector3(-8.0, 0, 0), func(): MoveSfx.land(e, -12.0), e)
	ok(landed is AudioStreamPlayer3D, "an enemy's landing plays placed at it")
	_foley(P, e)
	var kael := MoveSfx.pitch("juggernaut")
	var neve := MoveSfx.pitch("rimewright")
	ok(kael < neve, "height: Kael (2.05 m) sounds lower than Neve (1.56 m): %.2f vs %.2f" % [kael, neve])

func _foley(P: Hunter, e: Hunter) -> void:
	var home := e.arch
	var reach := float(MoveSfx.rules()["step_reach_m"])
	var rows: Dictionary = MoveSfx.foley_rules()["rows"]
	var missing := []
	var silent := []
	e.vel = Vector3(e.base_speed, 0, 0)
	for id: String in Arch.ids():
		e.arch = id
		var step_cue := HeroSfx.of(e, "foley", "")
		var dash_cue := HeroSfx.of(e, "foley_dash", "")
		if not rows.has(id) or step_cue == "" or dash_cue == "":
			missing.append(id)
			continue
		if _foley_voice(P, e, Vector3(5.0, 0, 0), func(): MoveSfx.footstep(e), step_cue) == null:
			silent.append(id + " run")
		if _foley_voice(P, e, Vector3(5.0, 0, 0), func(): MoveSfx.dash(e), dash_cue) == null:
			silent.append(id + " dash")
	var all: bool = missing.is_empty() and rows.size() == Arch.ids().size()
	ok(all, "every Hunter has a foley row and sounds (missing: %s)" % [missing])
	ok(silent.is_empty(), "...and it plays on a run step and a dash (silent: %s)" % [silent])
	e.arch = "juggernaut"
	var cue := HeroSfx.of(e, "foley", "")
	var run = _foley_voice(P, e, Vector3(5.0, 0, 0), func(): MoveSfx.footstep(e), cue)
	e.vel = Vector3.ZERO
	var walk = _foley_voice(P, e, Vector3(5.0, 0, 0), func(): MoveSfx.footstep(e), cue)
	var louder: bool = run != null and walk != null and run.volume_db > walk.volume_db
	ok(louder, "foley is louder the faster the Hunter moves")
	e.vel = Vector3(e.base_speed, 0, 0)
	var step := func(): MoveSfx.footstep(e)
	var near = _foley_voice(P, e, Vector3(0, 0, reach - 1.0), step, cue)
	ok(near != null, "a rival's foley is heard in the step reach")
	ok(_foley_voice(P, e, Vector3(0, 0, reach + 1.0), step, cue) == null, "...and not past it")
	e.crouch = true
	ok(_foley_voice(P, e, Vector3(3.0, 0, 0), step, cue) == null, "...nor while it sneaks")
	e.crouch = false
	var crowd := func():
		for k in 30:
			e.arch = Arch.ids()[k % Arch.ids().size()]
			MoveSfx.foley(e, "foley", "step_db", 0.0)
	_foley_voice(P, e, Vector3(5.0, 0, 0), crowd, cue)
	var started := 0
	for id: String in Arch.ids():
		for p in Sfx.voices():
			if _plays(p, id + "_foley"):
				started += 1
	var cap := int(MoveSfx.foley_rules()["voice_cap"])
	ok(started > 0 and started <= cap, "30 Hunters' foley at once start %d voices (cap %d)" % [started, cap])
	e.arch = home
	e.vel = Vector3.ZERO

## The voice that plays `cue` when `make` runs with e standing `off` from P (null if none).
func _foley_voice(P: Hunter, e: Hunter, off: Vector3, make: Callable, cue: String):
	MoveSfx.foley_ms.clear()
	_probe(P, P.pos + off, make, e)
	for p in Sfx.voices():
		if _plays(p, cue):
			return p
	return null

## Whether voice `p` holds one of the takes of sound `sname`.
func _plays(p, sname: String) -> bool:
	var st = Sfx.streams.get(sname)
	return p.stream != null and (p.stream in st if st is Array else p.stream == st)

## The voice e's footstep starts with e standing `off` from P (null if none).
func _step_of(P: Hunter, e: Hunter, off: Vector3):
	return _probe(P, P.pos + off, func(): MoveSfx.footstep(e), e)

func _cam(m: Match) -> Camera3D:
	return m.get_viewport().get_camera_3d()

## Runs `make` with `who` standing at `at` (the listener on P) and returns the one-shot voice it started
## at that spot, or null if nothing played there. (A voice reads as playing only once the audio server has
## mixed it, a frame later, so the probe clears every voice's stream and looks for the one given a sound.)
func _probe(P: Hunter, at: Vector3, make: Callable, who: Hunter = P):
	for p in Sfx.voices():
		p.stop()
		p.stream = null
	Sfx.last_played.clear()
	Sfx.recent.clear()
	Sfx.listener = P.pos
	var home := who.pos
	who.pos = at
	make.call()
	who.pos = home
	for p in Sfx.voices():
		if p.stream != null and (p is AudioStreamPlayer or (p as AudioStreamPlayer3D).position.is_equal_approx(at)):
			return p
	return null

func _step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

func _on_farm() -> bool:
	var sc: Script = main.current.get_script() if is_instance_valid(main.current) else null
	return sc != null and sc.resource_path.ends_with("home/home.gd")
