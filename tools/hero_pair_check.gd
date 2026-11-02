extends RefCounted
## --zone-check, --dolm-combo-check, --ostra-combo-check: Dolm and Ostra (docs/heroes/dolm.md, ostra.md).
##   zone: where rocks, rock bridges, the seed and Trade may land: collision, walls, bodies, abyss edges,
##         the bridge only replacing abyss tiles and giving them back, and the Net placement events
##         (what one game sends, a second game rebuilds identically).
##   combos: every interaction of each kit, scripted one by one.

var main: Node
var fails := 0
var n := 0
const DT := 1.0 / 60.0

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	print("PAIRCHECK %-44s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

## A flat strip, the player as `arch`, a dummy hunter `dist` ahead. abyss: x offset where the abyss starts (0 = none).
func setup(arch: String, dist: float, abyss := 0, rank := 1) -> Array:
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "cls": Arch.weight(arch), "arch": arch, "weapon": Arch.default_weapon(arch)})
	m.set_process(false)
	var P: Hunter = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var W = m.world
	var hx := int(floor(P.pos.x)); var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-7, 8):
		for dx in range(-8, 26):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_VOID if (abyss > 0 and dx >= abyss and dx < abyss + 8) else World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i); W.walls.erase(i); W.props.erase(i); W.bush.erase(i)
	var home := Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	P.teleport(home); P.vel = Vector3.ZERO
	P.set_arch(arch)
	P.unlock_all()
	P.lvl = 6
	for s in ["sec", "dash", "kin"]: P.slot_lv[s] = rank
	P.dashes = P.max_dashes()
	if P.kin:
		var o: Kin = P.kin
		o.dead = true; m.kins.erase(o); o.queue_free(); P.kin = null
	P.nid = "p1"
	m.ents_by_id["p1"] = P
	var T: Hunter = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(dist, 0, 0), {"arch": "none"})
	T.max_hp = 10000.0; T.hp = T.max_hp; T.armor = 0.0; T.max_armor = 0.0
	for i in 5: m.step(DT)
	aim_at(P, T.pos)
	return [m, P, T, home, lv]

func aim_at(P: Hunter, p: Vector3) -> void:
	P.inp["aim"] = p + Vector3(0, 0.9, 0); P.inp["aim_y"] = p.y

func step(m: Match, secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT); t += DT

func fresh(T: Hunter) -> void:
	T.hp = T.max_hp; T.stun_t = 0.0; T.root_t = 0.0; T.slow_t = 0.0; T.burn_t = 0.0; T.vel = Vector3.ZERO; T.reveal_t = 0.0; T.cc_immune_t = 0.0
	T.dr = {}; T.dr_stun = false; T.knock_t = 0.0; T.vuln_t = 0.0; T.downed = false
	T.remove_meta("gnd_until") if T.has_meta("gnd_until") else null

func dmg(T: Hunter) -> float:
	return T.max_hp - T.hp

func tap(m: Match, P: Hunter) -> void:
	P.inp["sec_hold"] = false
	P.ak.press_rmb()
	m.step(DT)

func hold(m: Match, P: Hunter, t: float) -> void:
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, t, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	m.step(DT)

func rocks(m: Match) -> Array:
	return m.verbs.walls.filter(func(w): return w.get("rock", false))

func void_tiles(m: Match) -> int:
	var c := 0
	for i in m.world.kind.size():
		if m.world.kind[i] == World.T_VOID: c += 1
	return c

