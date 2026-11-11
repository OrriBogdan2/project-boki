extends RefCounted
## --xp-share-check: a monster's XP goes to the Hunter who lands the last hit and to their squadmates
## within KillXp.SHARE_R of the kill, nothing for damage alone. A squad that deals 95% of a lair boss
## and loses the last hit to a rival gets no XP; the kill's other rewards (stat and gear) go to the
## killer too, so the rival squad takes both. Never touches the save.

var bad := 0
var m: Match


func ok(cond: bool, what: String) -> void:
	print("XPSHARE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO


func _zero_xp() -> void:
	for h in m.hunters:
		h.xp = 0.0


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
	# ---- 1. a monster: last hit and squadmates in range
	var want := 10.0 * KillXp.XP_PER_HP
	ok(is_equal_approx(KillXp.SHARE_R, 30.0), "the share radius is 30 m")
	_spot(P, spot)
	_spot(C, spot + Vector3(25, 0, 0))
	_kill(spot, [[P, 10.0]])
	ok(is_equal_approx(P.xp, want) and is_equal_approx(C.xp, want),
		"killer and a squadmate at 25 m get the monster's XP in full (%.1f, %.1f of %.1f)" % [P.xp, C.xp, want])
	_zero_xp()
	_spot(C, spot + Vector3(40, 0, 0))
	_kill(spot, [[P, 10.0]])
	ok(is_equal_approx(P.xp, want) and C.xp == 0.0, "a squadmate at 40 m gets none (%.1f)" % C.xp)
	_zero_xp()
	_spot(C, spot + Vector3(2, 0, 0))
	var big := m.spawn_mob("brute", spot)
	big.hurt(big.max_hp * 0.9, P, {})
	ok(not big.dead and P.xp == 0.0 and C.xp == 0.0, "damage without the kill pays nothing")
	m.mobs.erase(big)
	big.queue_free()
	# ---- 2. a stolen last hit
	_spot(Q, spot)
	_spot(Q2, spot + Vector3(5, 0, 0))
	_spot(P, spot + Vector3(-5, 0, 0))
	_spot(C, spot + Vector3(0, 0, 5))
	_kill(spot, [[Q, 9.0], [P, 1.0]])
	ok(is_equal_approx(P.xp, want) and is_equal_approx(C.xp, want) and Q.xp == 0.0 and Q2.xp == 0.0,
		"the squad that lands the last hit takes the XP, the squad that did 90% gets none")
	# ---- 3. a lair boss: A deals 95%, B last-hits
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
		m.lairs.open(F, Q, "dial")
	var c: Vector3 = F["c"]
	var out := Vector3(F["out"].x, 0, F["out"].y)
	var side := Vector3(-F["out"].y, 0, F["out"].x)
	_spot(Q, c + out * 3.0)
	_spot(Q2, c + side * 3.0)
	_spot(P, c - out * 3.0)
	_spot(C, c - side * 3.0)
	m.step(Match.DT)
	var b: Boss = F["boss_mob"]
	if b.buried:
		b._clear_attack()
	b.stagger_t = 0.0
	b.hurt(b.hp * 0.95, Q, {"src": "shot"})
	b.stagger_t = 0.0
	ok(float(b.damage_by.get(Q.team, 0.0)) > b.max_hp * 0.9 and not b.dead,
		"squad A has dealt over 90% of the boss and it still stands")
	_zero_xp()      # (nothing steps between here and the kill)
	b.hurt(b.hp + b.max_hp, P, {"src": "shot"})
	ok(b.dead, "squad B's last hit kills it")
	ok(is_equal_approx(P.xp, KillXp.BOSS_XP) and is_equal_approx(C.xp, KillXp.BOSS_XP),
		"squad B gets the boss's %d XP (%.2f, %.2f)" % [int(KillXp.BOSS_XP), P.xp, C.xp])
	ok(Q.xp == 0.0 and Q2.xp == 0.0,
		"squad A, with 95%% of the damage, gets none (%.2f, %.2f)" % [Q.xp, Q2.xp])
	ok(int(P.stats.get("bosses", 0)) == 1 and int(Q.stats.get("bosses", 0)) == 0,
		"the boss kill itself is credited to B, not A")
	print("XPSHARE done, %d fail" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
