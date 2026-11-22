extends RefCounted
## --lair-lock-check: a boss kill against gate campers. The boss drops a small pile, all of it high
## value, and the Rare Egg lands on its own spot a few metres off under its own beam. The lair then
## keeps its fighters locked in for Lairs.VICTORY_T (20 s): a rival waiting at the gate can't walk or
## glide in, and the fighters can't walk out, until the clock runs down and the gate opens by itself,
## or someone inside pulls the lever by the gate to open it early. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LAIRLOCK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

var m: Match
var keep: Array = []
var dropped: Array = []      # the pickups the last boss kill dropped

func _god() -> void:
	for h in keep:
		h.hp = h.max_hp; h.armor = h.max_armor
		if h.downed: m.revive_hunter(h, h)

func _run(sec: float) -> void:
	var t := 0.0
	while t < sec:
		_god()
		m.step(Match.DT); t += Match.DT

func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z)); h.vel = Vector3.ZERO

func _walk(h: Hunter, dir: Vector2, sec: float) -> void:
	var t := 0.0
	while t < sec:
		h.inp["move"] = dir
		_god()
		m.step(Match.DT); t += Match.DT
	h.inp["move"] = Vector2.ZERO
	m.step(Match.DT)

func _gate_shut(l: Dictionary) -> bool:
	return (l["gate_tiles"] as Array).all(func(q): return m.world.kind[m.world.idx(q.x, q.y)] == World.T_BLOCK)

## A boss in its lair, woken with P and C inside, then killed by P. Returns the kill time.
## s: the boss plays its death move, dissolves, then its drops spill (MobDissolve.begin), plus a frame or two
const SPILL_WAIT := BossAnim.DEATH_S + MobDissolve.DUR_MAX * MobDissolve.SPILL_AT + 0.1

func _kill(l: Dictionary, p_v: Hunter, c: Hunter) -> float:
	for g in l["guards"]: if is_instance_valid(g) and not g.dead: g.dead = true; g.visible = false
	if l["state"] == "sealed": m.lairs.open(l, p_v, "dial")
	_spot(p_v, l["c"] + Vector3(l["out"].x, 0, l["out"].y) * 3.0)
	_spot(c, l["c"] + Vector3(-l["out"].y, 0, l["out"].x) * 3.0)
	_run(0.3)
	var b: Boss = l["boss_mob"]
	if b.buried: b._clear_attack()
	b.stagger_t = 0.0
	var pk0: Array = m.pickups.duplicate()
	var kill_at := m.time
	b.hurt(b.hp + b.max_hp, p_v, {"src": "shot"})
	_run(SPILL_WAIT)
	dropped = m.pickups.filter(func(p): return not pk0.has(p))      # (before anyone walks over them)
	for a in l["adds"]: if is_instance_valid(a) and not a.dead: a.dead = true; a.visible = false
	return kill_at

