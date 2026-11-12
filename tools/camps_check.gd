extends RefCounted
## --camps-check: monster camps and the XP rules (scripts/match/camps.gd, scripts/match/xp_rules.gd,
## docs/decisions/0048-camps-and-xp.md). Camps spawn on every camp spot at their size (one up in the
## hot zone), tagged, with the size's XP in monsters; the Chief's Brute is a tier up. No XP for
## standing still or for hurting Hunters (armor only); a kill pays its XP to the last hit's squad
## within 30 m; a knock pays 40 + 15 x the victim's level. The last kill clears the camp: one toast,
## one bundle where it fell, no drops of the monsters' own; a stealer takes it. A cleared camp comes
## back once, one size up, 150 s later with nobody near, not after 7:00, under the cap. The Boon of
## the Hunt (HuntBoon) rows: _boon. A Camp Chief stolen after a rival did 95% of it: _steal_chief.
## Never touches the save.

const SIZE_XP := {"small": 60.0, "camp": 110.0, "great": 190.0, "chief": 260.0}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CAMPS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _match(main: Node, seed_v: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 6, "squad": 3, "tier": 0, "length": 1e9, "seed": seed_v, "no_drop": true})
	m.set_process(false)
	return m

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_rules()
	var m := _match(main, 5)
	_spawn(m)
	_xp(m)
	_boon(m)
	_clear(m)
	_comeback(m)
	_hot(main)
	_steal_chief(main)
	print("CAMPS DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _rules() -> void:
	var R := XpRules.rules()
	ok(float(R["share_r"]) == 30.0 and float(R["stray"]) == 8.0, "XP rules come from content/rules/xp.json (30 m squad, 8 a stray)")
	var src := FileAccess.get_file_as_string("res://scripts/match/rolling.gd")
	ok(not ("CAMP_RESPAWN" in src or "_camp_respawns" in src or "note_camp" in src), "Rolling no longer owns the camp comeback")
	var ms := FileAccess.get_file_as_string("res://scripts/match/match.gd")
	ok(not ("func _spawn_mobs" in ms) and not ("0.35))" in ms), "Match spawns camps through Camps and pays no damage XP")
	ok(not ("gain_xp(dt" in FileAccess.get_file_as_string("res://scripts/match/hunter.gd")), "no XP trickle in Hunter")

func _camp_mobs(c: Dictionary) -> Array:
	return (c["mobs"] as Array).filter(func(mb): return is_instance_valid(mb) and not mb.dead)

func _spawn(m: Match) -> void:
	var C: Camps = m.camps
	ok(C != null and C.camps.size() == m.world.camp_spots.size() and C.camps.size() > 4, "a camp on every camp spot (%d)" % (C.camps.size() if C else 0))
	var sized := true
	var tagged := true
	var xp_ok := true
	var chief_ok := true
	var seen := {}
	for c in C.camps:
		var sd := Camps.size_def(int(c["size"]))
		seen[sd["id"]] = true
		sized = sized and (c["mobs"] as Array).size() == int(sd["n"]) and c["state"] == Camps.State.LIVE
		var xp := 0.0
		for mb in c["mobs"]:
			tagged = tagged and int(mb.get_meta("camp", -1)) == int(c["id"])
			xp += XpRules.kill_xp(mb)
			if mb.has_meta("chief"):
				chief_ok = chief_ok and mb.mkind == "brute" and (not mb.has_meta("rarity") or int(mb.get_meta("rarity")) >= 1)
		xp_ok = xp_ok and absf(xp - float(SIZE_XP[sd["id"]])) < 0.5
		if sd["id"] == "chief":
			chief_ok = chief_ok and (c["mobs"] as Array).filter(func(mb): return mb.has_meta("chief")).size() == 1
	ok(sized, "each camp has its size's monster count and starts LIVE")
	ok(tagged, "camp monsters carry their camp's id")
	ok(xp_ok, "a camp's monsters add up to its size's XP (small 60, camp 110, great 190, chief 260)")
	ok(chief_ok, "a Camp Chief has one Chief Brute, a rarity tier up")
	ok(seen.size() >= 2, "the map has several camp sizes (%s)" % ", ".join(seen.keys()))
	var L := C.list()
	ok(L.size() == C.camps.size() and L[0].has_all(["id", "pos", "size", "state", "back_t", "region"]), "Camps.list() gives id, pos, size, state, back_t, region")
	var c0: Dictionary = C.camps[0]
	ok(int(C.nearest_live(c0["pos"], 5.0).get("id", -1)) == int(c0["id"]) and C.nearest_live(c0["pos"] + Vector3(1e4, 0, 0), 30.0).is_empty(), "nearest_live finds the camp here and none far off")
	ok(C.region_xp(int(c0["region"])) >= float(SIZE_XP[Camps.size_def(int(c0["size"]))["id"]]) - 0.5, "region_xp counts the XP alive in a region's camps")

func _xp(m: Match) -> void:
	var P: Hunter = m.player
	var x0 := P.xp
	for i in 100: P.sim(0.1)
	ok(absf(P.xp - x0) < 0.001, "no XP for standing 10 s")
	var rival: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	rival.pos = P.pos + Vector3(3, 0, 0)
	var a0 := P.armor_xp
	x0 = P.xp
	rival.hurt(20.0, P)
	ok(absf(P.xp - x0) < 0.001 and P.armor_xp > a0, "hurting a Hunter builds armor XP, not level XP")
	# a monster outside a camp: 8 to the killer and teammates within 30 m, nothing to the far one or a rival
	var mates: Array = m.hunters.filter(func(h): return h.team == P.team and h != P)
	var near: Hunter = mates[0]
	var far: Hunter = mates[1]
	near.pos = P.pos + Vector3(10, 0, 0)
	far.pos = P.pos + Vector3(40, 0, 0)
	var xs := [P.xp, near.xp, far.xp, rival.xp]
	var mb := m.spawn_mob("skitter", P.pos + Vector3(2, 0, 0))
	mb.hurt(1e6, P)
	ok(absf(P.xp - xs[0] - 8.0) < 0.01 and absf(near.xp - xs[1] - 8.0) < 0.01, "a stray kill pays 8 to the killer and a teammate 10 m away")
	ok(absf(far.xp - xs[2]) < 0.001 and absf(rival.xp - xs[3]) < 0.001, "not to a teammate 40 m away, nor a rival")
	var kx := XpRules.knock_xp(rival)
	ok(kx == 40.0 + 15.0 * rival.lvl, "a knock pays 40 + 15 x the victim's level (%d)" % int(kx))
	xs = [P.xp, near.xp, far.xp]
	rival.pos = P.pos + Vector3(3, 0, 0)
	m.knock(rival, P, {})
	ok(absf(P.xp - xs[0] - kx) < 0.01 and absf(near.xp - xs[1] - kx) < 0.01 and absf(far.xp - xs[2]) < 0.001, "the knock XP goes in full to the knocker and teammates within 30 m only")
	m.revive_hunter(rival, rival)

## Boon of the Hunt (xp.json "boon"): the Watcher's kill gives the Hunters it pays +8% damage and +8%
## move speed for 120 s, a second refreshes, a knock passes what the holder had left to the knocker's
## squad. Online the owner of each Hunter grants theirs and sends "kst" "bon"; the other games end and
## pass a boon on the "knock" event and grant their own on "mobdead" the same way.
func _boon(m: Match) -> void:
	var B: Dictionary = XpRules.rules()["boon"]
	ok(float(B["secs"]) == 120.0 and float(B["dmg"]) == 0.08 and float(B["speed"]) == 0.08,
		"boon: 120 s, +8% damage, +8% move speed, in xp.json")
	var P: Hunter = m.player
	var mates: Array = m.hunters.filter(func(h): return h.team == P.team and h != P)
	var near: Hunter = mates[0]
	var far: Hunter = mates[1]
	var rival: Hunter = m.hunters.filter(func(h): return h.team != P.team and not h.downed)[0]
	var v0 := _run_speed(P)
	var d0 := m.dmg_mult(P)
	near.pos = P.pos + Vector3(10, 0, 0)
	far.pos = P.pos + Vector3(40, 0, 0)
	rival.pos = P.pos + Vector3(3, 0, 0)
	m.spawn_mob("skitter", P.pos + Vector3(2, 0, 0)).hurt(1e6, P)
	ok(HuntBoon.left(P) == 0.0, "boon: a plain monster's kill gives none")
	m.spawn_mob("warden", P.pos + Vector3(2, 0, 0)).hurt(1e6, P)
	ok(absf(HuntBoon.left(P) - 120.0) < 0.01 and absf(HuntBoon.left(near) - 120.0) < 0.01,
		"boon: the Watcher's kill gives the killer and a teammate 10 m away 120 s")
	ok(HuntBoon.left(far) == 0.0 and HuntBoon.left(rival) == 0.0, "boon: not a teammate 40 m away, nor a rival")
	ok(is_equal_approx(m.dmg_mult(P), d0 * 1.08), "boon: +8%% damage dealt (x%.3f -> x%.3f)" % [d0, m.dmg_mult(P)])
	var v1 := _run_speed(P)
	ok(absf(v1 / v0 - 1.08) < 0.01, "boon: +8%% move speed (%.2f -> %.2f m/s)" % [v0, v1])
	P.set_meta("bon_until", m.time + 30.0)
	m.spawn_mob("warden", P.pos + Vector3(2, 0, 0)).hurt(1e6, P)
	ok(absf(HuntBoon.left(P) - 120.0) < 0.01 and is_equal_approx(m.dmg_mult(P), d0 * 1.08),
		"boon: a second refreshes it to 120 s and never stacks")
	# a knock passes the holder's time left to the knocker's squad in range
	for h in [P, near]: h.set_meta("bon_until", 0.0)
	KitStatus.apply(rival, "bon", 50.0)
	m.knock(rival, P, {})
	ok(HuntBoon.left(rival) == 0.0, "boon: knocking a holder ends theirs")
	ok(absf(HuntBoon.left(P) - 50.0) < 0.01 and absf(HuntBoon.left(near) - 50.0) < 0.01 and HuntBoon.left(far) == 0.0,
		"boon: the knocker and a teammate 10 m away get the 50 s it had left, not one 40 m away")
	m.revive_hunter(rival, rival)
	var by_mob := m.spawn_mob("skitter", near.pos + Vector3(2, 0, 0))
	m.knock(near, by_mob, {})
	ok(HuntBoon.left(near) == 0.0 and absf(HuntBoon.left(P) - 50.0) < 0.01,
		"boon: a monster's knock ends it and passes it to nobody")
	m.revive_hunter(near, near)
	_boon_net(m, P, near, rival)
	for h in m.hunters: h.set_meta("bon_until", 0.0)

## The boon online, on one game: what it sends for its own Hunters, and what it does with the events.
func _boon_net(m: Match, P: Hunter, near: Hunter, rival: Hunter) -> void:
	m.net_on = true
	for h in [P, near]: h.set_meta("bon_until", 0.0)
	Net.out_events.clear()
	m.spawn_mob("warden", P.pos + Vector3(2, 0, 0)).hurt(1e6, P)
	var sent: Array = Net.out_events.filter(func(e): return String(e[0]) == "kst" and String(e[2]) == "bon")
	var to: Array = sent.map(func(e): return String(e[1]))
	ok(sent.size() == 2 and P.nid in to and near.nid in to and float(sent[0][3]) == 120.0,
		"boon net: a \"kst\" \"bon\" of 120 s for each Hunter this game gave it to (%s)" % [to])
	for h in [P, near]: h.set_meta("bon_until", 0.0)
	rival.remote = true
	m._net_ev(["kst", rival.nid, "bon", 40.0, 0.0], "peer")
	ok(absf(HuntBoon.left(rival) - 40.0) < 0.01, "boon net: another game's Hunter shows the boon it was sent")
	m._net_ev(["knock", rival.nid, P.nid], "peer")
	ok(HuntBoon.left(rival) == 0.0 and absf(HuntBoon.left(P) - 40.0) < 0.01 and absf(HuntBoon.left(near) - 40.0) < 0.01,
		"boon net: a \"knock\" event ends theirs and gives this game's knocking squad the 40 s")
	rival.downed = false
	rival.remote = false
	m.revive_hunter(rival, rival)
	for h in [P, near]: h.set_meta("bon_until", 0.0)
	var w := m.spawn_mob("warden", P.pos + Vector3(2, 0, 0))
	m._net_ev(["mobdead", w.nid, P.nid, 8.0], "host")
	ok(absf(HuntBoon.left(P) - 120.0) < 0.01 and absf(HuntBoon.left(near) - 120.0) < 0.01,
		"boon net: a host's \"mobdead\" for the Watcher gives this game's squad the boon")
	m.net_on = false
	Net.out_events.clear()

## h's run speed on flat input after a second, from where it stands (it is put back after).
func _run_speed(h: Hunter) -> float:
	var at := h.pos
	h.vel = Vector3.ZERO
	h.inp["move"] = Vector2(1, 0)
	for i in 30: h.sim(1.0 / 30.0)
	var v := Vector2(h.vel.x, h.vel.z).length()
	h.inp["move"] = Vector2.ZERO
	h.vel = Vector3.ZERO
	h.teleport(at)
	return v

## Clears a camp with hunter h; returns the toasts and drops it made.
func _kill_camp(m: Match, c: Dictionary, h: Hunter) -> Dictionary:
	h.pos = (c["pos"] as Vector3) + Vector3(1, 0, 0)
	var picks0 := m.pickups.size()
	var w0 := m.wpicks.size()
	var o0: int = (PerkOrbs.st(m)["list"] as Array).size()
	var x0 := h.xp
	var got := []
	var on_clear := func(id, sq): got.append([id, sq])
	m.camps.cleared.connect(on_clear)
	var last: Mob = null
	for mb in _camp_mobs(c):
		last = mb
		mb.hurt(1e6, h)
	m.camps.cleared.disconnect(on_clear)
	var armor := m.pickups.slice(picks0).filter(func(p): return String(p.get("kind", "")) == "armor")
	return {"xp": h.xp - x0, "got": got, "picks": m.pickups.slice(picks0), "armor": armor, "w": m.wpicks.slice(w0),
		"orbs": (PerkOrbs.st(m)["list"] as Array).size() - o0, "last": last}

func _clear(m: Match) -> void:
	var C: Camps = m.camps
	var P: Hunter = m.player
	for h in m.hunters:
		if h != P: h.pos = Vector3(-1e4, 0, -1e4)      # (nobody else near: they'd share the XP)
	var by_size := {}
	for c in C.camps:
		by_size[Camps.size_def(int(c["size"]))["id"]] = c
	var seeds_vals := 0
	for sid in by_size:
		var c: Dictionary = by_size[sid]
		var sd := Camps.size_def(int(c["size"]))
		m.time = 30.0
		var r := _kill_camp(m, c, P)
		ok(absf(float(r["xp"]) - float(SIZE_XP[sid])) < 0.5, "%s: clearing it pays %d XP (got %d)" % [sid, int(SIZE_XP[sid]), int(r["xp"])])
		ok(r["got"].size() == 1 and int(r["got"][0][1]) == P.team, "%s: one cleared signal, for the clearing squad" % sid)
		ok(c["state"] == Camps.State.CLEARED and absf(float(c["back_t"]) - 180.0) < 0.01, "%s: CLEARED, back at +150 s" % sid)
		ok(r["armor"].size() == 1 and int(r["armor"][0]["v"]) == int(sd["armor"]), "%s: one armor drop of %d" % [sid, int(sd["armor"])])
		var p_last: Vector3 = (r["last"] as Mob).pos
		ok(r["armor"].size() == 1 and Vector2(r["armor"][0]["pos"].x - p_last.x, r["armor"][0]["pos"].z - p_last.z).length() < 2.5, "%s: the bundle lands where the last monster fell" % sid)
		if float(sd["orb"]) >= 1.0 or float(sd["orb"]) <= 0.0:
			ok(int(r["orbs"]) == int(sd["orb"]), "%s: %d perk orb(s) in the bundle (got %d)" % [sid, int(sd["orb"]), int(r["orbs"])])
		var gear: Array = r["w"].filter(func(w): return w.has("gear") and String(w.get("gear", "")) != "")
		var want_gear := 1 if sd.has("gear") else 0
		ok(gear.size() == want_gear, "%s: %d gear piece(s)" % [sid, want_gear])
		seeds_vals += r["picks"].filter(func(p): return String(p.get("kind", "")) == "seed").size()
		seeds_vals += r["w"].filter(func(w): return w.has("val")).size()
	ok(seeds_vals == 0, "camp monsters roll no seeds or treasure of their own")
	# a stealer takes the last hit, the XP and the bundle
	var thief: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	var c2: Dictionary = {}
	for c in C.camps:
		if c["state"] == Camps.State.LIVE and _camp_mobs(c).size() >= 2:
			c2 = c
			break
	if not c2.is_empty():
		P.pos = (c2["pos"] as Vector3) + Vector3(1, 0, 0)
		var ms := _camp_mobs(c2)
		var px := P.xp
		for i in ms.size() - 1: ms[i].hurt(1e6, P)
		var pgot := P.xp - px
		var tx := thief.xp
		var r := _kill_camp(m, c2, thief)
		ok(r["got"].size() == 1 and int(r["got"][0][1]) == thief.team and absf(float(r["xp"]) - XpRules.kill_xp(ms[-1])) < 0.5, "a stealer's last hit takes that kill's XP and the clear")
		ok(absf(P.xp - px - pgot) < 0.001 and pgot > 0.0 and thief.xp > tx, "the first squad keeps what its own kills paid")

## One Camps tick now (it runs once a second).
func _tick(C: Camps) -> void:
	C._tick_t = 0.0
	C.tick(0.1)

func _comeback(m: Match) -> void:
	var C: Camps = m.camps
	var cl: Array = C.camps.filter(func(c): return c["state"] == Camps.State.CLEARED)
	ok(cl.size() >= 2, "cleared camps to bring back (%d)" % cl.size())
	if cl.size() < 2:
		return
	var c: Dictionary = cl[0]
	var s0 := int(c["size"])
	var c2: Dictionary = cl[1]
	var c2_back := float(c2["back_t"])
	for o in cl.slice(1): o["back_t"] = 1e9       # one camp at a time
	for h in m.hunters: h.pos = Vector3(-1e4, 0, -1e4)
	m.time = float(c["back_t"]) - 5.0
	_tick(C)
	ok(c["state"] == Camps.State.CLEARED, "not back before 150 s")
	m.time = float(c["back_t"]) + 1.0
	m.player.pos = (c["pos"] as Vector3) + Vector3(10, 0, 0)
	_tick(C)
	ok(c["state"] == Camps.State.CLEARED, "not back with a Hunter within 30 m")
	m.player.pos = Vector3(-1e4, 0, -1e4)
	var len0 := m.length
	m.length = m.time + 30.0
	_tick(C)
	ok(c["state"] == Camps.State.CLEARED and not C.safe_for(c["pos"], 60.0), "not back where the Blight will be within 60 s")
	m.length = len0
	_tick(C)
	var want := mini(s0 + 1, Camps.rules()["sizes"].size() - 1)
	ok(c["state"] == Camps.State.RETURNING and int(c["size"]) == want and _camp_mobs(c).size() == int(Camps.size_def(want)["n"]), "back once at 150 s, one size up (%s)" % Camps.size_def(want)["id"])
	ok(C.comebacks == 1, "one comeback counted")
	var r := _kill_camp(m, c, m.player)
	ok(c["state"] == Camps.State.SPENT and r["got"].size() == 1, "clearing it again pays and leaves it SPENT")
	m.time += 1000.0
	_tick(C)
	ok(c["state"] == Camps.State.SPENT and _camp_mobs(c).is_empty(), "a spent camp never comes back")
	c2["back_t"] = c2_back
	m.time = maxf(c2_back, float(Camps.rules()["back_until_s"])) + 1.0
	_tick(C)
	ok(c2["state"] == Camps.State.SPENT, "no comeback after 7:00")
	# the cap: with 85 camp monsters up, nothing comes back
	var c3: Dictionary = {}
	for c4 in C.camps:
		if c4["state"] == Camps.State.LIVE and c4 != c2:
			c3 = c4
			break
	if not c3.is_empty():
		var sv: Variant = Camps.rules()["max_mobs"]
		Camps.rules()["max_mobs"] = C.alive()
		for mb in _camp_mobs(c3): mb.hurt(1e6, m.player)
		Camps.rules()["max_mobs"] = C.alive()
		m.time = float(c3["back_t"]) + 1.0
		for h in m.hunters: h.pos = Vector3(-1e4, 0, -1e4)
		_tick(C)
		ok(c3["state"] == Camps.State.CLEARED or m.time > float(Camps.rules()["back_until_s"]), "no comeback at the camp-monster cap")
		Camps.rules()["max_mobs"] = sv

## In the hot zone every camp is one size up from its spot's kind.
func _hot(main: Node) -> void:
	var checked := 0
	var good := true
	for s in [3, 9, 21]:
		var m := _match(main, s)
		var ks: Dictionary = Camps.rules()["kind_size"]
		var ids: Array = Camps.rules()["sizes"].map(func(d): return d["id"])
		for i in m.camps.camps.size():
			var c: Dictionary = m.camps.camps[i]
			var base: int = ids.find(ks.get(String(m.world.camp_spots[i].get("kind", "normal")), "camp"))
			var hot: bool = m.biomes != null and int(c["region"]) >= 0 and int(c["region"]) == m.biomes.hot.hot
			good = good and int(c["size"]) == (mini(base + 1, ids.size() - 1) if hot else base)
			if hot: checked += 1
		m.queue_free()
	ok(good and checked > 0, "hot-zone camps are one size up, the rest at their kind's size (%d hot)" % checked)

## Squad A (the player's) deals 95% of a Camp Chief's Brute, the camp's last monster; squad B lands
## the last hit and takes the chief's XP (its squadmate in the share too) and the clear, A gets nothing,
## and the feed names B's killer.
func _steal_chief(main: Node) -> void:
	var m: Match = null
	var c: Dictionary = {}
	for s in [5, 3, 9, 21, 1, 2, 4, 6]:
		m = _match(main, s)
		for cc in m.camps.camps:
			if Camps.size_def(int(cc["size"]))["id"] == "chief":
				c = cc
		if not c.is_empty():
			break
		m.queue_free()
	ok(not c.is_empty(), "a seed with a Camp Chief")
	if c.is_empty():
		return
	var P: Hunter = m.player
	var thief: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	var p_mate: Hunter = m.hunters.filter(func(h): return h.team == P.team and h != P)[0]
	var t_mate: Hunter = m.hunters.filter(func(h): return h.team == thief.team and h != thief)[0]
	for h in m.hunters:
		h.pos = Vector3(-1e4, 0, -1e4)
	P.pos = (c["pos"] as Vector3) + Vector3(1, 0, 0)
	p_mate.pos = (c["pos"] as Vector3) + Vector3(0, 0, 5)
	thief.pos = (c["pos"] as Vector3) + Vector3(-1, 0, 0)
	t_mate.pos = (c["pos"] as Vector3) + Vector3(0, 0, -5)      # (well inside the 30 m share)
	var chief: Mob = _camp_mobs(c).filter(func(mb): return mb.has_meta("chief"))[0]
	for mb in _camp_mobs(c):
		if mb != chief: mb.hurt(1e6, P)
	chief.hurt(chief.max_hp * 0.95, P)
	var a_dealt := float(chief.damage_by.get(P.team, 0.0))
	ok(not chief.dead and a_dealt > chief.max_hp * 0.9, "squad A has dealt over 90% of the Chief")
	var before: Array = [P, p_mate, thief, t_mate].map(func(h): return h.xp)
	var got := []
	m.camps.cleared.connect(func(id, sq): got.append(sq))
	chief.hurt(1e6, thief)
	var want := XpRules.kill_xp(chief)
	var gain: Array = [P, p_mate, thief, t_mate].map(func(h): return h.xp - float(before.pop_front()))
	ok(chief.dead and absf(gain[2] - want) < 0.01 and absf(gain[3] - want) < 0.01,
		"squad B's last hit takes the Chief's %d XP, for the killer and the squadmate 5 m off (%.1f, %.1f)"
		% [int(want), gain[2], gain[3]])
	ok(absf(gain[0]) < 0.001 and absf(gain[1]) < 0.001,
		"squad A, with 95%% of the damage, gets none (%.1f, %.1f)" % [gain[0], gain[1]])
	ok(got == [thief.team], "the camp's clear (its bundle and toast) goes to squad B")
	var named := "%s stole the Camp Chief from %s" % [thief.pname, m.truce.squad_name(P.team)]
	ok(String(m.feed_all[-1]).ends_with(named), "the feed calls out the steal (%s)" % String(m.feed_all[-1]))
	m.queue_free()
