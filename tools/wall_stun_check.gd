extends "res://tools/archetype_check.gd"
## --wall-stun-check: a foe knocked into each kind of surface, for every source that stuns on a wall hit
## (Lace's Heavy Shot, Albert's Crush, Burr's cone, Tenzo's punch, Joule's Storm Rod, and a plain knock's
## slam). Which surfaces stun is settled in docs/KNOCK_WALLS.md; every source goes through KnockWall.
## Prints AKCHECK lines: stun, damage and the frame the stun starts on (counted from the first damage).

const SURFACES := ["cliff", "tier step", "rock", "rimewall", "crate", "breakable", "hunter"]
const SOURCES := ["archer", "bulwark", "gunslinger", "dolm", "mage", "knock"]
## Settled: a tall wall of any kind stuns; ground a body walks up, soft props and decks do not. Another
## Hunter stuns only for the Storm Rod (the source says "wall or another target" for the spear alone).
const WALLS := ["cliff", "rock", "rimewall"]
const GAP := 2            # tiles between the foe's tile and the surface
const FRAMES := 90

func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("wall_stun_check", self)
	for src in SOURCES:
		await _source(src)
	await _monsters()
	await _train()
	_pool()
	print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _expect(src: String, surface: String) -> bool:
	return surface in WALLS or (surface == "hunter" and src == "mage")

