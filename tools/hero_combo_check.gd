extends RefCounted
## --mage-combo-check / --gunslinger-combo-check: Sparkle's and Vex's kits against their reference
## sheets and the owner notes (docs/heroes/mage.md and gunslinger.md, "Combinations"): where every shot
## and placement lands (max range vs cursor), the telegraph shown while aiming or holding (AimKit), the
## charge timings, and each payoff. Prints HCHECK PASS/FAIL and a DONE line.

var main: Node
var ac: RefCounted
var fails := 0
var n := 0
const DT := 1.0 / 60.0
const VPARITY := preload("res://tools/venator_parity_check.gd")   # Vex against the source (the parity pass)
const VTIME := preload("res://tools/vex_anim_time_check.gd")        # her move timing against the footage frames

func ok(name_: String, cond: bool, info := "") -> void:
	n += 1
	print("HCHECK %-58s %s  %s" % [name_, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node, who: String) -> void:
	main = main_node
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main_node
	var ults: RefCounted = load("res://tools/vv_ult_check.gd").new(self)
	if who == "mage":
		await _mage()
		await load("res://tools/combo_mark_check.gd").new().run(ok, ac, "mage")
		await _growth()
		await ults.mage()
		await load("res://tools/ryzz_items_check.gd").new().run(self, ac)
		var parity = load("res://tools/parity_pvb.gd").new()
		parity.main = main
		await parity.vireo()
		n += parity.n
		fails += parity.fails
	else:
		await _gunslinger()
		await load("res://tools/combo_mark_check.gd").new().run(ok, ac, "gunslinger")
		await ults.gunslinger()
	print("HCHECK DONE %s, %d checks, failures: %d" % [who, n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _wall(m: Match, p: Vector3) -> void:
	var W = m.world
	W.kind[W.idx(int(floor(p.x)), int(floor(p.z)))] = World.T_BLOCK

func _unwall(m: Match, p: Vector3) -> void:
	var W = m.world
	W.kind[W.idx(int(floor(p.x)), int(floor(p.z)))] = World.T_GROUND

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _fire(m: Match, P: Hunter) -> void:
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false

func _last_shot(m: Match, P: Hunter) -> Dictionary:
	for i in range(m.shots.size() - 1, -1, -1):
		if m.shots[i]["by"] == P: return m.shots[i]
	return {}

func _dash(m: Match, P: Hunter, hold_s: float, each := Callable()) -> void:
	P.inp["dash_down"] = true
	P.do_dash()
	ac.step(m, hold_s, func():
		P.inp["dash_down"] = true
		if each.is_valid(): each.call())
	P.inp["dash_down"] = false

## Wirerun's hit on the first foe with the hunter at level `lvl`.
func _wire(lvl: int) -> float:
	var r: Array = ac.setup("mage", 4.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: MageKit = P.ak
	P.lvl = lvl
	LevelGrowth.apply(P)          # growth follows levels gained, not a level set straight on the hunter
	ac.fresh(T)
	K._wire_hit(T, 10.0)
	var d: float = ac.dmg(T)
	await ac.done(m)
	return d

## Ability damage reads ArchKit.power() once, so quiet level growth (LevelGrowth.ap) raises it.
func _growth() -> void:
	var d1: float = await _wire(1)
	var d10: float = await _wire(10)
	ok("growth: Wirerun's hit grows with level (LevelGrowth.ap 1.0 -> %.2f)" % (1.0 + LevelGrowth.ap_pct(10)),
			d1 > 4.0 and absf(d10 / d1 - (1.0 + LevelGrowth.ap_pct(10))) < 0.01,
			"L1 %.2f L10 %.2f" % [d1, d10])

# ------------------------------------------------------------------ Sparkle
func _mage() -> void:
	var r: Array = ac.setup("mage", 4.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: MageKit = P.ak
	T2.teleport(home + Vector3(30, 0, 0))
	# 1. LMB: the finger bolt flies its full range whatever the cursor; the line shows to full range; hands alternate
	P.teleport(home)
	T.teleport(home + Vector3(30, 0, 8))
	ac.step(m, 0.1)
	P.inp["aim"] = home + Vector3(2.0, 0.9, 0)
	P.inp["aim_y"] = home.y
	ac.step(m, 0.05)
	var le := AimKit.entry(P, "lmb")
	ok("LMB: aim line to full range past a near cursor",
			not le.is_empty() and absf((le["to"] as Vector2).distance_to(le["from"] as Vector2) - 13.0) < 0.3,
			str(le.get("to", "")))
	ok("LMB: the weapon aims at max range", AimMode.mode_of(P) == AimMode.MAX)
	_fire(m, P)
	var sd := _last_shot(m, P)
	ac.step(m, 0.03)
	ok("LMB: the bolt reaches 13m with the cursor at 2m",
			not sd.is_empty() and absf(float(sd["life0"]) * (sd["vel"] as Vector2).length() - 13.0) < 0.5,
			"%.1f m" % (float(sd.get("life0", 0.0)) * (sd.get("vel", Vector2.ZERO) as Vector2).length()))
	ok("LMB: the round is a jagged bolt (a pooled rider)", VVFx.of(m).riders.size() >= 1)
	var a1 := K.anim_id
	ac.step(m, 0.85)
	_fire(m, P)
	ac.step(m, 0.03)
	ok("LMB: alternating hands (left, then right)",
			a1 == "mage_lmb_l" and K.anim_id == "mage_lmb_r",
			"%s %s" % [a1, K.anim_id])
	ok("LMB: one bolt every 0.648s (item 116), no magazine to speak of",
			is_equal_approx(float(P.wpn["rate"]), 0.648) and int(P.wpn["mag"]) >= 99)
	# 2. Static: a weapon hit is 1, the marker shows the count; the 4th is Live
	ac.fresh(T)
	T.teleport(home + Vector3(5, 0, 0))
	ac.step(m, 0.1)
	K.on_deal(T, 4.0, {"src": "shot"})
	ac.step(m, 0.05)
	var mk: Dictionary = VVFx.of(m).markers.get("vs%d" % T.get_instance_id(), {})
	ok("Static: a marker over the head shows the count",
			not mk.is_empty() and int(mk["n"]) == K.spark_n(T) and K.spark_n(T) >= 1 and (mk["node"] as Node3D).visible,
			"%s n %d" % [mk.keys(), K.spark_n(T)])
	var sparks_1 := ((mk["node"] as Node3D).get_node("Sparks") as CPUParticles3D).amount if not mk.is_empty() else 0
	var n_1 := K.spark_n(T)
	K.add_spark(T, 4 - n_1)
	ac.step(m, 0.05)
	mk = VVFx.of(m).markers.get("vs%d" % T.get_instance_id(), {})
	var sparks_4 := ((mk["node"] as Node3D).get_node("Sparks") as CPUParticles3D).amount if not mk.is_empty() else 0
	var high := float((mk["node"] as Node3D).global_position.y - T.position.y) if not mk.is_empty() else 0.0
	var grows := sparks_1 == 2 * n_1 and sparks_4 == 8
	ok("Static: 4 = Live, the sparks grow 2 a stack (to 8)",
			K.live(T) and int(mk.get("n", 0)) == 4 and grows,
			"%d -> %d" % [sparks_1, sparks_4])
	ok("Static: the marker sits above the HP bar", high >= K._top(T) + 0.45, "%.2f m" % high)
	# 3. Wirerun: the charge is spent on the press, the lane + end ring grow with the hold (not the cursor)
	K.sparks.clear()
	ac.fresh(T)
	T.teleport(home + Vector3(30, 0, -8))
	P.teleport(home)
	ac.step(m, 0.1)
	P.dashes = P.max_dashes()
	P.inp["aim"] = home + Vector3(3.0, 0.9, 0)
	var d_before := P.dashes
	P.inp["dash_down"] = true
	P.do_dash()
	ok("Wirerun: the cooldown starts on the press",
			P.dashes <= d_before - 0.99 and not K.wire.is_empty(),
			"dashes %.2f -> %.2f" % [d_before, P.dashes])
	ac.step(m, 0.1, func(): P.inp["dash_down"] = true)
	var e1 := _flat(K.wire.get("end", home), P.pos)
	var de := AimKit.entry(P, "dash_end")
	ok("Wirerun held: rails lane and the ticked end ring show",
			AimKit.shown(P, "dash") and not de.is_empty() and bool(de["ticks"]) and absf(float(de["r"]) - 2.25) < 0.01)
	ac.step(m, 0.45, func(): P.inp["dash_down"] = true; P.inp["move"] = Vector2(0, 1))
	var e2 := _flat(K.wire.get("end", home), P.pos)
	ok("Wirerun: length grows with the charge past the cursor (3m)", e1 < 10.0 and e2 > 11.5, "%.1f -> %.1f" % [e1, e2])
	ok("Wirerun held: your keys don't move you", _flat(P.pos, home) < 0.3, "moved %.2f" % _flat(P.pos, home))
	P.inp["move"] = Vector2.ZERO
	P.inp["dash_down"] = false
	ac.step(m, 0.7)
	ok("Wirerun: a full hold streaks at least 12.5 m", _flat(P.pos, home) >= 12.5, "%.1f m" % _flat(P.pos, home))
	var short_v := 7.5 / K.run_time(7.5)
	var long_v := 13.0 / K.run_time(13.0)
	ok("Wirerun: a constant speed (40 m/s under the global dash feel), so a short run is quicker",
			absf(short_v - long_v) < 0.5 and long_v > 31.0 and long_v < 46.0, "%.1f / %.1f m/s" % [short_v, long_v])
	# 4. height holds while charging in the air; drift carries into the run
	P.teleport(home)
	ac.step(m, 0.2)
	P.dashes = P.max_dashes()
	P.pos.y = home.y + 3.0
	P.grounded = false
	P.vel = Vector3.ZERO
	P.inp["aim"] = home + Vector3(8.0, 0.9, 0)
	P.inp["dash_down"] = true
	P.do_dash()
	var y0 := P.pos.y
	ac.step(m, 0.4, func(): P.inp["dash_down"] = true)
	ok("Wirerun held in the air: height holds", absf(P.pos.y - y0) < 0.1, "dy %.2f" % (P.pos.y - y0))
	P.inp["dash_down"] = false
	ac.step(m, 1.2)
	P.teleport(home)
	ac.step(m, 0.2)
	P.dashes = P.max_dashes()
	P.vel = Vector3(0, 0, 6.0)
	P.inp["aim"] = home + Vector3(8.0, 0.9, 0)
	_dash(m, P, 0.15)
	ac.step(m, 0.6)
	ok("Wirerun: momentum before the hold drifts the run", P.pos.z - home.z > 0.6, "drift z %.2f" % (P.pos.z - home.z))
	# 5. through a non-Live foe: a plain hit, no reset; through a Live foe: double + Blowout + reset
	ac.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(5, 0, 0))
	ac.step(m, 0.2)
	P.dashes = P.max_dashes()
	K.add_spark(T, 2)
	ac.aim_at(P, T.pos + Vector3(3, 0, 0))
	T.inv_t = 0.0
	_dash(m, P, 0.3)
	ac.step(m, 0.7)
	var plain: float = ac.dmg(T)
	ok("Wirerun through a non-Live foe: a plain hit, no reset",
			K.blowouts == 0 and P.dashes < 1.0 and plain >= 9.0,
			"took %.0f dashes %.2f" % [plain, P.dashes])
	ac.fresh(T)
	K.sparks.clear()
	P.teleport(home)
	T.teleport(home + Vector3(5, 0, 0))
	ac.step(m, 0.2)
	P.dashes = P.max_dashes()
	K.add_spark(T, 4)
	ac.aim_at(P, T.pos + Vector3(3, 0, 0))
	T.inv_t = 0.0
	_dash(m, P, 0.3)
	ac.step(m, 0.7)
	ok("Wirerun through Live: Blowout, Static spent, dash back",
			K.blowouts == 1 and K.spark_n(T) == 0 and P.dashes >= 1.0,
			"blowouts %d dashes %.1f" % [K.blowouts, P.dashes])
	ok("Wirerun through Live: double the pass plus the Blowout",
			ac.dmg(T) >= plain * 2.0 + 15.0,
			"%.0f vs plain %.0f" % [ac.dmg(T), plain])
	# 6. Storm Rod: the rod summoned, a fixed lane to full range, the full flash, the knock ~1 bh, the orb at once
	ac.fresh(T)
	K.sparks.clear()
	K.motes.clear()
	P.teleport(home)
	T.teleport(home + Vector3(5, 0, 0))
	ac.step(m, 0.2)
	ac.aim_at(P, home + Vector3(2.0, 0, 0))
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	ac.step(m, 0.2, func(): P.inp["sec_hold"] = true)
	var l1: float = float(AimKit.entry(P, "rmb").get("len", 0.0))
	var rod_up := K.rod != null and K.rod.visible
	var mv0 := K.anim_id
	ac.step(m, 0.85, func(): P.inp["sec_hold"] = true; ac.aim_at(P, T.pos))
	var l2: float = float(AimKit.entry(P, "rmb").get("len", 0.0))
	ok("Storm Rod held: the rod is in the hand", rod_up and mv0 == "mage_rmb_hold", mv0)
	ok("Storm Rod held: a fixed 13m double-rail lane (no growth)",
			absf(l1 - 13.0) < 0.01 and absf(l2 - 13.0) < 0.01 and bool(AimKit.entry(P, "rmb").get("rails", false)),
			"%.1f / %.1f" % [l1, l2])
	ok("Storm Rod full at 1s: the body flash", K.rod_full and K.charge_fulls >= 1)
	var x0 := T.pos.x
	P.inp["sec_hold"] = false
	m.step(DT)
	ac.step(m, 0.15)
	var orb_fast := K.motes.size() >= 1
	ac.step(m, 0.9)
	var kb := T.pos.x - x0
	ok("Storm Rod: damage + Static on the first foe", ac.dmg(T) >= 25.0 and K.spark_n(T) >= 1, "took %.0f" % ac.dmg(T))
	ok("Storm Rod: knocked about 1 body height on open ground", kb > 0.8 and kb < 3.0, "%.2f m" % kb)
	ok("Storm Rod: an orb at the impact the moment it hits",
			orb_fast and _flat(K.motes[0]["pos"], home + Vector3(5, 0, 0)) < 2.5)
	P.slot_lv["dash"] = 3
	ok("Rank 3: Wirerun's own hit doubles (rank 1: 1.0)", is_equal_approx(K.run_rank_k(), 2.0), "%.2f" % K.run_rank_k())
	P.slot_lv["dash"] = 1
	# upgrade parity (docs/heroes/mage.md): the source's tier II / III+IV numbers per slot
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 0.05
	var up: Array = []
	P.slot_lv["sec"] = 1
	P.slot_lv["kin"] = 1
	var pb1 := K.power("sec")
	var pk1 := K.power("kin")
	for rk in [1, 2, 3]:
		P.slot_lv["sec"] = rk
		P.slot_lv["dash"] = rk
		P.slot_lv["kin"] = rk
		up.append([K.rmb_def()["cooldown"] * K.cd_k("sec"), K.dash_def()["cd"] * K.dash_k(),
				K.e_def()["cooldown"] * K.cd_k("kin"),
				K.power("sec") / pb1, K.power("dash"), K.power("kin") / pk1])
	ok("upgrade parity: Storm Rod cooldown 8 -> 7.2 -> 6.4 and damage +20% / +90%",
			near.call(up[1][0], 7.2) and near.call(up[2][0], 6.4)
			and near.call(up[1][3], 1.2) and near.call(up[2][3], 1.9), str(up))
	ok("upgrade parity: Wirerun recharge 8 -> 7.33 -> 6.67, no shared damage step",
			near.call(up[1][1], 7.33) and near.call(up[2][1], 6.67)
			and near.call(up[1][4], up[0][4]) and near.call(up[2][4], up[0][4]), str(up))
	ok("upgrade parity: Skycall cooldown 10.5 -> 10.5 -> 7.9 and damage +25% / +50%",
			near.call(up[1][2], 10.5) and near.call(up[2][2], 7.875)
			and near.call(up[1][5], 1.25) and near.call(up[2][5], 1.5), str(up))
	P.slot_lv["sec"] = 1
	P.slot_lv["dash"] = 1
	P.slot_lv["kin"] = 1
	# 7. the orb adds no Static on its own (item 74); a Wirerun through it picks it up and gives the dash back
	ac.fresh(T)
	K.sparks.clear()
	if not K.motes.is_empty(): T.teleport((K.motes[0]["pos"] as Vector3) + Vector3(1.0, 0, 0))
	ac.step(m, 2.0)
	ok("Orb: a foe beside it gets no Static from it", K.spark_n(T) == 0, "sparks %d" % K.spark_n(T))
	P.teleport(home)
	ac.step(m, 0.1)
	P.dashes = P.max_dashes()      # the press spends it; the pickup gives it back
	K.motes.clear()
	K.motes.append({"pos": home + Vector3(5, 0, 0), "t": 4.0, "node": K.own_node(), "owner": P})
	ac.aim_at(P, home + Vector3(8, 0, 0))
	var ob0 := K.orb_bursts
	_dash(m, P, 0.25)
	ac.step(m, 0.6)
	ok("Wirerun through an orb: picked up, no Static, the dash is back",
			K.orb_bursts == ob0 + 1 and K.spark_n(T) == 0 and P.dashes >= P.max_dashes(),
			"picked %d sparks %d dashes %.2f" % [K.orb_bursts - ob0, K.spark_n(T), P.dashes])
	# 7b. walking over a resting orb picks it up too and resets the dash; one a few metres off stays
	P.teleport(home)
	ac.step(m, 0.1)
	P.dashes = 0.0
	K.motes.clear()
	K.motes.append({"pos": home + Vector3(4, 0, 0), "t": 4.0, "node": K.own_node(), "owner": P})
	ac.step(m, 0.2)
	ok("Orb: out of reach it stays, the dash stays spent", K.motes.size() == 1 and P.dashes < 1.0,
			"orbs %d dashes %.2f" % [K.motes.size(), P.dashes])
	P.teleport(home + Vector3(4, 0, 0))
	ob0 = K.orb_bursts
	ac.step(m, 0.2)
	ok("Walking over an orb: picked up, the dash is back",
			K.orb_bursts == ob0 + 1 and K.motes.is_empty() and P.dashes >= P.max_dashes(),
			"picked %d orbs %d dashes %.2f" % [K.orb_bursts - ob0, K.motes.size(), P.dashes])
	# 8. Storm Rod into a wall: stun; into another foe: both stunned
	ac.fresh(T)
	K.sparks.clear()
	P.teleport(home)
	T.teleport(home + Vector3(4, 0, 0))
	ac.step(m, 0.1)
	_wall(m, home + Vector3(5.6, 0, 0))
	ac.aim_at(P, T.pos)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	var s0 := K.slams
	ac.hold(m, P, 1.0)
	ac.step(m, 0.3)
	ok("Storm Rod into a wall: stun", K.slams == s0 + 1 and T.stun_t > 0.0, "stun %.2f" % T.stun_t)
	_unwall(m, home + Vector3(5.6, 0, 0))
	ac.fresh(T)
	ac.fresh(T2)
	P.teleport(home)
	T.teleport(home + Vector3(4, 0, 0))
	T2.teleport(home + Vector3(5.5, 0, 0))
	ac.step(m, 0.1)
	T2.inv_t = 0.0
	T.inv_t = 0.0
	ac.aim_at(P, T.pos)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	ac.hold(m, P, 1.0)
	ac.step(m, 0.3)
	ok("Storm Rod into another foe: both stunned",
			T.stun_t > 0.0 and T2.stun_t > 0.0,
			"%.2f / %.2f" % [T.stun_t, T2.stun_t])
	# 9. Skycall: placed at the cursor, held and dragged (toward you pulls in), committed on release, 0.8s
	# countdown, 1 Static, Grounded
	ac.fresh(T)
	ac.fresh(T2)
	T2.teleport(home + Vector3(30, 0, 0))
	K.sparks.clear()
	K.motes.clear()
	P.teleport(home)
	T.teleport(home + Vector3(7, 0, 0))
	ac.step(m, 0.2)
	K.cd["e"] = 0.0
	ac.aim_at(P, T.pos)
	P.inp["e_down"] = true
	P.ak.use_e()
	ok("Skycall: the circle drops at the cursor", not K.strikes.is_empty() and _flat(K.strikes[0]["at"], T.pos) < 0.3)
	ac.step(m, 0.05)
	ac.aim_at(P, T.pos + Vector3(-3.0, 0, 0))           # the drag: back toward Sparkle
	ac.step(m, 0.55)
	var ce := AimKit.entry(P, "e0")
	ok("Skycall held 0.6s (data: hold and drag, release): still dragging, the arrow + a rim chevron on the circle",
			AimKit.shown(P, "e_drag") and not ce.is_empty() and (ce["pointer"] as Vector2).x < -0.9
			and String(K.strikes[0]["phase"]) == "flick", str(ce.get("pointer", "")))
	P.inp["e_down"] = false
	m.step(ac.DT)
	ok("Skycall: the release commits the drag and starts the countdown", String(K.strikes[0]["phase"]) == "count")
	ac.step(m, 0.75)
	ok("Skycall: nothing lands before the 0.8s countdown", ac.dmg(T) < 0.5)
	var tx0 := T.pos.x
	ac.step(m, 0.3)
	ok("Skycall: 1 Static (data), Grounded, dragged toward you",
			K.spark_n(T) == 1 and KitStatus.grounded(T) and ac.dmg(T) >= 15.0 and T.pos.x < tx0 - 0.5,
			"sparks %d moved %.1f" % [K.spark_n(T), T.pos.x - tx0])
	ac.step(m, 0.9)
	ok("Skycall: the drag is a modest slide (about 3.4 m)",
			absf((tx0 - T.pos.x) - 3.4) < 0.5, "%.1f m" % (tx0 - T.pos.x))
	var e_d: Dictionary = K.e_def()
	ok("Skycall: radius 1.5 m, slide 3.4 m over 1.1 s",
			absf(float(e_d["radius"]) - 1.5) < 0.001 and absf(float(e_d["slide_dist"]) - 3.4) < 0.001
			and absf(float(e_d["slide_t"]) - 1.1) < 0.001)
	var sl_d := float(e_d["slide_dist"])
	var sl_t := float(e_d["slide_t"])
	ok("Skycall: the speed eases out (6.2 m/s peak, half at the midpoint, zero at the end)",
			absf(Displace.slide_speed(sl_d, sl_t, 0.0) - 6.18) < 0.05 and absf(Displace.slide_speed(sl_d, sl_t, sl_t * 0.5) - 3.09) < 0.05
			and Displace.slide_speed(sl_d, sl_t, sl_t) == 0.0 and Displace.slide_speed(sl_d, sl_t, 0.0) < 8.0,
			"%.2f" % Displace.slide_speed(sl_d, sl_t, 0.0))
	ok("Skycall: the strike direction is the flick", (K.last_strike.get("dir", Vector2.ZERO) as Vector2).x < -0.9)
	# source rows (briefs/hero-ref/vireo.md "E: Lightning Javelin": 0.8 s = 4 frames at 5 fps; briefs/supervive-data/
	# supervive_kits.md Joule E: 12 s, 1 Static; cooldown kept at our 8 : 8 : 10.5 pace, E / rod = 9.2 / 7)
	var rod_cd := float(K.rmb_def()["cooldown"])
	ok("Skycall data: 0.8 s countdown, 1 Static, 11 m reach, cooldown 10.5 at the source's E : rod ratio",
			absf(float(e_d["delay"]) - 0.8) < 0.001 and int(e_d["stacks"]) == 1
			and absf(float(e_d["reach"]) - 11.0) < 0.001 and absf(float(e_d["cooldown"]) - 10.5) < 0.001
			and absf(float(e_d["cooldown"]) / rod_cd - 9.2 / 7.0) < 0.05,
			"%s / %s" % [e_d["cooldown"], rod_cd])
	# the drag window is ours (the source states none): held with no release, it commits at drag_max, then 0.8 s
	K.cd["e"] = 0.0
	P.teleport(home)
	ac.aim_at(P, home + Vector3(0, 0, -8.0))
	P.inp["e_down"] = true
	P.ak.use_e()
	ac.step(m, float(e_d["drag_max"]) - 0.1)
	var held_open: bool = String(K.strikes[0]["phase"]) == "flick"
	ac.step(m, 0.2)
	ok("Skycall held with no release: open until 1 s (drag_max), then the countdown starts on its own",
			held_open and String(K.strikes[0]["phase"]) == "count" and absf(float(K.strikes[0]["t"]) - 0.7) < 0.15,
			str(K.strikes[0]["t"]))
	P.inp["e_down"] = false
	ac.step(m, 1.0)
	# no flick: thrown away from you; it steals a rival's orb
	ac.fresh(T)
	K.sparks.clear()
	P.teleport(home)
	T.teleport(home + Vector3(5, 0, 0))
	ac.step(m, 0.1)
	K.motes.clear()
	K.motes.append({"pos": home + Vector3(5, 0, 0), "t": 6.0, "node": K.own_node(), "owner": T})
	ac.aim_at(P, T.pos)
	K.cd["e"] = 0.0
	tx0 = T.pos.x
	P.ak.use_e()
	ac.step(m, 2.2)
	ok("Skycall without a flick: thrown away from you, within 3.9 m",
			T.pos.x > tx0 + 2.5 and T.pos.x < tx0 + 3.9, "%.1f" % (T.pos.x - tx0))
	ok("Skycall: flings a rival's orb, now yours", K.motes.size() >= 1 and K.motes[0]["owner"] == P)
	# a rival Wisp (downed hunter) is launched along the strike too, with no Static and no Grounded
	ac.fresh(T)
	K.sparks.clear()
	K.motes.clear()
	P.teleport(home)
	T.teleport(home + Vector3(5, 0, 0))
	m.knock(T, P, {})
	ac.step(m, 0.1)
	ac.aim_at(P, T.pos)
	K.cd["e"] = 0.0
	tx0 = T.pos.x
	P.ak.use_e()
	ac.step(m, 2.2)
	ok("Skycall launches a rival Wisp (no Static, no Grounded)",
			T.pos.x > tx0 + 2.5 and K.spark_n(T) == 0 and not KitStatus.grounded(T), "%.1f" % (T.pos.x - tx0))
	m.revive_hunter(T, null)
	# 9c. dash -> ability (content/dash_flow/mage.json): a bolt tapped inside Wirerun
	# is buffered and goes off at its end, E starts mid-dash, nothing is dropped
	ac.fresh(T)
	K.strikes.clear()
	P.teleport(home)
	T.teleport(home + Vector3(30, 0, 8))
	ac.step(m, 0.3)
	P.dashes = P.max_dashes()
	P.fire_cd = 0.0
	K.cd["e"] = 0.0
	P.inp["move"] = Vector2.ZERO
	P.inp["aim"] = home + Vector3(8, 0.9, 0)
	var n_di := P.shot_n
	P.do_dash()
	m.step(DT)
	ok("dash table: Wirerun is rolling and DashFlow says LMB fires (the source is silent), E fires",
			P.roll_t > 0.0 and String(DashFlow.row_of("mage", "lmb", false)["mode"]) == "fire" and String(DashFlow.row_of("mage", "e", false)["mode"]) == "fire"
			and absf(DashFlow.BUFFER_S - 0.15) < 0.001)
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	P.ak.use_e()
	ok("dash table: E is cast mid-dash (not dropped)", not K.strikes.is_empty())
	ok("dash table: the tapped bolt fires inside the dash", P.shot_n == n_di + 1 and P.roll_t > 0.0, "%d -> %d" % [n_di, P.shot_n])
	var n_di2 := P.shot_n
	ac.step(m, 0.5)
	ok("dash table: and only once", P.shot_n == n_di2)
	K.strikes.clear()
	# dash animation: Wirerun and Slipstep keep their own moves, none shared
	var dm := HunterAnim.km_def("mage_dash_go")
	var dg := HunterAnim.km_def("gunslinger_dash")
	ok("dash anim: Wirerun and Slipstep each have their own move; neither is a shared roll",
			not dm.is_empty() and not dg.is_empty() and not HunterAnim.km_def("mage_dash_ex").is_empty()
			and not HunterAnim.km_def("gunslinger_dash_ex").is_empty() and not K.dash_def().is_empty())
	# small mechanics (the wiki's fine print, docs/heroes/mage.md "Small mechanics")
	ac.fresh(T)
	ac.fresh(T2)
	K.sparks.clear()
	K.motes.clear()
	P.teleport(home)
	T.teleport(home + Vector3(4, 0, 0))
	T2.teleport(home + Vector3(6.5, 0, 0))
	ac.step(m, 0.2)
	T.inv_t = 0.0
	T2.inv_t = 0.0
	P.dashes = P.max_dashes()
	ac.aim_at(P, home + Vector3(11, 0, 0))
	_dash(m, P, 0.45, func(): if K.run_t > 0.0 and P.phase_t <= 0.0: ok("small: Wirerun ignores projectiles while it runs", false))
	ac.step(m, 0.1)
	ok("small: Wirerun ignores projectiles while it runs (phase)", P.phase_t > 0.0 or K.last_dash_kind == "wire")
	ac.step(m, 0.6)
	ok("small: Wirerun hits every foe it passes (two in a line), about 1.7 bolts each (data: Surge 153 / Jolt 90)",
			ac.dmg(T) >= 18.0 and ac.dmg(T2) >= 18.0,
			"%.0f / %.0f" % [ac.dmg(T), ac.dmg(T2)])
	ac.fresh(T)
	ac.fresh(T2)
	T.teleport(home + Vector3(5, 0, 0))
	T2.teleport(home + Vector3(7, 0, 0))
	P.teleport(home)
	ac.step(m, 0.2)
	T.inv_t = 0.0
	T2.inv_t = 0.0
	ac.aim_at(P, T.pos)
	_fire(m, P)
	ac.step(m, 0.6)
	ok("small: a finger bolt stops on the first foe in line (data: one bolt, no pierce)",
			ac.dmg(T) > 0.0 and ac.dmg(T2) == 0.0,
			"%.0f / %.0f sparks %d %d" % [ac.dmg(T), ac.dmg(T2), K.spark_n(T), K.spark_n(T2)])
	P.dashes = 0.0
	T2.hp = 0.0
	T2.downed = true
	K.on_deal(T2, 5.0, {"src": "shot"})
	ok("small: Sparkle's kit gives no Wirerun on a knock (the game-wide takedown reset is DashReset's)", P.dashes < 0.5)
	T2.downed = false
	T2.hp = T2.max_hp
	T2.teleport(home + Vector3(30, 0, 0))
	P.dashes = P.max_dashes()
	P.teleport(home)
	ac.step(m, 0.1)
	P.inp["dash_down"] = true; P.do_dash(); ac.step(m, 0.1, func(): P.inp["dash_down"] = true)
	P.stun_t = 0.3; ac.step(m, 0.05, func(): P.inp["dash_down"] = true)
	ok("small: a stun mid-hold cancels Wirerun, the charge stays spent", K.wire.is_empty() and P.dashes < 1.0)
	P.inp["dash_down"] = false
	P.stun_t = 0.0
	ac.step(m, 0.4)
	ac.fresh(T)
	K.sparks.clear()
	P.teleport(home)
	T.teleport(home + Vector3(4, 0, 0))
	ac.step(m, 0.2)
	T.inv_t = 0.0
	ac.aim_at(P, T.pos)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	m.step(DT)
	P.inp["sec_hold"] = false
	m.step(DT)
	ac.step(m, 0.2)
	var early_r: float = ac.dmg(T)
	ac.step(m, 0.4)
	ok("small: Storm Rod's 0.33s minimum cast (a tap still winds)",
			early_r < 0.5 and ac.dmg(T) >= 15.0,
			"%.0f then %.0f" % [early_r, ac.dmg(T)])
	# 10. Grounded: no Wirerun
	KitStatus.apply(P, "gnd", 1.0, 0.0, false)
	P.dashes = P.max_dashes()
	P.teleport(home)
	P.inp["dash_down"] = true
	P.do_dash()
	ok("Grounded: no Wirerun", K.wire.is_empty())
	P.inp["dash_down"] = false
	P.set_meta("gnd_until", 0.0)
	# 11. a Boki merge mid-hold: the Wirerun (refunded), the Storm Rod and a Skycall flick go, nothing fires
	ac.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(4, 0, 0))
	K.sparks.clear()
	K.motes.clear()
	ac.step(m, 0.1)
	P.dashes = P.max_dashes()
	ac.aim_at(P, T.pos)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	K.cd["e"] = 0.0
	P.inp["dash_down"] = true
	P.do_dash()
	ac.step(m, 0.2, func(): P.inp["dash_down"] = true; ac.aim_at(P, T.pos))
	var wire_before: bool = not K.wire.is_empty()
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	ac.step(m, 0.1, func(): P.inp["dash_down"] = true; P.inp["sec_hold"] = true; ac.aim_at(P, T.pos))
	P.ak.use_e()
	ok("merge hold: Wirerun, Rod and a Skycall flick are up before the merge",
			wire_before and K.rmb_down and not K.strikes.is_empty())
	var bl0 := K.blowouts
	ok("merge hold: a merge is under way", ac.merge_now(P))
	ac.step(m, 0.1)
	var took0: float = ac.dmg(T)
	ac.step(m, 1.4, func(): P.inp["dash_down"] = true; P.inp["sec_hold"] = true)
	P.inp["dash_down"] = false
	P.inp["sec_hold"] = false
	ac.step(m, 0.5)
	ok("merge hold: everything dropped, nothing fired mid-merge",
			K.wire.is_empty() and not K.rmb_down and K.rmb_t == 0.0 and K.strikes.is_empty() and K.blowouts == bl0 and ac.dmg(T) == took0 and P.dashes >= 1.0,
			"took %.0f -> %.0f dashes %.1f" % [took0, ac.dmg(T), P.dashes])
	await ac.done(m)
	fails += ac.fails

# ------------------------------------------------------------------ Vex
## Items 144 and 144b: the Longneedle's aim locks at the press and turns at a capped rate, so a flick across the
## screen moves the beam at most cap x charge time while a small adjustment still lands; the camera push-out
## scales with the aim distance (none close in, the full 25% at the 18 m range).
func _gunslinger_needle_aim(m: Match, P: Hunter, K: GunslingerKit, home: Vector3) -> void:
	var ed: Dictionary = K.e_def()
	var cap_deg: float = float(ed["turn_deg_s"]) * float(ed["charge"])
	var east := Vector2(1, 0)
	var charge := func(aim_from: Vector3, aim_to: Vector3, mid: float) -> Array:
		K.cd["e"] = 0.0
		P.teleport(home)
		ac.step(m, 0.1)
		ac.aim_at(P, home + aim_from)
		P.ak.use_e()
		ac.step(m, 0.05)
		ac.aim_at(P, home + aim_to)
		ac.step(m, mid)
		var held := rad_to_deg(absf(P.aim_dir().angle_to(east)))
		var cursor := Vector2(P.inp["aim"].x - P.pos.x, P.inp["aim"].z - P.pos.z)     # from where she stands
		ac.step(m, 0.7 - mid)
		return [held, cursor]
	var mid_deg: float = float(charge.call(Vector3(8, 0, 0), Vector3(-8, 0, 0), 0.2)[0])
	var flick_deg := rad_to_deg(absf(K.needle_dir.angle_to(east)))
	ok("Longneedle: the line shows the lagging aim, not the cursor, through the charge",
			mid_deg > 5.0 and mid_deg < cap_deg * 0.6, "%.1f deg after 0.2 s" % mid_deg)
	ok("Longneedle: a 180-degree flick at the press moves the beam at most %.0f degrees" % cap_deg,
			K.needle.is_empty() and flick_deg <= cap_deg + 2.0 and flick_deg >= cap_deg * 0.7, "%.1f deg" % flick_deg)
	var cursor: Vector2 = charge.call(Vector3(8, 0, 0), Vector3(8, 0, 2), 0.2)[1]
	var nudge_deg := rad_to_deg(absf(K.needle_dir.angle_to(cursor)))
	ok("Longneedle: a small tracking adjustment still lands on the cursor", nudge_deg <= 1.0,
			"%.2f deg off" % nudge_deg)
	var cam: CamRig = m.cam
	var push := func(at_m: float) -> Array:
		K.cd["e"] = 0.0
		P.teleport(home)
		ac.step(m, 0.1)
		ac.aim_at(P, home + Vector3(at_m, 0, 0))
		P.ak.use_e()
		ac.step(m, 0.3)
		var out := [cam.cast_zoom, cam.cast_pan.length()]
		ac.step(m, 0.4)
		return out
	var near: Array = push.call(3.0)
	ok("Longneedle: an aim at 3 m leaves the camera alone", float(near[0]) < 0.005 and float(near[1]) < 0.05,
			"zoom %.3f, pan %.2f m" % near)
	var mid: Array = push.call(11.0)
	var far: Array = push.call(18.0)
	ok("Longneedle: the push-out ramps with the aim distance, the full 25% at 18 m",
			float(mid[0]) > 0.05 and float(mid[0]) < 0.2 and absf(float(far[0]) - float(ed["view_zoom"])) < 0.005
			and float(far[1]) > 1.0,
			"11 m zoom %.3f; 18 m zoom %.3f, pan %.2f m" % [mid[0], far[0], far[1]])
	P.vel = Vector3.ZERO     # (she ends the charges still moving and teleport keeps that: it carried into the Slipstep)

func _gunslinger() -> void:
	var r: Array = ac.setup("gunslinger", 5.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: GunslingerKit = P.ak
	var bd: Dictionary = K.rmb_def()["burr"]
	T2.teleport(home + Vector3(30, 0, 0))
	ok("Hired Gun: the display name", Arch.name_of("gunslinger") == "The Hired Gun")
	# 1. LMB: to full range past the cursor, an ember tracer; Dazed = +90%, a gold crit number, no decay
	P.teleport(home)
	T.teleport(home + Vector3(30, 0, 8))
	ac.step(m, 0.1)
	P.inp["aim"] = home + Vector3(2.0, 0.9, 0)
	P.inp["aim_y"] = home.y
	_fire(m, P)
	var sd := _last_shot(m, P)
	ac.step(m, 0.03)
	ok("LMB: rounds fly the full 11m past a near cursor",
			not sd.is_empty() and absf(float(sd["life0"]) * (sd["vel"] as Vector2).length() - 11.0) < 0.6)
	ok("LMB: each round is an ember tracer (a pooled rider)", VVFx.of(m).riders.size() >= 1)
	KitStatus.apply(T, "rat", 3.0)
	var o := {"src": "shot"}
	ok("Dazed: the rifle does +90%", is_equal_approx(K.outgoing(T, 10.0, o), 19.0))
	ok("Dazed: big gold numbers (crit-style)", bool(o.get("crit", false)))
	P.sus_n = 6
	K.outgoing(T, 10.0, {"src": "shot"})
	ok("Dazed: the string's decay pauses", P.sus_n <= 5)
	ok("Dazed: abilities are not boosted through outgoing",
			is_equal_approx(K.outgoing(T, 10.0, {"src": "abil", "ab": "k1"}), 10.0))
	KitStatus.clear_rattled(T)
	# 2. RMB is a tap: no hold in the data, the press throws, no lane and no held pose
	ac.fresh(T)
	T.teleport(home + Vector3(4, 0, 0))
	P.teleport(home)
	ac.step(m, 0.1)
	P.inp["aim"] = home + Vector3(2.0, 0.9, 0)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	var card_rmb := String((K.d["card"] as Dictionary)["rmb"]) + String((K.rmb_def()["variants"] as Dictionary)["tap"])
	ok("RMB: tap only, no hold or auto release in the data, the text says tap",
			not K.rmb_def().has("hold") and not K.rmb_def().has("auto") and K.rmb_charge_full() == 0.0
			and "tap" in card_rmb.to_lower() and not "hold" in card_rmb.to_lower(), card_rmb.left(60))
	P.inp["sec_hold"] = true           # the key staying down changes nothing
	P.ak.press_rmb()
	ok("RMB tap: thrown on the press, nothing held, no lane shown",
			not K.rmb_down and K.burrs.size() == 1 and K.anim_id == "gunslinger_rmb" and AimKit.entry(P, "rmb").is_empty(),
			"%s, %d in flight" % [K.anim_id, K.burrs.size()])
	P.inp["sec_hold"] = false
	m.step(DT)
	# 3a. a direct hit: the foe on the line is hurt and Dazed on the spot, the charge is spent, no cone
	ac.step(m, 0.2)
	ok("RMB direct hit: damage + Dazed, no cone, the charge is spent",
			K.direct_hits == 1 and ac.dmg(T) >= 20.0 and KitStatus.rattled(T) and K.rattles == 0 and K.burrs.is_empty(),
			"took %.1f hits %d rattles %d burrs %d" % [ac.dmg(T), K.direct_hits, K.rattles, K.burrs.size()])
	var rifle := {"src": "shot"}
	ok("RMB direct hit: the Dazed foe takes the rifle's +90%", is_equal_approx(K.outgoing(T, 10.0, rifle), 19.0))
	# 3b. thrown with the foe off the lane: it lands at the lane's end on the ground, shows the cone, blasts
	ac.fresh(T)
	KitStatus.clear_rattled(T)
	T.teleport(home + Vector3(4, 0, 6))
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	P.teleport(home)
	ac.step(m, 0.1)
	P.inp["aim"] = home + Vector3(2.0, 0.9, 0)
	ac.tap(m, P)
	ac.step(m, 0.5)
	var b0: Dictionary = K.burrs[0] if not K.burrs.is_empty() else {}
	ok("RMB: sticks on the ground at the lane's end",
			not b0.is_empty() and float(b0["fuse"]) >= 0.0 and not bool(b0["wall"]) and absf(_flat(b0["pos"], home) - 10.5) < 1.2,
			"at %.1f" % (_flat(b0.get("pos", home), home)))
	var cone_id := ("burr%d" % (b0["node"] as Node3D).get_instance_id()) if not b0.is_empty() else ""
	var ce := AimKit.entry(P, cone_id)
	ok("RMB: the cone shows back toward you, for everyone",
			not ce.is_empty() and bool(ce["all"]) and (ce["dir"] as Vector2).x < -0.9 and absf(float(ce["len"]) - 6.0) < 0.01)
	ok("RMB: the cone drawn is the cone that hits (length %.1f, %.0f degrees)" % [bd["cone_len"], bd["cone_deg"]],
			is_equal_approx(float(ce.get("len", 0.0)), float(bd["cone_len"]))
			and is_equal_approx(float(ce.get("deg", 0.0)), float(bd["cone_deg"])), str(ce.get("deg", -1)))
	ac.fresh(T)
	T.teleport(home + Vector3(8, 0, 0))
	ac.step(m, 0.05)
	var tx := T.pos.x
	ac.step(m, 1.0)
	ok("RMB ground cone: damage + Dazed + shoved toward you",
			ac.dmg(T) >= 12.0 and KitStatus.rattled(T) and T.pos.x < tx - 1.5,
			"took %.0f moved %.1f" % [ac.dmg(T), T.pos.x - tx])
	ok("RMB: 0.9s fuse", is_equal_approx(float(bd["fuse"]), 0.9))
	# 4. on a wall: sticks, the cone back out, a hunter shoved into more terrain is stunned (no cooldown shave)
	ac.fresh(T)
	KitStatus.clear_rattled(T)
	P.teleport(home)
	T.teleport(home + Vector3(7.0, 0, 1.5))
	ac.step(m, 0.1)
	T.inv_t = 0.0
	for z in range(-3, 4):
		_wall(m, home + Vector3(9.5, 0, z))
	for z in [1, 2]:
		_wall(m, home + Vector3(5.5, 0, z))
	P.inp["aim"] = home + Vector3(9.5, 0.9, 0.0)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	var ws0 := K.wall_slams
	ac.fresh(T2)
	KitStatus.clear_rattled(T2)
	T2.teleport(home + Vector3(7.0, 0, -1.5))
	ac.step(m, 0.1)
	T2.inv_t = 0.0
	ac.tap(m, P)
	ac.step(m, 0.5)
	var bw: Dictionary = K.burrs[0] if not K.burrs.is_empty() else {}
	ok("RMB on a wall: sticks to the wall", not bw.is_empty() and bool(bw["wall"]), str(bw.get("pos", "")))
	ac.step(m, 1.1)
	ok("RMB wall cone: a second foe in the cone is hurt and Dazed too",
			KitStatus.rattled(T2) and ac.dmg(T2) >= 12.0, "took %.0f at %s" % [ac.dmg(T2), str(T2.pos - home)])
	ok("RMB wall cone: hits, Dazes, shoves into terrain = stun, the cooldown is not shaved",
			ac.dmg(T) >= 12.0 and KitStatus.rattled(T) and K.wall_slams == ws0 + 1 and float(K.cd["rmb"]) > 6.5 * 0.7,
			"took %.0f slams %d cd %.1f" % [ac.dmg(T), K.wall_slams - ws0, float(K.cd["rmb"])])
	var longer := KitStatus.rattled_left(T) - KitStatus.rattled_left(T2)
	ok("RMB wall slam: the walled foe is Dazed longer (the data), 0.6s past the cone's Daze",
			absf(longer - float(bd["wall_daze"])) < 0.1, "%.2f s longer" % longer)
	for z in range(-3, 4):
		_unwall(m, home + Vector3(9.5, 0, z))
	for z in [1, 2]:
		_unwall(m, home + Vector3(5.5, 0, z))
	# 5. Longneedle: stand still, a full-width line narrowing over 0.6s, the beam at 0.6, recoil back a step
	ac.fresh(T)
	KitStatus.clear_rattled(T)
	T.teleport(home + Vector3(8, 0, 0))
	P.teleport(home)
	ac.step(m, 0.2)
	K.cd["e"] = 0.0
	ac.aim_at(P, T.pos)
	P.ak.use_e()
	ac.step(m, 0.05)
	var w1: float = float(AimKit.entry(P, "e").get("width", 0.0))
	ok("Longneedle: you stand still to charge", K.move_k() <= 0.001)
	ac.step(m, 0.45)
	var w2: float = float(AimKit.entry(P, "e").get("width", 0.0))
	ok("Longneedle: the line narrows over the cast (18m)",
			w1 > 0.8 and w2 < w1 * 0.4 and absf(float(AimKit.entry(P, "e").get("len", 0.0)) - 18.0) < 0.01,
			"%.2f -> %.2f" % [w1, w2])
	ok("Longneedle: the line starts at the width of the beam that hits (%.2f m)" % K.beam_width(),
			w1 <= K.beam_width() + 0.001 and w1 > K.beam_width() * 0.85, "%.2f" % w1)
	ok("Longneedle: nothing before 0.6s", ac.dmg(T) < 0.5)
	var px := P.pos.x
	ac.step(m, 0.4)
	ok("Longneedle: fires at 0.6s", ac.dmg(T) >= 30.0, "took %.0f" % ac.dmg(T))
	ok("Longneedle: the recoil shoves you back", P.pos.x < px - 0.4, "%.2f" % (P.pos.x - px))
	ok("Longneedle hit takes 20% off its cooldown (not 30% before rank 3)",
			float(K.cd["e"]) < 8.9 and float(K.cd["e"]) > 7.7, "%.2f" % float(K.cd["e"]))
	ac.fresh(T)
	KitStatus.apply(T, "rat", 4.0)
	K.cd["e"] = 0.0
	P.teleport(home)
	ac.step(m, 0.1)
	ac.aim_at(P, T.pos)
	var sk0 := K.skewers
	P.ak.use_e()
	ac.step(m, 0.9)
	ok("Longneedle on a Dazed hunter: +20% and Skewered", K.skewers == sk0 + 1 and ac.dmg(T) >= 36.0 * 1.15)
	ac.fresh(T)
	KitStatus.clear_rattled(T)
	P.teleport(home)
	ac.step(m, 0.1)
	for zz in [-1, 0, 1]: _wall(m, home + Vector3(2.5, 0, zz))
	K.cd["e"] = 0.0
	ac.aim_at(P, T.pos)
	P.ak.use_e()
	ac.step(m, 0.9)
	ok("Longneedle passes through a wall", ac.dmg(T) >= 30.0)
	for zz in [-1, 0, 1]: _unwall(m, home + Vector3(2.5, 0, zz))
	K.cd["e"] = 0.0
	ac.fresh(T)
	P.teleport(home)
	ac.step(m, 0.1)
	ac.aim_at(P, T.pos)
	P.ak.use_e()
	ac.step(m, 0.3)
	P.stun_t = 0.5
	ac.step(m, 0.2)
	ok("Longneedle: a stun cancels the charge", K.needle.is_empty() and ac.dmg(T) < 0.5)
	P.stun_t = 0.0
	_gunslinger_needle_aim(m, P, K, home)
	# 6. Slipstep: goes where you move (not the aim), you fire through a tap too
	P.teleport(home)
	ac.step(m, 0.3)
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.inp["aim"] = home + Vector3(8, 0.9, 0)
	var dsh0 := P.dashes
	P.do_dash()
	m.step(DT)
	ok("Slipstep tap: the rifle keeps firing",
			K.fires_in_dash(),
			"dashes %.2f -> %.2f slide %s stun %.2f" % [dsh0, P.dashes, K.slide, P.stun_t])
	P.inp["move"] = Vector2.ZERO
	ac.step(m, 0.15)
	var early := _flat(P.pos, home)
	ac.step(m, 0.15)
	var skidding := not K.slide.is_empty()
	ac.step(m, 0.25)
	var total := _flat(P.pos, home)
	ok("Slipstep tap: a ~0.5s skid that bleeds off (front-loaded past an even pace, still going at 0.3s)",
			skidding and early > total * 0.35 and total > 3.6 and total < 5.6, "%.1f of %.1f m" % [early, total])
	P.inp["move"] = Vector2(0, 1)
	ok("Slipstep: along the keys, not the cursor",
			P.pos.z - home.z > 3.0 and absf(P.pos.x - home.x) < 1.0,
			"dz %.1f dx %.1f" % [P.pos.z - home.z, P.pos.x - home.x])
	P.inp["move"] = Vector2.ZERO
	P.teleport(home)
	ac.step(m, 0.2)
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	_dash(m, P, 0.3)
	ac.step(m, 0.2)
	ok("Slipstep: a held slide is owed a longer cooldown and letting go early refunds nothing",
			K.last_dash_kind == "slide" and P.dashes < -0.2 and absf(float(K.dash_def()["hold_cost"]) - 0.4) < 0.001,
			"dashes %.2f" % P.dashes)
	P.inp["move"] = Vector2.ZERO
	# dash -> ability: the ground slide fires the rifle and E / RMB start mid-slide
	P.teleport(home)
	ac.step(m, 0.3)
	P.dashes = P.max_dashes()
	P.fire_cd = 0.0
	K.cd["e"] = 0.0
	P.inp["move"] = Vector2(0, 1)
	P.inp["aim"] = home + Vector3(8, 0.9, 0)
	var n_gd := P.shot_n
	P.do_dash()
	m.step(DT)
	ok("dash table: the slide and the air roll fire LMB, DashFlow says so",
			String(DashFlow.row_of("gunslinger", "lmb", false)["mode"]) == "fire" and String(DashFlow.row_of("gunslinger", "lmb", true)["mode"]) == "fire" and K.fires_in_dash())
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	ok("dash table: a shot tapped mid-slide fires at once", P.shot_n == n_gd + 1, "%d -> %d" % [n_gd, P.shot_n])
	ac.fresh(T)
	P.ak.use_e()
	ok("dash table: E (Longneedle) starts mid-slide", not K.needle.is_empty())
	P.inp["move"] = Vector2.ZERO
	ac.step(m, 0.8)
	var gk: Array = (HunterAnim.km_def("gunslinger_dash")["keys"] as Array)
	ok("dash anim: Slipstep's move runs about 0.85 s, its own id (not Wirerun's)",
			absf(float((gk[-1] as Array)[0]) - 0.85) < 0.2 and "gunslinger_dash" != "mage_dash_go", "%.2f" % float((gk[-1] as Array)[0]))
	# small mechanics (the wiki's fine print, docs/heroes/gunslinger.md "Small mechanics")
	P.teleport(home)
	ac.step(m, 0.3)
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.pos.y = home.y + 2.5
	P.grounded = false
	P.vel = Vector3.ZERO
	var z0 := P.pos.z
	var dsa := P.dashes
	P.do_dash()
	ac.step(m, 0.45)
	ok("small: an air tap slides 2/3 of the full hold (about 4.7m), a charge spent",
			K.last_dash_kind == "air_slide" and absf(P.pos.z - z0 - 4.7) < 1.0 and dsa - P.dashes >= 0.5,
			"%.1f m kind %s" % [P.pos.z - z0, K.last_dash_kind])
	P.inp["move"] = Vector2.ZERO
	ac.step(m, 0.8)
	ok("small: the rifle loses half its punch over a 10-round string",
			is_equal_approx(float(P.wpn["sustain_loss"]), 0.5) and int(P.wpn["sustain_rounds"]) == 10)
	K.res = 3.0
	K.res_wait = 0.0
	ac.step(m, 0.05)
	ok("small: Fever wears off all at once", K.res == 0.0)
	K.add_fever(1)
	K.add_fever(1)
	ok("small: Fever is one flat level of 6% (a second ability hit adds nothing)",
			K.res == 1.0 and is_equal_approx(K.fever_k(), 0.06) and K.res_wait > 3.0, "%.2f %.2f" % [K.res, K.fever_k()])
	var hp_before := P.hp
	P.hp = 50.0
	K.on_deal(T, 100.0, {"src": "shot"})
	ok("small: Fever heals 6% of the damage dealt", absf(P.hp - 56.0) < 0.5, "hp %.1f" % P.hp)
	P.hp = hp_before
	K.res = 0.0
	ac.fresh(T)
	ac.fresh(T2)
	P.teleport(home)
	T.teleport(home + Vector3(5, 0, 0))
	T2.teleport(home + Vector3(9, 0, 0))
	ac.step(m, 0.2)
	T.inv_t = 0.0
	T2.inv_t = 0.0
	K.cd["e"] = 0.0
	ac.aim_at(P, T.pos)
	P.ak.use_e()
	ac.step(m, 0.9)
	ok("small: Longneedle hits everyone in its line (two)", ac.dmg(T) >= 30.0 and ac.dmg(T2) >= 30.0)
	var cd_two := float(K.cd["e"])
	ok("small: Longneedle at rank 1 cuts its cooldown once however many it hits (20%)", cd_two > 7.7, "%.2f" % cd_two)
	P.slot_lv["kin"] = 3
	ac.fresh(T)
	ac.fresh(T2)
	P.teleport(home)
	T.teleport(home + Vector3(5, 0, 0))
	T2.teleport(home + Vector3(9, 0, 0))
	ac.step(m, 0.2)
	T.inv_t = 0.0
	T2.inv_t = 0.0
	K.cd["e"] = 0.0
	ac.aim_at(P, T.pos)
	P.ak.use_e()
	ac.step(m, 0.9)
	ok("small: Longneedle at rank 3 takes 30% per hunter hit (two hits: 60% off its 11.5s cooldown)",
			float(K.cd["e"]) < 11.5 * 0.5, "%.2f" % float(K.cd["e"]))
	P.slot_lv["kin"] = 1
	# upgrade parity (docs/heroes/gunslinger.md): the source's tier II / III+IV numbers per slot
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 0.05
	var up: Array = []
	for rk in [1, 2, 3]:
		P.slot_lv["sec"] = rk
		P.slot_lv["dash"] = rk
		P.slot_lv["kin"] = rk
		up.append([
			K.rmb_def()["cooldown"] * K.cd_k("sec"), K.dash_def()["cd"] * K.dash_k(),
			K.e_def()["cooldown"] * K.cd_k("kin"), K.power("kin") / K.power("sec"),
		])
	ok("upgrade parity: Burr Charge cooldown 6.5 -> 5.4 -> 4.3",
			near.call(up[0][0], 6.5) and near.call(up[1][0], 5.4) and near.call(up[2][0], 4.3), str(up))
	ok("upgrade parity: Slipstep recharge 8.5 -> 7.4 -> 6.3",
			near.call(up[0][1], 8.5) and near.call(up[1][1], 7.4) and near.call(up[2][1], 6.3), str(up))
	ok("upgrade parity: Longneedle cooldown stays 11.5 and damage +20% / +40%",
			near.call(up[1][2], 11.5) and near.call(up[2][2], 11.5)
			and near.call(up[1][3], 1.2) and near.call(up[2][3], 1.4), str(up))
	P.slot_lv["sec"] = 1
	P.slot_lv["dash"] = 1
	P.slot_lv["kin"] = 1
	T2.teleport(home + Vector3(30, 0, 0))
	# 7. Hot Streak: a knock gives Slipstep back; rank 3 resets the Burr Charge
	P.slot_lv["sec"] = 3
	P.dashes = 0.0
	K.cd["rmb"] = 5.0
	K.ch_rmb = 0.0
	P.hp = 40.0
	T.hp = 0.0
	T.downed = true
	K.on_deal(T, 5.0, {"src": "abil", "ab": "k1"})
	ok("Knock: no Slipstep or heal from the kit (both are DashReset's, so nothing double-fires)",
			P.hp < 41.0 and P.dashes < 0.5, "hp %.1f, dashes %.2f" % [P.hp, P.dashes])
	ok("Knock at rank 3: Burr Charge resets", K.ch_rmb >= 1.0 and float(K.cd["rmb"]) == 0.0)
	T.downed = false
	T.hp = T.max_hp
	P.slot_lv["sec"] = 1
	VPARITY.new(self).run(m, P, K, T, home)
	VTIME.new(self).run(m, P, K, T, home)
	# 8. a Boki merge mid-hold: the Longneedle charge goes with nothing fired
	ac.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(5, 0, 0))
	ac.step(m, 0.1)
	K.cd["e"] = 0.0
	ac.aim_at(P, T.pos)
	P.ak.use_e()
	ac.step(m, 0.2)
	var needle_before: bool = not K.needle.is_empty()
	ok("merge hold: the Longneedle is charging before the merge", needle_before)
	var sk1 := K.skewers
	ok("merge hold: a merge is under way", ac.merge_now(P))
	ac.step(m, 0.1)
	var took1: float = ac.dmg(T)
	ac.step(m, 1.3)
	ok("merge hold: the Longneedle charge is dropped, no shot mid-merge",
			K.needle.is_empty() and K.e_t == 0.0 and K.skewers == sk1 and ac.dmg(T) == took1)
	await ac.done(m)
	fails += ac.fails
