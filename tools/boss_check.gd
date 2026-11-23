extends RefCounted
## Headless check for boss lairs: every map has them; the dial opens a gate when every arc is hit and
## a miss resets the lock, chimes and calls guards; runes and ward stones open theirs; the ward keeps
## people out until then; each boss wakes, changes phase at 66% and 33%, enrages, and drops a Rare Egg;
## the egg takes a backpack slot (a full pack asks to swap), stays in your deathbox, comes home on
## extract onto the Incubator by the Nook and hatches a rare kin. Bots can work a dial too.


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var bad := [0]
	var ok := func(cond: bool, what: String) -> void:
		print("BOSS %s %s" % ["ok  " if cond else "FAIL", what])
		if not cond: bad[0] += 1
	# 0. every map has lairs: the authored one, and generated maps of each size an expedition can use
	for sd in [3, 8, 13]:
		var gw := World.new()
		gw.generate(sd, World.BIG_SIZE, World.BIG_ISLANDS)
		ok.call(gw.lair_defs.size() >= 1, "generated big map seed %d has %d lair(s): %s" % [sd, gw.lair_defs.size(), str(gw.lair_defs.map(func(D): return D["boss"]))])
		gw.free()
	var gw2 := World.new()
	gw2.generate(5, 128, 16)
	ok.call(gw2.lair_defs.size() >= 1, "generated mid map has %d lair(s)" % gw2.lair_defs.size())
	gw2.free()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var P: Hunter = m.player
	# boss loot is picked from the killer's class weapons (lairs.gd); with an archetype only its family
	# can be held, so this check plays the classic class kit (see docs/ARCHETYPES.md, gaps)
	P.set_arch("")
	var C: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var Q: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	for h in m.hunters:
		h.ctrl = "idle" if h != P else "local"
		h.inp["move"] = Vector2.ZERO
	var LS: Array = m.lairs.list
	ok.call(LS.size() == 3 and LS.map(func(L): return L["boss"]).has("colossus") and LS.map(func(L): return L["boss"]).has("serpent") and LS.map(func(L): return L["boss"]).has("brood"),
		"Skyreach has 3 lairs: %s" % str(LS.map(func(L): return "%s (%s)" % [L["name"], L["boss"]])))
	# SpawnPlan rolls which lairs are live (the rest lie dormant, rusted shut); the full map announces them
	var live: int = LS.filter(func(L): return L["active"]).size()
	var marks: int = m.spawn_plan.active_of("boss").size() if m.spawn_plan else -1
	ok.call(live >= 2 and live <= 3 and marks == live and LS.filter(func(L): return not L["active"]).all(func(L): return L["state"] == "dormant" and L["boss_mob"] == null),
		"Skyreach rolled %d of 3 lairs live (%d boss markers on the full map), the rest dormant" % [live, marks])
	for L in LS: m.lairs.activate(L)
	# (this check covers the dial, runes and wards; --lair-breach-check the Gate Seal)
	for L in LS: m.lairs.breach.as_dial(L)
	var by_boss := {}
	for L in LS: by_boss[L["boss"]] = L
	var sealed_ok := true
	for L in LS:
		for q in L["gate_tiles"]:
			if m.world.kind[m.world.idx(q.x, q.y)] != World.T_BLOCK: sealed_ok = false
		if L["boss_mob"] == null or not (L["boss_mob"] as Boss).dormant or L["state"] != "sealed": sealed_ok = false
	ok.call(sealed_ok, "every gate starts sealed, each boss asleep inside")
	var god := func():
		for h in [P, C]:
			h.hp = h.max_hp; h.armor = h.max_armor
			if h.downed: m.revive_hunter(h, h)
	var run := func(sec: float, each := Callable()):
		var t := 0.0
		while t < sec:
			if each.is_valid(): each.call()
			god.call()
			m.step(Match.DT); t += Match.DT
	var spot := func(h: Hunter, at: Vector3): h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z)); h.vel = Vector3.ZERO
	var park := func(h: Hunter):
		var at: Vector3 = m.world.spawns[0] if not m.world.spawns.is_empty() else m.world.random_ground()
		spot.call(h, at)
		# (a parked hunter just stands there: clear the monsters round it, or they shove it about until
		# one knock sends it over the island's edge and out of the match)
		for mb in m.mobs:
			if not (mb is Boss) and not mb.dead and mb.flat_dist(at) < 18.0:
				print("BOSS  park: cleared a %s %.1fm from the parking spot" % [mb.mkind, mb.flat_dist(at)])
				mb.dead = true; mb.visible = false
	# 1. the ward keeps you out while it's sealed
	var F: Dictionary = by_boss["colossus"]
	spot.call(P, F["c"] + Vector3(2, 0, 2))
	run.call(0.1)
	ok.call(not m.lairs.inside(F, P.pos, 0.0), "the seal throws you out of a sealed lair (now %.1fm from its middle)" % P.flat_dist(F["c"]))
	# 2. the dial: press on every lit arc, through all four locks
	spot.call(P, F["dial"])
	for g in F["guards"]: if is_instance_valid(g): g.dead = true
	var prev := [false]
	var press_right := func():
		var fire := false
		if not m.lairs.puzzle_of(P).is_empty() and float(F["jam"]) <= 0.0 and float(F["grace"]) <= 0.0:
			var nxt := float(F["needle"]) + float(F["dir"]) * m.lairs.speed_of(F) * Match.DT
			for t in F["targets"]:
				if not t["hit"] and absf(wrapf(nxt - float(t["a"]), -PI, PI)) <= float(t["w"]) * 0.5 - 0.03: fire = true
		elif m.lairs.puzzle_of(P).is_empty():
			fire = true      # the first press starts the dial
		P.inp["interact"] = fire and not prev[0]
		prev[0] = P.inp["interact"]
	var t0 := m.time
	while F["state"] == "sealed" and m.time - t0 < 60.0:
		press_right.call()
		god.call()
		m.step(Match.DT)
	P.inp["interact"] = false
	ok.call(F["state"] == "open" and int(F["fails"]) == 0 and int(F["lock"]) == 4, "dial: %d locks opened in %.1fs with no misses, gate %s" % [int(F["lock"]), m.time - t0, F["state"]])
	var gate_open := true
	for q in F["gate_tiles"]:
		if m.world.kind[m.world.idx(q.x, q.y)] != World.T_GROUND: gate_open = false
	ok.call(gate_open, "the gate's tiles are open ground now")
	# 3. a miss: hit one arc, then press off the arcs. The lock resets, the chime pings, guards come.
	var E: Dictionary = by_boss["serpent"]
	Q.ctrl = "local"
	spot.call(Q, E["dial"])
	spot.call(P, E["dial"] + Vector3(E["out"].x, 0, E["out"].y) * 6.0)
	# the gate's guards go for whoever works the dial: a bomber's blast or a spitter's hit could knock Q
	# off the lectern (the dial stops) or down, depending only on how the frames fall. Keep Q on it and
	# standing: this part tests the dial's miss, not surviving the guards
	var pin := func():
		Q.hp = Q.max_hp; Q.armor = Q.max_armor
		if Q.downed: m.revive_hunter(Q, Q)
		if Q.flat_dist(E["dial"]) > 0.25: spot.call(Q, E["dial"])
	Q.inp["interact"] = true; run.call(Match.DT, pin); Q.inp["interact"] = false; run.call(0.4, pin)
	var hit_one := false
	var tq := m.time
	while not hit_one and m.time - tq < 8.0:
		var nxt := float(E["needle"]) + float(E["dir"]) * m.lairs.speed_of(E) * Match.DT
		var on := false
		for t in E["targets"]:
			if absf(wrapf(nxt - float(t["a"]), -PI, PI)) <= float(t["w"]) * 0.5 - 0.03: on = true
		Q.inp["interact"] = on and not Q.inp["interact"]
		run.call(Match.DT, pin)
		hit_one = (E["targets"] as Array).any(func(t): return t["hit"])
	Q.inp["interact"] = false; run.call(Match.DT, pin)
	var guards0: int = m.lairs._guards_alive(E)
	var pings0 := m.pings.size()
	var feed0 := m.feed_all.size()
	while m.lairs.target_under(E) >= 0:
		run.call(Match.DT, pin)
	Q.inp["interact"] = true; run.call(Match.DT, pin); Q.inp["interact"] = false
	var any_hit: bool = (E["targets"] as Array).any(func(t): return t["hit"])
	ok.call(hit_one and int(E["fails"]) == 1 and not any_hit and int(E["lock"]) == 0 and float(E["jam"]) > 0.0, "miss: the lock resets (fails %d, arcs lit again, jammed %.1fs)" % [int(E["fails"]), float(E["jam"])])
	ok.call(m.lairs._guards_alive(E) > guards0 and m.pings.size() > pings0 and m.feed_all.slice(feed0).any(func(f): return String(f).contains("chime")) and Q.reveal_t > 2.0,
		"miss: chime pings nearby players, reveals the presser, guards %d -> %d" % [guards0, m.lairs._guards_alive(E)])
	Q.ctrl = "idle"
	park.call(Q)
	run.call(0.5)
	# 4. runes open the Eyrie, wards open the Thornhive
	for rn in E["runes"]:
		spot.call(P, rn["pos"] + Vector3(0.6, 0, 0))
		P.inp["interact"] = true
		run.call(Match.DT * 2)
		var tr := m.time
		while not rn["lit"] and m.time - tr < 4.0:
			# (the guards each rune calls are fought for real in a match; here they'd only shove the test hunter off)
			for g in E["guards"]: if is_instance_valid(g): g.dead = true
			P.inp["interact"] = true
			run.call(Match.DT)
	P.inp["interact"] = false
	ok.call(E["runes"].size() == 3 and E["state"] == "open", "runes: %d pylons lit, the Eyrie is %s" % [E["runes"].filter(func(r): return r["lit"]).size(), E["state"]])
	var H: Dictionary = by_boss["brood"]
	var wards: Array = H["wards"]
	for wd in wards:
		spot.call(P, wd.pos + Vector3(1.2, 0, 0))
		wd.hurt(30.0, P, {"src": "shot"})
		run.call(0.2)
		wd.hurt(9999.0, P, {"src": "shot"})
		run.call(0.1)
	ok.call(wards.size() == 3 and H["state"] == "open" and m.lairs._guards_alive(H) > 0, "wards: %d broken (guards came out: %d), the Thornhive is %s" % [wards.filter(func(x): return x.dead).size(), m.lairs._guards_alive(H), H["state"]])
	# 4b. sealed in like a raid: free to come and go before the fight; step in and the gate shuts
	# behind you until the boss dies, you all go down, or the seal times out
	for g in F["guards"]: if is_instance_valid(g) and not g.dead: g.dead = true; g.visible = false
	park.call(C); park.call(Q)
	var outv := Vector2(F["out"].x, F["out"].y)
	var walk := func(h: Hunter, dir: Vector2, sec: float, until := Callable()) -> void:
		var t := 0.0
		while t < sec:
			h.inp["move"] = dir
			m.step(Match.DT); t += Match.DT
			if until.is_valid() and until.call(): break
		h.inp["move"] = Vector2.ZERO
		m.step(Match.DT)
	var gate_shut := func(L: Dictionary) -> bool:
		return (L["gate_tiles"] as Array).all(func(q): return m.world.kind[m.world.idx(q.x, q.y)] == World.T_BLOCK)
	var gate_free := func(L: Dictionary) -> bool:
		return (L["gate_tiles"] as Array).all(func(q): return m.world.kind[m.world.idx(q.x, q.y)] == World.T_GROUND)
	var fb: Boss = F["boss_mob"]
	# before the fight: walk up into the gateway and back out again, the boss sleeping
	spot.call(P, F["dial"])
	walk.call(P, -outv, 6.0, func(): return m.lairs.inside(F, P.pos, 0.3))
	var in_gateway: bool = m.lairs.inside(F, P.pos, 0.3) and F["state"] == "open"
	walk.call(P, outv, 1.5)      # (1.5 s: 3 s walked off the island edge, which is allowed now)
	ok.call(in_gateway and F["state"] == "open" and fb.dormant and not F.get("locked", false) and not m.lairs.inside(F, P.pos, 0.5) and gate_free.call(F),
		"before the fight: into the gateway and back out, the boss still asleep (%.1fm out)" % P.flat_dist(F["c"]))
	# step in: it wakes and the gate seals behind you, the ward lit
	walk.call(P, -outv, 6.0, func(): return F["state"] == "awake")
	walk.call(P, -outv, 0.4)
	ok.call(F["state"] == "awake" and F.get("locked", false) and (F["sealed_in"] as Array).has(P) and gate_shut.call(F) and m.lairs.sealed_lair(P) == F,
		"walk in: %s wakes and the gate seals behind you (locked %s, gate shut %s)" % [fb.md["name"], F.get("locked", false), gate_shut.call(F)])
	ok.call(Lairs.LOCK_T == 90.0 and m.lairs.lock_left(F) > 88.5 and m.lairs.lock_left(F) <= 90.0 and float(fb.md["enrage"]) < Lairs.LOCK_T,
		"the seal holds for at most %ds (%s left on the clock); %s enrages at %ds, inside it" % [int(Lairs.LOCK_T), Lairs.clock(m.lairs.lock_left(F)), fb.md["name"], int(fb.md["enrage"])])
	var dome: Node3D = F["nodes"]["dome"]
	run.call(0.6)
	ok.call(dome.visible and float(F["gate_k"]) < 0.05 and ((F["nodes"]["gate"] as Node3D).get_node("Bars") as Node3D).visible, "the bars are back down and the ward glows over the walls")
	# no way out while it's sealed: walking, or being flung over the wall
	walk.call(P, outv, 4.0)
	var walked_in := m.lairs.inside(F, P.pos, 0.0)
	P.pos = F["c"] + Vector3(outv.x, 0, outv.y) * (float(F["half"]) + 1.5); P.prev = P.pos
	run.call(0.1)
	ok.call(walked_in and m.lairs.inside(F, P.pos, 0.0) and F.get("locked", false), "sealed: walking at the gate or being flung over the wall keeps you inside")
	# nobody crashes in
	spot.call(Q, F["dial"])
	Q.ctrl = "local"
	walk.call(Q, -outv, 4.0)
	ok.call(not m.lairs.inside(F, Q.pos, 0.25), "sealed: a rival can't get in (%.1fm from the middle)" % Q.flat_dist(F["c"]))
	Q.ctrl = "idle"; park.call(Q)
	# bots: sealed in, they fight; outside, a sealed lair isn't a goal
	var bg: Array = m.lairs.bot_goal(P, true)
	Q.ai["boss_hunt"] = true
	var qg: Array = m.lairs.bot_goal(Q, false)
	ok.call(not bg.is_empty() and String(bg[1]) == "lair_fight" and (qg.is_empty() or (qg[0] as Vector3).distance_to(F["c"]) > 1.0),
		"bots: sealed in they fight it (%s); a sealed lair isn't a goal from outside (%s)" % [str(bg.slice(1)), str(qg.slice(1))])
	# everyone inside goes down: the seal breaks and the boss heals and goes back to sleep
	fb.hurt(fb.max_hp * 0.2, P, {"src": "shot"})
	var hp_hurt := fb.hp
	P.lives = 3
	m.knock(P, null, {})
	m.step(Match.DT); m.step(Match.DT)
	ok.call(P.downed and hp_hurt < fb.max_hp and not F.get("locked", false) and F["state"] == "open" and fb.dormant and fb.hp >= fb.max_hp and gate_free.call(F),
		"wiped: the seal breaks, %s heals (%d -> %d) and sleeps" % [fb.md["name"], int(hp_hurt), int(fb.hp)])
	m.revive_hunter(P, P)
	god.call()
	# the seal times out: it drops and the boss resets
	spot.call(P, F["c"] + Vector3(outv.x, 0, outv.y) * 2.0)
	var tl := m.time
	while not F.get("locked", false) and m.time - tl < 10.0: run.call(Match.DT)      # (it lets you be a moment after a reset)
	var relocked: bool = F.get("locked", false)
	fb.hurt(fb.max_hp * 0.1, P, {"src": "shot"})
	F["lock_at"] = m.time - Lairs.LOCK_T + 0.2
	run.call(0.5)
	ok.call(relocked and not F.get("locked", false) and fb.dormant and fb.hp >= fb.max_hp and F["state"] == "open", "the seal times out after %ds: it drops and the boss resets" % int(Lairs.LOCK_T))
	# unsealed: the way out through the gate is clear
	spot.call(P, F["c"])
	run.call(0.1)
	if F.get("locked", false):
		F["lock_at"] = m.time - Lairs.LOCK_T; run.call(0.2)
	walk.call(P, outv, 6.0, func(): return not m.lairs.inside(F, P.pos, 1.5))
	ok.call(not m.lairs.inside(F, P.pos, 1.0) and not F.get("locked", false), "unsealed: you walk out through the gate (%.1fm from the middle)" % P.flat_dist(F["c"]))
	run.call(13.0)      # (the boss settles back to sleep with nobody inside)
	# 5. each boss: wakes when you walk in, phases at 66% and 33%, attacks, enrages, drops its egg
	var egg_items: Array = []
	for h in [P, C]:      # (a kin's own attacks and abilities would move the scripted hp thresholds; its species is random)
		for k in [h.kin, h.kin2]:
			if k != null:
				k.dead = true
				k.visible = false
	for L in [F, E, H]:
		for g in L["guards"]: if is_instance_valid(g) and not g.dead: g.dead = true; g.visible = false
		var b: Boss = L["boss_mob"]
		spot.call(P, L["c"] + Vector3(L["out"].x, 0, L["out"].y) * 3.0)
		spot.call(C, L["c"] + Vector3(-L["out"].y, 0, L["out"].x) * 3.0)
		run.call(0.3)
		ok.call(L["state"] == "awake" and not b.dormant and L.get("locked", false) and (L["sealed_in"] as Array).has(P) and (L["sealed_in"] as Array).has(C), "%s wakes when you walk in and seals you both in" % b.md["name"])
		var atks := {}
		var track := func(): if b.atk != "": atks[b.atk] = true
		run.call(6.0, track)
		if b.buried: b._clear_attack()      # (a burrowed Brood Mother can't be hit: bring her up for the scripted hits)
		b.stagger_t = 0.0; b.stag_open = 0.0     # (nor staggered: a kin's ability can stagger it, and a staggered boss takes 2.5x)
		b.hurt(b.max_hp * 0.36, P, {"src": "shot"})
		run.call(0.1, track)
		var p1 := b.phase
		var hp_a := b.hp
		if b.buried: b._clear_attack()
		b.stagger_t = 0.0; b.stag_open = 0.0
		b.hurt(100.0, P, {"src": "shot"})
		var invul_ok := hp_a - b.hp < 30.0
		run.call(8.0, track)
		if b.buried: b._clear_attack()
		b.stagger_t = 0.0; b.stag_open = 0.0
		b.hurt(b.max_hp * 0.4, P, {"src": "shot"})
		run.call(0.1, track)
		var p2 := b.phase
		run.call(8.0, track)
		b.awake_t = float(b.md["enrage"]) - 0.05
		run.call(0.2, track)
		var enr := b.enraged
		ok.call(p1 == 1 and p2 == 2 and invul_ok and enr, "%s: phase 2 at 66%%, phase 3 at 33%% (shrugs off hits while it roars), enraged after %ds" % [b.md["name"], int(b.md["enrage"])])
		if not (p1 == 1 and p2 == 2 and invul_ok and enr):
			print("BOSS  (phases %d %d, invul %s, enraged %s, hp %d/%d, dead %s, damage by team %s, feed %s)" % [p1, p2, invul_ok, enr, int(b.hp), int(b.max_hp), b.dead, str(b.damage_by), str(m.feed_all.slice(-8))])
		ok.call(atks.size() >= 3, "%s used %d attacks: %s" % [b.md["name"], atks.size(), str(atks.keys())])
		var w0 := m.wpicks.size(); var brands0 := P.perks.filter(func(k): return String(k).begins_with("brand_")).size()      # (a Brand dropped where you stand is taken on the spot)
		spot.call(P, L["c"] + Vector3(L["out"].x, 0, L["out"].y) * 3.0)     # (a shove may have sent you out of the lair)
		P.lvl = 1; P.xp = 0.0
		var xp0 := P.xp
		b.hp = 1.0
		if b.buried: b._clear_attack()
		b.hurt(5.0, P, {"src": "shot"})
		run.call(0.2)
		var ew = L.get("egg_wp")
		var egg_shown: bool = m.feed_all.any(func(t): return " got the " in String(t) and String(t).ends_with(" Egg"))
		var egg_n: int = m.hunters.reduce(func(n, h): return n + h.pack.filter(func(it): return Loot.is_rare_egg(it)).size(), 0) + m.wpicks.slice(w0).filter(func(wp): return wp.has("egg")).size()
		var egg_ok: bool = egg_n == 1 and m.hunters.all(func(h): return h.pack.all(
				func(it): return not Loot.is_rare_egg(it) or not Data.no_egg(String(it["sp"]))))
		var strong: bool = m.wpicks.slice(w0).any(func(wp): return wp.has("gear") and int(wp["rar"]) >= 3)
		var kill_t := m.time - 0.2
		for a in L["adds"]: if is_instance_valid(a) and not a.dead: a.dead = true; a.visible = false     # (the brood scatters; here it'd only shove the test hunters about)
		var lvn: Node3D = L["nodes"]["lever"]
		var vent: Node3D = L["nodes"]["vent"]
		ok.call(L.get("locked", false) and L.get("victory", false) and gate_shut.call(L) and L.get("up_on", false) and (lvn.get_node("Lit") as Node3D).visible and (vent.get_node("Air") as Node3D).visible
			and m.lairs.victory_left(L) > Lairs.VICTORY_T - 0.5 and m.lairs.sealed_lair(P) == L,
			"%s falls: the gate stays shut (opens in %s), the lever lit, the updraft blowing" % [b.md["name"], Lairs.clock(m.lairs.victory_left(L))])
		var pile_now: Array = m.wpicks.slice(w0)      # the drop as it landed (walking about can pick some of it up)
		# no walking out yet
		spot.call(P, L["c"] + Vector3(L["out"].x, 0, L["out"].y) * (float(L["half"]) - 2.0))
		walk.call(P, Vector2(L["out"].x, L["out"].y), 1.2)
		ok.call(m.lairs.inside(L, P.pos, 0.0) and gate_shut.call(L), "after the kill: walking at the shut gate keeps you in")
		spot.call(P, L["c"] + Vector3(L["out"].x, 0, L["out"].y) * 3.0)
		# a small pile, all of it good
		var pile: Array = pile_now.filter(func(wp): return not wp.get("egg", false))
		var usable: bool = pile.any(func(wp): return wp.has("gear") and int(wp["rar"]) >= 3) and (pile.any(func(wp): return wp.has("tune")) or P.perks.filter(func(k): return String(k).begins_with("brand_")).size() > brands0)
		var good: bool = pile.all(func(wp): return int(wp["rar"]) >= 3 if not wp.has("val") else Loot.value(Pack.ground_item(wp)) >= 40)
		ok.call(pile.size() <= 4 and usable and good,
			"%s's loot: %d things, all good (%s), an Epic+ piece of gear and a Brand upgrade" % [b.md["name"], pile.size(), str(pile.map(func(wp): return String(wp["gear"]) + " " + str(wp["rar"]) if wp.has("gear") else (String(wp["tune"]) if wp.has("tune") else Loot.name_of(Pack.ground_item(wp)))))])
		var outL := Vector3(L["out"].x, 0, L["out"].y)
		var vic: bool = L.get("victory", false)
		if L == F:
			# the lever: a press away from it does nothing; at it, the gate opens (pressed well clear of the loot
			# and the egg: beside them it would pick them up, and where they land follows the fight)
			var clear := func(q: Vector3) -> float:
				return m.wpicks.reduce(func(d, wp): return minf(d, q.distance_to(wp["pos"])), 99.0)
			var spots: Array = [-3.0, 0.0, 3.0].map(func(d): return L["c"] + outL * d)
			spots.sort_custom(func(a, c): return clear.call(a) > clear.call(c))
			spot.call(P, spots[0])
			P.inp["interact"] = true; run.call(Match.DT); P.inp["interact"] = false; run.call(Match.DT)
			var held: bool = L.get("locked", false)
			spot.call(P, L["lever"] - outL * 0.8)
			var it: Dictionary = m.lairs.interact_for(P)
			run.call(0.1)
			P.inp["interact"] = true; run.call(Match.DT); P.inp["interact"] = false; run.call(0.3)
			ok.call(vic and held and String(it.get("what", "")) == "lever" and String(it.get("label", "")) == "%s: Open the gate" % Settings.key_cap("interact")
				and not L.get("locked", false) and gate_free.call(L) and not L.get("up_on", false) and String(L.get("opened_by_lever", "")) == P.pname,
				"the lever: '%s'; pulled %.1fs after the kill, the gate opens and the updraft dies down" % [it.get("label", "?"), m.time - kill_t])
		elif L == E:
			# the updraft: anyone who wasn't sealed in gets no lift from it
			var up: Vector3 = L["up"]
			Q.ctrl = "local"
			Q.teleport(up + Vector3(0, 6.0, 0)); Q.vel = Vector3.ZERO; Q.grounded = false
			var qy0 := Q.pos.y
			var qy := qy0
			var tq2 := 0.0
			while tq2 < 0.5:
				m.step(Match.DT); tq2 += Match.DT; god.call()
				qy = maxf(qy, Q.pos.y)
			var refused: bool = not (L["flown"] as Array).has(Q) and qy <= qy0 + 0.05 and not Q.auto_glide
			spot.call(Q, up)
			run.call(0.2)
			# (a person walks off an island's edge now, so an outsider shoved off the lair may fall out of the match: that counts as shoved out)
			refused = refused and not (L["flown"] as Array).has(Q) and Q.pos.y < float(L["c"].y) + 1.0 and (Q.out or not m.lairs.inside(L, Q.pos, 0.0))
			ok.call(refused, "the updraft refuses outsiders: no lift over it (%.2fm), shoved off and out (%.1fm from the middle)" % [qy - qy0, Q.flat_dist(L["c"])])
			if Q.out or Q.downed: Life.bring_back(m, Q, m.world.spawns[0] if not m.world.spawns.is_empty() else m.world.random_ground(), 1.0, false)
			Q.ctrl = "idle"; park.call(Q)
			# a hunter who fought rides it: up over the wall and away from the back, the gate still shut
			spot.call(P, up)
			var top := P.pos.y
			var shut_when_out := false
			var tf := 0.0
			while tf < 12.0:
				m.step(Match.DT); tf += Match.DT; god.call()
				top = maxf(top, P.pos.y)
				if not m.lairs.inside(L, P.pos, 0.3) and not shut_when_out: shut_when_out = gate_shut.call(L) and L.get("locked", false)
				if P.grounded and not m.lairs.inside(L, P.pos, 0.5): break
			var rel: Vector3 = P.pos - L["c"]
			var back: float = -rel.dot(outL)
			ok.call((L["flown"] as Array).has(P) and top > float(L["c"].y) + 6.0 and not m.lairs.inside(L, P.pos, 0.5) and shut_when_out and P.grounded and rel.dot(outL) < float(L["half"]) * 0.5 and not P.out and m.lairs.sealed_lair(P).is_empty(),
				"the updraft: lifts you %.1fm over the floor, over the wall and away (%.1fm behind the lair's middle, landed %s) while the gate stays shut" % [top - float(L["c"].y), back, P.grounded])
			# nobody pulls the lever: it opens by itself after VICTORY_T
			var ta := m.time
			while L.get("locked", false) and m.time - ta < Lairs.VICTORY_T + 2.0: run.call(Match.DT)
			ok.call(not L.get("locked", false) and gate_free.call(L) and not L.get("up_on", false) and absf(m.time - kill_t - Lairs.VICTORY_T) < 0.25 and String(L.get("opened_by_lever", "?")) == "",
				"nobody at the lever: the gate opens by itself %.1fs after the kill, the updraft dies down" % (m.time - kill_t))
		else:
			# a bot sealed in after the kill: the lever with nobody outside, the updraft with rivals at the gate
			C.ai["egg_" + String(L["id"])] = false      # (this bot leaves the egg to you)
			var g0: Array = m.lairs.bot_goal(C, false)
			spot.call(Q, m.lairs.camp_spot(L, Q))
			var g1: Array = m.lairs.bot_goal(C, false)
			ok.call(not g0.is_empty() and String(g0[1]) == "lair_lever" and not g1.is_empty() and String(g1[1]) == "lair_updraft" and m.lairs.campers(L, C.team) >= 1,
				"bots after the kill: no one at the gate, pull the lever (%s); rivals camping it, the updraft (%s)" % [str(g0.slice(1)), str(g1.slice(1))])
			# and it does: walks into the updraft and glides out over the wall
			L["victory_at"] = m.time      # (a fresh clock: this part is about the bot, not the timer)
			C.ctrl = "bot"
			var tb2 := 0.0
			while tb2 < 16.0 and (m.lairs.inside(L, C.pos, 0.5) or not C.grounded):
				m.step(Match.DT); tb2 += Match.DT; god.call()
				Q.hp = Q.max_hp
			ok.call((L["flown"] as Array).has(C) and not m.lairs.inside(L, C.pos, 0.5) and not C.out and L.get("locked", false),
				"a bot rides the updraft out with rivals at the gate (%.1fs, %.1fm from the gate, the gate still shut)" % [tb2, C.flat_dist(L["gate_c"])])
			C.ctrl = "idle"; C.inp["move"] = Vector2.ZERO
			Q.ctrl = "idle"; park.call(Q)
			spot.call(P, L["lever"] - outL * 0.8)
			run.call(0.1)
			P.inp["interact"] = true; run.call(Match.DT); P.inp["interact"] = false; run.call(0.3)
			park.call(C)
		# the way out is clear
		if m.lairs.inside(L, P.pos, 0.0): spot.call(P, L["c"] + outL * 3.0)
		var tw := 0.0
		while m.lairs.inside(L, P.pos, 1.0) and tw < 8.0:
			P.inp["move"] = Vector2(L["out"].x, L["out"].y) if absf(P.pos.x - L["gate_c"].x) + absf(P.pos.z - L["gate_c"].z) < 2.0 or m.lairs.inside(L, P.pos, -2.0) == false else Vector2(L["gate_c"].x - P.pos.x, L["gate_c"].z - P.pos.z).normalized()
			god.call(); m.step(Match.DT); tw += Match.DT
		P.inp["move"] = Vector2.ZERO
		ok.call(not m.lairs.inside(L, P.pos, 1.0), "after the kill you walk out through the gate (%.1fs)" % tw)
		ok.call(L["state"] == "cleared" and egg_ok and strong and P.xp > xp0 + 100.0 and egg_shown,
			"%s falls: exactly one Rare Egg, to one hunter in the pit (told in the feed), an Epic+ weapon, +%d XP" % [b.md["name"], int(P.xp - xp0)])
		var holder: Array = [P, C].filter(func(h): return h.pack.any(func(it): return Loot.is_rare_egg(it)))
		if holder.size() == 1:      # (the later steps use it lying on the ground)
			var egg: Dictionary = holder[0].pack.filter(func(it): return Loot.is_rare_egg(it))[0]
			holder[0].pack.erase(egg)
			egg_items.append(m.lairs.drop_egg(L, egg, L["c"]))
		elif ew != null: egg_items.append(ew)
	# 6. the egg takes a pack slot: a full pack asks what to leave
	var ew0: Dictionary = egg_items[0]
	spot.call(P, ew0["pos"])
	P.pack_cap = 2
	P.pack = [Loot.valuable("old_coin"), Loot.valuable("sky_pearl")]
	Pack.take_ground(m, P, ew0)
	ok.call(m.hud.swap_open() and m.wpicks.has(ew0), "full pack: the egg opens the swap window")
	Pack.swap(m, P, 0, ew0)
	m.hud.close_swap()
	var egg_it: Dictionary = P.pack.filter(func(it): return Loot.is_rare_egg(it))[0] if P.pack.any(func(it): return Loot.is_rare_egg(it)) else {}
	ok.call(not egg_it.is_empty() and P.pack.size() == 2, "the Rare Egg is in the pack (%s)" % str(P.pack.map(func(it): return Loot.name_of(it))))
	run.call(0.2)
	ok.call(m.lairs.egg_pings.any(func(e): return e.get("follow") == P), "picking it up shows the carrier to everyone for a few seconds")
	# 7. die with it: it's in your deathbox; a teammate smart-loots it
	P.lives = 1
	m.eliminate(P, Q, "knocked out")
	var bx := Life.box_of(m, P)
	var in_box: bool = not bx.is_empty() and (bx.get("pack", []) as Array).any(func(it): return Loot.is_rare_egg(it))
	ok.call(in_box, "dead: the egg is in your deathbox")
	spot.call(C, bx["pos"])
	C.pack = [Loot.valuable("old_coin"), Loot.valuable("kin_idol"), Loot.valuable("sky_pearl")]
	C.pack_cap = 3
	Life.smart_loot(m, C, bx)
	ok.call(C.pack.any(func(it): return Loot.is_rare_egg(it)), "smart loot takes the egg first, even from a full pack")
	# 8. extract: the egg goes to the Incubator (not the breeding nest), it hatches a rare kin
	Save.d["roster"] = [Save.new_kin("cindle", "Pip")]
	Save.d["active"] = Save.d["roster"][0]["uid"]
	Save.d["incubator"] = {}; Save.d["rare_eggs"] = []; Save.d["egg"] = {}
	var out := Game.apply_result({"extracted": true, "haul": Pack.haul(C), "tier": 0, "gems": 0, "kin_runs": []})
	var q: Array = [Incubator.eggs()[0]] if not Incubator.eggs().is_empty() else []
	ok.call(q.size() == 1 and not Data.no_egg(String(q[0]["sp"])) and (out.get("haul", []) as Array).any(func(it): return Loot.is_rare_egg(it)),
		"extract: a %s goes to the Incubator %s" % [Data.egg_name(String(q[0]["sp"])) if not q.is_empty() else "?", str(q)])
	ok.call(not Incubator.eggs().is_empty() and Save.d.get("egg", {}).is_empty() and Save.d.get("rare_eggs", []).is_empty(), "home: it goes straight into the Incubator's cradle (the breeding nest stays free)")
	var rr := RandomNumberGenerator.new(); rr.seed = 3
	var inc_egg: Dictionary = Incubator.eggs()[0].duplicate()
	var baby := Care.hatch_rare(inc_egg, rr)
	ok.call(not Data.no_egg(String(baby["species"])) and baby.get("rare", false) and String(baby["species"]) == String(inc_egg["sp"]),
		"hatch: a rare-egg %s (%s)" % [Data.KIN[baby["species"]]["name"], baby["species"]])
	# 9. rare kin never turn up wild, on rivals or as a starter
	var any_rare := false
	for i in 60:
		if Data.is_rare(String(m.bot_kin_record()["species"])): any_rare = true
	var rares: Array = Data.KIN.keys().filter(func(k): return Data.is_rare(k))
	ok.call(not any_rare and Data.common_kin().size() + rares.size() == Data.KIN.size() and rares.size() >= 2,
		"rare species (%s) only come from eggs" % str(rares))
	m.queue_free()
	# 10. a bot can work a dial
	var m2 := Match.new()
	main.add_child(m2)
	m2.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4, "no_drop": true, "autoplay": true})
	m2.set_process(false)
	var B: Hunter = m2.hunters[1]
	for h in m2.hunters:
		if h != B: h.ctrl = "idle"; h.teleport(m2.world.spawns[0])
	var L2: Dictionary = m2.lairs.list[0]
	m2.lairs.activate(L2)
	m2.lairs.breach.as_dial(L2)      # (a dial test: bots breaking a seal down are --lair-breach-check's)
	# the only lair it can go for: bots don't plan lairs in a match's first 25 s and roam instead,
	# then take the nearest live one, so with the other rolled-live lairs about, where that roam ended
	# (which drifts with the RNG stream the earlier sections leave) decided which gate it worked
	for x in m2.lairs.list:
		if x != L2 and x["state"] == "sealed":
			x["state"] = "dormant"; m2.lairs._tint_dormant(x, true)
	# ... and it has to find its way back across the islands: every route a bot takes lands on the
	# island it leads to (a bridge route that landed on the island it left looped the bot round it)
	var W2 := m2.world
	var bad_links: Array = W2.links.filter(func(lk): return W2.island_of(lk["land"].x, lk["land"].z) != int(lk["to"]))
	ok.call(bad_links.is_empty(), "every glide, wind and bridge route lands on the island it leads to (%d of %d don't: %s)" % [bad_links.size(), W2.links.size(), str(bad_links.slice(0, 3).map(func(lk): return "%d>%d land %s" % [lk["from"], lk["to"], str(lk["land"])]))])
	for g in L2["guards"]: g.dead = true
	B.ai["skill"] = 0.9
	B.ai["boss_hunt"] = true
	B.teleport(L2["dial"] + Vector3(L2["out"].x, 0, L2["out"].y) * 4.0)
	var tb := m2.time
	if "--boss-only-dial" in OS.get_cmdline_user_args(): print("  dial bot: %s %s %s" % [B.cls, B.arch, B.wid])
	# a dial test, not a loot test: no chests or ground loot to wander off to first
	for c in m2.chests: c["open"] = true
	m2.pickups.clear()
	while L2["state"] == "sealed" and m2.time - tb < 150.0:
		if "--boss-only-dial" in OS.get_cmdline_user_args() and int(m2.time * 60.0) % 300 == 0:
			print("  t=%.0f pos=%s dial=%.1f goal=%s kind=%s tgt=%s user=%s inter=%s" % [m2.time - tb, B.pos.snapped(Vector3(0.1,0.1,0.1)), B.flat_dist(L2["dial"]), str(B.ai.get("goal")), B.ai.get("goal_kind"), str(B.ai.get("tgt")), str(L2["user"]), B.inp.get("interact")])
		B.hp = B.max_hp
		for g in L2["guards"]: if is_instance_valid(g): g.dead = true
		m2.step(Match.DT)
	ok.call(L2["state"] != "sealed", "a bot walked up and opened %s in %.0fs (%d misses)" % [L2["name"], m2.time - tb, int(L2["fails"])])
	m2.queue_free()
	# 10b. the fight is loud: everyone outside within ALERT_R hears it start (a roar, a ping with the
	# boss's icon, a shaft of light over the lair, the seal's clock over the gate) and its boss fall;
	# bots that hear it may camp the gate, the stronger squads more often; bots sealed in get out by
	# the lever, or by the updraft when rivals wait at the gate
	var m4 := Match.new()
	main.add_child(m4)
	m4.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m4.set_process(false)
	var P4: Hunter = m4.player
	for h in m4.hunters:
		h.ctrl = "idle" if h != P4 else "local"
		h.inp["move"] = Vector2.ZERO
	var A: Dictionary = m4.lairs.list.filter(func(x): return x["boss"] == "colossus")[0]
	m4.lairs.activate(A)
	for g in A["guards"]: if is_instance_valid(g): g.dead = true; g.visible = false
	m4.lairs.open(A, null, "dial")
	var spot4 := func(h: Hunter, at: Vector3): h.teleport(Vector3(at.x, m4.world.ground_at(at.x, at.z), at.z)); h.vel = Vector3.ZERO
	var run4 := func(sec: float):
		var t := 0.0
		while t < sec:
			for h in m4.hunters:
				if not h.out: h.hp = h.max_hp
			m4.step(Match.DT); t += Match.DT
	var teams4 := {}
	for h in m4.hunters:
		if h.team != P4.team: teams4[h.team] = teams4.get(h.team, []) + [h]
	var tk: Array = teams4.keys()
	var R1: Hunter = teams4[tk[0]][0]; var R2: Hunter = teams4[tk[0]][1]
	var S1: Hunter = teams4[tk[1]][0]; var S2: Hunter = teams4[tk[1]][1]
	var C4: Hunter = m4.hunters.filter(func(x): return x.team == P4.team and x != P4)[0]
	var outA := Vector3(A["out"].x, 0, A["out"].y)
	var sideA := Vector3(-A["out"].y, 0, A["out"].x)
	# where everyone is when it starts: you and your mate by the gate, one rival a way off, one far away
	spot4.call(P4, A["dial"] + outA * 4.0)
	spot4.call(C4, A["dial"] + outA * 4.0 + sideA * 2.0)
	var mid_at := Vector3.INF; var far_at := Vector3.INF
	for i in 500:
		var gp: Vector3 = m4.world.random_ground()
		if m4.lairs.lair_of(gp, 2.0).size() > 0: continue
		var gd := Vector2(gp.x - A["c"].x, gp.z - A["c"].z).length()
		if gd > 50.0 and gd < 120.0 and mid_at == Vector3.INF: mid_at = gp
		if far_at == Vector3.INF or gd > Vector2(far_at.x - A["c"].x, far_at.z - A["c"].z).length(): far_at = gp
	spot4.call(S1, mid_at)
	spot4.call(S2, far_at)
	var far_real := S2.flat_dist(A["c"])
	if far_real <= Lairs.ALERT_R:
		S2.pos = A["c"] + (S2.pos - A["c"]).normalized() * (Lairs.ALERT_R + 10.0); S2.prev = S2.pos     # (the map isn't that big: put it out of earshot for the moment)
	var pings4 := m4.pings.size()
	var feed4 := m4.feed_all.size()
	# a rival squad walks in and the fight starts
	spot4.call(R1, A["c"] + outA * 1.5 + sideA * 1.5)
	spot4.call(R2, A["c"] + outA * 1.5 - sideA * 1.5)
	var tl4 := 0.0
	while not A.get("locked", false) and tl4 < 1.0:
		m4.step(Match.DT); tl4 += Match.DT
	var s2_far := S2.flat_dist(A["c"])
	spot4.call(S2, far_at)
	var heard_f: Array = m4.lairs.alert_log.filter(func(e): return e["lair"] == A["id"] and e["kind"] == "fight").map(func(e): return e["nid"])
	var lbl4: Label3D = A["nodes"]["label"]
	var beam4: Node3D = A["nodes"]["beam"]
	ok.call(A.get("locked", false) and (A["sealed_in"] as Array).has(R1) and (A["sealed_in"] as Array).has(R2) and not (A["sealed_in"] as Array).has(P4),
		"a rival squad walks into %s: sealed in with %s, you outside" % [A["name"], A["boss_mob"].md["name"]])
	ok.call(heard_f.has(P4.nid) and heard_f.has(C4.nid) and heard_f.has(S1.nid) and not heard_f.has(S2.nid) and not heard_f.has(R1.nid),
		"the fight is heard by everyone outside within %dm (you, your mate, a rival %.0fm off) but not %.0fm away, nor by those inside" % [int(Lairs.ALERT_R), S1.flat_dist(A["c"]), s2_far])
	var pinged: bool = m4.pings.slice(pings4).any(func(pg): return Vector2(pg["pos"].x - A["c"].x, pg["pos"].z - A["c"].z).length() < 1.0)
	var fed: bool = m4.feed_all.slice(feed4).any(func(f): return String(f).contains("fight at %s" % A["name"]))
	ok.call(pinged and fed and m4.lairs.alerted(A, P4) and beam4.visible and lbl4.text.contains("FIGHT") and lbl4.text.contains(Lairs.clock(m4.lairs.lock_left(A))),
		"outside: a ping on the lair (boss icon on the map), '%s', the beam over the lair, the seal's clock over the gate ('%s')" % [String(A.get("alert_text", "")), lbl4.text.replace("\n", " / ")])
	# bots outside that heard it: camp it, the stronger squads more often, never when leaving
	S1.ctrl = "bot"
	var odds_full: float = m4.lairs.camp_odds(S1)
	S1.hp = S1.max_hp * 0.3; S2.hp = S2.max_hp * 0.3
	var odds_hurt: float = m4.lairs.camp_odds(S1)
	S1.hp = S1.max_hp; S2.hp = S2.max_hp
	S1.ai["camp_" + String(A["id"])] = true
	var cg: Array = m4.lairs.bot_goal(S1, false)
	var cg_leave: Array = m4.lairs.bot_goal(S1, true)
	S2.ai["camp_" + String(A["id"])] = true
	var cg_deaf: Array = m4.lairs.bot_goal(S2, false)
	ok.call(odds_full > odds_hurt and not cg.is_empty() and String(cg[1]) == "lair_camp" and not m4.lairs.inside(A, cg[0], 0.5) and (cg[0] as Vector3).distance_to(A["gate_c"]) < 9.0
		and (cg_leave.is_empty() or String(cg_leave[1]) != "lair_camp") and (cg_deaf.is_empty() or String(cg_deaf[1]) != "lair_camp"),
		"bots that heard it may camp the gate (odds %.2f with the squad up, %.2f hurt; %s); not when leaving, nor if they never heard it" % [odds_full, odds_hurt, str(cg.slice(1))])
	S1.ctrl = "idle"
	spot4.call(S1, cg[0])
	# the boss falls: a different cry, the ping turns to "fallen", the gate's clock over the gate
	var feed4b := m4.feed_all.size()
	var bA: Boss = A["boss_mob"]
	bA.hurt(bA.max_hp * 3.0, R1, {"src": "shot"})
	run4.call(0.1)
	for a in A["adds"]: if is_instance_valid(a) and not a.dead: a.dead = true; a.visible = false
	var heard_v: Array = m4.lairs.alert_log.filter(func(e): return e["lair"] == A["id"] and e["kind"] == "fallen").map(func(e): return e["nid"])
	ok.call(A.get("victory", false) and heard_v.has(P4.nid) and heard_v.has(S1.nid) and String(A.get("alert", "")) == "fallen" and m4.feed_all.slice(feed4b).any(func(f): return String(f).contains("has fallen"))
		and lbl4.text.contains("has fallen") and lbl4.text.contains("gate opens") and beam4.visible,
		"the boss falls: everyone near hears it ('%s'), the clock over the gate: '%s'" % [String(A.get("alert_text", "")), lbl4.text.replace("\n", " / ")])
	# sealed-in bots: S1 waits at the gate, so R1 takes the updraft; with nobody there R2 takes the lever
	spot4.call(P4, A["dial"] + outA * 30.0 if not m4.world.is_void((A["dial"] + outA * 30.0).x, (A["dial"] + outA * 30.0).z) else far_at)
	spot4.call(C4, P4.pos + sideA * 1.5)
	R1.ai["egg_" + String(A["id"])] = false; R2.ai["egg_" + String(A["id"])] = false     # (straight out: the egg is another test)
	var gR1: Array = m4.lairs.bot_goal(R1, false)
	R1.ctrl = "bot"
	var tr1 := 0.0
	while tr1 < 11.0 and (m4.lairs.inside(A, R1.pos, 0.5) or not R1.grounded):
		run4.call(Match.DT); tr1 += Match.DT
	var r1_out: bool = (A["flown"] as Array).has(R1) and not m4.lairs.inside(A, R1.pos, 0.5) and A.get("locked", false)
	R1.ctrl = "idle"; R1.inp["move"] = Vector2.ZERO
	spot4.call(S1, far_at)
	A["victory_at"] = m4.time       # (a fresh clock for R2)
	var gR2: Array = m4.lairs.bot_goal(R2, false)
	R2.ctrl = "bot"
	var tr2 := 0.0
	while tr2 < 10.0 and A.get("locked", false):
		run4.call(Match.DT); tr2 += Match.DT
	ok.call(String(gR1[1]) == "lair_updraft" and r1_out and String(gR2[1]) == "lair_lever" and not A.get("locked", false) and String(A.get("opened_by_lever", "")) == R2.pname,
		"bots sealed in: with a rival camping the gate one rides the updraft out (%.1fs); with nobody there the other pulls the lever (%.1fs)" % [tr1, tr2])
	m4.queue_free()
	# 11. a generated map rolls at least one live lair too
	var m3 := Match.new()
	main.add_child(m3)
	m3.start({"teams": 2, "squad": 1, "tier": 1, "length": 1e9, "seed": 8, "no_drop": true, "procedural": true, "autoplay": true})
	m3.set_process(false)
	var live3: int = m3.lairs.list.filter(func(L): return L["active"]).size()
	ok.call(m3.lairs.list.size() >= 1 and live3 >= 1, "a generated map: %d lair(s), %d live (%s)" % [m3.lairs.list.size(), live3, str(m3.lairs.list.map(func(L): return L["boss"]))])
	print("BOSSCHECK done, failures: %d" % bad[0])
	main.get_tree().quit(1 if bad[0] > 0 else 0)
