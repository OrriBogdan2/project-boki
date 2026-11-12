extends RefCounted
## --blight-nest-check: Blight nests (scripts/match/blight_nests.gd, docs/decisions/0061). Nests stand
## at fixed spots the seed picks (the same every time), clear of camps and lairs; no Skitter ever
## appears outside a nest, however loud the squad or long the match; a nest pulses warn_s before
## its Skitters climb out, releases its stock and no more, then stays empty for its cooldown;
## breaking one pays gems, XP and the feed line; a Warden's shriek wakes nests but makes nothing;
## idle Skitters burrow home; a bot fights its way through without getting stuck; the "nest" event
## and the nest's snapshot reach clients; boss egg sacs cycle their adds. Never touches the save.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("NESTS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _match(main: Node, seed_v: int, extra := {}) -> Match:
	var m := Match.new()
	main.add_child(m)
	var o := {"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": seed_v, "no_drop": true, "raid": "clear"}
	o.merge(extra, true)
	m.start(o)
	m.set_process(false)
	return m


func _run(m: Match, secs: float, each := Callable()) -> void:
	for i in int(secs / Match.DT):
		if each.is_valid():
			each.call()
		m.step(Match.DT)


## Everyone stands still and can't die; camp monsters and Wardens go, nests stay.
func _calm(m: Match) -> void:
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.max_hp = 5000.0
		h.hp = 5000.0
		h.teleport(m.world.spawns[0])
	for mb in m.mobs:
		if mb is Blight and mb.mkind == "bl_nest":
			continue
		if mb is Blight:
			(mb as Blight).burrow()
		else:
			mb.dead = true
			mb.visible = false


## A spot `d` from the nest, on open ground in its sight.
func _beside(m: Match, n: Dictionary, d: float) -> Vector3:
	var p: Vector3 = n["pos"]
	for k in 16:
		var a := TAU * k / 16.0
		var q := m.world.free_spot_near(p + Vector3(cos(a), 0, sin(a)) * d, [p], 1.0, 0.45, 1.5)
		if absf(q.y - p.y) < 1.0 and m.world.los(p, q, p.y + 0.7) and Vector2(q.x - p.x, q.z - p.z).length() > d - 1.6:
			return q
	return Vector3.INF


