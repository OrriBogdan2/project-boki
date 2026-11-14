extends RefCounted
## --bot-ways-check: the bot rules of Limited Ways Out (scripts/match/bot_ways.gd, LIMITED_WAY_OUTS.md
## section 7) on a still match, no stepping: plan shares by seed against heart.json "bots", the bot cap
## (9 bot squads and the player's: 2), the 30 s delay, a human squad never delayed or capped, a raider's
## fall-through (Sealed Lair, then the spark, then the final ring) and goals kept inside the tide ring.
## How the plans play out over whole matches is --ways-out-sim. Never touches the save.

const SHARE_TOL := 0.03      # plan shares over 4000 squads within this of heart.json

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOTWAYS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 10, "squad": 1, "tier": 0, "seed": 5, "no_drop": true, "god": true})
	m.set_process(false)
	for h in m.hunters:
		if h != m.player: h.ctrl = "bot"
	m.exits.seats.build()
	ok(BotWays.on(m), "the Ways Out mode is on in a real match")
	_plans(m)
	_cap_delay(m)
	_fall_through(m)
	_ring(m)
	m.queue_free()
	print("BOTWAYS %s (%d fails)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _plans(m: Match) -> void:
	var n := {}
	var keep := m.seed_val
	for s in 400:
		m.seed_val = s + 1
		for t in 10:
			var p := BotWays.plan(m, t)
			n[p] = int(n.get(p, 0)) + 1
	m.seed_val = keep
	var share: Dictionary = Heart.rules()["bots"]["plans"]
	for p in BotWays.PLANS:
		var got := float(n.get(p, 0)) / 4000.0
		var want := float(share[p])
		ok(absf(got - want) <= SHARE_TOL, "plan %s %.3f of squads (heart.json %.2f)" % [p, got, want])

func _cap_delay(m: Match) -> void:
	var me := m.player.team
	var b1 := (me + 1) % 10
	var b2 := (me + 2) % 10
	var b3 := (me + 3) % 10
	ok(not BotWays.bot_squad(m, me) and BotWays.bot_squad(m, b1),
		"the player's squad is the human one, the rest are bot squads")
	ok(BotWays.cap(m) == 2, "9 bot squads: bots may take 2 of the 3 early seats (got %d)" % BotWays.cap(m))
	m.time = BotWays.start_t("lair") - 1.0 - m.sess_t0
	ok(not BotWays.may_start(m, b1, "lair") and BotWays.may_start(m, me, "lair"),
		"before the 30 s delay a bot squad may not start the Sealed Lair, the human squad may")
	m.time = BotWays.start_t("uplink") + 1.0 - m.sess_t0
	ok(BotWays.may_start(m, b3, "uplink"), "after the delay with no bot squad on a seat: may start")
	var sq: QuestSeats = m.exits.seats
	sq.lair.state = QuestSeat.S.TAKEN
	sq.lair.team = b1
	m.heart.early_team = b2
	ok(not BotWays.may_start(m, b3, "uplink"), "two early seats taken by bot squads: a third bot squad is capped")
	ok(not BotWays.may_start(m, b1, "uplink"), "...and so is one of a squad that already took one")
	ok(BotWays.may_start(m, me, "uplink"), "...the human squad never is")
	sq.lair.team = me
	ok(BotWays.may_start(m, b3, "uplink"), "a seat the human squad took does not count against the bots")
	sq.lair.state = QuestSeat.S.OPEN
	sq.lair.team = -1
	m.heart.early_team = -1

## A raider squad: the Sealed Lair once it may, the Heartspark when the lair is gone, the final at the end.
func _fall_through(m: Match) -> void:
	var raider := -1
	for t in 10:
		if t != m.player.team and BotWays.plan(m, t) == "raider":
			raider = t
			break
	ok(raider >= 0, "seed 5 has a bot raider squad")
	if raider < 0:
		return
	var h: Hunter = m.hunters.filter(func(x): return x.team == raider)[0]
	var sq: QuestSeats = m.exits.seats
	m.time = BotWays.knob("raider_at_s") - 20.0 - m.sess_t0
	sq.lair.state = QuestSeat.S.OPEN
	ok(BotWays.goal(m, h).is_empty(), "a raider before raider_at_s: no seat yet (it loots)")
	m.time = BotWays.knob("raider_at_s") + 5.0 - m.sess_t0
	var g := BotWays.goal(m, h)
	ok(not g.is_empty() and String(g[1]) in ["lair_dial", "lair_breach", "lair_fight"],
		"a raider at raider_at_s heads into the Sealed Lair (%s)" % str(g.slice(1)))
	sq.lair.state = QuestSeat.S.SHUT
	m.time = BotWays.knob("runner_at_s") - m.sess_t0
	g = BotWays.goal(m, h)
	var by_heart := not g.is_empty() and (g[0] as Vector3).distance_to(m.heart.site) <= BotWays.WAIT_R + 0.5
	ok(by_heart and String(g[1]) == "seat",
		"the lair shut: the raider falls through to the Heartspark and waits by the Heart (%s)" % str(g.slice(1)))
	m.heart.early_team = (raider + 1) % 10
	sq.uplink.state = QuestSeat.S.SHUT
	m.time = Heart.r("final_s") - 5.0 - m.sess_t0
	g = BotWays.goal(m, h)
	var in_ring := not g.is_empty() and (g[0] as Vector3).distance_to(m.heart.site) <= Heart.r("final_r")
	ok(in_ring and String(g[1]) == "ring",
		"every early seat gone: the final, inside the Heart ring (%s)" % str(g.slice(1)))
	m.heart.early_team = -1

func _ring(m: Match) -> void:
	m.time = 400.0 - m.sess_t0
	var c := m.heart.site
	var far := c + Vector3(400.0, 0.0, 0.0)
	var q := BotWays.keep_inside(m, far)
	var qd := Vector2(q.x - c.x, q.z - c.z).length()
	ok(qd <= BotWays.safe_r(m) + 0.01 and not m.world.is_void(q.x, q.z),
		"a goal out in the tide is pulled in to ground inside the ring (%.0f m, ring %.0f m)" % [qd, Heart.tide_r(m)])
	var h := m.player
	h.teleport(m.world.free_spot_near(c, [], 1.0, 0.45, 6.0))
	ok(BotWays.ring_back(m, h) == Vector3.INF, "a Hunter by the Heart has no reason to walk in")
	var edge := Heart.tide_r(m) + 3.0
	for k in 16:
		var a := TAU * k / 16.0
		var p := c + Vector3(cos(a), 0.0, sin(a)) * edge
		if not m.world.is_void(p.x, p.z) and not m.world.is_block(p.x, p.z):
			h.teleport(Vector3(p.x, m.world.ground_at(p.x, p.z), p.z))
			var back := BotWays.ring_back(m, h)
			ok(back != Vector3.INF and back.distance_to(c) < h.pos.distance_to(c),
				"out in the tide: walk back in toward the Heart")
			return
	ok(false, "found ground just outside the tide ring to stand on")
