extends RefCounted
## --ways-out-sfx-check: the Ways Out calls (scripts/match/heart_sfx.gd, content/sfx/heart.json).
##   1. every cue exists as a sound, and the six calls are six different files
##   2. each event (open, start, taken own / other, warn, last) plays its cue once with its words in the feed,
##      and spamming the same call plays nothing more; a start sounds again only after START_GAP_S
##   3. the Heart makes its own calls: the wake and the final seat open, a squad holding the ring starts it, the
##      early and the final seat taken; a client mirroring the host's "ht take" hears it too
## Every Heart sound cue (heart_take, heart_reveal, heart_extract) still plays once beside them. Never touches the save.

const CALLS := ["ways_open", "ways_start", "ways_taken_own", "ways_taken_other", "ways_warn", "ways_last"]

var bad := 0
var rl: Dictionary

func ok(cond: bool, what: String) -> void:
	print("WAYSSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	rl = Heart.rules()
	_files()
	_calls(main)
	_heart(main)
	_net(main)
	print("WAYSSFX DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _match(main: Node, seed_v: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": seed_v, "no_drop": true,
		"heart": true, "god": true})
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle"
		var p := m.world.random_ground()
		while p.distance_to(m.heart.site) < 30.0 or p.distance_to(m.heart.gate) < 20.0:
			p = m.world.random_ground()
		h.teleport(p)
	_calm(m)
	m.step(Match.DT)      # the first tick only notes the Heart's state; calls come from changes after it
	return m

func _calm(m: Match) -> void:
	for mb in m.mobs:
		if mb is Blight:
			(mb as Blight).burrow()
		else:
			mb.dead = true
			mb.visible = false

func _run(m: Match, secs: float) -> void:
	for i in int(secs / Match.DT):
		if i % 30 == 0:
			_calm(m)
		m.step(Match.DT)

## Runs a match's clock to this session time.
func _to(m: Match, t: float) -> void:
	m.time = t
	m.step(Match.DT)

func _n(m: Match, cue: String) -> int:
	return m.heart.audio.cues.count(cue)

func _said(m: Match, text: String) -> bool:
	return m.feed_all.any(func(f): return String(f).contains(text))

func _other_team(m: Match) -> int:
	for h in m.hunters:
		if h.team != m.player.team:
			return h.team
	return -1

# ------------------------------------------------------------------ 1. the files
func _files() -> void:
	var seen := {}
	for c in CALLS:
		var s := load("res://audio/%s.wav" % c) as AudioStream
		ok(s != null and s.get_length() > 0.1 and s.get_length() < 2.5, "%s is a short sound" % c)
		seen[c] = true
	ok(seen.size() == CALLS.size(), "the six calls are six different sounds")

# ------------------------------------------------------------------ 2. each event once
func _calls(main: Node) -> void:
	var m := _match(main, 8301)
	var A: HeartSfx = m.heart.audio
	var me: int = m.player.team
	var rival := _other_team(m)
	for i in 10:
		A.call_out("open", "lair")
	ok(_n(m, "ways_open") == 1 and _said(m, "The Sealed Lair is open"),
		"a seat opening: one cue and one line under spam")
	A.call_out("open", "uplink")
	ok(_n(m, "ways_open") == 2, "...another seat opening is its own call")
	for i in 10:
		A.call_out("start", "lair", rival)
	ok(_n(m, "ways_start") == 1 and _said(m, "started the Sealed Lair"), "a squad starting a seat: once under spam")
	A.call_out("start", "lair", me)
	ok(_n(m, "ways_start") == 2 and _said(m, "Your squad started the Sealed Lair"),
		"...a different squad starting does sound")
	m.time += HeartSfx.START_GAP_S + 1.0
	A.call_out("start", "lair", rival)
	ok(_n(m, "ways_start") == 3, "...and the same squad again after %.0f s" % HeartSfx.START_GAP_S)
	for i in 10:
		A.call_out("taken", "lair", rival)
	ok(_n(m, "ways_taken_other") == 1 and _n(m, "ways_taken_own") == 0,
		"a seat taken by another squad: the other-squad sting, once")
	ok(_said(m, "left by the Sealed Lair. 3 ways out left."), "...the line counts the ways out left")
	for i in 10:
		A.call_out("taken", "uplink", me)
	ok(_n(m, "ways_taken_own") == 1 and _said(m, "Your squad left by the Uplink. 2 ways out left."),
		"your squad's seat: the own sting, once")
	m.queue_free()
	# the 30 s warning
	m = _match(main, 8302)
	A = m.heart.audio
	A.call_out("open", "uplink")
	var shut := float(rl["quest"]["uplink_shut_s"])
	var warn := float(rl["quest"]["warn_before_shut_s"])
	_to(m, shut - warn - 1.0)
	_run(m, 0.5)
	ok(_n(m, "ways_warn") == 0, "no warning before %.0f s are left" % warn)
	_run(m, 2.0)
	_run(m, 6.0)
	ok(_n(m, "ways_warn") == 1 and _said(m, "The Uplink shuts in 30 s"),
		"the 30 s warning: once, with its line, however long it runs")
	m.queue_free()
	# the last way out
	m = _match(main, 8303)
	A = m.heart.audio
	m.heart.state = Heart.S.FINAL
	A.call_out("taken", "lair", me)
	A.call_out("taken", "uplink", me)
	_run(m, 3.0)
	ok(_n(m, "ways_last") == 0, "two ways out left is no last way out")
	A.call_out("taken", "early", _other_team(m))
	ok(_n(m, "ways_last") == 0, "...and it waits behind the taken sting")
	_run(m, HeartSfx.LAST_DELAY_S + 1.0)
	_run(m, 5.0)
	ok(_n(m, "ways_last") == 1 and _said(m, "Last way out: the Heart"), "the last way out: once, naming the seat")
	m.queue_free()

