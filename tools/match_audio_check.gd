extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel).
## And the heal and shield family (HealSfx): one cue per event, heals merged per 0.3 s, a shield's expiry pops.

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
	_heal_cues(m, P)
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

func _cue(sname: String) -> int:
	return int(HealSfx.cues.get(sname, 0))

func _heal_cues(m: Match, P: Hunter) -> void:
	HealSfx.cues.clear()
	P.hp = P.max_hp * 0.3
	P.heal(20.0)
	ok(_cue("heal_chime") == 1, "a heal is one chime (%d)" % _cue("heal_chime"))
	P.heal(5.0)
	P.heal(5.0)
	CareUtil.heal(m, P, 5.0)            # a Boki or Meeko heal goes the same way
	ok(_cue("heal_chime") == 1, "heals inside 0.3 s are merged, not one chime each (%d)" % _cue("heal_chime"))
	_step(m, HealSfx.MERGE + 0.1)
	ok(_cue("heal_chime") == 2, "the merged heals chime once as the window closes (%d)" % _cue("heal_chime"))
	_step(m, HealSfx.MERGE + 0.1)
	P.heal(0.5)
	ok(_cue("heal_chime") == 2, "a heal of under a point is silent")
	var foe: Hunter = m.hunters.filter(func(x): return x != P and not x.out)[0]
	foe.hp = foe.max_hp * 0.5
	foe.heal(30.0)
	ok(_cue("heal_chime") == 3, "another hunter's heal is a cue too, at its position (%d)" % _cue("heal_chime"))
	HealSfx.set_shield(P, 30.0)
	HealSfx.set_shield(P, 20.0)         # a smaller shield changes nothing: no second hum
	ok(_cue("shield_gain") == 1 and P.shield == 30.0, "one hum per shield gain (%d)" % _cue("shield_gain"))
	P.shield_t = 0.1
	_step(m, 0.3)
	ok(_cue("shield_pop") == 1 and P.shield == 0.0, "a shield running out pops once (%d)" % _cue("shield_pop"))
	HealSfx.set_shield(P, 30.0)
	P.shield_t = 0.0
	P.shield = 0.0
	P.armor = 0.0
	HealSfx.give_armor(P, 25.0)
	HealSfx.give_armor(P, 1000.0)
	ok(_cue("armor_refill") == 2 and P.armor == P.max_armor, "one ring per refill (%d)" % _cue("armor_refill"))
	HealSfx.give_armor(P, 10.0)
	ok(_cue("armor_refill") == 2, "armor already full is silent")
	for sname in ["heal_chime", "shield_gain", "armor_refill", "shield_pop"]:
		ok(Sfx.ensure(sname), "the sound file %s loads" % sname)

func _step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

func _on_farm() -> bool:
	var sc: Script = main.current.get_script() if is_instance_valid(main.current) else null
	return sc != null and sc.resource_path.ends_with("home/home.gd")
