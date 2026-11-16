extends RefCounted
## --ability-check, moved out of main.gd (AGENTS.md section 2); registered in tools/check_registry.gd.

var main: Node

## Headless check for the ability verbs: each one fired at a dummy rival, asserting what it should
## do (a hook drags them in, a wall stops a shot, a mirror sends it back, a slam throws them up...).
var _ac_fail := 0
func _ac(name: String, ok: bool, info := "") -> void:
	print("ACHECK %-26s %s  %s" % [name, "PASS" if ok else "FAIL", info])
	if not ok: _ac_fail += 1

func _ac_setup(dist: float, extra_t := false) -> Array:
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "weapon": "rifle", "cls": "medium"})
	m.set_process(false)
	var P: Hunter = m.player
	P.set_arch("")         # these are the old weapon RMBs and class dodges (the verbs stay; archetypes: --archetype-check)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	# a flat, open strip of ground for the test: the training map is small and busy, so the logical
	# tiles around the spawn are levelled (headless, nothing is drawn)
	var W = m.world
	var hx := int(floor(P.pos.x)); var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-3, 4):
		for dx in range(-6, int(dist) + 7):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i); W.walls.erase(i); W.props.erase(i); W.bush.erase(i)
	var home := Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.hp = P.max_hp
	var T: Hunter = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(dist, 0, 0))
	T.max_hp = 10000.0; T.hp = T.max_hp; T.armor = 0.0; T.max_armor = 0.0
	var T2: Hunter = null
	if extra_t:
		T2 = m.make_hunter("T2", 5, "medium", "Target2", "idle", {}, home + Vector3(dist + 2.0, 0, 0))
		T2.max_hp = 10000.0; T2.hp = T2.max_hp; T2.armor = 0.0; T2.max_armor = 0.0
	for i in 5: m.step(Match.DT)
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0); P.inp["aim_y"] = T.pos.y
	if OS.get_cmdline_user_args().has("--ac-debug"):
		print("  setup home=%s P=%s T=%s gP=%.2f gT=%.2f Tgr=%s Pgr=%s" % [home, P.pos, T.pos, m.world.ground_at(P.pos.x, P.pos.z), m.world.ground_at(T.pos.x, T.pos.z), T.grounded, P.grounded])
	return [m, P, T, T2]

