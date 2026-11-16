extends RefCounted
## --shrink-zone-check: the closing zone (scripts/match/shrink_zone.gd). On the Hollow Crown each
## seed gives 3-5 closes, each circle inside the one before and smaller, all done before the clock
## runs out, round a final area with an exit in it; the same seed gives the same zone and seeds vary;
## outside hurts (more each close, through armor), inside doesn't; the islands outside the last circle
## fall; the zone is heard (ZoneSfx); bots come in and stay in. Never touches the save.

const SEEDS := [3, 5, 9, 12, 21, 33, 47, 58]
const DT := 1.0 / 60.0

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("SHRINKZONE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _match(main: Node, seed_v: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 6, "squad": 3, "tier": 0, "seed": seed_v, "no_drop": true, "sim_keep": true})
	m.set_process(false)
	return m


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_shape(main)
	_hurt(main)
	_audio(main)
	_bots(main)
	print("SHRINKZONE DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)


## Phases close in, nest, finish in time, end on an exit; same seed same zone.
func _shape(main: Node) -> void:
	var finals := {}
	var picks := 0
	for s in SEEDS:
		var m := _match(main, s)
		var z := m.zone
		ok(z != null, "seed %d: the expedition has a closing zone" % s)
		if z == null:
			m.free()
			continue
		var n := z.last()
		ok(n >= 3 and n <= 5, "seed %d: %d closes" % [s, n])
		for j in range(1, n + 1):
			var nested := z.cs[j - 1].distance_to(z.cs[j]) + z.rs[j] <= z.rs[j - 1] + 0.01
			ok(z.rs[j] < z.rs[j - 1] and nested, "seed %d: circle %d (r %.0f) nests" % [s, j, z.rs[j]])
			var timed := z.t0[j] < z.t1[j] and (j == 1 or z.t0[j] > z.t1[j - 1])
			var what := [s, j, z.t0[j], z.t1[j], z.dps[j] * 100.0]
			ok(timed and z.dps[j] > z.dps[j - 1], "seed %d: close %d at %.0f-%.0f s, %.0f%%/s outside" % what)
		ok(z.t1[n] < m.length - 30.0, "seed %d: closes end at %.0f s (fall %.0f s)" % [s, z.t1[n], m.length])
		var holds := _in_final(z, Vector3(z.exit_at.x, 0, z.exit_at.y))
		ok(holds, "seed %d: the final area (%s) holds its exit" % [s, z.area_name])
		var all_in := true
		var e0 := z.edge_at(0.0)
		for p in [Vector2.ZERO, Vector2(m.world.w, m.world.h), Vector2(0, m.world.h), Vector2(m.world.w, 0)]:
			all_in = all_in and (e0[0] as Vector2).distance_to(p) < float(e0[1])
		ok(all_in, "seed %d: the first circle covers the whole map" % s)
		var again := ShrinkZone.new(m)
		ok(again.cs == z.cs and again.rs == z.rs and again.t0 == z.t0, "seed %d: the same seed gives the same zone" % s)
		finals[z.exit_at] = true
		var open_in := m.exits.of_kind("outpost").any(func(x): return _in_final(z, x["pos"]))
		ok(open_in, "seed %d: an exit that stays open is in the final area" % s)
		picks = m.exits.of_kind("outpost").size()
		m.free()
	# the 0.24.5 Hollow Crown has two outposts and no docks: the seeds must reach every one (3 when there are more)
	var want := mini(3, picks)
	ok(finals.size() >= want, "the final area varies between matches (%d exits of %d)" % [finals.size(), picks])


## Outside hurts (by the close's share, through armor), inside doesn't; the outer islands fall.
func _hurt(main: Node) -> void:
	var m := _match(main, 5)
	var z := m.zone
	var bots := m.hunters.filter(func(h): return h.ctrl == "bot")
	var a: Hunter = bots[0]
	var b: Hunter = bots[1]
	m.time = z.t1[2] + 1.0
	z.tick(DT)
	var c := z.cur_c
	var out_p := Vector3.INF
	for i in 400:
		var p := m.world.random_ground()
		if Vector2(p.x, p.z).distance_to(c) > z.cur_r + 10.0:
			out_p = p
			break
	a.pos = out_p
	b.pos = m.world.free_spot_near(Vector3(c.x, 0, c.y), [], 1.0, 0.45, 20.0)
	var pool := func(h: Hunter) -> float: return h.hp + h.shield + h.kin_shield
	var a0: float = pool.call(a)
	var b0: float = pool.call(b)
	var armor0 := a.armor
	for i in 180:
		m.time += DT
		z.tick(DT)
	var want := z.dps[2] * a.max_hp * 3.0
	var lost: float = a0 - pool.call(a)
	ok(lost > want * 0.6 and lost < want * 1.3, "outside after close 2: lost %.0f in 3 s (about %.0f)" % [lost, want])
	ok(is_equal_approx(a.armor, armor0), "outside damage goes through armor")
	ok(is_equal_approx(pool.call(b), b0), "inside: no damage")
	# the last close ends: whoever is on an island with no ground in the final circle falls
	var gone_p := Vector3.INF
	for ii in m.world.islands.size():
		var I: Dictionary = m.world.islands[ii]
		var cen := Vector2(I["c"])
		if cen.distance_to(z.cs[z.last()]) - float(I["r"]) * 1.6 > z.rs[z.last()]:
			gone_p = m.world.free_spot_near(Vector3(cen.x, 0, cen.y), [], 1.0, 0.45, 12.0)
			break
	b.pos = gone_p
	b.hp = b.max_hp
	m.time = z.t1[z.last()] + 0.05
	z.tick(DT)
	ok(z.fallen and b.out, "the last close: a hunter on an island outside the final circle falls")
	m.free()


## ZoneSfx. Standing well inside through every close: one warning each, at warn_s before it, and no other cue (no
## countdown: the Ways Out ticks stay the only one). The hum sits on the wall's nearest point, louder 12 m from it
## than 50 m, as loud just outside as just inside. Crossing out and back in sound once each; standing on the edge
## doesn't. The zone's damage plays its tick and no hurt voice; a hit taken plays the hurt voice and no tick.
## The zone's words in the feed name no squad (solos).
func _audio(main: Node) -> void:
	var m := _match(main, 12)
	var z := m.zone
	var a := z.audio
	var p := m.player
	var fc := z.cs[z.last()]
	p.pos = m.world.free_spot_near(Vector3(fc.x, 0, fc.y), [], 1.0, 0.45, 12.0)
	var warned: Array = []
	while m.time < z.t1[z.last()] + 2.0:
		m.time += 0.25
		Sfx.listener = p.pos
		var n := a.cues.size()
		z.tick(0.25)
		if a.cues.size() > n:
			warned.append(m.time)
	var on_time := warned.size() == z.last()
	for j in range(1, mini(warned.size(), z.last()) + 1):
		on_time = on_time and absf(float(warned[j - 1]) - (z.t0[j] - float(ShrinkZone.rules()["warn_s"]))) <= 0.26
	ok(on_time and a.cues.count("warn") == z.last(), "one warning before each of %d closes, warn_s ahead" % z.last())
	ok(a.cues.size() == z.last(), "inside the whole match: no other zone cue (%s)" % [a.cues])
	var said := m.feed_all.filter(func(t): return "zone" in t.to_lower())
	var squad_words := said.filter(func(t): return "squad" in t.to_lower() or "team" in t.to_lower())
	ok(not said.is_empty() and squad_words.is_empty(), "the zone's feed lines name no squad (%d lines)" % said.size())
	m.time = z.t1[2] + 1.0
	z.tick(DT)
	var dir := (Vector2(p.pos.x, p.pos.z) - z.cur_c).normalized()
	var put := func(past: float) -> void:
		var q := z.cur_c + dir * (z.cur_r + past)
		p.pos = Vector3(q.x, p.pos.y, q.y)
		Sfx.listener = p.pos
		z.tick(DT)
	var hum := func() -> float: return float((Sfx.loops[ZoneSfx.HUM_KEY]["p"] as AudioStreamPlayer).volume_db)
	put.call(-12.0)
	var at: Vector3 = Sfx.loops[ZoneSfx.HUM_KEY]["pos"] if Sfx.loop_on(ZoneSfx.HUM_KEY) else Vector3.INF
	var on_wall := absf(Vector2(at.x, at.z).distance_to(z.cur_c) - z.cur_r) < 0.5
	ok(on_wall and absf(p.pos.distance_to(at) - 12.0) < 0.5, "the hum sits on the wall's nearest point")
	var near: float = hum.call()
	put.call(-50.0)
	var far: float = hum.call()
	put.call(12.0)
	var out_db: float = hum.call()
	ok(near > far + 3.0, "the hum grows near the wall: %.1f dB at 12 m, %.1f dB at 50 m" % [near, far])
	ok(absf(out_db - near) < 1.0, "the hum as loud 12 m outside (%.1f dB) as 12 m inside" % out_db)
	put.call(-12.0)
	a.cues.clear()
	for past in [-0.3, 0.3, 2.0, 0.3, -0.3, 0.3, -2.0, -0.3]:
		put.call(past)
	ok(a.cues == ["out", "in"], "crossing out then in: one cue each, none on the edge (%s)" % [a.cues])
	var hurt := HeroSfx.of(p, "hurt", "hurt")
	put.call(10.0)
	a.cues.clear()
	Sfx.last_played.erase(hurt)
	var hp0 := p.hp + p.shield + p.kin_shield
	for i in 180:
		m.time += DT
		z.tick(DT)
	var ticks := a.cues.count("tick")
	var hurt_out := p.hp + p.shield + p.kin_shield < hp0
	ok(ticks >= 2 and ticks <= 3 and hurt_out, "outside 3 s: %d zone ticks as the damage lands" % ticks)
	ok(not Sfx.last_played.has(hurt), "the zone's damage plays no hurt voice (%s)" % hurt)
	var rival: Hunter = m.hunters.filter(func(h): return h.team != p.team)[0]
	a.cues.clear()
	p.hurt(20.0, rival, {})
	ok(Sfx.last_played.has(hurt) and a.cues.is_empty(), "a hit taken plays the hurt voice and no zone tick")
	m.free()


## Bots come into the circle and stay in: from just after close 2 to just after close 3.
func _bots(main: Node) -> void:
	var m := _match(main, 9)
	var z := m.zone
	Game.god = true  # (the local player stands idle: keep the match going)
	m.time = z.t1[2]
	z.tick(DT)
	# five minutes in, the squads are inside close 2's circle: put each bot somewhere in it
	for h in m.hunters:
		if h.ctrl != "bot":
			continue
		for i in 400:
			var p := m.world.random_ground()
			if Vector2(p.x, p.z).distance_to(z.cur_c) < z.cur_r - 4.0:
				h.pos = p
				break
	var lost := {}  # bots knocked out since (a revive brings them back somewhere else: not counted)
	var start := _share_in(m, z.cs[3], z.rs[3], lost)
	var at_closed := -1.0
	var inside := 0.0
	var samples := 0
	var steps := 0
	while m.time < z.t1[3] + 12.0:
		m.step(DT)
		steps += 1
		for h in m.hunters:
			if h.out or h.downed:
				lost[h] = true
		if at_closed < 0.0 and m.time >= z.t1[3]:
			at_closed = _share_in(m, z.cs[3], z.rs[3], lost)
		if m.time > z.t0[3] and steps % 30 == 0:
			inside += _share_in(m, z.cur_c, z.cur_r, lost)
			samples += 1
	inside /= maxf(1.0, float(samples))
	Game.god = false
	var shares := [int(start * 100.0), int(at_closed * 100.0)]
	ok(at_closed >= 0.7 and at_closed > start, "bots come in: %d%% inside circle 3, %d%% once it's closed" % shares)
	ok(inside >= 0.8, "bots keep inside the moving edge (%d%% of the time)" % int(inside * 100.0))
	m.free()


func _in_final(z: ShrinkZone, p: Vector3) -> bool:
	return z.cs[z.last()].distance_to(Vector2(p.x, p.z)) <= z.rs[z.last()]


func _share_in(m: Match, c: Vector2, r: float, lost: Dictionary) -> float:
	var n := 0
	var inn := 0
	for h in m.hunters:
		if h.ctrl != "bot" or h.out or h.extracted or h.downed or lost.has(h):
			continue
		n += 1
		inn += 1 if Vector2(h.pos.x, h.pos.z).distance_to(c) <= r else 0
	return float(inn) / maxf(1.0, float(n))
