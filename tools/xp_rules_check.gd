extends RefCounted
## --xp-rules-check: the XP rules (DECISIONS 2026-11-10) in a scripted two-squad bot match, one row each:
## no passive XP; hitting a Hunter pays no level XP (armour only); a monster's damage pays none; a kill
## pays the last hitter and teammates within 30 m; a rival squad that steals the last hit takes the XP,
## on a plain monster and on a lair boss. Never touches the save.

const SHARE_R := 30.0      # m: the kill-share radius in the decision
const STEP := 1.0 / 30.0      # s per Match.step while time passes
const IDLE_S := 60.0      # s a bot squad stands still for the passive-XP row

var bad := 0
var m: Match


func ok(cond: bool, what: String) -> void:
	print("XPRULES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO


func _zero_xp() -> void:
	for h in m.hunters:
		h.xp = 0.0
		h.lvl = 1


func _xps() -> String:
	return ", ".join(m.hunters.map(func(h): return "%.1f" % h.xp))


## A skitter at `at` that dies to the last of `hits`, each a [hunter, damage] pair.
func _kill(at: Vector3, hits: Array) -> void:
	var mob := m.spawn_mob("skitter", at)
	var total := 0.0
	for h in hits:
		total += float(h[1])
	mob.max_hp = total
	mob.hp = total
	for h in hits:
		mob.hurt(float(h[1]), h[0], {})
	m.mobs.erase(mob)
	mob.queue_free()


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	P.set_arch("")
	var C: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var foes: Array = m.hunters.filter(func(x): return x.team != P.team)
	var Q: Hunter = foes[0]
	var Q2: Hunter = foes[1]
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var spot: Vector3 = m.world.spawns[0]
	for h in foes:
		_spot(h, m.world.spawns[-1])
	# ---- 1. no passive XP: a bot squad stands still for a minute
	_zero_xp()
	for i in int(IDLE_S / STEP):
		m.step(STEP)
	ok(m.hunters.all(func(h): return h.xp == 0.0), "no passive XP in %d s of standing (%s)" % [int(IDLE_S), _xps()])
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	# ---- 2. hitting a Hunter: armour progress, no level XP
	P.armor_xp = 0.0
	P.armor_tier = 0
	_zero_xp()
	_spot(Q, spot + Vector3(8, 0, 0))
	Q.downed = false
	Q.hp = Q.max_hp
	m.on_damage(Q, P, 30.0, {})
	ok(P.xp == 0.0 and P.lvl == 1, "30 damage on a rival Hunter gives no level XP (%.1f)" % P.xp)
	ok(P.armor_xp > 0.0, "the same hit builds armour (%.1f)" % P.armor_xp)
	# ---- 3. monster damage pays nothing; a kill pays the last hitter and squadmates within 30 m
	_spot(P, spot)
	_spot(C, spot + Vector3(2, 0, 0))
	_zero_xp()
	var big := m.spawn_mob("brute", spot)
	big.hurt(big.max_hp * 0.9, P, {})
	ok(not big.dead and P.xp == 0.0 and C.xp == 0.0, "90%% of a monster's health in damage pays no XP (%s)" % _xps())
	m.mobs.erase(big)
	big.queue_free()
	_zero_xp()
	_spot(C, spot + Vector3(25, 0, 0))
	_kill(spot, [[P, 10.0]])
	ok(P.xp > 0.0 and is_equal_approx(P.xp, C.xp),
		"the killer and a squadmate at 25 m are paid the same (%.1f, %.1f)" % [P.xp, C.xp])
	var paid := P.xp
	_zero_xp()
	_spot(C, spot + Vector3(SHARE_R + 10.0, 0, 0))
	_kill(spot, [[P, 10.0]])
	ok(is_equal_approx(P.xp, paid) and C.xp == 0.0, "a squadmate at 40 m is not paid (%.1f)" % C.xp)
	# ---- 4. a stolen last hit on a plain monster
	_zero_xp()
	_spot(Q, spot)
	_spot(Q2, spot + Vector3(5, 0, 0))
	_spot(P, spot + Vector3(-5, 0, 0))
	_spot(C, spot + Vector3(0, 0, 5))
	_kill(spot, [[P, 9.0], [Q, 1.0]])
	ok(Q.xp > 0.0 and Q2.xp > 0.0 and P.xp == 0.0 and C.xp == 0.0,
		"the squad that lands the last hit gets the XP, the one that did 90%% gets none (%s)" % _xps())
	# ---- 5. a stolen last hit on a lair boss
	for L in m.lairs.list:
		m.lairs.activate(L)
	var F: Dictionary = m.lairs.list[0]
	for L in m.lairs.list:
		if String(L["boss"]) == "colossus":
			F = L
	for g in F["guards"]:
		if is_instance_valid(g) and not g.dead:
			g.dead = true
			g.visible = false
	if F["state"] == "sealed":
		m.lairs.open(F, P, "dial")
	var c: Vector3 = F["c"]
	var out := Vector3(F["out"].x, 0, F["out"].y)
	var side := Vector3(-F["out"].y, 0, F["out"].x)
	_spot(P, c + out * 3.0)
	_spot(C, c + side * 3.0)
	_spot(Q, c - out * 3.0)
	_spot(Q2, c - side * 3.0)
	m.step(STEP)
	var b: Boss = F["boss_mob"]
	if b.buried:
		b._clear_attack()
	b.stagger_t = 0.0
	b.hurt(b.hp * 0.95, P, {"src": "shot"})
	b.stagger_t = 0.0
	ok(float(b.damage_by.get(P.team, 0.0)) > b.max_hp * 0.9 and not b.dead,
		"squad A has dealt over 90%% of the boss, it stands")
	_zero_xp()
	b.hurt(b.hp + b.max_hp, Q, {"src": "shot"})
	ok(b.dead, "squad B's last hit kills it")
	ok(Q.xp > 0.0 and is_equal_approx(Q.xp, Q2.xp), "squad B takes the boss's XP (%s)" % _xps())
	ok(P.xp == 0.0 and C.xp == 0.0, "squad A, with 95%% of the damage, gets none (%.1f, %.1f)" % [P.xp, C.xp])
	ok(int(Q.stats.get("bosses", 0)) == 1 and int(P.stats.get("bosses", 0)) == 0, "the kill bonus (boss stat) is B's")
	print("XPRULES done, %d fail" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
