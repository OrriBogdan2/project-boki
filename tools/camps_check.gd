extends RefCounted
## --camps-check: monster camps (scripts/match/camps.gd, docs/decisions/0100-camps-own-the-early-game.md).
## Camps spawn on every camp spot at their size (one up in the hot zone), tagged. The last kill clears the
## camp: one toast signal, one bundle where it fell, no drops of the monsters' own, and the clearing squad
## is paid by KillXp. A cleared camp comes back once, one size up, 150 s later with nobody near, not after
## 7:00, under the cap. Rolling no longer owns the comeback. Never touches the save.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("CAMPS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


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
	var src := FileAccess.get_file_as_string("res://scripts/match/rolling.gd")
	ok(
		not ("CAMP_RESPAWN" in src or "_camp_respawns" in src or "note_camp" in src),
		"Rolling no longer owns the camp comeback"
	)
	var m := _match(main, 5)
	_spawn(m)
	_clear(m)
	_comeback(m)
	_hot(main)
	print("CAMPS DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)


func _camp_mobs(c: Dictionary) -> Array:
	return (c["mobs"] as Array).filter(func(mb): return is_instance_valid(mb) and not mb.dead)


func _spawn(m: Match) -> void:
	var camps: Camps = m.camps
	var n_spots := m.world.camp_spots.size()
	ok(camps != null and camps.camps.size() == n_spots and n_spots > 4, "a camp on every camp spot (%d)" % n_spots)
	var sized := true
	var tagged := true
	var seen := {}
	for c in camps.camps:
		var sd := Camps.size_def(int(c["size"]))
		seen[sd["id"]] = true
		sized = sized and (c["mobs"] as Array).size() == int(sd["n"]) and c["state"] == Camps.State.LIVE
		for mb in c["mobs"]:
			tagged = tagged and int(mb.get_meta("camp", -1)) == int(c["id"])
	ok(sized, "each camp has its size's monster count and starts LIVE")
	ok(tagged, "camp monsters carry their camp's id")
	ok(seen.size() >= 2, "the map has several camp sizes (%s)" % ", ".join(seen.keys()))
	var rows := camps.list()
	ok(
		rows.size() == camps.camps.size() and rows[0].has_all(["id", "pos", "size", "state", "back_t", "region"]),
		"Camps.list() gives id, pos, size, state, back_t, region"
	)


## Clears a camp with hunter h; returns what it paid and dropped.
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
	var kill_xp := 0.0
	for mb in _camp_mobs(c):
		last = mb
		kill_xp += KillXp.xp_of(mb)
		mb.hurt(1e6, h)
	m.camps.cleared.disconnect(on_clear)
	var armor := m.pickups.slice(picks0).filter(func(p): return String(p.get("kind", "")) == "armor")
	return {
		"xp": h.xp - x0,
		"want_xp": kill_xp,
		"got": got,
		"picks": m.pickups.slice(picks0),
		"armor": armor,
		"w": m.wpicks.slice(w0),
		"orbs": (PerkOrbs.st(m)["list"] as Array).size() - o0,
		"last": last
	}


func _clear(m: Match) -> void:
	var camps: Camps = m.camps
	var pl: Hunter = m.player
	for h in m.hunters:
		if h != pl:
			h.pos = Vector3(-1e4, 0, -1e4)  # (nobody else near: they'd share the XP)
	var by_size := {}
	for c in camps.camps:
		by_size[Camps.size_def(int(c["size"]))["id"]] = c
	var seeds_vals := 0
	for sid in by_size:
		var c: Dictionary = by_size[sid]
		var sd := Camps.size_def(int(c["size"]))
		m.time = 30.0
		var r := _kill_camp(m, c, pl)
		ok(
			absf(float(r["xp"]) - float(r["want_xp"])) < 0.5 and float(r["xp"]) > 0.0,
			"%s: clearing it pays its monsters' kill XP (%d)" % [sid, int(r["xp"])]
		)
		ok(
			r["got"].size() == 1 and int(r["got"][0][1]) == pl.team,
			"%s: one cleared signal, for the clearing squad" % sid
		)
		ok(
			c["state"] == Camps.State.CLEARED and absf(float(c["back_t"]) - 180.0) < 0.01,
			"%s: CLEARED, back at +150 s" % sid
		)
		ok(
			r["armor"].size() == 1 and int(r["armor"][0]["v"]) == int(sd["armor"]),
			"%s: one armor drop of %d" % [sid, int(sd["armor"])]
		)
		var p_last: Vector3 = (r["last"] as Mob).pos
		ok(
			(
				r["armor"].size() == 1
				and Vector2(r["armor"][0]["pos"].x - p_last.x, r["armor"][0]["pos"].z - p_last.z).length() < 2.5
			),
			"%s: the bundle lands where the last monster fell" % sid
		)
		if float(sd["orb"]) >= 1.0 or float(sd["orb"]) <= 0.0:
			ok(
				int(r["orbs"]) == int(sd["orb"]),
				"%s: %d perk orb(s) in the bundle (got %d)" % [sid, int(sd["orb"]), int(r["orbs"])]
			)
		var gear: Array = r["w"].filter(func(w): return w.has("gear") and String(w.get("gear", "")) != "")
		var want_gear := 1 if sd.has("gear") else 0
		ok(gear.size() == want_gear, "%s: %d gear piece(s)" % [sid, want_gear])
		seeds_vals += r["picks"].filter(func(p): return String(p.get("kind", "")) == "seed").size()
		seeds_vals += r["w"].filter(func(w): return w.has("val")).size()
	ok(seeds_vals == 0, "camp monsters roll no seeds or treasure of their own")
	# a stealer takes the last hit, its XP and the bundle; the first squad keeps what its own kills paid
	var thief: Hunter = m.hunters.filter(func(h): return h.team != pl.team)[0]
	var c2: Dictionary = {}
	for c in camps.camps:
		if c["state"] == Camps.State.LIVE and _camp_mobs(c).size() >= 2:
			c2 = c
			break
	if not c2.is_empty():
		pl.pos = (c2["pos"] as Vector3) + Vector3(1, 0, 0)
		var ms := _camp_mobs(c2)
		var px := pl.xp
		for i in ms.size() - 1:
			ms[i].hurt(1e6, pl)
		var pgot := pl.xp - px
		var tx := thief.xp
		var r := _kill_camp(m, c2, thief)
		ok(
			r["got"].size() == 1 and int(r["got"][0][1]) == thief.team and thief.xp > tx,
			"a stealer's last hit takes that kill's XP and the clear"
		)
		ok(absf(pl.xp - px - pgot) < 0.001 and pgot > 0.0, "the first squad keeps what its own kills paid")


## One Camps tick now (it runs once a second).
func _tick(camps: Camps) -> void:
	camps._tick_t = 0.0
	camps.tick(0.1)


func _comeback(m: Match) -> void:
	var camps: Camps = m.camps
	var cl: Array = camps.camps.filter(func(c): return c["state"] == Camps.State.CLEARED)
	ok(cl.size() >= 2, "cleared camps to bring back (%d)" % cl.size())
	if cl.size() < 2:
		return
	var c: Dictionary = cl[0]
	var s0 := int(c["size"])
	var c2: Dictionary = cl[1]
	var c2_back := float(c2["back_t"])
	for o in cl.slice(1):
		o["back_t"] = 1e9  # one camp at a time
	for h in m.hunters:
		h.pos = Vector3(-1e4, 0, -1e4)
	m.time = float(c["back_t"]) - 5.0
	_tick(camps)
	ok(c["state"] == Camps.State.CLEARED, "not back before 150 s")
	m.time = float(c["back_t"]) + 1.0
	m.player.pos = (c["pos"] as Vector3) + Vector3(10, 0, 0)
	_tick(camps)
	ok(c["state"] == Camps.State.CLEARED, "not back with a Hunter within 30 m")
	m.player.pos = Vector3(-1e4, 0, -1e4)
	var len0 := m.length
	m.length = m.time + 30.0
	_tick(camps)
	ok(
		c["state"] == Camps.State.CLEARED and not camps.safe_for(c["pos"], 60.0),
		"not back where the Blight will be within 60 s"
	)
	m.length = len0
	_tick(camps)
	var want := mini(s0 + 1, Camps.rules()["sizes"].size() - 1)
	ok(
		(
			c["state"] == Camps.State.RETURNING
			and int(c["size"]) == want
			and _camp_mobs(c).size() == int(Camps.size_def(want)["n"])
		),
		"back once at 150 s, one size up (%s)" % Camps.size_def(want)["id"]
	)
	ok(camps.comebacks == 1, "one comeback counted")
	var r := _kill_camp(m, c, m.player)
	ok(c["state"] == Camps.State.SPENT and r["got"].size() == 1, "clearing it again pays and leaves it SPENT")
	m.time += 1000.0
	_tick(camps)
	ok(c["state"] == Camps.State.SPENT and _camp_mobs(c).is_empty(), "a spent camp never comes back")
	c2["back_t"] = c2_back
	m.time = maxf(c2_back, float(Camps.rules()["back_until_s"])) + 1.0
	_tick(camps)
	ok(c2["state"] == Camps.State.SPENT, "no comeback after 7:00")


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
			if hot:
				checked += 1
		m.queue_free()
	ok(good and checked > 0, "hot-zone camps are one size up, the rest at their kind's size (%d hot)" % checked)
