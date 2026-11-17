extends "res://tools/ability_check.gd"      # shares its _ac_setup / _ac_run / _ac_glove helpers
## --grammar-runtime-check, moved out of main.gd (AGENTS.md section 2); registered in tools/check_registry.gd.

# ------------------------------------------------------------------ kin grammar runtime check
## Headless check of the kin grammar's runtime (docs/KIN_GRAMMAR.md, Phase 2): each kin's abilities
## run from their parts, diminishing returns and stun immunity, no self-trigger, the caps, carry
## modes, the merge's unlock, timer and cooldown, and owner bonuses. Prints GRT PASS/FAIL lines.
var _grt_fail := 0
func _grt(name: String, ok: bool, info := "") -> void:
	if main.has_meta("grt_T") and is_instance_valid(main.get_meta("grt_T")) and OS.get_cmdline_user_args().has("--grt-debug"): print("   T at %s" % str((main.get_meta("grt_T") as Hunter).pos))
	print("GRT %-34s %s  %s" % [name, "PASS" if ok else "FAIL", info])
	if not ok: _grt_fail += 1

## Gives the test player a fresh kin of this species, settled on its shoulder.
func _grt_kin(m: Match, P: Hunter, sp: String, rec_extra := {}) -> Kin:
	if P.kin:
		var o: Kin = P.kin
		KinMerge.end(P, "test")
		o.dead = true
		m.kins.erase(o)
		o.queue_free()
		P.kin = null
	var rec := Save.new_kin(sp)
	rec["trust"] = 95.0
	for kk in rec_extra: rec[kk] = rec_extra[kk]
	var k := m.give_kin(P, rec)
	k.stow()
	k.settle = 1.0
	k.brain.think_t = 1e9        # the test casts by hand; its own AI stays quiet (tested on its own below)
	P.merge_cd = 0.0
	for i in 3: m.step(Match.DT)
	return k

## Puts the kin out on the field beside its hunter.
func _grt_out(k: Kin, at: Vector3) -> void:
	k.runner.reset()
	k.target = null
	k.teleport(at)
	k.state = "active"
	k.fly = {}
	k.settle = 0.0
	k.grounded = true

func _grt_reset(T: Hunter) -> void:
	T.hp = T.max_hp
	T.burn_t = 0.0; T.blight_t = 0.0; T.slow_t = 0.0; T.stun_t = 0.0; T.root_t = 0.0; T.knock_t = 0.0
	T.dr = {}; T.cc_immune_t = 0.0; T.dr_stun = false; T.vuln_t = 0.0; T.vel = Vector3.ZERO

## A test-only ability from a dictionary (parsed by the checker like any file).
func _grt_spec(d: Dictionary) -> AbilitySpec:
	var rep := GrammarReport.new()
	var a := AbilitySpec.parse(d, rep)
	if not rep.ok():
		print("GRT spec errors: ", rep.errors)
	return a

