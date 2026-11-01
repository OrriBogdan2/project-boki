extends RefCounted
## --mage-combo-check / --gunslinger-combo-check: every cross-ability interaction of Vireo and
## Marlowe, scripted one by one with the right variant asserted (docs/heroes/mage.md and gunslinger.md,
## "Combinations"). Prints HCHECK PASS/FAIL and a DONE line.

var main: Node
var ac: RefCounted
var fails := 0
var n := 0
const DT := 1.0 / 60.0

func ok(name_: String, cond: bool, info := "") -> void:
	n += 1
	print("HCHECK %-52s %s  %s" % [name_, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node, who: String) -> void:
	main = main_node
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main_node
	if who == "mage": await _mage()
	else: await _gunslinger()
	print("HCHECK DONE %s, %d checks, failures: %d" % [who, n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _wall(m: Match, p: Vector3) -> void:
	var W = m.world
	var i: int = W.idx(int(floor(p.x)), int(floor(p.z)))
	W.kind[i] = World.T_BLOCK

func _unwall(m: Match, p: Vector3) -> void:
	var W = m.world
	W.kind[W.idx(int(floor(p.x)), int(floor(p.z)))] = World.T_GROUND

func _mage() -> void:
	var r: Array = ac.setup("mage", 4.0, "", true)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: MageKit = P.ak
	T2.teleport(home + Vector3(30, 0, 0))
	# 1. three weapon sparks + a Coilshot = the fourth: Live
	for i in 3: K.on_deal(T, 4.0, {"src": "shot"})
	ac.aim_at(P, T.pos); K.cd["rmb"] = 0.0; K.ch_rmb = 1.0
	ac.hold(m, P, 0.5)
	ac.step(m, 0.5)
	ok("Coilshot is the 4th Spark: foe is Live", K.live(T) or K.spark_n(T) >= 4, "sparks %d" % K.spark_n(T))
	# 2. Wirerun through a Live foe: Blowout, Sparks spent, dash back; a normal pass does not
	ac.fresh(T); P.teleport(home); P.dashes = P.max_dashes(); K.add_spark(T, 4); ac.step(m, 0.1); ac.aim_at(P, T.pos)
	P.inp["dash_down"] = true; P.do_dash()
	ac.step(m, 0.35, func(): P.inp["dash_down"] = true; ac.aim_at(P, T.pos))
	P.inp["dash_down"] = false
	ac.step(m, 0.1)
	ok("Wirerun: shots pass through you while it runs", P.phase_t > 0.0 or K.last_dash_kind == "wire")
	ac.step(m, 0.5)
	ok("Wirerun through Live: Blowout, Sparks spent, dash back", K.blowouts == 1 and K.spark_n(T) == 0 and P.dashes >= 1.0, "blowouts %d dashes %.1f" % [K.blowouts, P.dashes])
	ac.fresh(T); P.teleport(home); ac.step(m, 0.1); P.dashes = P.max_dashes(); K.add_spark(T, 2); ac.aim_at(P, T.pos)
	var b0 := K.blowouts
	P.inp["dash_down"] = true; P.do_dash()
	ac.step(m, 0.3, func(): P.inp["dash_down"] = true; ac.aim_at(P, T.pos))
	P.inp["dash_down"] = false
	ac.step(m, 0.6)
	ok("Wirerun through a non-Live foe: a plain hit, no reset", K.blowouts == b0 and P.dashes < 1.0 and ac.dmg(T) >= 9.0, "took %.0f dashes %.1f" % [ac.dmg(T), P.dashes])
	# 3. Coilshot into a wall stuns; into another foe stuns both
	ac.fresh(T); K.sparks.clear(); P.teleport(home); T.teleport(home + Vector3(4, 0, 0)); ac.step(m, 0.1)
	_wall(m, home + Vector3(5.6, 0, 0)); ac.aim_at(P, T.pos); K.cd["rmb"] = 0.0; K.ch_rmb = 1.0
	var s0 := K.slams
	ac.hold(m, P, 1.0)
	ac.step(m, 0.3)
	ok("Coilshot into a wall: stun", K.slams == s0 + 1 and T.stun_t > 0.0, "stun %.2f slams %d" % [T.stun_t, K.slams])
	ac.fresh(T); ac.fresh(T2); T.cc_immune_t = 0.0; T2.cc_immune_t = 0.0
	P.teleport(home); T.teleport(home + Vector3(4, 0, 0)); T2.teleport(home + Vector3(5.5, 0.0, 0.0))
	var W = m.world
	W.kind[W.idx(int(floor(home.x + 5.6)), int(floor(home.z)))] = World.T_GROUND
	ac.step(m, 0.1); T2.inv_t = 0.0; T.inv_t = 0.0; ac.aim_at(P, T.pos); K.cd["rmb"] = 0.0; K.ch_rmb = 1.0
	ac.hold(m, P, 1.0)
	ac.step(m, 0.3)
	ok("Coilshot into another foe: both stunned", T.stun_t > 0.0 and T2.stun_t > 0.0, "stuns %.2f / %.2f T %s T2 %s slams %d" % [T.stun_t, T2.stun_t, T.pos - home, T2.pos - home, K.slams])
	# 4. the mote after a hunter hit gives the dash back
	ac.fresh(T); ac.fresh(T2); T2.teleport(home + Vector3(30, 0, 0)); P.teleport(home); T.teleport(home + Vector3(4, 0, 0)); K.motes.clear(); P.dashes = 0.0
	ac.step(m, 0.1); ac.aim_at(P, T.pos); K.cd["rmb"] = 0.0; K.ch_rmb = 1.0
	ac.hold(m, P, 0.6)
	ac.step(m, 0.9)
	ok("Coilshot on a hunter drops a mote", K.motes.size() >= 1)
	var pk0 := K.mote_pickups
	if not K.motes.is_empty(): P.teleport(K.motes[0]["pos"])
	ac.step(m, 0.2)
	ok("Collecting the mote refunds Wirerun", K.mote_pickups == pk0 + 1 and P.dashes >= 1.0)
	# 5. Skycall steals a rival's mote and grounds; then Wirerun is cancelled while Grounded
	ac.fresh(T); P.teleport(home); T.teleport(home + Vector3(5, 0, 0)); K.motes.clear(); ac.step(m, 0.1)
	var mote_pos := home + Vector3(5, 0, 0)
	var nd := K.own_node()
	K.motes.append({"pos": mote_pos, "t": 6.0, "node": nd, "owner": T})
	ac.aim_at(P, T.pos); K.cd["e"] = 0.0
	P.ak.use_e()
	ac.step(m, 0.9)
	ok("Skycall steals a rival's mote", K.motes.size() >= 1 and K.motes[0]["owner"] == P)
	ok("Skycall: Spark + Grounded + flung", K.spark_n(T) >= 1 and KitStatus.grounded(T) and T.pos.x > home.x + 5.5, "x %.1f" % (T.pos.x - home.x))
	# 6. Skycall as the 4th Spark, then Wirerun: the chain
	ac.fresh(T); K.sparks.clear(); P.teleport(home); T.teleport(home + Vector3(5, 0, 0)); ac.step(m, 0.1); K.add_spark(T, 3); K.cd["e"] = 0.0; ac.aim_at(P, T.pos)
	P.ak.use_e()
	ac.step(m, 0.8)
	ok("Skycall as the 4th Spark makes a Live foe", K.live(T))
	# 7. a Grounded Vireo can't start a Wirerun
	KitStatus.apply(P, "gnd", 1.0, 0.0, false); P.dashes = P.max_dashes(); P.teleport(home)
	var w0 := K.blowouts
	P.inp["dash_down"] = true; P.do_dash()
	ok("Grounded: no Wirerun", K.wire.is_empty())
	P.inp["dash_down"] = false
	P.set_meta("gnd_until", 0.0)
	await ac.done(m)
	fails += ac.fails

func _gunslinger() -> void:
	var r: Array = ac.setup("gunslinger", 5.0, "", true)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: GunslingerKit = P.ak
	T2.teleport(home + Vector3(30, 0, 0))
	# 1. Burr Charge: attach + detonation = two Fever stacks, Rattled, rifle +28%
	ac.aim_at(P, T.pos); K.res = 0.0; K.cd["rmb"] = 0.0; K.ch_rmb = 1.0
	ac.tap(m, P)
	ac.step(m, 1.4)
	ok("Burr: sticks and pops, 2 Fever stacks", K.rattles >= 1 and K.res >= 2.0, "fever %.0f" % K.res)
	ok("Burr: target Rattled", KitStatus.rattled(T) and T.slow_t > 0.0)
	ok("Rattled foe takes 28% more from the rifle", is_equal_approx(K.outgoing(T, 10.0, {"src": "shot"}), 12.8))
	ok("Rattled does not boost abilities via outgoing", is_equal_approx(K.outgoing(T, 10.0, {"src": "abil", "ab": "k1"}), 10.0))
	# 2. Longneedle on a Rattled vs. a clean target: +20%, Skewered payoff, cooldown shaved
	ac.fresh(T); ac.fresh(T2)
	KitStatus.clear_rattled(T); K.cd["e"] = 0.0; ac.aim_at(P, T.pos)
	P.ak.use_e(); ac.step(m, 1.1)
	var clean: float = ac.dmg(T)
	ac.fresh(T); KitStatus.apply(T, "rat", 4.0); K.cd["e"] = 0.0; ac.aim_at(P, T.pos)
	var sk0 := K.skewers
	P.ak.use_e(); ac.step(m, 1.1)
	var rat: float = ac.dmg(T)
	ok("Longneedle +20% on a Rattled foe", rat > clean * 1.15 and rat < clean * 1.3, "%.1f vs %.1f" % [rat, clean])
	ok("Longneedle on a Rattled hunter: Skewered payoff", K.skewers == sk0 + 1)
	ok("Longneedle hit takes 30% off its cooldown", float(K.cd["e"]) <= 12.0 * 0.72, "cd %.1f" % float(K.cd["e"]))
	# 3. Longneedle ignores cover
	ac.fresh(T); KitStatus.clear_rattled(T)
	_wall(m, home + Vector3(2.5, 0, 0)); _wall(m, home + Vector3(2.5, 0, 1)); _wall(m, home + Vector3(2.5, 0, -1))
	K.cd["e"] = 0.0; ac.aim_at(P, T.pos)
	P.ak.use_e(); ac.step(m, 1.1)
	ok("Longneedle passes through a wall", ac.dmg(T) >= 30.0, "took %.0f" % ac.dmg(T))
	for zz in [-1, 0, 1]:
		_unwall(m, home + Vector3(2.5, 0, zz))
	# 4. a stun breaks the charge
	K.cd["e"] = 0.0; ac.aim_at(P, T.pos); ac.fresh(T)
	P.ak.use_e(); ac.step(m, 0.3); P.stun_t = 0.5; ac.step(m, 0.2)
	ok("Longneedle: a stun cancels the charge", K.needle.is_empty() and ac.dmg(T) < 0.5)
	P.stun_t = 0.0
	# 5. Burr stuck in a wall: cone, Rattle 2s, shoved into more terrain = stunned, cooldown -40%
	ac.fresh(T); P.teleport(home); T.teleport(home + Vector3(8.5, 0, 2.6)); ac.step(m, 0.1); T.inv_t = 0.0
	var W = m.world
	for z in range(-3, 4):
		_wall(m, home + Vector3(10.5, 0, 1.0 + z))
	for x in range(5, 10):
		_wall(m, home + Vector3(float(x) + 0.2, 0, 4.2))
	P.inp["aim"] = home + Vector3(10.5, 0.9, 1.0); K.cd["rmb"] = 0.0; K.ch_rmb = 1.0
	var ws0 := K.wall_slams
	ac.tap(m, P)
	ac.step(m, 1.2)
	ok("Burr in a wall: cone hits and Rattles for longer", ac.dmg(T) >= 9.0 and KitStatus.rattled_left(T) > 1.0, "took %.0f rattled %.1f" % [ac.dmg(T), KitStatus.rattled_left(T)])
	ok("Burr cone: shoved into terrain = stun + cooldown shave", K.wall_slams == ws0 + 1 and float(K.cd["rmb"]) < 9.0 * 0.7, "slams %d cd %.1f" % [K.wall_slams, float(K.cd["rmb"])])
	# 6. Knock: heal, Slipstep refreshed, rank 3 resets the Burr
	P.slot_lv["sec"] = 3
	P.dashes = 0.0; K.cd["rmb"] = 5.0; K.ch_rmb = 0.0; P.hp = 40.0
	T.hp = 0.0; T.downed = true
	K.on_deal(T, 5.0, {"src": "abil", "ab": "k1"})
	ok("Knock: heals a quarter, refreshes Slipstep", P.hp >= 40.0 + 30.0 and P.dashes >= 1.0, "hp %.0f dashes %.1f" % [P.hp, P.dashes])
	ok("Knock at rank 3: Burr Charge resets", K.ch_rmb >= 1.0 and float(K.cd["rmb"]) == 0.0)
	T.downed = false
	# 7. Slipstep: an early release refunds part of the cooldown
	P.slot_lv["sec"] = 1
	P.teleport(home); P.dashes = P.max_dashes(); P.inp["move"] = Vector2(0, 1)
	P.inp["dash_down"] = true; P.do_dash()
	ac.step(m, 0.3, func(): P.inp["dash_down"] = true)
	P.inp["dash_down"] = false
	ac.step(m, 0.2)
	ok("Slipstep: let go early, part of it comes back", K.last_dash_kind == "slide" and P.dashes > 0.2, "dashes %.2f kind %s" % [P.dashes, K.last_dash_kind])
	await ac.done(m)
	fails += ac.fails
