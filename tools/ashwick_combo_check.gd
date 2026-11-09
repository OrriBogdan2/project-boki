extends RefCounted
## --ashwick-combo-check: Cinder's (id ashwick) abilities and their interactions in the archetype check's
## flat strip (docs/heroes/ashwick.md, combinations and small-mechanics tables): the Torch Lance hose (pilot,
## full reach past the cursor, lag on a sweep, narrow then billowing, the burning-foe bonus and health chip,
## stops at once,
## the 0.35s relight gap), the burn stages and their pips, the Cinder Shot lane and its fixed full range, the
## Soot Ram stopping on the first foe, two quick charges and a knock's single charge back, the rank-3 speed and shield,
## the Furnace Cloak on the press round him (no cursor) and its swirling shield, walls, Char rules, the merge drops,
## and the X ult, Flue Flight (tools/ashwick_ult_check.gd).

const CARE := preload("res://tools/care_combo_check.gd")      # the shared dash-move rules (own ids, tail)

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
	await _lance_combos()
	await _growth()
	await load("res://tools/ashwick_ult_check.gd").new(ak, ok).run()
	var rows_bad: int = await load("res://tools/dash_flow_check.gd").new().check_hero(main, "ashwick")
	ok("item 51: every slot casts mid-jump, holds through moves, a jump or Shift moves him out of it in 0.1s",
			rows_bad == 0, "%d failures" % rows_bad)
	print("ASHCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Item 51: the lance held through a ram goes out and roars again the step it ends (no pilot, no relight gap), and
## keeps burning through a jump.
func _lance_combos() -> void:
	var r: Array = ak.setup("ashwick", 4.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: AshwickKit = P.ak
	T.teleport(T.pos + Vector3(0, 0, 6.0))      # (off the ram's line: it would stop on him)
	var keep_fire := func():
		P.inp["fire"] = true
		ak.aim_at(P, T.pos)
	ak.step(m, 0.4, keep_fire)
	P.dashes = P.max_dashes()
	P.do_dash()
	ak.step(m, 0.05, keep_fire)
	var em1: int = K.hose.emitted
	var out_t := 0.0
	while P.roll_t > 0.0 and out_t < 1.0:
		keep_fire.call()
		m.step(ak.DT)
		out_t += ak.DT
	var dark: bool = K.hose.emitted == em1 and K.was_held
	ak.step(m, 0.1, keep_fire)
	ok(
		"lance: held through a ram it goes out, then roars again within 0.1s of its end (item 51)",
		dark and K.hose.emitted > em1 and K.anim_id == "as_lance", "dark %s emitted +%d" % [dark, K.hose.emitted - em1]
	)
	ak.step(m, 0.3, keep_fire)
	var y0 := P.pos.y
	P.do_jump()
	var em2: int = K.hose.emitted
	ak.step(m, 0.2, keep_fire)
	var high := P.pos.y - y0
	ok("lance: it keeps burning through a jump", K.hose.emitted > em2 + 4 and high > 0.3,
			"emitted +%d, %.2f m up" % [K.hose.emitted - em2, high])
	P.inp["fire"] = false
	# audit: no fuel (the data's Flamethrower is a plain hold) and no slow while it roars (only the 0.35 s after)
	ak.step(m, 1.0)
	var em3: int = K.hose.emitted
	var slowest := 9.0
	var reloaded := false
	var tf := 0.0
	while tf < 10.0:
		keep_fire.call()
		m.step(ak.DT)
		tf += ak.DT
		if tf > 0.5: slowest = minf(slowest, K.move_k())
		reloaded = reloaded or P.reload_t > 0.0
	var late: int = K.hose.emitted
	m.step(ak.DT)
	ok("lance audit: 10 s of roaring with no fuel to run out (no refill), at his full walk",
			not reloaded and K.hose.emitted > late and late - em3 > 250 and slowest >= 0.999,
			"puffs %d, reload %s, move_k %.2f" % [late - em3, reloaded, slowest])
	P.inp["fire"] = false
	await ak.done(m)

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

## Owner item 35: the ram and the poof play his own moves (no shared charge pose under them), each covering its
## dash and settling soon after, no other kit plays them, and neither leaves a ring.
func _dash_moves(K: AshwickKit, ram_move: String, ram_t: float, poof_move: String, poof_t: float, rings: int) -> void:
	ok(
		"dash moves: the ram and the poof play his own moves, no shared pose under them",
		ram_move == "as_leap" and poof_move == "lw_hop" and K.dodge_anim() == "kit", "%s / %s" % [ram_move, poof_move]
	)
	var ram_n := _move_len("as_leap")
	var poof_n := _move_len("lw_hop")
	ok(
		"dash moves: each covers its dash and settles soon after",
		_fits(ram_n, ram_t) and _fits(poof_n, poof_t),
		"ram %.2f/%.2f poof %.2f/%.2f" % [ram_n, ram_t, poof_n, poof_t]
	)
	ok("dash moves: no other kit plays them", CARE.own_moves_only("ashwick_kit.gd", ["as_leap", "lw_hop"]))
	ok("dash moves: no ring on the ram or the poof", rings == 0, "rings %d" % rings)

static func _fits(move_t: float, dash_t: float) -> bool:
	return move_t >= dash_t and move_t <= dash_t + CARE.MOVE_TAIL_MAX

static func _move_len(id: String) -> float:
	return float((KMovesPair.MOVES[id]["keys"] as Array)[-1][0])

## Holds the lance on a target.
func _hold_at(hunter: Hunter, target: Hunter) -> void:
	hunter.inp["fire"] = true
	ak.aim_at(hunter, target.pos)

## Holds the lance with the burn's own ticks and the Char held off, so only the hose counts.
func _hold_bare(hunter: Hunter, target: Hunter) -> void:
	_hold_at(hunter, target)
	target.stacks.erase("char")
	target.burn_t = 0.0

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
		T.stacks.clear()
		T2.stacks.clear()
		m.displace.tows.clear()
		K.hose.clear()
		K.relight_t = 0.0
		K.bash = {}
		K.cd["rmb"] = 0.0
		K.ch_rmb = 1.0
		K.cd["e"] = 0.0
		P.dashes = P.max_dashes()
		P.fire_cd = 0.0
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
		P.wid == "flamethrower" and P.cls == "heavy" and P.max_dashes() >= 2.0
			and Arch.name_of("ashwick") == "The Ashen Kiss",
		"%s %s %s" % [P.wid, P.cls, Arch.name_of("ashwick")]
	)
	# --- no fuel (the source's flamethrower has none, and nothing reloads): held past the old 8s tank, it still roars
	reset.call()
	var roar := {"t": 0.0, "ticks": K.flame_ticks}
	ak.step(m, 9.0, func():
		P.inp["fire"] = true
		ak.aim_at(P, home + Vector3(0, 0, -8.0))      # away from the dummy: its burn stays clean for the next part
		roar["t"] = float(roar["t"]) + ak.DT
		if float(roar["t"]) > 8.5 and float(roar["t"]) - ak.DT <= 8.5:
			roar["ticks"] = K.flame_ticks)
	P.inp["fire"] = false
	ak.step(m, 0.6, func(): ak.aim_at(P, T.pos))      # turned back to the dummy before the next part
	var ft0: int = int(roar["ticks"])
	ok("lance: no fuel or reload, held 9s it still burns (no ammo count)",
			K.flame_ticks > ft0 and P.reload_t == 0.0 and not P.wpn.get("ammo", true), "ticks +%d" % (K.flame_ticks - ft0))
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
		"burning %d upgrades %d char %.1f" % [K.burning(T), K.upgrades, K.char_of(T)]
	)
	ak.step(m, 0.02)
	ok(
		"burn stage: three flame pips and a glow over a Flashover",
		K.pips_on(T) == 3 and K.fx.shown("pipg%d" % T.get_instance_id()), "pips %d" % K.pips_on(T)
	)
	# +25% on a burning foe (the burn's own ticks held off so only the hose counts)
	reset.call()
	ak.step(m, 0.8, func(): P.inp["fire"] = true; ak.aim_at(P, T.pos); T.stacks.erase("char"))
	var d0: float = ak.dmg(T)
	var t0: int = K.flame_ticks
	ak.step(m, 1.0, func(): P.inp["fire"] = true; ak.aim_at(P, T.pos); T.stacks.erase("char"); T.burn_t = 0.0)
	var cold: float = (ak.dmg(T) - d0) / maxf(1.0, K.flame_ticks - t0)
	Stacks.add(T, "ignite", 1.0, 99.0)
	d0 = ak.dmg(T)
	t0 = K.flame_ticks
	ak.step(m, 1.0, func(): P.inp["fire"] = true; ak.aim_at(P, T.pos); T.stacks.erase("char"); T.burn_t = 0.0)
	var hot: float = (ak.dmg(T) - d0) / maxf(1.0, K.flame_ticks - t0)
	var chip := T.max_hp * 0.015 * float(K.lmbd()["tick"])
	ok(
		"lance: +25% and 1.5% of health a second on an Ablaze foe (per tick)",
		cold > 1.5 and absf(hot - (cold * 1.25 + chip)) < cold * 0.12,
		"cold %.2f burning %.2f expect %.2f" % [cold, hot, cold * 1.25 + chip]
	)
	Stacks.add(T, "ignite", 2.0, 99.0)
	d0 = ak.dmg(T)
	t0 = K.flame_ticks
	ak.step(m, 1.0, func(): _hold_bare(P, T))
	var flash: float = (ak.dmg(T) - d0) / maxf(1.0, K.flame_ticks - t0)
	var chip2 := T.max_hp * 0.025 * float(K.lmbd()["tick"])
	ok(
		"lance: +40% and 2.5% of health a second on a Flashed-over foe (per tick)",
		absf(flash - (cold * 1.4 + chip2)) < cold * 0.12, "flash %.2f expect %.2f" % [flash, cold * 1.4 + chip2]
	)
	# a burning foe builds Char as fast as a cold one (the old halving is gone)
	reset.call()
	K.relight_t = 0.0
	ak.step(m, 0.7, func(): _hold_at(P, T))
	var char_cold: float = K.char_of(T)
	P.inp["fire"] = false
	reset.call()
	K.relight_t = 0.0
	Stacks.add(T, "ignite", 1.0, 99.0)
	ak.step(m, 0.7, func(): _hold_at(P, T))
	ok(
		"lance: a burning foe builds Char at the full rate", char_cold > 6.0 and K.char_of(T) >= char_cold * 0.9,
		"cold %.1f burning %.1f" % [char_cold, K.char_of(T)]
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
	# --- Cinder Shot: hold shows the full fixed lane, release fires; it always flies its max range
	reset.call()
	T.teleport(home + Vector3(0, 0, 9.0))
	T2.teleport(home + Vector3(0, 0, -9.0))
	var max_r := float(K.rmb_def()["range"])
	ak.aim_at(P, home + Vector3(2.0, 0, 0))
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	ak.step(m, 0.3, func(): P.inp["sec_hold"] = true; ak.aim_at(P, home + Vector3(2.0, 0, 0)))
	var lane: Dictionary = AimKit.entry(P, "rmb")
	ok(
		"cinder: holding shows the aim lane at its full fixed length (cursor at 2 m)",
		not lane.is_empty() and absf(float(lane.get("len", 0.0)) - max_r) < 0.01 and K.aiming and K.anim_id == "as_aim",
		"lane %s len %.1f" % [not lane.is_empty(), float(lane.get("len", 0.0))]
	)
	P.inp["sec_hold"] = false
	ak.step(m, 1.0)
	var e1: Array = K.bolt_ends[-1] if not K.bolt_ends.is_empty() else [Vector3.ZERO, false]
	var near_d := Vector2((e1[0] as Vector3).x - home.x, (e1[0] as Vector3).z - home.z).length()
	ok(
		"cinder: a miss flies its full length and fizzles at its end",
		bool(e1[1]) and K.fizzles >= 1 and not AimKit.shown(P, "rmb"), "expired %s" % e1[1]
	)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	ak.aim_at(P, home + Vector3(20.0, 0, 0))
	ak.tap(m, P)
	ak.step(m, 0.25, func(): ak.aim_at(P, home + Vector3(20.0, 0, 0)))
	ak.step(m, 0.8)
	var e2: Array = K.bolt_ends[-1] if not K.bolt_ends.is_empty() else [Vector3.ZERO, false]
	var far_d := Vector2((e2[0] as Vector3).x - home.x, (e2[0] as Vector3).z - home.z).length()
	ok(
		"cinder: cursor at 2 m and at 20 m travel the same distance, the max",
		absf(near_d - far_d) < 0.3 and absf(far_d - max_r) < 1.2, "2 m: %.1f, 20 m: %.1f" % [near_d, far_d]
	)
	reset.call()
	ak.tap(m, P)
	ak.step(m, 0.8)
	ok(
		"cinder: a hit sets the foe Ablaze", K.burning(T) == 1 and ak.dmg(T) >= 10.0,
		"burning %d took %.0f" % [K.burning(T), ak.dmg(T)]
	)
	ok(
		"cinder: the hit slows the foe 30%", T.slow_t > 0.5 and absf(T.slow_k - 0.3) < 0.02,
		"slow_t %.2f slow_k %.2f" % [T.slow_t, T.slow_k]
	)
	var cinder_cold: float = ak.dmg(T)
	ak.step(m, 7.0)
	reset.call()
	Stacks.add(T, "ignite", 1.0, 99.0)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	ak.aim_at(P, T.pos)
	ak.tap(m, P)
	ak.step(m, 0.8)
	ok(
		"cinder: 25% more on an Ablaze foe", ak.dmg(T) >= cinder_cold * 1.2,
		"hot %.1f cold %.1f" % [ak.dmg(T), cinder_cold]
	)
	reset.call()
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
		"ram: stops on the first foe and shoves it hard (doesn't pass through)",
		K.bash_hits == 1 and P.pos.x < T.pos.x and P.flat_dist(T) < 4.0 and T.pos.x - home.x > 3.4 and ak.dmg(T2) < 1.0,
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
	var rings := {"made": 0, "seen": m.fx.rings.size()}      # rings spawned (a lambda keeps a dict by reference)
	var count_rings := func():
		rings["made"] = int(rings["made"]) + maxi(0, m.fx.rings.size() - int(rings["seen"]))
		rings["seen"] = m.fx.rings.size()
	P.ak.on_dash(false)
	var ram_move: String = K.anim_id
	var feel: Dictionary = K.dash_feel()
	ok(
		"ram: the source's ~3.4 m in 0.33 s, as it is felt (no global scale on top)",
		absf(P.roll_t - 0.33) < 0.005 and absf(P.roll_speed * P.roll_t - 3.4) < 0.05,
		"%.2f m in %.2fs" % [P.roll_speed * P.roll_t, P.roll_t]
	)
	var ram_d: float = float(K.dash_def()["dist"]) * float(feel["dist"])
	var ram_t: float = float(K.dash_def()["time"]) * float(feel["time"])
	ak.step(m, ram_t * 0.3, count_rings)
	var d_front := P.pos.x - home.x
	ak.step(m, ram_t * 0.7 + 0.05, count_rings)
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
	rings["seen"] = m.fx.rings.size()
	P.ak.on_dash(true)
	ok(
		"air poof: 6.8 m in 0.28 s, scaled once (not twice)",
		absf(P.roll_t - 0.28) < 0.005 and absf(P.roll_speed * P.roll_t - 6.8) < 0.1,
		"%.2f m in %.2fs" % [P.roll_speed * P.roll_t, P.roll_t]
	)
	var poof_move: String = K.anim_id
	var poof_t: float = float(K.dash_def()["air_time"]) * float(feel["time"])
	ak.step(m, poof_t + 0.06, count_rings)
	var poof_d := P.pos.x - home.x
	var kept := Vector2(P.vel.x, P.vel.z).length()
	ok(
		"air poof: launches him far and fast (over twice the ground dash), momentum kept after it",
		poof_d > ram_d * 2.0 and poof_t < 0.35 and kept > 8.0,
		"poof %.1f m in %.2fs, ground %.1f, speed kept %.1f m/s" % [poof_d, poof_t, ram_d, kept]
	)
	_dash_moves(K, ram_move, ram_t, poof_move, poof_t, int(rings["made"]))
	P.dashes = 0.0
	K.on_knock(T, true)
	ok("passive: a knock gives back one ram charge, not both", absf(P.dashes - 1.0) < 0.01, "charges %.2f" % P.dashes)
	# --- rank 3: more damage, a speed boost and a shield on a hit (the lava carpet is the X ult now, not the ram)
	# (the target stands 3.9 m out: Cinder's own hit radius is 0.376 now, so the ram reaches 0.12 m less)
	reset.call()
	T.teleport(home + Vector3(3.9, 0, 0))
	ak.aim_at(P, T.pos)
	P.ak.on_dash(false)
	ak.step(m, 0.6)
	var ram1: float = ak.dmg(T)
	reset.call()
	P.slot_lv["dash"] = 3
	T.teleport(home + Vector3(3.9, 0, 0))
	ak.aim_at(P, T.pos)
	P.ak.on_dash(false)
	ak.step(m, 0.5)
	ok(
		"ram rank 3: +4.3 damage (before the rank's own +30%)", ak.dmg(T) > ram1 * 1.2,
		"rank 1 %.1f rank 3 %.1f" % [ram1, ak.dmg(T)]
	)
	ok(
		"ram rank 3: a hit gives +16% speed and a 11.6% shield, and no instant burn",
		P.shield >= P.max_hp * 0.11 and absf(K.move_k() - 1.16) < 0.02 and K.burning(T) == 0,
		"shield %.1f move_k %.2f burning %d" % [P.shield, K.move_k(), K.burning(T)]
	)
	ak.step(m, 2.5)
	ok("ram rank 3: the boost ends after 2s", absf(K.move_k() - 1.0) < 0.02, "move_k %.2f" % K.move_k())
	P.slot_lv["dash"] = 1
	# --- Furnace Cloak: fires on the press frame, centred on Cinder whatever the cursor
	reset.call()
	T.teleport(home + Vector3(3.8, 0, 0))
	ak.aim_at(P, home + Vector3(-12.0, 0, 9.0))      # the cursor far off to the other side
	var bl0: int = K.blasts
	P.inp["sig"] = true
	ak.step(m, 1.0 / 60.0)
	P.inp["sig"] = false
	var ring: Dictionary = AimKit.entry(P, "e_ring")
	var ring_at: Vector2 = ring.get("at", Vector2(INF, INF))
	ok(
		"cloak: fires on the press frame (no hold-to-aim, no delay)",
		K.e_on_press() and K.blasts == bl0 + 1 and ak.dmg(T) >= 6.0,
		"blasts +%d dmg %.1f" % [K.blasts - bl0, ak.dmg(T)]
	)
	ok(
		"cloak: the ring is centred on him at the blast's exact radius (cursor ignored)",
		AimKit.shown(P, "e_ring") and ring_at.distance_to(Vector2(home.x, home.z)) < 0.05
			and absf(float(ring.get("r", 0.0)) - float(K.e_def()["radius"])) < 0.001,
		"at %.2f m off, r %.2f" % [ring_at.distance_to(Vector2(home.x, home.z)), float(ring.get("r", 0.0))]
	)
	var flare_t := float((KMovesPair.MOVES["as_cloak"]["keys"] as Array)[-1][0])
	ok(
		"cloak: a quick arms-out flare (0.15-0.25 s)", K.anim_id == "as_cloak" and flare_t >= 0.15 and flare_t <= 0.25,
		"%s %.2f s" % [K.anim_id, flare_t]
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
	var pulled_far: float = P.flat_dist(T)
	reset.call()
	T.teleport(home + Vector3(3.8, 0, 0))
	ak.aim_at(P, T.pos)
	K._cloak_blast()
	ak.step(m, 0.7)
	ok(
		"cloak: no cursor dependence (cursor far away or on the foe: the same pull)",
		absf(P.flat_dist(T) - pulled_far) < 0.1, "%.2f vs %.2f m" % [pulled_far, P.flat_dist(T)]
	)
	K.cd["e"] = 8.0
	P.hp = P.max_hp * 0.5
	K.on_knock(T, true)
	ok(
		"passive: a knock resets the cloak and heals",
		float(K.cd["e"]) <= 0.0 and K.resets >= 1 and P.hp > P.max_hp * 0.6,
		"cd %.1f hp %.0f" % [float(K.cd["e"]), P.hp]
	)
	# --- rank 3: the cloak's shield is 30% bigger on top of the rank's own gain; Cinder Shot holds two charges
	reset.call()
	T.teleport(home + Vector3(3.8, 0, 0))
	K._cloak_blast()
	var shield1: float = P.shield
	reset.call()
	T.teleport(home + Vector3(3.8, 0, 0))
	P.slot_lv["kin"] = 3
	K._cloak_blast()
	ok(
		"cloak rank 3: shield +30%", shield1 > 5.0 and absf(P.shield / shield1 - 1.3) < 0.02,
		"rank 1 %.1f rank 3 %.1f" % [shield1, P.shield]
	)
	ok("cloak: rank 3 no longer refunds on a stoke", not K.has_method("_refund"))
	ok("cinder: one charge at rank 1", K.rmb_charges() == 1)
	P.slot_lv["sec"] = 3
	K.cd["rmb"] = 0.0
	ak.step(m, 0.1)
	ok("cinder: a second charge at rank 3", K.rmb_charges() == 2 and K.ch_rmb >= 2.0, "charges %.1f" % K.ch_rmb)
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
	ak.step(m, 1.0, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	ak.step(m, 0.3)
	ok(
		"merge hold: linwick's lance is dropped, no fire mid-merge",
		not K.was_held and K.spool == 0.0 and K.hose.puffs.is_empty() and K.flame_ticks == ft and P.mel_hold == 0.0,
		"held %s puffs %d ticks +%d" % [K.was_held, K.hose.puffs.size(), K.flame_ticks - ft]
	)
	KinMerge.end(P, "test")
	P.merge_cd = 0.0
	m.queue_free()
	await main.get_tree().process_frame
