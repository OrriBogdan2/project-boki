extends "res://tools/hero_pair_check.gd"
## --gil-kit-check: Gil, the Novice Mage (content/archetypes/gil.json, scripts/arch/kits/gil_kit.gd), on a training
## dummy through the real match code: the Fencer chain (steps, third-hit slow), the Grab Bag (the shuffled bag, each
## vial's effect, hold range, the air drop), Fish Out of Water (three marks Beach), Ground Swim (hittable, surfacing
## knocks up), Riptide (spin damage, the spout's knockup, longer spin = wider spout) and Tidal Wave (untargetable,
## knockup then slow, lands with a shield).

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
	_tide()
	_vials()
	_hold_and_air()
	_beach()
	_swim()
	_riptide()
	_wave()
	await done(m)
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
	K.tide = {}
	K.combo_n = 0
	P.teleport(home)
	P.vel = Vector3.ZERO
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
	var top := {"n": 0, "slow": 0.0, "t": 0.0, "pose": false}
	var thrusts := int(HeroVfx.of(m).plays.get("thrust", 0))
	step(m, 1.1, func():
		top["t"] += DT
		P.inp["fire"] = fmod(top["t"], 0.12) < 0.05      # clicking (holding is the Tide Lunge)
		top["pose"] = top["pose"] or K.anim_id == "gil_thrust_1"
		top["slow"] = maxf(top["slow"], T.slow_t)
		top["n"] = K.combo_n)
	P.inp["fire"] = false
	ok("Fencer: a thrust plays its own thrust pose and look (no slash arc)",
		top["pose"] and int(HeroVfx.of(m).plays.get("thrust", 0)) > thrusts)
	ok("Fencer: a three-hit chain lands on the dummy", int(top["n"]) >= 3 and dmg(T) >= 20.0,
		"swings %d dmg %.1f" % [top["n"], dmg(T)])
	ok("Fencer: each swing steps him forward", P.pos.x - x0 > 0.8, "moved %.2f" % (P.pos.x - x0))
	ok("Fencer: the third, longer thrust slows (30% for 0.5 s)", top["slow"] > 0.2 and top["slow"] <= 0.55,
		"slow_t %.2f" % top["slow"])

## Held LMB: the Tide Lunge. A short click is one thrust; held, he slows and draws back, and on release drives
## down the line hitting everyone on it; a full charge soaks them (a splash mark toward Beached).
func _tide() -> void:
	_reset(3.0)
	P.inp["fire"] = true
	step(m, 0.1)
	P.inp["fire"] = false
	step(m, 0.4)
	ok("Tide Lunge: a click is one thrust, no lunge", K.combo_n == 1 and K.lmb_t < 0.0 and K.tide.is_empty(),
		"thrusts %d" % K.combo_n)
	_reset(4.0)
	var x0 := P.pos.x
	P.inp["fire"] = true
	step(m, 1.2, func(): P.inp["fire"] = true)
	ok("Tide Lunge: held, he charges it (slowed, drawn back), full by 0.8 s",
		K.lmb_t >= 0.0 and K.tide_k() >= 1.0 and K.move_k() < 1.0 and K.anim_id == "gil_tide_wind",
		"k %.2f anim %s" % [K.tide_k(), K.anim_id])
	var before := dmg(T)
	P.inp["fire"] = false
	step(m, 0.5)
	var td: Dictionary = K.lmb_def()["tide"]
	ok("Tide Lunge: let go, he drives about 5 m down the line", P.pos.x - x0 > 4.0 and P.pos.x - x0 < 7.5,
		"%.2f m" % (P.pos.x - x0))
	ok("Tide Lunge: full charge hits the foe on the line for 22", dmg(T) - before >= float(td["dmg"][1]) * 0.9,
		"%.1f" % (dmg(T) - before))
	ok("Tide Lunge: full charge soaks (one splash mark)", K.marks_on(T) == 1, "%d" % K.marks_on(T))
	ok("Tide Lunge: the release plays its pose and look",
		int(HeroVfx.of(m).plays.get("tide_lunge", 0)) > 0 and int(HeroVfx.of(m).plays.get("tide_hit", 0)) > 0)

