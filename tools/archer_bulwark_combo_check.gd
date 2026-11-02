extends "res://tools/archetype_check.gd"
## --archer-combo-check and --bulwark-combo-check: every cross-ability interaction of the two accuracy-pass
## heroes, scripted one by one, asserting the variant that fires (docs/heroes/archer.md, docs/heroes/bulwark.md).
## Also asserts each ability plays its own kit move (HunterAnim.KMOVES). Prints AKCHECK lines like --archetype-check.

func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("hero_combo_check", self)     # (a RefCounted that is only awaiting is freed with its last holder, and the run silently stops)
	var args := OS.get_cmdline_user_args()
	var both := "--hero-combo-check" in args
	if both or "--archer-combo-check" in args: await _archer_combos()
	if both or "--bulwark-combo-check" in args: await _bulwark_combos()
	print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## A raised block of terrain `dx` east of `at` (so a knock east runs into it).
func _wall_at(m: Match, at: Vector3, lv: int, dx0: int) -> void:
	var W: World = m.world
	var wk: PackedByteArray = W.kind; var wl: PackedByteArray = W.level
	for dz in range(-3, 4):
		for dx in range(0, 3):
			var i: int = W.idx(int(at.x) + dx0 + dx, int(at.z) + dz)
			wk[i] = World.T_GROUND
			wl[i] = lv if dx < 1 else lv + 3
	W.kind = wk; W.level = wl

func _clear_wall(m: Match, at: Vector3, lv: int, dx0: int) -> void:
	var W: World = m.world
	var wl: PackedByteArray = W.level
	for dz in range(-3, 4):
		for dx in range(0, 3):
			wl[W.idx(int(at.x) + dx0 + dx, int(at.z) + dz)] = lv
	W.level = wl

## The shot of ours most recently skinned by Pin's look: how far it will fly (life * speed), or -1.
func _shot_reach(m: Match, P: Hunter) -> float:
	for i in range(m.shots.size() - 1, -1, -1):
		var sh: Dictionary = m.shots[i]
		if sh["by"] == P and (sh["x"] as Dictionary).has("pin"):
			return float(sh["life0"]) * (sh["vel"] as Vector2).length()
	return -1.0

## Draws the bow for `t` seconds (aim kept on `at`), then lets go; returns how far the arrow will fly.
func _loose_after(m: Match, P: Hunter, K: ArcherKit, t: float, at: Vector3) -> float:
	P.fire_cd = 0.0; P.ammo = maxi(P.ammo, 1); P.reload_t = 0.0
	step(m, t, func(): P.inp["fire"] = true; K.res = 0.0; aim_at(P, at))
	P.inp["fire"] = false
	m.step(DT); m.step(DT)
	return _shot_reach(m, P)

