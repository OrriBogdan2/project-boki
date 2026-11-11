extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel).
## The ultimate-ready chime (UltReadyCue): once per R coming back, only for you (never a rival's or a
## teammate's R), never on a match's first look, held while you're down until you're up, and set lower
## under a kill callout.

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

func _step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

func _on_farm() -> bool:
	var sc: Script = main.current.get_script() if is_instance_valid(main.current) else null
	return sc != null and sc.resource_path.ends_with("home/home.gd")
