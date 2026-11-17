extends RefCounted
## --shot-vertical-check: shooting from a ledge. A hunter on a terrace 1-2 blocks above a dummy, with
## the reticle on it (aim_y = the dummy's height, as Match._mouse_aim sets it), lands a real basic
## attack at close and long range; a dummy 4m+ below (past the aim limit) is not hit, bent or level.
## Also level shots (the aim missed the foe) from 1-2 terraces up. Builds its own ledge in the world's tiles. Never touches the save.

var bad := 0
const STRIP := 12          # tiles of flat ground needed along x
const LEDGE_TILES := 3     # the shooter's side: these first tiles are raised

func ok(cond: bool, what: String) -> void:
	print("SHOTV %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## A flat, open strip STRIP x 3 tiles long along +x.
func _strip(w: World) -> Vector3i:
	for k in 6000:
		var g := w.random_ground()
		var tx := int(floor(g.x)); var tz := int(floor(g.z))
		var good := true
		for dx in STRIP:
			for dz in [-1, 0, 1]:
				var x: int = tx + dx; var z: int = tz + dz
				if not w.inb(x, z) or w.is_void(x + 0.5, z + 0.5) or w.is_block(x + 0.5, z + 0.5) or absf(w.ground_at(x + 0.5, z + 0.5) - g.y) > 0.05 or w.stairs.has(w.idx(x, z)):
					good = false
		if good: return Vector3i(tx, int(round(g.y / World.LEVEL)), tz)
	return Vector3i(-1, 0, 0)

func _raise(w: World, s: Vector3i, up: int) -> void:
	for dx in STRIP:
		for dz in [-1, 0, 1]:
			w.level[w.idx(s.x + dx, s.z + dz)] = s.y + (up if dx < LEDGE_TILES else 0)

## Fires one basic attack from `P` at `T` (reticle on it) and returns whether T took damage.
func _shoot(m: Match, P: Hunter, T: Hunter, bend := true) -> bool:
	T.hp = T.max_hp
	P.ammo = 99; P.fire_cd = 0.0; P.warm_t = 0.0
	P.inp["aim"] = Vector3(T.pos.x, P.pos.y + 0.95, T.pos.z)
	P.inp["aim_y"] = T.pos.y if bend else P.pos.y        # (not bent: a level shot, the aim missed the foe)
	var hp0 := T.hp
	P.fire()
	for i in 90:
		P.pos = P.pos if i > 0 else P.pos
		m.step(Match.DT)
		T.vel = Vector3.ZERO
		if T.hp < hp0: break
		if m.shots.is_empty(): break
	m.shots.clear()
	return T.hp < hp0

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for b in m.breaks: b["dead"] = true
	var P: Hunter = m.hunters[0]
	var T: Hunter = null
	for o in m.hunters:
		o.ctrl = "idle"
		if o != P and o.team != P.team and T == null: T = o
	for h in [P, T]:
		for kk in [h.kin, h.kin2]:
			if kk: m.kins.erase(kk); kk.queue_free()
		h.kin = null; h.kin2 = null
	for o in m.hunters:
		if o != P and o != T: o.teleport(m.world.random_ground())
	var w: World = m.world
	var s := _strip(w)
	ok(s.x >= 0, "found a flat strip")
	if s.x < 0:
		print("SHOTV DONE, failures: ", bad); main.get_tree().quit(); return
	var weapons := ["smg", "rifle", "burst_rifle"]
	for up in [1, 2, 3]:
		_raise(w, s, up)
		for dist in [2.5, 4.0, 7.0]:
			for wid in weapons:
				for h in [P, T]: h.equip(wid)
				var gy := float(s.y + up) * World.LEVEL
				var ly := float(s.y) * World.LEVEL
				var px := float(s.x) + 1.5
				var pz := float(s.z) + 0.5
				P.teleport(Vector3(px, gy, pz)); P.vel = Vector3.ZERO
				T.teleport(Vector3(px + dist, ly, pz)); T.vel = Vector3.ZERO
				T.phase_t = 0.0; T.downed = false; T.armor = 0.0
				ok(_shoot(m, P, T), "%s from %.1fm above, %.1fm away: hit" % [wid, gy - ly, dist])
				if up <= 2:
					ok(_shoot(m, P, T, false), "%s from %.1fm above, %.1fm away, level shot: hit" % [wid, gy - ly, dist])
	# a dummy 4m+ below the shooter, at the foot of the drop: a level shot sails over, no hit
	_raise(w, s, 6)
	for dist in [3.0, 6.0]:
		for h in [P, T]: h.equip("smg")
		var gy2 := float(s.y + 6) * World.LEVEL
		var px2 := float(s.x) + 1.5
		var pz2 := float(s.z) + 0.5
		P.teleport(Vector3(px2, gy2, pz2)); P.vel = Vector3.ZERO
		T.teleport(Vector3(px2 + dist, float(s.y) * World.LEVEL, pz2)); T.vel = Vector3.ZERO
		T.phase_t = 0.0; T.downed = false
		ok(not _shoot(m, P, T), "dummy %.1fm below at %.1fm: not hit" % [gy2 - float(s.y) * World.LEVEL, dist])
		ok(not _shoot(m, P, T, false), "dummy %.1fm below at %.1fm, level shot: not hit" % [gy2 - float(s.y) * World.LEVEL, dist])
	print("SHOTV DONE, failures: ", bad)
	main.get_tree().quit()