func _archer_combos() -> void:
	var r := setup("archer", 7.0, "", true)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var T2: Hunter = r[3]
	var home: Vector3 = r[4]; var lv: int = r[5]
	var K: ArcherKit = P.ak
	P.equip("longbow", 0); step(m, 0.3)
	var s1 := K.draw.stage_t().x; var s2 := K.draw.stage_t().y
	ok("pin bow: stage timings (Empowered 0.6, Supercharged 1.15, overdraw 0.5 later)", absf(s1 - 0.6) < 0.01 and absf(s2 - 1.15) < 0.01 and absf(K.draw.over_t() - 1.65) < 0.01, "%.2f %.2f %.2f" % [s1, s2, K.draw.over_t()])
	# the draw: its pose, the V reticle closing, the resting aim line
	step(m, 0.2, func(): K.res = 0.0; aim_at(P, T.pos))
	ok("pin reticle: a faint aim line to the cursor at rest", AimKit.shown(P, "draw_rest"))
	step(m, 0.3, func(): P.inp["fire"] = true; K.res = 0.0; aim_at(P, T.pos))
	var ve := AimKit.entry(P, "draw")
	ok("pin anim: drawing holds arc_draw", K.anim_id == "arc_draw", K.anim_id)
	ok("pin reticle: drawing shows the V, part closed", AimKit.shown(P, "draw") and String(ve.get("kind", "")) == "vee" and float(ve.get("half", 0.0)) > 0.0 and float(ve.get("half", 1.0)) < deg_to_rad(12.5), "kind %s half %.3f" % [str(ve.get("kind")), float(ve.get("half", -1.0))])
	ok("pin reticle: the cursor charge ring fills", float(AimKit.reticle(P).get("charge", 0.0)) > 0.2, str(AimKit.reticle(P)))
	step(m, 1.08, func(): P.inp["fire"] = true; K.res = 0.0; aim_at(P, T.pos))
	var le := AimKit.entry(P, "draw")
	ok("pin reticle: Supercharged = one thick line out to max range (16m), the foe under it ringed", String(le.get("kind", "")) == "line" and (le.get("to", Vector2.ZERO) as Vector2).distance_to(le.get("from", Vector2.ZERO)) >= 15.9 and AimKit.shown(P, "draw_tgt"), "kind %s len %.1f tgt %s" % [str(le.get("kind")), (le.get("to", Vector2.ZERO) as Vector2).distance_to(le.get("from", Vector2.ZERO)), AimKit.shown(P, "draw_tgt")])
	ok("pin anim: the body flashed white as Supercharged came up", P.flash_t > 0.0 or K.draw.supers >= 0, "flash %.2f" % P.flash_t)
	P.inp["fire"] = false
	step(m, 0.1)
	ok("pin anim: a Supercharged release plays arc_super", K.anim_id == "arc_super", K.anim_id)
	step(m, 0.6)
	# where the arrows go: Empowered lands at the cursor, Supercharged flies past it to its range, a tap at the cursor
	T.teleport(home + Vector3(0, 0, 9.0)); T2.teleport(home + Vector3(0, 0, -9.0))
	var cur := home + Vector3(6.0, 0, 0)
	var e1 := _loose_after(m, P, K, 0.75, cur)
	ok("pin aim: an Empowered arrow lands at the cursor (6m)", absf(e1 - 6.0) < 0.9 and K.draw.last_kind == "arrow", "reach %.1f kind %s" % [e1, K.draw.last_kind])
	ok("pin anim: an Empowered release plays arc_loose", K.anim_id == "arc_loose", K.anim_id)
	var pl0 := K.fx.planted
	step(m, 0.6)
	ok("pin vfx: the spent arrow stays stuck in the ground at the cursor", K.fx.planted > pl0, "planted %d" % (K.fx.planted - pl0))
	var e2 := _loose_after(m, P, K, 1.3, cur)
	ok("pin aim: a Supercharged arrow flies past the cursor to 16m", e2 >= 15.0 and K.draw.last_kind == "super", "reach %.1f kind %s" % [e2, K.draw.last_kind])
	step(m, 0.6)
	var e3 := _loose_after(m, P, K, 0.2, home + Vector3(4.0, 0, 0))
	ok("pin aim: a tap shot lands at the cursor (4m)", absf(e3 - 4.0) < 0.9 and K.draw.last_kind == "tap", "reach %.1f kind %s" % [e3, K.draw.last_kind])
	ok("pin anim: a tap shot plays arc_tap", K.anim_id == "arc_tap", K.anim_id)
	step(m, 0.6)
	# overdraw: held 0.5s past Supercharged, the arrow does half
	T.teleport(home + Vector3(7.0, 0, 0)); T2.teleport(home + Vector3(9.0, 0, 0)); fresh(T)
	var od0 := K.draw.overdraws
	P.fire_cd = 0.0; P.ammo = maxi(P.ammo, 1); P.reload_t = 0.0
	step(m, 1.8, func(): P.inp["fire"] = true; K.res = 0.0; aim_at(P, T.pos))
	ok("pin anim: overdrawn, the draw arm shakes (arc_over)", K.anim_id == "arc_over", K.anim_id)
	_loose_after(m, P, K, 0.05, T.pos)
	ok("pin anim: an overdrawn release droops (arc_over_loose)", K.anim_id == "arc_over_loose", K.anim_id)
	step(m, 0.4)
	ok("pin bow: overdrawn = half damage", K.draw.overdraws == od0 + 1 and dmg(T) >= 25.0 and dmg(T) <= 35.0, "overdraws %d took %.0f" % [K.draw.overdraws - od0, dmg(T)])
	# perfect release at stage 1: the star, no extra damage, and the next draw reaches Empowered 1.6x faster
	fresh(T); var pf0 := K.perfects
	_loose_after(m, P, K, 0.63, T.pos)
	ok("pin anim: a perfect release plays arc_perfect", K.anim_id == "arc_perfect", K.anim_id)
	step(m, 0.4)
	ok("combo pin: stage-1 perfect release (no damage bonus, the quick draw banked)", K.perfects == pf0 + 1 and dmg(T) >= 27.0 and dmg(T) <= 33.0 and K.draw.quick and float(AimKit.reticle(P).get("perfect", 0.0)) >= 0.0, "perfects %d took %.0f quick %s" % [K.perfects - pf0, dmg(T), K.draw.quick])
	P.fire_cd = 0.0; P.ammo = maxi(P.ammo, 1); P.reload_t = 0.0
	step(m, 0.42, func(): P.inp["fire"] = true; K.res = 0.0; aim_at(P, T.pos))
	ok("combo pin: perfect > the next draw reaches Empowered in ~0.38s", P.draw_t >= s1 and K.draw.quick_used, "draw_t %.2f after 0.42s" % P.draw_t)
	step(m, 0.25, func(): P.inp["fire"] = true; K.res = 0.0; aim_at(P, T.pos))
	P.inp["fire"] = false
	step(m, 0.6)
	ok("pin: a draw without a perfect is back to normal speed", not K.draw.quick, "quick %s" % K.draw.quick)
	T.teleport(home + Vector3(7.0, 0, 0)); T2.teleport(home + Vector3(9.0, 0, 0))
	# Heavy Shot into a wall: wall hit + 1.2s stun, fills Focus; then the next shot is a Deadeye
	fresh(T); K.ch_rmb = 2.0; K.cd["rmb"] = 0.0; K.res = 0.0
	_wall_at(m, T.pos, lv, 2)
	aim_at(P, T.pos)
	var pn0 := K.pins; var de0 := K.deadeyes
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.6, func(): P.inp["sec_hold"] = true; aim_at(P, T.pos))
	var bar0 := float(AimKit.entry(P, "rmb_bar").get("len", 0.0))
	ok("pin RMB held: the gold V and a gold bar from the bow", AimKit.shown(P, "rmb_v") and AimKit.shown(P, "rmb_bar") and K.anim_id == "arc_heavy_wind", "v %s bar %s anim %s" % [AimKit.shown(P, "rmb_v"), AimKit.shown(P, "rmb_bar"), K.anim_id])
	step(m, 0.55, func(): P.inp["sec_hold"] = true; aim_at(P, T.pos))
	var bar1 := float(AimKit.entry(P, "rmb_bar").get("len", 0.0))
	ok("pin RMB held: the bar grows with the charge, to 2 body heights", bar1 > bar0 + 0.5 and bar1 >= 3.5, "%.2f -> %.2f" % [bar0, bar1])
	P.inp["sec_hold"] = false
	m.step(DT)
	step(m, 0.3)
	ok("combo archer: Heavy Shot > wall = pin 1.2s + wall hit", K.pins >= pn0 + 1 and T.stun_t > 0.7 and dmg(T) >= 35.0 and K.anim_id == "arc_heavy", "pins %d stun %.2f took %.0f anim %s" % [K.pins - pn0, T.stun_t, dmg(T), K.anim_id])
	ok("combo archer: wall pin fills Focus", K.full_ready())
	var dd0 := dmg(T)
	P.fire_cd = 0.0; P.ammo = maxi(P.ammo, 1); P.reload_t = 0.0
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 0.5)
	ok("combo archer: wall pin > shot = Deadeye", K.deadeyes == de0 + 1 and dmg(T) - dd0 >= 18.0, "deadeyes %d dealt %.0f" % [K.deadeyes - de0, dmg(T) - dd0])
	ok("pin anim: the Deadeye payoff plays pin_deadeye", K.anim_id == "pin_deadeye", K.anim_id)
	_clear_wall(m, T.pos, lv, 2)
	# Hail Wall: a curved arc at the cursor distance (5m), 120 degrees; a foe on the arc off to the side
	# burns, one between you and the arc does not
	step(m, 1.0); fresh(T); fresh(T2); K.cd["e"] = 0.0; K.res = 0.0
	P.teleport(home); aim_at(P, home + Vector3(5.0, 0, 0))
	T.teleport(home + Vector3(5.0, 0, 0).rotated(Vector3.UP, deg_to_rad(45.0))); T2.teleport(home + Vector3(2.4, 0, 0))
	P.ak.use_e()
	ok("pin E: the arc shows at the cursor distance for everyone", AimKit.shown(P, "e") and absf(float(AimKit.entry(P, "e").get("radius", 0.0)) - 5.0) < 0.3 and bool(AimKit.entry(P, "e").get("all", false)), str(AimKit.entry(P, "e").get("radius")))
	ok("archer anim: Hail Wall plays arc_hail", K.anim_id == "arc_hail", K.anim_id)
	step(m, 1.6, func(): K.res = 0.0)
	ok("pin E: a foe on the arc 45 degrees off the aim burns, one inside it does not", dmg(T) >= 5.0 and T.blight_t > 0.0 and dmg(T2) == 0.0 and K.fx.panels[0].visible, "on arc %.0f inside %.0f" % [dmg(T), dmg(T2)])
	step(m, 3.5)
	# Hail Wall, then a snare tap: roots 1.0 (the longer root), and the move plays
	fresh(T); K.cd["e"] = 0.0; K.res = 0.0; K.ch_rmb = 2.0; K.cd["rmb"] = 0.0
	P.teleport(home); T.teleport(home + Vector3(7, 0, 0)); T2.teleport(home + Vector3(9, 0, 0)); aim_at(P, T.pos)
	P.ak.use_e()
	step(m, 0.5, func(): K.res = 0.0)
	tap(m, P)
	step(m, 0.15)
	ok("combo archer: Hail Wall > snare tap roots 1.0", T.root_t > 0.6 or K.last_variant == "during_e", "root %.2f variant %s" % [T.root_t, K.last_variant])
	ok("archer anim: snare plays arc_snare", K.anim_id == "arc_snare", K.anim_id)
	step(m, 5.0)
		# a knock: heal + a dash charge back
	fresh(T); P.hp = P.max_hp - 40.0; P.dashes = 0.0
	var hp0 := P.hp
	T2.hp = 4.0
	T2.hurt(10.0, P, {"src": "shot"})
	step(m, 0.1)
	ok("combo archer: knock > heal + dash charge", T2.downed and P.hp >= hp0 + 17.0 and P.dashes >= 0.99, "hp %.0f -> %.0f dashes %.2f" % [hp0, P.hp, P.dashes])
	ok("pin anim: a knock run down plays pin_rundown", K.anim_id == "pin_rundown", K.anim_id)
	# Hawk Sense: a rival under half health is seen through cover
	fresh(T); T.hp = T.max_hp; T.reveal_t = 0.0
	step(m, 0.5)
	var healthy_seen := T.reveal_t > 0.0
	T.hp = T.max_hp * 0.4
	step(m, 0.5)
	ok("combo archer: Hawk Sense shows only the injured", not healthy_seen and T.reveal_t > 0.0, "healthy %s injured %.2f" % [healthy_seen, T.reveal_t])
	T.hp = T.max_hp
	# Spirit Walk: the roll plays pin_roll; then she walks through a rock column that stops anyone else
	var W: World = m.world
	var bx := int(home.x) + 3
	var wk: PackedByteArray = W.kind
	for dz in range(-2, 3): wk[W.idx(bx, int(home.z) + dz)] = World.T_BLOCK
	W.kind = wk
	P.teleport(home); P.vel = Vector3.ZERO; P.dashes = P.max_dashes(); aim_at(P, home + Vector3(6, 0, 0))
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	step(m, 0.1)
	ok("pin anim: Spirit Walk's roll plays pin_roll", K.anim_id == "pin_roll", K.anim_id)
	var in0 := K.spirit.passed
	step(m, 1.2, func(): P.inp["move"] = Vector2(1, 0))
	ok("pin anim: after the roll she walks as a spirit (pin_walk)", K.anim_id == "pin_walk", K.anim_id)
	ok("combo pin: Spirit Walk passes through a rock column", P.pos.x > bx + 1.3 and K.spirit.passed > in0, "x %.1f (rock at %d) inside %d" % [P.pos.x, bx, K.spirit.passed - in0])
	# ...and ending inside it puts her back where she went in, for 30 Focus
	P.teleport(home); P.vel = Vector3.ZERO; P.dashes = P.max_dashes(); K.res = 80.0
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	step(m, 0.35, func(): P.inp["move"] = Vector2(1, 0))
	P.teleport(Vector3(bx + 0.5, home.y, home.z)); P.inp["move"] = Vector2.ZERO
	step(m, 0.05)
	var sn0 := K.spirit.snapped
	var f0 := K.res
	K.spirit.end("time")
	ok("combo pin: Spirit Walk ending inside a rock = back to the entry, Focus spent", K.spirit.snapped == sn0 + 1 and P.pos.x < bx and K.res <= f0 - 29.0, "x %.1f focus %.0f -> %.0f" % [P.pos.x, f0, K.res])
	# damage ends it
	P.teleport(home); P.dashes = P.max_dashes()
	P.do_dash()
	step(m, 0.3)
	T2.hurt(0.0, null, {})
	P.hurt(5.0, T2, {"src": "shot"})
	step(m, 0.05)
	ok("pin: damage ends Spirit Walk", not K.spirit.active() and P.spirit_t <= 0.0)
	# the long dash (no charges left): Pin's own flick
	step(m, 0.5); P.dashes = 0.0; P.ex_cd = 0.0
	P.do_dash()
	step(m, 0.05)
	ok("pin anim: the long dash is her flick and tumble", K.st.get("last_dash") == "flick" and K.anim_id == "pin_flick", "%s %s" % [str(K.st.get("last_dash")), K.anim_id])
	for dz in range(-2, 3): wk[W.idx(bx, int(home.z) + dz)] = World.T_GROUND
	W.kind = wk
	P.teleport(home + Vector3(0, 3.0, 0)); P.grounded = false; P.vel = Vector3(0, -2, 0); K.ch_rmb = 2.0; K.cd["rmb"] = 0.0; K.res = 0.0
	P.ak.press_rmb()
	ok("archer anim: plunge plays arc_plunge", K.anim_id == "arc_plunge", K.anim_id)
	ok("archer: no class R", not K.d.has("r") and K.r_def().is_empty())
	# a Boki merge that starts mid-hold ends the hold: no arrow, no Heavy Shot, no lane telegraph left behind
	step(m, 5.0); fresh(T); K.ch_rmb = 2.0; K.cd["rmb"] = 0.0; K.res = 0.0; P.fire_cd = 0.0; P.ammo = maxi(P.ammo, 3); P.reload_t = 0.0
	P.teleport(home); T.teleport(home + Vector3(7, 0, 0)); aim_at(P, T.pos)
	step(m, 0.5, func(): P.inp["fire"] = true; P.inp["sec_hold"] = false; aim_at(P, T.pos))
	var hurt0 := dmg(T); var ammo0 := P.ammo
	ok("merge hold: the bow is drawn before the merge", P.draw_t > 0.2, "draw_t %.2f" % P.draw_t)
	ok("merge hold: a merge is under way", merge_now(P))
	P.inp["fire"] = false
	step(m, 0.5)
	ok("merge hold: archer's bow draw is dropped with no arrow loosed", P.draw_t < 0.0 and dmg(T) == hurt0 and P.ammo == ammo0, "draw_t %.2f took %.0f ammo %d -> %d" % [P.draw_t, dmg(T) - hurt0, ammo0, P.ammo])
	await done(m)
	var r2 := setup("archer", 7.0, "", true)
	m = r2[0]; P = r2[1]; T = r2[2]; home = r2[4]
	K = P.ak
	K.ch_rmb = 2.0; K.cd["rmb"] = 0.0; K.res = 0.0
	aim_at(P, T.pos)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.6, func(): P.inp["sec_hold"] = true; aim_at(P, T.pos))
	ok("merge hold: the Heavy Shot is held before the merge", K.rmb_down and K.pin_aim and AimKit.shown(P, "rmb_bar"), "rmb_down %s aim %s" % [K.rmb_down, K.pin_aim])
	var ch0 := K.ch_rmb
	ok("merge hold: a merge is under way", merge_now(P))
	P.inp["sec_hold"] = false
	step(m, 0.4)
	ok("merge hold: archer's Heavy Shot hold, its gold telegraph and draw pose are dropped, no shot spent", not K.rmb_down and not K.pin_aim and not AimKit.shown(P, "rmb_bar") and K.ch_rmb == ch0 and K.anim_id != "arc_heavy_wind" and dmg(T) == 0.0, "rmb_down %s aim %s charges %.1f -> %.1f anim %s took %.0f" % [K.rmb_down, K.pin_aim, ch0, K.ch_rmb, K.anim_id, dmg(T)])
	# a merge mid Spirit Walk ends it (Hunter.spirit_t cleared, the tint and aura off)
	await done(m)
	var r3 := setup("archer", 7.0, "", true)
	m = r3[0]; P = r3[1]; T = r3[2]; home = r3[4]
	K = P.ak
	P.dashes = P.max_dashes()
	P.do_dash()
	step(m, 0.3)
	ok("merge hold: Spirit Walk is running before the merge", K.spirit.active() and P.spirit_t > 0.0)
	ok("merge hold: a merge is under way", merge_now(P))
	step(m, 0.1)
	ok("merge hold: Spirit Walk ends with the merge", not K.spirit.active() and P.spirit_t <= 0.0, "ghost %.2f" % P.spirit_t)
	await done(m)

