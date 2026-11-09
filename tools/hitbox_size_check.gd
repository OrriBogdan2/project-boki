extends RefCounted
## --hitbox-size-check: hitboxes follow the Warden's size, compressed (docs/HITBOX_SIZE.md). Every
## archetype's hit_r is 0.85-1.15 x the standard (the Medium class's), the ground circle under the
## hunter is drawn at exactly that radius, and shots are tested against it (a bullet just inside
## the circle hits, just outside misses) for the smallest and the biggest. Body contact (the Body
## contact table in that doc): two Hunters walking into each other pass through, a dash goes through a
## foe without moving it, and a Hunter walking into a Boki is held off and pushes it. Never touches the save.

var bad := 0
const BAND := Vector2(0.85, 1.15)

func ok(cond: bool, what: String) -> void:
	print("HBCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _flatten(m: Match, h: Hunter) -> void:
	var W: World = m.world
	var hx := int(floor(h.pos.x))
	var hz := int(floor(h.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi])
	for dz in range(-6, 7):
		for dx in range(-8, 9):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			for d in [W.stairs, W.walls, W.props, W.bush]:
				d.erase(i)

## Fires one level bullet (radius 0.1) along +x, `side` metres off h's centre; true if it hit h.
func _fire(m: Match, shooter: Hunter, h: Hunter, side: float) -> bool:
	h.hp = h.max_hp
	var y := h.pos.y + 0.95
	m.spawn_shot(shooter, Vector3(h.pos.x - 4.0, y, h.pos.z + side), Vector2(40.0, 0), 5.0, 0.4, 0.1, Color.WHITE)
	for i in 30:
		h.teleport(h.pos)
		h.vel = Vector3.ZERO
		m.step(Match.DT)
		if m.shots.is_empty(): break
	m.shots.clear()
	return h.hp < h.max_hp

## Walks `a` (and `b`, when it has a move set) for `steps` frames; the closest the two bodies came, centre to centre.
func _walk(m: Match, a: Ent, b: Ent, steps: int) -> float:
	var closest := 1e9
	for i in steps:
		m.step(Match.DT)
		closest = minf(closest, Vector2(a.pos.x - b.pos.x, a.pos.z - b.pos.z).length())
	return closest

## Standing still at `at`, healthy, with no speed left from the last trial.
func _park(h: Hunter, at: Vector3) -> void:
	h.teleport(at)
	h.vel = Vector3.ZERO
	h.hp = h.max_hp

## Two Hunters 3 m apart walk straight at each other for a second: they cross, undeflected.
func _hunters_meet(m: Match, h: Hunter, o: Hunter) -> void:
	var at := h.pos
	_park(h, at)
	_park(o, at + Vector3(3.0, 0, 0))
	h.inp["move"] = Vector2(1, 0)
	o.inp["move"] = Vector2(-1, 0)
	var closest := _walk(m, h, o, 60)
	h.inp["move"] = Vector2.ZERO
	o.inp["move"] = Vector2.ZERO
	var bodies := h.r + o.r
	ok(closest < bodies * 0.5,
		"two Hunters walking into each other overlap (closest %.2f of %.2f m)" % [closest, bodies])
	ok(h.pos.x > o.pos.x + h.r + o.r, "...and pass through: %.2f m past each other" % (h.pos.x - o.pos.x))
	var aside := Vector2(h.pos.z - at.z, o.pos.z - at.z)
	ok(absf(aside.x) < 0.05 and absf(aside.y) < 0.05, "...with no sideways shove (%.3f, %.3f m)" % [aside.x, aside.y])

## A dash into a foe standing 1 m ahead goes through it; the foe stays where it was.
func _dash_through(m: Match, h: Hunter, o: Hunter) -> void:
	var at := h.pos
	_park(o, at + Vector3(1.0, 0, 0))
	h.inp["move"] = Vector2(1, 0)
	h.inp["aim"] = at + Vector3(8, 0.9, 0)
	h.dashes = h.max_dashes()
	h.do_dash()
	h.inp["move"] = Vector2.ZERO
	var closest := _walk(m, h, o, 45)
	ok(closest < (h.r + o.r) * 0.5, "a dash through a foe overlaps it (closest %.2f m)" % closest)
	ok(h.pos.x > o.pos.x + h.r + o.r, "...and ends %.2f m past it" % (h.pos.x - o.pos.x))
	var moved := o.pos.distance_to(at + Vector3(1.0, 0, 0))
	ok(moved < 0.02, "...without moving the foe (%.3f m)" % moved)

## Walking into a dazed wild Boki 2 m ahead for a second: held outside its body and pushing it along.
func _boki_block(m: Match, h: Hunter) -> void:
	var at := h.pos
	var k := m.spawn_wild(Save.new_kin("cindle", "Ash"), at + Vector3(2.0, 0, 0), true)
	k.teleport(at + Vector3(2.0, 0, 0))
	var k0 := k.pos
	h.inp["move"] = Vector2(1, 0)
	var closest := _walk(m, h, k, 60)
	h.inp["move"] = Vector2.ZERO
	var bodies := h.r + k.r
	ok(closest >= bodies - 0.03,
		"a Hunter walking into a Boki is held off its body (closest %.2f of %.2f m)" % [closest, bodies])
	var pushed := k.pos.x - k0.x
	ok(pushed > 0.5 and h.pos.x < k.pos.x, "...and pushes it along: %.2f m, Hunter still behind" % pushed)
	k.queue_free()
	m.kins.erase(k)

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for b in m.breaks: b["dead"] = true
	var h: Hunter = m.hunters[0]
	var shooter: Hunter = null
	for o in m.hunters:
		o.ctrl = "idle"
		if o.team != h.team and shooter == null: shooter = o
	for o in m.hunters:
		if o != h and o != shooter: o.teleport(m.world.random_ground())
	_flatten(m, h)
	var std := float(Data.CLASSES["medium"]["hit_r"])
	var lo := 9.0
	var hi := 0.0
	var lo_a := ""
	var hi_a := ""
	for a in Arch.ids():
		var cls := Arch.weight(a)
		h.reclass(cls, a)
		var hr := Arch.hit_r(a, Data.CLASSES[cls])
		var in_band := hr >= std * BAND.x - 0.0005 and hr <= std * BAND.y + 0.0005
		ok(in_band, "%s: hit_r %.3f is %.3f x standard (band 0.85-1.15)" % [a, hr, hr / std])
		ok(absf(h.r - hr) < 0.0001, "%s: the hunter's r is its hit_r" % a)
		var ring := h.model.get_node("TeamRing") as MeshInstance3D
		var drawn := (ring.mesh as PlaneMesh).size.x * 0.5 * ring.global_transform.basis.x.length()
		var drawn_z := (ring.mesh as PlaneMesh).size.y * 0.5 * ring.global_transform.basis.z.length()
		var same := absf(drawn - hr) < 0.002 and absf(drawn_z - hr) < 0.002
		ok(same, "%s: ground circle radius %.3f = hit_r %.3f" % [a, drawn, hr])
		if hr < lo:
			lo = hr
			lo_a = a
		if hr > hi:
			hi = hr
			hi_a = a
	ok(lo_a == "tender" and hi_a == "bulwark", "smallest is %s, biggest is %s" % [lo_a, hi_a])
	for a in [lo_a, hi_a]:
		h.reclass(Arch.weight(a), a)
		h.teleport(h.pos)
		h.vel = Vector3.ZERO
		shooter.teleport(h.pos + Vector3(0, 0, 5.0))
		var edge := h.hit_radius() + 0.1            # the circle plus the bullet's own radius
		ok(not _fire(m, shooter, h, edge + 0.04), "%s: %.2f m off, just outside, misses" % [a, edge + 0.04])
		ok(_fire(m, shooter, h, edge - 0.04), "%s: %.2f m off, just inside, hits" % [a, edge - 0.04])
		ok(_fire(m, shooter, h, 0.0), "%s: a bullet through the centre hits" % a)
	h.reclass("medium", "gunslinger")
	for k in m.kins:
		if k.state == "active": k.state = "bench"      # the shooter's own Boki would fight the walker
	var home := h.pos
	_hunters_meet(m, h, shooter)
	_park(h, home)
	_park(shooter, home)
	_dash_through(m, h, shooter)
	_park(h, home)
	_park(shooter, home + Vector3(0, 0, 40.0))
	_boki_block(m, h)
	print("HITBOX SIZE CHECK DONE, failures: ", bad)
	main.get_tree().quit()
