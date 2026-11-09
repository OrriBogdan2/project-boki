extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel).
## And the squad stingers (SquadAlerts): in a trio each of teammate down, teammate up, you last alive and a
## rival squad wiped by yours plays its own cue once, from the offline path and from the net event, never
## two inside 1.5 s.

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
	Game.goto("match", {"autoplay": true, "teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
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
	_squad_cues(m)
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

const CUES := ["squad_down", "squad_up", "squad_wipe", "squad_last"]

## Runs `act`; the squad cues that played during it.
func _heard(act: Callable) -> Array:
	for c in CUES:
		Sfx.last_played.erase(c)
	act.call()
	return CUES.filter(func(c): return Sfx.last_played.has(c))

func _take_out(m: Match, victims: Array) -> void:
	for r in victims:
		r.last_hit_by = m.player
		m.eliminate(r, m.player, "check", true)

func _squad_cues(m: Match) -> void:
	var P: Hunter = m.player
	var mates := m.hunters.filter(func(h): return h.team == P.team and h != P)
	var rivals := m.hunters.filter(func(h): return h.team != P.team)
	ok(mates.size() == 2 and rivals.size() >= 3, "setup: a trio with rivals (%d mates)" % mates.size())
	var a: Hunter = mates[0]
	var b: Hunter = mates[1]
	ok(_heard(func(): m.knock(a, null, {})) == ["squad_down"], "a teammate goes down: the down cue, once")
	ok(_heard(func(): m.revive_hunter(a, null)).is_empty(), "...a revive inside 1.5 s does not stack a cue")
	_step(m, 1.6)
	ok(_heard(func(): m.knock(a, null, {})) == ["squad_down"], "...down again after the gap: the cue again")
	_step(m, 1.6)
	ok(_heard(func(): m.revive_hunter(a, null)) == ["squad_up"], "a teammate is revived: the relief cue, once")
	_step(m, 1.6)
	ok(_heard(func(): m.knock(P, null, {})).is_empty(), "you going down is not a squad cue")
	m.revive_hunter(P, null)
	_step(m, 1.6)
	var net_down := func(): m._net_ev(["knock", a.nid, ""], "")
	ok(_heard(net_down) == ["squad_down"], "online: a teammate's down event plays the down cue")
	_step(m, 1.6)
	var last_down := func(): m._net_ev(["knock", b.nid, ""], "")
	ok(_heard(last_down) == ["squad_last"], "online: the last teammate down: you are last alive, that cue instead")
	_step(m, 1.6)
	var net_up := func(): m._net_ev(["up", a.nid], "")
	ok(_heard(net_up) == ["squad_up"], "online: a teammate's revive event plays the relief cue")
	_step(m, 1.6)
	var first: Array = rivals.slice(0, rivals.size() - 1)
	ok(_heard(func(): _take_out(m, first)).is_empty(), "rivals going out one by one: no wipe cue yet")
	_step(m, 1.6)
	var last_rival: Array = [rivals[rivals.size() - 1]]
	ok(_heard(func(): _take_out(m, last_rival)) == ["squad_wipe"], "your squad wipes a rival squad: the wipe cue, once")
	_step(m, 1.6)
	for h in m.hunters:
		h.downed = false

func _step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

func _on_farm() -> bool:
	var sc: Script = main.current.get_script() if is_instance_valid(main.current) else null
	return sc != null and sc.resource_path.ends_with("home/home.gd")
