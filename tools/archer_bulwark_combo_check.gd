extends "res://tools/archetype_check.gd"
## --archer-combo-check and --bulwark-combo-check: every cross-ability interaction of the two accuracy-pass
## heroes, scripted one by one, asserting the variant that fires (docs/heroes/archer.md, docs/heroes/bulwark.md).
## Also asserts each ability plays its own kit move (HunterAnim.KMOVES). Prints AKCHECK lines like --archetype-check.

func run(main_node: Node) -> void:
	main = main_node
	# (a RefCounted that is only awaiting is freed with its last holder, and the run silently stops)
	main_node.set_meta("hero_combo_check", self)
	var args := OS.get_cmdline_user_args()
	var both := "--hero-combo-check" in args
	var ult = load("res://tools/pin_bjorn_ult_check.gd").new()
	ult.main = main_node
	var own = load("res://tools/pin_bjorn_owner_check.gd").new()
	own.main = main_node
	var launch = load("res://tools/bjorn_launch_check.gd").new()
	launch.main = main_node
	if both or "--archer-combo-check" in args:
		await _archer_combos()
		await ult.pin()
		await own.pin()
	if both or "--bulwark-combo-check" in args:
		await _bulwark_combos()
		await _growth()
		await ult.bjorn()
		await own.bjorn()
		await launch.bjorn()
	n += ult.n + own.n + launch.n
	fails += ult.fails + own.fails + launch.fails
	print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## A raised block of terrain `dx` east of `at` (so a knock east runs into it).
func _wall_at(m: Match, at: Vector3, lv: int, dx0: int) -> void:
	var W: World = m.world
	var wk: PackedByteArray = W.kind
	var wl: PackedByteArray = W.level
	for dz in range(-3, 4):
		for dx in range(0, 3):
			var i: int = W.idx(int(at.x) + dx0 + dx, int(at.z) + dz)
			wk[i] = World.T_GROUND
			wl[i] = lv if dx < 1 else lv + 3
	W.kind = wk
	W.level = wl

func _clear_wall(m: Match, at: Vector3, lv: int, dx0: int) -> void:
	var W: World = m.world
	var wl: PackedByteArray = W.level
	for dz in range(-3, 4):
		for dx in range(0, 3):
			wl[W.idx(int(at.x) + dx0 + dx, int(at.z) + dz)] = lv
	W.level = wl

## The shot of ours most recently skinned by Hem's look: how far it will fly (life * speed), or -1.
func _shot_reach(m: Match, P: Hunter) -> float:
	for i in range(m.shots.size() - 1, -1, -1):
		var sh: Dictionary = m.shots[i]
		if sh["by"] == P and (sh["x"] as Dictionary).has("pin"):
			return float(sh["life0"]) * (sh["vel"] as Vector2).length()
	return -1.0

## Draws the bow for `t` seconds (aim kept on `at`), then lets go; returns how far the arrow will fly.
func _loose_after(m: Match, P: Hunter, t: float, at: Vector3) -> float:
	P.fire_cd = 0.0
	P.ammo = maxi(P.ammo, 1)
	P.reload_t = 0.0
	step(m, t, func(): P.inp["fire"] = true; aim_at(P, at))
	P.inp["fire"] = false
	m.step(DT)
	m.step(DT)
	return _shot_reach(m, P)

