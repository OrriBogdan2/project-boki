extends RefCounted
## --bot-downed-check: bots play downed teammates like a fair player (scripts/match/bot_rescue.gd). Scripted
## 1v2 setups on open ground (a bot and a downed squadmate against two rivals):
##   1. calm: a rival far off, the bot revives the squadmate
##   2. an enemy Well on the wisp: the bot waits outside its rim; once it is gone the bot revives
##   3. under fire and low: the bot gives up the revive; healthy, it takes the shooter on first
##   4. a Meeko bot with a rival closing in carries the wisp away, then sets it down when calm and revives
##   5. a rival's wisp in sight: the bot finishes it
##   6. Boki wisps on (KinSteal, DECISIONS 11-09 stealing): a downed rival's Boki wisp floats loose; with a rival
##      standing over it the bot leaves it, once clear the bot grabs it; a downed teammate's wisp is left for its owner
## Prints BOTDOWNED ok/FAIL.

var bad := 0
var m: Match
var main: Node
var bot: Hunter
var mate: Hunter
var foes: Array = []

func ok(cond: bool, what: String) -> void:
	print("BOTDOWNED %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _put(h: Hunter, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO

## Random ground well away from `at` (parks a hunter out of the way).
func _far(at: Vector3) -> Vector3:
	var g := m.world.random_ground()
	for k in 100:
		if g.distance_to(at) > 60.0: break
		g = m.world.random_ground()
	return g

func _roomy(p: Vector3, r: int) -> bool:
	var w := m.world
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var q := p + Vector3(dx, 0, dz)
			if w.is_void(q.x, q.z) or w.is_block(q.x, q.z) or absf(w.ground_at(q.x, q.z) - w.ground_at(p.x, p.z)) > 0.3:
				return false
	return true

## A fresh two-team match with the bot (team of the player), the player as the downed squadmate and two rivals.
func _fresh(home: Vector3, arch := "", wisps := false) -> void:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	var o := {"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true}
	if wisps:
		o.merge({"demo_kin": "cindle", "boki_wisps": true})
	m.start(o)
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		for kk in [h.kin, h.kin2]:
			if kk and wisps:
				if kk.summon: kk.summon.cd = 60.0      # resting: a ready summon guards its downed hunter instead (0040)
			elif kk:
				m.kins.erase(kk)
				kk.queue_free()
		if not wisps:
			h.kin = null
			h.kin2 = null
	mate = m.player
	var mates: Array = m.hunters.filter(func(x): return x.team == mate.team and x != mate)
	bot = mates[0]
	foes = m.hunters.filter(func(x): return x.team != mate.team)
	for h in m.hunters:
		if h != mate and h != bot and h != foes[0] and h != foes[1]:
			_put(h, _far(home))
	if arch != "":
		# its own class: set_arch keeps the bot's, and Arch.fix then drops the kit
		bot.reclass(Arch.weight(arch), arch)
		bot.unlock_all()
	for f in foes:
		f.max_hp = 1e6
		f.hp = 1e6        # they soak shots, so a test isn't won by killing them
	_put(mate, home)
	_put(bot, home + Vector3(8, 0, 0))
	_put(foes[0], home + Vector3(-8, 0, 0))
	_put(foes[1], _far(home))
	m.knock(mate, foes[0], {})
	mate.ctrl = "idle"
	mate.down_hp = 1e6        # no bleeding out mid-test
	bot.ctrl = "bot"
	bot.ai = m.bot_brain.new_mind(m.rng, 0.6)
	bot.ai["think"] = 0.0

## Steps up to `limit` seconds, or until `done` is true; returns the time taken (limit if never).
func _run(limit: float, done: Callable) -> float:
	var t := 0.0
	while t < limit and not done.call():
		m.step(Match.DT)
		t += Match.DT
	return t

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_fresh(Vector3.ZERO)
	var home := Vector3.INF
	for k in 3000:
		var g := m.world.random_ground()
		if _roomy(g, 9):
			home = g
			break
	ok(home != Vector3.INF, "found open ground")
	if home == Vector3.INF:
		_finish()
		return
	_calm(home)
	_aoe(home)
	_under_fire(home)
	_carry(home)
	_finish_rival(home)
	_steal(home)
	_finish()

func _calm(home: Vector3) -> void:
	_fresh(home)
	var t := _run(14.0, func(): return not mate.downed)
	ok(not mate.downed, "calm: the bot revives its squadmate (%.1fs)" % t)

func _aoe(home: Vector3) -> void:
	_fresh(home)
	m.add_zone("well", home, 6.0, 60.0, foes[0].team, foes[0])
	var ours := BotRescue.in_hostile_aoe(m, bot, home)
	var theirs := BotRescue.in_hostile_aoe(m, foes[0], home + Vector3(2, 0, 0))
	ok(ours and not theirs, "enemy Well: an enemy area for us, not for its owner")
	var closest := 1e9
	var t := 0.0
	while t < 9.0 and mate.downed:
		m.step(Match.DT)
		t += Match.DT
		closest = minf(closest, bot.flat_dist(home))
	ok(mate.downed and closest > 6.0, "enemy Well: the bot keeps out (closest %.1fm of 6.0)" % closest)
	ok(bot.flat_dist(home) < 12.0, "...and waits at its rim, not off on a loot run (%.1fm)" % bot.flat_dist(home))
	for z in m.zones.duplicate():
		(z["node"] as Node).queue_free()
		m.zones.erase(z)
	t = _run(14.0, func(): return not mate.downed)
	ok(not mate.downed, "enemy Well gone: the bot revives (%.1fs)" % t)

func _under_fire(home: Vector3) -> void:
	_fresh(home)
	var shooter: Hunter = foes[0]
	_put(shooter, home + Vector3(-9, 0, 0))
	bot.last_hit_by = shooter
	bot.hurt_at = m.time
	var plan: Dictionary = m.bot_brain._revive_plan(m, bot)
	ok(plan.get("danger") == shooter, "under fire, healthy: the shooter is dealt with before the revive")
	bot.hp = bot.max_hp * 0.2
	bot.armor = 0.0
	bot.hurt_at = m.time
	plan = m.bot_brain._revive_plan(m, bot)
	ok(plan.is_empty() and BotRescue.gives_up(m, bot), "under fire, low: the bot gives up the revive")
	m.step(Match.DT)
	var off: bool = float(bot.ai["rv_off"]) > m.time + 3.0
	ok(off and m.bot_brain._revive_plan(m, bot).is_empty(), "...and stays off it for a few seconds")

func _carry(home: Vector3) -> void:
	_fresh(home, "tender")
	var rival: Hunter = foes[0]
	_put(rival, home + Vector3(-4, 0, 0))
	_put(bot, home + Vector3(4, 0, 0))
	var kit: TenderKit = bot.ak as TenderKit
	ok(kit != null, "a Meeko bot has her kit")
	if kit == null:
		return
	var t := _run(6.0, func(): return CareUtil.is_carried(mate))
	ok(CareUtil.is_carried(mate) and kit.carrying().size() == 1, "Meeko bot: shoulders the wisp (%.1fs)" % t)
	var d0 := bot.flat_dist(rival)
	_run(4.0, func(): return bot.flat_dist(rival) > CALM_AWAY)
	var away := bot.flat_dist(rival)
	ok(CareUtil.is_carried(mate) and away > maxf(d0, CALM_AWAY - 1.0), "...walks it away (%.1fm -> %.1fm)" % [d0, away])
	_put(rival, _far(bot.pos))
	m.step(Match.DT)
	t = _run(10.0, func(): return not CareUtil.is_carried(mate) and not mate.downed)
	ok(not mate.downed, "...sets it down once calm and revives (%.1fs)" % t)

const CALM_AWAY := 9.0      # m: how far from the rival the carry check wants the bot

func _finish_rival(home: Vector3) -> void:
	_fresh(home)
	m.revive_hunter(mate, null)
	_put(mate, home + Vector3(6, 0, 6))
	var wisp: Hunter = foes[0]
	_put(wisp, home + Vector3(-2, 0, 0))
	m.knock(wisp, bot, {})
	wisp.down_hp = 1e6        # it would bleed out on its own, and the stomp could never end it: we watch for the stomp
	var t := _run(16.0, func(): return not bot.stomp.is_empty())
	ok(not bot.stomp.is_empty() and bot.stomp["o"] == wisp, "rival wisp in sight: starts the stomp (%.1fs)" % t)

## A downed hunter's Boki wisp broken loose; the hunter is then parked far away (no stomp or revive pulls the bot).
func _loose_of(h: Hunter) -> Kin:
	var k: Kin = h.kin
	m.knock(h, foes[1] if h.team == bot.team else bot, {})
	h.down_hp = 1e6
	_run(0.2, func(): return k == null or KinSteal.loose(k))
	_put(h, _far(h.pos))
	return k if k and KinSteal.loose(k) else null

func _steal(home: Vector3) -> void:
	_fresh(home, "", true)
	m.revive_hunter(mate, null)
	_put(mate, home + Vector3(0, 0, 7))
	var rival: Hunter = foes[0]
	_put(rival, home + Vector3(-2, 0, 0))
	_put(bot, home + Vector3(6, 0, 0))
	var wk := _loose_of(rival)
	ok(wk != null, "wisps on: a downed rival's Boki wisp floats loose")
	if wk == null:
		return
	var guard: Hunter = foes[1]
	_put(guard, Vector3(wk.pos.x - 3.0, 0, wk.pos.z))
	guard.max_hp = 1e6
	guard.hp = 1e6
	_run(4.0, func(): return wk.owner_h == bot)
	ok(KinSteal.loose(wk) and wk.owner_h != bot, "...a rival stands over it: the bot leaves it (4s)")
	_put(guard, _far(bot.pos))
	var t := _run(8.0, func(): return wk.owner_h == bot)
	ok(KinSteal.stolen(wk) and wk.owner_h == bot, "...the rival gone: the bot grabs it (%.1fs)" % t)
	# a downed teammate's wisp: left for its owner (revive them instead; they take it back)
	_fresh(home, "", true)
	m.revive_hunter(mate, null)
	_put(mate, _far(home))
	var mk: Hunter = m.hunters.filter(func(x): return x.team == bot.team and x != bot and x != mate)[0]
	_put(mk, home)
	_put(bot, home + Vector3(5, 0, 0))
	var tk := _loose_of(mk)
	ok(tk != null, "a downed teammate's Boki wisp floats loose")
	if tk:
		bot.ai["rv_off"] = m.time + 10.0      # off the revive (as if it gave up), so only the grab rule decides
		_run(4.0, func(): return tk.owner_h == bot)
		ok(tk.owner_h != bot, "...the bot leaves a teammate's wisp for its owner")

func _finish() -> void:
	print("BOTDOWNED %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
	m.get_tree().quit(1 if bad > 0 else 0)
