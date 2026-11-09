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
	_belt_items(m, P)
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
		Sfx.loop_stop(BeltSfx.loop_key(P, id))

func _belt_channel(m: Match, P: Hunter, id: String) -> void:
	var key := BeltSfx.loop_key(P, id)
	_step(m, 0.1)
	ok(Sfx.loop_on(key), "belt %s: loops while it channels" % id)
	Sfx.last_played.erase(BeltSfx.cue(id, "end"))
	_step(m, Hunter.KIT_TIME + 0.1)
	ok(not Sfx.loop_on(key) and Sfx.last_played.has(BeltSfx.cue(id, "end")), "belt %s: ends with its end cue" % id)
	UtilityBelt.set_slot(P, 0, id, 3, 0)
	P.hp = 20.0
	P.armor = 0.0
	UtilityUse.start(P, 0, id)
	_step(m, 0.1)
	Sfx.last_played.erase(BeltSfx.cue(id, "cancel"))
	P.stun_t = 1.0
	_step(m, 0.1)
	var spilt := not Sfx.loop_on(key) and Sfx.last_played.has(BeltSfx.cue(id, "cancel"))
	ok(spilt, "belt %s: a spill plays its cancel cue" % id)
	P.stun_t = 0.0

func _step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

func _on_farm() -> bool:
	var sc: Script = main.current.get_script() if is_instance_valid(main.current) else null
	return sc != null and sc.resource_path.ends_with("home/home.gd")
