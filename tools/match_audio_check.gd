extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel).

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
	await main.get_tree().create_timer(SETTLE).timeout
	ok(Sfx.match_voices() == 0, "after the fades nothing the match started is playing (%d)" % Sfx.match_voices())
	print("MATCHAUDIO DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

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
