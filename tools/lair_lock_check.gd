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

func _gate_shut(L: Dictionary) -> bool:
	return (L["gate_tiles"] as Array).all(func(q): return m.world.kind[m.world.idx(q.x, q.y)] == World.T_BLOCK)

## A boss in its lair, woken with P and C inside, then killed by P. Returns the kill time.
func _kill(L: Dictionary, P: Hunter, C: Hunter) -> float:
	for g in L["guards"]: if is_instance_valid(g) and not g.dead: g.dead = true; g.visible = false
	if L["state"] == "sealed": m.lairs.open(L, P, "dial")
	_spot(P, L["c"] + Vector3(L["out"].x, 0, L["out"].y) * 3.0)
	_spot(C, L["c"] + Vector3(-L["out"].y, 0, L["out"].x) * 3.0)
	_run(0.3)
	var b: Boss = L["boss_mob"]
	if b.buried: b._clear_attack()
	b.stagger_t = 0.0
	var pk0: Array = m.pickups.duplicate()
	b.hurt(b.hp + b.max_hp, P, {"src": "shot"})
	dropped = m.pickups.filter(func(p): return not pk0.has(p))      # (before anyone walks over them)
	_run(0.2)
	for a in L["adds"]: if is_instance_valid(a) and not a.dead: a.dead = true; a.visible = false
	return m.time - 0.2

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
	var P: Hunter = m.player
	P.set_arch("")      # (boss weapons come from the killer's class: the classic kit, as --boss-check)
	var C: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var Q: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	keep = [P, C, Q]
	for h in m.hunters:
		h.ctrl = "idle" if h != P else "local"
		h.inp["move"] = Vector2.ZERO
	for L in m.lairs.list: m.lairs.activate(L)
	var F: Dictionary = m.lairs.list[0]
	for L in m.lairs.list: if String(L["boss"]) == "colossus": F = L
	ok(is_equal_approx(Lairs.VICTORY_T, 20.0), "the post-kill lock is %d s" % int(Lairs.VICTORY_T))
	# ---------------------------------------------------------------- 1. the loot: few things, all good; the egg apart under its own beam
	# a piece of gear already lying in the lair where the egg would fall: the egg finds a spot clear of it too
	var stray_at := m.lairs._floor_spot(F, F["c"] + Vector3(-F["out"].y, 0, F["out"].x) * 4.0, 1.0)
	m.spawn_gear("bastion_plate", 4, stray_at, "", false)
	var w0 := m.wpicks.size()
	var kill_t := _kill(F, P, C)
	var gems_new: Array = dropped.filter(func(p): return String(p["kind"]) == "gem")
	# (utility items and keys from the boss table are loot now: UtilityDrops, decision 0007)
	var other_new: Array = dropped.filter(func(p): return not _is_loot_kind(String(p["kind"])))
	var gem_total := 0
	for p in gems_new: gem_total += int(p["v"])
	ok(gems_new.size() <= Match.BOSS_GEM_DROPS and gem_total >= int(Data.MOBS["colossus"]["gems"]) * 2 and other_new.is_empty(),
		"its gems come as %d big drops worth %d in all (not %d little ones), no armor shards or seeds (a utility item may come)" % [gems_new.size(), gem_total, int(Data.MOBS["colossus"]["gems"])])
	var b: Boss = F["boss_mob"]
	var drops: Array = m.wpicks.slice(w0)
	var egg = F.get("egg_wp")
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
	ok(egg != null and apart >= 3.0 and apart <= 7.0 and stray_d >= 2.5 and m.lairs.inside(F, egg["pos"], 0.0), "the egg sits on its own spot %.1f m from the nearest pile item (%.1f m from a rifle already lying there), inside the lair" % [apart, stray_d])
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
	ok(F.get("victory", false) and F.get("locked", false) and _gate_shut(F) and m.lairs.victory_left(F) > Lairs.VICTORY_T - 0.5,
		"the kill locks the lair: gate shut, opens in %s" % Lairs.clock(m.lairs.victory_left(F)))
	if sd != "":
		for i in 3:
			await main.get_tree().process_frame      # (the check ran in one long frame: let the frame time settle first)
		m.set_process(true)
		for i in 45:      # (the camera eases over to you)
			await main.get_tree().process_frame
		main.get_tree().root.get_texture().get_image().save_png(sd + "/lair_locked_in.png")
		m.set_process(false)
	var outv := Vector2(F["out"].x, F["out"].y)
	var outL := Vector3(outv.x, 0, outv.y)
	# a rival camping the gate tries to walk in
	Q.ctrl = "local"
	_spot(Q, F["gate_c"] + outL * 2.5)
	_walk(Q, -outv, 2.5)
	ok(not m.lairs.inside(F, Q.pos, 0.0), "a rival at the gate walks into it and stays out (%.1f m from the middle)" % Q.flat_dist(F["c"]))
	# ... or glides in over the wall
	Q.teleport(F["c"] + Vector3(0, 7.0, 0)); Q.vel = Vector3.ZERO; Q.grounded = false
	_run(0.6)
	ok(not m.lairs.inside(F, Q.pos, 0.0) or Q.pos.y > float(F["c"].y) + 3.0, "or glides in over the wall: thrown back out")
	_spot(Q, F["gate_c"] + outL * 3.0)
	Q.ctrl = "idle"
	# the fighters can't walk out either
	_spot(P, F["c"] + outL * (float(F["half"]) - 2.0))
	_walk(P, outv, 1.5)
	ok(m.lairs.inside(F, P.pos, 0.0) and _gate_shut(F), "you can't walk out through the shut gate")
	# the lock holds the whole clock
	_spot(P, F["c"] + outL * 3.0)
	while m.time - kill_t < Lairs.VICTORY_T - 1.0: _run(Match.DT)
	ok(F.get("locked", false) and _gate_shut(F) and F.get("victory", false), "still locked %.0f s after the kill (%s left)" % [m.time - kill_t, Lairs.clock(m.lairs.victory_left(F))])
	_spot(Q, F["gate_c"] + outL * 2.5)
	Q.ctrl = "local"
	_walk(Q, -outv, 1.0)
	ok(not m.lairs.inside(F, Q.pos, 0.0), "the camper is still kept out a second before it opens")
	Q.ctrl = "idle"; _spot(Q, F["gate_c"] + outL * 4.0)
	while F.get("locked", false) and m.time - kill_t < Lairs.VICTORY_T + 2.0: _run(Match.DT)
	ok(not F.get("locked", false) and not _gate_shut(F) and absf(m.time - kill_t - Lairs.VICTORY_T) < 0.3,
		"then it opens by itself %.1f s after the kill" % (m.time - kill_t))
	_walk(P, outv, 0.1)
	var tw := 0.0
	while m.lairs.inside(F, P.pos, 1.0) and tw < 8.0:
		P.inp["move"] = Vector2(F["gate_c"].x - P.pos.x, F["gate_c"].z - P.pos.z).normalized() if m.lairs.inside(F, P.pos, -2.0) else outv
		_god(); m.step(Match.DT); tw += Match.DT
	P.inp["move"] = Vector2.ZERO
	ok(not m.lairs.inside(F, P.pos, 1.0), "and you walk out (%.1f s)" % tw)
	# ---------------------------------------------------------------- 3. the inside button: the lever opens it early
	var G: Dictionary = {}
	for L in m.lairs.list: if L != F and L["boss_mob"] != null and not (L["boss_mob"] as Boss).dead: G = L
	ok(not G.is_empty(), "a second lair to fight (%s)" % String(G.get("name", "?")))
	if not G.is_empty():
		var kt2 := _kill(G, P, C)
		ok(G.get("victory", false) and G.get("locked", false), "%s falls and locks its fighters in" % String(G["name"]))
		var gout := Vector3(G["out"].x, 0, G["out"].y)
		_spot(P, G["lever"] - gout * 0.8)
		_run(0.1)
		var it := m.lairs.interact_for(P)
		ok(String(it.get("what", "")) == "lever" and String(it.get("label", "")).contains("Open the gate"), "by the gate inside, the lever offers: '%s'" % String(it.get("label", "")))
		# a rival just outside the wall by the lever can't pull it through the stones
		var qs: Vector3 = Q.pos
		Q.pos = G["lever"] + gout * 1.4; Q.pos.y = float(G["lever"].y)
		ok(not m.lairs.inside(G, Q.pos, 0.0) and not m.lairs.can_pull(G, Q), "nobody outside can pull it through the wall")
		Q.pos = qs
		P.inp["interact"] = true; _run(Match.DT); P.inp["interact"] = false; _run(0.3)
		ok(not G.get("locked", false) and not _gate_shut(G) and String(G.get("opened_by_lever", "")) == P.pname,
			"pulled %.1f s after the kill: the gate opens early" % (m.time - kt2))
		ok(m.lairs.interact_for(P).is_empty() or String(m.lairs.interact_for(P).get("what", "")) != "lever", "and the lever goes quiet")
	# ---------------------------------------------------------------- 4. the HUD tells the locked-in fighters the clock
	var H: Dictionary = {}
	for L in m.lairs.list: if L != F and L != G and L["boss_mob"] != null and not (L["boss_mob"] as Boss).dead: H = L
	if not H.is_empty() and m.hud:
		_kill(H, P, C)
		ok(m.lairs.sealed_lair(P) == H and H.get("victory", false), "after the third kill you're locked in %s, the victory banner up" % String(H["name"]))
	print("LAIR LOCK CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Gems, keys and utility items are loot from a boss table, not stray junk.
func _is_loot_kind(kind: String) -> bool:
	return kind in ["gem", "key", "ckey"] or UtilityBelt.is_item(kind)
