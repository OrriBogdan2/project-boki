extends RefCounted
## Sable's (thief) and Juggernaut's checks, run inside --archetype-check and --kit-combo-check (the
## helpers come from tools/archetype_check.gd, passed in as A), or alone as --dancer-combo-check /
## --juggernaut-combo-check (tools/check_registry.gd). They assert what the hero sheets ask for: cursor
## landing, the telegraph while aiming or holding, the charge timings, the payoffs, and the merge holds.

const AKCheck := preload("res://tools/archetype_check.gd")
const ULT := preload("res://tools/dj_ult_check.gd")      # both heroes' ultimates on X, and the burst cap
const ZFEEL := preload("res://tools/zedran_feel_check.gd")   # Kael's chain, RMB rows, Meteor Drop and dashes
const DFEEL := preload("res://tools/dancer_feel_check.gd")   # Sable's Cartwheel, empowered bolt and reset (item 7)
const DPARITY := preload("res://tools/dancer_parity_check.gd")   # her LMB against the source (the parity pass)
const DTIMING := preload("res://tools/dancer_timing_check.gd")   # her animation timing against the source
const DLOOP := preload("res://tools/dancer_loop_check.gd")   # the Vault loop and the Bola's slow (item 53)
const HOLD := preload("res://tools/hold_release_check.gd")      # how Kael's RMB hold ends
const STRIKES := preload("res://tools/clip_strike_check.gd")   # her clip strikes on the kit's releases (anim timing)
const FLIP_TURN := [0.1, 0.3]   # s into her flip clips where the body turns (kmoves_dj.gd thf_vault_*)
const DTIME := preload("res://tools/thief_anim_time_check.gd")   # her moves' start, hit and end on the move clock
var a_x: AKCheck

## Standalone: one hero's sections (both for "all"). Prints AKCHECK lines like --archetype-check.
func run(main_node: Node, who := "all") -> void:
	WardenNative.contract_only = true  # (the contract path; Meshy-native Hunters: --warden-native-check)
	a_x = AKCheck.new()
	a_x.main = main_node
	if who in ["all", "thief"]:
		await thief(a_x)
		await load("res://tools/combo_mark_check.gd").new().run(a_x.ok, a_x, "thief")
	if who in ["all", "juggernaut"]:
		await juggernaut(a_x)
		await HOLD.kael(a_x)
		await load("res://tools/combo_mark_check.gd").new().run(a_x.ok, a_x, "juggernaut")
	await combos(a_x)
	print("AKCHECK DONE, %d checks, failures: %d" % [a_x.n, a_x.fails])
	main_node.get_tree().quit(1 if a_x.fails > 0 else 0)

