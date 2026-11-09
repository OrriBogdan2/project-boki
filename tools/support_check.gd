extends RefCounted
## --support-check: the support pair (Pip the Tender, Claire the Rimewright). Ally heals, downed
## teammates (heal, carry, drop, revive), the dash through a teammate, and that the Rink Wall gives the
## squad nothing (no heal or shield). --tender-combo-check and --rimewright-combo-check also run each
## hero's combos (tools/care_combo_check.gd). Mode: "all" | "tender" | "rimewright". Prints SUPPORT PASS/FAIL.

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
## kin_species gives the player that Boki (the merge checks); otherwise the player has none.
func setup(arch: String, dist := 6.0, kin_species := "") -> Array:
	var cls := Arch.weight(arch)
	var m := Match.new()
	main.add_child(m)
	var opts := {"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"cls": cls, "arch": arch, "weapon": Arch.signature(arch)}
	if kin_species != "":
		opts["demo_kin"] = kin_species
	m.start(opts)
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
	for b in m.breaks: b["dead"] = true      # crates and kegs off the strip too: shots here are about the kit
	var home := Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	P.teleport(home); P.vel = Vector3.ZERO
	P.set_arch(arch)
	P.unlock_all()
	P.lvl = 6
	P.dashes = P.max_dashes()
	if P.kin and kin_species == "":
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
	var combos = load("res://tools/care_combo_check.gd").new()
	combos.sc = self
	var ults = load("res://tools/care_ult_check.gd").new()
	ults.sc = self
	if mode in ["all", "tender"]:
		await _tender_support()
		await combos.tender()
		await ults.tender()
	if mode in ["all", "rimewright"]:
		await _rime_support()
		await combos.rimewright()
		await ults.rimewright()
		await ults.burst_cap()
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
	# --- a stun does not put it out (only the ultimate's channel breaks on a stun)
	K.cd["e"] = 0.0
	P.inp["sig"] = true; step(m, 0.05); P.inp["sig"] = false
	P.stun_t = 0.5; step(m, 0.1)
	ok("Hearthlight: a stun on you does not put it out", K.in_e())
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
	ok("Carrier: running into a downed teammate carries them", CareUtil.is_carried(A) and K.carrying().size() == 1)
	ok("Carrier: no shield of ours and no slow while carrying", P.shield <= 0.01 and absf(K.move_k() - 1.0) < 0.01, "shield %.0f k %.2f" % [P.shield, K.move_k()])
	var dh := A.down_hp
	P.teleport(P.pos + Vector3(5, 0, 0)); step(m, 2.0)
	ok("Carrier: the carried teammate rides along and does not bleed", A.flat_dist(P) < 1.0 and A.down_hp >= dh - 0.5, "dist %.2f down_hp %.1f -> %.1f" % [A.flat_dist(P), dh, A.down_hp])
	P.inp["crouch"] = true; step(m, 0.1); P.inp["crouch"] = false; step(m, 0.1)
	ok("Carrier: crouch (never F) sets them down", not CareUtil.is_carried(A) and K.carrying().is_empty())
	# --- carry then a stun drops them
	T.teleport(P.pos + Vector3(14, 0, 0))
	P.slot_lv["dash"] = 3; P.ex_cd = 5.0
	A.teleport(P.pos + Vector3(0.4, 0, 0)); K.lock_t = 0.0; step(m, 0.1)
	var carried_again := CareUtil.is_carried(A)
	ok("Relay Step rank 3: picking up a teammate refreshes the air dash", carried_again and P.ex_cd < 0.01, "ex_cd %.2f" % P.ex_cd)
	P.stun_t = 0.5; step(m, 0.1)
	ok("Carrier: a stun drops them and locks pickup", carried_again and not CareUtil.is_carried(A) and K.lock_t > 3.0, "again %s lock %.1f" % [str(carried_again), K.lock_t])
	# --- a root keeps them (interrupt table: the data lists damage and a stun only)
	P.stun_t = 0.0; K.lock_t = 0.0
	A.teleport(P.pos + Vector3(0.4, 0, 0)); step(m, 0.1)
	var carried_root := CareUtil.is_carried(A)
	P.root_t = 0.5
	step(m, 0.1)
	ok("Carrier: a root does not drop them", carried_root and CareUtil.is_carried(A), "again %s" % str(carried_root))
	P.root_t = 0.0
	# --- a hit drops them too, and costs you no stun of your own
	var carried_third := CareUtil.is_carried(A)
	P.hurt(5.0, T, {}); step(m, 0.1)
	ok("Carrier: a hit drops them with a 4s lock and no stun on you",
		carried_third and not CareUtil.is_carried(A) and K.lock_t > 3.0 and P.stun_t <= 0.0,
		"lock %.1f stun %.2f" % [K.lock_t, P.stun_t])
	# --- rank 3 flare: the revive went back to Hearth Call (X); the flare tops the bleed-out bar up instead
	P.stun_t = 0.0
	P.slot_lv["kin"] = 3
	K.lock_t = 99.0
	K.cd["e"] = 0.0
	A.teleport(P.pos + Vector3(1.0, 0, 0))
	step(m, 0.05)
	ok("rank 3: ally is downed before the flare", A.downed)
	A.down_hp = 10.0
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	step(m, 3.2)
	ok("Hearthlight rank 3: the flare no longer revives (Hearth Call does), it heals the downed", A.downed and A.down_hp > 40.0,
		"down_hp %.0f" % A.down_hp)
	var boost3 := K.throw_boost()
	P.slot_lv["kin"] = 1
	ok("Hearthlight rank 3: the thrown light's healing boost doubles (50% -> 100%, still 1s)",
		absf(boost3 - 1.0) < 0.01 and absf(K.throw_boost() - 0.5) < 0.01 and float(K.e_def().get("boost_t", 1.0)) == 1.0,
		"r3 %.2f r1 %.2f" % [boost3, K.throw_boost()])
	m.queue_free()
	# --- the dash through a teammate
	r = setup("tender"); m = r[0]; P = r[1]; A = r[2]; T = r[3]; K = P.ak
	A.teleport(P.pos + Vector3(2.0, 0, 0)); step(m, 0.05)
	K.cd["e"] = 8.0
	P.inp["move"] = Vector2(1, 0); aim_at(P, P.pos + Vector3(5, 0, 0))
	P.dashes = P.max_dashes()
	P.inp["dash"] = true; step(m, 0.05); P.inp["dash"] = false
	ok("Relay Step: through a teammate refunds nothing", P.dashes <= P.max_dashes() - 0.95 and K.cd["e"] > 7.9, "dashes %.2f e %.1f" % [P.dashes, K.cd["e"]])
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
	A.hp = A.max_hp * 0.5; var ah := A.hp
	step(m, 1.5)
	ok("Rink Wall: no squad shield or heal (she copies her source: ice control only)", A.shield < 0.5 and A.hp <= ah + 0.01, "shield %.1f hp %.1f -> %.1f" % [A.shield, ah, A.hp])
	m.queue_free()
