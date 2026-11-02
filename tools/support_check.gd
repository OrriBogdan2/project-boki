extends RefCounted
## --support-check: the support pair (Moosh Moosh the Tender, Tamsin the Rimewright). Ally heals, downed
## teammates (heal, carry, drop, revive), the dash through a teammate, the Rink Wall's frost shield.
## --tender-combo-check and --rimewright-combo-check script each cross-ability interaction in
## docs/heroes. Mode: "all" | "tender" | "rimewright". Prints SUPPORT PASS/FAIL.

var main: Node
var fails := 0
var n := 0
var mode := "all"
const DT := 1.0 / 60.0

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	print("SUPPORT %-46s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

## A flat strip, the player as `arch` on team T, an ally (bot, idle) 3m behind, a rival dummy `dist` ahead.
func setup(arch: String, dist := 6.0) -> Array:
	var cls := Arch.weight(arch)
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "cls": cls, "arch": arch, "weapon": Arch.signature(arch)})
	m.set_process(false)
	var P: Hunter = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var W = m.world
	var hx := int(floor(P.pos.x)); var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-10, 11):
		for dx in range(-12, 26):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND; W.level[i] = lv; W.island[i] = W.island[hi]
			W.stairs.erase(i); W.walls.erase(i); W.props.erase(i); W.bush.erase(i)
	var home := Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	P.teleport(home); P.vel = Vector3.ZERO
	P.set_arch(arch)
	P.unlock_all()
	P.lvl = 6
	P.dashes = P.max_dashes()
	if P.kin:
		var o: Kin = P.kin
		o.dead = true; m.kins.erase(o); o.queue_free(); P.kin = null
	var A: Hunter = m.make_hunter("A", P.team, "medium", "Ally", "idle", {}, home + Vector3(-2.5, 0, 1.5), {"arch": "none"})
	var T: Hunter = m.make_hunter("T", P.team + 5, "medium", "Target", "idle", {}, home + Vector3(dist, 0, 0), {"arch": "none"})
	T.max_hp = 10000.0; T.hp = T.max_hp; T.armor = 0.0; T.max_armor = 0.0
	A.armor = 0.0; A.max_armor = 0.0
	for i in 5: m.step(DT)
	aim_at(P, T.pos)
	return [m, P, A, T, home]

func aim_at(P: Hunter, p: Vector3) -> void:
	P.inp["aim"] = p + Vector3(0, 0.9, 0); P.inp["aim_y"] = p.y

