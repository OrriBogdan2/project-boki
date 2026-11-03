extends RefCounted
## --ashwick-combo-check: Linwick's (id ashwick) abilities and their interactions in the archetype check's
## flat strip (docs/heroes/ashwick.md, combinations and small-mechanics tables): the Torch Lance hose (pilot,
## full reach past the cursor, lag on a sweep, narrow then billowing, +25% on a burning foe, stops at once,
## the 0.35s relight gap), the burn stages and their pips, the Cinder Shot lane and cursor landing, the
## Soot Ram stopping on the first foe, two quick charges and a knock's single charge back, the rank-3 stoke,
## the Furnace Cloak's 0.2s ring before the blast and its swirling shield, walls, Char rules, the merge drops,
## and the X ult, Flue Flight (tools/ashwick_ult_check.gd).

var main: Node
var fails := 0
var n := 0
var ak = null

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	print("ASHCHECK %-60s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	await _all()
	await _growth()
	await load("res://tools/ashwick_ult_check.gd").new(ak, ok).run()
	print("ASHCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Soot Ram's hit on the first foe with the hunter at level `lvl`.
func _ram(lvl: int) -> float:
	var r: Array = ak.setup("ashwick", 4.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: AshwickKit = P.ak
	P.lvl = lvl
	LevelGrowth.apply(P)      # (a level set straight on a hunter grows nothing on its own)
	ak.fresh(T)
	K.bash = {"dir": Vector2(1, 0), "start": P.pos}
	K._bash_impact(T)
	var d: float = ak.dmg(T)
	await ak.done(m)
	return d

## Ability damage reads ArchKit.power(), so quiet level growth (LevelGrowth.ap) raises it.
func _growth() -> void:
	var d1: float = await _ram(1)
	var d10: float = await _ram(10)
	ok(
		"growth: the Soot Ram's hit grows with level (LevelGrowth.ap 1.0 -> %.2f)" % (1.0 + LevelGrowth.ap_pct(10)),
		d1 > 4.0 and absf(d10 / d1 - (1.0 + LevelGrowth.ap_pct(10))) < 0.01, "L1 %.2f L10 %.2f" % [d1, d10]
	)

func _all() -> void:
	var r: Array = ak.setup("ashwick", 4.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: AshwickKit = P.ak
	var W = m.world
	var hx := int(floor(home.x))
	var hz := int(floor(home.z))
	var reset := func():
		P.teleport(home)
		P.vel = Vector3.ZERO
		P.hp = P.max_hp
		P.stun_t = 0.0
		P.shield = 0.0
		P.shield_t = 0.0
		for x in [T, T2]:
			ak.fresh(x)
			x.out = false
			x.downed = false
			x.dead = false
			x.burn_t = 0.0
			x.blight_t = 0.0
		T.teleport(home + Vector3(4.0, 0, 0))
		T2.teleport(home + Vector3(5.5, 0, 1.5))
		K.chars = {}
		K.ignites = {}
		K.drags = []
		K.hose.clear()
		K.relight_t = 0.0
		K.cloak_t = 0.0
		K.bash = {}
		K.cd["rmb"] = 0.0
		K.ch_rmb = 1.0
		K.cd["e"] = 0.0
		P.dashes = P.max_dashes()
		P.fire_cd = 0.0
		P.ammo = int(P.wpn["mag"])
		P.reload_t = 0.0
		P.inp["fire"] = false
		P.inp["move"] = Vector2.ZERO
		ak.aim_at(P, T.pos)
		ak.step(m, 0.05)
	var hold_fire := func(secs: float):
		var t := 0.0
		while t < secs:
			P.inp["fire"] = true
			ak.aim_at(P, T.pos)
			m.step(ak.DT)
			t += ak.DT
		P.inp["fire"] = false
		m.step(ak.DT)
	ok(
		"linwick: heavy, Torch Lance, 2 ram charges",
		P.wid == "flamethrower" and P.cls == "heavy" and P.max_dashes() >= 2.0 and Arch.name_of("ashwick") == "Linwick",
		"%s %s %s" % [P.wid, P.cls, Arch.name_of("ashwick")]
	)
	# --- the hose: the pilot first, then a stream that reaches its full length past a close cursor
	reset.call()
	ak.step(m, 0.15, func(): P.inp["fire"] = true; ak.aim_at(P, T.pos))
	ok(
		"lance: the cyan pilot shows, no fire for the first 0.2s",
		K.fx.shown("pilot%d" % P.get_instance_id()) and K.hose.puffs.is_empty() and ak.dmg(T) == 0.0,
		"puffs %d dmg %.1f" % [K.hose.puffs.size(), ak.dmg(T)]
	)
	ak.step(m, 0.6, func(): P.inp["fire"] = true; ak.aim_at(P, home + Vector3(1.5, 0, 0)))
	var reach: float = K.hose.reach_from(P.pos)
	ok(
		"lance: the stream runs its full ~7m past a close cursor", reach >= 6.5 and reach <= 8.8,
		"reach %.1f (cursor 1.5m)" % reach
	)
	var young := 9.0
	var old := 0.0
	for pf in K.hose.puffs:
		var rr := AshwickHose.radius(pf, float(K.lmbd()["w0"]), float(K.lmbd()["w1"]))
		if float(pf["age"]) < 0.035: young = minf(young, rr)
		if float(pf["age"]) > float(pf["life"]) * 0.8: old = maxf(old, rr)
	ok(
		"lance: narrow at the nozzle, billowing at the far end", young < 0.35 and old > 0.85,
		"near r %.2f far r %.2f" % [young, old]
	)
	# hose lag: swing the aim 90 degrees; the old fire keeps flying the old way for a moment
	ak.step(m, 0.1, func(): P.inp["fire"] = true; ak.aim_at(P, home + Vector3(0, 0, -6.0)))
	var east := 0
	var north := 0
	for pf in K.hose.puffs:
		var dp: Vector3 = (pf["p"] as Vector3) - P.pos
		if dp.x > 2.5: east += 1
		if dp.z < -1.0: north += 1
	ok(
		"lance: a sweep bends the stream (old fire keeps its own heading)", east >= 3 and north >= 1,
		"still east %d, new north %d" % [east, north]
	)
	P.inp["fire"] = false
	ak.step(m, 0.15)
	var live := 0
	for pf in K.hose.puffs:
		if not pf.get("dead", false): live += 1
	ok(
		"lance: letting go stops the fire at once",
		live == 0 and K.hose.puffs.size() <= 3 and K.after_t > 0.0 and K.move_k() < 1.0,
		"live %d left %d" % [live, K.hose.puffs.size()]
	)
	var em0: int = K.hose.emitted
	ak.step(m, 0.2, func(): P.inp["fire"] = true; ak.aim_at(P, T.pos))
	ok(
		"lance: 0.35s before it can roar again", K.hose.emitted == em0 and not K.was_held,
		"emitted +%d" % (K.hose.emitted - em0)
	)
	P.inp["fire"] = false
	# --- Char builds into Ablaze, then Flashover
	reset.call()
	var aim_t := func(): P.inp["fire"] = true
	ak.aim_at(P, T.pos)
	ak.step(m, 0.8, aim_t)
	var c1: float = K.char_of(T)
	ok(
		"lance: hold = damage and Char building", ak.dmg(T) > 5.0 and c1 > 5.0 and K.burning(T) == 0,
		"dmg %.1f char %.1f" % [ak.dmg(T), c1]
	)
	ak.step(m, 0.8, aim_t)
	ok(
		"lance: ~1s on the foe = Ablaze (level 1)", K.burning(T) == 1 and T.burn_t > 0.0 and K.ignitions >= 1,
		"burning %d burn_t %.1f ignitions %d" % [K.burning(T), T.burn_t, K.ignitions]
	)
	ak.step(m, 0.02)
	ok("burn stage: one flame pip over a foe Ablaze", K.pips_on(T) == 1, "pips %d" % K.pips_on(T))
	ak.step(m, 2.6, aim_t)
	ok(
		"lance: kept on a burning foe it Flashes over (level 2)", K.burning(T) == 2 and K.upgrades >= 1,
		"burning %d ammo %d upgrades %d char %.1f" % [K.burning(T), P.ammo, K.upgrades, K.char_of(T)]
	)
	ak.step(m, 0.02)
	ok(
		"burn stage: three flame pips and a glow over a Flashover",
		K.pips_on(T) == 3 and K.fx.shown("pipg%d" % T.get_instance_id()), "pips %d" % K.pips_on(T)
	)
	# +25% on a burning foe (the burn's own ticks held off so only the hose counts)
	reset.call()
	ak.step(m, 0.8, func(): P.inp["fire"] = true; ak.aim_at(P, T.pos); K.chars = {})
	var d0: float = ak.dmg(T)
	var t0: int = K.flame_ticks
	ak.step(m, 1.0, func(): P.inp["fire"] = true; ak.aim_at(P, T.pos); K.chars = {}; T.burn_t = 0.0)
	var cold: float = (ak.dmg(T) - d0) / maxf(1.0, K.flame_ticks - t0)
	K.ignites[T.get_instance_id()] = {"e": T, "lvl": 1, "until": m.time + 99.0}
	d0 = ak.dmg(T)
	t0 = K.flame_ticks
	ak.step(m, 1.0, func(): P.inp["fire"] = true; ak.aim_at(P, T.pos); K.chars = {}; T.burn_t = 0.0)
	var hot: float = (ak.dmg(T) - d0) / maxf(1.0, K.flame_ticks - t0)
	ok(
		"lance: +25% on a burning foe (per tick)", cold > 1.5 and hot > cold * 1.15 and hot < cold * 1.4,
		"cold %.1f burning %.1f" % [cold, hot]
	)
	P.inp["fire"] = false
	# --- walls stop the lance and the cloak
	reset.call()
	for dz in range(-6, 7):
		W.level[W.idx(hx + 2, hz + dz)] = lv + 4
	hold_fire.call(1.0)
	ok(
		"wall: the lance does not burn through a wall", ak.dmg(T) < 1.0 and K.char_of(T) == 0.0,
		"dmg %.1f char %.1f" % [ak.dmg(T), K.char_of(T)]
	)
	K.cast_e()
	ak.step(m, 0.8)
	ok(
		"wall: the cloak does not reach behind a wall",
		ak.dmg(T) < 1.0 and K.char_of(T) == 0.0 and P.flat_dist(T) > 3.5,
		"dmg %.1f char %.1f dist %.1f" % [ak.dmg(T), K.char_of(T), P.flat_dist(T)]
	)
	for dz in range(-6, 7):
		W.level[W.idx(hx + 2, hz + dz)] = lv
	# --- Cinder Shot: hold shows the lane to the cursor, release fires; it lands at the cursor
	reset.call()
	T.teleport(home + Vector3(0, 0, 9.0))
	T2.teleport(home + Vector3(0, 0, -9.0))
	ak.aim_at(P, home + Vector3(8.0, 0, 0))
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	ak.step(m, 0.3, func(): P.inp["sec_hold"] = true; ak.aim_at(P, home + Vector3(8.0, 0, 0)))
	var lane: Dictionary = AimKit.entry(P, "rmb")
	ok(
		"cinder: holding shows the aim lane out to the cursor",
		not lane.is_empty() and absf(float(lane.get("len", 0.0)) - 8.0) < 0.6 and K.aiming and K.anim_id == "as_aim",
		"lane %s len %.1f" % [not lane.is_empty(), float(lane.get("len", 0.0))]
	)
	P.inp["sec_hold"] = false
	ak.step(m, 0.7)
	var e1: Array = K.bolt_ends[-1] if not K.bolt_ends.is_empty() else [Vector3.ZERO, false]
	ok(
		"cinder: a miss lands at the cursor and fizzles there",
		bool(e1[1]) and absf((e1[0] as Vector3).x - home.x - 8.0) < 0.9 and K.fizzles >= 1 and not AimKit.shown(
			P, "rmb"
		),
		"end x %.1f expired %s" % [(e1[0] as Vector3).x - home.x, e1[1]]
	)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	ak.aim_at(P, home + Vector3(25.0, 0, 0))
	ak.tap(m, P)
	ak.step(m, 0.25, func(): ak.aim_at(P, home + Vector3(25.0, 0, 0)))
	ak.step(m, 0.8)
	var e2: Array = K.bolt_ends[-1] if not K.bolt_ends.is_empty() else [Vector3.ZERO, false]
	ok(
		"cinder: a far cursor caps it at 14m", absf((e2[0] as Vector3).x - home.x - 14.0) < 1.2,
		"end x %.1f" % ((e2[0] as Vector3).x - home.x)
	)
	reset.call()
	ak.tap(m, P)
	ak.step(m, 0.8)
	ok(
		"cinder: a hit sets the foe Ablaze", K.burning(T) == 1 and ak.dmg(T) >= 10.0,
		"burning %d took %.0f" % [K.burning(T), ak.dmg(T)]
	)
	ak.step(m, 7.0)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	K.stoke(T)
	var sp0: int = K.spreads
	ak.aim_at(P, T.pos)
	ak.tap(m, P)
	ak.step(m, 0.8)
	ok(
		"combo: lance burn > Cinder Shot = upgrade + spread",
		K.burning(T) == 2 and K.burning(T2) >= 1 and K.spreads == sp0 + 1, "T %d T2 %d" % [K.burning(T), K.burning(T2)]
	)
	# --- Soot Ram: toward the cursor, stops on the first foe with the impact
	reset.call()
	T.teleport(home + Vector3(3.0, 0, 0))
	T2.teleport(home + Vector3(5.5, 0, 0))
	ak.aim_at(P, T.pos)
	P.ak.on_dash(false)
	var skull := false
	var tt := 0.0
	while tt < 0.5:
		ak.step(m, ak.DT)
		tt += ak.DT
		if K.fx.shown("skull%d" % P.get_instance_id()): skull = true
	ok("ram: the flame skull wraps his front while it flies", skull)
	ok(
		"ram: stops on the first foe (doesn't pass through)",
		K.bash_hits == 1 and P.pos.x < T.pos.x and P.flat_dist(T) < 2.2 and ak.dmg(T2) < 1.0,
		"x %.1f foe x %.1f dist %.1f" % [P.pos.x - home.x, T.pos.x - home.x, P.flat_dist(T)]
	)
	ok(
		"ram: impact damage and 17 Char", ak.dmg(T) >= 12.0 and K.char_of(T) >= 15.0,
		"dmg %.0f char %.1f" % [ak.dmg(T), K.char_of(T)]
	)
	reset.call()
	T.teleport(home + Vector3(0, 0, 9.0))
	T2.teleport(home + Vector3(0, 0, -9.0))
	ak.aim_at(P, home + Vector3(8.0, 0, 0))
	P.ak.on_dash(false)
	var feel: Dictionary = K.dash_feel()
	var ram_d: float = float(K.dash_def()["dist"]) * float(feel["dist"])
	var ram_t: float = float(K.dash_def()["time"]) * float(feel["time"])
	ak.step(m, ram_t * 0.3)
	var d_front := P.pos.x - home.x
	ak.step(m, ram_t * 0.7 + 0.05)
	var d1 := P.pos.x - home.x
	ok(
		"ram: quick and short, front-loaded (over 37% of it in the first 30%)",
		d_front > ram_d * 0.37 and absf(d1 - ram_d) < 0.5 and ram_t < 0.4,
		"after %.2fs %.2f, at the end %.2f of %.2f" % [ram_t * 0.3, d_front, d1, ram_d]
	)
	P.ak.on_dash(false)
	ak.step(m, 0.45)
	ok(
		"ram: toward the cursor, two charges chain",
		P.pos.x - home.x > d1 + ram_d * 0.8 and P.dashes < 0.5,
		"first %.1f both %.1f charges %.2f" % [d1, P.pos.x - home.x, P.dashes]
	)
	# the air poof: long and fast, and he keeps a share of the speed after it
	reset.call()
	T.teleport(home + Vector3(0, 0, 9.0))
	T2.teleport(home + Vector3(0, 0, -9.0))
	P.teleport(home + Vector3(0, 4.0, 0))
	P.grounded = false
	P.vel = Vector3.ZERO
	P.ex_cd = 0.0
	ak.aim_at(P, home + Vector3(12.0, 0, 0))
	P.ak.on_dash(true)
	var poof_t: float = float(K.dash_def()["air_time"]) * float(feel["time"])
	ak.step(m, poof_t + 0.06)
	var poof_d := P.pos.x - home.x
	var kept := Vector2(P.vel.x, P.vel.z).length()
	ok(
		"air poof: launches him far and fast (over twice the ground dash), momentum kept after it",
		poof_d > ram_d * 2.0 and poof_t < 0.35 and kept > 8.0,
		"poof %.1f m in %.2fs, ground %.1f, speed kept %.1f m/s" % [poof_d, poof_t, ram_d, kept]
	)
	P.dashes = 0.0
	K.on_knock(T, true)
	ok("passive: a knock gives back one ram charge, not both", absf(P.dashes - 1.0) < 0.01, "charges %.2f" % P.dashes)
	# --- rank 3: stokes at once (the lava carpet is the X ult now, not the ram)
	reset.call()
	P.slot_lv["dash"] = 3
	T.teleport(home + Vector3(4.2, 0, 0))
	ak.aim_at(P, T.pos)
	P.ak.on_dash(false)
	ak.step(m, 0.6)
	ok(
		"ram rank 3: stokes at once, and lays no carpet", K.burning(T) >= 1 and K.jet.trail.is_empty(),
		"burning %d" % K.burning(T)
	)
	P.slot_lv["dash"] = 1
	# --- Furnace Cloak: a 0.2s ring first, then the blast
	reset.call()
	T.teleport(home + Vector3(3.8, 0, 0))
	var bl0: int = K.blasts
	P.ak.use_e()
	ak.step(m, 0.1)
	ok(
		"cloak: the edge ring shows for 0.2s before the blast",
		AimKit.shown(P, "e_ring") and K.blasts == bl0 and ak.dmg(T) == 0.0 and float(AimKit.entry(P, "e_ring").get("r", 0.0)) > 4.0,
		"blasts %d" % K.blasts
	)
	ak.step(m, 0.7)
	ok(
		"cloak: damage, Char, Anti-Heal and a shield",
		K.blasts == bl0 + 1 and ak.dmg(T) >= 6.0 and K.char_of(T) >= 15.0 and T.blight_t > 0.0 and P.shield > 5.0,
		"dmg %.0f char %.0f blight %.1f shield %.1f" % [ak.dmg(T), K.char_of(T), T.blight_t, P.shield]
	)
	ok(
		"cloak: foes in sight are dragged toward you", P.flat_dist(T) < 2.6 and K.pulled >= 1,
		"dist %.1f" % P.flat_dist(T)
	)
	ok("cloak: the swirling fire shield shows while it holds", K.fx.shown("swirl%d" % P.get_instance_id()))
	K.cd["e"] = 8.0
	P.hp = P.max_hp * 0.5
	K.on_knock(T, true)
	ok(
		"passive: a knock resets the cloak and heals",
		float(K.cd["e"]) <= 0.0 and K.resets >= 1 and P.hp > P.max_hp * 0.6,
		"cd %.1f hp %.0f" % [float(K.cd["e"]), P.hp]
	)
	# --- rank 3 refunds when the ability stokes
	reset.call()
	P.slot_lv["kin"] = 3
	P.slot_lv["sec"] = 3
	K.stoke(T)
	K.cd["e"] = 10.0
	K.add_char(T, 20.0)
	K._refund("e")
	ok(
		"rank 3: stoking refunds a quarter of the cooldown", float(K.cd["e"]) < 8.0 and K.refunds >= 1,
		"cd %.1f" % float(K.cd["e"])
	)
	P.slot_lv["kin"] = 1
	P.slot_lv["sec"] = 1
	reset.call()
	K.add_char(T, 100.0)
	ok("passive: Char past 31 is discarded (burn, then 0)", K.burning(T) == 1 and K.char_of(T) == 0.0)
	K.add_char(T2, 10.0)
	ak.step(m, 5.4)
	ok(
		"passive: Char falls off all at once after 5s", K.char_of(T2) == 0.0 and K.burning(T) == 0,
		"char %.1f" % K.char_of(T2)
	)
	# --- a Boki merge drops every hold: the hose, the cloak's ring
	reset.call()
	ak.step(m, 0.8, func(): P.inp["fire"] = true; ak.aim_at(P, T.pos))
	ok(
		"merge hold: the lance is roaring before the merge",
		K.was_held and not K.hose.puffs.is_empty() and P.mel_hold > 0.0, "puffs %d" % K.hose.puffs.size()
	)
	ok("merge hold: a merge is under way", ak.merge_now(P))
	ak.step(m, 0.1)
	var ft: int = K.flame_ticks
	var ammo: int = P.ammo
	ak.step(m, 1.0, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	ak.step(m, 0.3)
	ok(
		"merge hold: linwick's lance is dropped, no fire mid-merge",
		not K.was_held and K.spool == 0.0 and K.hose.puffs.is_empty() and K.flame_ticks == ft and P.ammo >= ammo and P.mel_hold == 0.0,
		"held %s puffs %d ticks +%d" % [K.was_held, K.hose.puffs.size(), K.flame_ticks - ft]
	)
	KinMerge.end(P, "test")
	P.merge_cd = 0.0
	reset.call()
	T.teleport(home + Vector3(3.0, 0, 0))
	P.ak.use_e()
	ak.step(m, 0.05)
	var b0: int = K.blasts
	ok("merge hold: the cloak's ring is up before the merge", K.cloak_t > 0.0)
	ok("merge hold: a merge is under way", ak.merge_now(P))
	ak.step(m, 0.5)
	ok(
		"merge hold: linwick's cloak never goes off mid-merge", K.cloak_t <= 0.0 and K.blasts == b0,
		"blasts +%d" % (K.blasts - b0)
	)
	m.queue_free()
	await main.get_tree().process_frame
