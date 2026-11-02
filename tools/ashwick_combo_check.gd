extends RefCounted
## --ashwick-combo-check: Ashwick's abilities and their interactions in the archetype check's flat
## strip (docs/heroes/ashwick.md, combinations table): the Torch Lance building Char into a
## Flashover, Cinder Shot on a burning foe (upgrade + spread), Spark Leap's Char and rank-3 stoke
## and trail, the Furnace Cloak (drag, shield, walls), knocks resetting the cloak, Char expiry, and
## the world rules (the lance and the cloak stop at walls, no fire trail over the abyss).

var main: Node
var fails := 0
var n := 0
var ak = null

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	print("ASHCHECK %-56s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	await _all()
	print("ASHCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _all() -> void:
	var r: Array = ak.setup("ashwick", 4.0, "", true)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var T2: Hunter = r[3]
	var home: Vector3 = r[4]; var lv: int = r[5]
	var K: AshwickKit = P.ak
	var W = m.world
	var hx := int(floor(home.x)); var hz := int(floor(home.z))
	var reset := func():
		P.teleport(home); P.vel = Vector3.ZERO; P.hp = P.max_hp; P.stun_t = 0.0; P.shield = 0.0
		for x in [T, T2]:
			ak.fresh(x); x.out = false; x.downed = false; x.dead = false; x.burn_t = 0.0; x.blight_t = 0.0
		T.teleport(home + Vector3(4.0, 0, 0)); T2.teleport(home + Vector3(5.5, 0, 1.5))
		K.chars = {}; K.ignites = {}; K.trail = []; K.drags = []
		K.cd["rmb"] = 0.0; K.ch_rmb = 1.0; K.cd["e"] = 0.0
		P.dashes = P.max_dashes(); P.fire_cd = 0.0
		ak.aim_at(P, T.pos)
	var hold_fire := func(secs: float):
		var t := 0.0
		while t < secs:
			P.inp["fire"] = true; ak.aim_at(P, T.pos)
			m.step(ak.DT); t += ak.DT
		P.inp["fire"] = false
		m.step(ak.DT)
	ok("ashwick: heavy, torch lance, 2 leap charges", P.wid == "flamethrower" and P.cls == "heavy" and P.max_dashes() >= 2.0, "%s %s" % [P.wid, P.cls])
	# --- the lance builds Char; at 31 the foe Flashes over
	reset.call()
	hold_fire.call(0.4)
	var c1: float = K.char_of(T)
	ok("lance: hold = damage and Char building", ak.dmg(T) > 5.0 and c1 > 5.0 and K.burning(T) == 0, "dmg %.1f char %.1f" % [ak.dmg(T), c1])
	hold_fire.call(1.0)
	ok("lance: ~1s of fire = Flashover level 1", K.burning(T) == 1 and T.burn_t > 0.0 and K.ignitions >= 1, "burning %d burn_t %.1f ignitions %d" % [K.burning(T), T.burn_t, K.ignitions])
	hold_fire.call(3.0)
	ok("lance: kept on a burning foe it upgrades to level 2", K.burning(T) == 2 and K.upgrades >= 1, "burning %d ammo %d upgrades %d char %.1f" % [K.burning(T), P.ammo, K.upgrades, K.char_of(T)])
	# --- walls stop the lance and the cloak
	reset.call()
	for dz in range(-6, 7):
		W.level[W.idx(hx + 2, hz + dz)] = lv + 4
	hold_fire.call(0.8)
	var walled: bool = ak.dmg(T) < 1.0 and K.char_of(T) == 0.0
	ok("wall: the lance does not burn through a wall", walled, "dmg %.1f char %.1f" % [ak.dmg(T), K.char_of(T)])
	K.cast_e()
	ak.step(m, 0.8)
	ok("wall: the cloak does not reach behind a wall", ak.dmg(T) < 1.0 and K.char_of(T) == 0.0 and P.flat_dist(T) > 3.5, "dmg %.1f char %.1f dist %.1f" % [ak.dmg(T), K.char_of(T), P.flat_dist(T)])
	for dz in range(-6, 7):
		W.level[W.idx(hx + 2, hz + dz)] = lv
	# --- Cinder Shot: ignites; on a burning foe it upgrades and spreads
	reset.call()
	ak.tap(m, P)
	ak.step(m, 0.8)
	ok("cinder: a hit Flashes the foe over", K.burning(T) == 1 and ak.dmg(T) >= 10.0, "burning %d took %.0f" % [K.burning(T), ak.dmg(T)])
	ak.step(m, 7.0)
	K.cd["rmb"] = 0.0; K.ch_rmb = 1.0
	K.stoke(T)
	var sp0: int = K.spreads
	ak.aim_at(P, T.pos)
	ak.tap(m, P)
	ak.step(m, 0.8)
	ok("combo: lance burn > Cinder Shot = upgrade + spread", K.burning(T) == 2 and K.burning(T2) >= 1 and K.spreads == sp0 + 1, "T %d T2 %d" % [K.burning(T), K.burning(T2)])
	# --- Spark Leap: Char, and at rank 3 a stoke plus a fire trail
	reset.call()
	ak.aim_at(P, T.pos)
	P.ak.on_dash(false)
	ak.step(m, 0.5)
	ok("leap: damage and 17 Char on the foe it passes", ak.dmg(T) >= 10.0 and K.char_of(T) >= 15.0, "dmg %.0f char %.1f" % [ak.dmg(T), K.char_of(T)])
	reset.call()
	P.slot_lv["dash"] = 3
	ak.aim_at(P, T.pos)
	P.ak.on_dash(false)
	ak.step(m, 0.6)
	ok("leap rank 3: stokes at once and leaves a fire trail", K.burning(T) >= 1 and not K.trail.is_empty(), "burning %d trail %d" % [K.burning(T), K.trail.size()])
	var th0: int = K.trail_hits
	T.teleport(K.trail[0]["p"]) if not K.trail.is_empty() else null
	ak.step(m, 0.8)
	ok("leap rank 3: the trail burns whoever stands in it", K.trail_hits > th0, "hits %d" % (K.trail_hits - th0))
	# the trail never forms over the abyss
	reset.call()
	for dz in range(-3, 4):
		for dx in range(2, 4):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_VOID
	K.trail = []
	P.slot_lv["dash"] = 3
	K._lay_trail(home)
	P.teleport(home + Vector3(4.4, 0, 0))
	K.trail = []
	K._lay_trail(home)
	var over_void := false
	for t in K.trail:
		if W.ground_at(t["p"].x, t["p"].z) <= World.VOID + 1.0: over_void = true
	ok("abyss: the fire trail never forms over the void", not over_void and K.trail.size() < 7, "points %d" % K.trail.size())
	for dz in range(-3, 4):
		for dx in range(2, 4):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_GROUND
	P.slot_lv["dash"] = 1
	# --- Furnace Cloak: damage, Char, anti-heal, drag, shield
	reset.call()
	T.teleport(home + Vector3(3.8, 0, 0))
	K.cast_e()
	ak.step(m, 0.8)
	ok("cloak: damage, Char, Anti-Heal and a shield", ak.dmg(T) >= 8.0 and K.char_of(T) >= 15.0 and T.blight_t > 0.0 and P.shield > 5.0, "dmg %.0f char %.0f blight %.1f shield %.1f" % [ak.dmg(T), K.char_of(T), T.blight_t, P.shield])
	ok("cloak: foes in sight are dragged toward you", P.flat_dist(T) < 2.6 and K.pulled >= 1, "dist %.1f" % P.flat_dist(T))
	# --- a knock resets the cloak; knocks heal
	K.cd["e"] = 8.0
	P.hp = P.max_hp * 0.5
	K.on_knock(T, true)
	ok("passive: a knock resets the cloak and heals", float(K.cd["e"]) <= 0.0 and K.resets == 1 and P.hp > P.max_hp * 0.6, "cd %.1f hp %.0f" % [float(K.cd["e"]), P.hp])
	# --- rank 3 refunds when the ability stokes
	reset.call()
	P.slot_lv["kin"] = 3; P.slot_lv["sec"] = 3
	K.stoke(T)
	K.cd["e"] = 10.0
	K.add_char(T, 20.0)           # takes it past 31: the burn upgrades
	K._refund("e")
	ok("rank 3: stoking refunds a quarter of the cooldown", float(K.cd["e"]) < 8.0 and K.refunds >= 1, "cd %.1f" % float(K.cd["e"]))
	P.slot_lv["kin"] = 1; P.slot_lv["sec"] = 1
	# --- Char above 31 is discarded; Char falls off after 5s
	reset.call()
	K.add_char(T, 100.0)
	ok("passive: Char past 31 is discarded (burn, then 0)", K.burning(T) == 1 and K.char_of(T) == 0.0)
	K.add_char(T2, 10.0)
	ak.step(m, 5.4)
	ok("passive: Char falls off all at once after 5s", K.char_of(T2) == 0.0 and K.burning(T) == 0, "char %.1f" % K.char_of(T2))
	m.queue_free()
	await main.get_tree().process_frame
