extends RefCounted
## --zone-check: Tarek (dolm) and Motley placement (docs/heroes/dolm.md, ostra.md). The combo checks extend
## this file: tools/breah_combo_check.gd (--dolm-combo-check), tools/ostra_combo_check.gd (--ostra-combo-check).
##   zone: where rocks, the seed and Trade may land: collision, walls, bodies, abyss edges (the Basalt
##         Spine clipped there, no walkway), and the Net placement events
##         (what one game sends, a second game rebuilds identically).

const ALLY := preload("res://tools/ally_probe.gd")      # a teammate dummy and the friendly-fire sweep

var main: Node
var fails := 0
var n := 0
const DT := 1.0 / 60.0

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	print("PAIRCHECK %-44s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

## Teammates (the ally-effects parity pass): friendly fire is off for every slot of the hero.
func _ally(arch: String) -> void:
	var bad: Array = await ALLY.sweep(main, arch)
	ok("%s ally: no slot hurts, stuns, roots or slows a teammate" % arch, bad.is_empty(), "; ".join(bad))

## A flat strip, the player as `arch`, a dummy hunter `dist` ahead. abyss: x offset where the abyss starts (0 = none).
func setup(arch: String, dist: float, abyss := 0, rank := 1) -> Array:
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch)})
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

## Tarek's Basalt Spine laid along the aim across the abyss strip: X held at a centre over the gap, the
## cursor dragged on along the aim, let go; returns once the cracks are done.
func spine_across(m: Match, P: Hunter, home: Vector3) -> void:
	P.ak.cd["x"] = 0.0
	P.inp["aim"] = home + Vector3(6.5, 0.9, 0)
	step(m, 0.1)
	P.inp["x_down"] = true
	HunterKeys.ult_pressed(P)
	P.inp["aim"] = home + Vector3(12.0, 0.9, 0)
	step(m, 0.2)
	P.inp["x_down"] = false
	step(m, float(P.ak.x_def()["tell"]) + 0.05)

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
	main.get_tree().quit(1 if fails > 0 else 0)

