extends RefCounted
## --bot-human-check: the bot behaviours from docs/BOTS_HUMAN_1111.md, one small staged case each.
##   retreat   a bot at 25% health facing a healthy rival backs off instead of trading
##   tiers     an expert bot backs off far more often than an easy one (difficulty stays a difference)
##   belt      a hurt bot in a fight uses its mending kit (belt items used to wait for the fight to end)
##   regroup   a calm bot far from its squad's lead walks back to it instead of roaming alone
##   focus     with two rivals in reach, a bot shoots the one its squadmate is already on
## Prints PASS/FAIL per case. Never touches the save.

var bad := 0
var m: Match
var main: Node

func run(main_: Node) -> void:
	main = main_
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_retreat()
	_tiers()
	_belt()
	_regroup()
	_focus()
	print("BOTHUMAN done, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("BOTHUMAN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _fresh() -> void:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	m.pickups.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO

func _put(h: Hunter, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO

## Open level ground: no void, rock or step within r tiles of p.
func _roomy(p: Vector3, r: int) -> bool:
	var w := m.world
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var x := p.x + dx
			var z := p.z + dz
			if w.is_void(x, z) or w.is_block(x, z) or absf(w.ground_at(x, z) - w.ground_at(p.x, p.z)) > 0.3:
				return false
	return true

func _open_spot(r: int) -> Vector3:
	for k in 400:
		var p := m.world.random_ground()
		if _roomy(p, r): return p
	return m.world.random_ground()

## Somewhere 60+ m from p, to park the hunters a case doesn't use.
func _far_spot(p: Vector3) -> Vector3:
	var q := m.world.random_ground()
	for k in 50:
		if Vector2(q.x - p.x, q.z - p.z).length() > 60.0: break
		q = m.world.random_ground()
	return q

## A bot of the first squad (not its lead) and a rival, staged d metres apart on open ground.
func _duo(d: float, skill: float) -> Array:
	_fresh()
	var at := _open_spot(int(d) + 3)
	var mates := m.hunters.filter(func(x): return x.team == 0)
	var lead := BotSquad.lead(m, mates[0])
	var bot: Hunter = mates.filter(func(x): return x != lead)[0]
	var foe: Hunter = m.hunters.filter(func(x): return x.team != 0)[0]
	for h in m.hunters:
		_put(h, _far_spot(at))
	_put(bot, at)
	_put(foe, at + Vector3(d, 0, 0))
	foe.max_hp = 1e6      # it soaks the bot's shots: the case is about the bot, not the trade
	foe.hp = 1e6
	bot.ctrl = "bot"
	bot.ai = m.bot_brain.new_mind(m.rng, skill)
	bot.ai["skill"] = skill
	bot.ai["think"] = 0.0
	return [bot, foe, at]

func _run(t: float) -> void:
	for i in int(t / Match.DT):
		m.step(Match.DT)

func _retreat() -> void:
	var s := _duo(6.0, 1.0)
	var bot: Hunter = s[0]
	var foe: Hunter = s[1]
	bot.hp = bot.max_hp * 0.25
	var d0 := bot.flat_dist(foe)
	_run(2.5)
	var d1 := bot.flat_dist(foe)
	ok(BotRetreat.on(m, bot) and d1 > d0 + 3.0, "retreat: at 25%% health a bot backs off (%.1f m -> %.1f m)" % [d0, d1])

func _tiers() -> void:
	var s := _duo(6.0, 1.0)
	var bot: Hunter = s[0]
	var foe: Hunter = s[1]
	bot.hp = bot.max_hp * 0.25
	var n := {}
	seed(5)
	for sk in [0.15, 0.92]:
		bot.ai["skill"] = sk
		n[sk] = 0
		for i in 60:
			bot.ai["rt_until"] = -1.0
			bot.ai["rt_next"] = -1.0
			if BotRetreat.spot(m, bot, foe) != Vector3.INF: n[sk] += 1
	ok(n[0.92] > n[0.15] + 15 and n[0.15] < 60, "tiers: expert backs off %d/60, easy %d/60" % [n[0.92], n[0.15]])

func _belt() -> void:
	var s := _duo(6.0, 1.0)
	var bot: Hunter = s[0]
	bot.hp = bot.max_hp * 0.45       # (above the retreat line: this one stands and fights)
	UtilityBelt.grant(bot, "medkit", 1)
	var i := UtilityBelt.slot_of(bot, "medkit")
	_run(4.0)
	ok(i >= 0 and UtilityBelt.slot_of(bot, "medkit") < 0, "belt: a hurt bot in a fight uses its mending kit")

func _regroup() -> void:
	var s := _duo(6.0, 0.6)
	var bot: Hunter = s[0]
	var foe: Hunter = s[1]
	_put(foe, _far_spot(bot.pos))
	var lead := BotSquad.lead(m, bot)
	_put(lead, _far_spot(bot.pos))
	m.bot_brain._choose(m, bot)
	ok(String(bot.ai["goal_kind"]) == "regroup" and bot.ai["goal"].distance_to(lead.pos) < 1.0,
		"regroup: %d m from the lead, a calm bot heads back to it (goal %s)" % [
			bot.flat_dist(lead), bot.ai["goal_kind"]])

func _focus() -> void:
	var s := _duo(6.0, 0.9)
	var bot: Hunter = s[0]
	var at: Vector3 = s[2]
	var foes := m.hunters.filter(func(x): return x.team != 0)
	_put(foes[1], at + Vector3(-7.0, 0, 0))     # the squadmate's rival, a little further than the other
	var mate: Hunter = m.hunters.filter(func(x): return x.team == 0 and x != bot)[0]
	_put(mate, at + Vector3(-1.0, 0, 3.0))
	mate.ai["tgt"] = foes[1]
	m.bot_brain._choose(m, bot)
	ok(bot.ai["tgt"] == foes[1], "focus: with rivals at 6 m and 7 m, the bot joins its squadmate's fight")