func _vials() -> void:
	var want := {"thunder": "stun", "slime": "slow", "fire": "burn", "zeep": "lift"}
	for v in ["thunder", "slime", "air", "fire", "zeep"]:
		_reset(6.0)
		K.bag.append(v)
		var x0 := T.pos.x
		var looks := int(HeroVfx.of(m).plays.get("shatter_" + v, 0))
		tap(m, P)
		var thrown := K.anim_id == "gil_throw"
		var top := _land()
		var hit := dmg(T) > 0.0
		ok("%s: the toss pose, and the bottle breaks in its own look" % v,
			thrown and int(HeroVfx.of(m).plays.get("shatter_" + v, 0)) == looks + 1)
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
	var dives := int(HeroVfx.of(m).plays.get("dive", 0))
	K.on_dash(false)
	m.step(DT)
	var under := K.swim_t > 0.0
	var hit_on := float(K.incoming(T, 10.0, {})[0]) == 10.0
	ok("Ground Swim: the dive and its wake play, no shared dash pill over the ground",
		int(HeroVfx.of(m).plays.get("dive", 0)) == dives + 1 and K.own_dash_trail())
	step(m, 0.15)
	# owner 11-11: the swim didn't take him under. Mid-swim the dive pose has the whole body (hat and all,
	# plate_offset up from the feet) below the surface.
	var age := m.time - K.anim_at
	var lift := float(HunterAnim.km_sample(K.anim_id, age).get("lift", 0.0))
	ok("Ground Swim: mid-swim his whole body is under the ground",
		K.anim_id == "gil_dive" and lift + float(K.d["plate_offset"]) < 0.0, "%s lift %.2f" % [K.anim_id, lift])
	var top := {"stun": 0.0, "y": 0.0, "out": false}
	var y0 := T.pos.y
	step(m, 0.8, func():
		top["out"] = top["out"] or K.anim_id == "gil_surface"
		top["stun"] = maxf(top["stun"], T.stun_t)
		top["y"] = maxf(top["y"], T.pos.y - y0))
	ok("Ground Swim: swims about 6 m", P.pos.x - x0 > 4.0 and P.pos.x - x0 < 7.5, "%.2f m" % (P.pos.x - x0))
	ok("Ground Swim: he bursts back out (gil_surface) and nothing holds him under after",
		top["out"] and K.anim_id != "gil_dive" and int(HeroVfx.of(m).plays.get("surface", 0)) > 0)
	ok("Ground Swim: he stays hittable underground", under and hit_on)
	ok("Ground Swim: surfacing knocks nearby foes up 0.5 s", top["stun"] >= 0.4 and top["y"] > 0.2,
		"stun %.2f lift %.2f" % [top["stun"], top["y"]])
	ok("Ground Swim: 8 s cooldown", float(K.dash_def()["cd"]) == 8.0)

func _riptide() -> void:
	_reset(1.6)
	K.use_e()
	ok("Riptide: E starts the spin (the spin pose)", K.spin_t >= 0.0 and K.anim_id == "gil_spin")
	step(m, 1.0)
	var spin_dmg := dmg(T)
	ok("Riptide: the spin hurts foes around him", spin_dmg > 0.0, "%.1f" % spin_dmg)
	_reset(7.0)
	K.use_e()
	step(m, 0.3)
	K.e_recast()
	ok("Riptide recast: the spin stops on the spout thrust, the spout's look plays",
		K.anim_id == "gil_spout" and int(HeroVfx.of(m).plays.get("spout", 0)) > 0)
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
	ok("Tidal Wave: Gil is untargetable while he surfs (the surf pose, the wave's look)",
		K.untarget_t > 0.0 and float(K.incoming(T, 50.0, {})[0]) == 0.0 and K.anim_id == "gil_surf"
		and int(HeroVfx.of(m).plays.get("wave", 0)) > 0)
	var top := {"stun": 0.0, "slow": 0.0, "k": 0.0}
	step(m, 1.2, func():
		top["stun"] = maxf(top["stun"], T.stun_t)
		top["slow"] = maxf(top["slow"], T.slow_t)
		top["k"] = maxf(top["k"], T.slow_k))
	ok("Tidal Wave: knocks up 1 s, then slows 50% for 2 s",
		top["stun"] >= 0.9 and top["slow"] >= 2.5 and absf(top["k"] - 0.5) < 0.05,
		"stun %.2f slow %.2f k %.2f" % [top["stun"], top["slow"], top["k"]])
	ok("Tidal Wave: lands with a shield and is hittable again",
		K.anim_id != "gil_surf" and int(HeroVfx.of(m).plays.get("wave_land", 0)) > 0
		and P.shield > 0.0 and K.untarget_t <= 0.0 and float(K.incoming(T, 10.0, {})[0]) == 10.0,
		"shield %.1f" % P.shield)
	ok("Tidal Wave: 90 s cooldown after the cast", float(K.cd["x"]) > 85.0, "%.1f" % float(K.cd["x"]))
	_wave_way(Vector2(-1, 0))
	_wave_way(Vector2(0, 1))

## Owner 11-11: the ult pushed him the wrong way. Cast while running another way (back, or sideways), he surfs the
## wave's own line toward the cursor, the whole 14 m, and stays on it.
func _wave_way(run: Vector2) -> void:
	_reset(6.0)
	P.lvl = 6
	K.cd["x"] = 0.0
	P.inp["move"] = run
	var p0 := P.pos
	var aim := P.aim_dir()
	K.cast_ult()
	step(m, 1.1, func(): P.inp["move"] = run)
	P.inp["move"] = Vector2.ZERO
	var moved := P.pos - p0
	var along := Vector2(moved.x, moved.z).dot(aim)
	var off := absf(Vector2(moved.x, moved.z).cross(aim))
	ok("Tidal Wave: running %s, he surfs toward the cursor" % str(run), along > 10.0 and off < 1.0,
		"along %.2f off-line %.2f" % [along, off])
	ok("Tidal Wave: he rides with the crest (within 2 m of it at the end)",
		absf(along - float(K.x_def()["range"])) < 2.0, "along %.2f" % along)
