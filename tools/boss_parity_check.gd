extends RefCounted
## --boss-parity-check: a lair boss against the parity table (docs/CAMP_PARITY.md). Woken from outside
## (no seal), it resets after Boss.LEASH_T with nobody inside: asleep, full health, phase 0, back in the
## middle. Its phases start at Boss.PHASE_HP, and a reset mid-roar leaves no armour behind. The last hit's
## squad takes the kill: the XP (KillXp.BOSS_XP, squadmates near it too), the kill stat and the perk-orb
## fan, while the squad that only dealt damage gets none. Never touches the save.

var bad := 0
var m: Match


func ok(cond: bool, what: String) -> void:
	print("BOSSPARITY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


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


## Opens the lair, stands P at `at` and wakes the boss with a hit from there.
func _wake(L: Dictionary, P: Hunter, at: Vector3) -> Boss:
	for g in L["guards"]:
		if is_instance_valid(g) and not g.dead:
			g.dead = true
			g.visible = false
	if L["state"] == "sealed":
		m.lairs.open(L, P, "dial")
	_spot(P, at)
	var b: Boss = L["boss_mob"]
	b.hurt(1.0, P, {"src": "shot"})
	_run(0.3)
	return b


## A spot on solid ground just outside the lair's gate.
func _outside(L: Dictionary) -> Vector3:
	var out := Vector3(L["out"].x, 0, L["out"].y)
	for d in range(3, 12):
		var p: Vector3 = L["c"] + out * (float(L["half"]) + float(d))
		if not m.world.is_void(p.x, p.z) and not m.world.is_block(p.x, p.z):
			return p
	return L["c"] + out * (float(L["half"]) + 3.0)


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
	for L in m.lairs.list:
		m.lairs.activate(L)
	var F: Dictionary = m.lairs.list[0]
	for L in m.lairs.list:
		if String(L["boss"]) == "colossus":
			F = L
	var c: Vector3 = F["c"]
	var out := Vector3(F["out"].x, 0, F["out"].y)
	var side := Vector3(-out.z, 0, out.x)
	# 1. woken from outside the gate, nobody inside: no seal, and after Boss.LEASH_T it resets
	var b := _wake(F, P, _outside(F))
	ok(
		not b.dormant and not F.get("locked", false) and not m.lairs.inside(F, P.pos, 0.25),
		"woken by a hit from outside: awake, no seal, P stays out"
	)
	b.hp = b.max_hp * 0.5
	_run(Boss.LEASH_T - 1.5)
	ok(not b.dormant and b.phase == 1, "still awake (phase %d) %.0f s after waking" % [b.phase, Boss.LEASH_T - 1.2])
	_run(2.0)
	var home: float = Vector2(b.pos.x - c.x, b.pos.z - c.z).length()
	ok(
		b.dormant and b.phase == 0 and is_equal_approx(b.hp, b.max_hp) and home < 0.1,
		"empty for %.0f s: asleep, phase 0, full health, home (%.1f m off)" % [Boss.LEASH_T, home]
	)
	# 2. inside, sealed in: the phases start at Boss.PHASE_HP
	b = _wake(F, P, c + out * 3.0)
	ok(not b.dormant and b.phase == 0 and F.get("locked", false), "woken from inside: sealed, phase 0")
	ok(_phase_at(b, Boss.PHASE_HP[0] + 0.01) == 0, "phase 0 just above %d%% health" % int(Boss.PHASE_HP[0] * 100))
	ok(_phase_at(b, Boss.PHASE_HP[0] - 0.01) == 1, "phase 1 just below %d%% health" % int(Boss.PHASE_HP[0] * 100))
	ok(_phase_at(b, Boss.PHASE_HP[1] - 0.01) == 2, "phase 2 just below %d%% health" % int(Boss.PHASE_HP[1] * 100))
	# 3. a reset during the phase roar (a wipe, the seal running out) leaves a clean boss
	ok(b.invul_t > 0.0, "the phase roar armours it (%.1f s)" % b.invul_t)
	m.lairs.reset_boss(b)
	ok(
		b.dormant and b.phase == 0 and b.invul_t == 0.0 and b.empty_t == 0.0 and not F.get("locked", false),
		"reset mid-roar: asleep, unsealed, no armour or empty-lair time left over"
	)
	# 4. the last hit's squad takes the kill; the squad that dealt the damage gets nothing
	b = _wake(F, P, c + out * 3.0)
	_spot(C, c + side * 3.0)
	_spot(Q, c + out * 5.0)
	_spot(Q2, c - side * 5.0)
	b.stagger_t = 0.0
	b.hurt(b.hp * 0.95, P, {"src": "shot"})
	b.stagger_t = 0.0
	var dealt := float(b.damage_by.get(P.team, 0.0)) / b.max_hp
	ok(not b.dead and dealt > 0.9, "P's squad has dealt %d%% and it stands" % int(dealt * 100))
	for h in m.hunters:
		h.xp = 0.0  # (nothing steps between here and the kill)
	var orbs0 := PerkOrbs.list(m).size()
	b.hurt(b.hp + b.max_hp, Q, {"src": "shot"})
	var by := String(F.get("cleared_by", ""))
	ok(b.dead and by == Q.pname, "the last hitter (%s) is credited the kill" % by)
	ok(
		is_equal_approx(Q.xp, KillXp.BOSS_XP) and is_equal_approx(Q2.xp, KillXp.BOSS_XP),
		"the last hitter and a squadmate get the %d kill XP (%.1f, %.1f)" % [int(KillXp.BOSS_XP), Q.xp, Q2.xp]
	)
	ok(P.xp == 0.0 and C.xp == 0.0, "the squad that did the damage gets none (%.1f, %.1f)" % [P.xp, C.xp])
	ok(
		int(Q.stats.get("bosses", 0)) == 1 and int(P.stats.get("bosses", 0)) == 0,
		"the boss kill stat goes to the last hitter"
	)
	ok(PerkOrbs.list(m).size() > orbs0, "the perk-orb fan dropped (%d orbs)" % (PerkOrbs.list(m).size() - orbs0))
	print("BOSSPARITY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
