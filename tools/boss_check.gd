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
		if not cond:
			bad[0] += 1
	# 0. every map has lairs: the authored one, and generated maps of each size an expedition can use
	for sd in [3, 8, 13]:
		var gw := World.new()
		gw.generate(sd, World.BIG_SIZE, World.BIG_ISLANDS)
		ok.call(
			gw.lair_defs.size() >= 1,
			(
				"generated big map seed %d has %d lair(s): %s"
				% [sd, gw.lair_defs.size(), str(gw.lair_defs.map(func(d_v): return d_v["boss"]))]
			)
		)
		gw.free()
	var gw2 := World.new()
	gw2.generate(5, 128, 16)
	ok.call(gw2.lair_defs.size() >= 1, "generated mid map has %d lair(s)" % gw2.lair_defs.size())
	gw2.free()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var p: Hunter = m.player
	# boss loot is picked from the killer's class weapons (lairs.gd); with an archetype only its family
	# can be held, so this check plays the classic class kit (see docs/ARCHETYPES.md, gaps)
	p.set_arch("")
	var c_v: Hunter = m.hunters.filter(func(x): return x.team == p.team and x != p)[0]
	var q_v: Hunter = m.hunters.filter(func(x): return x.team != p.team)[0]
	for h in m.hunters:
		h.ctrl = "idle" if h != p else "local"
		h.inp["move"] = Vector2.ZERO
	var ls: Array = m.lairs.list
	ok.call(
		(
			ls.size() == 3
			and ls.map(func(l): return l["boss"]).has("colossus")
			and ls.map(func(l): return l["boss"]).has("serpent")
			and ls.map(func(l): return l["boss"]).has("brood")
		),
		"Skyreach has 3 lairs: %s" % str(ls.map(func(l): return "%s (%s)" % [l["name"], l["boss"]]))
	)
	# SpawnPlan rolls which lairs are live (the rest lie dormant, rusted shut); the full map announces them
	var live: int = ls.filter(func(l): return l["active"]).size()
	var marks: int = m.spawn_plan.active_of("boss").size() if m.spawn_plan else -1
	ok.call(
		(
			live >= 2
			and live <= 3
			and marks == live
			and (
				ls
				. filter(func(l): return not l["active"])
				. all(func(l): return l["state"] == "dormant" and l["boss_mob"] == null)
			)
		),
		"Skyreach rolled %d of 3 lairs live (%d boss markers on the full map), the rest dormant" % [live, marks]
	)
	for l in ls:
		m.lairs.activate(l)
	# (this check covers the dial, runes and wards; --lair-breach-check the Gate Seal)
	for l in ls:
		m.lairs.breach.as_dial(l)
	var by_boss := {}
	for l in ls:
		by_boss[l["boss"]] = l
	var sealed_ok := true
	for l in ls:
		for q in l["gate_tiles"]:
			if m.world.kind[m.world.idx(q.x, q.y)] != World.T_BLOCK:
				sealed_ok = false
		if l["boss_mob"] == null or not (l["boss_mob"] as Boss).dormant or l["state"] != "sealed":
			sealed_ok = false
	ok.call(sealed_ok, "every gate starts sealed, each boss asleep inside")
	var god := func():
		for h in [p, c_v]:
			h.hp = h.max_hp
			h.armor = h.max_armor
			if h.downed:
				m.revive_hunter(h, h)
	var run := func(sec: float, each := Callable()):
		var t := 0.0
		while t < sec:
			if each.is_valid():
				each.call()
			god.call()
			m.step(Match.DT)
			t += Match.DT
	var spot := func(h: Hunter, at: Vector3):
		h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
		h.vel = Vector3.ZERO
	var park := func(h: Hunter):
		var at: Vector3 = m.world.spawns[0] if not m.world.spawns.is_empty() else m.world.random_ground()
		spot.call(h, at)
		# (a parked hunter just stands there: clear the monsters round it, or they shove it about until
		# one knock sends it over the island's edge and out of the match)
		for mb in m.mobs:
			if not (mb is Boss) and not mb.dead and mb.flat_dist(at) < 18.0:
				print("BOSS  park: cleared a %s %.1fm from the parking spot" % [mb.mkind, mb.flat_dist(at)])
				mb.dead = true
				mb.visible = false
	# 1. the ward keeps you out while it's sealed
	var f_v: Dictionary = by_boss["colossus"]
	spot.call(p, f_v["c"] + Vector3(2, 0, 2))
	run.call(0.1)
	ok.call(
		not m.lairs.inside(f_v, p.pos, 0.0),
		"the seal throws you out of a sealed lair (now %.1fm from its middle)" % p.flat_dist(f_v["c"])
	)
	# 2. the dial: press on every lit arc, through all four locks
	spot.call(p, f_v["dial"])
	for g in f_v["guards"]:
		if is_instance_valid(g):
			g.dead = true
	var prev := [false]
	var press_right := func():
		var fire := false
		if not m.lairs.puzzle_of(p).is_empty() and float(f_v["jam"]) <= 0.0 and float(f_v["grace"]) <= 0.0:
			var nxt := float(f_v["needle"]) + float(f_v["dir"]) * m.lairs.speed_of(f_v) * Match.DT
			for t in f_v["targets"]:
				if not t["hit"] and absf(wrapf(nxt - float(t["a"]), -PI, PI)) <= float(t["w"]) * 0.5 - 0.03:
					fire = true
		elif m.lairs.puzzle_of(p).is_empty():
			fire = true  # the first press starts the dial
		p.inp["interact"] = fire and not prev[0]
		prev[0] = p.inp["interact"]
	var t0 := m.time
	while f_v["state"] == "sealed" and m.time - t0 < 60.0:
		press_right.call()
		god.call()
		m.step(Match.DT)
	p.inp["interact"] = false
	ok.call(
		f_v["state"] == "open" and int(f_v["fails"]) == 0 and int(f_v["lock"]) == 4,
		"dial: %d locks opened in %.1fs with no misses, gate %s" % [int(f_v["lock"]), m.time - t0, f_v["state"]]
	)
	var gate_open := true
	for q in f_v["gate_tiles"]:
		if m.world.kind[m.world.idx(q.x, q.y)] != World.T_GROUND:
			gate_open = false
	ok.call(gate_open, "the gate's tiles are open ground now")
	# 3. a miss: hit one arc, then press off the arcs. The lock resets, the chime pings, guards come.
	var e_v: Dictionary = by_boss["serpent"]
	q_v.ctrl = "local"
	spot.call(q_v, e_v["dial"])
	spot.call(p, e_v["dial"] + Vector3(e_v["out"].x, 0, e_v["out"].y) * 6.0)
	# the gate's guards go for whoever works the dial: a bomber's blast or a spitter's hit could knock Q
	# off the lectern (the dial stops) or down, depending only on how the frames fall. Keep Q on it and
	# standing: this part tests the dial's miss, not surviving the guards
	var pin := func():
		q_v.hp = q_v.max_hp
		q_v.armor = q_v.max_armor
		if q_v.downed:
			m.revive_hunter(q_v, q_v)
		if q_v.flat_dist(e_v["dial"]) > 0.25:
			spot.call(q_v, e_v["dial"])
	q_v.inp["interact"] = true
	run.call(Match.DT, pin)
	q_v.inp["interact"] = false
	run.call(0.4, pin)
	var hit_one := false
	var tq := m.time
	while not hit_one and m.time - tq < 8.0:
		var nxt := float(e_v["needle"]) + float(e_v["dir"]) * m.lairs.speed_of(e_v) * Match.DT
		var on := false
		for t in e_v["targets"]:
			if absf(wrapf(nxt - float(t["a"]), -PI, PI)) <= float(t["w"]) * 0.5 - 0.03:
				on = true
		q_v.inp["interact"] = on and not q_v.inp["interact"]
		run.call(Match.DT, pin)
		hit_one = (e_v["targets"] as Array).any(func(t): return t["hit"])
	q_v.inp["interact"] = false
	run.call(Match.DT, pin)
	var guards0: int = m.lairs._guards_alive(e_v)
	var pings0 := m.pings.size()
	var feed0 := m.feed_all.size()
	while m.lairs.target_under(e_v) >= 0:
		run.call(Match.DT, pin)
	q_v.inp["interact"] = true
	run.call(Match.DT, pin)
	q_v.inp["interact"] = false
	var any_hit: bool = (e_v["targets"] as Array).any(func(t): return t["hit"])
	ok.call(
		hit_one and int(e_v["fails"]) == 1 and not any_hit and int(e_v["lock"]) == 0 and float(e_v["jam"]) > 0.0,
		"miss: the lock resets (fails %d, arcs lit again, jammed %.1fs)" % [int(e_v["fails"]), float(e_v["jam"])]
	)
	ok.call(
		(
			m.lairs._guards_alive(e_v) > guards0
			and m.pings.size() > pings0
			and m.feed_all.slice(feed0).any(func(f): return String(f).contains("chime"))
			and q_v.reveal_t > 2.0
		),
		"miss: chime pings nearby players, reveals the presser, guards %d -> %d" % [guards0, m.lairs._guards_alive(e_v)]
	)
	q_v.ctrl = "idle"
	park.call(q_v)
	run.call(0.5)
	# 4. runes open the Eyrie, wards open the Thornhive
	for rn in e_v["runes"]:
		spot.call(p, rn["pos"] + Vector3(0.6, 0, 0))
		p.inp["interact"] = true
		run.call(Match.DT * 2)
		var tr := m.time
		while not rn["lit"] and m.time - tr < 4.0:
			# (the guards each rune calls are fought for real in a match; here they'd only shove the test hunter off)
			for g in e_v["guards"]:
				if is_instance_valid(g):
					g.dead = true
			p.inp["interact"] = true
			run.call(Match.DT)
	p.inp["interact"] = false
	ok.call(
		e_v["runes"].size() == 3 and e_v["state"] == "open",
		"runes: %d pylons lit, the Eyrie is %s" % [e_v["runes"].filter(func(r): return r["lit"]).size(), e_v["state"]]
	)
	var h_v: Dictionary = by_boss["brood"]
	var wards: Array = h_v["wards"]
	for wd in wards:
		spot.call(p, wd.pos + Vector3(1.2, 0, 0))
		wd.hurt(30.0, p, {"src": "shot"})
		run.call(0.2)
		wd.hurt(9999.0, p, {"src": "shot"})
		run.call(0.1)
	ok.call(
		wards.size() == 3 and h_v["state"] == "open" and m.lairs._guards_alive(h_v) > 0,
		(
			"wards: %d broken (guards came out: %d), the Thornhive is %s"
			% [wards.filter(func(x): return x.dead).size(), m.lairs._guards_alive(h_v), h_v["state"]]
		)
	)
	# 4b. sealed in like a raid: free to come and go before the fight; step in and the gate shuts
	# behind you until the boss dies, you all go down, or the seal times out
	for g in f_v["guards"]:
		if is_instance_valid(g) and not g.dead:
			g.dead = true
			g.visible = false
	park.call(c_v)
	park.call(q_v)
	var outv := Vector2(f_v["out"].x, f_v["out"].y)
	var walk := func(h: Hunter, dir: Vector2, sec: float, until := Callable()) -> void:
		var t := 0.0
		while t < sec:
			h.inp["move"] = dir
			m.step(Match.DT)
			t += Match.DT
			if until.is_valid() and until.call():
				break
		h.inp["move"] = Vector2.ZERO
		m.step(Match.DT)
	var gate_shut := func(l: Dictionary) -> bool:
		return (l["gate_tiles"] as Array).all(func(q): return m.world.kind[m.world.idx(q.x, q.y)] == World.T_BLOCK)
	var gate_free := func(l: Dictionary) -> bool:
		return (l["gate_tiles"] as Array).all(func(q): return m.world.kind[m.world.idx(q.x, q.y)] == World.T_GROUND)
	var fb: Boss = f_v["boss_mob"]
	# before the fight: walk up into the gateway and back out again, the boss sleeping
	spot.call(p, f_v["dial"])
	walk.call(p, -outv, 6.0, func(): return m.lairs.inside(f_v, p.pos, 0.3))
	var in_gateway: bool = m.lairs.inside(f_v, p.pos, 0.3) and f_v["state"] == "open"
	walk.call(p, outv, 1.5)  # (1.5 s: 3 s walked off the island edge, which is allowed now)
	ok.call(
		(
			in_gateway
			and f_v["state"] == "open"
			and fb.dormant
			and not f_v.get("locked", false)
			and not m.lairs.inside(f_v, p.pos, 0.5)
			and gate_free.call(f_v)
		),
		"before the fight: into the gateway and back out, the boss still asleep (%.1fm out)" % p.flat_dist(f_v["c"])
	)
	# step in: it wakes and the gate seals behind you, the ward lit
	walk.call(p, -outv, 6.0, func(): return f_v["state"] == "awake")
	walk.call(p, -outv, 0.4)
	ok.call(
		(
			f_v["state"] == "awake"
			and f_v.get("locked", false)
			and (f_v["sealed_in"] as Array).has(p)
			and gate_shut.call(f_v)
			and m.lairs.sealed_lair(p) == f_v
		),
		(
			"walk in: %s wakes and the gate seals behind you (locked %s, gate shut %s)"
			% [fb.md["name"], f_v.get("locked", false), gate_shut.call(f_v)]
		)
	)
	ok.call(
		(
			Lairs.LOCK_T == 90.0
			and m.lairs.lock_left(f_v) > 88.5
			and m.lairs.lock_left(f_v) <= 90.0
			and float(fb.md["enrage"]) < Lairs.LOCK_T
		),
		(
			"the seal holds for at most %ds (%s left on the clock); %s enrages at %ds, inside it"
			% [int(Lairs.LOCK_T), Lairs.clock(m.lairs.lock_left(f_v)), fb.md["name"], int(fb.md["enrage"])]
		)
	)
	var dome: Node3D = f_v["nodes"]["dome"]
	run.call(0.6)
	ok.call(
		(
			dome.visible
			and float(f_v["gate_k"]) < 0.05
			and ((f_v["nodes"]["gate"] as Node3D).get_node("Bars") as Node3D).visible
		),
		"the bars are back down and the ward glows over the walls"
	)
	# no way out while it's sealed: walking, or being flung over the wall
	walk.call(p, outv, 4.0)
	var walked_in := m.lairs.inside(f_v, p.pos, 0.0)
	p.pos = f_v["c"] + Vector3(outv.x, 0, outv.y) * (float(f_v["half"]) + 1.5)
	p.prev = p.pos
	run.call(0.1)
	ok.call(
		walked_in and m.lairs.inside(f_v, p.pos, 0.0) and f_v.get("locked", false),
		"sealed: walking at the gate or being flung over the wall keeps you inside"
	)
	# nobody crashes in
	spot.call(q_v, f_v["dial"])
	q_v.ctrl = "local"
	walk.call(q_v, -outv, 4.0)
	ok.call(
		not m.lairs.inside(f_v, q_v.pos, 0.25),
		"sealed: a rival can't get in (%.1fm from the middle)" % q_v.flat_dist(f_v["c"])
	)
	q_v.ctrl = "idle"
	park.call(q_v)
	# bots: sealed in, they fight; outside, a sealed lair isn't a goal
	var bg: Array = m.lairs.bot_goal(p, true)
	q_v.ai["boss_hunt"] = true
	var qg: Array = m.lairs.bot_goal(q_v, false)
	ok.call(
		(
			not bg.is_empty()
			and String(bg[1]) == "lair_fight"
			and (qg.is_empty() or (qg[0] as Vector3).distance_to(f_v["c"]) > 1.0)
		),
		(
			"bots: sealed in they fight it (%s); a sealed lair isn't a goal from outside (%s)"
			% [str(bg.slice(1)), str(qg.slice(1))]
		)
	)
	# everyone inside goes down: the seal breaks and the boss heals and goes back to sleep
	fb.hurt(fb.max_hp * 0.2, p, {"src": "shot"})
	var hp_hurt := fb.hp
	p.lives = 3
	m.knock(p, null, {})
	m.step(Match.DT)
	m.step(Match.DT)
	ok.call(
		(
			p.downed
			and hp_hurt < fb.max_hp
			and not f_v.get("locked", false)
			and f_v["state"] == "open"
			and fb.dormant
			and fb.hp >= fb.max_hp
			and gate_free.call(f_v)
		),
		"wiped: the seal breaks, %s heals (%d -> %d) and sleeps" % [fb.md["name"], int(hp_hurt), int(fb.hp)]
	)
	m.revive_hunter(p, p)
	god.call()
	# the seal times out: it drops and the boss resets
	spot.call(p, f_v["c"] + Vector3(outv.x, 0, outv.y) * 2.0)
	var tl := m.time
	while not f_v.get("locked", false) and m.time - tl < 10.0:
		run.call(Match.DT)  # (it lets you be a moment after a reset)
	var relocked: bool = f_v.get("locked", false)
	fb.hurt(fb.max_hp * 0.1, p, {"src": "shot"})
	f_v["lock_at"] = m.time - Lairs.LOCK_T + 0.2
	run.call(0.5)
	ok.call(
		relocked and not f_v.get("locked", false) and fb.dormant and fb.hp >= fb.max_hp and f_v["state"] == "open",
		"the seal times out after %ds: it drops and the boss resets" % int(Lairs.LOCK_T)
	)
	# unsealed: the way out through the gate is clear
	spot.call(p, f_v["c"])
	run.call(0.1)
	if f_v.get("locked", false):
		f_v["lock_at"] = m.time - Lairs.LOCK_T
		run.call(0.2)
	walk.call(p, outv, 6.0, func(): return not m.lairs.inside(f_v, p.pos, 1.5))
	ok.call(
		not m.lairs.inside(f_v, p.pos, 1.0) and not f_v.get("locked", false),
		"unsealed: you walk out through the gate (%.1fm from the middle)" % p.flat_dist(f_v["c"])
	)
	run.call(13.0)  # (the boss settles back to sleep with nobody inside)
	# 5. each boss: wakes when you walk in, phases at 66% and 33%, attacks, enrages, drops its egg
	var egg_items: Array = []
	for h in [p, c_v]:  # (a kin's own attacks and abilities would move the scripted hp thresholds; its species is random)
		for k in [h.kin, h.kin2]:
			if k != null:
				k.dead = true
				k.visible = false
	for l in [f_v, e_v, h_v]:
		for g in l["guards"]:
			if is_instance_valid(g) and not g.dead:
				g.dead = true
				g.visible = false
		var b: Boss = l["boss_mob"]
		spot.call(p, l["c"] + Vector3(l["out"].x, 0, l["out"].y) * 3.0)
		spot.call(c_v, l["c"] + Vector3(-l["out"].y, 0, l["out"].x) * 3.0)
		run.call(0.3)
		ok.call(
			(
				l["state"] == "awake"
				and not b.dormant
				and l.get("locked", false)
				and (l["sealed_in"] as Array).has(p)
				and (l["sealed_in"] as Array).has(c_v)
			),
			"%s wakes when you walk in and seals you both in" % b.md["name"]
		)
		var atks := {}
		var track := func():
			if b.atk != "":
				atks[b.atk] = true
		run.call(6.0, track)
		if b.buried:
			b._clear_attack()  # (a burrowed Brood Mother can't be hit: bring her up for the scripted hits)
		b.stagger_t = 0.0
		b.stag_open = 0.0  # (nor staggered: a kin's ability can stagger it, and a staggered boss takes 2.5x)
		b.hurt(b.max_hp * 0.36, p, {"src": "shot"})
		run.call(0.1, track)
		var p1 := b.phase
		var hp_a := b.hp
		if b.buried:
			b._clear_attack()
		b.stagger_t = 0.0
		b.stag_open = 0.0
		b.hurt(100.0, p, {"src": "shot"})
		var invul_ok := hp_a - b.hp < 30.0
		run.call(8.0, track)
		if b.buried:
			b._clear_attack()
		b.stagger_t = 0.0
		b.stag_open = 0.0
		b.hurt(b.max_hp * 0.4, p, {"src": "shot"})
		run.call(0.1, track)
		var p2 := b.phase
		run.call(8.0, track)
		b.awake_t = float(b.md["enrage"]) - 0.05
		run.call(0.2, track)
		var enr := b.enraged
		ok.call(
			p1 == 1 and p2 == 2 and invul_ok and enr,
			(
				"%s: phase 2 at 66%%, phase 3 at 33%% (shrugs off hits while it roars), enraged after %ds"
				% [b.md["name"], int(b.md["enrage"])]
			)
		)
		if not (p1 == 1 and p2 == 2 and invul_ok and enr):
			print(
				(
					"BOSS  (phases %d %d, invul %s, enraged %s, hp %d/%d, dead %s, damage by team %s, feed %s)"
					% [
						p1,
						p2,
						invul_ok,
						enr,
						int(b.hp),
						int(b.max_hp),
						b.dead,
						str(b.damage_by),
						str(m.feed_all.slice(-8))
					]
				)
			)
		ok.call(atks.size() >= 3, "%s used %d attacks: %s" % [b.md["name"], atks.size(), str(atks.keys())])
		var w0 := m.wpicks.size()
		var brands0 := p.perks.filter(func(k): return String(k).begins_with("brand_")).size()  # (a Brand dropped where you stand is taken on the spot)
		spot.call(p, l["c"] + Vector3(l["out"].x, 0, l["out"].y) * 3.0)  # (a shove may have sent you out of the lair)
		p.lvl = 1
		p.xp = 0.0
		var xp0 := p.xp
		b.hp = 1.0
		if b.buried:
			b._clear_attack()
		b.hurt(5.0, p, {"src": "shot"})
		run.call(0.2)
		var ew = l.get("egg_wp")
		var egg_shown: bool = m.feed_all.any(func(t): return " got the " in String(t) and String(t).ends_with(" Egg"))
		var egg_n: int = (
			m.hunters.reduce(func(n, h): return n + h.pack.filter(func(it): return Loot.is_rare_egg(it)).size(), 0)
			+ m.wpicks.slice(w0).filter(func(wp): return wp.has("egg")).size()
		)
		var holds_no_egg := func(h):
			return h.pack.all(func(it): return not Loot.is_rare_egg(it) or not Data.no_egg(String(it["sp"])))
		var egg_ok: bool = egg_n == 1 and m.hunters.all(holds_no_egg)
		var strong: bool = m.wpicks.slice(w0).any(func(wp): return wp.has("gear") and int(wp["rar"]) >= 3)
		var kill_t := m.time - 0.2
		for a in l["adds"]:
			if is_instance_valid(a) and not a.dead:
				a.dead = true
				a.visible = false  # (the brood scatters; here it'd only shove the test hunters about)
		var lvn: Node3D = l["nodes"]["lever"]
		var vent: Node3D = l["nodes"]["vent"]
		ok.call(
			(
				l.get("locked", false)
				and l.get("victory", false)
				and gate_shut.call(l)
				and l.get("up_on", false)
				and (lvn.get_node("Lit") as Node3D).visible
				and (vent.get_node("Air") as Node3D).visible
				and m.lairs.victory_left(l) > Lairs.VICTORY_T - 0.5
				and m.lairs.sealed_lair(p) == l
			),
			(
				"%s falls: the gate stays shut (opens in %s), the lever lit, the updraft blowing"
				% [b.md["name"], Lairs.clock(m.lairs.victory_left(l))]
			)
		)
		var pile_now: Array = m.wpicks.slice(w0)  # the drop as it landed (walking about can pick some of it up)
		# no walking out yet
		spot.call(p, l["c"] + Vector3(l["out"].x, 0, l["out"].y) * (float(l["half"]) - 2.0))
		walk.call(p, Vector2(l["out"].x, l["out"].y), 1.2)
		ok.call(
			m.lairs.inside(l, p.pos, 0.0) and gate_shut.call(l), "after the kill: walking at the shut gate keeps you in"
		)
		spot.call(p, l["c"] + Vector3(l["out"].x, 0, l["out"].y) * 3.0)
		# a small pile, all of it good
		var pile: Array = pile_now.filter(func(wp): return not wp.get("egg", false))
		var usable: bool = (
			pile.any(func(wp): return wp.has("gear") and int(wp["rar"]) >= 3)
			and (
				pile.any(func(wp): return wp.has("tune"))
				or p.perks.filter(func(k): return String(k).begins_with("brand_")).size() > brands0
			)
		)
		var good: bool = pile.all(
			func(wp): return int(wp["rar"]) >= 3 if not wp.has("val") else Loot.value(Pack.ground_item(wp)) >= 40
		)
		var pile_desc := func(wp):
			return (
				String(wp["gear"]) + " " + str(wp["rar"])
				if wp.has("gear")
				else (String(wp["tune"]) if wp.has("tune") else Loot.name_of(Pack.ground_item(wp)))
			)
		(
			ok
			. call(
				pile.size() <= 4 and usable and good,
				(
					"%s's loot: %d things, all good (%s), an Epic+ piece of gear and a Brand upgrade"
					% [
						b.md["name"],
						pile.size(),
						str(pile.map(pile_desc)),
					]
				)
			)
		)
		var out_l := Vector3(l["out"].x, 0, l["out"].y)
		var vic: bool = l.get("victory", false)
		if l == f_v:
			# the lever: a press away from it does nothing; at it, the gate opens (pressed well clear of the loot
			# and the egg: beside them it would pick them up, and where they land follows the fight)
			var clear := func(q: Vector3) -> float:
				return m.wpicks.reduce(func(d, wp): return minf(d, q.distance_to(wp["pos"])), 99.0)
			var spots: Array = [-3.0, 0.0, 3.0].map(func(d): return l["c"] + out_l * d)
			spots.sort_custom(func(a, c): return clear.call(a) > clear.call(c))
			spot.call(p, spots[0])
			p.inp["interact"] = true
			run.call(Match.DT)
			p.inp["interact"] = false
			run.call(Match.DT)
			var held: bool = l.get("locked", false)
			spot.call(p, l["lever"] - out_l * 0.8)
			var it: Dictionary = m.lairs.interact_for(p)
			run.call(0.1)
			p.inp["interact"] = true
			run.call(Match.DT)
			p.inp["interact"] = false
			run.call(0.3)
			ok.call(
				(
					vic
					and held
					and String(it.get("what", "")) == "lever"
					and String(it.get("label", "")) == "%s: Open the gate" % Settings.key_cap("interact")
					and not l.get("locked", false)
					and gate_free.call(l)
					and not l.get("up_on", false)
					and String(l.get("opened_by_lever", "")) == p.pname
				),
				(
					"the lever: '%s'; pulled %.1fs after the kill, the gate opens and the updraft dies down"
					% [it.get("label", "?"), m.time - kill_t]
				)
			)
		elif l == e_v:
			# the updraft: anyone who wasn't sealed in gets no lift from it
			var up: Vector3 = l["up"]
			q_v.ctrl = "local"
			q_v.teleport(up + Vector3(0, 6.0, 0))
			q_v.vel = Vector3.ZERO
			q_v.grounded = false
			var qy0 := q_v.pos.y
			var qy := qy0
			var tq2 := 0.0
			while tq2 < 0.5:
				m.step(Match.DT)
				tq2 += Match.DT
				god.call()
				qy = maxf(qy, q_v.pos.y)
			var refused: bool = not (l["flown"] as Array).has(q_v) and qy <= qy0 + 0.05 and not q_v.auto_glide
			spot.call(q_v, up)
			run.call(0.2)
			# (a person walks off an island's edge now, so an outsider shoved off the lair may fall out of the match: that counts as shoved out)
			refused = (
				refused
				and not (l["flown"] as Array).has(q_v)
				and q_v.pos.y < float(l["c"].y) + 1.0
				and (q_v.out or not m.lairs.inside(l, q_v.pos, 0.0))
			)
			ok.call(
				refused,
				(
					"the updraft refuses outsiders: no lift over it (%.2fm), shoved off and out (%.1fm from the middle)"
					% [qy - qy0, q_v.flat_dist(l["c"])]
				)
			)
			if q_v.out or q_v.downed:
				Life.bring_back(
					m, q_v, m.world.spawns[0] if not m.world.spawns.is_empty() else m.world.random_ground(), 1.0, false
				)
			q_v.ctrl = "idle"
			park.call(q_v)
			# a hunter who fought rides it: up over the wall and away from the back, the gate still shut
			spot.call(p, up)
			var top := p.pos.y
			var shut_when_out := false
			var tf := 0.0
			while tf < 12.0:
				m.step(Match.DT)
				tf += Match.DT
				god.call()
				top = maxf(top, p.pos.y)
				if not m.lairs.inside(l, p.pos, 0.3) and not shut_when_out:
					shut_when_out = gate_shut.call(l) and l.get("locked", false)
				if p.grounded and not m.lairs.inside(l, p.pos, 0.5):
					break
			var rel: Vector3 = p.pos - l["c"]
			var back: float = -rel.dot(out_l)
			(
				ok
				. call(
					(
						(l["flown"] as Array).has(p)
						and top > float(l["c"].y) + 6.0
						and not m.lairs.inside(l, p.pos, 0.5)
						and shut_when_out
						and p.grounded
						and rel.dot(out_l) < float(l["half"]) * 0.5
						and not p.out
						and m.lairs.sealed_lair(p).is_empty()
					),
					(
						"the updraft: lifts you %.1fm over the floor, over the wall and away (%.1fm behind the lair's middle, landed %s) while the gate stays shut"
						% [top - float(l["c"].y), back, p.grounded]
					)
				)
			)
			# nobody pulls the lever: it opens by itself after VICTORY_T
			var ta := m.time
			while l.get("locked", false) and m.time - ta < Lairs.VICTORY_T + 2.0:
				run.call(Match.DT)
			ok.call(
				(
					not l.get("locked", false)
					and gate_free.call(l)
					and not l.get("up_on", false)
					and absf(m.time - kill_t - Lairs.VICTORY_T) < 0.25
					and String(l.get("opened_by_lever", "?")) == ""
				),
				(
					"nobody at the lever: the gate opens by itself %.1fs after the kill, the updraft dies down"
					% (m.time - kill_t)
				)
			)
		else:
			# a bot sealed in after the kill: the lever with nobody outside, the updraft with rivals at the gate
			c_v.ai["egg_" + String(l["id"])] = false  # (this bot leaves the egg to you)
			var g0: Array = m.lairs.bot_goal(c_v, false)
			spot.call(q_v, m.lairs.camp_spot(l, q_v))
			var g1: Array = m.lairs.bot_goal(c_v, false)
			ok.call(
				(
					not g0.is_empty()
					and String(g0[1]) == "lair_lever"
					and not g1.is_empty()
					and String(g1[1]) == "lair_updraft"
					and m.lairs.campers(l, c_v.team) >= 1
				),
				(
					"bots after the kill: no one at the gate, pull the lever (%s); rivals camping it, the updraft (%s)"
					% [str(g0.slice(1)), str(g1.slice(1))]
				)
			)
			# and it does: walks into the updraft and glides out over the wall
			l["victory_at"] = m.time  # (a fresh clock: this part is about the bot, not the timer)
			c_v.ctrl = "bot"
			var tb2 := 0.0
			while tb2 < 16.0 and (m.lairs.inside(l, c_v.pos, 0.5) or not c_v.grounded):
				m.step(Match.DT)
				tb2 += Match.DT
				god.call()
				q_v.hp = q_v.max_hp
			(
				ok
				. call(
					(
						(l["flown"] as Array).has(c_v)
						and not m.lairs.inside(l, c_v.pos, 0.5)
						and not c_v.out
						and l.get("locked", false)
					),
					(
						"a bot rides the updraft out with rivals at the gate (%.1fs, %.1fm from the gate, the gate still shut)"
						% [tb2, c_v.flat_dist(l["gate_c"])]
					)
				)
			)
			c_v.ctrl = "idle"
			c_v.inp["move"] = Vector2.ZERO
			q_v.ctrl = "idle"
			park.call(q_v)
			spot.call(p, l["lever"] - out_l * 0.8)
			run.call(0.1)
			p.inp["interact"] = true
			run.call(Match.DT)
			p.inp["interact"] = false
			run.call(0.3)
			park.call(c_v)
		# the way out is clear
		if m.lairs.inside(l, p.pos, 0.0):
			spot.call(p, l["c"] + out_l * 3.0)
		var tw := 0.0
		while m.lairs.inside(l, p.pos, 1.0) and tw < 8.0:
			p.inp["move"] = (
				Vector2(l["out"].x, l["out"].y)
				if (
					absf(p.pos.x - l["gate_c"].x) + absf(p.pos.z - l["gate_c"].z) < 2.0
					or m.lairs.inside(l, p.pos, -2.0) == false
				)
				else Vector2(l["gate_c"].x - p.pos.x, l["gate_c"].z - p.pos.z).normalized()
			)
			god.call()
			m.step(Match.DT)
			tw += Match.DT
		p.inp["move"] = Vector2.ZERO
		ok.call(not m.lairs.inside(l, p.pos, 1.0), "after the kill you walk out through the gate (%.1fs)" % tw)
		ok.call(
			l["state"] == "cleared" and egg_ok and strong and p.xp > xp0 + 100.0 and egg_shown,
			(
				"%s falls: exactly one Rare Egg, to one hunter in the pit (told in the feed), an Epic+ weapon, +%d XP"
				% [b.md["name"], int(p.xp - xp0)]
			)
		)
		var holder: Array = [p, c_v].filter(func(h): return h.pack.any(func(it): return Loot.is_rare_egg(it)))
		if holder.size() == 1:  # (the later steps use it lying on the ground)
			var egg: Dictionary = holder[0].pack.filter(func(it): return Loot.is_rare_egg(it))[0]
			holder[0].pack.erase(egg)
			egg_items.append(m.lairs.drop_egg(l, egg, l["c"]))
		elif ew != null:
			egg_items.append(ew)
	# 6. the egg takes a pack slot: a full pack asks what to leave
	var ew0: Dictionary = egg_items[0]
	spot.call(p, ew0["pos"])
	p.pack_cap = 2
	p.pack = [Loot.valuable("old_coin"), Loot.valuable("sky_pearl")]
	Pack.take_ground(m, p, ew0)
	ok.call(m.hud.swap_open() and m.wpicks.has(ew0), "full pack: the egg opens the swap window")
	Pack.swap(m, p, 0, ew0)
	m.hud.close_swap()
	var egg_it: Dictionary = (
		p.pack.filter(func(it): return Loot.is_rare_egg(it))[0]
		if p.pack.any(func(it): return Loot.is_rare_egg(it))
		else {}
	)
	ok.call(
		not egg_it.is_empty() and p.pack.size() == 2,
		"the Rare Egg is in the pack (%s)" % str(p.pack.map(func(it): return Loot.name_of(it)))
	)
	run.call(0.2)
	ok.call(
		m.lairs.egg_pings.any(func(e): return e.get("follow") == p),
		"picking it up shows the carrier to everyone for a few seconds"
	)
	# 7. die with it: it's in your deathbox; a teammate smart-loots it
	p.lives = 1
	m.eliminate(p, q_v, "knocked out")
	var bx := Life.box_of(m, p)
	var in_box: bool = not bx.is_empty() and (bx.get("pack", []) as Array).any(func(it): return Loot.is_rare_egg(it))
	ok.call(in_box, "dead: the egg is in your deathbox")
	spot.call(c_v, bx["pos"])
	c_v.pack = [Loot.valuable("old_coin"), Loot.valuable("kin_idol"), Loot.valuable("sky_pearl")]
	c_v.pack_cap = 3
	Life.smart_loot(m, c_v, bx)
	ok.call(
		c_v.pack.any(func(it): return Loot.is_rare_egg(it)), "smart loot takes the egg first, even from a full pack"
	)
	# 8. extract: the egg goes to the Incubator (not the breeding nest), it hatches a rare kin
	Save.d["roster"] = [Save.new_kin("cindle", "Pip")]
	Save.d["active"] = Save.d["roster"][0]["uid"]
	Save.d["incubator"] = {}
	Save.d["rare_eggs"] = []
	Save.d["egg"] = {}
	var out := Game.apply_result({"extracted": true, "haul": Pack.haul(c_v), "tier": 0, "gems": 0, "kin_runs": []})
	var q: Array = [Incubator.eggs()[0]] if not Incubator.eggs().is_empty() else []
	ok.call(
		(
			q.size() == 1
			and not Data.no_egg(String(q[0]["sp"]))
			and (out.get("haul", []) as Array).any(func(it): return Loot.is_rare_egg(it))
		),
		(
			"extract: a %s goes to the Incubator %s"
			% [Data.egg_name(String(q[0]["sp"])) if not q.is_empty() else "?", str(q)]
		)
	)
	ok.call(
		not Incubator.eggs().is_empty() and Save.d.get("egg", {}).is_empty() and Save.d.get("rare_eggs", []).is_empty(),
		"home: it goes straight into the Incubator's cradle (the breeding nest stays free)"
	)
	var rr := RandomNumberGenerator.new()
	rr.seed = 3
	var inc_egg: Dictionary = Incubator.eggs()[0].duplicate()
	var baby := Care.hatch_rare(inc_egg, rr)
	ok.call(
		(
			not Data.no_egg(String(baby["species"]))
			and baby.get("rare", false)
			and String(baby["species"]) == String(inc_egg["sp"])
		),
		"hatch: a rare-egg %s (%s)" % [Data.KIN[baby["species"]]["name"], baby["species"]]
	)
	# 9. rare kin never turn up wild, on rivals or as a starter
	var any_rare := false
	for i in 60:
		if Data.is_rare(String(m.bot_kin_record()["species"])):
			any_rare = true
	var rares: Array = Data.KIN.keys().filter(func(k): return Data.is_rare(k))
	ok.call(
		not any_rare and Data.common_kin().size() + rares.size() == Data.KIN.size() and rares.size() >= 2,
		"rare species (%s) only come from eggs" % str(rares)
	)
	m.queue_free()
	# 10. a bot can work a dial
	var m2 := Match.new()
	main.add_child(m2)
	m2.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4, "no_drop": true, "autoplay": true})
	m2.set_process(false)
	var b_v: Hunter = m2.hunters[1]
	for h in m2.hunters:
		if h != b_v:
			h.ctrl = "idle"
			h.teleport(m2.world.spawns[0])
	var l2: Dictionary = m2.lairs.list[0]
	m2.lairs.activate(l2)
	m2.lairs.breach.as_dial(l2)  # (a dial test: bots breaking a seal down are --lair-breach-check's)
	# the only lair it can go for: bots don't plan lairs in a match's first 25 s and roam instead,
	# then take the nearest live one, so with the other rolled-live lairs about, where that roam ended
	# (which drifts with the RNG stream the earlier sections leave) decided which gate it worked
	for x in m2.lairs.list:
		if x != l2 and x["state"] == "sealed":
			x["state"] = "dormant"
			m2.lairs._tint_dormant(x, true)
	# ... and it has to find its way back across the islands: every route a bot takes lands on the
	# island it leads to (a bridge route that landed on the island it left looped the bot round it)
	var w2 := m2.world
	var bad_links: Array = w2.links.filter(func(lk): return w2.island_of(lk["land"].x, lk["land"].z) != int(lk["to"]))
	ok.call(
		bad_links.is_empty(),
		(
			"every glide, wind and bridge route lands on the island it leads to (%d of %d don't: %s)"
			% [
				bad_links.size(),
				w2.links.size(),
				str(
					bad_links.slice(0, 3).map(
						func(lk): return "%d>%d land %s" % [lk["from"], lk["to"], str(lk["land"])]
					)
				)
			]
		)
	)
	for g in l2["guards"]:
		g.dead = true
	b_v.ai["skill"] = 0.9
	b_v.ai["boss_hunt"] = true
	b_v.teleport(l2["dial"] + Vector3(l2["out"].x, 0, l2["out"].y) * 4.0)
	var tb := m2.time
	if "--boss-only-dial" in OS.get_cmdline_user_args():
		print("  dial bot: %s %s %s" % [b_v.cls, b_v.arch, b_v.wid])
	# a dial test, not a loot test: no chests or ground loot to wander off to first
	for c in m2.chests:
		c["open"] = true
	m2.pickups.clear()
	while l2["state"] == "sealed" and m2.time - tb < 150.0:
		if "--boss-only-dial" in OS.get_cmdline_user_args() and int(m2.time * 60.0) % 300 == 0:
			print(
				(
					"  t=%.0f pos=%s dial=%.1f goal=%s kind=%s tgt=%s user=%s inter=%s"
					% [
						m2.time - tb,
						b_v.pos.snapped(Vector3(0.1, 0.1, 0.1)),
						b_v.flat_dist(l2["dial"]),
						str(b_v.ai.get("goal")),
						b_v.ai.get("goal_kind"),
						str(b_v.ai.get("tgt")),
						str(l2["user"]),
						b_v.inp.get("interact")
					]
				)
			)
		b_v.hp = b_v.max_hp
		for g in l2["guards"]:
			if is_instance_valid(g):
				g.dead = true
		m2.step(Match.DT)
	ok.call(
		l2["state"] != "sealed",
		"a bot walked up and opened %s in %.0fs (%d misses)" % [l2["name"], m2.time - tb, int(l2["fails"])]
	)
	m2.queue_free()
	# 10b. the fight is loud: everyone outside within ALERT_R hears it start (a roar, a ping with the
	# boss's icon, a shaft of light over the lair, the seal's clock over the gate) and its boss fall;
	# bots that hear it may camp the gate, the stronger squads more often; bots sealed in get out by
	# the lever, or by the updraft when rivals wait at the gate
	var m4 := Match.new()
	main.add_child(m4)
	m4.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m4.set_process(false)
	var p4: Hunter = m4.player
	for h in m4.hunters:
		h.ctrl = "idle" if h != p4 else "local"
		h.inp["move"] = Vector2.ZERO
	var a_v: Dictionary = m4.lairs.list.filter(func(x): return x["boss"] == "colossus")[0]
	m4.lairs.activate(a_v)
	for g in a_v["guards"]:
		if is_instance_valid(g):
			g.dead = true
			g.visible = false
	m4.lairs.open(a_v, null, "dial")
	var spot4 := func(h: Hunter, at: Vector3):
		h.teleport(Vector3(at.x, m4.world.ground_at(at.x, at.z), at.z))
		h.vel = Vector3.ZERO
	var run4 := func(sec: float):
		var t := 0.0
		while t < sec:
			for h in m4.hunters:
				if not h.out:
					h.hp = h.max_hp
			m4.step(Match.DT)
			t += Match.DT
	var teams4 := {}
	for h in m4.hunters:
		if h.team != p4.team:
			teams4[h.team] = teams4.get(h.team, []) + [h]
	var tk: Array = teams4.keys()
	var r1: Hunter = teams4[tk[0]][0]
	var r2: Hunter = teams4[tk[0]][1]
	var s1: Hunter = teams4[tk[1]][0]
	var s2: Hunter = teams4[tk[1]][1]
	var c4: Hunter = m4.hunters.filter(func(x): return x.team == p4.team and x != p4)[0]
	var out_a := Vector3(a_v["out"].x, 0, a_v["out"].y)
	var side_a := Vector3(-a_v["out"].y, 0, a_v["out"].x)
	# where everyone is when it starts: you and your mate by the gate, one rival a way off, one far away
	spot4.call(p4, a_v["dial"] + out_a * 4.0)
	spot4.call(c4, a_v["dial"] + out_a * 4.0 + side_a * 2.0)
	var mid_at := Vector3.INF
	var far_at := Vector3.INF
	for i in 500:
		var gp: Vector3 = m4.world.random_ground()
		if m4.lairs.lair_of(gp, 2.0).size() > 0:
			continue
		var gd := Vector2(gp.x - a_v["c"].x, gp.z - a_v["c"].z).length()
		if gd > 50.0 and gd < 120.0 and mid_at == Vector3.INF:
			mid_at = gp
		if far_at == Vector3.INF or gd > Vector2(far_at.x - a_v["c"].x, far_at.z - a_v["c"].z).length():
			far_at = gp
	spot4.call(s1, mid_at)
	spot4.call(s2, far_at)
	var far_real := s2.flat_dist(a_v["c"])
	if far_real <= Lairs.ALERT_R:
		s2.pos = a_v["c"] + (s2.pos - a_v["c"]).normalized() * (Lairs.ALERT_R + 10.0)
		s2.prev = s2.pos  # (the map isn't that big: put it out of earshot for the moment)
	var pings4 := m4.pings.size()
	var feed4 := m4.feed_all.size()
	# a rival squad walks in and the fight starts
	spot4.call(r1, a_v["c"] + out_a * 1.5 + side_a * 1.5)
	spot4.call(r2, a_v["c"] + out_a * 1.5 - side_a * 1.5)
	var tl4 := 0.0
	while not a_v.get("locked", false) and tl4 < 1.0:
		m4.step(Match.DT)
		tl4 += Match.DT
	var s2_far := s2.flat_dist(a_v["c"])
	spot4.call(s2, far_at)
	var heard_f: Array = (
		m4
		. lairs
		. alert_log
		. filter(func(e): return e["lair"] == a_v["id"] and e["kind"] == "fight")
		. map(func(e): return e["nid"])
	)
	var lbl4: Label3D = a_v["nodes"]["label"]
	var beam4: Node3D = a_v["nodes"]["beam"]
	ok.call(
		(
			a_v.get("locked", false)
			and (a_v["sealed_in"] as Array).has(r1)
			and (a_v["sealed_in"] as Array).has(r2)
			and not (a_v["sealed_in"] as Array).has(p4)
		),
		"a rival squad walks into %s: sealed in with %s, you outside" % [a_v["name"], a_v["boss_mob"].md["name"]]
	)
	(
		ok
		. call(
			(
				heard_f.has(p4.nid)
				and heard_f.has(c4.nid)
				and heard_f.has(s1.nid)
				and not heard_f.has(s2.nid)
				and not heard_f.has(r1.nid)
			),
			(
				"the fight is heard by everyone outside within %dm (you, your mate, a rival %.0fm off) but not %.0fm away, nor by those inside"
				% [int(Lairs.ALERT_R), s1.flat_dist(a_v["c"]), s2_far]
			)
		)
	)
	var pinged: bool = m4.pings.slice(pings4).any(
		func(pg): return Vector2(pg["pos"].x - a_v["c"].x, pg["pos"].z - a_v["c"].z).length() < 1.0
	)
	var fed: bool = m4.feed_all.slice(feed4).any(func(f): return String(f).contains("fight at %s" % a_v["name"]))
	(
		ok
		. call(
			(
				pinged
				and fed
				and m4.lairs.alerted(a_v, p4)
				and beam4.visible
				and lbl4.text.contains("FIGHT")
				and lbl4.text.contains(Lairs.clock(m4.lairs.lock_left(a_v)))
			),
			(
				"outside: a ping on the lair (boss icon on the map), '%s', the beam over the lair, the seal's clock over the gate ('%s')"
				% [String(a_v.get("alert_text", "")), lbl4.text.replace("\n", " / ")]
			)
		)
	)
	# bots outside that heard it: camp it, the stronger squads more often, never when leaving
	s1.ctrl = "bot"
	var odds_full: float = m4.lairs.camp_odds(s1)
	s1.hp = s1.max_hp * 0.3
	s2.hp = s2.max_hp * 0.3
	var odds_hurt: float = m4.lairs.camp_odds(s1)
	s1.hp = s1.max_hp
	s2.hp = s2.max_hp
	s1.ai["camp_" + String(a_v["id"])] = true
	var cg: Array = m4.lairs.bot_goal(s1, false)
	var cg_leave: Array = m4.lairs.bot_goal(s1, true)
	s2.ai["camp_" + String(a_v["id"])] = true
	var cg_deaf: Array = m4.lairs.bot_goal(s2, false)
	(
		ok
		. call(
			(
				odds_full > odds_hurt
				and not cg.is_empty()
				and String(cg[1]) == "lair_camp"
				and not m4.lairs.inside(a_v, cg[0], 0.5)
				and (cg[0] as Vector3).distance_to(a_v["gate_c"]) < 9.0
				and (cg_leave.is_empty() or String(cg_leave[1]) != "lair_camp")
				and (cg_deaf.is_empty() or String(cg_deaf[1]) != "lair_camp")
			),
			(
				"bots that heard it may camp the gate (odds %.2f with the squad up, %.2f hurt; %s); not when leaving, nor if they never heard it"
				% [odds_full, odds_hurt, str(cg.slice(1))]
			)
		)
	)
	s1.ctrl = "idle"
	spot4.call(s1, cg[0])
	# the boss falls: a different cry, the ping turns to "fallen", the gate's clock over the gate
	var feed4b := m4.feed_all.size()
	var b_a: Boss = a_v["boss_mob"]
	b_a.hurt(b_a.max_hp * 3.0, r1, {"src": "shot"})
	run4.call(0.1)
	for a in a_v["adds"]:
		if is_instance_valid(a) and not a.dead:
			a.dead = true
			a.visible = false
	var heard_v: Array = (
		m4
		. lairs
		. alert_log
		. filter(func(e): return e["lair"] == a_v["id"] and e["kind"] == "fallen")
		. map(func(e): return e["nid"])
	)
	ok.call(
		(
			a_v.get("victory", false)
			and heard_v.has(p4.nid)
			and heard_v.has(s1.nid)
			and String(a_v.get("alert", "")) == "fallen"
			and m4.feed_all.slice(feed4b).any(func(f): return String(f).contains("has fallen"))
			and lbl4.text.contains("has fallen")
			and lbl4.text.contains("gate opens")
			and beam4.visible
		),
		(
			"the boss falls: everyone near hears it ('%s'), the clock over the gate: '%s'"
			% [String(a_v.get("alert_text", "")), lbl4.text.replace("\n", " / ")]
		)
	)
	# sealed-in bots: S1 waits at the gate, so R1 takes the updraft; with nobody there R2 takes the lever
	spot4.call(
		p4,
		(
			a_v["dial"] + out_a * 30.0
			if not m4.world.is_void((a_v["dial"] + out_a * 30.0).x, (a_v["dial"] + out_a * 30.0).z)
			else far_at
		)
	)
	spot4.call(c4, p4.pos + side_a * 1.5)
	r1.ai["egg_" + String(a_v["id"])] = false
	r2.ai["egg_" + String(a_v["id"])] = false  # (straight out: the egg is another test)
	var g_r1: Array = m4.lairs.bot_goal(r1, false)
	r1.ctrl = "bot"
	var tr1 := 0.0
	while tr1 < 11.0 and (m4.lairs.inside(a_v, r1.pos, 0.5) or not r1.grounded):
		run4.call(Match.DT)
		tr1 += Match.DT
	var r1_out: bool = (
		(a_v["flown"] as Array).has(r1) and not m4.lairs.inside(a_v, r1.pos, 0.5) and a_v.get("locked", false)
	)
	r1.ctrl = "idle"
	r1.inp["move"] = Vector2.ZERO
	spot4.call(s1, far_at)
	a_v["victory_at"] = m4.time  # (a fresh clock for R2)
	var g_r2: Array = m4.lairs.bot_goal(r2, false)
	r2.ctrl = "bot"
	var tr2 := 0.0
	while tr2 < 10.0 and a_v.get("locked", false):
		run4.call(Match.DT)
		tr2 += Match.DT
	(
		ok
		. call(
			(
				String(g_r1[1]) == "lair_updraft"
				and r1_out
				and String(g_r2[1]) == "lair_lever"
				and not a_v.get("locked", false)
				and String(a_v.get("opened_by_lever", "")) == r2.pname
			),
			(
				"bots sealed in: with a rival camping the gate one rides the updraft out (%.1fs); with nobody there the other pulls the lever (%.1fs)"
				% [tr1, tr2]
			)
		)
	)
	m4.queue_free()
	# 11. a generated map rolls at least one live lair too
	var m3 := Match.new()
	main.add_child(m3)
	m3.start(
		{
			"teams": 2,
			"squad": 1,
			"tier": 1,
			"length": 1e9,
			"seed": 8,
			"no_drop": true,
			"procedural": true,
			"autoplay": true
		}
	)
	m3.set_process(false)
	var live3: int = m3.lairs.list.filter(func(l): return l["active"]).size()
	ok.call(
		m3.lairs.list.size() >= 1 and live3 >= 1,
		(
			"a generated map: %d lair(s), %d live (%s)"
			% [m3.lairs.list.size(), live3, str(m3.lairs.list.map(func(l): return l["boss"]))]
		)
	)
	print("BOSSCHECK done, failures: %d" % bad[0])
	main.get_tree().quit(1 if bad[0] > 0 else 0)