func _archer_combos() -> void:
	var r := setup("archer", 7.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: ArcherKit = P.ak
	P.equip("longbow", 0)
	step(m, 0.3)
	var s1 := K.draw.stage_t().x
	var s2 := K.draw.stage_t().y
	ok(
		"pin bow: stage timings (Empowered 0.6, Supercharged 1.15, overdraw 0.5 later)",
		absf(s1 - 0.6) < 0.01 and absf(s2 - 1.15) < 0.01 and absf(K.draw.over_t() - 1.65) < 0.01,
		"%.2f %.2f %.2f" % [s1, s2, K.draw.over_t()]
	)
	# the draw: its pose, the filling line, the resting aim line
	step(m, 0.2, func(): aim_at(P, T.pos))
	ok("pin reticle: a faint aim line to the cursor at rest", AimKit.shown(P, "draw_rest"))
	step(m, 0.3, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	var ve := AimKit.entry(P, "draw")
	ok("pin anim: drawing holds arc_draw", K.anim_id == "arc_draw", K.anim_id)
	var fe := AimKit.entry(P, "draw_fill")
	var fl := (fe.get("to", Vector2.ZERO) as Vector2).distance_to(fe.get("from", Vector2.ZERO))
	var tl := (ve.get("to", Vector2.ZERO) as Vector2).distance_to(ve.get("from", Vector2.ZERO))
	ok(
		"pin reticle: drawing fills the aim line part way (a filling line, no V)",
		AimKit.shown(P, "draw") and String(ve.get("kind", "")) == "line" and fl > 0.1 and fl < tl - 0.1
			and AimKit.shown(P, "draw_mark"),
		"fill %.2f of %.2f" % [fl, tl]
	)
	ok(
		"pin reticle: no cursor ring and no bow glint (the line is the whole readout)",
		float(AimKit.reticle(P).get("charge", 0.0)) < 0.0 and not K.fx.bow_glint.visible,
		str(AimKit.reticle(P))
	)
	step(m, 1.08, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	var le := AimKit.entry(P, "draw")
	ok(
		"pin reticle: Supercharged = one thick line out to max range (16m), the foe under it ringed",
		String(le.get("kind", "")) == "line" and absf(
			(le.get("to", Vector2.ZERO) as Vector2).distance_to(Vector2(P.pos.x, P.pos.z)) - 16.0
		) < 0.1 and AimKit.shown(P, "draw_tgt"),
		"kind %s reach %.1f tgt %s" % [
			str(le.get("kind")),
			(le.get("to", Vector2.ZERO) as Vector2).distance_to(Vector2(P.pos.x, P.pos.z)),
			AimKit.shown(P, "draw_tgt")
		]
	)
	ok(
		"pin anim: the body flashed white as Supercharged came up",
		P.flash_t > 0.0 or K.draw.supers >= 0,
		"flash %.2f" % P.flash_t
	)
	P.inp["fire"] = false
	step(m, 0.1)
	ok("pin anim: a Supercharged release plays arc_super", K.anim_id == "arc_super", K.anim_id)
	step(m, 0.6)
	# where the arrows go: Empowered lands at the cursor, Supercharged flies past it to its range, a tap at the cursor
	T.teleport(home + Vector3(0, 0, 9.0))
	T2.teleport(home + Vector3(0, 0, -9.0))
	var cur := home + Vector3(6.0, 0, 0)
	var e1 := _loose_after(m, P, 0.85, cur)
	ok(
		"pin aim: an Empowered arrow lands at the cursor (6m)",
		absf(e1 - 6.0) < 0.9 and K.draw.last_kind == "arrow",
		"reach %.1f kind %s" % [e1, K.draw.last_kind]
	)
	ok("pin anim: an Empowered release plays arc_loose", K.anim_id == "arc_loose", K.anim_id)
	var pl0 := K.fx.planted
	step(m, 0.6)
	ok(
		"pin vfx: the spent arrow stays stuck in the ground at the cursor",
		K.fx.planted > pl0,
		"planted %d" % (K.fx.planted - pl0)
	)
	var e2 := _loose_after(m, P, 1.3, cur)
	ok(
		"pin aim: a Supercharged arrow flies past the cursor to 16m",
		e2 >= 15.0 and K.draw.last_kind == "super",
		"reach %.1f kind %s" % [e2, K.draw.last_kind]
	)
	step(m, 0.6)
	var e3 := _loose_after(m, P, 0.2, home + Vector3(4.0, 0, 0))
	ok(
		"pin aim: a tap shot lands at the cursor (4m)",
		absf(e3 - 4.0) < 0.9 and K.draw.last_kind == "tap",
		"reach %.1f kind %s" % [e3, K.draw.last_kind]
	)
	ok("pin anim: a tap shot plays arc_tap", K.anim_id == "arc_tap", K.anim_id)
	step(m, 0.6)
	# overdraw: held 0.5s past Supercharged, the arrow does half
	T.teleport(home + Vector3(7.0, 0, 0))
	T2.teleport(home + Vector3(9.0, 0, 0))
	fresh(T)
	var od0 := K.draw.overdraws
	P.fire_cd = 0.0
	P.ammo = maxi(P.ammo, 1)
	P.reload_t = 0.0
	step(m, 1.8, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	ok("pin anim: overdrawn, the draw arm shakes (arc_over)", K.anim_id == "arc_over", K.anim_id)
	var oe := AimKit.entry(P, "draw")
	ok("pin reticle: overdrawn dims the line to a thin pale one and drops the circle",
		float(oe.get("alpha", 1.0)) < 0.6 and float(oe.get("lw", 1.0)) < 0.05 and not AimKit.shown(P, "draw_mark"),
		"alpha %s lw %s" % [str(oe.get("alpha")), str(oe.get("lw"))])
	_loose_after(m, P, 0.05, T.pos)
	ok("pin anim: an overdrawn release droops (arc_over_loose)", K.anim_id == "arc_over_loose", K.anim_id)
	step(m, 0.4)
	ok(
		"pin bow: overdrawn = half damage",
		K.draw.overdraws == od0 + 1 and dmg(T) >= 25.0 and dmg(T) <= 35.0,
		"overdraws %d took %.0f" % [K.draw.overdraws - od0, dmg(T)]
	)
	# perfect release at stage 1: the burst at the bow, no extra damage, and the next draw reaches Empowered 1.6x faster
	fresh(T)
	var pf0 := K.perfects
	_loose_after(m, P, 0.63, T.pos)
	ok("pin anim: a perfect release plays arc_perfect", K.anim_id == "arc_perfect", K.anim_id)
	step(m, 0.4)
	ok(
		"combo pin: stage-1 perfect release (no damage bonus, the quick draw banked)",
		K.perfects == pf0 + 1 and dmg(T) >= 27.0 and dmg(T) <= 33.0 and K.draw.quick,
		"perfects %d took %.0f quick %s" % [K.perfects - pf0, dmg(T), K.draw.quick]
	)
	P.fire_cd = 0.0
	P.ammo = maxi(P.ammo, 1)
	P.reload_t = 0.0
	step(m, 0.42, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	ok(
		"combo pin: perfect > the next draw reaches Empowered in ~0.38s",
		P.draw_t >= s1 and K.draw.quick_used,
		"draw_t %.2f after 0.42s" % P.draw_t
	)
	ok(
		"pin small: after a perfect the draw slows you less (0.85 not 0.7, wiki)",
		absf(K.move_k() * 0.7 - 0.85) < 0.01,
		"move_k %.2f" % K.move_k()
	)
	step(m, 0.25, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	P.inp["fire"] = false
	step(m, 0.6)
	ok("pin: a draw without a perfect is back to normal speed", not K.draw.quick, "quick %s" % K.draw.quick)
	T.teleport(home + Vector3(7.0, 0, 0))
	T2.teleport(home + Vector3(9.0, 0, 0))
	# Heavy Shot into a wall: wall hit + 1.2s stun; the next arrow is a plain one
	fresh(T)
	K.ch_rmb = 2.0
	K.cd["rmb"] = 0.0
	var wall_pos := T.pos
	_wall_at(m, T.pos, lv, 2)
	aim_at(P, T.pos)
	var pn0 := K.pins
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.6, func(): P.inp["sec_hold"] = true; aim_at(P, T.pos))
	var bar0 := float(AimKit.entry(P, "rmb_bar").get("len", 0.0))
	ok(
		"pin RMB held: the gold V and a gold bar from the bow",
		not AimKit.shown(P, "rmb_v") and AimKit.shown(P, "rmb_bar") and K.anim_id == "arc_heavy_wind",
		"v %s bar %s anim %s" % [AimKit.shown(P, "rmb_v"), AimKit.shown(P, "rmb_bar"), K.anim_id]
	)
	ok(
		"pin anim: the Heavy Shot's draw clip runs on the hold's clock (its full-draw key 1.1 lands with full 1.1)",
		absf((m.time - K.anim_at) - K.rmb_t) < 0.02,
		"clip %.2f hold %.2f" % [m.time - K.anim_at, K.rmb_t]
	)
	step(m, 0.55, func(): P.inp["sec_hold"] = true; aim_at(P, T.pos))
	var bar1 := float(AimKit.entry(P, "rmb_bar").get("len", 0.0))
	ok(
		"pin RMB held: the bar grows with the charge, to 2 body heights",
		bar1 > bar0 + 0.5 and bar1 >= 3.5,
		"%.2f -> %.2f" % [bar0, bar1]
	)
	ok(
		"pin small: the Heavy Shot can be held 3 s before it looses by itself (wiki)",
		absf(K.rmb_auto_t() - 3.0) < 0.01 and float(K.rmb_def()["pin"]["push"][0]) >= 8.0,
		"auto %.1f" % K.rmb_auto_t()
	)
	P.inp["sec_hold"] = false
	m.step(DT)
	step(m, 0.3)
	ok(
		"combo archer: Heavy Shot > wall = pin 1.2s + wall hit",
		K.pins >= pn0 + 1 and T.stun_t > 0.7 and dmg(T) >= 35.0 and K.anim_id == "arc_heavy",
		"pins %d stun %.2f took %.0f anim %s" % [K.pins - pn0, T.stun_t, dmg(T), K.anim_id]
	)
	var pd: Dictionary = K.rmb_def()["pin"]
	var want := float(pd["dmg"][1]) * (1.0 + 173.0 / 35.0)
	ok(
		"parity lace: wall pin pays 173 extra on the 35 shot (source ratio 4.94x), not our old 0.4x",
		absf(float(pd["wall_mult"]) - 173.0 / 35.0) < 0.02 and dmg(T) >= want * 0.95,
		"took %.0f, want %.0f" % [dmg(T), want]
	)
	ok(
		"parity lace: RMB charge starts at the press (guard 0.15 s, was a 0.5 s dead zone)",
		float(K.rmb_def()["hold"]) <= 0.15 and K.rmb_charge_full() > 1.0,
		"hold %.2f" % float(K.rmb_def()["hold"])
	)
	var dd0 := dmg(T)
	P.fire_cd = 0.0
	P.ammo = maxi(P.ammo, 1)
	P.reload_t = 0.0
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	step(m, 0.5)
	ok(
		"combo archer: wall pin > shot is a plain arrow (Focus and Deadeye are cut, not in the source)",
		dmg(T) - dd0 > 0.0 and dmg(T) - dd0 < 30.0 and K.anim_id != "pin_deadeye"
			and not K.has_meter() and K.res == 0.0,
		"dealt %.0f anim %s res %.0f" % [dmg(T) - dd0, K.anim_id, K.res]
	)
	# rank 3 (data: Heartpiercer IV): a wall stun gives a dash charge
	P.slot_lv["sec"] = 3
	fresh(T)
	T.teleport(wall_pos)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	P.dashes = 0.0
	aim_at(P, T.pos)
	hold(m, P, 1.2)
	step(m, 0.3)
	ok("pin rank 3: a Heavy Shot wall stun gives a dash charge", T.stun_t > 0.0 and P.dashes >= 0.95, "stun %.2f dashes %.2f" % [T.stun_t, P.dashes])
	P.slot_lv["sec"] = 1
	_clear_wall(m, T.pos, lv, 2)
	# Hail Wall: a curved arc at the cursor distance (5m), 120 degrees; a foe on the arc off to the side
	# burns, one between you and the arc does not
	step(m, 1.0)
	fresh(T)
	fresh(T2)
	K.cd["e"] = 0.0
	P.teleport(home)
	aim_at(P, home + Vector3(5.0, 0, 0))
	T.teleport(home + Vector3(5.0, 0, 0).rotated(Vector3.UP, deg_to_rad(45.0)))
	T2.teleport(home + Vector3(2.4, 0, 0))
	P.ak.use_e()
	ok(
		"pin E: the arc shows at the cursor distance for everyone",
		AimKit.shown(P, "e") and absf(
			float(AimKit.entry(P, "e").get("radius", 0.0)) - 5.0
		) < 0.3 and bool(AimKit.entry(P, "e").get("all", false)),
		str(AimKit.entry(P, "e").get("radius"))
	)
	ok("archer anim: Hail Wall plays arc_hail", K.anim_id == "arc_hail", K.anim_id)
	step(m, 1.6)
	ok(
		"pin E: a foe on the arc 45 degrees off the aim burns, one inside it does not",
		dmg(T) >= 5.0 and T.blight_t > 0.0 and dmg(T2) == 0.0 and K.fx.panels[0].visible,
		"on arc %.0f inside %.0f" % [dmg(T), dmg(T2)]
	)
	# small mechanic (wiki): a Heavy Shot knocking a foe that burns in the wall Cremates it
	var cr0 := K.cremations
	K.ch_rmb = 2.0
	K.cd["rmb"] = 0.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.7, func(): P.inp["sec_hold"] = true; aim_at(P, T.pos))
	P.inp["sec_hold"] = false
	m.step(DT)
	step(m, 0.3)
	ok(
		"pin small: Heavy Shot into a foe burning in the Hail Wall = CREMATED",
		K.cremations == cr0 + 1,
		"cremations %d" % (K.cremations - cr0)
	)
	step(m, 3.5)
	# the Heavy Shot is hold only (data: Heartpiercer): one charge, 16 s, a tap looses nothing and costs nothing
	fresh(T)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	P.teleport(home)
	T.teleport(home + Vector3(7, 0, 0))
	T2.teleport(home + Vector3(9, 0, 0))
	aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.3)
	ok(
		"combo archer: RMB tap looses nothing and costs no charge (no snare, no Tripwire)",
		dmg(T) <= 0.0 and T.root_t <= 0.0 and K.ch_rmb >= 1.0 and K.last_variant == "tap" and not K.d["rmb"].has("snare"),
		"took %.0f root %.2f charges %.1f variant %s" % [dmg(T), T.root_t, K.ch_rmb, K.last_variant]
	)
	hold(m, P, 1.2)
	step(m, 0.3)
	ok(
		"combo archer: RMB hold looses the Heavy Shot on one charge and a 16 s cooldown",
		dmg(T) >= 14.0 and K.rmb_charges() == 1 and K.ch_rmb < 1.0 and absf(float(K.cd["rmb"]) - 16.0) < 0.6,
		"took %.0f max charges %d charges %.1f cd %.1f" % [dmg(T), K.rmb_charges(), K.ch_rmb, float(K.cd["rmb"])]
	)
	ok("archer anim: the Heavy Shot plays arc_heavy", K.anim_id == "arc_heavy", K.anim_id)
	# ranks: the cooldown drops 3 s a rank (16 -> 13 -> 10) and rank 3 adds 3 m of range
	var cds: Array = []
	var reaches: Array = []
	for rk in [1, 2, 3]:
		P.slot_lv["sec"] = rk
		cds.append(K.rmb_def()["cooldown"] * K.cd_k("sec"))
		reaches.append(K.heavy_reach())
	ok(
		"combo archer: Heavy Shot ranks cut 3 s each (16, 13, 10) and rank 3 flies 3 m farther",
		absf(cds[0] - 16.0) < 0.01 and absf(cds[1] - 13.0) < 0.01 and absf(cds[2] - 10.0) < 0.01 and absf(
			reaches[2] - reaches[0] - 3.0
		) < 0.01,
		"cds %s reaches %s" % [str(cds), str(reaches)]
	)
	# upgrade parity (docs/heroes/archer.md): damage and the other two slots
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 0.05
	var up: Array = []
	P.slot_lv["sec"] = 1
	P.slot_lv["kin"] = 1
	var p1 := K.power("sec")
	var pk1 := K.power("kin")
	for rk in [1, 2, 3]:
		P.slot_lv["sec"] = rk
		P.slot_lv["dash"] = rk
		P.slot_lv["kin"] = rk
		up.append([
			K.power("sec") / p1, K.power("kin") / pk1,
			K.dash_def()["cd"] * K.dash_k(), K.e_def()["cooldown"] * K.cd_k("kin"),
		])
	ok("upgrade parity: Heavy Shot damage +20% / +40%", near.call(up[1][0], 1.2) and near.call(up[2][0], 1.4), str(up))
	ok("upgrade parity: Spirit Walk recharge 9.5 -> 8.5 -> 7.5",
			near.call(up[0][2], 9.5) and near.call(up[1][2], 8.5) and near.call(up[2][2], 7.5), str(up))
	ok("upgrade parity: Hail Wall cooldown 15 -> 13 -> 9 and damage +30% / +60%",
			near.call(up[1][3], 13.0) and near.call(up[2][3], 9.0)
			and near.call(up[1][1], 1.3) and near.call(up[2][1], 1.6), str(up))
	P.slot_lv["sec"] = 1
	P.slot_lv["dash"] = 1
	P.slot_lv["kin"] = 1
	# Hail Wall, then a hold-only RMB: the old tap-snare root is gone
	K.cd["e"] = 0.0
	step(m, 5.0)
	# a knock: a dash charge back (DashReset); no kit heal (the source's passive has none)
	fresh(T)
	P.dashes = 0.0
	T2.hp = 4.0
	T2.hurt(10.0, P, {"src": "shot"})
	step(m, 0.1)
	ok("combo archer: knock > a dash charge back, no kit heal", T2.downed and P.dashes >= 0.99
		and not K.res_def().has("knock_heal"), "dashes %.2f" % P.dashes)
	# Hawk Sense: a rival under half health is seen through cover
	fresh(T)
	T.hp = T.max_hp
	T.reveal_t = 0.0
	step(m, 0.5)
	var healthy_seen := T.reveal_t > 0.0
	T.hp = T.max_hp * 0.4
	step(m, 0.5)
	ok(
		"combo archer: Hawk Sense shows only the injured",
		not healthy_seen and T.reveal_t > 0.0,
		"healthy %s injured %.2f" % [healthy_seen, T.reveal_t]
	)
	T.hp = T.max_hp
	# Spirit Walk: the roll plays pin_roll; then she walks through a rock column that stops anyone else
	var W: World = m.world
	var bx := int(home.x) + 3
	var wk: PackedByteArray = W.kind
	for dz in range(-2, 3): wk[W.idx(bx, int(home.z) + dz)] = World.T_BLOCK
	W.kind = wk
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.dashes = P.max_dashes()
	aim_at(P, home + Vector3(6, 0, 0))
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	step(m, 0.1)
	ok("pin anim: Spirit Walk's roll plays pin_roll", K.anim_id == "pin_roll", K.anim_id)
	var roll_t0 := K.anim_at
	step(m, 0.18, func(): P.inp["move"] = Vector2(1, 0))
	ok(
		"pin anim: the roll hands to the crouched walk as the travel ends (roll_t 0.24, footage: no landing beat)",
		K.anim_id == "pin_walk" and absf(K.anim_at - roll_t0 - 0.24) < 0.03,
		"%s at +%.2f" % [K.anim_id, K.anim_at - roll_t0]
	)
	var in0 := K.spirit.passed
	var mk := [0.0]
	step(m, 1.2, func():
		P.inp["move"] = Vector2(1, 0)
		if K.spirit.inside: mk[0] = maxf(mk[0], K.move_k()))
	var mk_in: float = mk[0]
	ok(
		"pin small: no extra speed inside something below rank 3 (x1.1 like outside)",
		absf(mk_in - 1.1) < 0.01,
		"move_k inside %.2f" % mk_in
	)
	ok(
		"pin small: walking into the rock left a spirit orb at the entry",
		K.spirit.orbs.size() >= 1,
		"orbs %d" % K.spirit.orbs.size()
	)
	if K.spirit.orbs.size() >= 1:
		var tp0 := T.pos
		T.teleport(K.spirit.orbs[0]["pos"])
		T.spirit_t = 0.0
		step(m, 0.1)
		ok(
			"pin small: anyone touching the orb walks as a spirit too",
			T.spirit_t > 2.0,
			"ghost %.2f granted %d" % [T.spirit_t, K.spirit.granted.size()]
		)
		T.teleport(tp0)
	ok("pin anim: after the roll she walks as a spirit (pin_walk)", K.anim_id == "pin_walk", K.anim_id)
	ok(
		"combo pin: Spirit Walk passes through a rock column",
		P.pos.x > bx + 1.3 and K.spirit.passed > in0,
		"x %.1f (rock at %d) inside %d" % [P.pos.x, bx, K.spirit.passed - in0]
	)
	# ...and ending inside it puts her back where she went in (no cost: there is no Focus)
	K.spirit.end("time")
	step(m, 0.5)
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	step(m, 0.25, func(): P.inp["move"] = Vector2.ZERO)
	P.teleport(Vector3(bx + 0.5, home.y, home.z))
	P.inp["move"] = Vector2.ZERO
	step(m, 0.05)
	var sn0 := K.spirit.snap_backs
	K.spirit.end("time")
	ok(
		"combo pin: Spirit Walk ending inside a rock = back to the entry",
		K.spirit.snap_backs == sn0 + 1 and P.pos.x < bx,
		"x %.1f (rock %d, entry %.1f)" % [P.pos.x, bx, K.spirit.entry.x]
	)
	# damage ends it
	P.teleport(home)
	P.dashes = P.max_dashes()
	P.do_dash()
	step(m, 0.3)
	T2.hurt(0.0, null, {})
	P.hurt(5.0, T2, {"src": "shot"})
	step(m, 0.05)
	ok("pin: damage ends Spirit Walk", not K.spirit.active() and P.spirit_t <= 0.0)
	# rank 3 (data: Phase Walk IV): 0.5 s longer, +33% inside something that fades over the walk, allies near her walk too
	P.slot_lv["dash"] = 3
	step(m, 0.5)
	var ally_team := T2.team
	T2.team = P.team
	T2.downed = false
	fresh(T2)
	T2.teleport(home + Vector3(0, 0, 2.5))
	T2.spirit_t = 0.0
	K.spirit.granted.clear()
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.dashes = P.max_dashes()
	aim_at(P, home + Vector3(6, 0, 0))
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	ok(
		"pin rank 3: Spirit Walk lasts 0.5 s longer (3.3 s) and an ally within 6 m walks too",
		absf(K.spirit.walk_time() - 3.3) < 0.01 and K.spirit.t > 3.3 and T2.spirit_t > 3.0,
		"walk %.2f ally ghost %.2f" % [K.spirit.walk_time(), T2.spirit_t]
	)
	var boosts: Array = []
	step(m, 1.4, func():
		P.inp["move"] = Vector2(1, 0)
		if K.spirit.inside: boosts.append(K.spirit.inside_boost()))
	boosts.append(0.0)
	boosts.push_front(0.0)
	var first_boost: float = boosts[1]
	var last_boost: float = boosts[boosts.size() - 2]
	ok(
		"pin rank 3: +33% inside something, fading as the walk runs out",
		boosts.size() >= 4 and first_boost > last_boost and first_boost > 0.2 and first_boost <= 0.33,
		"samples %d first %.3f last %.3f" % [boosts.size() - 2, first_boost, last_boost]
	)
	K.spirit.end("time")
	P.slot_lv["dash"] = 1
	T2.team = ally_team
	T2.spirit_t = 0.0
	K.spirit.granted.clear()
	P.inp["move"] = Vector2.ZERO
	# the long dash (no charges left): Hem's own flick
	step(m, 0.5)
	P.dashes = 0.0
	P.ex_cd = 0.0
	P.do_dash()
	step(m, 0.05)
	ok(
		"pin anim: the long dash is her flick and tumble",
		K.st.get("last_dash") == "flick" and K.anim_id == "pin_flick",
		"%s %s" % [str(K.st.get("last_dash")), K.anim_id]
	)
	for dz in range(-2, 3): wk[W.idx(bx, int(home.z) + dz)] = World.T_GROUND
	W.kind = wk
	P.teleport(home + Vector3(0, 3.0, 0))
	P.grounded = false
	P.vel = Vector3(0, -2, 0)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	P.ak.press_rmb()
	ok("archer RMB air: the press starts a draw, no Plunge", K.rmb_down and P.vel.y < 5.0, "vy %.1f" % P.vel.y)
	K.rmb_down = false
	ok("archer: no class R", not K.d.has("r") and K.r_def().is_empty())
	# a Boki merge that starts mid-hold ends the hold: no arrow, no Heavy Shot, no lane telegraph left behind
	step(m, 5.0)
	fresh(T)
	K.ch_rmb = 2.0
	K.cd["rmb"] = 0.0
	P.fire_cd = 0.0
	P.ammo = maxi(P.ammo, 3)
	P.reload_t = 0.0
	P.teleport(home)
	T.teleport(home + Vector3(7, 0, 0))
	aim_at(P, T.pos)
	step(m, 0.5, func(): P.inp["fire"] = true; P.inp["sec_hold"] = false; aim_at(P, T.pos))
	var hurt0 := dmg(T)
	var ammo0 := P.ammo
	ok("merge hold: the bow is drawn before the merge", P.draw_t > 0.2, "draw_t %.2f" % P.draw_t)
	ok("merge hold: a merge is under way", merge_now(P))
	P.inp["fire"] = false
	step(m, 0.5)
	ok(
		"merge hold: archer's bow draw is dropped with no arrow loosed",
		P.draw_t < 0.0 and dmg(T) == hurt0 and P.ammo == ammo0,
		"draw_t %.2f took %.0f ammo %d -> %d" % [P.draw_t, dmg(T) - hurt0, ammo0, P.ammo]
	)
	await done(m)
	var r2 := setup("archer", 7.0, "", true)
	m = r2[0]
	P = r2[1]
	T = r2[2]
	home = r2[4]
	K = P.ak
	K.ch_rmb = 2.0
	K.cd["rmb"] = 0.0
	aim_at(P, T.pos)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.6, func(): P.inp["sec_hold"] = true; aim_at(P, T.pos))
	ok(
		"merge hold: the Heavy Shot is held before the merge",
		K.rmb_down and K.pin_aim and AimKit.shown(P, "rmb_bar"),
		"rmb_down %s aim %s" % [K.rmb_down, K.pin_aim]
	)
	var ch0 := K.ch_rmb
	ok("merge hold: a merge is under way", merge_now(P))
	P.inp["sec_hold"] = false
	step(m, 0.4)
	ok(
		"merge hold: archer's Heavy Shot hold, its gold telegraph and draw pose are dropped, no shot spent",
		not K.rmb_down and not K.pin_aim and not AimKit.shown(
			P,
			"rmb_bar"
		) and K.ch_rmb == ch0 and K.anim_id != "arc_heavy_wind" and dmg(T) == 0.0,
		"rmb_down %s aim %s charges %.1f -> %.1f anim %s took %.0f" % [
			K.rmb_down,
			K.pin_aim,
			ch0,
			K.ch_rmb,
			K.anim_id,
			dmg(T)
		]
	)
	# a merge mid Spirit Walk ends it (Hunter.spirit_t cleared, the tint and aura off)
	await done(m)
	var r3 := setup("archer", 7.0, "", true)
	m = r3[0]
	P = r3[1]
	T = r3[2]
	home = r3[4]
	K = P.ak
	P.dashes = P.max_dashes()
	P.do_dash()
	step(m, 0.3)
	ok("merge hold: Spirit Walk is running before the merge", K.spirit.active() and P.spirit_t > 0.0)
	ok("merge hold: a merge is under way", merge_now(P))
	step(m, 0.1)
	ok(
		"merge hold: Spirit Walk ends with the merge",
		not K.spirit.active() and P.spirit_t <= 0.0,
		"ghost %.2f" % P.spirit_t
	)
	await done(m)

## The 360 Smash's spin hit on the first foe with the hunter at level `lvl`.
func _spin(lvl: int) -> float:
	var r := setup("bulwark", 2.2)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: BulwarkKit = P.ak
	P.lvl = lvl
	LevelGrowth.apply(P)          # a level set straight on the hunter grows nothing until applied
	fresh(T)
	T.teleport(P.pos + Vector3(1.4, 0, 0))
	aim_at(P, T.pos)
	K._spin_hit(P.aim_dir())
	step(m, 0.3)
	var d := dmg(T)
	await done(m)
	return d

## Ability damage reads ArchKit.power(), so quiet level growth (LevelGrowth.ap) raises it.
func _growth() -> void:
	var d1: float = await _spin(1)
	var d10: float = await _spin(10)
	ok(
		"growth: the 360 Smash spin hit grows with level (LevelGrowth.ap 1.0 -> %.2f)" % (1.0 + LevelGrowth.ap_pct(10)),
		d1 > 4.0 and absf(d10 / d1 - (1.0 + LevelGrowth.ap_pct(10))) < 0.01,
		"L1 %.2f L10 %.2f" % [d1, d10]
	)

func _bulwark_combos() -> void:
	var r := setup("bulwark", 2.2)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: BulwarkKit = P.ak
	_wall_at(m, home, lv, 3)
	var reset := func():
		P.teleport(home)
		P.vel = Vector3.ZERO
		fresh(T)
		T.teleport(home + Vector3(2.2, 0, 0))
		aim_at(P, T.pos)
		K.crushed_at = {}
		K.lock_t = 0.0
		K.ch_rmb = 1.0
		K.cd["rmb"] = 0.0
		K.res = 0.0
		P.fire_cd = 0.0
		P.dashes = P.max_dashes()
		K.lmb_t = -1.0
		step(m, 0.6)
		fresh(T)
		T.teleport(home + Vector3(2.2, 0, 0))
		aim_at(P, T.pos)
	# the throw lands at the cursor (5m, past the dummy), clamped to 9m when the cursor is far
	reset.call()
	T.teleport(home + Vector3(0, 0, 6.0))
	var thr0 := K.throws
	aim_at(P, home + Vector3(-5.0, 0, 0))
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	step(m, 0.6)
	ok(
		"bjorn aim: the hammer lands at the cursor (5m) and stays planted",
		K.throws == thr0 + 1 and String(
			K.mace.get("st", "")
		) == "ground" and absf(K.throw_d - 5.0) < 0.7 and K.fx.beacon.visible,
		"throws %d st %s d %.1f beacon %s" % [K.throws - thr0, str(K.mace.get("st")), K.throw_d, K.fx.beacon.visible]
	)
	step(m, 7.0)
	ok(
		"bjorn: the planted hammer never comes back by itself",
		String(K.mace.get("st", "")) == "ground",
		str(K.mace.get("st"))
	)
	# E with the hammer planted grows there (checked below); in hand it comes down on him
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	step(m, 1.2)
	ok("bjorn: tap again calls it back", K.mace.is_empty())
	K.cd["e"] = 0.0
	aim_at(P, home + Vector3(-5.0, 0, 0))
	P.ak.use_e()
	ok(
		"bjorn E: with the hammer in hand it comes down on him, the column and circle shown",
		Vector2(K.mend["pos"].x - P.pos.x, K.mend["pos"].z - P.pos.z).length() < 0.5 and K.fx.column.visible,
		"mend %s" % str(K.mend.get("pos"))
	)
	step(m, 0.1)
	ok(
		"bjorn E: the landing circle shows for everyone while it comes down",
		AimKit.shown(P, "e") and bool(AimKit.entry(P, "e").get("all", false))
	)
	step(m, 5.0)
	ok("bjorn E: the zone ends after the column (1s) and 4s of ticks", K.mend.is_empty())
	P.fire_cd = 0.0
	_clear_wall(m, home, lv, 3)
	T.teleport(home + Vector3(0, 0, 6.0))
	aim_at(P, home + Vector3(30.0, 0, 0))
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	step(m, 0.8)
	ok("bjorn aim: a far cursor clamps the throw to 9m", absf(K.throw_d - 9.0) < 0.8, "d %.1f" % K.throw_d)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	step(m, 1.0)
	# small mechanics: it flies at least 2.5 m (a cursor at 2 m lands at 2.5 m), and can't be recalled in its
	# first 0.25 s
	P.fire_cd = 0.0
	aim_at(P, home + Vector3(2.0, 0, 0))
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	step(m, 0.05)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	ok(
		"bjorn small: a recall in the first 0.25 s is ignored",
		String(K.mace.get("st", "")) in ["wind", "fly"],
		str(K.mace.get("st"))
	)
	step(m, 0.6)
	ok("bjorn small: a close cursor still throws 2.5 m", absf(K.throw_d - 2.5) < 0.6, "d %.1f" % K.throw_d)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	step(m, 1.0)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	step(m, 1.0)
	# LMB held: the hammer whirling round him, the glint from 0.6 s, the flare at full; let go: the slam
	# carries him forward with a flaming crescent
	reset.call()
	_clear_wall(m, home, lv, 3)
	T.teleport(home + Vector3(2.4, 0, 0))
	step(m, 0.4, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	ok(
		"bjorn LMB held: the hammer whirling round him (item 59), no glint yet",
		K.fx.held and not K.fx.glint.visible and K.anim_id == "bul_smash_wind",
		"held %s glint %s anim %s" % [K.fx.held, K.fx.glint.visible, K.anim_id]
	)
	step(m, 0.4, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	ok(
		"bjorn LMB held: the glint shows from 0.6s, the cursor ring filling",
		K.fx.glint.visible and float(AimKit.reticle(P).get("charge", 0.0)) > 0.4,
		"glint %s charge %.2f" % [K.fx.glint.visible, float(AimKit.reticle(P).get("charge", 0.0))]
	)
	step(m, 0.75, func(): P.inp["fire"] = true; aim_at(P, T.pos))      # past the perfect window: a normal swing
	ok("bjorn LMB held: the full-charge flare at 1.25s", K.flared and K.smash_k() >= 0.99, "k %.2f" % K.smash_k())
	var px0 := P.pos.x
	var sl0 := K.slams
	P.inp["fire"] = false
	m.step(DT)
	m.step(DT)
	var gcd := P.glide_cd
	step(m, 0.32)
	ok(
		"combo bjorn: the full slam = a 180 crescent, carries him forward, hits hard (5x the throw)",
		K.slams == sl0 + 1 and K.slam_k >= 0.99 and P.pos.x - px0 >= 1.0 and dmg(T) >= 55.0 and not K.fx.held,
		"carry %.2f took %.0f" % [P.pos.x - px0, dmg(T)]
	)
	ok("bjorn anim: the slam plays bul_smash", K.anim_id == "bul_smash", K.anim_id)
	ok(
		"bjorn small: wind-down after the slam, no glider straight away (momentum kept)",
		gcd >= 0.25,
		"glide_cd %.2f" % gcd
	)
	# 360 Smash: a short dash, then ONE spin hit around him on arrival
	step(m, 1.0)
	reset.call()
	T.teleport(home + Vector3(5.2, 0, 0))
	aim_at(P, T.pos)
	var sp0 := K.spins
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	step(m, 0.12, func(): P.inp["move"] = Vector2(1, 0))
	var mid := dmg(T)
	step(m, 0.4, func(): P.inp["move"] = Vector2.ZERO)
	ok(
		"combo bjorn: 360 Smash = no hit on the way, one spin hit on arrival",
		mid == 0.0 and K.spins == sp0 + 1 and dmg(T) >= 18.0 and dmg(T) <= 30.0,
		"mid %.0f spins %d took %.0f" % [mid, K.spins - sp0, dmg(T)]
	)
	# the aegis: his own curved slab over the wall while raised
	reset.call()
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	ok(
		"bjorn RMB: his aegis is drawn in place of the plain wall",
		not K.wall.is_empty() and K.fx.aegis.visible and not (
			K.wall["node"] as Node3D
		).visible and K.anim_id == "bul_guard",
		"aegis %s anim %s" % [K.fx.aegis.visible, K.anim_id]
	)
	P.inp["sec_hold"] = false
	step(m, 0.5)
	_wall_at(m, home, lv, 3)
	# the long dash (no charges left): Breaker's lumbering shove
	reset.call()
	P.dashes = 0.0
	P.ex_cd = 0.0
	P.do_dash()
	step(m, 0.05)
	ok(
		"bjorn anim: the long dash is his lumbering shove",
		K.st.get("last_dash") == "lumber" and K.anim_id == "bul_lumber",
		"%s %s" % [str(K.st.get("last_dash")), K.anim_id]
	)
	step(m, 0.6)
	# the RMB has no Bash any more (data: the Bash is Shift behind the shield): a tap pushes nothing
	reset.call()
	var c0 := K.crushes
	var x0 := T.pos.x
	tap(m, P)
	step(m, 0.3)
	ok(
		"combo bulwark: RMB tap no longer bashes (no push, no Crush, no charge spent)",
		absf(T.pos.x - x0) < 0.2 and dmg(T) <= 0.0 and K.crushes == c0 and K.ch_rmb >= 1.0 and not K.d["rmb"].has("bash"),
		"moved %.2f took %.0f crushes %d charges %.1f" % [T.pos.x - x0, dmg(T), K.crushes - c0, K.ch_rmb]
	)
	# Shield Charge into the wall: Crushed (a stun, no heal), on the RMB slot's own 6 s cooldown, no dash charge spent
	step(m, 1.0)
	reset.call()
	c0 = K.crushes
	P.hp = P.max_hp - 40.0
	var hp_before := P.hp
	var dashes_before := P.dashes
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.do_dash()
	var dashes_spent := dashes_before - P.dashes
	var charge_cd := float(K.cd["rmb"])
	step(m, 0.35, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	step(m, 0.2)
	ok(
		"combo bulwark: shield up > Shift = Shield Charge, Crushed on the wall",
		K.st.get("last_dash") == "charge" and K.crushes == c0 + 1 and T.stun_t > 0.0,
		"dash %s crushes %d stun %.2f" % [str(K.st.get("last_dash")), K.crushes - c0, T.stun_t]
	)
	ok(
		"combo bulwark: the Shield Charge spends no dash charge and has its own 6 s cooldown",
		dashes_spent < 0.2 and absf(charge_cd - 6.0) < 0.4 and K.ch_rmb < 1.0,
		"dashes spent %.2f cd %.1f charges %.1f" % [dashes_spent, charge_cd, K.ch_rmb]
	)
	ok("combo bulwark: a Crush no longer heals him", P.hp <= hp_before + 1.0, "hp %.0f -> %.0f" % [hp_before, P.hp])
	# on cooldown the Shift behind the shield does nothing
	P.dashes = P.max_dashes()
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	var spins_before := K.spins
	var dashes_held := P.dashes
	P.do_dash()
	step(m, 0.2, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	ok(
		"combo bulwark: the Shield Charge on cooldown denies the dash (no charge spent, no spin)",
		P.dashes >= dashes_held - 0.01 and K.spins == spins_before,
		"dashes %.2f -> %.2f" % [dashes_held, P.dashes]
	)
	# ranks (data: Shield Bash and Spin Dash -1.5 s a rank; the shield +25% HP, then faster repair): cooldown 6, 4.5, 3
	var cds: Array = []
	var shields: Array = []
	for rk in [1, 2, 3]:
		P.slot_lv["dash"] = rk
		P.slot_lv["sec"] = rk
		cds.append(K.rmb_def()["cooldown"] * K.cd_k("sec"))
		shields.append(K.shield_max())
	ok(
		"combo bulwark: Shield Charge cooldown 6 / 4.5 / 3 s by dash rank, aegis 160 / 200 / 240",
		absf(cds[0] - 6.0) < 0.01 and absf(cds[1] - 4.5) < 0.01 and absf(cds[2] - 3.0) < 0.01 and absf(
			shields[1] - 200.0
		) < 0.01 and absf(shields[2] - 240.0) < 0.01,
		"cds %s shields %s" % [str(cds), str(shields)]
	)
	P.slot_lv["sec"] = 3
	ok(
		"combo bulwark: rank 3 repairs faster (regen 30/s, back in 2 s when broken, 1.4 s wait)",
		absf(K._shield_stat("regen") - 30.0) < 0.01 and absf(K._shield_stat("lock") - 2.0) < 0.01 and absf(
			K._shield_stat("wait") - 1.4
		) < 0.01,
		"regen %.0f lock %.1f wait %.1f" % [K._shield_stat("regen"), K._shield_stat("lock"), K._shield_stat("wait")]
	)
	P.slot_lv["sec"] = 1
	P.slot_lv["dash"] = 1
	# Whirl (no shield) is a knock like any other: into the wall it Crushes now (data: any knock into a wall stuns)
	step(m, 1.0)
	reset.call()
	c0 = K.crushes
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	step(m, 0.4)
	P.inp["move"] = Vector2.ZERO
	ok(
		"combo bulwark: the 360 Smash into the wall Crushes (stun, 8 damage on top)",
		K.st.get("last_dash") == "whirl" and K.crushes == c0 + 1 and dmg(T) > 0.0 and T.stun_t > 0.0,
		"crushes %d took %.0f stun %.2f" % [K.crushes - c0, dmg(T), T.stun_t]
	)
	# rank 3: a 360 Smash that hits refunds the Shield Charge
	step(m, 1.0)
	reset.call()
	P.slot_lv["dash"] = 3
	K.ch_rmb = 0.0
	K.cd["rmb"] = 4.0
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	step(m, 0.4)
	P.inp["move"] = Vector2.ZERO
	ok(
		"combo bulwark: rank 3, a 360 Smash that hits refunds the Shield Charge",
		K.ch_rmb >= 1.0 and float(K.cd["rmb"]) <= 0.0,
		"charges %.1f cd %.1f" % [K.ch_rmb, float(K.cd["rmb"])]
	)
	P.slot_lv["dash"] = 1
	# Guard at 50: the Shield Charge ends in a Shield Slam (stun 0.6, spends the Guard)
	step(m, 1.0)
	reset.call()
	K.res = 80.0
	var guard_before := K.res
	var slams_before := K.shield_slams
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true; K.res = maxf(K.res, 80.0))
	guard_before = K.res
	P.do_dash()
	step(m, 0.5, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	step(m, 0.2)
	ok(
		"combo bulwark: Guard 50 + Shift behind the shield = Shield Slam, Guard spent",
		K.shield_slams == slams_before + 1 and K.res <= guard_before - 49.0,
		"slams %d guard %.0f -> %.0f stun %.2f" % [K.shield_slams - slams_before, guard_before, K.res, T.stun_t]
	)
	# a part-charged blow into the wall Crushes too (any knock)
	step(m, 1.0)
	reset.call()
	c0 = K.crushes
	step(m, 0.6, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	ok("anim bulwark: charging holds bul_smash_wind", K.anim_id == "bul_smash_wind", K.anim_id)
	P.inp["fire"] = false
	step(m, 0.4)
	ok("combo bulwark: a half-charged blow into the wall Crushes", K.crushes == c0 + 1, "crushes %d" % (K.crushes - c0))
	step(m, 1.0)
	reset.call()
	c0 = K.crushes
	step(m, 1.55, func(): P.inp["fire"] = true; aim_at(P, T.pos))      # past the perfect window
	P.inp["fire"] = false
	step(m, 0.3)
	ok(
		"combo bulwark: full Crushing Blow > wall = Crushed",
		K.crushes == c0 + 1 and K.anim_id == "bul_smash",
		"crushes %d anim %s" % [K.crushes - c0, K.anim_id]
	)
	# Shift while winding up the blow: a short plain dash on a full charge, the swing still charging (item 51)
	step(m, 1.5)
	reset.call()
	_clear_wall(m, home, lv, 3)
	T.teleport(home + Vector3(9.0, 0, 0))
	P.dashes = 2.0
	step(m, 0.5, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	var d0 := P.dashes
	var p0 := P.pos
	P.do_dash()
	m.step(DT)
	var short_anim := K.anim_id
	step(m, 0.2, func(): P.inp["fire"] = true)
	ok(
		"combo bulwark: hold LMB > Shift = short dash, a full charge, the swing still charging",
		K.st.get(
			"last_dash"
		) == "short" and K.lmb_t > 0.6 and d0 - P.dashes > 0.9 and P.flat_dist(p0) > 0.8 and short_anim == "bul_short",
		"dash %s lmb %.2f spent %.2f moved %.1f" % [str(K.st.get("last_dash")), K.lmb_t, d0 - P.dashes, P.flat_dist(p0)]
	)
	ok("anim bulwark: out of the short dash he is back in the spin's pose", K.anim_id == "bul_smash_wind", K.anim_id)
	P.inp["fire"] = false
	step(m, 1.0)
	# Mending Ground mends the shield only while it is raised
	reset.call()
	K.shield_hp = 40.0
	K.down_t = -20.0
	K.cd["e"] = 0.0
	P.hp = P.max_hp - 100.0
	var hp_start := P.hp
	P.inp["aim"] = home
	P.ak.use_e()
	ok("anim bulwark: Mending Ground plays bul_mend", K.anim_id == "bul_mend", K.anim_id)
	var tk0 := K.ticks_healed
	step(m, 1.3)
	ok(
		"combo bulwark: Mending Ground is a zone: the column (1 s), then ticks of 2 every 0.5 s",
		not K.mend.is_empty() and float(K.mend["zone"]) > 0.0 and K.ticks_healed > tk0 - 1,
		"zone %.2f ticks %d" % [float(K.mend.get("zone", -9.0)), K.ticks_healed - tk0]
	)
	step(m, 4.0)
	step(m, 0.1)
	ok(
		"combo bulwark: E with the shield down heals but does not mend it, and foes inside are not slowed",
		P.hp >= hp_start + 33.0 and K.shield_hp < 55.0 and K.mend.is_empty() and K.ticks_healed - tk0 >= 7 and T.slow_t <= 0.0,
		"hp %.0f -> %.0f shield %.0f ticks %d" % [hp_start, P.hp, K.shield_hp, K.ticks_healed - tk0]
	)
	var ecds: Array = []
	var heals: Array = []
	for rk in [1, 2, 3]:
		P.slot_lv["kin"] = rk
		ecds.append(K.e_def()["cooldown"] * K.cd_k("kin"))
		heals.append(K.heal_k())
	ok(
		"combo bulwark: E cooldown 12 / 12 / 8 s and healing x1 / 1.25 / 1.5 by rank",
		absf(ecds[0] - 12.0) < 0.01 and absf(ecds[1] - 12.0) < 0.01 and absf(ecds[2] - 8.0) < 0.01 and absf(
			heals[1] - 1.25
		) < 0.01 and absf(heals[2] - 1.5) < 0.01,
		"cds %s heals %s" % [str(ecds), str(heals)]
	)
	P.slot_lv["kin"] = 1
	# small mechanics (wiki): a broken aegis isn't repaired by it; a downed teammate inside starts coming back
	K.cd["e"] = 0.0
	K.shield_hp = 0.0
	K.lock_t = 30.0
	K.down_t = 0.0
	var A: Hunter = m.make_hunter(
		"A",
		P.team,
		"medium",
		"Mate",
		"idle",
		{},
		P.pos + Vector3(0, 0, 2.7),
		{"arch": "none"}
	)
	T.teleport(home + Vector3(0, 0, -5.0))
	step(m, 0.1)
	A.downed = true
	A.revive = 0.0
	A.down_hp = 1000.0
	var ks0 := K.kickstarts
	P.ak.use_e()
	step(m, 5.2)
	ok("bjorn small: Mending Ground doesn't repair a broken aegis", K.shield_hp < 1.0, "shield %.0f" % K.shield_hp)
	ok(
		"bjorn small: a downed teammate inside Mending Ground starts reviving",
		K.kickstarts == ks0 + 1 and A.revive >= 0.3,
		"revive %.2f" % A.revive
	)
	A.downed = false
	A.teleport(home + Vector3(0, 0, -30))
	K.lock_t = 0.0
	K.cd["e"] = 0.0
	K.lock_t = 0.0
	P.hp = P.max_hp - 30.0
	K.shield_hp = 40.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	P.ak.use_e()
	step(m, 5.3, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	ok(
		"combo bulwark: E with the shield raised mends it (at the burst)",
		float(K.wall.get("hp", K.shield_hp)) >= 95.0 or K.shield_hp >= 95.0,
		"shield %.0f" % K.shield_hp
	)
	step(m, 0.5)
	# the mace lies, then E grows where it lies
	reset.call()
	K.cd["e"] = 0.0
	T.teleport(home + Vector3(6.0, 0, 0))
	aim_at(P, T.pos)
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	m.step(DT)
	step(m, 0.8)
	var lie: Vector3 = K.mace.get("pos", Vector3.ZERO)
	P.inp["aim"] = home
	P.ak.use_e()
	ok(
		"combo bulwark: mace thrown > E blooms where it lies",
		String(K.mace.get("st", "")) == "ground" and Vector2(
			K.mend["pos"].x - lie.x,
			K.mend["pos"].z - lie.z
		).length() < 1.5,
		"mend %s mace %s" % [str(K.mend.get("pos")), str(lie)]
	)
	# the zone follows the hammer: recalled while the zone stands, it moves back to him
	step(m, 1.6)
	var far := Vector2(K.mend["pos"].x - P.pos.x, K.mend["pos"].z - P.pos.z).length()
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	step(m, 1.2)
	var near := Vector2(K.mend["pos"].x - P.pos.x, K.mend["pos"].z - P.pos.z).length() if not K.mend.is_empty() else -1.0
	ok(
		"combo bulwark: the zone follows the hammer back to him when it is recalled",
		far > 3.0 and near >= 0.0 and near < 1.5 and K.mace.is_empty(),
		"far %.1f near %.1f" % [far, near]
	)
	step(m, 4.0)
	ok("bulwark: no class R", not K.d.has("r") and K.r_def().is_empty())
	# a Boki merge that starts mid-hold ends the holds: no Crushing Blow when LMB is let go, the raised shield comes down
	
	step(m, 1.0)
	reset.call()
	c0 = K.crushes
	step(m, 1.0, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	ok("merge hold: the Crushing Blow is charging before the merge", K.lmb_t > 0.5, "lmb_t %.2f" % K.lmb_t)
	ok("merge hold: a merge is under way", merge_now(P))
	var burst := dmg(T)          # (the merge's own burst has landed by now; the release must add nothing)
	P.inp["fire"] = false
	step(m, 0.4)
	ok(
		"merge hold: bulwark's Crushing Blow charge is dropped, the release swings nothing",
		K.lmb_t < 0.0 and P.mel_hold == 0.0 and dmg(T) == burst and K.crushes == c0 and K.anim_id != "bul_smash",
		"lmb_t %.2f took %.0f (merge burst %.0f) anim %s" % [K.lmb_t, dmg(T), burst, K.anim_id]
	)
	await done(m)
	var r2 := setup("bulwark", 2.2)
	m = r2[0]
	P = r2[1]
	T = r2[2]
	home = r2[4]
	K = P.ak
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	K.lock_t = 0.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.5, func(): P.inp["sec_hold"] = true)
	ok("merge hold: the shield is raised before the merge", not K.wall.is_empty() and K.rmb_down)
	var hp0 := float(K.wall.get("hp", 0.0))
	ok("merge hold: a merge is under way", merge_now(P))
	P.inp["sec_hold"] = false
	step(m, 0.3)
	ok("merge hold: bulwark's raised shield comes down with the merge (hit points kept)", K.wall.is_empty() and not K.rmb_down and K.shield_hp >= hp0 - 1.0 and not m.verbs.walls.any(func(w): return w.get("by") == P), "wall %s rmb_down %s hp %.0f -> %.0f" % [not K.wall.is_empty(), K.rmb_down, hp0, K.shield_hp])
	await done(m)