func run(main_node: Node) -> void:
	main = main_node
	var r: Array
	var m: Match; var P: Hunter; var T: Hunter
	var acc := {}
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	main.set_meta("grt_T", T)
	var home := P.pos
	# ---- 1. each of the six kin: its E and its auto active, run from their parts
	var k := _grt_kin(m, P, "cindle")
	_grt_out(k, home + Vector3(1.0, 0, 0))
	var d0 := k.flat_dist(T)
	_grt("cindle E Stinger Hook cast", k.use_ability("k1", T.pos), "")
	_ac_run(m, 0.8)
	_grt("cindle E hook yanks + poisons", k.flat_dist(T) < d0 - 2.0 and T.blight_t > 0.0 and T.burn_t > 0.0, "dist %.1f -> %.1f, blight %.1f burn %.1f" % [d0, k.flat_dist(T), T.blight_t, T.burn_t])
	_grt_reset(T); T.teleport(home + Vector3(6, 0, 0))
	_grt_out(k, home + Vector3(1.0, 0, 0))
	var dash_ok := k.use_ability("k2", T.pos)
	_ac_run(m, 0.6)
	_grt("cindle auto Stinger Dash", dash_ok and T.hp < T.max_hp and T.burn_t > 0.0, "took %.0f burn %.1f" % [T.max_hp - T.hp, T.burn_t])
	_grt_reset(T); T.teleport(home + Vector3(6, 0, 0))
	k = _grt_kin(m, P, "pebbit")
	_grt_out(k, home + Vector3(1.0, 0, 0))
	acc["top"] = 0.0
	var g0 := T.pos.y
	k.use_ability("k1", T.pos + Vector3(-1.0, 0, 0))
	_ac_run(m, 1.2, func(): acc["top"] = maxf(float(acc["top"]), T.pos.y - g0))
	_grt("pebbit E Gravity Slam", T.hp < T.max_hp and float(acc["top"]) > 0.3, "took %.0f, rose %.2f" % [T.max_hp - T.hp, acc["top"]])
	k.stow()
	var nw := m.verbs.walls.size()
	k.use_ability("k2", P.pos)
	_grt("pebbit auto Mass Guard wall", m.verbs.walls.size() == nw + 1 and bool(m.verbs.walls[-1]["follow"]), "%d walls" % m.verbs.walls.size())
	_ac_run(m, 3.5)
	_grt_reset(T)
	T.teleport(home + Vector3(6, 0, 0))        # (the slam knocked it close: the shot must start past the wall)
	k = _grt_kin(m, P, "puddlet")
	_grt_out(k, home + Vector3(0.5, 0, 1.0))
	k.use_ability("k1", home + Vector3(2.5, 0, 0))
	var thp := T.hp; var php := P.hp
	m.spawn_shot(T, T.pos + Vector3(-0.6, 0.95, 0), Vector2(-30, 0), 20.0, 0.6, 0.15, Color.RED, {})
	_ac_run(m, 0.6)
	_grt("puddlet E Prism Wall reflects", T.hp < thp and P.hp >= php, "shooter took %.0f" % (thp - T.hp))
	k.stow()
	P.shield = 0.0
	var nm := m.verbs.mirrors.size()
	k.use_ability("k2", P.pos)
	_grt("puddlet auto Refraction", P.shield >= 19.0 and m.verbs.mirrors.size() > nm, "shield %.0f, mirrors %d" % [P.shield, m.verbs.mirrors.size()])
	_ac_run(m, 5.0)
	_grt_reset(T)
	k = _grt_kin(m, P, "burrlet")
	_grt_out(k, home + Vector3(1.0, 0, 0))
	var ntr := m.verbs.traps.size()
	var nf := m.fields.list.size()
	k.use_ability("k1", T.pos + Vector3(-3.5, 0, 0))
	_grt("burrlet E Puffcap Mines: 3 traps", m.verbs.traps.size() - ntr == 3, "%d" % (m.verbs.traps.size() - ntr))
	_ac_run(m, 0.8)
	acc["root"] = 0.0
	_ac_run(m, 1.6, func():
		T.inp["move"] = Vector2(-1, 0)
		acc["root"] = maxf(float(acc["root"]), T.root_t))
	T.inp["move"] = Vector2.ZERO
	_grt("burrlet E mine roots + spore cloud", float(acc["root"]) > 0.5 and m.fields.list.size() > nf, "root %.2f, took %.0f" % [acc["root"], T.max_hp - T.hp])
	_ac_run(m, 3.5)
	_grt_reset(T); T.teleport(home + Vector3(6, 0, 0))
	_grt_out(k, home + Vector3(2.0, 0, 0))
	nf = m.fields.list.size()
	k.use_ability("k2", T.pos)
	_ac_run(m, 1.0)
	_grt("burrlet auto Spore Patch zone", m.fields.list.size() > nf and T.slow_t > 0.0 and T.hp < T.max_hp, "slow %.2f took %.0f" % [T.slow_t, T.max_hp - T.hp])
	_ac_run(m, 3.5)
	_grt_reset(T)
	k = _grt_kin(m, P, "zapple")
	_grt_out(k, home + Vector3(1.0, 0, 0))
	k.use_ability("k1", T.pos)
	_ac_run(m, 0.05)
	_grt("zapple E Echo Chain stuns", T.stun_t > 0.2 and T.hp < T.max_hp, "stun %.2f took %.0f" % [T.stun_t, T.max_hp - T.hp])
	_ac_run(m, 1.5)
	_grt_reset(T)
	k.stow()
	P.crit_t = 0.0
	k.use_ability("k2", P.pos)
	_grt("zapple auto Echolocate", T.reveal_t > 0.0 and P.crit_t > 0.0, "reveal %.1f crit %.1f" % [T.reveal_t, P.crit_t])
	_grt_reset(T)
	k = _grt_kin(m, P, "wisplet")
	var pa := P.pos
	k.use_ability("k1", T.pos)
	_ac_run(m, 0.6)
	_grt("wisplet E Moon Mark marks the foe, you stay", P.flat_dist(pa) < 0.05 and T.vuln_t > 0.0 and T.reveal_t > 0.0,
		"player moved %.2f" % P.flat_dist(pa))
	P.teleport(home); T.teleport(home + Vector3(6, 0, 0)); _grt_reset(T)
	_ac_run(m, 0.2)
	k.use_ability("k2", P.pos)
	_grt("wisplet auto Moonlift lifts you", P.vel.y > 8.0, "vel.y %.1f" % P.vel.y)
	_ac_run(m, 2.0)
	P.teleport(home); P.vel = Vector3.ZERO
	# the rare kin run too
	var rare_ok := true
	for sp in ["cairnback", "hivara", "zephyrak"]:
		k = _grt_kin(m, P, sp)
		_grt_out(k, home + Vector3(1.0, 0, 0))
		var a1 := k.use_ability("k1", T.pos)
		_ac_run(m, 1.0)
		_grt_out(k, home + Vector3(1.0, 0, 0))
		var a2 := k.use_ability("k2", T.pos if sp != "cairnback" else P.pos)
		_ac_run(m, 1.0)
		rare_ok = rare_ok and a1 and a2
		acc[sp] = "%s E %s auto %s, took %.0f" % [sp, a1, a2, T.max_hp - T.hp]
		_grt_reset(T)
	_grt("rare Boki abilities cast", rare_ok, "%s; %s; %s" % [acc["cairnback"], acc["hivara"], acc["zephyrak"]])
	P.teleport(home); T.teleport(home + Vector3(6, 0, 0)); _ac_run(m, 3.5); _grt_reset(T)
	# (a zephyrak gust can leave the dummy flying: put it back on its mark, at rest)
	T.teleport(home + Vector3(6, 0, 0)); T.vel = Vector3.ZERO; T.knock_t = 0.0; T.grounded = true; _ac_run(m, 0.2)
	# ---- 2. diminishing returns and stun immunity
	T.hurt(0.1, P, {"stun": 1.0, "dr": true})
	var s1 := T.stun_t
	_ac_run(m, 1.1)
	var imm := T.cc_immune_t
	T.hurt(0.1, P, {"stun": 1.0, "dr": true})
	var s2 := T.stun_t
	_ac_run(m, 1.0)
	T.hurt(0.1, P, {"stun": 1.0, "dr": true})
	var s3 := T.stun_t
	_grt("DR: full stun, then immunity", s1 > 0.95 and imm > 0.5 and s2 <= 0.0, "stun %.2f, immune %.2f, stun during immunity %.2f" % [s1, imm, s2])
	_grt("DR: next stun is shorter", s3 > 0.5 and s3 < 0.7, "%.2f" % s3)
	_ac_run(m, 1.6)
	T.hurt(0.1, P, {"root": 1.0, "dr": true})
	var r1 := T.root_t
	_ac_run(m, 1.1)
	T.hurt(0.1, P, {"root": 1.0, "dr": true})
	var r2 := T.root_t
	_grt("DR: repeated root gets shorter", r1 > 0.95 and r2 > 0.5 and r2 < 0.7, "%.2f then %.2f" % [r1, r2])
	_grt_reset(T)
	T.hurt(0.1, P, {"slow": 1.0, "dr": true})
	var sl1 := T.slow_t
	T.hurt(0.1, P, {"slow": 1.0, "dr": true})
	var sl1b := T.slow_t
	_ac_run(m, 1.1)
	T.hurt(0.1, P, {"slow": 1.0, "dr": true})
	var sl2 := T.slow_t
	_grt("DR: slow refresh free, new slow weaker", sl1 > 0.95 and sl1b > 0.95 and sl2 > 0.7 and sl2 < 0.8, "%.2f, refresh %.2f, then %.2f" % [sl1, sl1b, sl2])
	_grt_reset(T)
	# a zone that tries to stun every 0.25s can't keep anyone locked down
	k = _grt_kin(m, P, "burrlet")
	var zs := _grt_spec({"grammar": 1, "id": "grt_stun_zone", "name": "Test Zone", "trigger": {"type": "on_cast"},
		"stages": [{"delivery": {"type": "zone", "origin": "aim", "radius": 2.5, "duration": 4, "every": 0.25}, "effects": [{"type": "stun", "duration": 1.0}]}]})
	KinExec.cast(zs, KinExec.make_cx(m, P, k, P, T.pos, 1.0, "k1", zs.id))
	acc["st"] = 0.0
	_ac_run(m, 4.0, func(): if T.stun_t > 0.0: acc["st"] = float(acc["st"]) + Match.DT)
	_grt("DR: a stunning zone can't lock", float(acc["st"]) < 2.2, "stunned %.2fs of 4s" % acc["st"])
	_grt_reset(T)
	# ---- 3. no ability triggers itself
	var trig := _grt_spec({"grammar": 1, "id": "grt_on_hit", "name": "Test Trigger", "trigger": {"type": "on_hit", "every": 1}, "cue": {"type": "foe_in_range"},
		"stages": [{"delivery": {"type": "burst", "origin": "aim", "radius": 1.5}, "effects": [{"type": "damage", "amount": 5}]}]})
	k.runner.set_slot("k2", trig)
	_grt_out(k, home + Vector3(5.0, 0, 0))
	k.melee_n = 1
	var self_fire := k.fire_trigger("on_hit", {"at": T.pos, "chain": ["grt_on_hit"]})
	var real_fire := k.fire_trigger("on_hit", {"at": T.pos, "chain": []})
	k.stow()       # (so it doesn't swing at the target itself)
	var mel0 := k.melee_n
	_ac_run(m, 0.3)
	_grt("no self-trigger", not self_fire and real_fire and k.melee_n == mel0, "own hit fired=%s, melee hit fired=%s, its hits counted as melee %d" % [self_fire, real_fire, k.melee_n - mel0])
	_grt_reset(T)
	# ---- 4. caps
	m.verbs.add_mirror(P, {"time": 1.0, "radius": 1.6, "dmg_k": 3.0})
	m.verbs.add_mirror(T, {"time": 1.0, "radius": 1.6, "dmg_k": 3.0})
	var kmax := 0.0
	for mr in m.verbs.mirrors: kmax = maxf(kmax, float(mr["k"]))
	php = P.hp; thp = T.hp
	m.spawn_shot(T, T.pos + Vector3(-0.8, 0.95, 0), Vector2(-30, 0), 20.0, 0.6, 0.15, Color.RED, {})
	_ac_run(m, 0.8)
	_grt("reflect power capped at 1.5", kmax <= KinRules.REFLECT_MAX + 0.001, "%.2f" % kmax)
	_grt("a reflected shot isn't reflected again", P.hp >= php and T.hp < thp and T.hp > thp - 31.0, "shooter took %.0f, you took %.0f" % [thp - T.hp, php - P.hp])
	_ac_run(m, 0.5); _grt_reset(T)
	KinRules.mark(T, "vulnerable", 3.0, 0.6)
	var vh := T.hp
	T.hurt(100.0, null, {})
	_grt("vulnerable capped at +35%", is_equal_approx(T.vuln_k, 0.35) and absf((vh - T.hp) - 135.0) < 1.0, "k %.2f, 100 dmg -> %.0f" % [T.vuln_k, vh - T.hp])
	_grt_reset(T)
	var hook := KinLib.ability("stinger_hook")
	var big := KinLib.effective(hook, "k1", KinLib.kin("cindle"), {"level": 1}, 1, {"stage": 0, "scale": {"range": 9.0}})
	var rng0 := float(hook.stages[0].delivery.params["range"])
	var rng1 := float(big.stages[0].delivery.params["range"])
	_grt("merge scale clamped (x1.3 max)", rng1 <= rng0 * 1.3 + 0.01 and rng1 > rng0, "range %.1f -> %.1f" % [rng0, rng1])
	var hard := _grt_spec({"grammar": 1, "id": "grt_hard", "name": "Hard", "trigger": {"type": "on_cast"},
		"stages": [{"delivery": {"type": "burst", "radius": 2}, "effects": [{"type": "stun", "duration": 1.5}]}]})
	var hard3 := KinLib.effective(hard, "k1", null, {}, 3)
	_grt("ranks stay inside bounds", float(hard3.stages[0].effects[0].params["duration"]) <= 1.5, "stun %.2f at rank 3" % float(hard3.stages[0].effects[0].params["duration"]))
	var evo := KinLib.effective(hook, "k1", KinLib.kin("cindle"), {"level": 8, "forms": ["fierce", "fierce"]})
	_grt("evolution sidegrade applies", float(evo.stages[0].delivery.params["range"]) > rng0 and float(evo.stages[0].effects[4].params["duration"]) < 0.3,
		"range %.1f, stun %.2f" % [float(evo.stages[0].delivery.params["range"]), float(evo.stages[0].effects[4].params["duration"])])
	var pts := KinLib.points(KinLib.kin("cindle"), {"level": 8, "forms": ["fierce", "fierce"]})
	var tot := 0
	for kk in pts: tot += int(pts[kk])
	_grt("evolution stat shift is budget-neutral", tot == KinParts.STAT_BUDGET and int(pts["kin_damage"]) == 4, "%s" % pts)
	var many: Array = []
	for i in 20: many.append(T)
	var hc := {"n": 0}
	var cxh := KinExec.make_cx(m, P, null, P, T.pos, 0.0, "k1", "grt"); cxh["hits"] = hc
	KinExec._hit([], null, many, cxh, T.pos, 1.0)
	_grt("one delivery touches at most 12", int(hc["n"]) == KinParts.MAX_HITS, "%d" % int(hc["n"]))
	_grt("level growth capped by tier", is_equal_approx(KinRules.level_growth(30, 0), 0.15) and is_equal_approx(KinRules.level_growth(30, 2), 0.35), "")
	# ---- 5. slot locks and auto-cast
	k = _grt_kin(m, P, "cindle")
	P.slot_lv["kin"] = 0
	_grt_out(k, home + Vector3(1.0, 0, 0))
	var locked := not k.use_ability("k1", T.pos) and not k.use_ability("k2", T.pos)
	P.slot_lv["kin"] = 1
	_grt("locked Boki slot never casts", locked, "")
	k.target = T
	k.runner.reset()
	var used := {"k1": 0, "k2": 0}
	for i in 60:
		k.brain.think_t = 0.0
		var c1 := k.runner.charges("k1"); var c2 := k.runner.charges("k2")
		k.brain.think_abilities(0.1)
		if k.runner.charges("k1") < c1: used["k1"] += 1
		if k.runner.charges("k2") < c2: used["k2"] += 1
		k.runner.reset()
		_grt_out(k, home + Vector3(1.0, 0, 0)); k.target = T
	_grt("your out Boki casts both its abilities itself", int(used["k1"]) > 0 and int(used["k2"]) > 0, "ability %d, auto %d" % [used["k1"], used["k2"]])
	_ac_run(m, 1.0); _grt_reset(T)
	# ---- 6. carry modes
	k = _grt_kin(m, P, "pebbit")
	P.teleport(home); _ac_run(m, 0.1)
	var kb := P.vel.x
	P.impulse(Vector2(8, 0))
	var kbv := P.vel.x - kb
	_grt("big Boki on Return: at your side, -15% damage, half knockback",
		not P.mounted() and k.beside and is_equal_approx(P.owner_stat("damage_reduction"), 0.15),
		"kb %.1f, %.1f m away" % [kbv, P.flat_dist(k)])
	P.vel = Vector3.ZERO
	P.gliding = true
	P._refresh_kin_stats()
	_grt("big Boki curls up while you glide", not P.mounted() and P.owner_stat("damage_reduction") == 0.0, "")
	P.gliding = false
	P._refresh_kin_stats()
	var dashes0 := P.max_dashes()
	k = _grt_kin(m, P, "wisplet")
	P._refresh_kin_stats()
	_grt("perch extends your glide, never your dashes", P.gear_stat("heat") >= 0.19 and P.max_dashes() == dashes0, "glide +%.2f, dodges %.0f" % [P.gear_stat("heat"), P.max_dashes()])
	k.throw_cd = 0.0
	k.throw_to(T.pos)
	if k.hesitate_t > 0.0: k._launch(T.pos)
	var dive_y := k.pos.y - P.pos.y
	var dive: bool = k.fly.get("dive", false)
	_ac_run(m, 0.6)
	_grt("perch: its throw is a dive", dive and dive_y > 2.5 and T.stun_t > 0.0, "starts %.1fm up, target stun %.2f" % [dive_y, T.stun_t])
	_ac_run(m, 1.0); _grt_reset(T)
	k = _grt_kin(m, P, "cindle")
	P.teleport(home); T.teleport(home + Vector3(6, 0, 0)); P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	_ac_run(m, 0.1)
	P._emit_shot()
	_ac_run(m, 0.5)
	_grt("shoulder: shots poison (carry rider)", T.burn_t > 0.0, "burn %.1f" % T.burn_t)
	_grt_reset(T)
	# ---- 7. owner bonuses
	var base_hp := float(Data.CLASSES[P.cls]["hp"]) + float(P.get_meta("growth_hp", 0.0))        # (+ LevelGrowth)
	_grt("owner bonus: Vespyx +8 hp, +3% speed", is_equal_approx(P.max_hp, base_hp + 8.0) and absf(P.kin_pt("owner_move_speed") - 0.03) < 0.001, "max hp %.0f (base %.0f)" % [P.max_hp, base_hp])
	k = _grt_kin(m, P, "puddlet")
	_grt("owner bonus: Prismander shield + regen", is_equal_approx(P.kin_shield, 16.0) and absf(P.kin_pt("owner_regen") - 0.75) < 0.01 and is_equal_approx(P.max_hp, base_hp), "shield %.0f regen %.2f" % [P.kin_shield, P.kin_pt("owner_regen")])
	var hp0 := P.hp
	P.hurt(10.0, T, {})
	_grt("owner shield soaks the hit", P.hp >= hp0 - 0.05 and P.kin_shield < 16.0, "hp %.0f -> %.0f, shield %.0f" % [hp0, P.hp, P.kin_shield])
	# ---- 8. the merge: unlocks at level 6 with a free full meter, runs out, then a cooldown
	k = _grt_kin(m, P, "cindle")
	P.slot_lv["ult"] = 0; P.ult = 0.0; P.merge_free = true; P.skill_pts = 1; P.lvl = 5
	var early := P.level_slot("ult")
	P.lvl = 6
	var unl := P.level_slot("ult")
	_grt("merge unlocks at level 6, meter full", not early and unl and P.ult >= 1.0, "lvl5 %s, lvl6 %s, meter %.2f" % [early, unl, P.ult])
	var ok_cast := KinMerge.cast(P)
	var dur := float(P.merge_st.get("T", 0.0))
	var ms := KinMerge.def_for(k)
	_grt("merge casts: fused, timed, passives on", ok_cast and k.state == "fused" and is_equal_approx(dur, ms.duration) and P.owner_stat("damage") > 0.19,
		"%.1fs, damage +%.2f" % [dur, P.owner_stat("damage")])
	_ac_run(m, dur + float(MergeForm.data()["xform_s"]) + 0.3)       # (the transformation comes first, then the timer; no tiers: the length is fixed)
	_grt("merge ends on its timer, then cooldown", not KinMerge.active(P) and P.merge_cd > 0.0 and k.state == "shoulder" and not KinMerge.can_cast(P), "cd %.1f" % P.merge_cd)
	P.ult = 1.0
	var blocked := not KinMerge.can_cast(P)
	_ac_run(m, P.merge_cd + 0.1)        # (a timed-out merge rests the Boki timeout_rest_s, past the spent window)
	_grt("merge again after the cooldown", blocked and KinMerge.can_cast(P), "")
	KinMerge.cast(P)
	KinCommand.tap(P)
	_ac_run(m, 0.05)
	_grt("throwing ends the merge (throw still works)", not KinMerge.active(P) and k.state in ["flying", "active"], "Boki %s" % k.state)
	_ac_run(m, 1.0)
	k = _grt_kin(m, P, "cairnback")        # (a mount without a form of its own yet: the stat merge grows it giant; Gravadillo has the Heavy Star form)
	P.teleport(home); T.teleport(home + Vector3(2.0, 0, 0)); _grt_reset(T)
	P.ult = 1.0; P.merge_cd = 0.0
	KinMerge.cast(P)
	_grt("mount merge: giant under you", KinMerge.active(P) and not k.giant.is_empty() and k.state == "shoulder" and P.owner_stat("knockback_resist") > 0.49, "knockback resist %.2f" % P.owner_stat("knockback_resist"))
	_ac_run(m, 0.2)
	var ph := T.hp
	_ac_run(m, 2.4, func(): T.teleport(home + Vector3(2.0, 0, 0)); T.vel = Vector3.ZERO)
	_grt("merge pulses stomp around you", T.hp < ph, "took %.0f" % (ph - T.hp))
	KinMerge.end(P, "test")
	# IVs ride on top of the budget: final hp/damage/speed and the merge meter's fill (sizes are
	# normalized here, since two random Boki differ in size and size nudges hp and speed too)
	var was_norm := Unique.normalize
	Unique.normalize = true
	var lo := _grt_kin(m, P, "cindle", {"ivs": {"hp": 0, "atk": 0, "spd": 0, "work": 0, "bond": 0}})
	var lo_st := [lo.max_hp, lo.dmg, lo.speed]
	P.ult = 0.0; Bond.add(P, 0.1)
	var lo_b := P.ult
	var hi := _grt_kin(m, P, "cindle", {"ivs": {"hp": 31, "atk": 31, "spd": 31, "work": 31, "bond": 31}})
	P.ult = 0.0; Bond.add(P, 0.1)
	var hi_b := P.ult
	_grt("IVs: +10% hp/dmg, +5% speed at 31", absf(hi.max_hp / lo_st[0] - 1.1) < 0.005 and absf(hi.dmg / lo_st[1] - 1.1) < 0.005 and absf(hi.speed / lo_st[2] - 1.05) < 0.005,
		"hp %.0f/%.0f dmg %.1f/%.1f speed %.2f/%.2f" % [hi.max_hp, lo_st[0], hi.dmg, lo_st[1], hi.speed, lo_st[2]])
	Unique.normalize = was_norm
	_grt("IVs: Bond fills the merge meter 10% faster", absf(hi_b / lo_b - 1.1) < 0.005, "%.3f vs %.3f" % [hi_b, lo_b])
	m.queue_free(); await main.get_tree().process_frame
	print("GRT DONE, failures: ", _grt_fail)
	main.get_tree().quit(1 if _grt_fail > 0 else 0)