# ------------------------------------------------------------------ Sable
func thief(a) -> void:
	a_x = a
	var r = a_x.setup("thief", 6.0, "", true)
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var t2: Hunter = r[3]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var k: ThiefKit = p_v.ak
	# parked clear of the Vault landing (~4.9 m): a shot now hits a body touching her
	t2.teleport(home + Vector3(0, 0, 8.0))
	a_x.ok("dancer: kit, model, Arc Bolts",
			k != null and p_v.model.get_meta("arch") == "thief" and p_v.wid == "arc_bolts"
			and Arch.name_of("thief") == "The Silver Thief",
			p_v.wid)
	a_x.ok("dancer: her moves are keyed (KMovesDJ)",
			["thf_lmb_r", "thf_lmb_l", "thf_primed", "thf_vault_r", "thf_vault_l", "thf_bola", "thf_knife",
					"thf_arrive", "thf_encore", "thf_encore_dance", "thf_exdash", "thf_land"]
			.all(func(mv): return not HunterAnim.km_sample(mv, 0.1).is_empty()))
	# LMB: a bolt every 0.45s from alternating hands, each one to the cursor
	p_v.fire_cd = 0.0
	var hands := []
	a_x.step(m, 1.0, func():
		p_v.inp["fire"] = true
		if hands.is_empty() or hands[-1] != k.hand: hands.append(k.hand))
	p_v.inp["fire"] = false
	a_x.step(m, 0.5)
	a_x.ok("dancer LMB: a bolt every 0.45s while held, hands alternating",
			k.bolts == 3 and hands.size() >= 3, "bolts %d hands %s" % [k.bolts, str(hands)])
	a_x.ok("dancer LMB: bolts hit and stack Marks (one per hit)",
			a_x.dmg(t_v) >= 20.0 and k.marks_on(t_v) == 3, "took %.0f marks %d" % [a_x.dmg(t_v), k.marks_on(t_v)])
	var hv := HeroVfx.of(m)
	a_x.ok("dancer LMB: every bolt flies under its cel tracer and every hit plays her lit burst (thief.json)",
			int(hv.plays.get("bolt_trail", 0)) == 3 and int(hv.plays.get("bolt_hit", 0)) == 3,
			"trails %d hits %d" % [hv.plays.get("bolt_trail", 0), hv.plays.get("bolt_hit", 0)])
	a_x.ok("dancer LMB: the aim line is pale lilac",
			AimKit.shown(p_v, "aim") and (AimKit.entry(p_v, "aim")["col"] as Color).is_equal_approx(ThiefKit.AIM_LILAC))
	# a bolt with nothing in its way flies its full range whatever the cursor (--tester-feedback-check)
	a_x.aim_at(p_v, home + Vector3(-30.0, 0, 0))
	p_v.fire_cd = 0.0
	var fz := k.fizzles
	p_v.inp["fire"] = true
	m.step(a_x.DT)
	p_v.inp["fire"] = false
	var flight := 0.0
	while k.fizzles == fz and flight < 1.0:
		m.step(a_x.DT)
		flight += a_x.DT
	a_x.step(m, 0.4)
	var rng := float(p_v.wpn["range"])
	var reach := Vector2(k.last_bolt_end.x - p_v.pos.x, k.last_bolt_end.z - p_v.pos.z).length()
	a_x.ok("dancer LMB: clamped to 8.5m (the source's 850 units)",
			absf(rng - 8.5) < 0.01 and absf(reach - rng) < 0.8, "%.1f m of %.1f" % [reach, rng])
	a_x.ok("dancer LMB: flight time, 37.5 m/s over its range (0.23s)",
			absf(float(p_v.wpn["speed"]) - 37.5) < 0.01 and absf(flight - rng / 37.5) < 0.08, "%.2fs" % flight)
	p_v.dashes = p_v.max_dashes()
	p_v.inp["move"] = Vector2(0, 1)
	p_v.do_dash()
	a_x.step(m, 0.55)
	p_v.inp["move"] = Vector2.ZERO
	for b in m.breaks:
		b["dead"] = true        # a crate in the long bolt's path would stop it short of 9.5 m
	a_x.aim_at(p_v, p_v.pos + Vector3(-30.0, 0, 0))
	p_v.fire_cd = 0.0
	p_v.inp["fire"] = true
	m.step(a_x.DT)
	p_v.inp["fire"] = false
	var haste_after := k.haste_t
	a_x.step(m, 0.6)
	var ed := Vector2(k.last_bolt_end.x - p_v.pos.x, k.last_bolt_end.z - p_v.pos.z).length()
	a_x.ok("dancer small mechanics: the empowered bolt flies 12% further (9.5m); firing it ends the speed",
			k.last_bolt_emp and absf(ed - rng * 1.12) < 0.9 and haste_after <= 0.0,
			"%.1f m haste %.2f" % [ed, haste_after])
	a_x.ok("dancer LMB: each bolt has its own pooled look",
			DJFx.of(m).free_pools.has("ride_chakram") and DJFx.of(m).free_pools.has("puff"))
	# Marks: a flat +1.3 per Mark on bolts only (the data's +16 a stack on its 160 shot), no cap
	a_x.fresh(t_v)
	k.mark_gap = {}
	k.add_mark(t_v, 2, true)
	a_x.ok("dancer passive: a flat +1.3 per Mark on bolts only, whatever the bolt deals",
			absf(k.outgoing(t_v, 10.0, {"src": "shot"}) - 12.6) < 0.01
			and absf(k.outgoing(t_v, 30.0, {"src": "shot"}) - 32.6) < 0.01
			and absf(k.outgoing(t_v, 10.0, {"src": "abil", "ab": "utility"}) - 10.0) < 0.01,
			"%.2f" % k.outgoing(t_v, 10.0, {"src": "shot"}))
	k.on_deal(t_v, 5.0, {"src": "abil", "ab": "utility"})
	a_x.ok("dancer passive: ability hits don't stack", k.marks_on(t_v) == 2)
	k.add_mark(t_v, 20, true)
	a_x.ok("dancer passive: Marks have no cap (22 after 20 more), eight diamonds show",
			k.marks_on(t_v) == 22 and k.res_text() == "22" and k.pip_count() == 8 and k.res_frac() == 1.0, k.res_text())
	a_x.ok("dancer passive: 22 Marks add 28.6 to a bolt", absf(k.outgoing(t_v, 13.0, {"src": "shot"}) - 41.6) < 0.01)
	# Vault ranks: empowered +20% at rank 2 and again at rank 3, the speed boost half again as big at rank 3
	var vault_ranks: Array = []
	for rk in [1, 2, 3]:
		p_v.slot_lv["dash"] = rk
		vault_ranks.append([k.prime_rank_k(), k.vault_haste()])
	p_v.slot_lv["dash"] = 1
	a_x.ok("dancer Vault ranks: empowered +20% / +40%, speed boost 0.18 -> 0.27 at rank 3",
			absf(float(vault_ranks[0][0]) - 1.0) < 0.001 and absf(float(vault_ranks[1][0]) - 1.2) < 0.001
			and absf(float(vault_ranks[2][0]) - 1.4) < 0.001 and absf(float(vault_ranks[1][1]) - 0.18) < 0.001
			and absf(float(vault_ranks[2][1]) - 0.27) < 0.001, str(vault_ranks))
	# upgrade parity (docs/heroes/thief.md): the source's tier II / III+IV numbers per slot
	var tp: Array = []
	for rk in [1, 2, 3]:
		p_v.slot_lv["sec"] = rk
		p_v.slot_lv["dash"] = rk
		p_v.slot_lv["kin"] = rk
		tp.append([k.rmb_def()["cooldown"] * k.cd_k("sec"), k.power("sec"), k.dash_def()["cd"] * k.dash_k(),
				k.e_def()["cooldown"] * k.cd_k("kin"), k.power("kin")])
	p_v.slot_lv["sec"] = 1
	p_v.slot_lv["dash"] = 1
	p_v.slot_lv["kin"] = 1
	a_x.ok("upgrade parity: Bola damage +50% from rank 2 and the cooldown 7 -> 4.8 only at rank 3",
			absf(float(tp[1][1]) / float(tp[0][1]) - 1.5) < 0.01
			and absf(float(tp[2][1]) / float(tp[0][1]) - 1.5) < 0.01
			and absf(float(tp[1][0]) - 7.0) < 0.01 and absf(float(tp[2][0]) - 4.85) < 0.05, str(tp))
	a_x.ok("upgrade parity: Vault recharge stays 5 (Quickflip 5s, no cooldown upgrade)",
			absf(float(tp[1][2]) - 5.0) < 0.01 and absf(float(tp[2][2]) - 5.0) < 0.01, str(tp))
	a_x.ok("upgrade parity: Shadow Knife cooldown 15 -> 10.7 from rank 2 (the source's -8s of 28), no damage step",
			absf(float(tp[1][3]) - 10.71) < 0.05 and absf(float(tp[2][3]) - 10.71) < 0.05
			and absf(float(tp[2][4]) / float(tp[0][4]) - 1.0) < 0.01, str(tp))
	# Vault: a cartwheel, speed, the next bolt empowered; it lands for 3.5x and the Vault comes back
	a_x.fresh(t_v)
	p_v.teleport(home)
	p_v.dashes = p_v.max_dashes()
	a_x.aim_at(p_v, t_v.pos)
	var d0 := p_v.dashes
	var rings0 := _dancer_rings(m)
	var v := HeroVfx.of(m)
	var played := [int(v.plays.get("dash", 0)), int(v.plays.get("flip", 0))]
	var older := v.ribbons.duplicate()                  # trails of earlier moves (not this flip's)
	p_v.inp["move"] = Vector2(0, 1)
	p_v.do_dash()
	var wheel := k.anim_id
	var pop := [0.0]           # an Array: a lambda can't assign a captured local
	var live := {"before": 0, "mid": 0, "after": 0}      # steps her flip trail (data "flip") draws, by turn phase
	var flipped := [0.0]       # how far the flip itself carried her: the run after it (keys held) is not the Cartwheel
	a_x.step(m, 0.55, func():
		pop[0] = maxf(pop[0], k.glint_pop)
		if p_v.roll_t <= 0.0 and flipped[0] == 0.0:
			flipped[0] = p_v.flat_dist(home)
		var at: float = m.time - k.anim_at
		var key := "after"
		if at < FLIP_TURN[0]: key = "before"
		elif at < FLIP_TURN[1]: key = "mid"
		var mine := func(e): return (e["h"] == p_v and String(e["anchor"]) in ["hand_r", "foot_l"]
				and not older.any(func(o): return is_same(o, e)))
		if v.ribbons.any(mine):
			live[key] = int(live[key]) + 1)
	p_v.inp["move"] = Vector2.ZERO
	a_x.ok("dancer dash: her violet after-images and the flip's hand and foot trail are data (content/vfx/thief.json)",
			int(v.plays.get("dash", 0)) == played[0] + 1 and int(v.plays.get("flip", 0)) == played[1] + 1,
			"%s -> %s" % [played, [v.plays.get("dash", 0), v.plays.get("flip", 0)]])
	a_x.ok("dancer dash: the flip leaves a trail that follows the turn, none before it starts; it fades out after",
			live["before"] == 0 and live["mid"] >= 6, str(live))
	a_x.ok("dancer dash (item 8): no ring on the cartwheel or its landing; the glint in the throwing hand flares",
			_dancer_rings(m) == rings0 and pop[0] > 0.5 and k.glint != null and k.glint.visible
			and k.glint.global_position.distance_to(k.hand_pos(k.hand == 0)) < 0.15,
			"rings %d -> %d pop %.2f glint %s" % [rings0, _dancer_rings(m), pop[0],
					k.glint.global_position.distance_to(k.hand_pos(k.hand == 0)) if k.glint else -1.0])
	var far := 4.5        # the sheet's measured 4.5m (she is off the global dash feel)
	a_x.ok("dancer dash: Vault cartwheels about 4.5m, speeds +18%, empowers",
			absf(flipped[0] - far) < 0.6 and k.primed_t > 0.0 and k.speed_bonus() > 0.15
			and p_v.dashes < d0 - 0.5 and wheel in ["thf_vault_l", "thf_vault_r"],
		"flip %.1f (to 0.55 s %.1f) primed %.2f anim %s" % [flipped[0], p_v.flat_dist(home), k.primed_t, wheel])
	var gold: Dictionary = AimKit.entry(p_v, "aim")
	a_x.ok("dancer dash: the aim line turns solid gold, thick, with a glow while empowered",
			(gold.get("col", Color.WHITE) as Color).is_equal_approx(ThiefKit.EMP_LINE)
			and float(gold.get("lw", 0.0)) >= 0.09
			and float(gold.get("hot", 1.0)) == 0.0 and AimKit.shown(p_v, "aim_glow"))
	a_x.ok("dancer HUD: dash dot while empowered",
			k.dash_payoff_ready() and p_v.slot_info("dash").get("full", false)
			and not p_v.slot_info("sec").get("full", false))
	a_x.fresh(t_v)
	a_x.aim_at(p_v, t_v.pos)
	p_v.fire_cd = 0.0
	p_v.inp["fire"] = true
	m.step(a_x.DT)
	p_v.inp["fire"] = false
	a_x.ok("dancer empowered bolt: the big look rides it",
			k.last_bolt_emp and DJFx.of(m).free_pools.has("ride_chakram_big"))
	a_x.step(m, 0.5)
	a_x.ok("dancer empowered bolt: a big hit, 2 Marks (the owner's faster stacking), no Shred, speed ends, Vault back",
			a_x.dmg(t_v) >= 18.0 and k.marks_on(t_v) == 2 and t_v.vuln_t <= 0.0 and k.move_k() <= 1.0
			and p_v.dashes >= p_v.max_dashes() - 0.01 and k.primed_t <= 0.0 and k.primed_hits == 1,
		"dealt %.0f marks %d vuln %.1f dashes %.2f" % [a_x.dmg(t_v), k.marks_on(t_v), t_v.vuln_t, p_v.dashes])
	# from a jump the cartwheel (the ground one with a charge, item 183) carries on to the landing under the air's
	# drag: further than on the ground
	a_x.step(m, 0.5)
	p_v.teleport(home)
	p_v.dashes = p_v.max_dashes()
	t_v.teleport(home + Vector3(0, 0, 5.0))
	p_v.do_jump()
	a_x.step(m, 0.1)
	p_v.inp["move"] = Vector2(1, 0)
	p_v.do_dash()
	p_v.inp["move"] = Vector2.ZERO
	var air_move := k.anim_id
	var air_rings := _dancer_rings(m)
	var landed := [false]
	a_x.step(m, 2.4, func(): landed[0] = landed[0] or k.anim_id == "thf_land")
	a_x.ok("dancer dash: from a jump the cartwheel carries its speed on to the landing (further than on the ground)",
			p_v.flat_dist(home) > far * 1.1 and p_v.grounded and k.vault.is_empty(), "moved %.1f" % p_v.flat_dist(home))
	a_x.ok("dancer air dash (items 32, 35): the air Cartwheel, empowered by its row, lands in thf_land, no ring",
			air_move == "thf_exdash" and landed[0] and k.primed_t > 0.0
			and _dancer_rings(m) == air_rings, "move %s landed %s primed %.2f" % [air_move, landed[0], k.primed_t])
	_dancer_dash_moves(k)
	k.primed_t = 0.0
	k.haste_t = 0.0
	p_v.teleport(home)
	t_v.teleport(home + Vector3(6.0, 0, 0))
	# RMB: a 0.4s wind-up with the lane showing, then the Bola grounds the first, flies on, tangles a second
	a_x.fresh(t_v)
	a_x.fresh(t2)
	t_v.teleport(home + Vector3(4.0, 0, 0))
	t2.teleport(home + Vector3(7.0, 0, 0))
	p_v.teleport(home)
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	a_x.aim_at(p_v, t_v.pos)
	a_x.tap(m, p_v)
	a_x.step(m, 0.2)
	var bl: Dictionary = AimKit.entry(p_v, "rmb")
	a_x.ok("dancer RMB: the lane shows through the 0.4s wind-up (about 1 bh by 6 bh), nothing thrown yet",
			AimKit.shown(p_v, "rmb") and absf(float(bl.get("len", 0.0)) - 10.8) < 0.1 and k.bola.is_empty()
			and a_x.dmg(t_v) <= 0.0,
			"len %.1f" % float(bl.get("len", 0.0)))
	a_x.ok("dancer RMB telegraph: the lane is drawn as wide as it catches (rmb.bola.lane_w, the parity 1.8 m)",
			absf(float(bl.get("width", 0.0)) - float(k.rmb_def()["bola"]["lane_w"])) < 0.01,
			"width %.2f" % float(bl.get("width", 0.0)))
	a_x.step(m, 0.6)
	a_x.ok("dancer RMB: Bola grounds the first, flies on, tangles two (stun)",
			k.bola_pairs == 1 and KitStatus.grounded(t_v) and KitStatus.grounded(t2) and t_v.stun_t > 0.0
			and t2.stun_t > 0.0 and a_x.dmg(t_v) >= 9.0,
		"pairs %d grounded %s/%s stun %.2f/%.2f dmg %.0f" % [k.bola_pairs, KitStatus.grounded(t_v),
				KitStatus.grounded(t2), t_v.stun_t, t2.stun_t, a_x.dmg(t_v)])
	# pair stun 0.9 s (docs/heroes/thief.md "Pair stun length"): the footage has no two-foe tie to time
	var pst := float(k.rmb_def()["bola"]["pair_stun"])
	a_x.ok("dancer RMB: the pair stun is 0.9s in data and neither foe is held longer",
			absf(pst - 0.9) < 1e-6 and t_v.stun_t > 0.0 and t_v.stun_t <= pst + 1e-3
			and t2.stun_t > 0.0 and t2.stun_t <= pst + 1e-3,
			"pair_stun %.2f stun %.2f/%.2f" % [pst, t_v.stun_t, t2.stun_t])
	a_x.ok("dancer RMB: yellow binding rings on the Grounded (everyone sees them)",
			AimKit.shown(p_v, "gnd%d" % t_v.get_instance_id())
			and bool(AimKit.entry(p_v, "gnd%d" % t_v.get_instance_id()).get("all", false)))
	t_v.stun_t = 0.0
	t_v.dashes = 1.0
	t_v.do_dash()
	t_v.do_jump()
	m.step(a_x.DT)
	a_x.ok("dancer Bola: Grounded can't dash or jump",
			t_v.dashes >= 0.99 and t_v.roll_t <= 0.0 and t_v.vel.y < 1.0, "dashes %.2f vy %.1f" % [t_v.dashes,
					t_v.vel.y])
	a_x.step(m, 2.0)
	_bola_edge(a_x, m, p_v, k, t_v, t2, home)
	# ... it bounces once off a wall
	var w = m.world
	for dz in range(-3, 4):
		for dx in range(-7, -5):
			w.level[w.idx(int(home.x) + dx, int(home.z) + dz)] = lv + 3
	p_v.teleport(home)
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	a_x.aim_at(p_v, home + Vector3(-6.0, 0, 0))
	a_x.tap(m, p_v)
	a_x.step(m, 0.9)
	a_x.ok("dancer Bola: bounces off a wall", k.bola_bounces == 1, "bounces %d" % k.bola_bounces)
	# small mechanic: a crate counts as the Bola's first catch (it breaks and flies on its after-distance)
	a_x.step(m, 1.0)
	p_v.teleport(home)
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	a_x.aim_at(p_v, home + Vector3(0, 0, -6.0))
	m._add_break("crate", home + Vector3(0, 0, -2.5))
	a_x.tap(m, p_v)
	a_x.step(m, 0.6)
	a_x.ok("dancer Bola small mechanic: a crate counts as the first catch, it flies on",
			k.bola_breaks == 1, "breaks %d" % k.bola_breaks)
	# E: the dagger to the cursor (no foe on the way), the arrival circle, recast blinks through afterimages
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(4.0, 0, 3.0))
	p_v.teleport(home)
	k.cd["e"] = 0.0
	var kspot := home + Vector3(5.0, 0, -2.0)
	t2.teleport(home + Vector3(-5.0, 0, 5.0))
	a_x.aim_at(p_v, kspot)
	var shots0: int = m.shots.size()
	p_v.ak.use_e()
	a_x.step(m, ThiefKit.KNIFE_RELEASE_S - 0.03)
	var early: bool = m.shots.size() > shots0
	a_x.step(m, 0.06)
	a_x.ok("dancer E: the knife leaves the hand on the throw's key pose (0.12s), not before",
			not early and m.shots.size() > shots0 and k.anim_id == "thf_knife"
			and absf(float(HunterAnim.km_sample("thf_knife", ThiefKit.KNIFE_RELEASE_S)["fy"]) + TAU) < 0.01,
			"early %s shots %d" % [str(early), m.shots.size() - shots0])
	a_x.step(m, 0.5)
	a_x.ok("dancer E: the dagger lands at the cursor, RecastCue's marker on it",
			not k.knife.is_empty() and k.knife.get("target") == null
			and Vector2((k.knife["pos"] as Vector3).x - kspot.x, (k.knife["pos"] as Vector3).z - kspot.z).length() < 1.0
			and k.recast_window().get("at") == k.knife["pos"],
		"%s vs %s" % [str(k.knife.get("pos", Vector3.ZERO)), str(kspot)])
	p_v.ak.use_e()
	m.step(a_x.DT)
	a_x.ok("dancer E recast: a blink to it with an afterimage chain, arriving in her own low drop",
			k.blinks == 1 and k.anim_id == "thf_arrive" and Vector2(p_v.pos.x - kspot.x,
					p_v.pos.z - kspot.z).length() < 1.2
			and (DJFx.of(m).free_pools.get("ghost", []) as Array).size() >= 5,
			"blinks %d" % k.blinks)
	# ... into a foe: it sticks (slows), recast steps behind them; left alone it steps you there after 6s
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(5.0, 0, 0))
	p_v.teleport(home)
	k.cd["e"] = 0.0
	a_x.aim_at(p_v, t_v.pos)
	p_v.ak.use_e()
	a_x.step(m, 0.35)
	a_x.ok("dancer E: the dagger sticks in a foe (slow 50%, damage)",
			not k.knife.is_empty() and k.knife.get("target") == t_v and t_v.slow_t > 0.0 and a_x.dmg(t_v) >= 7.0,
			"slow %.2f dmg %.0f" % [t_v.slow_t, a_x.dmg(t_v)])
	a_x.step(m, 6.1)
	a_x.ok("dancer E: waiting 6s steps you to it anyway",
			p_v.flat_dist(t_v) < 1.8 and k.knife.is_empty(), "dist %.1f" % p_v.flat_dist(t_v))
	_knife_in_barriers(m, a_x, p_v, t_v, k, home)
	# a knock heals a quarter (20% passive, 5% from the takedown reset) in all, the data's 25%; the crimson star
	# and the green pillar
	p_v.hp = p_v.max_hp * 0.5
	var php := p_v.hp
	t_v.hp = 4.0
	t_v.hurt(10.0, p_v, {"src": "shot"})
	a_x.step(m, 0.1)
	a_x.ok("dancer passive: a knock heals (25% in all), star + pillar",
			t_v.downed and k.knocks_seen >= 1 and absf(p_v.hp - php - p_v.max_hp * 0.25) <= p_v.max_hp * 0.01
			and DJFx.of(m).free_pools.has("pillar")
			and DJFx.of(m).free_pools.has("star"),
			"hp %.0f -> %.0f" % [php, p_v.hp])
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(5.0, 0, 0))
	t_v.downed = false
	a_x.step(m, 1.4, func():
		p_v.inp["fire"] = true
		a_x.aim_at(p_v, t_v.pos))
	p_v.inp["fire"] = false
	a_x.step(m, 0.4)
	var made := DJFx.of(m).made
	a_x.step(m, 1.4, func():
		p_v.inp["fire"] = true
		a_x.aim_at(p_v, t_v.pos))
	p_v.inp["fire"] = false
	a_x.step(m, 0.4)
	var capped := DJFx.of(m).free_pools.values().all(func(arr): return (arr as Array).size() <= DJFx.POOL_CAP)
	a_x.ok("dancer fx: pooled (every kind capped, a handful of nodes at most per burst)",
			capped and DJFx.of(m).made <= made + 6, "made %d -> %d" % [made, DJFx.of(m).made])
	_dancer_dash_flow(m, p_v, k, t_v, home)
	DFEEL.new().run(a_x, m, p_v, k, t_v, home)
	DPARITY.new().run(a_x, m, p_v, k, t_v, home)
	DTIMING.new().run(a_x, m, k)
	DLOOP.new().run(a_x, m, p_v, k, t_v, t2, home)
	STRIKES.new().run(a_x, a_x.main, "thief", {"thf_lmb_r": 0.0, "thf_lmb_l": 0.0, "thf_primed": 0.0,
			"thf_bola": float(k.rmb_def()["bola"]["cast"]), "thf_knife": ThiefKit.KNIFE_RELEASE_S},
			{"thf_bola": 0.2})        # (the bolas are raised overhead in the first frames; the sling is the throw)
	DTIME.new(a_x).run(m, p_v, k, t_v, home)
	await a_x.done(m)
	await _growth()
	await ULT.new().dancer(a_x)
	await ULT.new().dancer_ring(a_x)



