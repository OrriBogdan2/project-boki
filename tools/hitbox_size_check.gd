extends RefCounted
## --hitbox-size-check: hitboxes follow the Warden's size, compressed (docs/HITBOX_SIZE.md). Every
## archetype's hit_r is 0.85-1.15 x the standard (the Medium class's), the ground circle under the
## hunter is drawn at exactly that radius, and shots are tested against it (a bullet just inside
## the circle hits, just outside misses) for the smallest and the biggest. Never touches the save.

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
	print("HITBOX SIZE CHECK DONE, failures: ", bad)
	main.get_tree().quit()
