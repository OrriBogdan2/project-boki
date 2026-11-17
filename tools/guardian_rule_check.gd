extends RefCounted
## --guardian-rule-check: a team is out the moment nobody stands and no revive can still happen (KinWispForm.mark,
## Match._check_team). In a 2v2 with a bot teammate, the last standing member goes down:
##   1. no Boki summoned (both on the shoulder): the team is wiped in the same step
##   2. a Boki summoned when its Hunter went down: the team stays in for that pull, which brings them back
##   3. that guardian Boki is killed: the team is wiped at once
##   4. a Boki summoned only after its Hunter went down is no guardian: wiped, and it pulls nobody up
##   5. the pull runs out (enemy on the Wisp): wiped
## Never touches the save.

const DT := 1.0 / 60.0

var bad := 0
var m: Match
var main: Node
var P: Hunter
var bot: Hunter
var foe: Hunter
var spot: Vector3

func ok(cond: bool, what: String) -> void:
	print("GUARDRULE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	m.opts["sim_keep"] = true       # the player going out must not end the match (the next case reuses it)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	P = m.player
	bot = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	foe = m.hunters.filter(func(x): return x.team != P.team)[0]
	spot = m.world.random_ground()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h.kin == null:
			m.give_kin(h, m.bot_kin_record())
		_put(h, spot + Vector3(-25, 0, 3) if h.team != P.team else spot)
	_put(P, spot + Vector3(25, 0, 0))
	_case_no_boki()
	_case_guardian_pulls()
	_case_guardian_killed()
	_case_late_summon()
	_case_pull_stopped()
	print("GUARDRULE CHECK %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)

## Everyone on the team back up, standing apart, Boki on the shoulders, nothing out.
func _reset() -> void:
	for h in [bot, P]:
		h.out = false
		h.gone = false
		h.downed = false
		h.hp = h.max_hp
		h.remove_meta("stomped")
		for k in [h.kin, h.kin2]:
			if k:
				k.dead = false
				k.hp = k.max_hp
				k.state = "shoulder"
				k.cmd = "return"
				k.hesitate_t = 0.0
				k.hesitate_to = Vector3.INF
				k.pend_skill = Vector3.INF
				k.remove_meta("guard_until")
	_put(foe, spot + Vector3(-25, 0, 3))
	_put(bot, spot)
	_put(P, spot + Vector3(25, 0, 0))
	m.over = false
	m.result = {}

func _put(h: Ent, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO

func _run(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit and not cond.call():
		m.step(DT)
		t += DT
	return t

## Both teammates knocked, the bot (first) with its Boki in `bot_state`; P's Boki stays on the shoulder.
func _both_down(bot_state: String) -> void:
	bot.kin.state = bot_state
	m.knock(bot, foe, {})
	_run(DT)
	m.knock(P, foe, {})

func _case_no_boki() -> void:
	_reset()
	_both_down("shoulder")
	ok(bot.out and P.out, "1. no Boki summoned: the whole team is out in the same step")
	ok(String(P.get_meta("died_why", "")) == "team wiped", "1. reason: team wiped")

func _case_guardian_pulls() -> void:
	_reset()
	_both_down("active")
	ok(bot.downed and P.downed and not bot.out and not P.out, "2. a summoned Boki: the team stays in for the pull")
	var t := _until(func(): return not bot.downed, KinWispForm.GUARD_CAP + 1.0)
	ok(not bot.downed and not bot.out and t < KinWispForm.GUARD_CAP, "2. the guardian pulls its Hunter up (%.1fs)" % t)
	_run(1.0)
	ok(P.downed and not P.out and P.revive <= 0.0, "2. the unsummoned Boki pulls nobody up")

func _case_guardian_killed() -> void:
	_reset()
	_both_down("active")
	_run(0.5)
	ok(not bot.out, "3. the guardian is still pulling")
	bot.kin.go_down()
	_run(DT)
	ok(bot.out and P.out, "3. the guardian is killed: the team is wiped at once")

func _case_late_summon() -> void:
	_reset()
	m.knock(bot, foe, {})
	_run(DT)
	bot.kin.state = "active"
	_run(0.5)
	m.knock(P, foe, {})
	ok(bot.out and P.out, "4. a Boki summoned after the knock keeps no one in: wiped")
	_reset()
	m.knock(bot, foe, {})
	bot.kin.state = "active"
	_run(KinWispForm.GUARD_CAP * 0.5)
	ok(bot.downed and bot.revive <= 0.0, "4. and it never pulls its Hunter up (%.2f)" % bot.revive)

func _case_pull_stopped() -> void:
	_reset()
	_both_down("active")
	_put(foe, bot.pos)
	_run(0.5)
	ok(bot.out and P.out, "5. an enemy on the Wisp stops the pull: wiped")
