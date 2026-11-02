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

func _archer_combos() -> void:
	var r := setup("archer", 7.0, "", true)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var T2: Hunter = r[3]
	var home: Vector3 = r[4]; var lv: int = r[5]
	var K: ArcherKit = P.ak
	# the bow's own move while drawing and on release
	P.equip("longbow", 0); step(m, 0.3)
	step(m, 0.2, func(): P.inp["fire"] = true; K.res = 0.0; aim_at(P, T.pos))
	ok("archer anim: drawing holds arc_draw", K.anim_id == "arc_draw", K.anim_id)
	P.inp["fire"] = false
	step(m, 0.1)
	ok("archer anim: release plays arc_loose", K.anim_id == "arc_loose", K.anim_id)
	step(m, 0.6)
	# a perfect release at the first stage (0.4s) is a smaller bonus; at full draw the full one
	fresh(T); var pf0 := K.perfects
	step(m, 0.43, func(): P.inp["fire"] = true; K.res = 0.0; aim_at(P, T.pos))
	P.inp["fire"] = false
	step(m, 0.5)
	ok("combo archer: stage-1 perfect release", K.perfects == pf0 + 1 and dmg(T) >= 33.0, "perfects %d took %.0f" % [K.perfects - pf0, dmg(T)])
	# Heavy Shot into a wall: wall hit + 1.2s stun, fills Focus; then the next shot is a Deadeye
	fresh(T); K.ch_rmb = 2.0; K.cd["rmb"] = 0.0; K.res = 0.0
	_wall_at(m, T.pos, lv, 2)
	aim_at(P, T.pos)
	var pn0 := K.pins; var de0 := K.deadeyes
	hold(m, P, 1.15)
	step(m, 0.3)
	ok("combo archer: Heavy Shot > wall = pin 1.2s + wall hit", K.pins >= pn0 + 1 and T.stun_t > 0.7 and dmg(T) >= 35.0 and K.anim_id == "arc_heavy", "pins %d stun %.2f took %.0f anim %s" % [K.pins - pn0, T.stun_t, dmg(T), K.anim_id])
	ok("combo archer: wall pin fills Focus", K.full_ready())
	var dd0 := dmg(T)
	P.fire_cd = 0.0; P.ammo = maxi(P.ammo, 1); P.reload_t = 0.0
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 0.5)
	ok("combo archer: wall pin > shot = Deadeye", K.deadeyes == de0 + 1 and dmg(T) - dd0 >= 18.0, "deadeyes %d dealt %.0f" % [K.deadeyes - de0, dmg(T) - dd0])
	_clear_wall(m, T.pos, lv, 2)
	# Hail Wall, then a snare tap: roots 1.0 (the longer root), and the move plays
	step(m, 1.0); fresh(T); K.cd["e"] = 0.0; K.res = 0.0; K.ch_rmb = 2.0; K.cd["rmb"] = 0.0
	P.teleport(home); T.teleport(home + Vector3(7, 0, 0)); aim_at(P, T.pos)
	P.ak.use_e()
	ok("archer anim: Hail Wall plays arc_hail", K.anim_id == "arc_hail", K.anim_id)
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
	# Hawk Sense: a rival under half health is seen through cover
	fresh(T); T.hp = T.max_hp; T.reveal_t = 0.0
	step(m, 0.5)
	var healthy_seen := T.reveal_t > 0.0
	T.hp = T.max_hp * 0.4
	step(m, 0.5)
	ok("combo archer: Hawk Sense shows only the injured", not healthy_seen and T.reveal_t > 0.0, "healthy %s injured %.2f" % [healthy_seen, T.reveal_t])
	T.hp = T.max_hp
	# grapple: zip and hop each play their own move
	P.teleport(home); P.vel = Vector3.ZERO; P.dashes = P.max_dashes(); P.inp["aim"] = home + Vector3(0, 0, 6.0)
	P.do_dash()
	step(m, 0.1)
	ok("archer anim: hop plays arc_hop", K.anim_id == "arc_hop", K.anim_id)
	P.teleport(home + Vector3(0, 3.0, 0)); P.grounded = false; P.vel = Vector3(0, -2, 0); K.ch_rmb = 2.0; K.cd["rmb"] = 0.0; K.res = 0.0
	P.ak.press_rmb()
	ok("archer anim: plunge plays arc_plunge", K.anim_id == "arc_plunge", K.anim_id)
	ok("archer: no class R", not K.d.has("r") and K.r_def().is_empty())
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
	# Bash into the wall: Crushed with the 0.5s stun
	reset.call()
	var c0 := K.crushes
	tap(m, P)
	step(m, 0.3)
	ok("combo bulwark: Bash > wall = Crushed 0.5", K.crushes == c0 + 1 and T.stun_t > 0.2 and T.stun_t <= 0.9 and K.anim_id == "bul_bash", "crushes %d stun %.2f anim %s" % [K.crushes - c0, T.stun_t, K.anim_id])
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
	await done(m)