# ------------------------------------------------------------------ 3. the Heart makes its calls
func _heart(main: Node) -> void:
	var m := _match(main, 8304)
	var H: Heart = m.heart
	var p: Hunter = m.player
	_to(m, float(rl["wake_s"]))
	ok(H.state == Heart.S.CHARGING and _n(m, "ways_open") == 1 and _said(m, "The Heart Gate is open"),
		"the Heart waking opens the early seat: one call")
	_run(m, float(rl["charge_s"]) + 0.5)
	p.teleport(m.world.free_spot_near(H.site + Vector3(1, 0, 0), [], 1.0, 0.45, 6.0))
	H._pick(p)
	m.step(Match.DT)
	ok(_n(m, "heart_take") == 1 and _n(m, "heart_reveal") == 0 and _n(m, "ways_start") == 0,
		"taking the Heartspark: the taker's own sting, no call on top")
	p.teleport(H.gate)
	H._gate_done(p)
	m.step(Match.DT)
	ok(_n(m, "ways_taken_own") == 1 and _n(m, "heart_extract") == 1 and _said(m, "Your squad left by the Heart Gate"),
		"the early seat taken by you: the call and the Gate's own cue, once each")
	m.queue_free()
	m = _match(main, 8305)
	H = m.heart
	p = m.player
	_to(m, float(rl["final_s"]))
	ok(H.state == Heart.S.FINAL and _n(m, "ways_open") == 1 and _said(m, "The Heart is open"),
		"the final seat opening: one call")
	for i in 3:
		p.teleport(m.world.free_spot_near(H.site + Vector3(1.5, 0, 0), [], 1.0, 0.45, 1.5))
		m.step(Match.DT)
	ok(H.final_team == p.team and _n(m, "ways_start") == 1 and _said(m, "Your squad started the Heart"),
		"holding the ring starts the final seat: one call")
	for i in int(float(rl["final_hold_s"]) / Match.DT) + 60:
		p.teleport(m.world.free_spot_near(H.site + Vector3(1.5, 0, 0), [], 1.0, 0.45, 1.5))
		m.step(Match.DT)
	ok(H.state == Heart.S.DONE and _n(m, "ways_taken_own") == 1 and _n(m, "ways_start") == 1,
		"the ring filling: taken once, no second start")
	ok(H.refused == 0, "no refused edges")
	m.queue_free()
	# another squad takes the early seat while you watch
	m = _match(main, 8306)
	H = m.heart
	_to(m, float(rl["wake_s"]))
	_run(m, float(rl["charge_s"]) + 0.5)
	var rival: Hunter = m.hunters.filter(func(h): return h.team != m.player.team)[0]
	rival.teleport(m.world.free_spot_near(H.site + Vector3(1, 0, 0), [], 1.0, 0.45, 6.0))
	H._pick(rival)
	m.step(Match.DT)
	ok(_n(m, "heart_reveal") == 1 and _n(m, "heart_take") == 0, "a rival taking the Heartspark: the reveal sting, once")
	rival.teleport(H.gate)
	H._gate_done(rival)
	m.step(Match.DT)
	ok(_n(m, "ways_taken_other") == 1 and _n(m, "ways_taken_own") == 0,
		"the early seat taken by a rival: the other-squad sting")
	m.queue_free()

# ------------------------------------------------------------------ 4. a client hears the host's take
func _net(main: Node) -> void:
	var cli := _match(main, 8307)
	cli.net_on = true
	cli.is_host = false
	var C: Heart = cli.heart
	var rival := _other_team(cli)
	for i in 3:
		C.net_in(JSON.parse_string(JSON.stringify(["ht", "take", Heart.HOW_EARLY, rival])))
	ok(_n(cli, "ways_taken_other") == 1 and _said(cli, "left by the Heart Gate"),
		"a client told of a seat taken: the call, once")
	cli.net_on = false
	cli.queue_free()
