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
	var pc: Hunter = m.player
	pc.set_arch("")
	var cc: Hunter = m.hunters.filter(func(x): return x.team == pc.team and x != pc)[0]
	var foes: Array = m.hunters.filter(func(x): return x.team != pc.team)
	var q1: Hunter = foes[0]
	var q2: Hunter = foes[1]
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var spot: Vector3 = m.world.spawns[0]
	for h in foes:
		_spot(h, m.world.spawns[-1])
	# ---- 1. a monster: last hit and squadmates in range
	var want := 10.0 * KillXp.XP_PER_HP
	ok(is_equal_approx(KillXp.SHARE_R, 30.0), "the share radius is 30 m")
	_spot(pc, spot)
	_spot(cc, spot + Vector3(25, 0, 0))
	_kill(spot, [[pc, 10.0]])
	ok(
		is_equal_approx(pc.xp, want) and is_equal_approx(cc.xp, want),
		"killer and a squadmate at 25 m get the monster's XP in full (%.1f, %.1f of %.1f)" % [pc.xp, cc.xp, want]
	)
	_zero_xp()
	_spot(cc, spot + Vector3(40, 0, 0))
	_kill(spot, [[pc, 10.0]])
	ok(is_equal_approx(pc.xp, want) and cc.xp == 0.0, "a squadmate at 40 m gets none (%.1f)" % cc.xp)
	_zero_xp()
	_spot(cc, spot + Vector3(2, 0, 0))
	var big := m.spawn_mob("brute", spot)
	big.hurt(big.max_hp * 0.9, pc, {})
	ok(not big.dead and pc.xp == 0.0 and cc.xp == 0.0, "damage without the kill pays nothing")
	m.mobs.erase(big)
	big.queue_free()
	# ---- 2. a stolen last hit
	_spot(q1, spot)
	_spot(q2, spot + Vector3(5, 0, 0))
	_spot(pc, spot + Vector3(-5, 0, 0))
	_spot(cc, spot + Vector3(0, 0, 5))
	_kill(spot, [[q1, 9.0], [pc, 1.0]])
	ok(
		is_equal_approx(pc.xp, want) and is_equal_approx(cc.xp, want) and q1.xp == 0.0 and q2.xp == 0.0,
		"the squad that lands the last hit takes the XP, the squad that did 90% gets none"
	)
	# ---- 3. a lair boss: A deals 95%, B last-hits
	for lair in m.lairs.list:
		m.lairs.activate(lair)
	var fx: Dictionary = m.lairs.list[0]
	for lair in m.lairs.list:
		if String(lair["boss"]) == "colossus":
			fx = lair
	for g in fx["guards"]:
		if is_instance_valid(g) and not g.dead:
			g.dead = true
			g.visible = false
	if fx["state"] == "sealed":
		m.lairs.open(fx, q1, "dial")
	var c: Vector3 = fx["c"]
	var out := Vector3(fx["out"].x, 0, fx["out"].y)
	var side := Vector3(-fx["out"].y, 0, fx["out"].x)
	_spot(q1, c + out * 3.0)
	_spot(q2, c + side * 3.0)
	_spot(pc, c - out * 3.0)
	_spot(cc, c - side * 3.0)
	m.step(Match.DT)
	var b: Boss = fx["boss_mob"]
	if b.buried:
		b._clear_attack()
	b.stagger_t = 0.0
	b.hurt(b.hp * 0.95, q1, {"src": "shot"})
	b.stagger_t = 0.0
	ok(
		float(b.damage_by.get(q1.team, 0.0)) > b.max_hp * 0.9 and not b.dead,
		"squad A has dealt over 90% of the boss and it still stands"
	)
	_zero_xp()  # (nothing steps between here and the kill)
	b.hurt(b.hp + b.max_hp, pc, {"src": "shot"})
	ok(b.dead, "squad B's last hit kills it")
	ok(
		is_equal_approx(pc.xp, KillXp.BOSS_XP) and is_equal_approx(cc.xp, KillXp.BOSS_XP),
		"squad B gets the boss's %d XP (%.2f, %.2f)" % [int(KillXp.BOSS_XP), pc.xp, cc.xp]
	)
	ok(q1.xp == 0.0 and q2.xp == 0.0, "squad A, with 95%% of the damage, gets none (%.2f, %.2f)" % [q1.xp, q2.xp])
	ok(
		int(pc.stats.get("bosses", 0)) == 1 and int(q1.stats.get("bosses", 0)) == 0,
		"the boss kill itself is credited to B, not A"
	)
	print("XPSHARE done, %d fail" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