## Starts a Boki merge on `h` the way R does (the full merge when it has a Boki to merge with, else the surge).
func _merge(h: Hunter) -> bool:
	h.ult = 1.0
	if not KinMerge.cast(h):
		KinMerge.surge(h)
	return KinMerge.active(h)

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
	# ---- never over the abyss (the row stands 2.2m ahead; the abyss starts 1.5m ahead)
	r = setup("dolm", 9.0, 2)
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
	step(m, 0.25)      # (the row rises after its 0.2s ground flash)
	var all_ok := true
	for w in rocks(m):
		var mid2: Vector3 = (P.ak as DolmKit).rock_mid(w)
		all_ok = all_ok and not m.world.is_void(mid2.x, mid2.z)
	ok("stone row: rocks near the edge stay on ground", rocks(m).size() > 0 and all_ok, "rocks %d" % rocks(m).size())
	# ---- the Basalt Spine over the abyss: the rocks are laid on the gap as ground, no bridge tiles or event
	var before := void_tiles(m)
	for w in m.verbs.walls.duplicate(): m.verbs._break_wall(w)
	HeroZones.capture = true
	HeroZones.sent.clear()
	spine_across(m, P, home)
	step(m, float(P.ak.x_def()["rise"]) + 0.1)
	HeroZones.capture = false
	var spine := (P.ak as DolmKit).spine
	var over_gap := rocks(m).filter(func(w):
		var mid := (P.ak as DolmKit).rock_mid(w)
		return m.world.is_void(mid.x, mid.z))
	ok(
		"spine: over the abyss the rocks are the walkway: the abyss stays abyss, no bridge event",
		void_tiles(m) == before and not HeroZones.sent.any(func(e): return e[1] == "bridge"),
		"void %d -> %d" % [before, void_tiles(m)]
	)
	ok(
		"spine: rocks stand over the gap and on the banks, every rock raised",
		over_gap.size() >= 3 and rocks(m).size() > over_gap.size() and spine.rocks_raised == rocks(m).size(),
		"rocks %d over the gap %d" % [rocks(m).size(), over_gap.size()]
	)
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
	step(m, 0.25)
	ok("stone row: not built through a rock or wall", rocks(m).size() == 0 and not c2, "rocks %d" % rocks(m).size())
	W2.kind[W2.idx(bx, bz)] = World.T_GROUND
	T.teleport(home + Vector3(3.0, 0, 0))
	step(m, 0.1)
	P.ak.cd["e"] = 0.0
	P.ak.cast_e()
	step(m, 0.25)      # (the row rises after its 0.2s ground flash)
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
	step(m, 0.25)      # (the row rises after its 0.2s ground flash)
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
	await done(m2)
	await done(m)
	# ---- Motley: the seed and Trade respect ground, walls and the abyss
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
	step(m, 1.9)
	# item 42: the target is the cursor (or full reach along it), the abyss included; no ground or walk clamp
	ok(
		"swap: aimed over the abyss, it lands at the cursor, over the abyss (item 42)",
		m.world.is_void(P.pos.x, P.pos.z) and absf(P.pos.x - home.x - 9.0) < 0.3 and absf(P.pos.z - home.z) < 0.3,
		"x %.1f" % (P.pos.x - home.x)
	)
	await done(m)
	r = setup("ostra", 9.0)
	m = r[0]; P = r[1]; home = r[3]
	var W3: World = m.world
	W3.kind[W3.idx(int(floor(home.x)) + 4, int(floor(home.z)))] = World.T_BLOCK
	P.inp["aim"] = home + Vector3(10, 0.9, 0)
	P.ak.on_dash(false)
	step(m, 1.9)
	# the lantern is a high lob (footage: it climbs well above the field and lands exactly at the cursor), so a rock
	# in the way doesn't stop it
	ok(
		"swap: a rock in the way is lobbed over, it lands at the cursor (item 42)",
		absf(P.pos.x - home.x - 10.0) < 0.3 and absf(P.pos.z - home.z) < 0.3, "x %.1f" % (P.pos.x - home.x)
	)
	await done(m)
	# ---- Net: a Trade on a body another game owns is sent, and that body's own game moves it
	ok("net: Net.VERSION is at least 0.14.0 (carry and zone events)", int(Net.VERSION.split(".")[0]) > 0 or int(Net.VERSION.split(".")[1]) >= 14, Net.VERSION)
	r = setup("ostra", 6.0)
	m = r[0]; P = r[1]; T = r[2]; home = r[3]
	T.nid = "t1"
	m.ents_by_id["t1"] = T
	T.remote = true
	T.teleport(home + Vector3(8.0, 0, 0)); aim_at(P, T.pos)
	Displace.capture = true
	Displace.sent.clear()
	P.ak.on_dash(false)
	step(m, 1.9)
	Displace.capture = false
	var tev: Array = Displace.sent.filter(func(e): return e[1] == "tp")
	ok("net: Trade tells the game that owns the foe to move it", tev.size() == 1 and String(tev[0][2]) == "t1" and float(tev[0][3]) < home.x + 2.0 and T.pos.x - home.x > 6.0, str(tev))
	r2 = setup("ostra", 6.0)
	m2 = r2[0]
	var owned: Hunter = r2[2]
	owned.nid = "t1"
	m2.ents_by_id["t1"] = owned
	owned.teleport(r2[3] + Vector3(8.0, 0, 0))
	for e in tev: m2.displace.net_in(e)
	ok("net: the owning game moves the foe to where the trader stood", owned.pos.x - float(r2[3].x) < 2.0, "x %.1f" % (owned.pos.x - float(r2[3].x)))
	await done(m2)
	await done(m)
	HeroZones.capture = false