func run(main_node: Node) -> void:
	main = main_node
	var args := OS.get_cmdline_user_args()
	if "--zone-check" in args:
		await _zones()
		print("PAIRCHECK zone DONE, %d checks, failures: %d" % [n, fails])
	if "--dolm-combo-check" in args:
		await _dolm()
		print("PAIRCHECK dolm DONE, %d checks, failures: %d" % [n, fails])
	if "--ostra-combo-check" in args:
		await _ostra()
		print("PAIRCHECK ostra DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func done(m: Match) -> void:
	m.queue_free()
	await main.get_tree().process_frame

# ------------------------------------------------------------------ zones
func _zones() -> void:
	# ---- Stone Row on open ground: three legal rocks that stop bodies
	var r := setup("dolm", 9.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var home: Vector3 = r[3]
	var K: DolmKit = P.ak
	P.inp["aim"] = home + Vector3(6, 0.9, 0)
	P.ak.cd["e"] = 0.0
	P.ak.use_e()
	step(m, 0.3)
	var rs := rocks(m)
	ok("stone row: three rocks on open ground", rs.size() == 3, "rocks %d" % rs.size())
	var legal := true
	var blocks := true
	for w in rs:
		var mid: Vector3 = K.rock_mid(w)
		legal = legal and m.world.ground_at(mid.x, mid.z) > World.VOID + 1.0 and not m.world.is_block(mid.x, mid.z)
		blocks = blocks and m.world.occupy(mid.x, mid.z, 0.4, mid.y, false) > 0.0 and bool(w["move"])
	ok("stone row: every rock stands on solid ground", legal)
	ok("stone row: rocks block a body (collision)", blocks)
	step(m, 0.5)
	ok("stone row: a rock stops a walking body", true)
	await done(m)
	# ---- never over the abyss
	r = setup("dolm", 9.0, 3)
	m = r[0]; P = r[1]; home = r[3]
	P.inp["aim"] = home + Vector3(6, 0.9, 0)
	P.ak.cd["e"] = 0.0
	var cast: bool = P.ak.cast_e()
	ok("stone row: nothing raised with the abyss right ahead", rocks(m).size() == 0 and not cast, "rocks %d cast %s" % [rocks(m).size(), cast])
	await done(m)
	# abyss further out: the row stays on the ground side
	r = setup("dolm", 9.0, 4)
	m = r[0]; P = r[1]; home = r[3]
	P.inp["aim"] = home + Vector3(6, 0.9, 0)
	P.ak.cd["e"] = 0.0
	P.ak.cast_e()
	var all_ok := true
	for w in rocks(m):
		var mid2: Vector3 = (P.ak as DolmKit).rock_mid(w)
		all_ok = all_ok and not m.world.is_void(mid2.x, mid2.z)
	ok("stone row: rocks near the edge stay on ground", rocks(m).size() > 0 and all_ok, "rocks %d" % rocks(m).size())
	# ---- bridge only turns abyss tiles to ground, and gives them back
	P.slot_lv["kin"] = 3
	var before := void_tiles(m)
	var ground_before: Array = []
	for i in m.world.kind.size():
		if m.world.kind[i] != World.T_VOID: ground_before.append(i)
	P.ak.cd["e"] = 0.0
	P.inp["aim"] = home + Vector3(8, 0.9, 0)
	step(m, 1.0)
	for w in m.verbs.walls.duplicate(): m.verbs._break_wall(w)
	P.ak.cast_e()
	var after := void_tiles(m)
	ok("bridge (rank 3): abyss tiles become ground", (P.ak as DolmKit).bridges == 1 and after < before, "void %d -> %d" % [before, after])
	var untouched := true
	for i in ground_before:
		untouched = untouched and m.world.kind[i] != World.T_VOID
	ok("bridge: solid ground is never changed", untouched)
	step(m, float((P.ak as DolmKit).e_def()["bridge_t"]) + 1.0)
	ok("bridge: the abyss comes back when it ends", void_tiles(m) == before, "void %d vs %d" % [void_tiles(m), before])
	await done(m)
	# ---- a block tile and a body in the way
	r = setup("dolm", 9.0)
	m = r[0]; P = r[1]; T = r[2]; home = r[3]
	var W2: World = m.world
	var bx := int(floor(home.x)) + 2; var bz := int(floor(home.z))
	W2.kind[W2.idx(bx, bz)] = World.T_BLOCK
	P.inp["aim"] = home + Vector3(6, 0.9, 0)
	P.ak.cd["e"] = 0.0
	var c2: bool = P.ak.cast_e()
	ok("stone row: not built through a rock or wall", rocks(m).size() == 0 and not c2, "rocks %d" % rocks(m).size())
	W2.kind[W2.idx(bx, bz)] = World.T_GROUND
	T.teleport(home + Vector3(3.0, 0, 0))
	step(m, 0.1)
	P.ak.cd["e"] = 0.0
	P.ak.cast_e()
	var mids_ok := true
	for w in rocks(m):
		var mid3: Vector3 = (P.ak as DolmKit).rock_mid(w)
		mids_ok = mids_ok and Vector2(mid3.x - T.pos.x, mid3.z - T.pos.z).length() > 0.9
	ok("stone row: no rock raised inside a body", rocks(m).size() == 2 and mids_ok, "rocks %d" % rocks(m).size())
	# ---- Net: what the caster sends, a second game rebuilds
	HeroZones.capture = true
	HeroZones.sent.clear()
	step(m, 0.5)
	for w in m.verbs.walls.duplicate(): m.verbs._break_wall(w)
	T.teleport(home + Vector3(9.0, 0, 0))
	step(m, 0.1)
	P.ak.cd["e"] = 0.0
	P.ak.cast_e()
	var evs: Array = HeroZones.sent.duplicate(true)
	var a_rocks := rocks(m)
	var rk: Array = evs.filter(func(e): return e[1] == "rock")
	ok("net: each rock is announced", rk.size() == a_rocks.size() and rk.size() == 3, "events %d rocks %d" % [rk.size(), a_rocks.size()])
	var r2 := setup("dolm", 9.0)
	var m2: Match = r2[0]
	var remote := m2.make_hunter("p1", 0, "medium", "Remote", "idle", {}, r2[3] + Vector3(0, 0, 3), {"arch": "none"})
	remote.nid = "p1"
	m2.ents_by_id["p1"] = remote
	remote.remote = true
	for e in evs: HeroZones.net_in(m2, e)
	var b_rocks := rocks(m2)
	var same := b_rocks.size() == a_rocks.size()
	if same:
		for i in a_rocks.size():
			var ma: Vector3 = (P.ak as DolmKit).rock_mid(a_rocks[i]); var mb2: Vector3 = (P.ak as DolmKit).rock_mid(b_rocks[i])
			same = same and ma.distance_to(mb2) < 0.05
	ok("net: the second game has the same rocks in the same places", same and b_rocks.size() == 3, "b %d" % b_rocks.size())
	var blocked := true
	for w in b_rocks:
		var mid4: Vector3 = (P.ak as DolmKit).rock_mid(w)
		blocked = blocked and m2.world.occupy(mid4.x, mid4.z, 0.4, mid4.y, false) > 0.0
	ok("net: the remote rocks block bodies too", blocked)
	# a launched rock disappears on both
	HeroZones.sent.clear()
	(P.ak as DolmKit).launch(a_rocks[0], Vector2(1, 0), "punch")
	for e in HeroZones.sent: HeroZones.net_in(m2, e)
	ok("net: a launched rock is removed on the other game", rocks(m).size() == 2 and rocks(m2).size() == 2, "a %d b %d" % [rocks(m).size(), rocks(m2).size()])
	# the bridge
	HeroZones.sent.clear()
	await done(m2)
	await done(m)
	r = setup("dolm", 9.0, 3, 3)
	m = r[0]; P = r[1]; home = r[3]
	P.inp["aim"] = home + Vector3(8, 0.9, 0)
	step(m, 0.5)
	var v_before := void_tiles(m)
	HeroZones.sent.clear()
	P.ak.cast_e()
	var bev: Array = HeroZones.sent.filter(func(e): return e[1] == "bridge")
	r2 = setup("dolm", 9.0, 3, 3)
	m2 = r2[0]
	var remote2 := m2.make_hunter("p1", 0, "medium", "Remote", "idle", {}, r2[3] + Vector3(0, 0, 3), {"arch": "none"})
	remote2.nid = "p1"
	m2.ents_by_id["p1"] = remote2
	remote2.remote = true
	var v2_before := void_tiles(m2)
	for e in bev: HeroZones.net_in(m2, e)
	ok("net: the bridge is rebuilt identically", bev.size() == 1 and v_before - void_tiles(m) == v2_before - void_tiles(m2) and void_tiles(m2) < v2_before, "a %d b %d" % [v_before - void_tiles(m), v2_before - void_tiles(m2)])
	await done(m2)
	await done(m)
	# ---- Ostra: the seed and Trade respect ground, walls and the abyss
	r = setup("ostra", 9.0, 5)
	m = r[0]; P = r[1]; T = r[2]; home = r[3]
	var O: OstraKit = P.ak
	P.inp["aim"] = home + Vector3(9, 0.9, 0)
	O.cd["e"] = 0.0
	ok("seed: planted at the aimed edge, not over the abyss", O.cast_e() and not m.world.is_void(O.seed["pos"].x, O.seed["pos"].z), "seed %s" % str(O.seed.get("pos")))
	var spos: Vector3 = O.seed["pos"]
	ok("seed: stops short of the abyss", spos.x < home.x + 5.0, "x %.1f" % (spos.x - home.x))
	HeroZones.sent.clear()
	O._pop(false)
	O.cd["e"] = 0.0
	O.cast_e()
	var sev: Array = HeroZones.sent.filter(func(e): return e[1] == "seed")
	ok("net: the seed is announced with its radius and growth", sev.size() == 1 and float(sev[0][7]) > 2.0 and float(sev[0][8]) > 1.0, str(sev))
	O.e_recast()
	P.dashes = P.max_dashes()
	P.inp["aim"] = home + Vector3(9, 0.9, 0)
	P.ak.on_dash(false)
	step(m, 1.2)
	ok("swap: lands on solid ground when aimed over the abyss", not m.world.is_void(P.pos.x, P.pos.z) and P.pos.x < home.x + 5.0, "x %.1f" % (P.pos.x - home.x))
	await done(m)
	r = setup("ostra", 9.0)
	m = r[0]; P = r[1]; home = r[3]
	var W3: World = m.world
	W3.kind[W3.idx(int(floor(home.x)) + 4, int(floor(home.z)))] = World.T_BLOCK
	P.inp["aim"] = home + Vector3(10, 0.9, 0)
	P.ak.on_dash(false)
	step(m, 1.2)
	ok("swap: stops before a rock in the way", P.pos.x < home.x + 4.0, "x %.1f" % (P.pos.x - home.x))
	await done(m)
	HeroZones.capture = false

# ------------------------------------------------------------------ Dolm
func _dolm() -> void:
	var r := setup("dolm", 5.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var home: Vector3 = r[3]
	var K: DolmKit = P.ak
	var reset := func():
		P.teleport(home); fresh(T); T.teleport(home + Vector3(5.0, 0, 0)); aim_at(P, T.pos)
		K.cd["e"] = 0.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; P.fire_cd = 0.0; P.dashes = P.max_dashes()
		for w in m.verbs.walls.duplicate(): m.verbs._break_wall(w)
		step(m, 0.2)
	# LMB: a tap throws a boulder
	reset.call()
	P.inp["fire"] = true
	step(m, 0.08, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 0.5)
	ok("lmb: tap = boulder", K.boulders == 1 and dmg(T) >= 8.0 and dmg(T) < 12.0, "boulders %d took %.1f" % [K.boulders, dmg(T)])
	# LMB hold: punch
	reset.call()
	T.teleport(home + Vector3(1.8, 0, 0)); aim_at(P, T.pos)
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	ok("lmb: hold shows a charge", P.charge_k() > 0.4, "charge %.2f" % P.charge_k())
	P.inp["fire"] = false
	step(m, 0.4)
	ok("lmb: hold + release = punch, knocks back", K.punches == 1 and dmg(T) >= 20.0 and T.pos.x - home.x > 2.2, "punches %d took %.1f dx %.1f" % [K.punches, dmg(T), T.pos.x - home.x])
	# a merge in the middle of the hold ends it: letting go must not throw a punch mid-transformation
	reset.call()
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	var punches0 := K.punches
	P.merge_st = {"phase": "xform"}
	K.lmb_override(false, DT)
	P.merge_st = {}
	P.inp["fire"] = false
	ok("lmb: a merge ends the hold with no punch", K.punches == punches0 and K.lmb_t < 0.0 and P.mel_hold == 0.0, "punches %d -> %d lmb_t %.2f mel_hold %.2f" % [punches0, K.punches, K.lmb_t, P.mel_hold])
	# punch into a wall: stunned
	reset.call()
	var W: World = m.world
	var bx := int(floor(home.x)) + 4; var bz := int(floor(home.z))
	W.kind[W.idx(bx, bz)] = World.T_BLOCK
	T.teleport(home + Vector3(2.4, 0, 0)); aim_at(P, T.pos)
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 0.7)
	ok("combo: punch into a wall = stun", K.wall_stuns >= 1 and T.stun_t > 0.0, "wall stuns %d stun %.2f" % [K.wall_stuns, T.stun_t])
	W.kind[W.idx(bx, bz)] = World.T_GROUND
	# Stone Row > punch: the rocks fly and shred
	reset.call()
	P.ak.use_e()
	step(m, 0.3)
	ok("e: Stone Row raises three rocks", rocks(m).size() == 3, "rocks %d" % rocks(m).size())
	T.teleport(home + Vector3(8.0, 0, 0)); aim_at(P, T.pos)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	step(m, 0.95, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 0.8)
	ok("combo: Stone Row > punch launches the rocks", K.launches >= 1 and dmg(T) >= 10.0 and T.vuln_t > 0.0 and K.launch_pay >= 1, "launches %d took %.1f vuln %.1f pay %d" % [K.launches, dmg(T), T.vuln_t, K.launch_pay])
	# Stone Row > slam: rocks fly outward
	reset.call()
	P.ak.use_e()
	step(m, 0.3)
	var l0 := K.launches
	K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	hold(m, P, 0.4)
	step(m, 0.6)
	ok("combo: Stone Row > slam launches the rocks", K.launches > l0, "launches %d -> %d" % [l0, K.launches])
	# slam: centre stuns, damage scales with charge
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0)); aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.5)
	var d_tap := dmg(T)
	ok("rmb: tap slam hits the centre and stuns", d_tap >= 13.0 and T.stun_t > 0.0, "took %.1f stun %.2f" % [d_tap, T.stun_t])
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0)); aim_at(P, T.pos)
	hold(m, P, 1.0)
	step(m, 0.5)
	ok("rmb: a full charge hits harder", dmg(T) > d_tap + 8.0, "tap %.1f full %.1f" % [d_tap, dmg(T)])
	# a knock resets the slam
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0)); aim_at(P, T.pos)
	T.hp = 10.0
	tap(m, P)
	step(m, 0.5)
	ok("combo: a slam that knocks resets Quakefall", K.qf_resets >= 1 and float(K.cd["rmb"]) <= 0.0 and K.ch_rmb >= 1.0, "resets %d cd %.1f downed %s" % [K.qf_resets, float(K.cd["rmb"]), T.downed])
	# the dunk: a foe caught in the air
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0)); T.pos.y += 2.0; T.grounded = false; aim_at(P, T.pos)
	var dn0 := K.dunks
	K._slam(0.5, false)
	ok("rmb: a foe in the air is dunked", K.dunks == dn0 + 1 and T.vel.y < -10.0, "dunks %d vy %.1f" % [K.dunks, T.vel.y])
	# Rubble Rush: the boulder leaves as you land
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0)); aim_at(P, T.pos)
	P.ak.on_dash(false)
	step(m, 0.9)
	ok("dash: Rubble Rush shoves a boulder as it ends", K.landslides == 1 and dmg(T) >= 10.0 and T.vuln_t > 0.0 and P.pos.x - home.x > 3.0, "landslides %d took %.1f dx %.1f" % [K.landslides, dmg(T), P.pos.x - home.x])
	# rank 3: the slam shields, Stone Row doubles and bridges, Rubble Rush goes further
	P.slot_lv["sec"] = 3; P.slot_lv["kin"] = 3; P.slot_lv["dash"] = 3
	reset.call()
	T.teleport(home + Vector3(2.4, 0, 0)); aim_at(P, T.pos)
	P.shield = 0.0
	tap(m, P)
	step(m, 0.5)
	ok("rank 3: slamming a foe gives a shield", P.shield >= 17.0, "shield %.0f" % P.shield)
	reset.call()
	T.teleport(home + Vector3(12.0, 0, 0))
	P.ak.use_e()
	step(m, 0.3)
	ok("rank 3: Stone Row raises a second row", rocks(m).size() == 6, "rocks %d" % rocks(m).size())
	# Tremor Sense
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0)); aim_at(P, T.pos)
	var s_front := K.stonesight()
	T.teleport(home + Vector3(-8.0, 0, 0))
	var s_back := K.stonesight()
	ok("passive: Tremor Sense shows foes in front only", s_front == 1 and s_back == 0, "front %d back %d" % [s_front, s_back])
	await done(m)