## Drawn = hit for the Bola: the lane is the catch corridor for a foe of her size, so a foe whose body is just inside
## the lane's reach past it is caught and one just outside is not.
func _bola_edge(a_v, m: Match, p_v: Hunter, k, t_v: Hunter, t2: Hunter, home: Vector3) -> void:
	var reach := float(k.rmb_def()["bola"]["lane_w"]) * 0.5 - p_v.r
	a_v.fresh(t_v)
	a_v.fresh(t2)
	p_v.teleport(home)
	t_v.teleport(home + Vector3(3.0, 0, t_v.r + reach - 0.08))
	t2.teleport(home + Vector3(5.0, 0, -t2.r - reach - 0.08))
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	a_v.aim_at(p_v, home + Vector3(8.0, 0, 0))
	a_v.tap(m, p_v)
	a_v.step(m, 0.8)
	a_v.ok("dancer RMB telegraph: a foe just inside the lane's edge is caught, one just outside is not",
			KitStatus.grounded(t_v) and not KitStatus.grounded(t2), "in %s out %s" % [KitStatus.grounded(t_v),
			KitStatus.grounded(t2)])
	a_v.step(m, 1.8)


## Rings in Sable's own colours alive now (the shared team-colour dash ring is Hunter's, not hers).
func _dancer_rings(m: Match) -> int:
	var res_col := Color(Arch.def("thief")["resource"]["col"])
	var cols := [ThiefKit.AIM_LILAC, ThiefKit.EMP_LINE, Arch.color("thief"), res_col]
	var n := 0
	for rg in m.fx.rings:
		for c in cols:
			if (rg["col"] as Color).is_equal_approx(c): n += 1
	return n

## Item 35: her dash moves are her own (no other table has them) and fit inside their dashes.
func _dancer_dash_moves(k: ThiefKit) -> void:
	var dd: Dictionary = Arch.def("thief")["dash"]
	var feel_t := float(k.dash_feel()["time"])
	var others := [HunterAnim.KMOVES, KMovesPair.MOVES, KMovesVV.MOVES, KMovesStone.MOVES, MergeMoves.MOVES,
			KMovesCare.MOVES, KMovesPin.MOVES, KMovesBjorn.MOVES]
	var own := true
	for mv in ThiefKit.CARTWHEELS:
		own = own and KMovesDJ.MOVES.has(mv) and others.all(func(t): return not (t as Dictionary).has(mv))
	var ground_len := maxf(_move_len("thf_vault_r"), _move_len("thf_vault_l"))
	var air_len := _move_len("thf_exdash")
	a_x.ok("dancer dash moves (item 35): her own ids; the ground and air cartwheels fit inside their dash",
			own and ground_len <= float(dd["time"]) * feel_t + 0.005 and air_len <= float(dd["time"]) * feel_t + 0.005,
			"ground %.2f air %.2f / %.2f" % [ground_len, air_len, float(dd["time"]) * feel_t])

func _move_len(mv: String) -> float:
	var keys: Array = KMovesDJ.MOVES[mv]["keys"]
	return float(keys[-1][0])

## E into a placed barrier (a Verbs wall: rock, ice, shield): the dagger sticks, rides it, drops under it when it
## breaks, the 6s return stays, and the blink lands beside it on her side, never inside.
func _knife_in_barriers(m, a_v, p_v, t_v, k, home: Vector3) -> void:
	t_v.teleport(home + Vector3(0, 0, 9.0))
	var wd := {"time": 30.0, "hp": 500.0, "move": true, "length": 4.0}
	var at := home + Vector3(5.0, 0, 0)
	var w: Dictionary = m.verbs.add_wall(t_v, at, Vector2(1, 0), wd, 1.0)
	p_v.teleport(home)
	k.cd["e"] = 0.0
	a_v.aim_at(p_v, at + Vector3(0, 0.9, 0))
	p_v.ak.use_e()
	a_v.step(m, 0.4)
	a_v.ok("dancer E: the dagger sticks to a barrier it hits, on her side of it",
			k.knife.get("wall") == w and k.knife.get("target") == null and p_v.pos.x < at.x
			and absf((k.knife["pos"] as Vector3).x - at.x) < 0.7
			and k.recast_window().get("at") == k.knife["pos"],
			"knife %s" % str(k.knife.get("pos", Vector3.ZERO)))
	var z0: float = (k.knife["pos"] as Vector3).z
	w["a"] += Vector2(2.0, 3.0)
	w["b"] += Vector2(2.0, 3.0)
	a_v.step(m, 0.1)
	var kp: Vector3 = k.knife["pos"]
	a_v.ok("dancer E: the stuck dagger rides its barrier when it moves",
			k.knife.get("wall") == w and absf(kp.z - z0 - 3.0) < 0.1
			and absf(kp.x - at.x - 2.0) < 0.7, "moved %.2f" % (kp.z - z0))
	a_v.step(m, 6.0)
	var near := Geometry2D.get_closest_point_to_segment(Vector2(p_v.pos.x, p_v.pos.z), w["a"], w["b"])
	var gap := Vector2(p_v.pos.x, p_v.pos.z).distance_to(near)
	a_v.ok("dancer E: after 6s the return puts her beside it on her side, never inside",
			k.knife.is_empty() and p_v.pos.x < at.x + 2.0 and gap >= float(w["th"]) + p_v.r
			and m.world.occupy(p_v.pos.x, p_v.pos.z, p_v.r, p_v.pos.y, false) == 0.0, "gap %.2f" % gap)
	m.verbs.clear()
	# it breaks (here: runs out) with the dagger in it: the dagger lies on the ground under it
	w = m.verbs.add_wall(t_v, at, Vector2(1, 0), {"time": 0.5, "hp": 500.0, "move": true, "length": 4.0}, 1.0)
	p_v.teleport(home)
	k.cd["e"] = 0.0
	a_v.aim_at(p_v, at + Vector3(0, 0.9, 0))
	p_v.ak.use_e()
	a_v.step(m, 0.4)
	var stuck: bool = k.knife.get("wall") == w
	a_v.step(m, 0.4)
	a_v.ok("dancer E: the barrier broke: the dagger drops to the ground under it",
			stuck and not m.verbs.walls.has(w) and not k.knife.is_empty() and not k.knife.has("wall")
			and absf((k.knife["pos"] as Vector3).y - m.world.ground_at(at.x, at.z)) < 0.05
			and absf((k.knife["pos"] as Vector3).x - at.x) < 0.7, "knife %s" % str(k.knife.get("pos", Vector3.ZERO)))
	p_v.ak.use_e()
	m.step(a_v.DT)
	a_v.ok("dancer E: ... and she steps to it", k.knife.is_empty()
			and Vector2(p_v.pos.x - at.x, p_v.pos.z - at.z).length() < 1.5)
	m.verbs.clear()

