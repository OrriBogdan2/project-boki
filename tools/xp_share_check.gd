extends RefCounted
## --xp-share-check: a monster's XP goes to the Hunter who lands the last hit and to their squadmates
## within XpRules' share_r of the killer, nothing for damage alone. A squad that deals 95% of each lair boss
## and loses the last hit to a rival gets no XP; the kill's other rewards (stat and gear) go to the
## killer too, and so does its Boon of the Hunt (HuntBoon), so the rival squad takes it all, and the
## feed names the stealer (KillSteal). Never touches the save.

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
	var want := float(XpRules.rules()["stray"])
	var boss_xp := float(XpRules.rules()["boss"])
	ok(is_equal_approx(float(XpRules.rules()["share_r"]), 30.0), "the share radius is 30 m")
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
	# ---- 3. every lair boss: A deals 95%, B last-hits
	for L in m.lairs.list:
		m.lairs.activate(L)
	var kinds := {}
	for L in m.lairs.list:
		if not kinds.has(String(L["boss"])):
			kinds[String(L["boss"])] = true
			_steal_boss(L, [Q, Q2], [P, C], boss_xp)
	ok(kinds.size() >= 3, "every lair boss kind is fought (%s)" % ", ".join(kinds.keys()))
	var steals: Array = m.feed_all.filter(func(f): return " stole " in String(f))
	ok(steals.size() == kinds.size(),
		"a stolen skitter carries no kill bonus, so only the bosses are called out (%d)" % steals.size())
	print("XPSHARE done, %d fail" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## Lair `F`'s boss: squad `A` deals 95% of it, squad `B`'s first Hunter lands the last hit. B (its
## killer and the squadmate beside them) gets the boss's XP and Boon of the Hunt, the boss stat goes to
## the killer, A gets nothing, and the feed names the stealer.
func _steal_boss(F: Dictionary, A: Array, B: Array, boss_xp: float) -> void:
	var kind := String(F["boss"])
	for g in F["guards"]:
		if is_instance_valid(g) and not g.dead:
			g.dead = true
			g.visible = false
	if F["state"] == "sealed":
		m.lairs.open(F, A[0], "dial")
	var c: Vector3 = F["c"]
	var out := Vector3(F["out"].x, 0, F["out"].y)
	var side := Vector3(-F["out"].y, 0, F["out"].x)
	_spot(A[0], c + out * 3.0)
	_spot(A[1], c + side * 3.0)
	_spot(B[0], c - out * 3.0)
	_spot(B[1], c - side * 3.0)
	m.step(Match.DT)
	var b: Boss = F["boss_mob"]
	if b.buried:
		b._clear_attack()
	b.stagger_t = 0.0
	# (small hits until A is past 90%: a kit bonus, e.g. the Juggernaut's rage, can turn one big hit into the kill)
	while float(b.damage_by.get(A[0].team, 0.0)) <= b.max_hp * 0.92 and not b.dead:
		b.hurt(b.max_hp * 0.02, A[0], {"src": "shot"})
		b.stagger_t = 0.0
	ok(float(b.damage_by.get(A[0].team, 0.0)) > b.max_hp * 0.9 and not b.dead,
		"%s: squad A has dealt over 90%% of it and it still stands" % kind)
	_zero_xp()      # (nothing steps between here and the kill)
	var bosses: Array = (A + B).map(func(h): return int(h.stats.get("bosses", 0)))
	for h in A + B:
		h.set_meta("bon_until", 0.0)
	b.hurt(b.hp + b.max_hp, B[0], {"src": "shot"})
	ok(b.dead, "%s: squad B's last hit kills it" % kind)
	ok(is_equal_approx(B[0].xp, boss_xp) and is_equal_approx(B[1].xp, boss_xp),
		"%s: squad B, killer and squadmate, gets the %d XP (%.2f, %.2f)" % [kind, int(boss_xp), B[0].xp, B[1].xp])
	ok(A[0].xp == 0.0 and A[1].xp == 0.0,
		"%s: squad A, with 95%% of the damage, gets none (%.2f, %.2f)" % [kind, A[0].xp, A[1].xp])
	var won: Array = (A + B).map(func(h): return int(h.stats.get("bosses", 0)))
	ok(won[2] == bosses[2] + 1 and won[0] == bosses[0] and won[1] == bosses[1],
		"%s: the boss kill itself is credited to B, not A" % kind)
	var boon := float(XpRules.rules()["boon"]["secs"])
	var b_got := absf(HuntBoon.left(B[0]) - boon) < 0.01 and absf(HuntBoon.left(B[1]) - boon) < 0.01
	ok(b_got and HuntBoon.left(A[0]) == 0.0 and HuntBoon.left(A[1]) == 0.0,
		"%s: squad B also takes its Boon of the Hunt (%.0f s), squad A none" % [kind, boon])
	var line := String(m.feed_all[-1]) if not m.feed_all.is_empty() else ""
	var named := "%s stole %s from %s" % [B[0].pname, b.md["name"], m.truce.squad_name(A[0].team)]
	ok(line.ends_with(named), "%s: the feed calls out the steal, naming the stealer (%s)" % [kind, line])