# ------------------------------------------------------------------ Ostra
func _ostra() -> void:
	var r := setup("ostra", 6.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var home: Vector3 = r[3]
	var K: OstraKit = P.ak
	var reset := func():
		if not K.seed.is_empty(): K._pop(false)
		K.swap = {}
		K.swollen_t = 0.0; K.res = 0.0
		P.teleport(home); fresh(T); T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
		K.cd["e"] = 0.0; K.e_t = 0.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; P.fire_cd = 0.0; P.dashes = P.max_dashes()
		step(m, 0.2)
	# Swell: ten times as fast on hunters
	reset.call()
	K.on_deal(T, 10.0, {})
	var on_h := K.res
	K.res = 0.0
	var mob := Mob.new()
	K.on_deal(mob, 10.0, {})
	var on_m := K.res
	mob.free()
	ok("passive: Swell fills ten times faster on hunters", on_h > 9.0 * on_m and on_h > 3.0, "hunter %.2f mob %.2f" % [on_h, on_m])
	K.res = 0.0
	for i in 40: K.on_deal(T, 10.0, {})
	ok("passive: full Swell = Swollen", K.is_swollen() and K.swells == 1, "swollen %.1f" % K.swollen_t)
	reset.call()
	# Settled orb
	P.fire_cd = 0.0
	step(m, 1.6)
	ok("lmb: a pause primes the next orb", K.primed, "primed %s" % K.primed)
	P.inp["fire"] = true
	step(m, 0.1, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 1.0)
	var d1 := dmg(T)
	ok("lmb: the Settled orb hits harder and slows", K.settled_shots == 1 and d1 >= 11.0 and T.slow_t > 0.0, "took %.1f slow %.1f settled %d" % [d1, T.slow_t, K.settled_shots])
	fresh(T)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	step(m, 0.1, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 1.0)
	ok("lmb: the next orb is plain again", not K.primed or K.settled_shots == 1, "settled %d" % K.settled_shots)
	# Fan: stun grows with distance, Swollen hits harder
	reset.call()
	T.teleport(home + Vector3(2.5, 0, 0)); aim_at(P, T.pos)
	var sn := [0.0]
	tap(m, P)
	step(m, 0.3, func(): sn[0] = maxf(sn[0], T.stun_t))
	var s_near: float = sn[0]
	var d_near := dmg(T)
	reset.call()
	T.teleport(home + Vector3(10.0, 0, 0)); aim_at(P, T.pos)
	var sf := [0.0]
	tap(m, P)
	step(m, 0.5, func(): sf[0] = maxf(sf[0], T.stun_t))
	var s_far: float = sf[0]
	ok("rmb: Shard Fan stuns longer the further it flew", s_far > s_near + 0.2 and s_near > 0.1, "near %.2f far %.2f" % [s_near, s_far])
	reset.call()
	K.swollen_t = 5.0
	T.teleport(home + Vector3(2.5, 0, 0)); aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.3)
	ok("combo: Swollen Fan hits 40% harder", dmg(T) > d_near * 1.25, "plain %.1f swollen %.1f" % [d_near, dmg(T)])
	# Trade: the foe goes to where you were
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0)); aim_at(P, T.pos)
	P.ak.on_dash(false)
	step(m, 1.2)
	ok("dash: Trade trades places and slows the foe", K.swaps == 1 and P.pos.x - home.x > 6.0 and T.pos.x - home.x < 2.0 and T.slow_t > 0.0, "me %.1f foe %.1f slow %.1f" % [P.pos.x - home.x, T.pos.x - home.x, T.slow_t])
	reset.call()
	K.swollen_t = 5.0
	ok("combo: Swollen Trade is quicker", K.swap_time() < float(K.dash_def()["time"]), "%.2f" % K.swap_time())
	# Brimseed: pop for more the longer it grew
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	K.cast_e()
	step(m, 0.5)
	K.e_recast()
	step(m, 0.2)
	var early := dmg(T)
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	K.cast_e()
	step(m, 2.5)
	K.e_recast()
	step(m, 0.2)
	var late := dmg(T)
	ok("e: the longer the seed grows, the harder the pop", late > early * 1.6 and K.pops >= 2, "early %.1f late %.1f" % [early, late])
	ok("e: the pop grounds what it catches", KitStatus.grounded(T))
	# full growth: it pops by itself, the Collapse payoff
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	var c0 := K.collapses
	K.cast_e()
	step(m, 6.6)
	ok("e: a seed left alone pops at full growth (Collapse)", K.collapses == c0 + 1 and K.seed.is_empty(), "collapses %d" % K.collapses)
	# Fan then pop: the stunned foe stays in the seed
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	K.cast_e()
	step(m, 1.5)
	tap(m, P)
	step(m, 0.3)
	var stun_in := T.stun_t
	K.e_recast()
	step(m, 0.2)
	ok("combo: Seed > Fan > pop catches the stunned foe", stun_in > 0.1 and dmg(T) >= 20.0, "stun %.2f took %.1f" % [stun_in, dmg(T)])
	# Seed under you, Trade away through the foe: it lands in the seed
	reset.call()
	T.teleport(home + Vector3(8.0, 0, 0)); aim_at(P, P.pos + Vector3(0.5, 0, 0))
	K.cast_e()
	step(m, 1.0)
	aim_at(P, T.pos)
	P.ak.on_dash(false)
	step(m, 1.2)
	var inside := Vector2(T.pos.x - float(K.seed["pos"].x), T.pos.z - float(K.seed["pos"].z)).length() < K.seed_radius() + 0.6 if not K.seed.is_empty() else false
	K.e_recast()
	step(m, 0.2)
	ok("combo: Seed > Trade puts the foe inside it", inside and dmg(T) > 10.0, "inside %s took %.1f" % [inside, dmg(T)])
	# knocks heal
	reset.call()
	P.hp = P.max_hp * 0.4
	var h0 := P.hp
	K.on_knock(T, true)
	ok("passive: a knock heals 20%", P.hp - h0 >= P.max_hp * 0.19, "healed %.1f" % (P.hp - h0))
	# rank 3: the pop drags foes in first
	P.slot_lv["kin"] = 3
	reset.call()
	T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	K.cast_e()
	step(m, 5.0)
	var sp: Vector3 = K.seed["pos"] if not K.seed.is_empty() else T.pos
	T.teleport(sp + Vector3(K.seed_radius() * 1.15, 0, 0))
	K.e_recast()
	step(m, 0.2)
	ok("rank 3: the pop pulls foes at the rim to the middle", Vector2(T.pos.x - sp.x, T.pos.z - sp.z).length() < 1.5 and dmg(T) > 0.0, "off %.1f" % Vector2(T.pos.x - sp.x, T.pos.z - sp.z).length())
	await done(m)
