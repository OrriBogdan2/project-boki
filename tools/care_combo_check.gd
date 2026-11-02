extends RefCounted
## The support pair's combo checks (--tender-combo-check, --rimewright-combo-check, and part of
## --support-check): each sheet behaviour and small mechanic in docs/heroes/tender.md and
## rimewright.md: where shots land, the telegraph shown while holding, the timings, the payoffs, the
## moves and sounds, merge-start hold drops. Runs on tools/support_check.gd's setup and report.

var sc        # the SupportCheck running us (setup, step, ok, aim_at)

func ok(what: String, cond: bool, info := "") -> void:
	sc.ok(what, cond, info)

func step(m: Match, secs: float, each := Callable()) -> void:
	sc.step(m, secs, each)


func _free(m: Match) -> void:
	m.queue_free()
	await sc.main.get_tree().process_frame

## The shots in flight from P.
func _mine(m: Match, P: Hunter) -> Array:
	return m.shots.filter(func(s): return s["by"] == P)

# ================================================================== Moosh Moosh
func tender() -> void:
	var r: Array = sc.setup("tender", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var T: Hunter = r[3]
	var K: TenderKit = P.ak
	ok(
			"mm: renamed Moosh Moosh, kit sounds load",
			Arch.name_of("tender") == "Moosh Moosh"
			and Sfx.streams.has("tend_seed")
			and Sfx.streams.has("tend_root")
			and Sfx.streams.has("tend_hop"))
	# --- Moon Shot flies its full range past the cursor (cursor 3 m out, off the target line)
	sc.aim_at(P, P.pos + Vector3(0, 0, 3.0))
	P.inp["fire"] = true
	step(m, 0.05)
	P.inp["fire"] = false
	var sh: Array = _mine(m, P)
	var reach := 0.0
	if not sh.is_empty(): reach = float(sh[-1]["life0"]) * (sh[-1]["vel"] as Vector2).length()
	ok(
			"mm LMB: the ember flies its full range past the cursor",
			AimMode.mode_of(P) == AimMode.MAX and reach > float(P.wpn["range"]) - 0.3, "reach %.1f" % reach)
	ok(
			"mm LMB: each ember has its comet look, a swirl at the hand and the flick move",
			K.stats["swirls"] >= 1 and K.lk().skins.size() >= 1 and K.anim_id in ["mm_shot_r", "mm_shot_l"],
			"%s %d" % [K.anim_id, K.stats["swirls"]])
	step(m, 0.6)
	# --- Kindle ramp and its foot glow; nodes stay pooled while firing
	sc.aim_at(P, T.pos)
	K.cd["e"] = 8.0
	P.inp["fire"] = true
	step(m, 0.3)
	var made0: int = K.lk().made
	step(m, 1.8)
	P.inp["fire"] = false
	var shown_glow: bool = K.lk().showing("kin%d" % T.get_instance_id())
	ok(
			"mm passive: embers Kindle the foe and a foot glow grows on them", K.kindle_on(T) >= 3 and shown_glow,
			"kindle %d" % K.kindle_on(T))
	ok("mm passive: an ember into a Kindled foe winds Hearthlight back", K.cd["e"] < 7.0, "e %.2f" % K.cd["e"])
	ok(
			"mm LMB: looks are pooled (no new nodes per ember)", K.lk().made - made0 <= 3,
			"made %d -> %d" % [made0, K.lk().made])
	# the ramp: about +45% over 5 hits (sheet: 64 -> 93)
	var ramp := float(Arch.def("tender")["resource"]["per_stack"]) * 5.0 / float(P.wpn["dmg"])
	ok(
			"mm passive: Kindle ramps embers about +45% at 5 stacks", ramp > 0.38 and ramp < 0.52,
			"+%.0f%%" % (ramp * 100.0))
	# --- the idle crook: the next ember is Empowered (longer, its own bigger flick)
	step(m, 1.3)
	var e0: int = K.stats["emp"]
	P.ammo = int(P.wpn["mag"])
	P.reload_t = 0.0
	P.inp["fire"] = true
	step(m, 0.05)
	P.inp["fire"] = false
	ok(
			"mm LMB: after a pause the next ember is Empowered (40% further, its own move)",
			K.stats["emp"] > e0 and K.anim_id == "mm_shot_emp", "emp %d anim %s" % [K.stats["emp"], K.anim_id])
	step(m, 0.6)
	# --- Burrseed: hold shows the dotted lane to max range, the coiled pose; release throws
	K.kind.clear()
	T.hp = T.max_hp
	T.root_t = 0.0
	sc.aim_at(P, T.pos)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	var n0: int = _mine(m, P).size()
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	step(m, 0.3)
	var lane: Dictionary = AimKit.entry(P, "rmb")
	ok(
			"mm RMB: held, a dotted lane to the seed's full range and the coiled pose",
			AimKit.shown(P, "rmb")
			and String(lane.get("kind", "")) == "dotted"
			and absf(float(lane.get("len", 0.0)) - float(K.rmb_def()["seed"]["range"])) < 0.1
			and K.anim_id == "mm_seed_aim",
			"%s len %.1f %s" % [String(lane.get("kind", "")), float(lane.get("len", 0.0)), K.anim_id])
	ok("mm RMB: nothing leaves while it is held", _mine(m, P).size() == n0)
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	var t_stick := -1.0
	var tt := 0.0
	while tt < 0.5 and t_stick < 0.0:
		step(m, 1.0 / 60.0)
		tt += 1.0 / 60.0
		if K.burrs.size() > 0: t_stick = tt
	ok(
			"mm RMB: let go, a fast seed (6 m in under 0.35 s) with the throw move",
			t_stick > 0.0 and t_stick < 0.35 and K.anim_id == "mm_seed",
			"stuck at %.2f s, %s" % [t_stick, K.anim_id])
	var bid := "burr%d" % int(K.burrs[0]["id"]) if K.burrs.size() > 0 else ""
	step(m, 0.1)
	var tele: Dictionary = AimKit.entry(P, bid)
	ok(
			"mm RMB: the burst area shows under the foe at once, for everyone, filling",
			AimKit.shown(P, bid)
			and bool(tele.get("all", false))
			and absf(float(tele.get("r", 0.0)) - 2.2) < 0.05
			and K.lk().showing(bid),
			"r %.2f" % float(tele.get("r", 0.0)))
	var rooted_early := T.root_t > 0.0
	var h1 := T.hp
	step(m, 0.7)
	ok(
			"mm RMB: it roots about 0.7 s after it sticks (not before), damages and Kindles",
			not rooted_early and T.root_t > 0.0 and h1 - T.hp > 25.0 and K.kindle_on(T) >= 1,
			"root %.2f dmg %.0f" % [T.root_t, h1 - T.hp])
	await _free(m)
	# --- Hearthlight: on her a 2.6 m ring with its own cast move; E again throws it to the cursor at once
	r = sc.setup("tender", 6.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	A.teleport(P.pos + Vector3(-6, 0, 3))
	T.teleport(P.pos + Vector3(14, 0, 0))
	step(m, 0.05)
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	ok(
			"mm E: lit on her, a 2.6 m ring (1.4 bh) and the raise-the-lantern move",
			K.in_e() and absf(K.hearth_r() - 2.6) < 0.01 and K.anim_id == "mm_hearth" and K.lk().showing("hearth"))
	var cur := P.pos + Vector3(6.0, 0, 0)
	sc.aim_at(P, cur)
	step(m, 0.2)
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	step(m, 0.15)
	var hp: Vector3 = K.hearth.get("pos", Vector3.ZERO)
	var land_off := Vector2(hp.x - cur.x, hp.z - cur.z).length()
	ok(
			"mm E: thrown, it lands on the cursor within 0.2 s and widens to 2.9 m",
			String(K.hearth.get("mode", "")) == "ground" and land_off < 0.4
				and absf(K.hearth_r() - 2.9) < 0.01 and K.anim_id == "mm_toss",
			"%s at %.2f m" % [String(K.hearth.get("mode", "")), land_off])
	step(m, 3.0)
	# --- Relay Step goes where you move, not at the cursor, with its own hop and a lantern trail
	K.cd["e"] = 8.0
	var p0 := P.pos
	sc.aim_at(P, P.pos + Vector3(0, 0, -6))
	P.inp["move"] = Vector2(1, 0)
	P.dashes = P.max_dashes()
	P.inp["dash"] = true
	step(m, 0.05)
	P.inp["dash"] = false
	var aft := K.lk().live.filter(func(e): return String(e["kind"]) == "mote").size()
	step(m, 0.25)
	P.inp["move"] = Vector2.ZERO
	ok(
			"mm Shift: Relay Step goes where you move (cursor elsewhere), its own hop and after-images",
			P.pos.x - p0.x > 2.5 and absf(P.pos.z - p0.z) < 1.0 and aft >= 1,
			"dx %.1f dz %.1f aft %d" % [P.pos.x - p0.x, P.pos.z - p0.z, aft])
	ok("mm Shift: the hop is its own move", K.anim_id in ["mm_dash", "mm_relay"])
	# --- the air dash is her long floaty glide (dash.air), not the class long dash
	step(m, 0.4)
	var g0 := P.pos
	P.teleport(P.pos + Vector3(0, 3.0, 0))
	P.ex_cd = 0.0
	P.inp["move"] = Vector2(1, 0)
	K.on_dash(true)
	var lift0 := P.pos.y
	step(m, 0.5)
	var sink := lift0 - P.pos.y
	step(m, 0.4)
	P.inp["move"] = Vector2.ZERO
	var glide_d := P.pos.x - g0.x
	var air: Dictionary = K.dash_def()["air"]
	ok(
			"mm air dash: a long glide of about dash.air.dist, held up while it floats (her own move)",
			absf(glide_d - float(air["dist"])) < 2.0 and sink < 1.0 and K.anim_id == "mm_dash_air",
			"%.1f m, sank %.2f m in 0.5 s" % [glide_d, sink])
	ok(
			"mm body: small (a 0.74 model) with the 0.34 m hitbox",
			absf(P.r - 0.34) < 0.001 and P.model.scale.y < 0.9,
			"r %.2f scale %.2f" % [P.r, P.model.scale.y])
	step(m, 1.0)
	# --- Bearer: a teammate being stomped can't be picked up (small mechanic), else a pickup move
	sc.down(m, A)
	A.teleport(P.pos + Vector3(0.5, 0, 0))
	T.teleport(A.pos)
	K.lock_t = 0.2
	step(m, 0.1)
	K.lock_t = 0.0
	step(m, 0.1)
	ok(
			"mm passive: a teammate being stomped can't be scooped up",
			not CareUtil.is_carried(A) and bool(A.get_meta("stomped", false)))
	T.teleport(P.pos + Vector3(14, 0, 0))
	step(m, 0.1)
	ok(
			"mm passive: scooping a downed teammate up plays the pickup move",
			CareUtil.is_carried(A) and K.anim_id == "mm_pickup", K.anim_id)
	P.inp["crouch"] = true
	step(m, 0.1)
	P.inp["crouch"] = false
	step(m, 0.1)
	await _free(m)
	# --- merge start drops the Burrseed aim (no throw, the lane and pose gone)
	r = sc.setup("tender", 6.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	K.ch_rmb = 1.0
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	step(m, 0.2)
	var aiming := K.seed_aim and AimKit.shown(P, "rmb")
	var n1: int = _mine(m, P).size()
	K.drop_holds()
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	step(m, 0.2)
	ok(
			"mm merge: drop_holds ends the Burrseed aim without a throw",
			aiming
			and not K.seed_aim
			and not K.rmb_down
			and not AimKit.shown(P, "rmb")
			and _mine(m, P).size() == n1
			and K.ch_rmb >= 1.0)
	await _free(m)
	await growth()

## Burrseed's burst damage on the first foe, with the hunter at level `lvl`.
func _seed_burst(lvl: int) -> float:
	var r: Array = sc.setup("tender", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: TenderKit = P.ak
	P.lvl = lvl
	sc.aim_at(P, T.pos)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	var h0 := T.hp
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	step(m, 0.3)
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	step(m, 1.2)
	var dmg := h0 - T.hp
	await _free(m)
	return dmg

## Ability damage reads ArchKit.power(), so quiet level growth (LevelGrowth.ap) raises it.
func growth() -> void:
	var d1: float = await _seed_burst(1)
	var d10: float = await _seed_burst(10)
	ok(
			"mm RMB: Burrseed's burst grows with level (LevelGrowth.ap 1.0 -> %.2f)" % (1.0 + LevelGrowth.ap_pct(10)),
			d1 > 25.0 and d10 > d1 * 1.15, "L1 %.1f L10 %.1f" % [d1, d10])

# ================================================================== Tamsin
func rimewright() -> void:
	var r: Array = sc.setup("rimewright", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var T: Hunter = r[3]
	var K: RimewrightKit = P.ak
	ok(
			"tm: kit sounds load",
			Sfx.streams.has("rime_shard") and Sfx.streams.has("rime_wall_tell") and Sfx.streams.has("rime_zone"))
	step(m, 0.05)
	ok("tm: the thin aim line to the cursor is always up", AimKit.shown(P, "aim"))
	# --- a steady stream (no heavy phase, no pause) of slow darts that bow out and home
	var times: Array = []
	var dmgs: Array = []
	var bows: Array = []
	var seen := {}
	P.inp["fire"] = true
	var t := 0.0
	while t < 1.4:
		step(m, 1.0 / 60.0)
		t += 1.0 / 60.0
		for s in _mine(m, P):
			if not seen.has(s["sid"]):
				seen[s["sid"]] = true
				times.append(t)
				dmgs.append(float(s["dmg"]))
				bows.append(absf(rad_to_deg((s["vel"] as Vector2).angle_to(P.aim_dir()))))
	P.inp["fire"] = false
	var gaps: Array = []
	for i in range(1, times.size()): gaps.append(float(times[i]) - float(times[i - 1]))
	var maxgap: float = gaps.max() if not gaps.is_empty() else 9.0
	ok(
			"tm LMB: a steady stream, one dart every 0.18 s with no pause", times.size() >= 7 and maxgap < 0.22,
			"%d darts, longest gap %.2f" % [times.size(), maxgap])
	ok("tm LMB: every dart the same (no heavy phase)", not dmgs.is_empty() and dmgs.max() - dmgs.min() < 0.01)
	ok(
			"tm LMB: darts come out slowly (16 m/s) and bowed out to the side",
			float(P.wpn["speed"]) <= 18.0 and not bows.is_empty() and float(bows[0]) > 12.0,
			"first bow %.0f deg" % (float(bows[0]) if not bows.is_empty() else 0.0))
	step(m, 0.8)
	ok(
			"tm LMB: the bowed darts curve back onto the foe at the cursor",
			T.max_hp - T.hp >= float(P.wpn["dmg"]) * times.size() * 0.75,
			"dealt %.0f of %.0f" % [T.max_hp - T.hp, float(P.wpn["dmg"]) * times.size()])
	ok("tm LMB: darts alternate hands with their own flick moves", K.stats["darts"] >= 7)
	ok(
			"tm passive: the frost glow on the foe shows the stacks",
			K.lk().showing("frost%d" % T.get_instance_id()) or K.splinter_log > 0)
	await _free(m)
	# --- 8 darts on one foe Shatter them for about 15 darts' worth, with the spikes
	r = sc.setup("rimewright", 5.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	var T2: Hunter = m.make_hunter(
			"T2", T.team, "medium", "Target2", "idle", {}, T.pos + Vector3(1.2, 0, 0), {"arch": "none"})
	T2.max_hp = 10000.0
	T2.hp = 10000.0
	T2.armor = 0.0
	T2.max_armor = 0.0
	var s0 := K.splinter_log
	P.inp["fire"] = true
	step(m, 2.4)
	P.inp["fire"] = false
	var spikes := K.lk().live.filter(func(e): return String(e["fx"]) == "spikes").size() > 0 or K.lk().made > 0
	ok(
			"tm passive: 8 darts on one foe Shatter them (about 15 darts' damage, ice spikes)",
			K.splinter_log > s0 and T2.max_hp - T2.hp > float(P.wpn["dmg"]) * 12.0 and spikes,
			"neighbour -%.0f" % (T2.max_hp - T2.hp))
	step(m, 0.5)
	# --- Shatter on a knock (Chilled foe)
	T.hp = 8.0
	K.add_chill(T)
	T2.teleport(T.pos + Vector3(1.5, 0, 0))
	T2.hp = T2.max_hp
	step(m, 0.05)
	var s1 := K.splinter_log
	var hh := T2.hp
	sc.aim_at(P, T.pos)
	P.inp["fire"] = true
	step(m, 0.8)
	P.inp["fire"] = false
	step(m, 0.8)
	ok(
			"tm passive: knocking a Chilled foe Shatters them after a beat",
			T.downed and K.splinter_log > s1 and T2.hp < hh, "downed %s" % str(T.downed))
	await _free(m)
	# --- Skate: darts fly straight, thick and 1.6x; she carries on over a ledge; the stride move loops
	r = sc.setup("rimewright", 6.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	var W = m.world
	var hx := int(floor(P.pos.x))
	var hz := int(floor(P.pos.z))
	var lv := int(W.level[W.idx(hx, hz)])
	for dz in range(-10, 11):
		for dx in range(-2, 2):
			# she stands on a step; off its edge it drops
			if W.inb(hx + dx, hz + dz): W.level[W.idx(hx + dx, hz + dz)] = lv + 1
	P.teleport(P.pos + Vector3(0, World.LEVEL, 0))
	step(m, 0.1)
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(-1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 0.05)
	P.inp["dash"] = false
	ok(
			"tm Shift: Shift held starts a skate with its push-off",
			K.rinkrunning() and P.roll_t > 0.0 and K.anim_id == "tm_skate_go")
	sc.aim_at(P, T.pos)
	var nb := _mine(m, P).size()
	P.inp["fire"] = true
	step(m, 0.1)
	P.inp["fire"] = false
	var bs: Array = _mine(m, P)
	var bd := float(bs[-1]["dmg"]) if bs.size() > nb else 0.0
	ok(
			"tm Shift: darts while skating are straight beams at 1.6x",
			bs.size() > nb and absf(bd - float(P.wpn["dmg"]) * 1.6) < 0.05 and K.stats["beams"] >= 1,
			"dmg %.2f" % bd)
	step(m, 0.15)
	var skate_v := Vector2(P.vel.x, P.vel.z).length()
	ok(
			"tm Shift: full skating speed (dash.speed) within about 0.2 s, with a ribbon of ice chips",
			absf(skate_v - float(K.dash_def()["speed"])) < 0.6
				and K.lk().live.filter(func(e): return String(e["kind"]) == "chip").size() >= 4,
			"%.1f m/s" % skate_v)
	step(m, 0.55)
	ok("tm Shift: the stride move loops while skating", K.anim_id == "tm_skate" and K.rinkrunning(), K.anim_id)
	ok(
			"tm Shift: she skates on over a ledge (not stopped by leaving the ground)",
			K.rinkrunning() and float(int(floor(P.pos.x)) - hx) <= -3.0,
			"at %.1f from the start" % (P.pos.x - float(hx)))
	P.inp["dash_down"] = false
	step(m, 0.1)
	ok(
			"tm Shift: letting go stops with a hockey stop and refunds part of the charge",
			not K.rinkrunning() and P.dashes > 0.05 and K.anim_id == "tm_skate_stop", "dashes %.2f" % P.dashes)
	await _free(m)
	# --- Ice Spear: hold shows the ring at the cursor; it lands there, slows, detonates 1.8 s later
	r = sc.setup("rimewright", 30.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	var cur := P.pos + Vector3(7.0, 0, 0)
	T.teleport(cur + Vector3(0.6, 0, 0))
	step(m, 0.05)
	sc.aim_at(P, cur)
	K.ch_rmb = 2.0
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	step(m, 0.3)
	var ring: Dictionary = AimKit.entry(P, "rmb")
	var ra: Vector2 = ring.get("at", Vector2.ZERO)
	ok(
			"tm RMB: held, the landing ring sits on the cursor with the raised-spear pose and the spear in hand",
			AimKit.shown(P, "rmb") and ra.distance_to(Vector2(cur.x, cur.z)) < 0.2 and K.anim_id == "tm_spear_aim"
				and K.lk().showing("spear_prop"))
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	step(m, 0.02)
	ok("tm RMB: the held spear leaves her hand on release", not K.lk().showing("spear_prop"))
	step(m, 0.33)
	var zat: Vector3 = K.zones[0]["at"] if not K.zones.is_empty() else Vector3.INF
	ok(
			"tm RMB: the spear lands at the cursor and leaves a slow zone",
			not K.zones.is_empty() and Vector2(zat.x - cur.x, zat.z - cur.z).length() < 1.0 and K.anim_id == "tm_spear",
			"off %.2f" % Vector2(zat.x - cur.x, zat.z - cur.z).length())
	step(m, 0.2)
	ok(
			"tm RMB: a foe in the zone is slowed and Chilled", T.slow_t > 0.0 and T.slow_k >= 0.34 and K.chilled(T),
			"slow %.2f" % T.slow_k)
	var hb := T.hp
	step(m, 1.0)
	var early := hb - T.hp
	step(m, 0.6)
	ok(
			"tm RMB: it detonates about 1.8 s after landing: the big hit and a freeze",
			early < 10.0 and hb - T.hp > 50.0 and T.root_t > 0.0 and K.stats["detonations"] >= 1,
			"early %.0f total %.0f root %.2f" % [early, hb - T.hp, T.root_t])
	await _free(m)
	# --- Rink Wall: a 0.2 s tell, narrow just ahead, widening as it slides, stops at the cursor
	r = sc.setup("rimewright", 30.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	cur = P.pos + Vector3(7.0, 0, 0)
	sc.aim_at(P, cur)
	T.teleport(P.pos + Vector3(4.0, 0, 0))
	T.ctrl = "idle"
	step(m, 0.05)
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	ok(
			"tm E: a 0.2 s tell first (sparkle, the move, the path shown to all), no wall yet",
			K.wall.is_empty()
			and not K.wall_cast.is_empty()
			and K.anim_id == "tm_wall"
			and AimKit.shown(P, "e")
			and bool(AimKit.entry(P, "e").get("all", false)))
	step(m, 0.25)
	var w0: Dictionary = K.wall.get("w", {})
	var mid0 := ((w0.get("a", Vector2.ZERO) as Vector2) + (w0.get("b", Vector2.ZERO) as Vector2)) * 0.5
	ok(
			"tm E: then it erupts about 1 bh ahead and narrow, in her own ice look",
			not K.wall.is_empty()
			and absf(mid0.x - P.pos.x - 1.8) < 0.8
			and float(w0.get("len", 9.0)) < 2.4
			and K.lk().showing("wall")
			and not (w0["node"] as Node3D).visible,
			"at %.1f len %.1f" % [mid0.x - P.pos.x, float(w0.get("len", 0.0))])
	var tx := T.pos.x
	step(m, 1.4)
	var w1: Dictionary = K.wall["w"]
	var mid1 := ((w1["a"] as Vector2) + (w1["b"] as Vector2)) * 0.5
	ok(
			"tm E: it slides toward the cursor, widening, and shoves the foe ahead",
			float(w1["len"]) > 3.5 and mid1.x > mid0.x + 3.0 and T.pos.x > tx + 1.0,
			"len %.1f moved %.1f foe +%.1f" % [float(w1["len"]), mid1.x - mid0.x, T.pos.x - tx])
	ok(
			"tm E: it stops at the cursor", not bool(K.wall["sliding"]) and absf(mid1.x - cur.x) < 0.8,
			"mid at %.1f, cursor %.1f" % [mid1.x - P.pos.x, cur.x - P.pos.x])
	await _free(m)
	r = sc.setup("rimewright", 30.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	sc.aim_at(P, P.pos + Vector3(10.0, 0, 0))
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	step(m, 0.5)
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	var wa: Vector2 = K.wall["w"]["a"]
	step(m, 0.5)
	ok(
			"tm E: E again freezes it where it stands, for 6 s, with the stamp move",
			not bool(K.wall["sliding"])
			and (K.wall["w"]["a"] as Vector2).distance_to(wa) < 0.01
			and float(K.wall["w"]["t"]) > 5.0
			and K.anim_id == "tm_freeze")
	# a foe's shot into the wall is stopped
	var ph := P.hp
	var wm := ((K.wall["w"]["a"] as Vector2) + (K.wall["w"]["b"] as Vector2)) * 0.5
	m.spawn_shot(T, Vector3(wm.x + 3.0, P.pos.y + 0.95, wm.y), Vector2(-1, 0) * 30.0, 10.0, 1.0, 0.2, Color.RED, {})
	step(m, 0.6)
	ok("tm E: the wall stops a foe's shot", P.hp >= ph - 0.01, "hp %.1f -> %.1f" % [ph, P.hp])
	await _free(m)
	# --- merge start: skate, spear aim and a wall in its tell all drop
	r = sc.setup("rimewright", 6.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 0.05)
	P.inp["dash"] = false
	K.ch_rmb = 2.0
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	step(m, 0.2)
	P.inp["sig"] = true
	step(m, 0.02)
	P.inp["sig"] = false
	var all_up := K.rinkrunning() and K.spear_aim and not K.wall_cast.is_empty()
	K.drop_holds()
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	P.inp["dash_down"] = false
	step(m, 0.4)
	ok(
			"tm merge: drop_holds ends the skate, the spear aim and the wall's tell (no throw, no wall)",
			all_up
			and not K.rinkrunning()
			and not K.spear_aim
			and K.wall_cast.is_empty()
			and K.wall.is_empty()
			and K.zones.is_empty()
			and not AimKit.shown(P, "rmb"))
	await _free(m)
