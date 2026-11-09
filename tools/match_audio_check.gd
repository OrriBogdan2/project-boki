extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel),
## and movement sounds (MoveSfx): a remote Hunter's footstep plays placed at it (panned), quieter than
## yours, out to the step reach and silent past it or while crouched; landings are placed and weighted.

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
		var wt := MoveSfx.weight(e.arch)
		var dbs := [theirs.volume_db, mine.volume_db]
		ok(dbs[0] < dbs[1], "...quieter than yours (%.1f vs %.1f dB)" % dbs)
		var pitch: float = theirs.pitch_scale
		ok(absf(pitch / wt.x - 1.0) <= 0.081, "...at its weight's pitch (%.2f, weight %.2f)" % [pitch, wt.x])
	ok(_step_of(P, e, Vector3(0, 0, reach - 1.0)) != null, "...heard just inside the step reach (%.0f m)" % reach)
	ok(_step_of(P, e, Vector3(0, 0, reach + 1.0)) == null, "...silent past it")
	e.crouch = true
	ok(_step_of(P, e, Vector3(3.0, 0, 0)) == null, "...and silent while it sneaks (crouched)")
	e.crouch = false
	var landed = _probe(P, P.pos + Vector3(-8.0, 0, 0), func(): MoveSfx.land(e, -12.0), e)
	ok(landed is AudioStreamPlayer3D, "an enemy's landing plays placed at it")
	var kael := MoveSfx.weight("juggernaut")
	var neve := MoveSfx.weight("rimewright")
	var what := "weight: Kael (2.05 m) lower and louder than Neve (1.56 m)"
	ok(kael.x < neve.x and kael.y > neve.y, "%s: %s vs %s" % [what, kael, neve])

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
