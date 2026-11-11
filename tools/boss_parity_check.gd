extends RefCounted
## --boss-parity-check: a lair boss against the parity table (docs/CAMP_PARITY.md). Its phases start at
## Boss.PHASE_HP, an empty lair resets it after Boss.LEASH_T (asleep, full health, phase 0, back in the
## middle), and the last hit's squad takes the kill: the XP (KillXp.BOSS_XP, squadmates near it too), the
## kill stat and the perk-orb fan, while the squad that only dealt damage gets none. Never touches the save.

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("BOSSPARITY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(sec: float) -> void:
	var t := 0.0
	while t < sec:
		for h in m.hunters:
			h.hp = h.max_hp
		m.step(Match.DT)
		t += Match.DT

func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO

func _wake(L: Dictionary, P: Hunter) -> Boss:
	for g in L["guards"]:
		if is_instance_valid(g) and not g.dead:
			g.dead = true
			g.visible = false
	if L["state"] == "sealed":
		m.lairs.open(L, P, "dial")
	_spot(P, L["c"] + Vector3(L["out"].x, 0, L["out"].y) * 3.0)
	var b: Boss = L["boss_mob"]
	b.hurt(1.0, P, {"src": "shot"})
	_run(0.3)
	return b

func _phase_at(b: Boss, frac: float) -> int:
	b.hp = b.max_hp * frac
	_run(0.2)
	return b.phase

func run(main: Node) -> void:
	main.set_meta("boss_parity_check", self)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var P: Hunter = m.player
	P.set_arch("")
	var C: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var rivals: Array = m.hunters.filter(func(x): return x.team != P.team)
	var Q: Hunter = rivals[0]
	var Q2: Hunter = rivals[1]
	for h in m.hunters:
		h.ctrl = "idle" if h != P else "local"
	for L in m.lairs.list: m.lairs.activate(L)
	var F: Dictionary = m.lairs.list[0]
	for L in m.lairs.list:
		if String(L["boss"]) == "colossus":
			F = L
	# 1. the phases start at Boss.PHASE_HP
	var b := _wake(F, P)
	ok(not b.dormant and b.phase == 0, "awake in phase 0 at full health")
	ok(_phase_at(b, Boss.PHASE_HP[0] + 0.01) == 0, "phase 0 just above %d%% health" % int(Boss.PHASE_HP[0] * 100))
	ok(_phase_at(b, Boss.PHASE_HP[0] - 0.01) == 1, "phase 1 just below %d%% health" % int(Boss.PHASE_HP[0] * 100))
	ok(_phase_at(b, Boss.PHASE_HP[1] - 0.01) == 2, "phase 2 just below %d%% health" % int(Boss.PHASE_HP[1] * 100))
	# 2. the lair empties: after Boss.LEASH_T it is asleep, whole and back in the middle
	_spot(P, F["c"] + Vector3(60, 0, 0))
	_run(Boss.LEASH_T - 1.0)
	ok(not b.dormant, "still awake %.0f s after the lair emptied" % (Boss.LEASH_T - 1.0))
	_run(2.0)
	var home: float = Vector2(b.pos.x - F["c"].x, b.pos.z - F["c"].z).length()
	ok(b.dormant and b.phase == 0 and not b.enraged and is_equal_approx(b.hp, b.max_hp) and home < 0.1,
		"empty for %.0f s: asleep, phase 0, full health, home (%.1f m off)" % [Boss.LEASH_T, home])
	# 3. the last hit's squad takes the kill; the squad that dealt the damage gets nothing
	b = _wake(F, P)
	_spot(C, F["c"] + Vector3(-F["out"].y, 0, F["out"].x) * 3.0)
	_spot(Q, F["c"] + Vector3(F["out"].x, 0, F["out"].y) * 5.0)
	_spot(Q2, F["c"] + Vector3(F["out"].y, 0, -F["out"].x) * 10.0)
	b.stagger_t = 0.0
	b.hurt(b.hp * 0.95, P, {"src": "shot"})
	b.stagger_t = 0.0
	var dealt := float(b.damage_by.get(P.team, 0.0)) / b.max_hp
	ok(not b.dead and dealt > 0.9, "P's squad has dealt %d%% and it stands" % int(dealt * 100))
	for h in m.hunters:
		h.xp = 0.0      # (nothing steps between here and the kill)
	var orbs0 := PerkOrbs.list(m).size()
	b.hurt(b.hp + b.max_hp, Q, {"src": "shot"})
	ok(b.dead and F["cleared_by"] == Q.pname, "the last hitter (%s) is credited the kill" % F["cleared_by"])
	ok(is_equal_approx(Q.xp, KillXp.BOSS_XP) and is_equal_approx(Q2.xp, KillXp.BOSS_XP),
		"the last hitter and a squadmate 10 m off get the %d kill XP (%.1f, %.1f)" % [int(KillXp.BOSS_XP), Q.xp, Q2.xp])
	ok(P.xp == 0.0 and C.xp == 0.0, "the squad that did the damage gets none (%.1f, %.1f)" % [P.xp, C.xp])
	ok(int(Q.stats.get("bosses", 0)) == 1 and int(P.stats.get("bosses", 0)) == 0,
		"the boss kill stat goes to the last hitter")
	ok(PerkOrbs.list(m).size() > orbs0, "the perk-orb fan dropped (%d orbs)" % (PerkOrbs.list(m).size() - orbs0))
	print("BOSSPARITY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