func run(main: Node) -> void:
	main.set_meta("lair_lock_check", self)      # (a RefCounted that awaits frames must be kept alive, as the swim check does)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var sd := ""      # --shots-dir=<dir> (under a real renderer, with a dummy --shot=): a screenshot of the lock-in banner, in recording mode
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): sd = String(a).substr(12)
	if sd != "": Record.set_level(1)
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1500.0 if sd != "" else 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var p_v: Hunter = m.player
	p_v.set_arch("")      # (boss weapons come from the killer's class: the classic kit, as --boss-check)
	var c: Hunter = m.hunters.filter(func(x): return x.team == p_v.team and x != p_v)[0]
	var q: Hunter = m.hunters.filter(func(x): return x.team != p_v.team)[0]
	keep = [p_v, c, q]
	for h in m.hunters:
		h.ctrl = "idle" if h != p_v else "local"
		h.inp["move"] = Vector2.ZERO
	for l in m.lairs.list: m.lairs.activate(l)
	var f: Dictionary = m.lairs.list[0]
	for l in m.lairs.list: if String(l["boss"]) == "colossus": f = l
	ok(is_equal_approx(Lairs.VICTORY_T, 20.0), "the post-kill lock is %d s" % int(Lairs.VICTORY_T))
	# ---------------------------------------------------------------- 1. the loot: few things, all good; the egg apart under its own beam
	# a piece of gear already lying in the lair where the egg would fall: the egg finds a spot clear of it too
	var stray_at := m.lairs._floor_spot(f, f["c"] + Vector3(-f["out"].y, 0, f["out"].x) * 4.0, 1.0)
	m.spawn_gear("bastion_plate", 4, stray_at, "", false)
	var w0 := m.wpicks.size()
	var kill_t := _kill(f, p_v, c)
	var gems_new: Array = dropped.filter(func(p): return String(p["kind"]) == "gem")
	# (utility items and keys from the boss table are loot now: UtilityDrops, decision 0007)
	var other_new: Array = dropped.filter(func(p): return not _is_loot_kind(String(p["kind"])))
	var gem_total := 0
	for p in gems_new: gem_total += int(p["v"])
	ok(gems_new.size() == 1 and gem_total >= int(Data.MOBS["colossus"]["gems"]) * 2 and other_new.is_empty(),
		"its gems come as %d pile worth %d in all (not %d little ones), no armor shards or seeds (a utility item may come)" % [gems_new.size(), gem_total, int(Data.MOBS["colossus"]["gems"])])
	var b: Boss = f["boss_mob"]
	var drops: Array = m.wpicks.slice(w0)
	var egg = f.get("egg_wp")
	var pile: Array = drops.filter(func(wp): return not wp.get("egg", false))
	ok(egg != null and drops.has(egg) and Loot.is_rare_egg(Pack.ground_item(egg)), "%s drops a Rare %s" % [b.md["name"], Data.egg_name(String(Pack.ground_item(egg)["sp"])) if egg != null else "?"])
	ok(pile.size() >= 2 and pile.size() <= 4, "a small pile: %d things (%s)" % [pile.size(), ", ".join(pile.map(func(wp): return String(Data.PERKS[String(wp["tune"])]["name"]) if wp.has("tune") else Loot.name_of(Pack.ground_item(wp))))])
	var low: Array = pile.filter(func(wp): return false if wp.has("tune") else ((int(wp["rar"]) < 3) if not wp.has("val") else Loot.value(Pack.ground_item(wp)) < 50))
	ok(low.is_empty(), "all of it high value: Epic+ gear, a weapon upgrade, treasure worth 50+ (worth %s)" % str(pile.map(func(wp): return 0 if wp.has("tune") else Loot.value(Pack.ground_item(wp)))))
	var apart := 99.0
	var pile_c := Vector3.ZERO
	for wp in pile:
		pile_c += wp["pos"] / float(maxi(1, pile.size()))
		if egg != null: apart = minf(apart, Vector2(wp["pos"].x - egg["pos"].x, wp["pos"].z - egg["pos"].z).length())
	var stray_d: float = Vector2(egg["pos"].x - stray_at.x, egg["pos"].z - stray_at.z).length() if egg != null else 0.0
	ok(egg != null and apart >= 3.0 and apart <= 7.0 and stray_d >= 2.5 and m.lairs.inside(f, egg["pos"], 0.0), "the egg sits on its own spot %.1f m from the nearest pile item (%.1f m from a rifle already lying there), inside the lair" % [apart, stray_d])
	var en: Node3D = egg["node"] if egg != null else null
	var beam: MeshInstance3D = en.get_node_or_null("Beam") if en else null
	ok(beam != null and beam.visible and beam.position.y > 4.0, "under its own light beam, reaching %.0f m up" % ((beam.position.y * 2.0) if beam else 0.0))
	# the pile's weapon and glove have short coloured pillars; the egg's gold shaft stands far over them
	var tallest := 0.0
	for wp in pile:
		for ch in (wp["node"] as Node3D).get_children():
			if ch is MeshInstance3D and ch.position.y > tallest: tallest = ch.position.y
	ok(beam != null and beam.position.y > tallest * 2.0, "its beam reaches %.0f m, over twice the pile's pillars (%.0f m): it reads apart from across the lair" % [(beam.position.y * 2.0) if beam else 0.0, tallest * 2.0])
	ok(m.lairs.egg_pings.size() > 0, "and it's pinged on everyone's map")
	# ---------------------------------------------------------------- 2. locked in after the kill; campers locked out
	ok(f.get("victory", false) and f.get("locked", false) and _gate_shut(f) and m.lairs.victory_left(f) > Lairs.VICTORY_T - SPILL_WAIT - 0.5,
		"the kill locks the lair: gate shut, opens in %s" % Lairs.clock(m.lairs.victory_left(f)))
	if sd != "":
		for i in 3:
			await main.get_tree().process_frame      # (the check ran in one long frame: let the frame time settle first)
		m.set_process(true)
		for i in 45:      # (the camera eases over to you)
			await main.get_tree().process_frame
		main.get_tree().root.get_texture().get_image().save_png(sd + "/lair_locked_in.png")
		m.set_process(false)
	var outv := Vector2(f["out"].x, f["out"].y)
	var outl := Vector3(outv.x, 0, outv.y)
	# a rival camping the gate tries to walk in
	q.ctrl = "local"
	_spot(q, f["gate_c"] + outl * 2.5)
	_walk(q, -outv, 2.5)
	ok(not m.lairs.inside(f, q.pos, 0.0), "a rival at the gate walks into it and stays out (%.1f m from the middle)" % q.flat_dist(f["c"]))
	# ... or glides in over the wall
	q.teleport(f["c"] + Vector3(0, 7.0, 0)); q.vel = Vector3.ZERO; q.grounded = false
	_run(0.6)
	ok(not m.lairs.inside(f, q.pos, 0.0) or q.pos.y > float(f["c"].y) + 3.0, "or glides in over the wall: thrown back out")
	_spot(q, f["gate_c"] + outl * 3.0)
	q.ctrl = "idle"
	# the fighters can't walk out either
	_spot(p_v, f["c"] + outl * (float(f["half"]) - 2.0))
	_walk(p_v, outv, 1.5)
	ok(m.lairs.inside(f, p_v.pos, 0.0) and _gate_shut(f), "you can't walk out through the shut gate")
	# the lock holds the whole clock
	_spot(p_v, f["c"] + outl * 3.0)
	while m.time - kill_t < Lairs.VICTORY_T - 1.0: _run(Match.DT)
	ok(f.get("locked", false) and _gate_shut(f) and f.get("victory", false), "still locked %.0f s after the kill (%s left)" % [m.time - kill_t, Lairs.clock(m.lairs.victory_left(f))])
	_spot(q, f["gate_c"] + outl * 2.5)
	q.ctrl = "local"
	_walk(q, -outv, 1.0)
	ok(not m.lairs.inside(f, q.pos, 0.0), "the camper is still kept out a second before it opens")
	q.ctrl = "idle"; _spot(q, f["gate_c"] + outl * 4.0)
	while f.get("locked", false) and m.time - kill_t < Lairs.VICTORY_T + 2.0: _run(Match.DT)
	ok(not f.get("locked", false) and not _gate_shut(f) and absf(m.time - kill_t - Lairs.VICTORY_T) < 0.3,
		"then it opens by itself %.1f s after the kill" % (m.time - kill_t))
	_walk(p_v, outv, 0.1)
	var tw := 0.0
	while m.lairs.inside(f, p_v.pos, 1.0) and tw < 8.0:
		p_v.inp["move"] = Vector2(f["gate_c"].x - p_v.pos.x, f["gate_c"].z - p_v.pos.z).normalized() if m.lairs.inside(f, p_v.pos, -2.0) else outv
		_god(); m.step(Match.DT); tw += Match.DT
	p_v.inp["move"] = Vector2.ZERO
	ok(not m.lairs.inside(f, p_v.pos, 1.0), "and you walk out (%.1f s)" % tw)
	# ---------------------------------------------------------------- 3. the inside button: the lever opens it early
	var g: Dictionary = {}
	for l in m.lairs.list: if l != f and l["boss_mob"] != null and not (l["boss_mob"] as Boss).dead: g = l
	ok(not g.is_empty(), "a second lair to fight (%s)" % String(g.get("name", "?")))
	if not g.is_empty():
		var kt2 := _kill(g, p_v, c)
		ok(g.get("victory", false) and g.get("locked", false), "%s falls and locks its fighters in" % String(g["name"]))
		var gout := Vector3(g["out"].x, 0, g["out"].y)
		_spot(p_v, g["lever"] - gout * 0.8)
		_run(0.1)
		var it := m.lairs.interact_for(p_v)
		ok(String(it.get("what", "")) == "lever" and String(it.get("label", "")).contains("Open the gate"), "by the gate inside, the lever offers: '%s'" % String(it.get("label", "")))
		# a rival just outside the wall by the lever can't pull it through the stones
		var qs: Vector3 = q.pos
		q.pos = g["lever"] + gout * 1.4; q.pos.y = float(g["lever"].y)
		ok(not m.lairs.inside(g, q.pos, 0.0) and not m.lairs.can_pull(g, q), "nobody outside can pull it through the wall")
		q.pos = qs
		p_v.inp["interact"] = true; _run(Match.DT); p_v.inp["interact"] = false; _run(0.3)
		ok(not g.get("locked", false) and not _gate_shut(g) and String(g.get("opened_by_lever", "")) == p_v.pname,
			"pulled %.1f s after the kill: the gate opens early" % (m.time - kt2))
		ok(m.lairs.interact_for(p_v).is_empty() or String(m.lairs.interact_for(p_v).get("what", "")) != "lever", "and the lever goes quiet")
	# ---------------------------------------------------------------- 4. the HUD tells the locked-in fighters the clock
	var h_v: Dictionary = {}
	for l in m.lairs.list: if l != f and l != g and l["boss_mob"] != null and not (l["boss_mob"] as Boss).dead: h_v = l
	if not h_v.is_empty() and m.hud:
		_kill(h_v, p_v, c)
		ok(m.lairs.sealed_lair(p_v) == h_v and h_v.get("victory", false), "after the third kill you're locked in %s, the victory banner up" % String(h_v["name"]))
	# ---------------------------------------------------------------- 5. the Sealed Lair quest seat
	# (Limited Ways Out, QuestSeats)
	# a match in the mode: one lair by the seed, locked before 2:00, then the first squad to kill its
	# boss takes it and leaves by its updraft (a rival there doesn't); unused, it shuts at 5:30
	m.over = true
	m.queue_free()
	await main.get_tree().process_frame
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 720.0, "seed": 21, "no_drop": true})
	m.set_process(false)
	p_v = m.player
	p_v.set_arch("")
	c = m.hunters.filter(func(x): return x.team == p_v.team and x != p_v)[0]
	q = m.hunters.filter(func(x): return x.team != p_v.team)[0]
	keep = [p_v, q]
	for h in m.hunters:
		h.ctrl = "idle" if h != p_v else "local"
		h.inp["move"] = Vector2.ZERO
	m.time = 10.0
	_run(0.1)
	var s: QuestSeats = m.exits.seats
	ok(s != null and s.lair != null, "the mode's exits have the Sealed Lair seat")
	if s != null and s.lair != null:
		var k: QuestSeat = s.lair
		var l: Dictionary = k.ref
		var s2 := QuestSeats.new(m)
		s2.build()
		ok(is_same(s2.lair.ref, l) and l.get("seat", false), "the seed picks %s (again the same)" % l["name"])
		m.lairs.open(l, p_v, "dial")
		_run(0.1)
		var locked: bool = k.state == QuestSeat.S.LOCKED and l["state"] == "sealed" and _gate_shut(l)
		ok(locked and m.lairs.seat_wait(l).contains("opens in"),
			"before 2:00 it's LOCKED: cracking the gate leaves it shut ('%s')" % m.lairs.seat_wait(l))
		m.time = k.open_s - m.sess_t0 + 0.5
		_run(0.2)
		ok(k.state == QuestSeat.S.OPEN and l["state"] != "sealed" and not _gate_shut(l),
			"at 2:00 it's OPEN and the gate cracked earlier opens (%s)" % l["state"])
		_spot(q, l["gate_c"] + Vector3(l["out"].x, 0, l["out"].y) * 4.0)
		_kill(l, p_v, c)
		ok(k.state == QuestSeat.S.TAKEN and k.team == p_v.team and not k.out,
			"P kills the boss: TAKEN by team %d" % k.team)
		m.knock(c, q, {})
		_spot(p_v, l["up"])
		_run(0.3)
		var how := String(m.result.get("how", ""))
		ok(k.out and p_v.extracted and c.extracted and how == QuestSeats.HOW_LAIR and not q.extracted,
			"P steps into the updraft: P and downed C leave (how=%s), the rival stays" % how)
		ok(k.refused == 0, "trail %s" % str(k.trail))
		# a seat nobody takes: a second lair run on a seat of its own, shut at 5:30 and sealed again
		for o in m.lairs.list: m.lairs.activate(o)
		var l2: Dictionary = {}
		for o in m.lairs.list: if not is_same(o, l) and o["state"] == "sealed": l2 = o
		if not l2.is_empty():
			var k2 := QuestSeat.new(m, "lair", l2, k.open_s, k.shut_s)
			s._host_lair(k2, k.open_s + 1.0)
			m.lairs.open(l2, q, "dial")
			var was := String(l2["state"])
			s._host_lair(k2, k.shut_s + 0.1)
			s._apply(k2)
			var resealed: bool = l2["state"] == "sealed" and _gate_shut(l2)
			ok(k2.state == QuestSeat.S.SHUT and was != "sealed" and resealed and k2.refused == 0,
				"unused at 5:30 it's SHUT and its gate seals again; trail %s" % str(k2.trail))
	for map_id in ["hollowcrown", "skyreach"]:
		await _prize_lairs(main, map_id)
	print("LAIR LOCK CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## ---------------------------------------------------------------- 6. one exit lair, two prize lairs per map
## All three lairs are live every match. The seed's Sealed Lair is the exit and only that; a boss kill in
## either other lair pays the last hit's squad inside 30 m its XP and drops, and nobody leaves the match.
func _prize_lairs(main: Node, map_id: String) -> void:
	m.over = true
	m.queue_free()
	await main.get_tree().process_frame
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 720.0, "seed": 21, "no_drop": true, "map": map_id})
	m.set_process(false)
	var p: Hunter = m.player
	p.set_arch("")
	var c: Hunter = m.hunters.filter(func(x): return x.team == p.team and x != p)[0]
	var q: Hunter = m.hunters.filter(func(x): return x.team != p.team)[0]
	keep = [p, c, q]
	for h in m.hunters:
		h.ctrl = "idle" if h != p else "local"
	m.time = 10.0
	_run(0.1)
	var live: Array = m.lairs.list.filter(func(l): return l["active"] and l["boss_mob"] != null)
	var exits: Array = live.filter(func(l): return l.get("seat", false))
	var prizes: Array = live.filter(func(l): return not l.get("seat", false))
	ok(live.size() == 3 and exits.size() == 1 and prizes.size() == 2,
		"%s: %d lairs live, %d exit (Sealed Lair) and %d prize" % [map_id, live.size(), exits.size(), prizes.size()])
	if prizes.size() != 2:
		return
	var seat: QuestSeat = m.exits.seats.lair
	for l in prizes:
		_spot(q, l["gate_c"] + Vector3(l["out"].x, 0, l["out"].y) * 40.0)
		var xp0 := [p.xp, c.xp, q.xp]
		_kill(l, p, c)
		var gain := [p.xp - xp0[0], c.xp - xp0[1], q.xp - xp0[2]]
		# (the rival's gain is only the Hunter's slow time trickle over the kill window: the boss's death move and
		# dissolve before its drops spill, SPILL_WAIT: about 9 XP, under a tenth of the boss's pay)
		var paid: bool = gain[0] >= KillXp.BOSS_XP and gain[1] >= KillXp.BOSS_XP and gain[2] < KillXp.BOSS_XP * 0.1
		var what := "%s: %s kill pays the last hit's squad, not the rival" % [map_id, l["name"]]
		ok(paid, what + " (%.1f, %.1f, %.1f)" % gain)
		ok(not dropped.is_empty(), "%s: and drops its pile" % l["name"])
		_run(Lairs.VICTORY_T + 1.0)
		_spot(p, l["up"])
		_run(0.5)
		ok(not p.extracted and not c.extracted and seat.state != QuestSeat.S.TAKEN and not m.over,
			"%s: standing in its updraft leaves nobody out of the match (seat %d)" % [l["name"], seat.state])

## Gems, keys and utility items are loot from a boss table, not stray junk.
func _is_loot_kind(kind: String) -> bool:
	return kind in ["gem", "key", "ckey"] or UtilityBelt.is_item(kind)