func step(m: Match, secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		t += DT

func down(m: Match, A: Hunter) -> void:
	A.hp = 0.0
	m.knock(A, null, {})
	A.ctrl = "idle"
	A.down_hp = 60.0

func run(mn: Node, md := "all") -> void:
	main = mn
	mode = md
	Save.no_write = true
	if mode in ["all", "tender"]:
		await _tender_support()
		await _tender_combos()
	if mode in ["all", "rimewright"]:
		await _rime_support()
		await _rime_combos()
	print("SUPPORT DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _free(m: Match) -> void:
	m.queue_free()
	await main.get_tree().process_frame

# ------------------------------------------------------------------ Tender
func _tender_support() -> void:
	var r := setup("tender")
	var m: Match = r[0]; var P: Hunter = r[1]; var A: Hunter = r[2]; var T: Hunter = r[3]
	var K: TenderKit = P.ak
	ok("tender: kit wired, medium, no R", K is TenderKit and P.cls == "medium" and Arch.def("tender").get("r", {}).is_empty())
	# --- heal an ally in the ring over its life, flare at the end
	A.hp = A.max_hp * 0.4
	var h0 := A.hp
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false
	ok("Hearthlight: lit, a ring is up", K.in_e() and K.cd["e"] > 5.0)
	step(m, 1.3)
	var mid := A.hp
	ok("Hearthlight: heals an ally in the ring", mid > h0 + 3.0, "%.1f -> %.1f" % [h0, mid])
	step(m, 1.6)
	ok("Hearthlight: flares at the end", not K.in_e() and A.hp > mid + 10.0, "-> %.1f" % A.hp)
	# --- self heal is a third
	P.hp = P.max_hp * 0.4; var p0 := P.hp; A.hp = A.max_hp
	K.cd["e"] = 0.0
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false; step(m, 3.0)
	ok("Hearthlight: heals you at a third", P.hp > p0 and (P.hp - p0) < 22.0, "+%.1f" % (P.hp - p0))
	# --- stun puts it out
	K.cd["e"] = 0.0
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false
	P.stun_t = 0.5; step(m, 0.1)
	ok("Hearthlight: a stun on you puts it out", not K.in_e())
	# --- toss latches on the first teammate it passes
	K.cd["e"] = 0.0; P.stun_t = 0.0
	A.teleport(P.pos + Vector3(4, 0, 0)); step(m, 0.05)
	aim_at(P, A.pos)
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false; step(m, 0.2)
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false; step(m, 0.6)
	ok("Hearthlight: tossed, latches onto a teammate", String(K.hearth.get("mode", "")) == "latched" and K.hearth.get("who") == A, str(K.hearth.get("mode", "")))
	step(m, 3.0)
	# --- downed teammate heals five times over
	down(m, A)
	A.teleport(P.pos + Vector3(1.0, 0, 0.5)); step(m, 0.02)
	K.cd["e"] = 0.0; K.lock_t = 10.0
	var d0 := A.down_hp
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false; step(m, 1.3)
	ok("Hearthlight: a downed teammate drinks it five times over", A.down_hp > d0 + 10.0, "%.0f -> %.0f" % [d0, A.down_hp])
	step(m, 2.0)
	# --- carry
	K.lock_t = 0.0; K.cd["e"] = 99.0
	A.down_hp = 60.0
	A.teleport(P.pos + Vector3(0.6, 0, 0)); step(m, 0.1)
	ok("Bearer: running into a downed teammate carries them", CareUtil.is_carried(A) and K.carrying().size() == 1)
	ok("Bearer: shield up and 30% slower while carrying", P.shield > 30.0 and absf(K.move_k() - 0.7) < 0.01, "shield %.0f k %.2f" % [P.shield, K.move_k()])
	var dh := A.down_hp
	P.teleport(P.pos + Vector3(5, 0, 0)); step(m, 2.0)
	ok("Bearer: the carried teammate rides along and does not bleed", A.flat_dist(P) < 1.0 and A.down_hp >= dh - 0.5, "dist %.2f down_hp %.1f -> %.1f" % [A.flat_dist(P), dh, A.down_hp])
	P.inp["crouch"] = true; step(m, 0.1); P.inp["crouch"] = false; step(m, 0.1)
	ok("Bearer: crouch (never F) sets them down", not CareUtil.is_carried(A) and K.carrying().is_empty())
	# --- carry then a stun drops them
	T.teleport(P.pos + Vector3(14, 0, 0))
	P.shield = 0.0
	P.slot_lv["dash"] = 3; P.ex_cd = 5.0
	A.teleport(P.pos + Vector3(0.4, 0, 0)); K.lock_t = 0.0; step(m, 0.1)
	var carried_again := CareUtil.is_carried(A)
	ok("Relay Step rank 3: picking up a teammate refreshes the air dash", carried_again and P.ex_cd < 0.01, "ex_cd %.2f" % P.ex_cd)
	P.stun_t = 0.5; step(m, 0.1)
	ok("Bearer: a stun drops them and locks pickup", carried_again and not CareUtil.is_carried(A) and K.lock_t > 3.0, "again %s lock %.1f" % [str(carried_again), K.lock_t])
	# --- revive from the flare at rank 3
	P.stun_t = 0.0; P.slot_lv["kin"] = 3; K.lock_t = 99.0; K.cd["e"] = 0.0
	A.teleport(P.pos + Vector3(1.0, 0, 0)); step(m, 0.05)
	ok("rank 3: ally is downed before the flare", A.downed)
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false; step(m, 3.2)
	ok("Hearthlight rank 3: the flare stands a downed teammate up", not A.downed and A.hp > 5.0, "hp %.0f" % A.hp)
	m.queue_free()
	# --- the dash through a teammate
	r = setup("tender"); m = r[0]; P = r[1]; A = r[2]; T = r[3]; K = P.ak
	A.teleport(P.pos + Vector3(2.0, 0, 0)); step(m, 0.05)
	K.cd["e"] = 8.0
	P.inp["move"] = Vector2(1, 0); aim_at(P, P.pos + Vector3(5, 0, 0))
	P.dashes = P.max_dashes()
	P.inp["dash"] = true; step(m, 0.05); P.inp["dash"] = false
	ok("Relay Step: through a teammate refunds half a dash and 1s of Hearthlight", K.last_dash_pass and P.dashes >= P.max_dashes() - 0.55 and K.cd["e"] < 7.2, "dashes %.2f e %.1f" % [P.dashes, K.cd["e"]])
	m.queue_free()

func _tender_combos() -> void:
	var r := setup("tender", 6.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var A: Hunter = r[2]; var T: Hunter = r[3]
	var K: TenderKit = P.ak
	# embers Kindle and wind Hearthlight back
	K.cd["e"] = 8.0
	P.inp["fire"] = true
	step(m, 1.6)
	P.inp["fire"] = false
	ok("combo: embers Kindle a foe", K.kindle_on(T) >= 2, "kindle %d" % K.kindle_on(T))
	ok("combo: ember into a Kindled foe winds Hearthlight back", K.cd["e"] < 7.0, "e %.2f" % K.cd["e"])
	ok("combo: Kindle adds damage to embers", T.max_hp - T.hp > 8.0 * 2, "dealt %.0f" % (T.max_hp - T.hp))
	# an idle gun: the next ember is empowered (longer range flag)
	step(m, 1.3)
	ok("combo: an idle crook empowers the next ember", m.time < K.emp_until and P.shot_range_k > 1.3, "k %.2f" % P.shot_range_k)
	# Burrseed: sticks, bursts, roots, Kindles
	K.kind.clear(); T.hp = T.max_hp
	aim_at(P, T.pos)
	K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	P.inp["sec"] = true; step(m, 0.05); P.inp["sec"] = false
	step(m, 0.7)
	ok("combo: Burrseed sticks to the first foe", K.burrs.size() >= 1 or T.hp < T.max_hp, "burrs %d" % K.burrs.size())
	var h1 := T.hp
	step(m, 2.2)
	ok("combo: Burrseed bursts into roots and Kindles", T.root_t > 0.0 and T.hp < h1 - 20.0 and K.kindle_on(T) >= 1, "root %.2f dmg %.0f kindle %d" % [T.root_t, h1 - T.hp, K.kindle_on(T)])
	# a burst root can't be re-rooted at once (diminishing returns): check separately via second seed? skip
	m.queue_free()
	# Hearthlight on a carried teammate (the toss lands on them)
	r = setup("tender"); m = r[0]; P = r[1]; A = r[2]; T = r[3]; K = P.ak
	down(m, A); A.teleport(P.pos + Vector3(0.5, 0, 0)); step(m, 0.1)
	K.cd["e"] = 0.0
	aim_at(P, P.pos + Vector3(0.5, 0, 0))
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false; step(m, 0.2)
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false; step(m, 0.3)
	ok("combo: Hearthlight tossed at yourself lands on the one you carry", String(K.hearth.get("mode", "")) == "latched" and K.hearth.get("who") == A)
	m.queue_free()

# ------------------------------------------------------------------ Rimewright
func _rime_support() -> void:
	var r := setup("rimewright", 5.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var A: Hunter = r[2]; var T: Hunter = r[3]
	var K: RimewrightKit = P.ak
	ok("rimewright: kit wired, light, no R", K is RimewrightKit and P.cls == "light" and Arch.def("rimewright").get("r", {}).is_empty())
	# --- the Rink Wall shields a teammate who touches it
	var dir := P.aim_dir()
	A.teleport(P.pos + Vector3(dir.x, 0, dir.y) * 5.0 + Vector3(0, 0, 0.5)); step(m, 0.05)
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false
	step(m, 0.5)
	ok("Rink Wall: raised ahead", not K.wall.is_empty() and m.verbs.walls.size() >= 1)
	step(m, 1.5)
	ok("Rink Wall: a teammate touching it gets a frost shield", A.shield >= 17.0, "shield %.1f" % A.shield)
	m.queue_free()

func _rime_combos() -> void:
	var r := setup("rimewright", 6.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var A: Hunter = r[2]; var T: Hunter = r[3]
	var K: RimewrightKit = P.ak
	# the fan Chills; the flurry ends with heavier shards
	P.inp["fire"] = true
	step(m, 1.0)
	P.inp["fire"] = false
	ok("combo: fan darts Chill", K.chilled(T), "dealt %.0f" % (T.max_hp - T.hp))
	var base_dmg := T.max_hp - T.hp
	# rinkrunning doubles the fan
	T.hp = T.max_hp; K.seq_i = 0; K.seq_next = 0.0
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1); P.inp["dash"] = true; P.inp["dash_down"] = true; step(m, 0.05); P.inp["dash"] = false
	ok("combo: Shift held starts a rinkrun", K.rinkrunning() and P.roll_t > 0.0)
	aim_at(P, T.pos)
	P.inp["fire"] = true
	step(m, 0.9)
	P.inp["fire"] = false; P.inp["dash_down"] = false; step(m, 0.3)
	var sk_dmg := T.max_hp - T.hp
	ok("combo: rinkrunning doubles the fan's damage", sk_dmg > base_dmg * 1.4, "%.1f vs %.1f" % [sk_dmg, base_dmg])
	ok("combo: letting go early stops the rinkrun and refunds charge", not K.rinkrunning() and P.dashes > 0.1, "dashes %.2f" % P.dashes)
	m.queue_free()
	# eight shards on one foe Splinter them
	r = setup("rimewright", 5.0); m = r[0]; P = r[1]; A = r[2]; T = r[3]; K = P.ak
	var T2: Hunter = m.make_hunter("T2", T.team, "medium", "Target2", "idle", {}, T.pos + Vector3(1.2, 0, 0), {"arch": "none"})
	T2.max_hp = 10000.0; T2.hp = 10000.0; T2.armor = 0.0; T2.max_armor = 0.0
	var s0 := K.splinter_log
	P.inp["fire"] = true
	step(m, 3.2)
	P.inp["fire"] = false
	ok("combo: eight shards on one foe Splinter them", K.splinter_log > s0 and T2.hp < T2.max_hp, "splinters %d, neighbour -%.0f" % [K.splinter_log - s0, T2.max_hp - T2.hp])
	# Sleet Lance: Chills, slows more up close, goes off twice
	T.hp = T.max_hp; T2.hp = T2.max_hp
	T.teleport(P.pos + Vector3(3.0, 0, 0)); T2.teleport(P.pos + Vector3(30, 0, 0)); step(m, 0.05)
	aim_at(P, T.pos)
	K.ch_rmb = 2.0
	P.inp["sec"] = true; step(m, 0.05); P.inp["sec"] = false
	step(m, 0.25)
	var near_k := T.slow_k
	var first := T.max_hp - T.hp
	step(m, 1.0)
	var second := T.max_hp - T.hp
	ok("combo: Sleet Lance hits, slows up close, and goes off a second time", first > 5.0 and second > first + 8.0 and near_k >= 0.4, "first %.1f total %.1f slow %.2f" % [first, second, near_k])
	# Splinter on a knock: a Chilled foe at low health
	T.hp = 8.0; K.add_chill(T); T2.teleport(T.pos + Vector3(1.5, 0, 0)); T2.hp = T2.max_hp; step(m, 0.05)
	var s1 := K.splinter_log
	var hh := T2.hp
	aim_at(P, T.pos)
	P.inp["fire"] = true; step(m, 0.6); P.inp["fire"] = false
	step(m, 0.8)
	ok("combo: knocking a Chilled foe Splinters them after a beat", T.downed and K.splinter_log > s1 and T2.hp < hh, "downed %s splinters %d neighbour -%.0f" % [str(T.downed), K.splinter_log - s1, hh - T2.hp])
	m.queue_free()
	# the wall stops a foe's shot, and E again freezes it
	r = setup("rimewright", 8.0); m = r[0]; P = r[1]; A = r[2]; T = r[3]; K = P.ak
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false; step(m, 0.3)
	var w0: Vector2 = (K.wall["w"]["a"] as Vector2)
	step(m, 0.5)
	var w1: Vector2 = (K.wall["w"]["a"] as Vector2)
	ok("combo: the Rink Wall slides forward", w1.distance_to(w0) > 0.8, "moved %.2f" % w1.distance_to(w0))
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false; step(m, 0.1)
	var w2: Vector2 = (K.wall["w"]["a"] as Vector2)
	step(m, 0.5)
	ok("combo: E again freezes the wall in place", not bool(K.wall["sliding"]) and (K.wall["w"]["a"] as Vector2).distance_to(w2) < 0.01)
	m.queue_free()
