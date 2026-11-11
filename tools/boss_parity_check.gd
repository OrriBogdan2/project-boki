extends RefCounted
## --boss-parity-check: a lair boss against the parity rules (docs/CAMP_PARITY.md): the second phase
## at 66% health (the sourced numbers: none, ours kept), the lair emptying resets it (asleep, full health,
## phase 0, back in the middle), and the kill XP goes to the last-hit squad (within Lairs.BOSS_XP_SHARE_R),
## not to a squad that only dealt damage. Never touches the save.

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
	var Q: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	for h in m.hunters:
		h.ctrl = "idle" if h != P else "local"
	for L in m.lairs.list: m.lairs.activate(L)
	var F: Dictionary = m.lairs.list[0]
	for L in m.lairs.list:
		if String(L["boss"]) == "colossus":
			F = L
	# 1. phase at 66% health
	var b := _wake(F, P)
	ok(not b.dormant and b.phase == 0, "awake in phase 0 at full health")
	b.hp = b.max_hp * 0.67
	_run(0.2)
	ok(b.phase == 0, "phase 0 at 67%% health (%d/%d)" % [int(b.hp), int(b.max_hp)])
	b.hp = b.max_hp * 0.65
	_run(0.2)
	ok(b.phase == 1, "phase 1 at 65% health")
	# 2. the lair empties: it leashes back, asleep, whole, in the middle
	_spot(P, F["c"] + Vector3(60, 0, 0))
	_run(13.0)
	var home: float = Vector2(b.pos.x - F["c"].x, b.pos.z - F["c"].z).length()
	ok(b.dormant and b.phase == 0 and not b.enraged and is_equal_approx(b.hp, b.max_hp) and home < 0.1,
		"nobody inside for 12 s: asleep, phase 0, full health, home (%.1f m off)" % home)
	# 3. the last hit's squad takes the XP, the squad that only dealt damage gets none
	b = _wake(F, P)
	_spot(C, F["c"] + Vector3(-F["out"].y, 0, F["out"].x) * 10.0)
	_spot(Q, F["c"] + Vector3(F["out"].x, 0, F["out"].y) * 5.0)
	b.stagger_t = 0.0
	b.hurt(20.0, P, {"src": "shot"})      # P's squad is in the fight (the damage XP it earns is small) ...
	b.hp = 5.0
	var p0 := [P.xp, C.xp, Q.xp]
	var l0 := [P.lvl, C.lvl, Q.lvl]
	b.hurt(50.0, Q, {"src": "shot"})      # ... Q's squad lands the last hit
	_run(0.2)
	var got := func(h: Hunter, i: int) -> bool: return h.xp - p0[i] + 1000.0 * (h.lvl - l0[i]) >= Lairs.BOSS_XP
	ok(b.dead and F["cleared_by"] == Q.pname, "the last hitter (%s) is credited the kill" % F["cleared_by"])
	ok(got.call(Q, 2), "the last-hit squad's hunter got the kill XP")
	ok(not got.call(P, 0) and not got.call(C, 1), "the squad that fought but not the last hit got no kill XP")
	print("BOSSPARITY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