func _source(src: String) -> void:
	var r := setup(src if src != "knock" else "thief", 3.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var spot := T.pos
	for s in SURFACES:
		fresh(T)
		T.teleport(spot)
		T.vel = Vector3.ZERO
		P.teleport(home)      # (a punch steps forward)
		P.vel = Vector3.ZERO
		T2.teleport(home + Vector3(0, 0, 8.0))
		var undo := _build(m, T, T2, s, spot, lv)
		var wi: WallImpact = m.fx.wall_impact
		var decals0 := wi.placed
		var rec := _knock(src, m, P, T)
		undo.call()
		var want := _expect(src, s)
		var info := "stun %.2f dmg %.0f frame %d" % [rec["stun"], rec["dmg"], rec["frame"]]
		ok("wall %s > %s" % [src, s], (rec["stun"] > 0.4) == want, info)
		# one wall stun, one decal, on the wall face (a Hunter or a step is no wall: none)
		var face := float(int(floor(spot.x)) + GAP)
		var at := wi.last_at
		var placed_ok := wi.placed - decals0 == (1 if s in WALLS else 0)
		if s in WALLS and placed_ok:
			placed_ok = at.x > face - 0.3 and at.x < face + 1.0 and absf(at.z - spot.z) < 1.0
			placed_ok = placed_ok and wi.last_normal.is_equal_approx(Vector3(-1, 0, 0))
		ok("decal %s > %s" % [src, s], placed_ok, "decals %d at %s" % [wi.placed - decals0, at])
	await done(m)

## Puts `surface` GAP tiles east of the foe; returns how to take it away again.
func _build(m: Match, T: Hunter, T2: Hunter, surface: String, spot: Vector3, lv: int) -> Callable:
	var W: World = m.world
	var tx := int(floor(spot.x)) + GAP
	var tz := int(floor(spot.z))
	var at := Vector3(tx + 0.5, lv * World.LEVEL, spot.z)
	var rise := {"cliff": 3, "tier step": 1}
	if rise.has(surface):
		for dz in range(-3, 4):
			W.level[W.idx(tx, tz + dz)] = lv + int(rise[surface])
		return func():
			for dz in range(-3, 4): W.level[W.idx(tx, tz + dz)] = lv
	if surface == "rock":
		var w := HeroZones.rock(m, T, at, Vector2(1, 0), "wsc", 4.0, 30.0, 999.0, false)
		return func(): m.verbs.walls.erase(w)
	if surface == "rimewall":
		var e := {"length": 4.0, "hp": 999.0, "time": 30.0, "move": true, "block": "enemy"}
		var w: Dictionary = m.verbs.add_wall(T, at, Vector2(1, 0), e, 1.0)
		return func(): m.verbs.walls.erase(w)
	if surface == "hunter":
		T2.teleport(at)
		return func(): pass
	m._add_break("crate" if surface == "crate" else "barrel", at)
	var b: Dictionary = m.breaks[m.breaks.size() - 1]
	return func(): b["dead"] = true

## One knock of `src` at the foe (hit facing east); returns {stun, dmg, frame}.
func _knock(src: String, m: Match, P: Hunter, T: Hunter) -> Dictionary:
	var dir := Vector2(1, 0)
	aim_at(P, T.pos)
	P.dashes = P.max_dashes()
	# a kit with its own probe is measured without the body slam (Tenzo's punch hands the slam a longer stun)
	T.wslam_t = 0.0 if src in ["knock", "dolm"] else 99.0
	var K = P.ak
	match src:
		"archer":
			K.ch_rmb = 2.0
			K.cd["rmb"] = 0.0
			P.inp["sec_hold"] = true
			K.press_rmb()
			step(m, 1.2, func():
				P.inp["sec_hold"] = true
				aim_at(P, T.pos))
			P.inp["sec_hold"] = false
		"bulwark":
			K.knock_until = m.time + 0.25
			K.crushed_at = {}
			T.hurt(5.0, P, {"src": "abil", "ab": "lmb", "kb": dir * 8.0, "lift": 2.0})
		"gunslinger":
			K._cone(T.pos - Vector3(1.0, 0, 0), dir, K.rmb_def()["burr"], false)
		"dolm":
			K._punch(1.0)
		"mage":
			K._coil_hit(T, dir, 1.0)
		"knock":
			T.hurt(5.0, P, {"src": "abil", "ab": "lmb", "kb": dir * 14.0, "lift": 0.5})
	var hp0 := T.hp
	var rec := {"stun": 0.0, "dmg": 0.0, "frame": -1}
	var f0 := -1
	for i in FRAMES:
		m.step(DT)
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		if f0 < 0 and T.hp < hp0 - 0.01: f0 = i
		if rec["frame"] < 0 and T.stun_t > 0.4: rec["frame"] = i - maxi(f0, 0)
		rec["stun"] = maxf(rec["stun"], T.stun_t)
	rec["dmg"] = dmg(T)
	return rec

## A monster knocked into a cliff, a rock and a tier step (it slams like a Hunter does).
func _monsters() -> void:
	var r := setup("thief", 3.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var lv: int = r[5]
	var spot := T.pos
	var mb := m.spawn_mob("skitter", spot)
	for s in ["cliff", "tier step", "rock"]:
		mb.teleport(spot)
		mb.vel = Vector3.ZERO
		mb.stun_t = 0.0
		mb.hp = mb.max_hp
		var undo := _build(m, T, T2, s, spot, lv)
		var decals0: int = m.fx.wall_impact.placed
		mb.hurt(1.0, P, {"src": "abil", "ab": "lmb", "kb": Vector2(14.0, 0.0), "lift": 0.5})
		var stun := 0.0
		for i in FRAMES:
			m.step(DT)
			stun = maxf(stun, mb.stun_t)
		undo.call()
		ok("wall monster > %s" % s, (stun > 0.4) == (s != "tier step"), "stun %.2f" % stun)
		var made: int = m.fx.wall_impact.placed - decals0
		ok("decal monster > %s" % s, made == (0 if s == "tier step" else 1), "decals %d" % made)
	await done(m)

## The sky train: a flat car you stand on is no wall, the engine is solid.
func _train() -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "map": "skyreach"})
	m.set_process(false)
	var st: SkyTrain = m.skytrain
	ok("wall train: the map has a sky train", st != null)
	if st != null:
		var P: Hunter = m.player
		var probes := {"car": 2, "engine": 0}
		for k in probes:
			var xf: Transform3D = st.cur[int(probes[k])]
			var fwd := -xf.basis.z
			var face := Vector2(fwd.x, fwd.z).normalized()
			P.pos = xf.origin - fwd * (SkyTrain.CAR_LEN * 0.5 + 1.5)
			var hit: bool = KnockWall.behind(m, P, face, 4.0)
			ok("wall train %s" % k, hit == (k == "engine"), "behind %s" % hit)
	m.queue_free()
	await main.get_tree().process_frame

## The decals are pooled: stamping far more than the pool holds leaves no more than the pool visible, and the
## dust and decals are gone by about 0.6 s.
func _pool() -> void:
	var wi := WallImpact.new()
	main.add_child(wi)
	for i in WallImpact.POOL * 3:
		wi.stamp(Vector3(i, 1, 0), Vector3(-1, 0, 0), Color.WHITE)
	var shown := wi.get_children().filter(func(c): return (c as Node3D).visible).size()
	ok("decal pool is capped", shown == WallImpact.POOL, "%d shown of %d" % [shown, WallImpact.POOL])
	wi._process(WallImpact.LIFE + 0.01)
	shown = wi.get_children().filter(func(c): return (c as Node3D).visible).size()
	ok("decals are gone after %.1f s" % WallImpact.LIFE, shown == 0, "%d still shown" % shown)
	wi.queue_free()