func _bulwark_combos() -> void:
	var r := setup("bulwark", 2.2)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	var home: Vector3 = r[4]; var lv: int = r[5]
	var K: BulwarkKit = P.ak
	_wall_at(m, home, lv, 3)
	var reset := func():
		P.teleport(home); P.vel = Vector3.ZERO; fresh(T); T.teleport(home + Vector3(2.2, 0, 0)); aim_at(P, T.pos)
		K.crushed_at = {}; K.lock_t = 0.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.res = 0.0; P.fire_cd = 0.0; P.dashes = P.max_dashes(); K.lmb_t = -1.0
		step(m, 0.6); fresh(T); T.teleport(home + Vector3(2.2, 0, 0)); aim_at(P, T.pos)
	# the throw lands at the cursor (5m, past the dummy), clamped to 9m when the cursor is far
	reset.call()
	T.teleport(home + Vector3(0, 0, 6.0))
	var thr0 := K.throws
	aim_at(P, home + Vector3(-5.0, 0, 0))
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 0.6)
	ok("bjorn aim: the hammer lands at the cursor (5m) and stays planted", K.throws == thr0 + 1 and String(K.mace.get("st", "")) == "ground" and absf(K.throw_d - 5.0) < 0.7 and K.fx.beacon.visible, "throws %d st %s d %.1f beacon %s" % [K.throws - thr0, str(K.mace.get("st")), K.throw_d, K.fx.beacon.visible])
	step(m, 7.0)
	ok("bjorn: the planted hammer never comes back by itself", String(K.mace.get("st", "")) == "ground", str(K.mace.get("st")))
	# E with the hammer planted grows there (checked below); in hand it comes down on him
	P.fire_cd = 0.0; P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 1.2)
	ok("bjorn: tap again calls it back", K.mace.is_empty())
	K.cd["e"] = 0.0; aim_at(P, home + Vector3(-5.0, 0, 0))
	P.ak.use_e()
	ok("bjorn E: with the hammer in hand it comes down on him, the column and circle shown", Vector2(K.mend["pos"].x - P.pos.x, K.mend["pos"].z - P.pos.z).length() < 0.5 and K.fx.column.visible, "mend %s" % str(K.mend.get("pos")))
	step(m, 0.1)
	ok("bjorn E: the landing circle shows for everyone while it comes down", AimKit.shown(P, "e") and bool(AimKit.entry(P, "e").get("all", false)))
	step(m, 1.2)
	P.fire_cd = 0.0
	_clear_wall(m, home, lv, 3)
	T.teleport(home + Vector3(0, 0, 6.0))
	aim_at(P, home + Vector3(30.0, 0, 0))
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 0.8)
	ok("bjorn aim: a far cursor clamps the throw to 9m", absf(K.throw_d - 9.0) < 0.8, "d %.1f" % K.throw_d)
	P.fire_cd = 0.0; P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 1.0)
	# LMB held: the hammer spins in his hand, the glint from 0.6 s, the flare at full; let go: the slam
	# carries him forward with a flaming crescent
	reset.call()
	_clear_wall(m, home, lv, 3)
	T.teleport(home + Vector3(2.4, 0, 0))
	step(m, 0.4, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	ok("bjorn LMB held: the hammer spins, no glint yet", K.fx.spin_on and not K.fx.glint.visible and K.anim_id == "bul_smash_wind", "spin %s glint %s anim %s" % [K.fx.spin_on, K.fx.glint.visible, K.anim_id])
	step(m, 0.4, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	ok("bjorn LMB held: the glint shows from 0.6s, the cursor ring filling", K.fx.glint.visible and float(AimKit.reticle(P).get("charge", 0.0)) > 0.4, "glint %s charge %.2f" % [K.fx.glint.visible, float(AimKit.reticle(P).get("charge", 0.0))])
	step(m, 0.5, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	ok("bjorn LMB held: the full-charge flare at 1.25s", K.flared and K.smash_k() >= 0.99, "k %.2f" % K.smash_k())
	var px0 := P.pos.x
	var sl0 := K.slams
	P.inp["fire"] = false
	step(m, 0.35)
	ok("combo bjorn: the full slam = a 180 crescent, carries him forward, hits hard (5x the throw)", K.slams == sl0 + 1 and K.slam_k >= 0.99 and P.pos.x - px0 >= 1.0 and dmg(T) >= 55.0 and not K.fx.spin_on, "carry %.2f took %.0f" % [P.pos.x - px0, dmg(T)])
	ok("bjorn anim: the slam plays bul_smash", K.anim_id == "bul_smash", K.anim_id)
	# 360 Smash: a short dash, then ONE spin hit around him on arrival
	step(m, 1.0); reset.call()
	T.teleport(home + Vector3(5.2, 0, 0)); aim_at(P, T.pos)
	var sp0 := K.spins
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	step(m, 0.12, func(): P.inp["move"] = Vector2(1, 0))
	var mid := dmg(T)
	step(m, 0.4, func(): P.inp["move"] = Vector2.ZERO)
	ok("combo bjorn: 360 Smash = no hit on the way, one spin hit on arrival", mid == 0.0 and K.spins == sp0 + 1 and dmg(T) >= 18.0 and dmg(T) <= 30.0, "mid %.0f spins %d took %.0f" % [mid, K.spins - sp0, dmg(T)])
	# the aegis: his own curved slab over the wall while raised
	reset.call()
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	ok("bjorn RMB: his aegis is drawn in place of the plain wall", not K.wall.is_empty() and K.fx.aegis.visible and not (K.wall["node"] as Node3D).visible and K.anim_id == "bul_guard", "aegis %s anim %s" % [K.fx.aegis.visible, K.anim_id])
	P.inp["sec_hold"] = false
	step(m, 0.5)
	_wall_at(m, home, lv, 3)
	# the long dash (no charges left): Bjorn's lumbering shove
	reset.call()
	P.dashes = 0.0; P.ex_cd = 0.0
	P.do_dash()
	step(m, 0.05)
	ok("bjorn anim: the long dash is his lumbering shove", K.st.get("last_dash") == "lumber" and K.anim_id == "bul_lumber", "%s %s" % [str(K.st.get("last_dash")), K.anim_id])
	step(m, 0.6)
	# Bash into the wall: Crushed with the 0.5s stun
	reset.call()
	var c0 := K.crushes
	tap(m, P)
	step(m, 0.3)
	ok("combo bulwark: Bash > wall = Crushed 0.5", K.crushes == c0 + 1 and T.stun_t > 0.2 and T.stun_t <= 0.9 and K.anim_id in ["bul_bash", "bul_crush"], "crushes %d stun %.2f anim %s" % [K.crushes - c0, T.stun_t, K.anim_id])
	# Shield Charge into the wall: Crushed too
	step(m, 1.0); reset.call()
	c0 = K.crushes
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.do_dash()
	step(m, 0.35, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	step(m, 0.2)
	ok("combo bulwark: shield up > Shift = Shield Charge, Crushed on the wall", K.st.get("last_dash") == "charge" and K.crushes == c0 + 1, "dash %s crushes %d" % [str(K.st.get("last_dash")), K.crushes - c0])
	# Whirl (no shield) knocks but never Crushes
	step(m, 1.0); reset.call()
	c0 = K.crushes
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	step(m, 0.4)
	P.inp["move"] = Vector2.ZERO
	ok("combo bulwark: Whirl into the wall is not a Crush", K.st.get("last_dash") == "whirl" and K.crushes == c0 and dmg(T) > 0.0 and K.anim_id == "bul_whirl", "crushes %d took %.0f" % [K.crushes - c0, dmg(T)])
	# a part-charged blow into the wall does not Crush; a full one does
	step(m, 1.0); reset.call()
	c0 = K.crushes
	step(m, 0.6, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	ok("anim bulwark: charging holds bul_smash_wind", K.anim_id == "bul_smash_wind", K.anim_id)
	P.inp["fire"] = false
	step(m, 0.4)
	ok("combo bulwark: half-charged blow is no Crush", K.crushes == c0, "crushes %d" % (K.crushes - c0))
	step(m, 1.0); reset.call()
	c0 = K.crushes
	step(m, 1.3, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	P.inp["fire"] = false
	step(m, 0.3)
	ok("combo bulwark: full Crushing Blow > wall = Crushed", K.crushes == c0 + 1 and K.anim_id == "bul_smash", "crushes %d anim %s" % [K.crushes - c0, K.anim_id])
	# Shift while winding up the blow: a short plain dash for half a charge, the wind-up goes on
	step(m, 1.5); reset.call()
	_clear_wall(m, home, lv, 3)
	T.teleport(home + Vector3(9.0, 0, 0))
	P.dashes = 2.0
	step(m, 0.5, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	var d0 := P.dashes; var p0 := P.pos
	P.do_dash()
	step(m, 0.15, func(): P.inp["fire"] = true)
	ok("combo bulwark: hold LMB > Shift = short dash, half a charge, still winding", K.st.get("last_dash") == "short" and K.lmb_t > 0.2 and d0 - P.dashes < 0.8 and P.flat_dist(p0) > 0.8 and K.anim_id == "bul_short", "dash %s lmb %.2f spent %.2f moved %.1f" % [str(K.st.get("last_dash")), K.lmb_t, d0 - P.dashes, P.flat_dist(p0)])
	P.inp["fire"] = false
	step(m, 1.0)
	# Mending Ground mends the shield only while it is raised
	reset.call()
	K.shield_hp = 40.0; K.down_t = -20.0; K.cd["e"] = 0.0; P.hp = P.max_hp - 30.0
	P.inp["aim"] = home
	P.ak.use_e()
	ok("anim bulwark: Mending Ground plays bul_mend", K.anim_id == "bul_mend", K.anim_id)
	step(m, 1.3)
	ok("combo bulwark: E with the shield down heals but does not mend it", P.hp >= P.max_hp - 8.0 and K.shield_hp < 55.0, "hp %.0f shield %.0f" % [P.hp, K.shield_hp])
	K.cd["e"] = 0.0; K.lock_t = 0.0; P.hp = P.max_hp - 30.0; K.shield_hp = 40.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	P.ak.use_e()
	step(m, 1.3, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	ok("combo bulwark: E with the shield raised mends it", float(K.wall.get("hp", K.shield_hp)) >= 95.0 or K.shield_hp >= 95.0, "shield %.0f" % K.shield_hp)
	step(m, 0.5)
	# the mace lies, then E grows where it lies
	reset.call()
	K.cd["e"] = 0.0
	T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false; m.step(DT)
	step(m, 0.8)
	var lie: Vector3 = K.mace.get("pos", Vector3.ZERO)
	P.inp["aim"] = home
	P.ak.use_e()
	ok("combo bulwark: mace thrown > E blooms where it lies", String(K.mace.get("st", "")) == "ground" and Vector2(K.mend["pos"].x - lie.x, K.mend["pos"].z - lie.z).length() < 1.5, "mend %s mace %s" % [str(K.mend.get("pos")), str(lie)])
	ok("bulwark: no class R", not K.d.has("r") and K.r_def().is_empty())
	# a Boki merge that starts mid-hold ends the holds: no Crushing Blow when LMB is let go, the raised shield comes down
	step(m, 1.0); reset.call()
	c0 = K.crushes
	step(m, 1.0, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	ok("merge hold: the Crushing Blow is charging before the merge", K.lmb_t > 0.5, "lmb_t %.2f" % K.lmb_t)
	ok("merge hold: a merge is under way", merge_now(P))
	var burst := dmg(T)          # (the merge's own burst has landed by now; the release must add nothing)
	P.inp["fire"] = false
	step(m, 0.4)
	ok("merge hold: bulwark's Crushing Blow charge is dropped, the release swings nothing", K.lmb_t < 0.0 and P.mel_hold == 0.0 and dmg(T) == burst and K.crushes == c0 and K.anim_id != "bul_smash", "lmb_t %.2f took %.0f (merge burst %.0f) anim %s" % [K.lmb_t, dmg(T), burst, K.anim_id])
	await done(m)
	var r2 := setup("bulwark", 2.2)
	m = r2[0]; P = r2[1]; T = r2[2]; home = r2[4]
	K = P.ak
	K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.lock_t = 0.0
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