## Item 32: a bolt pressed mid-cartwheel goes at once, empowered, and the cartwheel isn't cut; Shift in the Bola's
## wind-up cartwheels and the Bola still flies; the dagger's blink ends a cartwheel.
func _dancer_dash_flow(m: Match, p_v: Hunter, k: ThiefKit, t_v: Hunter, home: Vector3) -> void:
	k.primed_t = 0.0
	k.haste_t = 0.0
	a_x.step(m, 0.3)
	p_v.teleport(home)
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(-6.0, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	p_v.dashes = p_v.max_dashes()
	p_v.fire_cd = 0.0
	var bolts0 := k.bolts
	p_v.inp["move"] = Vector2(0, 1)
	p_v.do_dash()
	a_x.step(m, 0.08)
	p_v.inp["fire"] = true
	m.step(a_x.DT)
	p_v.inp["fire"] = false
	a_x.ok("dancer dash -> LMB (row: fire, empowered): the bolt leaves mid-flip, empowered; the cartwheel plays on",
			k.bolts == bolts0 + 1 and k.last_bolt_emp and p_v.roll_t > 0.0 and k.anim_id in ThiefKit.CARTWHEELS,
			"bolts %d emp %s roll %.2f anim %s" % [k.bolts - bolts0, k.last_bolt_emp, p_v.roll_t, k.anim_id])
	a_x.step(m, 0.6)
	p_v.inp["move"] = Vector2.ZERO
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	p_v.dashes = p_v.max_dashes()
	a_x.tap(m, p_v)
	a_x.step(m, 0.1)
	p_v.inp["move"] = Vector2(0, 1)
	p_v.do_dash()
	var wound := not k.bola_cast.is_empty() and p_v.roll_t > 0.0
	var thrown := [false]
	a_x.step(m, 0.4, func(): thrown[0] = thrown[0] or not k.bola.is_empty())
	p_v.inp["move"] = Vector2.ZERO
	a_x.ok("dancer RMB -> dash (into_dash row: fire): Shift in the wind-up cartwheels, the Bola still flies",
			wound and thrown[0], "wound %s thrown %s" % [wound, thrown[0]])
	a_x.step(m, 1.0)
	p_v.teleport(home)
	k.cd["e"] = 0.0
	a_x.aim_at(p_v, home + Vector3(4.0, 0, -2.0))
	k.use_e()
	a_x.step(m, 0.4)
	var blinks0 := k.blinks
	p_v.dashes = p_v.max_dashes()
	p_v.inp["move"] = Vector2(0, 1)
	p_v.do_dash()
	a_x.step(m, 0.06)
	k.use_e()
	m.step(a_x.DT)
	p_v.inp["move"] = Vector2.ZERO
	a_x.ok("dancer dash -> E recast: the blink ends the cartwheel (she arrives standing)",
			k.blinks == blinks0 + 1 and p_v.roll_t <= 0.0 and k.vault.is_empty(),
			"blinks +%d roll %.2f vault %s" % [k.blinks - blinks0, p_v.roll_t, k.vault])
	k.primed_t = 0.0
	k.haste_t = 0.0
	a_x.step(m, 0.5)

## An Encore blade's damage on the first foe with the hunter at level `lvl`.
func _blade(lvl: int) -> float:
	var r = a_x.setup("thief", 6.0)
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var k: ThiefKit = p_v.ak
	p_v.lvl = lvl
	p_v.set_meta("growth_lvl", lvl)       # growth follows levels gained; a level set straight grows nothing
	a_x.fresh(t_v)
	k.encore._hit(t_v, false)
	var d: float = a_x.dmg(t_v)
	await a_x.done(m)
	return d

## Ability damage reads ArchKit.power(), so quiet level growth (LevelGrowth.ap) raises it.
func _growth() -> void:
	var d1: float = await _blade(1)
	var d10: float = await _blade(10)
	a_x.ok("dancer Encore: a blade grows with level (LevelGrowth.ap 1.0 -> %.2f)" % (1.0 + LevelGrowth.ap_pct(10)),
			d1 >= 3.9 and absf(d10 / d1 - (1.0 + LevelGrowth.ap_pct(10))) < 0.01, "L1 %.2f L10 %.2f" % [d1, d10])


# ------------------------------------------------------------------ Juggernaut
func juggernaut(a) -> void:
	a_x = a
	var r := a_x.setup("juggernaut", 2.4)
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var k: JuggernautKit = p_v.ak
	a_x.air_dash_is_ground(m, p_v, home)
	a_x.step(m, 0.8)
	p_v.slot_lv["dash"] = 1
	var charges_r1 := p_v.max_dashes()
	p_v.slot_lv["dash"] = 2
	var charges_r2 := p_v.max_dashes()
	p_v.slot_lv["dash"] = 1
	a_x.ok("juggernaut: greatsword, 2 Rampage charges at rank 1 and 3 at rank 2",
			p_v.wid == "greatsword" and charges_r1 == 2.0 and charges_r2 == 3.0,
			"%s %.0f %.0f" % [p_v.wid, charges_r1, charges_r2])
	var smash_ks: Array = []
	var chain_ks: Array = []
	for rk in [1, 2, 3]:
		p_v.slot_lv["sec"] = rk
		p_v.slot_lv["kin"] = rk
		smash_ks.append(k.smash_k())
		chain_ks.append(k.cd_k("kin"))
	p_v.slot_lv["sec"] = 1
	var air_r1 := k.air_cooldown()
	p_v.slot_lv["sec"] = 3
	var air_r3 := k.air_cooldown()
	p_v.slot_lv["sec"] = 1
	p_v.slot_lv["kin"] = 1
	a_x.ok("juggernaut ranks: Smash +20% at rank 2 and 3, Warchain cooldown -12.5% / -37.5%, Meteor Drop 7.2s -> 4.8s",
			absf(float(smash_ks[0]) - 1.0) < 0.001 and absf(float(smash_ks[1]) - 1.2) < 0.001
			and absf(float(smash_ks[2]) - 1.4) < 0.001 and absf(float(chain_ks[1]) - 0.875) < 0.001
			and absf(float(chain_ks[2]) - 0.625) < 0.001 and absf(air_r1 - 7.2) < 0.001 and absf(air_r3 - 4.8) < 0.001,
			"%s %s %.1f %.1f" % [smash_ks, chain_ks, air_r1, air_r3])
	var close := func(a: float, b: float) -> bool: return absf(a - b) < 0.05
	var jc := []
	var kin_p1 := k.power("kin")
	for rk in [1, 2, 3]:
		p_v.slot_lv["dash"] = rk
		p_v.slot_lv["sec"] = rk
		p_v.slot_lv["kin"] = rk
		jc.append([
			float(k.dash_def()["cd"]) * k.dash_k(), float(k.rmb_def()["cooldown"]) * k.cd_k("sec"),
			float(k.e_def()["cooldown"]) * k.cd_k("kin"), k.power("kin") / kin_p1,
		])
	p_v.slot_lv["dash"] = 1
	p_v.slot_lv["sec"] = 1
	p_v.slot_lv["kin"] = 1
	a_x.ok("upgrade parity: Rampage recharge 10.4 -> 8.8 -> 6.4 (source -1.6s, then -2.4s more)",
			close.call(jc[0][0], 10.4) and close.call(jc[1][0], 8.8) and close.call(jc[2][0], 6.4), str(jc))
	a_x.ok("upgrade parity: Warchain cooldown 12.8 -> 11.2 -> 8.0, no damage step (the source has none)",
			close.call(jc[1][2], 11.2) and close.call(jc[2][2], 8.0) and close.call(jc[2][3], 1.0), str(jc))
	a_x.ok("upgrade parity: Smash keeps its 2s cooldown at every rank (only damage and the Meteor Drop change)",
			close.call(jc[1][1], 2.0) and close.call(jc[2][1], 2.0), str(jc))
	# Rage (Blazing Spirit): damage fills it; nothing below full; Enraged gives damage, dash and ability haste
	k.res = 0.0
	k.enraged_t = 0.0
	k.on_deal(t_v, 40.0, {"src": "shot"})
	a_x.ok("juggernaut passive: damage fills Rage", k.res > 25.0 and k.res < 31.0, "rage %.1f" % k.res)
	a_x.ok("juggernaut passive: no bonus below full", absf(k.outgoing(t_v, 100.0, {}) - 100.0) < 0.1)
	k.gain_rage(100.0)
	a_x.ok("juggernaut passive: full = Enraged (+15%)",
			k.enraged_t > 0.0 and absf(k.outgoing(t_v, 100.0, {}) - 115.0) < 0.1,
			"%.1f" % k.outgoing(t_v, 100.0, {}))
	k.cd["e"] = 10.0
	p_v.dashes = 0.0
	a_x.step(m, 1.0)
	a_x.ok("juggernaut Enraged: ability + dash haste",
			float(k.cd["e"]) < 8.85 and p_v.dashes > 1.0 / p_v.dash_regen() * 1.08,
			"e cd %.2f dashes %.3f" % [float(k.cd["e"]), p_v.dashes])
	k.enraged_t = 0.0
	k.res = 0.0
	k.cd["e"] = 0.0
	# LMB: quick slashes, double at the tip; hold for a Searing Wave
	p_v.teleport(home)
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(1.3, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	p_v.fire_cd = 0.0
	p_v.inp["fire"] = true
	m.step(a_x.DT)
	p_v.inp["fire"] = false
	a_x.step(m, 0.3)
	var near := a_x.dmg(t_v)
	# owner 11-11: the LMB knocks nobody back (slash, tip or Searing Wave): the target stays where it stood
	var moved := t_v.flat_dist(home + Vector3(1.3, 0, 0))
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(2.95, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	p_v.fire_cd = 0.0
	p_v.inp["fire"] = true
	m.step(a_x.DT)
	p_v.inp["fire"] = false
	a_x.step(m, 0.3)
	a_x.ok("juggernaut LMB tap: a slash, 1.6x at the tip (the footage's 151 / 94)",
			near >= 7.0 and a_x.dmg(t_v) >= near * 1.5 and k.waves == 0, "near %.0f tip %.0f" % [near, a_x.dmg(t_v)])
	moved = maxf(moved, t_v.flat_dist(home + Vector3(2.95, 0, 0)))
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(7.0, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	p_v.fire_cd = 0.0
	k.res = 0.0
	a_x.step(m, 0.5, func(): p_v.inp["fire"] = true)
	var midk := k.wave_k()
	a_x.step(m, 0.6, func(): p_v.inp["fire"] = true)
	p_v.inp["fire"] = false
	a_x.step(m, 0.1)
	var chord := 0.0
	for rider in DJFx.of(m).riders:
		if rider["kind"] == "crescent_bolt":
			chord = DJFx.CRESCENT_CHORD * ((rider["node"] as Node3D).get_node("Head") as Node3D).scale.x
	var wave_w := 2.0 * float(k.lmb_def()["wave_size"][1])        # held to full
	a_x.step(m, 0.5)
	a_x.ok("juggernaut LMB hold: the wave's crescent is as wide as its hit (a wave of 2 x size across)",
			chord > 0.3 and absf(chord - wave_w) < 0.35, "crescent %.2f wave %.2f" % [chord, wave_w])
	a_x.ok("juggernaut LMB hold: Searing Wave (ranged, fills Rage fast, the full wave does not slow)",
			k.waves == 1 and midk > 0.2 and a_x.dmg(t_v) >= 12.0 and t_v.slow_t <= 0.0 and k.res > 30.0,
			"mid %.2f took %.0f rage %.0f slow %.2f" % [midk, a_x.dmg(t_v), k.res, t_v.slow_t])
	moved = maxf(moved, t_v.flat_dist(home + Vector3(7.0, 0, 0)))
	a_x.ok("juggernaut LMB: no knockback (slash, tip, Searing Wave)", moved < 0.01, "moved %.3fm" % moved)
	k.res = 0.0
	# RMB tap: the Finishing Slam winds up (aim it), then hits; +50% under 35%; its sweet spot is the payoff
	p_v.teleport(home)
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(2.6, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	a_x.tap(m, p_v)
	var early := a_x.dmg(t_v)
	var winding := not k.slam_w.is_empty()
	a_x.step(m, 0.3)
	var lane: Dictionary = AimKit.entry(p_v, "slam")
	var sl: Dictionary = k.rmb_def()["slam"]
	var vd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/vfx/juggernaut.json"))
	var mv: Dictionary = vd["moves"]
	var lm: Dictionary = k.d["lmb"]
	var scorch: Dictionary = mv["slam_hit"]["fx"][0]
	var slam_lane_only: bool = mv["slam_hit"]["fx"].all(func(l): return not l.has("arc") and not l.has("size_x"))
	a_x.ok("juggernaut move art: slash arc %.0f, slam scorch a %.2f m lane, true sizes" % [lm["arc"], sl["width"]],
			is_equal_approx(float(mv["slash"]["fx"][0]["arc"]), float(lm["arc"]))
			and scorch["p"] == "scorch" and scorch["shape"] == "lane" and scorch["len"] == "len"
			and is_equal_approx(float(scorch["w"]), float(sl["width"])) and slam_lane_only
			and not mv["slash"]["fx"][0].has("size_x") and not mv["drop_hit"]["fx"][0].has("size_x")
			and not mv["drop_hit"]["fx"][1].has("size_x")
			and not mv["dash_go"]["fx"].any(func(l): return l["p"] == "scorch"),
			"")
	_slash_edge(mv)
	var bursts: Array = []
	for id in ["dash_wind", "dash_go", "dash_drive", "dash_tip", "enrage"]:
		for l in mv[id].get("fx", []):
			if l["p"] in ["flare", "ring"] or String(l.get("shape", "")) == "disc":
				bursts.append("%s:%s" % [id, l["p"]])
	a_x.ok("juggernaut VFX: no burst, ring or disc on his dashes or the Enrage (DECISIONS)",
			bursts.is_empty(), str(bursts))
	var cols: Array = vd["palette"].values()
	cols.append_array([JuggernautDrop.AREA, JuggernautDrop.CORE, JuggernautKit.SLASH_OUT, JuggernautKit.LUNGE_FULL,
			JuggernautKit.WAVE_RED, JuggernautKit.WAVE_EDGE, JuggernautKit.WAVE_FULL])
	var foreign := _foreign_cols(k, cols)
	a_x.ok("juggernaut VFX: every colour is his signature, a slot colour, pale/dark, or far from other Hunters'",
			foreign.is_empty(), str(foreign))
	# Brall's Execution Slam is a lane, not a cone (hero-ref 0157: 0.4 bh wide, parallel sides; reach 2.4 bh)
	a_x.ok("juggernaut RMB tap: strike lane drawn = hit (%.1f x %.2f m, no taper)" % [sl["len"], sl["width"]],
			AimKit.shown(p_v, "slam") and bool(lane.get("all", false)) and String(lane.get("kind", "")) == "lane"
			and is_equal_approx(float(lane.get("len", 0.0)), float(sl["len"]))
			and is_equal_approx(float(lane.get("width", 0.0)), float(sl["width"]))
			and is_equal_approx(float(lane.get("width_end", 0.0)), float(sl["width"]))
			and absf(float(sl["len"]) - 4.3) < 0.05 and absf(float(sl["width"]) - 0.72) < 0.1,
			str(lane))
	_crimson_soft(a_x, p_v, lane, "tap cone")
	a_x.step(m, 0.4)
	a_x.ok("juggernaut RMB tap: Finishing Slam winds up, then lands",
			winding and early <= 0.0 and a_x.dmg(t_v) >= 14.0 and k.last_variant == "tap", "took %.0f" % a_x.dmg(t_v))
	a_x.ok("juggernaut RMB: the Slam marks the foe it hits for the Riposte reset",
			k.sweet_spots == 1 and k.slam_hit.has(t_v.get_instance_id()), "spots %d" % k.sweet_spots)
	p_v.teleport(home)
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(1.2, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	t_v.hp = t_v.max_hp * 0.3
	var hp0 := t_v.hp
	m.step(a_x.DT)
	a_x.ok("juggernaut RMB ready: the wounded (under 35%) are outlined red",
			AimKit.shown(p_v, "exec%d" % t_v.get_instance_id()))
	a_x.tap(m, p_v)
	a_x.step(m, 0.7)
	a_x.ok("juggernaut RMB tap: +50% under 35%, no sweet spot up close",
			hp0 - t_v.hp >= 21.0 and k.sweet_spots == 1, "dealt %.0f spots %d" % [hp0 - t_v.hp, k.sweet_spots])
	a_x.ok("juggernaut RMB: short cooldown (2s)",
			float(k.cd["rmb"]) <= 2.0 and float(k.cd["rmb"]) > 1.0, "%.2f" % float(k.cd["rmb"]))
	# the lane's shape: a foe the old 70-degree cone took (3 m out, 1.4 m aside) is missed; one at the tip is hit
	a_x.step(m, 2.1)
	var lane_hits: Array = []
	for spot: Vector3 in [Vector3(3.0, 0, 1.4), Vector3(float(sl["len"]) - 0.1, 0, 0.3)]:
		p_v.teleport(home)
		a_x.fresh(t_v)
		t_v.teleport(home + spot)
		a_x.aim_at(p_v, home + Vector3(3.0, 0, 0))
		k.ch_rmb = 1.0
		k.cd["rmb"] = 0.0
		a_x.tap(m, p_v)
		a_x.step(m, 0.7)
		lane_hits.append(a_x.dmg(t_v))
	a_x.ok("juggernaut RMB tap: the Slam hits a lane, not a cone (aside %.0f, tip %.0f)" % lane_hits,
			lane_hits[0] <= 0.0 and lane_hits[1] >= 24.0)
	_smash_drawn_is_hit(m, p_v, t_v, k, home)
	# the Lunge charge walks at rmb.lunge.walk_k of the run: the footage's Heavy Attack hold runs slower than
	# his plain runs (briefs/hero-ref/juggernaut.md, locomotion; docs/MOVEMENT_FEEL.md)
	a_x.step(m, 1.0)
	p_v.teleport(home)
	var run_v := _walk_v(m, p_v, func(): pass)
	p_v.teleport(home)
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	p_v.inp["sec_hold"] = true
	p_v.ak.press_rmb()
	var hold_v := _walk_v(m, p_v, func(): p_v.inp["sec_hold"] = true)
	var hold_k := k.move_k()
	p_v.inp["sec_hold"] = false
	m.step(a_x.DT)
	a_x.step(m, 3.5)
	a_x.ok("juggernaut RMB hold: he walks at 80% while the Lunge charges",
			is_equal_approx(hold_k, 0.8) and absf(hold_v / run_v - 0.8) < 0.05,
			"move_k %.2f, %.2f of %.2f m/s" % [hold_k, hold_v, run_v])
	# hold: the charged Lunge into the first foe; a miss doubles the cooldown
	p_v.teleport(home)
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(5.0, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	p_v.inp["sec_hold"] = true
	p_v.ak.press_rmb()
	a_x.step(m, 0.5, func(): p_v.inp["sec_hold"] = true)
	var ln: Dictionary = AimKit.entry(p_v, "rmb")
	var k_mid := float(ln.get("fill", -1.0))
	a_x.ok("juggernaut RMB hold: the lane grows with the charge (and the wind-up pose plays)",
			AimKit.shown(p_v, "rmb") and k_mid > 0.2 and k_mid < 1.0 and k.anim_id == "jug_lunge_wind"
			and not k.lunge_full,
			"k %.2f anim %s" % [k_mid, k.anim_id])
	a_x.ok("juggernaut RMB hold: lane = contact width (body + %.1f m a side), drawn = hit" % k.LUNGE_REACH,
			is_equal_approx(float(ln.get("width", 0.0)), 2.0 * (p_v.r + k.LUNGE_REACH))
			and is_equal_approx(k.lunge_w(), 2.0 * (p_v.r + k.LUNGE_REACH)), "%.2f" % float(ln.get("width", 0.0)))
	_crimson_soft(a_x, p_v, ln, "hold lane")
	p_v.do_jump()
	m.step(a_x.DT)
	a_x.ok("juggernaut RMB hold: you can jump while holding", p_v.vel.y > 0.5 and k.rmb_down, "vy %.1f" % p_v.vel.y)
	a_x.step(m, 0.35, func(): p_v.inp["sec_hold"] = true)
	a_x.ok("juggernaut RMB hold: full charge flashes (lane full, the cursor flare)",
			k.lunge_full and float(AimKit.entry(p_v, "rmb").get("fill", 0.0)) >= 1.0
			and float(AimKit.reticle(p_v)["flare"]) > 0.0,
			"full %s" % k.lunge_full)
	p_v.inp["sec_hold"] = false
	m.step(a_x.DT)
	a_x.step(m, 0.5)
	a_x.ok("juggernaut RMB hold: release flings you forward into them",
			k.last_variant == "hold" and a_x.dmg(t_v) >= 9.0 and p_v.flat_dist(home) > 3.5,
			"took %.0f moved %.1f" % [a_x.dmg(t_v), p_v.flat_dist(home)])
	a_x.step(m, 3.2)
	p_v.teleport(home)
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(0, 0, 6.0))
	a_x.aim_at(p_v, home + Vector3(6.0, 0, 0))
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	a_x.hold(m, p_v, 0.95)
	a_x.step(m, 0.5)
	var far := float(k.rmb_def()["lunge"]["dist"][1]) * float(k.dash_feel()["dist"])  # the full fling, after the feel
	a_x.ok("juggernaut RMB hold: a miss doubles the cooldown, the fling goes its full length",
			float(k.cd["rmb"]) > 3.0 and p_v.flat_dist(home) > far - 0.4,
			"cd %.1f moved %.1f" % [float(k.cd["rmb"]), p_v.flat_dist(home)])
	# air: the down slam, its hit circle just ahead of where he lands; it slows, the centre takes more and is stunned
	var dd: Dictionary = k.rmb_def()["drop"]
	var ahead := float(dd["ahead"])
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	p_v.teleport(t_v.pos + Vector3(-1.0, 3.0, 0))
	p_v.grounded = false
	a_x.fresh(t_v)
	a_x.aim_at(p_v, t_v.pos + Vector3(6.0, 0, 0))
	m.step(a_x.DT)
	var aim_at: Vector2 = AimKit.entry(p_v, "drop_aim").get("at", Vector2.ZERO) \
			if AimKit.shown(p_v, "drop_aim") else Vector2.ZERO
	a_x.ok("juggernaut air: the hit circle shows under him, just ahead, while the drop is ready",
			aim_at.distance_to(Vector2(p_v.pos.x + ahead, p_v.pos.z)) < 0.1, "circle at %s" % aim_at)
	var x0 := p_v.pos.x
	p_v.ak.press_rmb()
	var disc := AimKit.shown(p_v, "drop") and bool(AimKit.entry(p_v, "drop").get("all", false))
	a_x.ok("juggernaut RMB air: hit circle %.1f m, stun core %.1f m, drawn = hit" % [dd["radius"], dd["core"]],
			is_equal_approx(float(AimKit.entry(p_v, "drop").get("r", 0.0)), float(dd["radius"]))
			and is_equal_approx(float(AimKit.entry(p_v, "drop_core").get("r", 0.0)), float(dd["core"])))
	a_x.step(m, 0.6)
	var off := absf(k.meteor.last_drop.x - x0)
	a_x.ok("juggernaut RMB air: the down slam lands under him, its hit circle just ahead (everyone sees it)",
			disc and k.meteor.drops == 1 and off < 0.05 and absf(k.meteor.last_hit.x - x0 - ahead) < 0.01,
			"landed %.2f off, hit at +%.2f" % [off, k.meteor.last_hit.x - x0])
	a_x.ok("juggernaut RMB air: Meteor Drop knocks down, the centre takes more",
			k.last_variant == "air" and a_x.dmg(t_v) >= 14.0 and t_v.stun_t > 0.0,
			"took %.0f stun %.2f" % [a_x.dmg(t_v), t_v.stun_t])
	a_x.ok("juggernaut Meteor Drop: its own 7.2s slot, the Smash charge untouched",
			float(k.cd["air"]) > 6.0 and float(k.cd["air"]) <= 7.2 and k.ch_rmb >= 1.0 and float(k.cd["rmb"]) <= 0.0,
			"air cd %.2f smash charge %.1f cd %.2f" % [float(k.cd["air"]), k.ch_rmb, float(k.cd["rmb"])])
	p_v.teleport(t_v.pos + Vector3(-4.0, 3.0, 0))
	p_v.grounded = false
	a_x.aim_at(p_v, t_v.pos)
	a_x.tap(m, p_v)
	a_x.step(m, 0.2)
	a_x.ok("juggernaut Meteor Drop: while its slot rests an air press is the ground Smash (a Slam), not a second drop",
			k.meteor.drops == 1 and k.last_variant == "tap" and not k.slam_w.is_empty(),
			"drops %d variant %s" % [k.meteor.drops, k.last_variant])
	# the hit sits ahead, not round his feet: T 2.6m behind him (inside a circle round him) is not touched
	a_x.step(m, 1.5)
	k.cd["air"] = 0.0
	k.ch_rmb = 0.0
	k.cd["rmb"] = 2.0
	a_x.fresh(t_v)
	p_v.teleport(t_v.pos + Vector3(2.6, 3.0, 0))
	p_v.grounded = false
	a_x.aim_at(p_v, t_v.pos + Vector3(9.0, 0, 0))
	p_v.ak.press_rmb()
	a_x.step(m, 0.6)
	a_x.ok("juggernaut Meteor Drop: it fires with the Smash resting (usable right after a ground Smash)",
			k.meteor.drops == 2 and k.ch_rmb < 1.0 and float(k.cd["air"]) > 6.0,
			"drops %d air cd %.2f" % [k.meteor.drops, float(k.cd["air"])])
	a_x.ok("juggernaut Meteor Drop: a foe 2.6m behind him is outside the hit circle", a_x.dmg(t_v) <= 0.0,
			"took %.0f" % a_x.dmg(t_v))
	# on the ground RMB is never the drop: no cast, its slot untouched
	k.cd["air"] = 0.0
	a_x.step(m, 0.6)
	a_x.tap(m, p_v)
	a_x.step(m, 0.3)
	a_x.ok("juggernaut Meteor Drop: never from the ground (he must already be in the air)",
			p_v.grounded and k.meteor.drops == 2 and float(k.cd["air"]) <= 0.0,
			"drops %d air cd %.2f" % [k.meteor.drops, float(k.cd["air"])])
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	k.cd["air"] = 0.0
	# Rampage (Flame Step): a dash attack, aimed like any dash (ArchKit.dash_dir: WASD by default); the tip
	# hits double; rank 2 adds a charge
	a_x.step(m, 1.0)
	p_v.teleport(home)
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(3.5, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	p_v.dashes = 3.0
	p_v.inp["move"] = Vector2(1, 0)        # (toward the target: the dash follows the dash setting)
	p_v.do_dash()
	a_x.step(m, 0.5)
	p_v.inp["move"] = Vector2.ZERO
	a_x.ok("juggernaut dash: Rampage the way you dash, tip hits",
			k.tips >= 1 and a_x.dmg(t_v) >= 5.0 and p_v.dashes < 2.5,
			"tips %d took %.0f dashes %.2f" % [k.tips, a_x.dmg(t_v), p_v.dashes])
	a_x.ok("juggernaut dash: the tip does not stun into a wall", t_v.wallstun <= 0.0, "wallstun %.2f" % t_v.wallstun)
	# rank 3: a shot dodged through the dash feeds Rage (through the real dodge hook); rank 1 does not
	k.res = 0.0
	k.on_perfect_dodge()
	var rage_r1 := k.res
	p_v.slot_lv["dash"] = 3
	k.res = 0.0
	p_v.dodged = false
	p_v.inv_t = 0.3
	p_v.dash_at = m.time
	p_v.hurt(10.0, t_v, {"src": "shot"})
	a_x.ok("juggernaut dash rank 3: a dodged shot builds Rage (15), rank 1 does not",
			rage_r1 <= 0.01 and absf(k.res - 15.0) < 0.5, "r1 %.1f r3 %.1f" % [rage_r1, k.res])
	p_v.inv_t = 0.0
	p_v.slot_lv["dash"] = 1
	# E: the Warchain hooks a foe (blight); its cooldown waits for the pull; a Smash in the pull spins
	p_v.teleport(home)
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(6.0, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	k.cd["e"] = 0.0
	p_v.ak.use_e()
	a_x.step(m, 0.3)
	var chain_dmg := float(k.e_def()["dmg"])
	a_x.ok("juggernaut E: Warchain hooks (no blight: the data puts Anti-Heal on the spin), cooldown waits",
			k.warchain.hooked() and k.warchain.target == t_v and t_v.blight_t <= 0.0
			and a_x.dmg(t_v) >= chain_dmg * 0.85 and float(k.cd["e"]) <= 0.0,
			"blight %.1f cd %.1f" % [t_v.blight_t, float(k.cd["e"])])
	var wid := "war%d" % p_v.get_instance_id()
	a_x.ok("juggernaut E: the hooked foe wears the marker ring (shown whoever looks)",
			(DJFx.of(m).chains.get(wid + "ring", {}).get("node") as Node3D).visible)
	p_v.ak.use_e()
	a_x.step(m, 0.08)
	a_x.ok("juggernaut E recast: the pull starts the cooldown",
			k.warchain.reels == 1 and float(k.cd["e"]) > 5.0 and k.in_e(), "cd %.1f" % float(k.cd["e"]))
	a_x.step(m, 0.12)
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	a_x.aim_at(p_v, t_v.pos)
	a_x.tap(m, p_v)
	a_x.step(m, 0.2)
	a_x.ok("juggernaut RMB during the pull: Cinder Spin (blight)",
			k.spins == 1 and k.last_variant == "during_e" and a_x.dmg(t_v) >= 13.0,
			"spins %d variant %s took %.0f" % [k.spins, k.last_variant, a_x.dmg(t_v)])
	# rooted: no chain; a stun breaks a chain
	a_x.step(m, 0.5)
	k.cd["e"] = 0.0
	p_v.root_t = 1.0
	p_v.ak.use_e()
	a_x.ok("juggernaut E: can't throw it rooted", k.warchain.state == "ready")
	p_v.root_t = 0.0
	p_v.teleport(home)
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(6.0, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	p_v.ak.use_e()
	a_x.step(m, 0.3)
	p_v.stun_t = 0.3
	a_x.step(m, 0.05)
	a_x.ok("juggernaut E: a stun breaks the chain", k.warchain.state != "hooked" and float(k.cd["e"]) > 5.0)
	var halves: Dictionary = DJFx.of(m).chains
	var h0: Node3D = halves.get(wid + "s0", {}).get("node")
	var h1: Node3D = halves.get(wid + "s1", {}).get("node")
	a_x.ok("juggernaut E: the break shows two thick halves whipping back",
			h0 != null and h1 != null and h0.visible and k.warchain.snap_t > 0.0, "snap_t %.2f" % k.warchain.snap_t)
	a_x.step(m, 0.4)
	# ... or bites a wall and pulls you to it
	var w = m.world
	for dz in range(-3, 4):
		for dx in range(7, 9):
			w.level[w.idx(int(home.x) + dx, int(home.z) + dz)] = lv + 3
	p_v.teleport(home)
	t_v.teleport(home + Vector3(0, 0, 5.0))
	k.cd["e"] = 0.0
	a_x.aim_at(p_v, home + Vector3(8.0, 0, 0))
	p_v.ak.use_e()
	a_x.step(m, 0.35)
	var anchored: bool = k.warchain.hooked() and k.warchain.target == null
	p_v.ak.use_e()
	a_x.step(m, 0.45)
	a_x.ok("juggernaut E: chain a wall, pull yourself to it",
			anchored and p_v.flat_dist(home) > 4.0, "anchored %s moved %.1f" % [anchored, p_v.flat_dist(home)])
	var straight := p_v.pos
	# small mechanic (the owner's example): sideways input steers the pull, the arrival moves aside
	a_x.step(m, 0.5)
	p_v.teleport(home)
	k.cd["e"] = 0.0
	a_x.aim_at(p_v, home + Vector3(8.0, 0, 0))
	p_v.ak.use_e()
	a_x.step(m, 0.35)
	p_v.ak.use_e()
	a_x.step(m, 0.45, func(): p_v.inp["move"] = Vector2(0, 1))
	p_v.inp["move"] = Vector2.ZERO
	var side_off := absf(p_v.pos.z - straight.z)
	a_x.ok("juggernaut Warchain small mechanic: sideways input shifts the arrival by at least 1.5m",
			side_off >= 1.5, "%.2f m aside" % side_off)
	# a pull stopped in the air (the chain snaps) keeps its speed and the keys steer (docs/MOVEMENT_FEEL.md)
	a_x.step(m, 0.5)
	t_v.teleport(home + Vector3(6.0, 0, 0))
	a_x.fresh(t_v)
	var carry := a_x.air_steers(m, p_v, home, "a Warchain pull that snaps mid-air", func():
		p_v.teleport(home)
		p_v.grounded = true
		a_x.aim_at(p_v, t_v.pos)
		k.cd["e"] = 0.0
		p_v.ak.use_e()
		a_x.step(m, 0.3)
		p_v.ak.use_e()
		a_x.step(m, 0.05)
		p_v.teleport(p_v.pos + Vector3(0, 40.0, 0))     # (the hook flies flat: lifted mid-pull, not hooked in the air)
		p_v.grounded = false
		a_x.step(m, 0.05)
		k.warchain.snap())
	a_x.ok("juggernaut Warchain stopped mid-air: the pull's speed carries (not zeroed)", carry > p_v.base_speed,
			"%.1f m/s" % carry)
	a_x.fresh(t_v)
	# the source's Execution Slam: knock a foe within 2s of its sweet spot and the ultimate (X) is ready again
	p_v.lvl = maxi(p_v.lvl, 6)
	p_v.slot_lv["ult"] = 1
	a_x.step(m, 2.5)
	p_v.teleport(home)
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(2.6, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	k.cd["x"] = 15.0
	a_x.tap(m, p_v)
	a_x.step(m, 0.9)
	t_v.hp = 4.0
	p_v.hp = 1.0
	t_v.hurt(10.0, p_v, {"src": "shot"})
	a_x.step(m, 0.1)
	a_x.ok("juggernaut Smash small mechanic: a knock after the sweet spot resets the Gilded Riposte",
			t_v.downed and k.slam_resets == 1 and float(k.cd["x"]) <= 0.0 and k.knock_healed > 0.0,
			"x cd %.1f resets %d" % [float(k.cd["x"]), k.slam_resets])
	a_x.ok("juggernaut passive: a knock heals 20% of their health",
			k.knock_healed >= minf(0.19 * t_v.max_hp, 0.9 * p_v.max_hp), "healed %.0f of %.0f" % [k.knock_healed,
					t_v.max_hp])
	# audit (data: "knocking an enemy resets Volcanic Rebuke"): a plain body hit then a knock resets it too
	a_x.step(m, 1.0)
	t_v.downed = false
	t_v.dead = false
	t_v.out = false
	a_x.fresh(t_v)
	p_v.teleport(home)
	t_v.teleport(home + Vector3(1.4, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	k.cd["x"] = 15.0
	var spots0 := k.sweet_spots
	var resets0 := k.slam_resets
	a_x.tap(m, p_v)
	a_x.step(m, 0.9)
	t_v.hp = 4.0
	t_v.hurt(10.0, p_v, {"src": "shot"})
	a_x.step(m, 0.1)
	a_x.ok("juggernaut Smash: a knock after any Slam hit (not the sweet spot) resets the Gilded Riposte",
			k.sweet_spots == spots0 and k.slam_resets == resets0 + 1 and float(k.cd["x"]) <= 0.0,
			"spots +%d resets +%d" % [k.sweet_spots - spots0, k.slam_resets - resets0])
	await a_x.done(m)
	await ZFEEL.new().run(a_x)
	await ULT.new().zedran(a_x)


# ------------------------------------------------------------------ cross-ability combinations (--kit-combo-check)

# ------------------------------------------------------------------ combinations (--kit-combo-check)

## His mean ground speed walking north for 0.4 s after a 0.4 s run-up, `each` called every step.
func _walk_v(m: Match, p_v: Hunter, each: Callable) -> float:
	var walk := func():
		each.call()
		p_v.inp["move"] = Vector2(0, -1)
	a_x.step(m, 0.4, walk)
	var z0 := p_v.pos.z
	a_x.step(m, 0.4, walk)
	p_v.inp["move"] = Vector2.ZERO
	return (z0 - p_v.pos.z) / 0.4

func combos(a) -> void:
	a_x = a
	# ---- Juggernaut
	var r := a_x.setup("juggernaut", 6.0)
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	var _lv: int = r[5]
	var k: JuggernautKit = p_v.ak
	var hook := func():
		p_v.teleport(home)
		a_x.fresh(t_v)
		t_v.teleport(home + Vector3(6.0, 0, 0))
		a_x.aim_at(p_v, t_v.pos)
		k.cd["e"] = 0.0
		k.ch_rmb = 1.0
		k.cd["rmb"] = 0.0
		k.haul = {}
		p_v.ak.use_e()
		a_x.step(m, 0.3)
	# E, E, then RMB tap in the pull: Cinder Spin
	hook.call()
	p_v.ak.use_e()
	var wait := 0.0
	while k.warchain.pulling() and wait < 1.0:      # (the spin's blight lands on who it hits: wait to be close)
		m.step(a_x.DT)
		wait += a_x.DT
	a_x.tap(m, p_v)
	a_x.step(m, 0.3)
	a_x.ok("combo jug: E > E > RMB tap = Cinder Spin (it blights who it hits)",
			k.spins == 1 and k.last_variant == "during_e" and t_v.blight_t > 0.0,
			"spins %d variant %s" % [k.spins, k.last_variant])
	# E, then RMB held and let go while attached: Chain Lunge along it
	a_x.step(m, 1.0)
	hook.call()
	var hp0 := a_x.dmg(t_v)
	a_x.hold(m, p_v, 0.95)
	a_x.step(m, 0.4)
	a_x.ok("combo jug: E > hold RMB = Chain Lunge (no stun)",
			k.chain_lunges == 1 and k.warchain.state != "hooked" and a_x.dmg(t_v) - hp0 >= 18.0 and t_v.stun_t <= 0.0
			and p_v.flat_dist(t_v) < 3.4,
			"lunges %d dist %.1f took %.0f stun %.2f" % [k.chain_lunges, p_v.flat_dist(t_v), a_x.dmg(t_v) - hp0,
					t_v.stun_t])
	# E, hold RMB, then E while still holding: pulled in, Haul Slam on arrival
	a_x.step(m, 1.0)
	hook.call()
	hp0 = a_x.dmg(t_v)
	p_v.inp["sec_hold"] = true
	p_v.ak.press_rmb()
	a_x.step(m, 0.5, func(): p_v.inp["sec_hold"] = true)
	p_v.ak.use_e()
	p_v.inp["sec_hold"] = false
	a_x.step(m, 0.45)
	a_x.ok("combo jug: E > hold RMB > E = Haul Slam on arrival (no stun)",
			k.haul_slams == 1 and a_x.dmg(t_v) - hp0 >= 16.0 and t_v.stun_t <= 0.0 and k.chain_lunges == 1,
			"slams %d took %.0f stun %.2f" % [k.haul_slams, a_x.dmg(t_v) - hp0, t_v.stun_t])
	# E, E, then RMB pressed (and held) in the pull: the Cinder Spin goes on the press, no Haul Slam
	a_x.step(m, 1.0)
	hook.call()
	p_v.ak.use_e()
	a_x.step(m, 0.04)
	var spins0 := k.spins
	p_v.inp["sec_hold"] = true
	p_v.ak.press_rmb()
	var spun_on_press := k.spins == spins0 + 1
	a_x.step(m, 0.4, func(): p_v.inp["sec_hold"] = true)
	p_v.inp["sec_hold"] = false
	a_x.step(m, 0.3)
	a_x.ok("combo jug: E > E > hold RMB = Cinder Spin on the press (no Haul Slam, no second move)",
			spun_on_press and k.spins == spins0 + 1 and k.haul_slams == 1,
			"spins %d slams %d" % [k.spins, k.haul_slams])
	_spin_timing(m, p_v, k, hook)
	# E attached, RMB tapped (not pulling): a normal Finishing Slam
	a_x.step(m, 1.0)
	hook.call()
	a_x.tap(m, p_v)
	a_x.ok("combo jug: E > RMB tap = Finishing Slam", not k.slam_w.is_empty() and k.last_variant == "tap")
	a_x.ok("combo jug: the attached Warchain draws as a link chain",
			is_instance_valid(DJFx.of(m).chains.get("war%d" % p_v.get_instance_id(), {}).get("node"))
			and (DJFx.of(m).chains["war%d" % p_v.get_instance_id()]["node"] as Node3D).visible)
	a_x.step(m, 0.8)
	# the Finishing Slam's sweet spot, then a knock within 2s: the Riposte (X) is ready again, a heal, a dash back
	p_v.lvl = maxi(p_v.lvl, 6)
	p_v.slot_lv["ult"] = 1
	p_v.teleport(home)
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(2.6, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	k.cd["x"] = 15.0
	a_x.tap(m, p_v)
	a_x.step(m, 0.8)
	p_v.dashes = 0.0
	var rs := k.slam_resets
	t_v.hp = 4.0
	t_v.hurt(10.0, p_v, {"src": "shot"})
	a_x.step(m, 0.05)
	a_x.ok("combo jug: RMB sweet spot > knock = Riposte reset + heal + a dash",
			k.slam_resets == rs + 1 and float(k.cd["x"]) <= 0.0 and k.knock_healed > 0.0 and p_v.dashes >= 0.99,
			"dashes %.2f" % p_v.dashes)
	await a_x.done(m)
	r = a_x.setup("juggernaut", 6.0)
	m = r[0]
	p_v = r[1]
	t_v = r[2]
	home = r[4]
	_lv = r[5]
	k = p_v.ak
	# a Lunge that strikes nothing doubles the Smash cooldown
	a_x.aim_at(p_v, home + Vector3(0, 0, 6.0))
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	a_x.hold(m, p_v, 0.95)
	a_x.step(m, 0.5)
	a_x.ok("combo jug: RMB hold miss = cooldown x2", float(k.cd["rmb"]) > 3.0, "%.1f" % float(k.cd["rmb"]))
	# a dash or a lunge winds down: no glider straight out of it
	p_v.dashes = 2.0
	a_x.aim_at(p_v, home + Vector3(6.0, 0, 0))
	p_v.do_dash()
	a_x.step(m, 0.05)
	for i in 30:
		if p_v.roll_t <= 0.0:
			break
		a_x.step(m, 0.05)
	a_x.ok("combo jug: Rampage winds down (no instant glide)", p_v.glide_cd > 0.2, "%.2f" % p_v.glide_cd)
	# rooted: no chain; a stun breaks it; Enraged speeds every cooldown
	a_x.step(m, 1.0)
	k.cd["e"] = 0.0
	p_v.root_t = 1.0
	p_v.ak.use_e()
	a_x.ok("combo jug: rooted = no Warchain", k.warchain.state == "ready")
	p_v.root_t = 0.0
	KitStatus.apply(p_v, "gnd", 1.0)
	p_v.ak.use_e()
	a_x.ok("combo jug: Grounded = no Warchain", k.warchain.state == "ready")
	a_x.step(m, 1.1)
	p_v.teleport(home)
	a_x.fresh(t_v)
	t_v.teleport(home + Vector3(6.0, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	p_v.ak.use_e()
	a_x.step(m, 0.3)
	p_v.stun_t = 0.3
	a_x.step(m, 0.05)
	a_x.ok("combo jug: stun breaks the Warchain", k.warchain.state != "hooked" and float(k.cd["e"]) > 5.0)
	a_x.step(m, 0.4)
	k.gain_rage(100.0)
	k.cd["rmb"] = 3.0
	a_x.step(m, 1.0)
	a_x.ok("combo jug: Enraged hastes the Smash", float(k.cd["rmb"]) < 1.85, "%.2f" % float(k.cd["rmb"]))
	await a_x.done(m)
	# ---- Sable
	r = a_x.setup("thief", 4.0, "", true)
	m = r[0]
	p_v = r[1]
	t_v = r[2]
	var t2: Hunter = r[3]
	home = r[4]
	var tk: ThiefKit = p_v.ak
	# Vault > empowered bolt hits: Vault reset, speed ends
	p_v.dashes = p_v.max_dashes()
	a_x.aim_at(p_v, t_v.pos)
	p_v.inp["move"] = Vector2(0, 1 if tk.primed_hits % 2 == 0 else -1)
	p_v.do_dash()
	a_x.step(m, 0.55)
	p_v.inp["move"] = Vector2.ZERO
	a_x.aim_at(p_v, t_v.pos)
	p_v.fire_cd = 0.0
	p_v.inp["fire"] = true
	m.step(a_x.DT)
	p_v.inp["fire"] = false
	a_x.step(m, 0.4)
	a_x.ok("combo dancer: Vault > bolt = empowered hit + Vault reset",
			tk.primed_hits == 1 and p_v.dashes >= p_v.max_dashes() - 0.01 and tk.haste_t <= 0.0)
	# the loop: Vault again at once, empowered again, about 1.4s a loop while the hits land
	p_v.inp["move"] = Vector2(0, 1 if tk.primed_hits % 2 == 0 else -1)
	p_v.do_dash()
	a_x.step(m, 0.55)
	p_v.inp["move"] = Vector2.ZERO
	a_x.aim_at(p_v, t_v.pos)
	p_v.fire_cd = 0.0
	p_v.inp["fire"] = true
	m.step(a_x.DT)
	p_v.inp["fire"] = false
	a_x.step(m, 0.4)
	a_x.ok("combo dancer: the reset loop (Vault > bolt > Vault > bolt)",
			tk.primed_hits == 2 and p_v.dashes >= p_v.max_dashes() - 0.01)
	# an empowered bolt that misses is spent (no reset)
	p_v.inp["move"] = Vector2(0, 1 if tk.primed_hits % 2 == 0 else -1)
	p_v.do_dash()
	a_x.step(m, 0.55)
	p_v.inp["move"] = Vector2.ZERO
	a_x.aim_at(p_v, home + Vector3(0, 0, -5.0))
	p_v.fire_cd = 0.0
	p_v.inp["fire"] = true
	m.step(a_x.DT)
	p_v.inp["fire"] = false
	a_x.step(m, 0.5)
	a_x.ok("combo dancer: an empowered bolt that misses is spent",
			tk.primed_hits == 2 and tk.primed_t <= 0.0 and p_v.dashes < p_v.max_dashes() - 0.5)
	# Knife into a foe: the Vault comes back with the Knife's rank 3, not Vault's
	p_v.slot_lv["dash"] = 3
	p_v.slot_lv["kin"] = 2
	p_v.teleport(home)
	a_x.fresh(t_v)
	t2.teleport(home + Vector3(0, 0, 9.0))
	a_x.aim_at(p_v, t_v.pos)
	p_v.dashes = 0.0
	tk.cd["e"] = 0.0
	p_v.ak.use_e()
	a_x.step(m, 0.35)
	a_x.ok("combo dancer: Knife in a foe at rank 2 (Vault rank 3) gives no Vault back",
			p_v.dashes < 0.99, "dashes %.2f" % p_v.dashes)
	p_v.ak.use_e()
	a_x.step(m, 0.3)
	p_v.slot_lv["dash"] = 1
	p_v.slot_lv["kin"] = 3
	p_v.teleport(home)
	a_x.fresh(t_v)
	t2.teleport(home + Vector3(0, 0, 9.0))
	a_x.aim_at(p_v, t_v.pos)
	p_v.dashes = 0.0
	tk.cd["e"] = 0.0
	p_v.ak.use_e()
	a_x.step(m, 0.35)
	a_x.ok("combo dancer: Knife in a foe (Knife rank 3) = Vault reset + refund",
			p_v.dashes >= 0.99 and float(tk.cd["e"]) < 10.0, "dashes %.2f e cd %.1f" % [p_v.dashes, float(tk.cd["e"])])
	p_v.ak.use_e()
	a_x.step(m, 0.05)
	a_x.ok("combo dancer: Knife > E = step to them", p_v.flat_dist(t_v) < 1.8)
	# Bola into two at rank 3: their Marks pool
	p_v.slot_lv["sec"] = 3
	p_v.teleport(home)
	a_x.fresh(t_v)
	a_x.fresh(t2)
	t_v.teleport(home + Vector3(4.0, 0, 0))
	t2.teleport(home + Vector3(7.0, 0, 0))
	a_x.aim_at(p_v, t_v.pos)
	tk.add_mark(t2, 3, true)
	tk.ch_rmb = 1.0
	tk.cd["rmb"] = 0.0
	a_x.tap(m, p_v)
	a_x.step(m, 0.9)
	a_x.ok("combo dancer: Bola on two (rank 3) = pooled Marks",
			tk.bola_pairs >= 1 and tk.marks_on(t_v) >= 4 and tk.marks_on(t_v) == tk.marks_on(t2),
			"T %d T2 %d" % [tk.marks_on(t_v), tk.marks_on(t2)])
	a_x.ok("combo dancer: Bola > Grounded = no dash", KitStatus.grounded(t_v) and _dash_blocked(t_v))
	a_x.step(m, 2.0)
	await a_x.done(m)
	await ULT.new().combos(a_x)
	await merge_holds()

## True when a dash attempt leaves `t` with the dashes it had (Grounded blocks the dash).
func _dash_blocked(t: Hunter) -> bool:
	var d0 := t.dashes
	t.stun_t = 0.0
	t.do_dash()
	return t.dashes == d0

## A Boki merge starting mid-hold: nothing the hunter was holding or winding up fires, and none of it is left
## behind for when the merge ends (ArchKit.drop_holds: the kits' _drop_holds, then AimKit.clear).
func merge_holds() -> void:
	# ---- Juggernaut: the Searing Wave charge (LMB held)
	var r := a_x.setup("juggernaut", 6.0, "cindle")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var k: JuggernautKit = p_v.ak
	p_v.ult = 1.0
	p_v.merge_cd = 0.0
	a_x.step(m, 0.7, func(): p_v.inp["fire"] = true)
	a_x.ok("merge hold jug: the Searing Wave is charging", k.lmb_t > 0.3 and p_v.mel_hold > 0.0, "lmb_t %.2f" % k.lmb_t)
	var w0 := k.waves
	a_x.ok("merge hold jug: the merge starts", KinMerge.cast(p_v) and KinMerge.active(p_v))
	a_x.step(m, 0.6, func(): p_v.inp["fire"] = false)
	a_x.ok("merge hold jug: the charged wave does not fire",
			k.waves == w0 and a_x.dmg(t_v) <= 0.0, "waves %d took %.0f" % [k.waves - w0, a_x.dmg(t_v)])
	a_x.ok("merge hold jug: no charge left behind",
			k.lmb_t < 0.0 and k.lmb_buf <= 0.0 and p_v.mel_hold <= 0.0, "lmb_t %.2f" % k.lmb_t)
	await a_x.done(m)
	# the Finishing Slam winding up
	# (a control first: what the merge's own transformation does to a foe this close, with no slam)
	r = a_x.setup("juggernaut", 2.6, "cindle")
	m = r[0]
	p_v = r[1]
	t_v = r[2]
	p_v.ult = 1.0
	p_v.merge_cd = 0.0
	KinMerge.cast(p_v)
	a_x.step(m, 1.0)
	var ctl := a_x.dmg(t_v)
	await a_x.done(m)
	r = a_x.setup("juggernaut", 2.6, "cindle")
	m = r[0]
	p_v = r[1]
	t_v = r[2]
	k = p_v.ak
	p_v.ult = 1.0
	p_v.merge_cd = 0.0
	a_x.aim_at(p_v, t_v.pos)
	a_x.tap(m, p_v)
	a_x.ok("merge hold jug: the Finishing Slam is winding up", not k.slam_w.is_empty())
	KinMerge.cast(p_v)
	a_x.step(m, 1.0)
	a_x.ok("merge hold jug: the wound-up slam does not land",
			k.slam_w.is_empty() and k.sweet_spots == 0 and a_x.dmg(t_v) <= ctl + 0.5,
			"took %.0f (merge alone %.0f)" % [a_x.dmg(t_v), ctl])
	await a_x.done(m)
	# the Smash held (the Lunge charge), and a Haul Slam armed for the end of a pull
	r = a_x.setup("juggernaut", 6.0, "cindle")
	m = r[0]
	p_v = r[1]
	t_v = r[2]
	k = p_v.ak
	p_v.ult = 1.0
	p_v.merge_cd = 0.0
	a_x.aim_at(p_v, t_v.pos)
	p_v.inp["sec_hold"] = true
	p_v.ak.press_rmb()
	a_x.step(m, 0.6, func(): p_v.inp["sec_hold"] = true)
	a_x.ok("merge hold jug: the Lunge is charging", k.rmb_down and k.rmb_t > 0.3)
	k.haul = {"k": 1.0}
	var chg := k.ch_rmb
	KinMerge.cast(p_v)
	p_v.inp["sec_hold"] = false
	a_x.step(m, 0.6)
	a_x.ok("merge hold jug: the charged Lunge does not go and no Smash charge is spent",
			k.lunge.is_empty() and not k.rmb_down and k.ch_rmb >= chg, "charges %.1f of %.1f" % [k.ch_rmb, chg])
	a_x.ok("merge hold jug: an armed Haul Slam is dropped", k.haul.is_empty() and k.haul_slams == 0)
	await a_x.done(m)
	# ---- Sable: the Bola's wind-up stops when a merge starts (a running Encore: tools/dj_ult_check.gd)
	r = a_x.setup("thief", 4.0, "cindle")
	m = r[0]
	p_v = r[1]
	t_v = r[2]
	var tk: ThiefKit = p_v.ak
	p_v.ult = 1.0
	p_v.merge_cd = 0.0
	a_x.aim_at(p_v, t_v.pos)
	tk.ch_rmb = 1.0
	tk.cd["rmb"] = 0.0
	a_x.tap(m, p_v)
	a_x.ok("merge hold dancer: the Bola is winding up", not tk.bola_cast.is_empty())
	KinMerge.cast(p_v)
	a_x.step(m, 0.8)
	a_x.ok("merge hold dancer: the wound-up Bola is not thrown",
			tk.bola_cast.is_empty() and tk.bola.is_empty() and not KitStatus.grounded(t_v) and not AimKit.shown(p_v,
					"rmb"))
	await a_x.done(m)
	# ---- Juggernaut: a Meteor Drop diving when a merge starts doesn't land
	r = a_x.setup("juggernaut", 4.0, "cindle")
	m = r[0]
	p_v = r[1]
	t_v = r[2]
	var jk: JuggernautKit = p_v.ak
	p_v.ult = 1.0
	p_v.merge_cd = 0.0
	p_v.teleport(t_v.pos + Vector3(-3.0, 4.0, 0))
	p_v.grounded = false
	a_x.aim_at(p_v, t_v.pos)
	jk.ch_rmb = 1.0
	jk.cd["rmb"] = 0.0
	p_v.ak.press_rmb()
	a_x.ok("merge hold jug: the Meteor Drop is diving", jk.meteor.running())
	KinMerge.cast(p_v)
	a_x.step(m, 0.8)
	a_x.ok("merge hold jug: the dive is dropped, no slam lands", not jk.meteor.running() and jk.meteor.drops == 0)
	await a_x.done(m)

## The first fx of kind `p` in a move (its index moves as layers are added).
func _fx(move: Dictionary, p: String) -> Dictionary:
	for fx in move["fx"]:
		if fx["p"] == p:
			return fx
	return {}

const FOREIGN_D := 0.15     # RGB distance under which a colour reads as another Hunter's signature
const PALE_S := 0.35        # saturation under this is white-hot or a pale tint (free); pale signatures are not fenced
const DARK_V := 0.4         # value under this is char or smoke (free)

## Colours (hex strings or Color) a kit draws that read as another Hunter's: not Kael's signature or a slot col,
## not pale or dark, and within FOREIGN_D of another archetype's saturated signature colour.
func _foreign_cols(k: ArchKit, cols: Array) -> Array:
	var own: Array = [Arch.color("juggernaut"), k.res_col()]
	for sd in [k.lmb_def(), k.rmb_def(), k.dash_def(), k.e_def(), k.x_def()]:
		if sd.has("col"):
			own.append(k.col_of(sd))
	var out: Array = []
	for v in cols:
		var c := v as Color if v is Color else Color(String(v))
		if own.any(func(o): return (o as Color).is_equal_approx(c)) or c.s < PALE_S or c.v < DARK_V:
			continue
		for id in Arch.ids():
			var sig := Arch.color(id)
			var d := Vector3(c.r - sig.r, c.g - sig.g, c.b - sig.b).length()
			if id != "juggernaut" and sig.s >= PALE_S and d < FOREIGN_D:
				out.append("%s ~ %s" % [c.to_html(false), id])
	return out

## A Smash telegraph in Kael's crimson (his archetype colour, owner 11-08) with a lit rim and a faint inside.
func _crimson_soft(a_v, p_v: Hunter, e: Dictionary, what: String) -> void:
	var edge := float(e.get("width", 0.0)) * 0.5 if e.get("kind", "") == "lane" else float(e.get("len", 0.0))
	var got: Array = load("res://tools/aimkit_check.gd").measure(e, 0.6, edge - 0.02)
	var col := AimKit.hero_col(p_v).to_html(false)
	a_v.ok("juggernaut RMB %s: crimson %s, lit rim, inside %.2f <= %.2f (rim %.2f)"
			% [what, col, got[0], AimShapes.SOFT_A, got[1]],
			(e.get("col", Color.BLACK) as Color).is_equal_approx(Color("ff3a2a")) and bool(e.get("soft", false))
			and got[0] <= AimShapes.SOFT_A + 0.001 and got[1] >= 0.5, str(e.get("col")))

## VFX_QUALITY 6: the crimson Smash telegraphs are the hit, read off the drawn entries (not the data): a foe
## whose body just reaches into the drawn Slam cone or lane (at its rim or side, at its tip) is hit and one just
## past it is not; the same at the drawn Lunge lane's side, and the fling travels the drawn length.
func _smash_drawn_is_hit(m: Match, p_v: Hunter, t_v: Hunter, k: JuggernautKit, home: Vector3) -> void:
	var fwd := Vector3(1, 0, 0)
	var side := Vector3(0, 0, 1)
	var got := []
	for probe in [["rim in", true], ["rim out", false], ["tip in", true], ["tip out", false]]:
		a_x.step(m, 0.3)
		p_v.teleport(home)
		a_x.fresh(t_v)
		t_v.teleport(home + Vector3(0, 0, 12))           # out of reach while the cone is read
		a_x.aim_at(p_v, home + fwd * 3.0)
		k.ch_rmb = 1.0
		k.cd["rmb"] = 0.0
		a_x.tap(m, p_v)
		a_x.step(m, 0.1)
		var e: Dictionary = AimKit.entry(p_v, "slam")
		var l := float(e.get("len", 0.0))
		var half := deg_to_rad(float(e.get("deg", 0.0))) * 0.5
		var lane := String(e.get("kind", "")) == "lane"     # the source's lane (ext/parity-kael-slam-lane) or our cone
		var rim := side * (float(e.get("width", 0.0)) * 0.5 + t_v.r) + fwd * l * 0.7
		var at := Vector3.ZERO
		match probe[0]:
			"rim in": at = rim - side * 0.1 if lane else (fwd.rotated(Vector3.UP, half - 0.03)) * l * 0.7
			"rim out": at = rim + side * 0.15 if lane else (fwd.rotated(Vector3.UP, half + 0.06)) * l * 0.7
			"tip in": at = fwd * (l + t_v.r - 0.1)
			"tip out": at = fwd * (l + t_v.r + 0.2)
		t_v.teleport(home + at)
		a_x.step(m, 0.6)
		got.append("%s %.0f" % [probe[0], a_x.dmg(t_v)])
		var hit := a_x.dmg(t_v) > 0.0
		var what := "%s (%.1f m, %s drawn)" % [probe[0], l,
				"%.2f m wide" % float(e.get("width", 0.0)) if lane else "%.0f deg" % rad_to_deg(half * 2.0)]
		a_x.ok("juggernaut RMB tap: drawn %s = hit, %s" % [e.get("kind", "?"), what],
				k.last_variant == "tap" and l > 0.0 and hit == probe[1], ", ".join(got))
	# the Lunge: charged to full, the drawn lane's half width (+ the foe's body, as for every edge) is the contact
	for probe in [["side in", true], ["side out", false], ["length", false]]:
		a_x.step(m, 0.5)
		p_v.teleport(home)
		a_x.fresh(t_v)
		t_v.teleport(home + Vector3(0, 0, 12))
		a_x.aim_at(p_v, home + fwd * 3.0)
		k.ch_rmb = 1.0
		k.cd["rmb"] = 0.0
		p_v.inp["sec_hold"] = true
		p_v.ak.press_rmb()
		a_x.step(m, k.rmb_charge_full() + 0.5, func(): p_v.inp["sec_hold"] = true)   # full, between perfect windows
		var e: Dictionary = AimKit.entry(p_v, "rmb")
		var w := float(e.get("width", 0.0))
		var l := float(e.get("len", 0.0))
		if probe[0] == "side in":
			t_v.teleport(home + fwd * 3.0 + side * (w * 0.5 + t_v.r - 0.1))
		elif probe[0] == "side out":
			t_v.teleport(home + fwd * 3.0 + side * (w * 0.5 + t_v.r + 0.15))
		var from := p_v.pos
		p_v.inp["sec_hold"] = false
		m.step(a_x.DT)
		var flung := 0.0              # where the fling's own travel ends (the slide after it is the run's brake)
		for i in 90:
			if k.lunge.is_empty() and flung > 0.0:
				break
			if not k.lunge.is_empty():
				flung = Vector2(p_v.pos.x - from.x, p_v.pos.z - from.z).length()
			m.step(a_x.DT)
		a_x.step(m, 1.0)
		var moved := flung
		if probe[0] == "length":
			a_x.ok("juggernaut RMB hold: the fling travels the drawn lane (%.2f m drawn, %.2f m flung)" % [l, moved],
					l > 0.0 and absf(moved - l) <= 0.25, "")
		else:
			a_x.ok("juggernaut RMB hold: drawn lane = hit, %s (%.2f m drawn wide)" % [probe[0], w],
					w > 0.0 and (a_x.dmg(t_v) > 0.0) == probe[1], "took %.0f" % a_x.dmg(t_v))
	a_x.step(m, 0.5)
	p_v.teleport(home)
	a_x.fresh(t_v)


const SLASH_HIT := 0.08     # s: the slash's contact in its sound (tools/gen_sfx_kael.py SLASH_HIT)
const CLEAVE_HIT := 0.1     # s: the cleave's cut in jug_riposte (gen_sfx_kael.py RIPOSTE_HIT)

## Kael's LMB slash sound: the swish keeps its 0.42 s and its play on the press, and every take's loudest
## moment is a hard edge on the contact frame, as sharp over its swish as the cleave's cut, and quieter in game.
func _slash_edge(mv: Dictionary) -> void:
	var cleave := _edge("jug_riposte", CLEAVE_HIT)
	var heard := float(mv["slash"]["sfx"][0]["db"]) - float(mv["riposte_go"]["sfx"][0]["db"])
	var bad: Array = []
	for take in ["jug_slash", "jug_slash_1", "jug_slash_2", "jug_slash_3"]:
		var e := _edge(take, SLASH_HIT)
		var louder: float = e["edge"] + heard - cleave["edge"]
		if absf(e["len"] - 0.42) > 0.002 or e["lead"] < cleave["lead"] - 1.5 or louder > 0.0 or louder < -6.0:
			bad.append("%s %s, %+.1f dB in game vs the cleave" % [take, e, louder])
	a_x.ok("juggernaut LMB sound: a hard edge on the contact frame over the swish, levelled under the cleave",
			bad.is_empty() and not mv["slash"]["sfx"][0].has("delay"), "cleave %s %s" % [cleave, bad])

## A source wav (44.1 kHz mono 16-bit) at its hit time: length, the peak (dBFS) in the 15 ms from it, and
## how far that peak sits over the loudest moment anywhere else (the swish before it, the tail after 30 ms).
func _edge(sname: String, hit: float) -> Dictionary:
	var b := FileAccess.get_file_as_bytes("res://audio/%s.wav" % sname)
	var edge := 0.0
	var rest := 1.0
	for i in range(44, b.size() - 1, 2):
		var t := float(i - 44) / 2.0 / 44100.0
		var v := absf(b.decode_s16(i))
		if t >= hit and t < hit + 0.015: edge = maxf(edge, v)
		elif t < hit - 0.005 or t >= hit + 0.03: rest = maxf(rest, v)
	return {"len": snappedf(float(b.size() - 44) / 2.0 / 44100.0, 0.001),
			"edge": snappedf(linear_to_db(edge / 32768.0), 0.1), "lead": snappedf(linear_to_db(edge / rest), 0.1)}

## The Cinder Spin is forgiving: an RMB press at the pull's start, middle, last frame, just after it ended (the
## arrival, or a dash that cut it short) or just before it (tapped, or still held) is exactly one spin; a press
## outside all that is the normal Smash.
func _spin_timing(m: Match, p_v: Hunter, k: JuggernautKit, hook: Callable) -> void:
	var cases := ["start", "middle", "last frame", "0.14 s after arriving", "0.1 s after a dash cut it",
			"0.1 s before (tapped)", "0.1 s before (held)"]
	for name: String in cases:
		a_x.step(m, 1.0)
		hook.call()
		k.slam_w = {}
		var spins0 := k.spins
		var early := name.begins_with("0.1 s before")
		if early:
			p_v.inp["sec_hold"] = true
			p_v.ak.press_rmb()
			a_x.step(m, 0.1, func(): p_v.inp["sec_hold"] = name.ends_with("(held)"))
			p_v.ak.use_e()
		else:
			p_v.ak.use_e()
		match name:
			"middle":
				a_x.step(m, 0.1)
			"last frame", "0.14 s after arriving":
				while k.warchain.pulling():
					m.step(a_x.DT)
				if name != "last frame":
					a_x.step(m, 0.14)
			"0.1 s after a dash cut it":
				a_x.step(m, 0.04)
				p_v.do_dash()
				a_x.step(m, 0.1)
		if not early:
			a_x.tap(m, p_v)
		a_x.step(m, 0.1)
		p_v.inp["sec_hold"] = false
		a_x.step(m, 0.8)
		a_x.ok("jug spin timing: RMB %s = exactly one Cinder Spin" % name,
				k.spins == spins0 + 1 and k.slam_w.is_empty(), "spins %d" % (k.spins - spins0))
	# outside the pull: the ordinary Smash (a tap on a hooked chain, and well after a pull) is a Slam, no spin
	a_x.step(m, 1.0)
	hook.call()
	k.slam_w = {}
	var spins1 := k.spins
	a_x.tap(m, p_v)
	a_x.ok("jug spin timing: RMB on the hooked chain (no pull) = the Slam", not k.slam_w.is_empty()
			and k.spins == spins1)
	a_x.step(m, 1.0)
	k.warchain.snap()
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	a_x.tap(m, p_v)
	a_x.ok("jug spin timing: RMB 1 s after the chain is gone = the Slam", not k.slam_w.is_empty() and k.spins == spins1)
	a_x.step(m, 1.0)
	k.slam_w = {}