func _skitters(m: Match) -> Array:
	return m.mobs.filter(func(x): return x is Blight and not x.dead and x.mkind == "bl_skitter")


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	# a frame between parts frees the last part's match (queue_free), so memory stays flat
	for part in [_placement, _none_outside, _cycle, _shriek_and_home, _bots, _net_and_boss]:
		part.call(main)
		await main.get_tree().process_frame
	print("NESTS DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)


# ------------------------------------------------------------------ 1. where they stand
func _placement(main: Node) -> void:
	var m := _match(main, 8101)
	var nst: BlightNests = m.blight.nests
	var w := m.world
	var spots: Array = nst.list.map(func(n): return n["pos"])
	print(
		(
			"NESTS %d nests on %d islands: stock %s, cooldown %.0fs, warn %.1fs"
			% [
				nst.list.size(),
				w.islands.size(),
				str(nst.list.map(func(n): return n["full"])),
				nst.rule("cooldown_s"),
				nst.rule("warn_s")
			]
		)
	)
	ok(nst.list.size() >= w.islands.size(), "every island has a nest (%d)" % nst.list.size())
	ok(nst.list.all(_standing), "each nest stands as a body at its spot")
	ok(nst.list.all(func(n): return int(n["full"]) >= 6 and int(n["full"]) <= 8), "each holds 6-8 Skitters")
	ok(_skitters(m).is_empty(), "no Skitters at the start")
	var clash := 0
	for p in spots:
		for c in w.camp_spots:
			if Vector2(p.x - c["pos"].x, p.z - c["pos"].z).length() < 8.5:
				clash += 1
		if m.lairs and not m.lairs.lair_of(p, 5.0).is_empty():
			clash += 1
	ok(clash == 0, "nests stand clear of camps and lairs")
	m.queue_free()
	var m2 := _match(main, 8101)
	var same: bool = m2.blight.nests.list.size() == spots.size()
	for i in mini(spots.size(), m2.blight.nests.list.size()):
		same = same and (m2.blight.nests.list[i]["pos"] as Vector3).distance_to(spots[i]) < 0.01
	ok(same, "the same seed puts them in the same spots (every client places them alike)")
	m2.queue_free()
	var m3 := _match(main, 8102)
	var moved := false
	for i in mini(spots.size(), m3.blight.nests.list.size()):
		moved = moved or (m3.blight.nests.list[i]["pos"] as Vector3).distance_to(spots[i]) > 1.0
	ok(moved, "another seed moves them")
	m3.queue_free()


# ------------------------------------------------------------------ 2. nothing from nowhere
## A long match with bots playing: every Skitter that ever appears climbed out of a nest, next to it.
func _none_outside(main: Node) -> void:
	var m := _match(main, 8103, {"heart": true})
	var bl: BlightDir = m.blight
	for h in m.hunters:
		h.ctrl = "bot"
	m.player.ctrl = "bot"
	var seen := {}
	var c := {"stray": 0, "far": 0.0}  # (lambdas capture locals by value: count in a dictionary)
	var watch := func():
		for x in m.mobs:
			if x is Blight and x.mkind == "bl_skitter" and not seen.has(x.nid):
				var n: Dictionary = bl.nests.nest_of(x)
				var d: float = x.flat_dist(n["pos"]) if not n.is_empty() else 999.0
				seen[x.nid] = d
				c["far"] = maxf(float(c["far"]), d)
				if d > 2.5:
					c["stray"] = int(c["stray"]) + 1
	# loud far from every nest as well: shots and blasts in the open draw nothing out of the ground
	for team in bl.land_at.keys():
		bl.land_at[team] = m.time - 200.0
	_run(
		m,
		150.0,
		func():
			watch.call()
			if int(m.time * 60.0) % 45 == 0 and m.player and not m.player.out:
				m.note_sound(m.player, m.player.pos, "boom")
	)
	var stray: int = c["stray"]
	var total := seen.size()
	var far_nest: float = c["far"]
	print(
		(
			(
				"NESTS 150 s of bots: %d Skitters appeared, all from nests"
				+ " (%d strays, farthest %.1f m from its nest), %d released"
			)
			% [total, stray, far_nest, bl.nests.released]
		)
	)
	ok(stray == 0, "no Skitter appears outside a nest")
	ok(
		total > 0 and total <= bl.nests.released,
		"every Skitter seen is one a nest released (%d of %d)" % [total, bl.nests.released]
	)
	var held := 0
	for n in bl.nests.list:
		held += int(n["full"])
	ok(
		bl.nests.released <= held + 2 * bl.nests.list.size(),
		"no more come out than the nests hold (%d of %d)" % [bl.nests.released, held]
	)
	m.queue_free()


# ------------------------------------------------------------------ 3. telegraph, release, empty, cooldown, break
func _cycle(main: Node) -> void:
	var m := _match(main, 8104)
	var nst: BlightNests = m.blight.nests
	_calm(m)
	var pl := m.player
	var n: Dictionary = {}
	var stand := Vector3.INF
	for c in nst.list:
		stand = _beside(m, c, nst.rule("wake_r") - 2.0)
		if stand != Vector3.INF:
			n = c
			break
	ok(not n.is_empty(), "found a nest with open ground round it")
	if n.is_empty():
		m.queue_free()
		return
	var nest: Blight = n["mob"]
	var full := int(n["full"])
	var sk0 := _skitters(m).size()
	pl.teleport(stand)
	_run(m, 0.3)
	ok(n["stir_at"] != INF, "walking up to a nest stirs it")
	_run(m, nst.rule("warn_s") - 0.6)
	ok(
		_skitters(m).size() == sk0 and nest.spot > 0.5,
		"it pulses for warn_s first, nothing out yet (spot %.2f)" % nest.spot
	)
	_run(m, 0.6)
	var out := _skitters(m).size() - sk0
	var want := mini(full, int(nst.rule("area_cap")))
	print(
		(
			"NESTS woke: %d of %d climbed out after %.1fs warning (area cap %d)"
			% [out, full, nst.rule("warn_s"), int(nst.rule("area_cap"))]
		)
	)
	ok(
		out > 0 and out <= want,
		"then it releases its stock, within the area cap and the Blight cap %d (%d)" % [m.blight.cap(), out]
	)
	# kill them all (and whatever the rest of the stock brings) while standing there
	var killed := 0
	var t := 0.0
	while t < 20.0 and (int(n["stock"]) > 0 or not _skitters(m).is_empty()):
		for s in _skitters(m):
			s.hurt(9999.0, pl, {})
			killed += 1
		m.step(Match.DT)
		t += Match.DT
	ok(int(n["stock"]) == 0 and nst.cooling(n), "%d killed, the nest is empty and cooling" % killed)
	ok(killed == full, "it gave exactly what it held (%d of %d)" % [killed, full])
	var left := nst.refill_left(n)
	ok(absf(left - nst.rule("cooldown_s")) < 25.0, "it stays empty for its cooldown (%.0fs left)" % left)
	# still standing right by it: nothing comes, through most of the cooldown
	var sk1 := nst.released
	_run(m, 3.0)
	m.time += left - 8.0
	_run(m, 3.0, func(): pl.teleport(stand))
	ok(nst.released == sk1 and _skitters(m).is_empty(), "standing by an empty nest for %.0fs: quiet" % (left - 2.0))
	# break it: gems, XP to the squad close by, the feed line
	var gems0 := m.pickups.filter(func(p): return p["kind"] == "gem").size()
	pl.lvl = 1  # (the 9999-damage kills above maxed the level; gain_xp stops at the top)
	pl.xp = 0.0
	var xp0 := pl.xp
	nest.hurt(nest.hp + 1.0, pl, {})
	m.step(Match.DT)
	var gems1 := m.pickups.filter(func(p): return p["kind"] == "gem").size()
	print(
		(
			"NESTS broke a nest: +%d gem piles (%d gems), +%.0f XP, refill in %.0fs"
			% [gems1 - gems0, int(Data.MOBS["bl_nest"]["gems"]), pl.xp - xp0, nst.refill_left(n)]
		)
	)
	ok(nest.dead and gems1 > gems0, "breaking a nest drops its gems")
	ok(pl.xp - xp0 >= nst.rule("pop_xp") - 0.01, "and pays XP (%.0f)" % (pl.xp - xp0))
	ok(not GearDrops.table("bl_nest").is_empty(), "and rolls a gear table (gear.json bl_nest)")
	# the cooldown runs out: it grows back full, and walking up wakes it again
	m.time += nst.refill_left(n) + 0.5
	_run(m, 0.5, func(): pl.teleport(Vector3(stand.x + 60.0, stand.y, stand.z)))
	ok(
		not nst.cooling(n) and int(n["stock"]) == full and n["mob"] is Blight and not n["mob"].dead,
		"after the cooldown it grows back, full"
	)
	m.queue_free()


# ------------------------------------------------------------------ 4. shrieks wake, burrowers go home
func _shriek_and_home(main: Node) -> void:
	var m := _match(main, 8105)
	var bl: BlightDir = m.blight
	var nst := bl.nests
	_calm(m)
	var pl := m.player
	var n: Dictionary = nst.list[0]
	var full := int(n["full"])
	var wspot := _beside(m, n, 10.0)
	if wspot == Vector3.INF:
		wspot = m.world.free_spot_near(n["pos"] + Vector3(10, 0, 0), [], 1.0, 0.8, 6.0)
	var wd := bl.spawn("bl_warden", wspot, 1.0)
	var sk0 := _skitters(m).size()
	bl.on_shriek(wd, pl)
	ok(_skitters(m).size() == sk0, "a shriek makes no Skitters of its own")
	ok(n["stir_at"] != INF, "but a nest %.0f m away stirs" % wd.flat_dist(n["pos"]))
	_run(m, nst.rule("warn_s") + 0.4)
	var out := _skitters(m).size() - sk0
	ok(
		out > 0 and out <= mini(full, int(nst.rule("area_cap"))),
		"and gives up what it holds, within the caps (%d)" % out
	)
	# send them home: idle, far from everyone
	var s: Blight = _skitters(m)[0]
	var st0 := int(n["stock"])
	for h in m.hunters:
		h.teleport(m.world.spawns[-1])
	if pl.flat_dist(s) > 32.0:
		s.st = "idle"
		s.tgt = null
		s.heard = Vector3.INF
		s.idle_t = 25.0
		bl._despawn_tick()
		ok(
			s.gone and int(n["stock"]) == (st0 + 1 if not nst.cooling(n) else st0),
			"an idle Skitter far from everyone burrows home (stock %d -> %d)" % [st0, int(n["stock"])]
		)
	else:
		ok(true, "(burrow home: spots too close on this map, skipped)")
	# a second shriek after it's empty: nothing
	for x in _skitters(m):
		x.hurt(9999.0, pl, {})
	n["stock"] = 0
	n["refill_at"] = m.time + 100.0
	var mine := func(): return _skitters(m).filter(func(x): return int(x.get_meta("nest", -1)) == 0).size()
	wd.shriek_cd = 0.0
	bl.on_shriek(wd, pl)
	_run(m, nst.rule("warn_s") + 0.4)
	ok(mine.call() == 0 and n["stir_at"] == INF, "a shriek at an empty nest brings nothing from it")
	m.queue_free()


# ------------------------------------------------------------------ 5. bots
func _bots(main: Node) -> void:
	var m := _match(main, 8106)
	var nst := m.blight.nests
	_calm(m)
	var bot: Hunter = null
	for o in m.hunters:
		if o != m.player and o.team != m.player.team:
			bot = o
			break
	var n: Dictionary = {}
	var stand := Vector3.INF
	for c in nst.list:
		stand = _beside(m, c, 5.0)
		if stand != Vector3.INF:
			n = c
			break
	if bot == null or n.is_empty():
		ok(false, "found a bot and a nest")
		m.queue_free()
		return
	bot.ctrl = "bot"
	bot.max_hp = 400.0
	bot.hp = 400.0
	bot.teleport(stand)
	m.player.teleport(m.world.spawns[-1])
	var path := 0.0
	var last := bot.pos
	var killed := 0
	var ids := {}
	var t := 0.0
	while t < 40.0:
		m.step(Match.DT)
		t += Match.DT
		path += Vector2(bot.pos.x - last.x, bot.pos.z - last.z).length()
		last = bot.pos
		for x in m.mobs:
			if x is Blight and x.mkind == "bl_skitter" and x.dead and not x.gone and not ids.has(x.nid):
				ids[x.nid] = true
				killed += 1
	var nest_dead: bool = n["mob"] == null or n["mob"].dead
	print(
		(
			"NESTS a bot beside a nest: %.0fs, %d Skitters killed, nest broken %s, moved %.0f m, downed %s"
			% [t, killed, nest_dead, path, bot.downed]
		)
	)
	ok(nst.released > 0 or nest_dead, "a bot walking up wakes the nest or breaks it first")
	ok(killed > 0 or nest_dead, "the bot fights what comes out")
	ok(path > 8.0, "and keeps moving (no stuck loop)")
	m.queue_free()


# ------------------------------------------------------------------ 6. clients, boss adds
func _net_and_boss(main: Node) -> void:
	var m := _match(main, 8107)
	var nst := m.blight.nests
	var n: Dictionary = nst.list[0]
	var nest: Blight = n["mob"]
	nest.spot = 0.6
	nest.cone_a = 0.5
	var it: Array = m._ser(nest)
	var it2 := it.duplicate()
	it2[1] = "mnest1"
	var made: Ent = m._net_make(it2)
	if made:
		m._net_apply(made, it2)
	ok(
		(
			made is Blight
			and (made as Blight).mkind == "bl_nest"
			and absf((made as Blight).spot - 0.6) < 0.01
			and absf((made as Blight).cone_a - 0.5) < 0.01
		),
		"a client builds the nest from its snapshot, pulse and stock share"
	)
	nst.net(["nest", 0, 0, 120.0, 0])
	ok(
		nst.cooling(n) and absf(nst.refill_left(n) - 120.0) < 0.5 and int(n["stock"]) == 0,
		"the nest event carries its stock and refill clock"
	)
	nst.net(["nest", 0, 5, -1.0, 1])
	ok(not nst.cooling(n) and n["stir_at"] != INF and int(n["stock"]) == 5, "... and that it is stirring")
	ok(MapDetail.DETAIL.has("nest"), "nests have a minimap kind")
	m.queue_free()
	var src := FileAccess.get_file_as_string("res://scripts/match/boss.gd")
	var brood := src.substr(src.find("func _atk_brood"), 1600)
	ok(
		brood.find("randi()") < 0 and brood.find("randf()") < 0 and Boss.BROOD_ADDS.size() == 4,
		"boss egg sacs cycle their adds in a fixed order (no dice)"
	)


func _standing(n: Dictionary) -> bool:
	var b = n["mob"]
	return b is Blight and not b.dead and b.flat_dist(n["pos"]) < 0.5
