extends "res://tools/hero_pair_check.gd"
## --gil-combo-check (old name --gil-kit-check): Gil, the Novice Mage (content/archetypes/gil.json,
## scripts/arch/kits/gil_kit.gd, docs/heroes/gil.md), on a training dummy through the real match code: the Fencer
## chain (steps, third-hit slow), the Grab Bag (the shuffled bag, each vial's effect, hold range, the air drop), Fish
## Out of Water (three marks Beach), Ground Swim (hittable, surfacing knocks up), Riptide (spin damage, the spout's
## knockup, longer spin = wider spout) and Tidal Wave (untargetable, knockup then slow, lands with a shield). Then
## gil.md's tables: each slot's numbers, the cancels, the Riptide recast window, the clips, and the dash-flow rows
## (tools/dash_flow_check.gd).

var m: Match
var P: Hunter
var T: Hunter
var K: GilKit
var home: Vector3

func run(main_node: Node) -> void:
	main = main_node
	var r := setup("gil", 6.0)
	m = r[0]
	P = r[1]
	T = r[2]
	home = r[3]
	K = P.ak
	_data()
	_bag()
	_fencer()
	_vials()
	_hold_and_air()
	_beach()
	_swim()
	_riptide()
	_wave()
	_numbers()
	_cancels()
	_recast()
	_clips()
	await done(m)
	var rows_bad: int = await load("res://tools/dash_flow_check.gd").new().check_hero(main, "gil")
	ok("dash flow: every row in content/dash_flow/gil.json holds, every slot casts mid-jump, holds through moves",
		rows_bad == 0, "%d failures" % rows_bad)
	print("PAIRCHECK gil DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _reset(dist := 6.0) -> void:
	K._drop_holds()
	K.flying.clear()
	K.puddles.clear()
	K.spouts.clear()
	K.wave = {}
	K.untarget_t = 0.0
	K.marks.clear()
	K.beach_at.clear()
	K.spin_t = -1.0
	K.swim_t = 0.0
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.roll_t = 0.0            # (a ride or dash left over from the last trial: DashFlow would hold the next press)
	P.grounded = true
	P.shield = 0.0
	P.shield_t = 0.0
	fresh(T)
	T.teleport(home + Vector3(dist, 0, 0))
	aim_at(P, T.pos)
	for s in ["e", "rmb", "dash", "x"]: K.cd[s] = 0.0
	K.e_t = 0.0
	K.ch_rmb = float(K.rmb_def()["charges"])
	P.fire_cd = 0.0
	P.dashes = P.max_dashes()
	P.inp["fire"] = false
	P.inp["sec_hold"] = false
	P.inp["dash_down"] = false
	step(m, 0.1)
	fresh(T)

## Steps until every thrown vial has landed; returns the most stun/slow/burn/lift the dummy showed.
func _land() -> Dictionary:
	var top := {"stun": 0.0, "slow": 0.0, "burn": 0.0, "lift": 0.0, "slow_k": 0.0}
	var y0 := T.pos.y
	var t := 0.0
	var watch := func():
		top["stun"] = maxf(top["stun"], T.stun_t)
		top["slow"] = maxf(top["slow"], T.slow_t)
		top["slow_k"] = maxf(top["slow_k"], T.slow_k)
		top["burn"] = maxf(top["burn"], T.burn_t)
		top["lift"] = maxf(top["lift"], T.pos.y - y0)
	while not K.flying.is_empty() and t < 2.5:
		step(m, DT, watch)
		t += DT
	step(m, 0.05, watch)
	return top

func _data() -> void:
	var card: Dictionary = K.d["card"]
	ok("card: the loop line and one line each for RMB, E, Shift, the passive and the ultimate",
		["loop", "rmb", "e", "dash", "passive", "x"].all(func(k): return String(card.get(k, "")).length() > 10))
	ok("class: Light, signature swordfish", Arch.weight("gil") == "light" and Arch.signature("gil") == "swordfish")
	ok("roster: Gil is in the hunter order (Training Area picker)", "gil" in Arch.ORDER)
	ok("ultimate: Tidal Wave on X, 90 s", float(K.x_def().get("cooldown", 0)) == 90.0)

func _bag() -> void:
	K._refill()
	var counts := {}
	for i in 9:
		var v := K._draw_vial()
		counts[v] = int(counts.get(v, 0)) + 1
	ok("bag: one bag is 2 Thunder, 2 Slime, 2 Air, 2 Fire, 1 Super Zeep",
		counts == {"thunder": 2, "slime": 2, "air": 2, "fire": 2, "zeep": 1}, str(counts))
	ok("bag: refills itself when empty", K.bag.size() == 9, "left %d" % K.bag.size())
	var nx := K.next_vial()
	ok("bag: the next vial is visible on the HUD",
		K.slot_info("sec").get("next", "") == nx and K.res_text() == String(K.vial_def(nx)["name"]))
	var orders := {}
	for i in 4:
		K._refill()
		orders[str(K.bag)] = true
	ok("bag: reshuffles (not one fixed order)", orders.size() > 1)

func _fencer() -> void:
	_reset(3.2)
	var x0 := P.pos.x
	var top := {"n": 0, "slow": 0.0}
	P.inp["fire"] = true
	step(m, 1.1, func():
		P.inp["fire"] = true
		top["slow"] = maxf(top["slow"], T.slow_t)
		top["n"] = K.combo_n)
	P.inp["fire"] = false
	ok("Fencer: a three-hit chain lands on the dummy", int(top["n"]) >= 3 and dmg(T) >= 20.0,
		"swings %d dmg %.1f" % [top["n"], dmg(T)])
	ok("Fencer: each swing steps him forward", P.pos.x - x0 > 0.8, "moved %.2f" % (P.pos.x - x0))
	ok("Fencer: the third, longer thrust slows (30% for 0.5 s)", top["slow"] > 0.2 and top["slow"] <= 0.55,
		"slow_t %.2f" % top["slow"])

func _vials() -> void:
	var want := {"thunder": "stun", "slime": "slow", "fire": "burn", "zeep": "lift"}
	for v in ["thunder", "slime", "air", "fire", "zeep"]:
		_reset(6.0)
		K.bag.append(v)
		var x0 := T.pos.x
		tap(m, P)
		var top := _land()
		var hit := dmg(T) > 0.0
		match v:
			"thunder": ok("Thunder: damage and a stun in the centre", hit and top["stun"] >= 0.4,
				"dmg %.1f stun %.2f" % [dmg(T), top["stun"]])
			"slime": ok("Slime: 40% slow and a puddle stays",
				top["slow"] >= 1.2 and absf(top["slow_k"] - 0.4) < 0.05 and K.puddles.size() == 1,
				"slow %.2f k %.2f puddles %d" % [top["slow"], top["slow_k"], K.puddles.size()])
			"air":
				step(m, 0.5)
				ok("Air: knocks the dummy away", T.pos.x - x0 > 1.5, "pushed %.2f" % (T.pos.x - x0))
			"fire": ok("Fire: damage plus a burn", hit and top["burn"] > 0.0,
				"dmg %.1f burn %.2f" % [dmg(T), top["burn"]])
			"zeep": ok("Super Zeep: bigger blast, knocks up", hit and top["stun"] >= 0.6 and top["lift"] > 0.3,
				"stun %.2f lift %.2f" % [top["stun"], top["lift"]])
	# the slime puddle keeps slowing
	_reset(6.0)
	K.bag.append("slime")
	tap(m, P)
	_land()
	fresh(T)
	step(m, 0.3)
	ok("Slime: the puddle slows whoever stands in it", T.slow_t > 0.0 and absf(T.slow_k - 0.25) < 0.05,
		"slow %.2f k %.2f" % [T.slow_t, T.slow_k])

func _hold_and_air() -> void:
	_reset(6.0)
	aim_at(P, home + Vector3(30, 0, 0))
	K.bag.append("air")
	hold(m, P, 0.5)
	var far := 0.0
	if not K.flying.is_empty():
		far = Vector2(K.flying[0]["at"].x - home.x, K.flying[0]["at"].z - home.z).length()
	ok("Grab Bag hold: lands +50% further (12 m against 8)", far > 11.0 and far < 12.6, "%.2f m" % far)
	_land()
	_reset(6.0)
	P.teleport(home + Vector3(0, 3.0, 0))
	P.grounded = false
	K.bag.append("fire")
	tap(m, P)
	var below := false
	if not K.flying.is_empty():
		var at: Vector3 = K.flying[0]["at"]
		below = Vector2(at.x - P.pos.x, at.z - P.pos.z).length() < 0.6 and at.y < P.pos.y - 1.0
	ok("Grab Bag in the air: drops the vial straight down", below)
	_land()

func _beach() -> void:
	_reset(6.0)
	for v in ["air", "fire", "slime"]: K.bag.append(v)      # slime first, then fire, then air (none stuns alone)
	var top := {"stun": 0.0}
	for i in 3:
		K.ch_rmb = 2.0
		K.cd["rmb"] = 0.0
		aim_at(P, T.pos)
		var before := K.marks_on(T)
		tap(m, P)
		var t := _land()
		top["stun"] = maxf(top["stun"], t["stun"])
		if i < 2:
			ok("Fish Out of Water: vial %d leaves a mark (%d)" % [i + 1, K.marks_on(T)], K.marks_on(T) == before + 1)
	ok("Fish Out of Water: three different marks within 5 s Beach the dummy (0.75 s stun)", top["stun"] >= 0.6,
		"stun %.2f" % top["stun"])
	ok("Fish Out of Water: 8 s per target", float(K.beach_at.get(T.get_instance_id(), 0.0)) - m.time > 7.0)

func _swim() -> void:
	_reset(5.0)
	var x0 := P.pos.x
	K.on_dash(false)
	m.step(DT)
	var under := K.swim_t > 0.0
	var hit_on := float(K.incoming(T, 10.0, {})[0]) == 10.0
	var top := {"stun": 0.0, "y": 0.0}
	var y0 := T.pos.y
	step(m, 0.8, func():
		top["stun"] = maxf(top["stun"], T.stun_t)
		top["y"] = maxf(top["y"], T.pos.y - y0))
	ok("Ground Swim: swims about 6 m", P.pos.x - x0 > 4.0 and P.pos.x - x0 < 7.5, "%.2f m" % (P.pos.x - x0))
	ok("Ground Swim: he stays hittable underground", under and hit_on)
	ok("Ground Swim: surfacing knocks nearby foes up 0.5 s", top["stun"] >= 0.4 and top["y"] > 0.2,
		"stun %.2f lift %.2f" % [top["stun"], top["y"]])
	ok("Ground Swim: 8 s cooldown", float(K.dash_def()["cd"]) == 8.0)

func _riptide() -> void:
	_reset(1.6)
	K.use_e()
	ok("Riptide: E starts the spin", K.spin_t >= 0.0)
	step(m, 1.0)
	var spin_dmg := dmg(T)
	ok("Riptide: the spin hurts foes around him", spin_dmg > 0.0, "%.1f" % spin_dmg)
	_reset(7.0)
	K.use_e()
	step(m, 0.3)
	K.e_recast()
	var w_short: float = K.spouts[0]["w"] if not K.spouts.is_empty() else 0.0
	var top := {"stun": 0.0}
	step(m, 1.2, func(): top["stun"] = maxf(top["stun"], T.stun_t))
	ok("Riptide recast: the waterspout runs down the line and knocks up 1 s", top["stun"] >= 0.9 and dmg(T) > 0.0,
		"stun %.2f" % top["stun"])
	_reset(7.0)
	K.use_e()
	step(m, 2.2)
	var w_long := 0.0
	var auto := not K.spouts.is_empty() and K.spin_t < 0.0
	if not K.spouts.is_empty(): w_long = K.spouts[0]["w"]
	if K.spouts.is_empty() and dmg(T) > 0.0: auto = true
	ok("Riptide: at 2 s the spout goes on its own", auto or K.spin_t < 0.0)
	ok("Riptide: a longer spin makes a wider spout",
		w_long > w_short + 0.3 or (w_long == 0.0 and w_short > 0.0 and K.spin_t < 0.0),
		"%.2f vs %.2f" % [w_long, w_short])
	ok("Riptide: 12 s cooldown", float(K.e_def()["cooldown"]) == 12.0)

func _wave() -> void:
	_reset(6.0)
	P.lvl = 6
	ok("Tidal Wave: casts", K.cast_ult())
	m.step(DT)
	ok("Tidal Wave: Gil is untargetable while he surfs",
		K.untarget_t > 0.0 and float(K.incoming(T, 50.0, {})[0]) == 0.0)
	var top := {"stun": 0.0, "slow": 0.0, "k": 0.0}
	step(m, 1.2, func():
		top["stun"] = maxf(top["stun"], T.stun_t)
		top["slow"] = maxf(top["slow"], T.slow_t)
		top["k"] = maxf(top["k"], T.slow_k))
	ok("Tidal Wave: knocks up 1 s, then slows 50% for 2 s",
		top["stun"] >= 0.9 and top["slow"] >= 2.5 and absf(top["k"] - 0.5) < 0.05,
		"stun %.2f slow %.2f k %.2f" % [top["stun"], top["slow"], top["k"]])
	ok("Tidal Wave: lands with a shield and is hittable again",
		P.shield > 0.0 and K.untarget_t <= 0.0 and float(K.incoming(T, 10.0, {})[0]) == 10.0,
		"shield %.1f" % P.shield)
	ok("Tidal Wave: 90 s cooldown after the cast", float(K.cd["x"]) > 85.0, "%.1f" % float(K.cd["x"]))

# ------------------------------------------------------------------ gil.md: numbers per slot
## One press of a one-step key (Hunter.inp: "sig" E, "sec" RMB, "dash" Shift, "jump"), held for a single step.
func _press(key: String) -> void:
	P.inp[key] = true
	m.step(DT)
	P.inp[key] = false

func _numbers() -> void:
	_lmb_numbers()
	_rmb_numbers()
	_dash_numbers()
	_e_numbers()
	_x_numbers()
	_passive_numbers()
	_rank_numbers()

## Fencer: 7 / 7 / 11 a thrust, 0.32 s between thrusts and 0.48 s after the lunge, the chain resets after 0.75 s.
func _lmb_numbers() -> void:
	_reset(2.0)
	K.combo_n = 0
	var by_n := {}
	var cds := {}
	var t := 0.0
	while t < 1.1:
		P.inp["fire"] = true
		var was := K.combo_n
		m.step(DT)
		t += DT
		if K.combo_n != was: cds[K.combo_n] = P.fire_cd
		by_n[K.combo_n] = dmg(T)
	P.inp["fire"] = false
	var hit := [float(by_n.get(1, 0.0)), float(by_n.get(2, 0.0)) - float(by_n.get(1, 0.0)),
		float(by_n.get(3, 0.0)) - float(by_n.get(2, 0.0))]
	ok("numbers LMB: 7, 7, then 11 on the lunge (+0.1 for the slow)",
		absf(hit[0] - 7.0) < 0.2 and absf(hit[1] - 7.0) < 0.2 and absf(hit[2] - 11.1) < 0.2, str(hit))
	ok("numbers LMB: 0.32 s between thrusts, 0.48 s after the lunge",
		absf(float(cds.get(1, 0.0)) - 0.32) < 0.02 and absf(float(cds.get(3, 0.0)) - 0.48) < 0.02, str(cds))
	step(m, 0.8)
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	ok("numbers LMB: after 0.75 s idle the chain starts again at the first thrust", P.combo_i == 1, "i %d" % P.combo_i)

## Grab Bag: 2 charges, 5 s each, 8 m to the cursor, 0.35 s + 0.03 s a metre in the air.
func _rmb_numbers() -> void:
	_reset(6.0)
	aim_at(P, home + Vector3(30, 0, 0))
	var t0 := m.time
	tap(m, P)
	var at: Vector3 = K.flying[0]["at"] if not K.flying.is_empty() else home
	var far := Vector2(at.x - home.x, at.z - home.z).length()
	var ft: float = K.flying[0]["t"] if not K.flying.is_empty() else 0.0
	ok("numbers RMB: a tap lands 8 m out at most, 0.59 s in the air there", absf(far - 8.0) < 0.3
		and absf(ft - (0.35 + 0.03 * far)) < 0.01, "%.2f m %.2f s" % [far, ft])
	tap(m, P)
	var thrown := K.flying.size()
	tap(m, P)
	ok("numbers RMB: two charges, a third press throws nothing", thrown == 2 and K.flying.size() == 2,
		"%d then %d" % [thrown, K.flying.size()])
	while K.ch_rmb < 1.0 and m.time - t0 < 7.0:
		m.step(DT)
	ok("numbers RMB: a charge comes back 5 s after the first throw", absf(m.time - t0 - 5.0) < 0.1,
		"%.2f s" % (m.time - t0))

## Ground Swim: under for 0.4 s, 4 damage and the 0.5 s knockup on surfacing, a charge back after 8 s.
func _dash_numbers() -> void:
	_reset(5.0)
	var d0 := P.dashes
	_press("dash")
	var under := 0.0
	while K.swim_t > 0.0 and under < 1.0:
		m.step(DT)
		under += DT
	step(m, 0.1)
	ok("numbers Shift: under the ground about 0.4 s (the shared dash feel's time scale)", under > 0.25 and under < 0.6,
		"%.2f s" % under)
	ok("numbers Shift: surfacing deals 4", absf(dmg(T) - 4.0) < 0.2, "%.1f" % dmg(T))
	var back := 0.0
	while P.dashes < d0 and back < 10.0:
		m.step(DT)
		back += DT
	ok("numbers Shift: a charge back in 8 s at rank 1", absf(back + under + 0.1 - 8.0) < 0.3,
		"%.2f s" % (back + under + 0.1))

## Riptide: ticks every 0.25 s rising 2 -> 5, he walks at 70% while spinning, the full-spin spout is 11 m long,
## 2.2 m wide, 22 m/s, and does 10.
func _e_numbers() -> void:
	_reset(1.6)
	var seen := {"ticks": [], "last": 0.0, "k": 1.0}
	_press("sig")
	step(m, 1.95, func():
		seen["k"] = minf(seen["k"], K.move_k())
		if dmg(T) > float(seen["last"]) + 0.01:
			seen["ticks"].append(snappedf(dmg(T) - float(seen["last"]), 0.01))
			seen["last"] = dmg(T))
	var ticks: Array = seen["ticks"]
	ok("numbers E: 8 spin ticks, 2 at first, rising, under 5", ticks.size() == 8 and absf(float(ticks[0]) - 2.0) < 0.2
		and float(ticks[-1]) > float(ticks[0]) and float(ticks[-1]) <= 5.0, str(ticks))
	ok("numbers E: he moves at 70% while he spins", absf(float(seen["k"]) - 0.7) < 0.01, "%.2f" % seen["k"])
	var spout := {}
	step(m, 0.2, func(): if spout.is_empty() and not K.spouts.is_empty(): spout.merge(K.spouts[0]))
	ok("numbers E: a full 2 s spin sends an 11 m, 2.2 m wide, 22 m/s spout",
		absf(float(spout.get("left", 0.0)) - 11.0) < 0.6 and absf(float(spout.get("w", 0.0)) - 2.2) < 0.05
		and absf(float(spout.get("spd", 0.0)) - 22.0) < 0.5 and K.move_k() == 1.0, str(spout.get("left", 0.0)))
	_reset(5.0)
	_press("sig")
	step(m, 0.3)
	_press("sig")
	step(m, 0.6)
	ok("numbers E: the spout does 10 (nothing else reaches 5 m)", absf(dmg(T) - 10.0) < 0.2, "%.1f" % dmg(T))

## Tidal Wave: locked below level 6, 14 m in 1 s, 18 damage, a 40 shield for 3 s.
func _x_numbers() -> void:
	_reset(6.0)
	P.lvl = 5
	var cast := HunterKeys.ult_pressed(P)
	ok("numbers X: no wave below level 6", not cast and K.wave.is_empty() and float(K.cd["x"]) == 0.0)
	P.lvl = 6
	K.cd["x"] = 0.0
	var x0 := P.pos.x
	HunterKeys.ult_pressed(P)
	var t := 0.0
	while not K.wave.is_empty() and t < 2.0:
		m.step(DT)
		t += DT
	ok("numbers X: he rides about 14 m in 1 s", absf(t - 1.0) < 0.1 and absf(P.pos.x - x0 - 14.0) < 1.5,
		"%.2f s %.2f m" % [t, P.pos.x - x0])
	ok("numbers X: 18 to a foe in the line", absf(dmg(T) - 18.0) < 0.2, "%.1f" % dmg(T))
	ok("numbers X: lands with a 40 shield for 3 s", P.shield == 40.0 and absf(P.shield_t - 3.0) < 0.05,
		"%.1f for %.2f s" % [P.shield, P.shield_t])

## Fish Out of Water: marks older than 5 s drop, so two marks, a 5 s wait and a third don't Beach.
func _passive_numbers() -> void:
	_reset(6.0)
	for v in ["slime", "fire"]: K.bag.append(v)      # fire, then slime, then (after the wait) air: none stuns alone
	for i in 2:
		K.ch_rmb = 2.0
		aim_at(P, T.pos)
		tap(m, P)
		_land()
	step(m, 5.1)
	fresh(T)
	K.bag.append("air")
	K.ch_rmb = 2.0
	aim_at(P, T.pos)
	tap(m, P)
	var top := _land()
	ok("numbers passive: marks last 5 s (two, a 5 s wait, a third: no Beach)",
		K.marks_on(T) == 1 and top["stun"] == 0.0,
		"marks %d stun %.2f" % [K.marks_on(T), top["stun"]])

## The shared rank steps (ArchKit.cd_k, dash_k, power): RMB and E -10% cooldown a rank, Shift -15% a rank.
func _rank_numbers() -> void:
	var p1 := K.power("sec")
	for s in ["sec", "dash", "kin"]: P.slot_lv[s] = 2
	var r2 := [K.cd_k("sec"), K.cd_k("kin"), P.dash_regen(), K.power("sec") / p1]
	for s in ["sec", "dash", "kin"]: P.slot_lv[s] = 3
	var r3 := [K.cd_k("sec"), K.cd_k("kin"), P.dash_regen(), K.power("sec") / p1]
	for s in ["sec", "dash", "kin"]: P.slot_lv[s] = 1
	ok("numbers ranks: RMB and E cooldowns x0.9 then x0.8", is_equal_approx(r2[0], 0.9) and is_equal_approx(r2[1], 0.9)
		and is_equal_approx(r3[0], 0.8) and is_equal_approx(r3[1], 0.8), "%s %s" % [r2, r3])
	ok("numbers ranks: Shift recharges in 6.8 s then 5.6 s (the card says 7 s and 6 s)",
		absf(float(r2[2]) - 6.8) < 0.01 and absf(float(r3[2]) - 5.6) < 0.01, "%.2f %.2f" % [r2[2], r3[2]])
	ok("numbers ranks: damage +15% then +30%", absf(float(r2[3]) - 1.15) < 0.01 and absf(float(r3[3]) - 1.3) < 0.01,
		"%.3f %.3f" % [r2[3], r3[3]])

# ------------------------------------------------------------------ gil.md: cancels (second press, first action)
func _cancels() -> void:
	_spin_cancels()
	_wave_cancels()
	_cc_cancels()

## During the Riptide spin: LMB and RMB go with it, Shift is locked (dash_flow into_dash.e), X sends the spout first.
func _spin_cancels() -> void:
	_reset(1.6)
	_press("sig")
	step(m, 0.3)
	step(m, 0.4, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	ok("cancel E spin + LMB: both (the thrusts land, the spin goes on)", K.combo_n >= 1 and K.spin_t >= 0.0,
		"thrusts %d" % K.combo_n)
	tap(m, P)
	ok("cancel E spin + RMB: both (the potion flies, the spin goes on)", K.flying.size() == 1 and K.spin_t >= 0.0)
	var d0 := P.dashes
	_press("dash")
	ok("cancel E spin + Shift: locked (no dash, no charge spent, the spin goes on)",
		P.dashes == d0 and K.swim_t <= 0.0 and P.roll_t <= 0.0 and K.spin_t >= 0.0)
	var y0 := P.pos.y
	_press("jump")
	step(m, 0.15)
	ok("cancel E spin + jump: both (he hops, still spinning)", P.pos.y - y0 > 0.2 and K.spin_t >= 0.0,
		"%.2f m" % (P.pos.y - y0))
	step(m, 0.6)
	HunterKeys.ult_pressed(P)
	ok("cancel E spin + X: the spout goes first, then the wave", K.spin_t < 0.0 and K.spouts.size() == 1
		and not K.wave.is_empty())

## During the Tidal Wave (an Effects dash, so DashFlow's default rows): E, RMB and LMB wait for the landing and go
## then; Shift is dropped (into_dash.x lock: no charge, no swim, not replayed); X does nothing (no early landing).
func _wave_cancels() -> void:
	_reset(6.0)
	HunterKeys.ult_pressed(P)
	m.step(DT)
	var d0 := P.dashes
	_press("sig")
	_press("sec")
	step(m, 0.1, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	var mid := [K.spin_t >= 0.0, K.flying.size(), K.combo_n, P.dashes]
	var left := K.untarget_t
	HunterKeys.ult_pressed(P)
	m.step(DT)
	ok("cancel X wave + X: nothing (no early landing)", not K.wave.is_empty() and K.untarget_t < left)
	_press("dash")
	ok("cancel X wave + E, RMB, LMB: nothing goes mid-ride", not mid[0] and mid[1] == 0 and mid[2] == 2, str(mid))
	var t := 0.0
	while not K.wave.is_empty() and t < 2.0:
		m.step(DT)
		t += DT
	step(m, 0.1)
	ok("cancel X wave + E, RMB, LMB: each waits and goes on landing (spin, potion, a fresh first thrust)",
		K.spin_t >= 0.0 and K.flying.size() == 1 and K.combo_n == 1, "spin %.2f potions %d thrust %d" % [
		K.spin_t, K.flying.size(), K.combo_n])
	ok("cancel X wave + Shift: dropped (no charge spent, no swim after the landing)", P.dashes == d0
		and K.swim_t <= 0.0 and float(mid[3]) == d0)
	K.drop_holds()

## A stun stops the presses (ArchKit.busy) but not a spin already going; a Boki merge drops it with no spout.
func _cc_cancels() -> void:
	_reset(1.6)
	_press("sig")
	step(m, 0.3)
	P.stun_t = 0.6
	var d0 := dmg(T)
	step(m, 0.55)
	ok("cancel E spin + stunned: the spin goes on and keeps hitting (finding F5)", K.spin_t >= 0.0 and dmg(T) > d0,
		"%.1f" % (dmg(T) - d0))
	K.drop_holds()
	step(m, 1.8)
	ok("cancel E spin + Boki merge (drop_holds): it ends, no spout", K.spin_t < 0.0 and K.spouts.is_empty(),
		"spin %.2f spouts %d" % [K.spin_t, K.spouts.size()])

# ------------------------------------------------------------------ gil.md: the Riptide recast window
func _recast() -> void:
	_reset(7.0)
	_press("sig")
	var w := K.recast_window()
	ok("recast E: the spin opens an E window for RecastCue (slot e, at Gil)", String(w.get("slot", "")) == "e"
		and float(w.get("left", 0.0)) > 1.9)
	ok("recast E: the window's total is its time left, the ring never empties (finding F1)",
		is_equal_approx(float(w.get("total", 0.0)), float(w.get("left", -1.0))) and not bool(w.get("auto", true)))
	_press("sig")
	ok("recast E: a press in the first 0.12 s is eaten, not buffered (finding F2)", K.spin_t >= 0.0
		and K.spouts.is_empty() and K.recast_buf.is_empty())
	step(m, 0.2)
	_press("sig")
	ok("recast E: from 0.12 s a press sends the spout and closes the window", not K.spouts.is_empty()
		and K.recast_window().is_empty() and float(K.cd["e"]) > 11.0)
	_reset(7.0)
	_press("sig")
	step(m, 2.1)
	ok("recast E: left alone the spout goes at 2 s, and the cue reads it as EXPIRED (finding F1)",
		(not K.spouts.is_empty() or dmg(T) > 0.0) and String(K.cue.get("exp_slot", "")) == "e")
	_reset(6.0)
	HunterKeys.ult_pressed(P)
	m.step(DT)
	ok("recast X: Tidal Wave opens no recast window", not K.wave.is_empty() and K.recast_window().is_empty())
	K.drop_holds()

# ------------------------------------------------------------------ gil.md: the Relic screen clips
func _clips() -> void:
	var want := {"lmb": "swing", "rmb": "bolt", "e": "nova", "dash": "dash", "x": "strike"}
	var got := {}
	var lines_ok := true
	var moves := 0
	for s in want:
		got[s] = AbilityClip.fx_for("gil", s)
		lines_ok = lines_ok and AbilityClip.line_for("gil", s) == String(K.d["clip"]["lines"][s])
		moves += HunterViewer.moves_for("gil", s).size()
	ok("clips: effects swing / bolt / nova / dash / strike (from the deliveries, no clip.fx)", got == want, str(got))
	ok("clips: each line is gil.json clip.lines", lines_ok)
	ok("clips: no kit moves under them (Gil has no keyed moves yet)", moves == 0, "%d" % moves)
	K.bag.append("fire")
	ok("colour: the RMB slot wears the next potion's colour, not Gil's blue (finding F3)",
		K.slot_info("sec")["col"] == Color("#ff5a3a"))
