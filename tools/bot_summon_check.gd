extends RefCounted
## --bot-summon-check: bots press Summon (BotKin.summon). A bot that walks into a duel summons its Boki
## once within 2 s and never again while the cooldown runs; a bot below the health line, a hexed one and a
## tutorial bot do not summon (a beat can allow it); a downed teammate close by calls the Boki out; an easy
## bot waits longer than an expert one.

const DT := 1.0 / 60.0
const EXPERT := {"abil": 1.0, "react": 0.16, "fire": 1.0, "dmg": 1.0, "aggro": 1.1}

var bad := 0
var m: Match
var main: Node
var bot: Hunter
var foe: Hunter
var summons := 0     # rising edges of the bot Boki's window
var first_at := -1.0
var pin := 0.0       # health share the bot is held at (0: free)
var _prev_left := 0.0

func run(main_node: Node) -> void:
	main = main_node
	_duel()
	_no_summon_cases()
	_downed_mate()
	_easy_waits_longer()
	m.queue_free()
	print("BOTSUMMON %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("BOTSUMMON %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A fresh match: one bot with a wisp Boki, the other hunters idle, the foe 8 m from the bot.
func _start(opts := {}) -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	var base := {"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 79, "no_drop": true, "boki_wisps": true}
	m.start(base.merged(opts))
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	bot = m.hunters.filter(func(h: Hunter) -> bool: return h.ctrl == "bot" and h.kin != null)[0]
	for h in m.hunters:
		if h != bot:
			h.ctrl = "idle"
			h.inp["move"] = Vector2.ZERO
	foe = m.hunters.filter(func(h: Hunter) -> bool: return h.team != bot.team)[0]
	foe.pos = bot.pos + Vector3(8, 0, 0)
	foe.prev = foe.pos
	bot.ai["diff"] = EXPERT
	bot.ai["skill"] = 0.9
	summons = 0
	first_at = -1.0
	_prev_left = 0.0
	pin = 0.0

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		foe.hp = foe.max_hp
		if pin > 0.0:
			bot.hp = bot.max_hp * pin
		var left: float = bot.kin.summon.left
		if left > _prev_left:
			summons += 1
			if first_at < 0.0:
				first_at = t
		_prev_left = left

func _duel() -> void:
	_start()
	ok(bot.kin.wisp and bot.kin.summon.cd <= 0.0, "setup: the bot's Boki rides as a wisp, ready")
	_frames(2.0)
	ok(summons == 1 and first_at <= 2.0, "duel: the bot summons once within 2 s (at %.2f s)" % first_at)
	_frames(KinSummon.times(bot.kin.ks).x + 1.0)
	var cd: float = bot.kin.summon.cd
	ok(bot.kin.wisp and cd > 0.0, "duel: the window ends and the cooldown runs (%.0f s)" % cd)
	_frames(25.0)
	ok(summons == 1, "duel: no second summon on cooldown (%d)" % summons)

func _no_summon_cases() -> void:
	_start()
	pin = 0.2
	_frames(4.0)
	ok(summons == 0, "low health: a losing bot does not summon")
	_start()
	bot.ai["goal_kind"] = "flee"
	bot.ai["think"] = 1e9
	_frames(3.0)
	ok(summons == 0, "fleeing: no summon")
	_start()
	m.opts["tutorial"] = true       # (BotKin.summon alone: a stepped match would need the Tutorial object)
	_decide(4.0)
	ok(bot.kin.wisp, "tutorial: a bot never summons on its own")
	bot.ai["summon_ok"] = true
	_decide(2.0)
	ok(not bot.kin.wisp, "tutorial: a beat that allows it gets the summon")

## Only the bot's summon decision, once per tick for secs.
func _decide(secs: float) -> void:
	for i in int(secs / DT):
		BotKin.summon(m, bot, foe, 1.0, DT)

func _downed_mate() -> void:
	_start()
	foe.pos = bot.pos + Vector3(60, 0, 0)
	foe.prev = foe.pos
	var mate: Hunter = m.hunters.filter(func(h: Hunter) -> bool: return h != bot and h.team == bot.team)[0]
	mate.pos = bot.pos + Vector3(5, 0, 0)
	mate.prev = mate.pos
	_frames(1.0)
	ok(summons == 0, "teammate up, no rival near: no summon")
	m.knock(mate, null, {})
	_frames(2.0)
	ok(summons == 1, "a teammate downed close by calls the Boki out")

## The wait before pressing is longer for easy bots (same moment, many draws).
func _easy_waits_longer() -> void:
	var sums := {}
	for tier in ["easy", "expert"]:
		_start()
		bot.ai["diff"] = Data.BOT_DIFF[tier]
		var total := 0.0
		for i in 40:
			bot.ai["sum_wait"] = -1.0
			BotKin.summon(m, bot, foe, float(Data.BOT_DIFF[tier]["abil"]), 0.0)
			total += float(bot.ai["sum_wait"])
		sums[tier] = total / 40.0
	ok(sums["easy"] > sums["expert"] * 2.0, "easy bots wait longer (%.2f s vs %.2f s)" % [sums["easy"], sums["expert"]])