func _ac_run(m: Match, secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(Match.DT); t += Match.DT

func _ac_glove(P: Hunter, gid: String, rar := 1) -> void:
	P.gear[0] = {"id": gid, "rar": rar}
	P.gear_cd[0] = 0.0
	P.m.use_gear(P, 0)

func run(main_node: Node) -> void:
	main = main_node
	var r: Array
	var m: Match; var P: Hunter; var T: Hunter
	# 1. Hook glove drags the target in
	r = _ac_setup(7.0); m = r[0]; P = r[1]; T = r[2]
	var d0 := P.flat_dist(T)
	_ac_glove(P, "grapple")
	_ac_run(m, 1.0)
	_ac("hook pulls target", P.flat_dist(T) < 3.0, "dist %.1f -> %.1f" % [d0, P.flat_dist(T)])
	m.queue_free(); await main.get_tree().process_frame
	# 2. Barrier wall stops an enemy shot
	r = _ac_setup(7.0); m = r[0]; P = r[1]; T = r[2]
	P.inp["aim"] = P.pos + Vector3(2.5, 0.9, 0)
	_ac_glove(P, "barrier")
	var whp: float = m.verbs.walls[0]["hp"] if not m.verbs.walls.is_empty() else -1.0
	var php := P.hp
	m.spawn_shot(T, T.pos + Vector3(-0.6, 0.95, 0), Vector2(-30, 0), 20.0, 0.5, 0.15, Color.RED, {})
	_ac_run(m, 0.5)
	var whp2: float = m.verbs.walls[0]["hp"] if not m.verbs.walls.is_empty() else -1.0
	_ac("wall blocks a shot", P.hp >= php and whp2 < whp and whp > 0.0, "wall hp %.0f -> %.0f, player hp %.0f -> %.0f" % [whp, whp2, php, P.hp])
	# a barrier stops bodies too: walk the target into it
	var tx0 := T.pos.x
	_ac_run(m, 1.2, func(): T.inp["move"] = Vector2(-1, 0))
	_ac("wall blocks movement", T.pos.x > P.pos.x + 2.4, "target x %.1f (wall at %.1f)" % [T.pos.x - P.pos.x, 2.5])
	m.queue_free(); await main.get_tree().process_frame
	# 3. Mirror glove reflects a shot back at the shooter
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	_ac_glove(P, "bubble")
	php = P.hp
	var thp := T.hp
	m.spawn_shot(T, T.pos + Vector3(-0.6, 0.95, 0), Vector2(-30, 0), 20.0, 0.6, 0.15, Color.RED, {})
	_ac_run(m, 0.6)
	_ac("reflect returns a shot", P.hp >= php and T.hp < thp, "shooter took %.0f, player took %.0f" % [thp - T.hp, php - P.hp])
	m.queue_free(); await main.get_tree().process_frame
	# 4. Riposte (frontal) parries a melee swing and stuns the swinger
	r = _ac_setup(1.4); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("riposte"))
	P.runner.use("utility", {})
	m.spawn_shot(T, T.pos + Vector3(-0.3, 0.95, 0), Vector2(-40, 0), 10.0, 0.08, 0.3, Color.RED, {"melee": true})
	_ac_run(m, 0.15)
	_ac("riposte parries melee", T.stun_t > 0.3, "attacker stun %.2f" % T.stun_t)
	m.queue_free(); await main.get_tree().process_frame
	# 5. Earthshatter: leap, knock up; an airborne target is spiked
	r = _ac_setup(5.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("earthshatter"))
	P.runner.use("utility", {})
	var acc := {"top": 0.0, "hits": 0, "last": 0.0}
	var g := T.pos.y
	_ac_run(m, 1.0, func(): acc["top"] = maxf(acc["top"], T.pos.y - g))
	_ac("slam knocks up", acc["top"] > 0.5 and T.hp < T.max_hp, "rose %.2fm, took %.0f" % [acc["top"], T.max_hp - T.hp])
	m.queue_free(); await main.get_tree().process_frame
	r = _ac_setup(5.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("earthshatter"))
	P.runner.use("utility", {})
	_ac_run(m, 0.42)
	T.vel.y = 7.0; T.grounded = false
	_ac_run(m, 0.3)
	_ac("slam spikes airborne", T.stun_t > 0.4, "stun %.2f, took %.0f" % [T.stun_t, T.max_hp - T.hp])
	m.queue_free(); await main.get_tree().process_frame
	# 6. Leash Bolt: tether snaps when stretched
	r = _ac_setup(5.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("leash_bolt"))
	P.runner.use("utility", {})
	_ac_run(m, 0.4)
	var tethered := not m.verbs.tethers.is_empty()
	thp = T.hp
	T.teleport(P.pos + Vector3(8.0, 0, 0))
	_ac_run(m, 0.2)
	_ac("tether snaps", tethered and T.hp < thp - 15.0 and T.stun_t > 0.5, "tethered=%s snap dmg %.0f stun %.2f" % [tethered, thp - T.hp, T.stun_t])
	m.queue_free(); await main.get_tree().process_frame
	# 7. Tripwire Mine roots whoever steps on it
	r = _ac_setup(4.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("tripwire_mine"))
	P.inp["aim"] = T.pos + Vector3(-2.0, 0, 0)      # clear of the target's hitbox (item 46 sizes)
	P.runner.use("utility", {})
	_ac_run(m, 1.0)
	var before_root := T.root_t
	_ac_run(m, 1.0, func(): T.inp["move"] = Vector2(-1, 0))
	_ac("trap roots on step", before_root <= 0.0 and (T.root_t > 0.0 or T.hp < T.max_hp) and m.verbs.traps.is_empty(), "root %.2f, took %.0f" % [T.root_t, T.max_hp - T.hp])
	m.queue_free(); await main.get_tree().process_frame
	# 8. Moon Mark (kin E, performed from the shoulder): the foe is marked, you stay where you are
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	var pa := P.pos
	KinExec.cast(KinLib.ability("moon_mark"), KinExec.make_cx(m, P, null, P, T.pos, 1.0, "k1", "moon_mark"))
	_ac_run(m, 0.5)
	_ac("moon mark reveals and marks, you stay", P.flat_dist(pa) < 0.05 and T.vuln_t > 0.0 and T.reveal_t > 0.0,
		"player moved %.2f, vuln %.1f" % [P.flat_dist(pa), T.vuln_t])
	m.queue_free(); await main.get_tree().process_frame
	# 9. Fissure glove: the line throws the target up
	r = _ac_setup(5.0); m = r[0]; P = r[1]; T = r[2]
	_ac_glove(P, "quake")
	acc["top"] = 0.0; g = T.pos.y
	_ac_run(m, 1.0, func(): acc["top"] = maxf(acc["top"], T.pos.y - g))
	_ac("fissure knocks up", acc["top"] > 0.4 and T.hp < T.max_hp, "rose %.2f" % acc["top"])
	m.queue_free(); await main.get_tree().process_frame
	# 10. Vortex glove: drags the target to the centre
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	var ctr := T.pos + Vector3(2.0, 0, 0)
	P.inp["aim"] = ctr
	_ac_glove(P, "shock")
	var dc0 := T.flat_dist(ctr)
	_ac_run(m, 1.0)
	_ac("vortex pulls in", T.flat_dist(ctr) < dc0 - 0.6, "to centre %.1f -> %.1f" % [dc0, T.flat_dist(ctr)])
	m.queue_free(); await main.get_tree().process_frame
	# 11. Razor Disc: out and back, hitting twice
	r = _ac_setup(4.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("razor_disc"))
	P.runner.use("utility", {})
	acc["hits"] = 0; acc["last"] = T.hp
	_ac_run(m, 1.6, func():
		if T.hp < float(acc["last"]) - 0.5: acc["hits"] = int(acc["hits"]) + 1
		acc["last"] = T.hp)
	_ac("boomerang hits twice", int(acc["hits"]) >= 2, "%d hits" % acc["hits"])
	m.queue_free(); await main.get_tree().process_frame
	# 12. Rail Charge: a full charge pierces two in a line
	r = _ac_setup(5.0, true); m = r[0]; P = r[1]; T = r[2]
	var T2: Hunter = r[3]
	P.runner.set_slot("utility", Content.ability("rail_charge"))
	P.runner.use("utility", {"charge": 1.0})
	_ac_run(m, 0.4)
	_ac("rail pierces", T.hp < T.max_hp - 20.0 and T2.hp < T2.max_hp - 20.0, "%.0f and %.0f" % [T.max_hp - T.hp, T2.max_hp - T2.hp])
	# and the player's held charge path: press, hold 1s, let go
	P.runner.reset()
	T.hp = T.max_hp
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.inp["sec"] = true; P.inp["sec_hold"] = true
	_ac_run(m, 1.0, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	_ac_run(m, 0.3)
	_ac("rail hold-to-charge", T.hp < T.max_hp - 25.0, "took %.0f" % (T.max_hp - T.hp))
	# the same hold as an archetype (Sparkle's Coilshot): the shared wind-up fills, ticks full, punches out
	P.reclass("light", "mage"); P.unlock_all()
	_ac_run(m, 0.3)      # (the swap to a Light body settles on the ground first)
	T.hp = T.max_hp
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.ak.cd["rmb"] = 0.0; P.ak.ch_rmb = 1.0
	P.inp["sec_hold"] = true; P.ak.press_rmb()
	var hk_mid := [-1.0]
	_ac_run(m, 1.3, func():
		P.inp["sec_hold"] = true
		if hk_mid[0] < 0.0 and P.ak.rmb_t > 0.6: hk_mid[0] = P.ak.charge_k())
	P.inp["sec_hold"] = false
	_ac_run(m, 0.3)
	_ac("archetype hold wind-up", hk_mid[0] > 0.2 and P.ak.charge_fulls >= 1 and P.ak.charge_last > 0.9 and T.hp < T.max_hp - 10.0, "mid %.2f fulls %d took %.0f" % [hk_mid[0], P.ak.charge_fulls, T.max_hp - T.hp])
	m.queue_free(); await main.get_tree().process_frame
	# 13. Breach: throws the target back and you the other way
	r = _ac_setup(2.5); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("breach"))
	var p0 := P.pos; var t0 := T.pos
	P.runner.use("utility", {})
	var pv := P.vel
	_ac_run(m, 0.5)
	print("   breach vel after cast ", pv)
	_ac("breach knocks both apart", T.pos.x - t0.x > 1.5 and p0.x - P.pos.x > 1.0, "target +%.1f, you -%.1f" % [T.pos.x - t0.x, p0.x - P.pos.x])
	m.queue_free(); await main.get_tree().process_frame
	# 14. Bulwark: a shield that follows you and stops shots
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("bulwark"))
	P.runner.use("utility", {})
	php = P.hp
	m.spawn_shot(T, T.pos + Vector3(-0.6, 0.95, 0), Vector2(-30, 0), 20.0, 0.5, 0.15, Color.RED, {})
	_ac_run(m, 0.4)
	_ac("bulwark blocks", P.hp >= php and not m.verbs.walls.is_empty(), "")
	m.queue_free(); await main.get_tree().process_frame
	# 15. Shadow Step: knife, then you're behind them
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("shadow_step"))
	P.runner.use("utility", {})
	_ac_run(m, 0.4)
	_ac("shadow step lands behind", P.pos.x > T.pos.x and P.flat_dist(T) < 1.8 and P.crit_t > 0.0, "x %.1f vs %.1f, target took %.0f" % [P.pos.x, T.pos.x, T.max_hp - T.hp])
	m.queue_free(); await main.get_tree().process_frame
	# 16. Ice Bridge: over the abyss
	r = _ac_setup(4.0); m = r[0]; P = r[1]; T = r[2]
	var edge := Vector3.INF; var ed := Vector2.ZERO
	for i in 4000:
		var q: Vector3 = m.world.random_ground()
		for dd in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var q2 := q + Vector3(dd.x, 0, dd.y) * 1.2
			if m.world.is_void(q2.x, q2.z) and not m.world.is_block(q.x, q.z):
				edge = q; ed = dd; break
		if edge != Vector3.INF: break
	P.teleport(edge); P.inp["aim"] = edge + Vector3(ed.x, 0, ed.y) * 8.0
	_ac_glove(P, "frost")
	var ground_ok: bool = not m.world.is_void(edge.x + ed.x * 3.0, edge.z + ed.y * 3.0)
	_ac("ice bridge makes ground", not m.verbs.terrain.is_empty() and ground_ok, "%d tiles" % (m.verbs.terrain[0]["tiles"].size() if not m.verbs.terrain.is_empty() else 0))
	_ac_run(m, 7.5)
	_ac("ice bridge melts", m.verbs.terrain.is_empty() and m.world.is_void(edge.x + ed.x * 3.0, edge.z + ed.y * 3.0), "")
	m.queue_free(); await main.get_tree().process_frame
	# 17. Prism Wall (kin E) reflects shots back
	r = _ac_setup(7.0); m = r[0]; P = r[1]; T = r[2]
	P.inp["aim"] = P.pos + Vector3(2.5, 0, 0)
	KinExec.cast(KinLib.ability("prism_wall"), KinExec.make_cx(m, P, null, P, P.pos + Vector3(2.5, 0, 0), 1.0, "k1", "prism_wall"))
	thp = T.hp; php = P.hp
	m.spawn_shot(T, T.pos + Vector3(-0.6, 0.95, 0), Vector2(-30, 0), 20.0, 0.6, 0.15, Color.RED, {})
	_ac_run(m, 0.6)
	_ac("prism wall reflects", T.hp < thp and P.hp >= php, "shooter took %.0f" % (thp - T.hp))
	m.queue_free(); await main.get_tree().process_frame
	# 18. Stinger Hook (kin E): yanks to the caster and blights
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	KinExec.cast(KinLib.ability("stinger_hook"), KinExec.make_cx(m, P, null, P, T.pos, 1.0, "k1", "stinger_hook"))
	_ac_run(m, 0.8)
	_ac("stinger hook yanks + blights", P.flat_dist(T) < 3.0 and T.blight_t > 0.0, "dist %.1f blight %.1f" % [P.flat_dist(T), T.blight_t])
	m.queue_free(); await main.get_tree().process_frame
	# 19. Gravity Slam (kin E) pulls in and lifts
	r = _ac_setup(5.0); m = r[0]; P = r[1]; T = r[2]
	var gk: Kin = P.kin
	if gk:
		gk.teleport(P.pos + Vector3(1, 0, 0)); gk.state = "active"
		var land := T.pos + Vector3(1.5, 0, 0)
		KinExec.cast(KinLib.ability("slam"), KinExec.make_cx(m, gk, gk, P, land, 1.0, "k1", "slam"))
		acc["top"] = 0.0; g = T.pos.y
		var dl := T.flat_dist(land)
		var mind := {"d": dl, "v": 0.0}
		var to_c := Vector2(land.x - T.pos.x, land.z - T.pos.z).normalized()
		_ac_run(m, 1.0, func():
			acc["top"] = maxf(acc["top"], T.pos.y - g)
			mind["v"] = maxf(float(mind["v"]), Vector2(T.vel.x, T.vel.z).dot(to_c))
			mind["d"] = minf(mind["d"], T.flat_dist(land)))
		# (the kin itself lands in the crater, so the pull ends against its body)
		_ac("gravity slam pulls + lifts", acc["top"] > 0.4 and float(mind["v"]) > 3.0, "rose %.2f, pulled at %.1fm/s toward the crater (kin %s)" % [acc["top"], mind["v"], gk.state])
	m.queue_free(); await main.get_tree().process_frame
	# 20. Dashes: class verbs (no kin changes a dash: --boki-dash-check). Each starts grounded at the same spot, 3m short of the target.
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	var home2 := P.pos
	var ready := func(cls: String, at: Vector3, mv: Vector2) -> void:
		P.teleport(at); P.vel = Vector3.ZERO
		T.teleport(home2 + Vector3(6.0, 0, 0)); T.vel = Vector3.ZERO
		T.burn_t = 0.0; T.blight_t = 0.0; T.slow_t = 0.0; T.stun_t = 0.0; T.root_t = 0.0; T.knock_t = 0.0
		P.cls = cls; P.dodge_def = Content.class_dodge(cls)
		P.kin = null
		_ac_run(m, 0.3)
		P.dashes = P.max_dashes(); P.ex_cd = 0.0; P.roll_t = 0.0
		P.inp["move"] = mv
	# Light: phase step, a shot fired through you mid-step does nothing
	ready.call("light", home2, Vector2(1, 0))
	var php2 := P.hp
	P.do_dash()
	m.spawn_shot(T, P.pos + Vector3(1.0, 0.95, 0), Vector2(-30, 0), 20.0, 0.3, 0.15, Color.RED, {})
	_ac_run(m, 0.25)
	_ac("light phase: shots pass", P.phase_t >= 0.0 and P.hp >= php2, "hp %.0f -> %.0f" % [php2, P.hp])
	# Medium: the roll reloads
	ready.call("medium", home2, Vector2(1, 0))
	P.ammo = 0
	P.do_dash()
	_ac("medium roll reloads", P.ammo > 0, "ammo %d" % P.ammo)
	# Heavy: the charge bowls the target back
	ready.call("heavy", T.pos + Vector3(-2.2, 0, 0), Vector2(1, 0))
	var tx := T.pos.x
	P.do_dash()
	_ac_run(m, 0.5)
	_ac("heavy charge knocks back", T.pos.x - tx > 1.0 and T.hp < T.max_hp, "target pushed %.1f, took %.0f" % [T.pos.x - tx, T.max_hp - T.hp])
	m.queue_free(); await main.get_tree().process_frame
	# 21. Every ability and active glove runs without errors (watch the log for SCRIPT ERROR)
	r = _ac_setup(5.0); m = r[0]; P = r[1]; T = r[2]
	var n := 0
	for id in Content.ids("hunter_abilities"):
		var ad := Content.ability(id)
		P.teleport(T.pos + Vector3(-5, 0, 0)); P.vel = Vector3.ZERO
		P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
		Effects.run(ad.effects, P, {"slot": "utility", "ability": id, "charge": 0.7})
		_ac_run(m, 0.8)
		n += 1
	for gid in Gear.ALL:
		if Gear.active(gid):
			P.teleport(T.pos + Vector3(-5, 0, 0)); P.vel = Vector3.ZERO
			P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
			for rar in [1, 4]:
				_ac_glove(P, gid, rar)
				_ac_run(m, 0.6)
			n += 1
	for kid in KinLib.lib()["abilities"]:
		P.teleport(T.pos + Vector3(-5, 0, 0)); P.vel = Vector3.ZERO
		KinExec.cast(KinLib.ability(kid), KinExec.make_cx(m, P, null, P, T.pos, 1.0, "k1", kid))
		_ac_run(m, 0.8)
		n += 1
	_ac("all abilities run", true, "%d ran" % n)
	m.queue_free(); await main.get_tree().process_frame
	# 22. Ranks: a rank-3 slot makes the same verb stronger and recharge faster; a glove never ranks (Gloves)
	r = _ac_setup(7.0); m = r[0]; P = r[1]; T = r[2]
	P.inp["aim"] = P.pos + Vector3(2.5, 0.9, 0)
	_ac_glove(P, "barrier")
	var hp1: float = m.verbs.walls[-1]["hp"] if not m.verbs.walls.is_empty() else 0.0
	var cd1: float = P.gear_cd[0]
	P.skill_pts = 5      # spent on the hero's own abilities (the level stays, so level growth stays out of it)
	P._bot_spend()
	_ac_glove(P, "barrier")
	var hp3: float = m.verbs.walls[-1]["hp"] if not m.verbs.walls.is_empty() else 0.0
	_ac("a glove is as strong after spending skill points (no ranks)", absf(hp3 - hp1) < 0.01
			and absf(float(P.gear_cd[0]) - cd1) < 0.01 and not P.slot_lv.has("gear"),
			"wall hp %.0f -> %.0f, cooldown %.1f -> %.1f" % [hp1, hp3, cd1, float(P.gear_cd[0])])
	P.runner.set_slot("utility", Content.ability("leash_bolt"))
	P.slot_lv["sec"] = 3
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.runner.use("utility", {"level": P.ability_level("sec")})
	_ac("rank 3 RMB cooldown", P.runner.cd_left("utility") < Content.ability("leash_bolt").cooldown * 0.85, "%.1fs" % P.runner.cd_left("utility"))
	m.queue_free(); await main.get_tree().process_frame
	print("ACHECK DONE, failures: ", _ac_fail)
	main.get_tree().quit()
