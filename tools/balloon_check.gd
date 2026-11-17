extends RefCounted
## --balloon-check: the hit marker is the hitbox. For every class, below an island's lip (balloon),
## gliding high over land (ring) and mid-hop (no marker: the body), the marker's radius is the real
## hit radius (the class's hit_r + Match.HIT_SLACK) and its heights sit inside the band
## Match.shot_height_ok lets through; then a real level shot fired through the marker hits, and
## flashes it (but not the hopping body, which has none). Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001

## An island edge with open air beyond it and flat ground behind it.
func _edge(m: Match) -> Dictionary:
	var w: World = m.world
	for k in 4000:
		var g := w.random_ground()
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var good := true
			for dd in [1.6, 2.4, 3.2, 4.0]:
				for sd in [-1.0, 0.0, 1.0]:
					if not w.is_void(g.x + d.x * dd + d.y * sd, g.z + d.y * dd + d.x * sd): good = false
			for dd in [0.0, -0.75, -1.5, -2.25, -3.0, -3.75, -4.5]:
				var x: float = g.x + d.x * dd; var z: float = g.z + d.y * dd
				if w.is_void(x, z) or w.is_block(x, z) or absf(w.ground_at(x, z) - g.y) > 0.05: good = false
			if good:
				var ex := g.x; var ez := g.z
				while not w.is_void(ex + d.x * 0.25, ez + d.y * 0.25):
					ex += d.x * 0.25; ez += d.y * 0.25
				return {"edge": Vector3(ex, g.y, ez), "dir": d}
	return {}

func _place(m: Match, h: Hunter, p: Vector3, glide: bool) -> void:
	h.teleport(p); h.vel = Vector3.ZERO; h.grounded = false; h.pad = {}
	h.gliding = glide; h.inp["glide"] = glide; h.glide_fuel = 1.0; h.glide_cd = 0.0
	h.downed = false; h.phase_t = 0.0; h.hp = h.max_hp; h.armor = 0.0
	h.update_lip()

## Fires one level shot (radius 0.1) from `from` through `h`'s marker (or body) at height y, passing
## `side` metres to one side of its centre; true if it hit h.
func _fire(m: Match, shooter: Hunter, h: Hunter, from: Vector3, y: float, glide: bool, side := 0.0) -> bool:
	var at := h.pos
	shooter.inp.erase("aim_y")
	h.hp = h.max_hp; h._mk_flash = 0.0
	var hp0 := h.hp
	var dv := Vector2(at.x - from.x, at.z - from.z).normalized()
	var off := Vector2(-dv.y, dv.x) * side
	m.spawn_shot(shooter, Vector3(from.x + off.x, y, from.z + off.y), dv * 40.0, 5.0, 0.4, 0.1, Color.WHITE)
	var hit := false
	for i in 30:
		_place(m, h, at, glide)
		m.step(Match.DT)
		if h.hp < hp0 or h._mk_flash > 0.0: hit = true
		if m.shots.is_empty(): break
	m.shots.clear()
	return hit

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for b in m.breaks: b["dead"] = true       # (crates would stop the test shots)
	var h: Hunter = m.hunters[0]
	var shooter: Hunter = null
	for o in m.hunters:
		o.ctrl = "idle"
		if o.team != h.team and shooter == null: shooter = o
	for kk in [h.kin, h.kin2, shooter.kin, shooter.kin2]:
		if kk: m.kins.erase(kk); kk.queue_free()
	h.kin = null; h.kin2 = null; shooter.kin = null; shooter.kin2 = null
	for o in m.hunters:
		if o != h and o != shooter: o.teleport(m.world.random_ground())
	ok(_near(h.r, Arch.hit_r(h.arch, h.cdat)), "hunter r is its archetype's hit_r (%s %.2f)" % [h.cls, h.r])
	var ed := _edge(m)
	ok(not ed.is_empty(), "found an island edge")
	if ed.is_empty():
		print("BALLOON CHECK DONE, failures: ", bad); main.get_tree().quit(); return
	var e: Vector3 = ed["edge"]; var d: Vector2 = ed["dir"]
	var flat := Vector3(e.x - d.x * 1.5, e.y, e.z - d.y * 1.5)        # on the island, back from the rim
	var r0 := h.r
	for cls in Data.CLASSES:
		h.r = float(Data.CLASSES[cls]["hit_r"])
		var hr := h.r + Match.HIT_SLACK
		ok(_near(h.hit_radius(), hr), "%s: hit radius %.2f = hit_r + slack" % [cls, hr])
		var cases := [
			["below lip", Vector3(e.x + d.x * (hr + 0.8), e.y - 2.4, e.z + d.y * (hr + 0.8)), true, "balloon"],
			["gliding high", flat + Vector3(0, 3.0, 0), true, "ring"],
			["just over hop height", flat + Vector3(0, Match.HOP_STAND + 0.1, 0), false, "ring"],
			["hopping", flat + Vector3(0, 0.9, 0), false, ""],
			["hop apex", flat + Vector3(0, Match.HOP_STAND - 0.02, 0), false, ""],
		]
		for c in cases:
			var nm: String = "%s %s" % [cls, c[0]]
			_place(m, h, c[1], c[2])
			var kind := h.hit_marker()
			ok(kind == c[3], "%s: marker '%s' (want '%s')" % [nm, kind, c[3]])
			var band: Vector2 = m.shot_band(h)
			var stance: float = m.shot_stance_y(h)
			h._render_balloon(0.0)
			var shot_y := stance + Hunter.MARKER_BALL_Y          # a level shot at the marker's centre
			if kind != "":
				var ring: Node3D = h.balloon.get_node("Ring")
				var ball: Node3D = h.balloon.get_node("Ball")
				ok(h.balloon.visible, "%s: marker shows" % nm)
				ok(_near(ring.scale.x, hr) and _near(ring.scale.z, hr), "%s: ring radius %.3f = hit radius %.3f" % [nm, ring.scale.x, hr])
				var ry := ring.global_position.y
				ok(ry > band.x and ry < band.y, "%s: ring height %.2f inside the shot band %.2f..%.2f" % [nm, ry, band.x, band.y])
				var hc := Vector2(ring.global_position.x - h.pos.x, ring.global_position.z - h.pos.z).length()
				ok(hc < 0.001, "%s: ring centred on the hit circle" % nm)
				if kind == "balloon":
					ok(ball.visible and _near(ball.scale.x, hr) and _near(ball.scale.z, hr), "%s: balloon radius %.3f = hit radius" % [nm, ball.scale.x])
					var by := ball.global_position.y
					ok(by - hr * 1.15 > band.x and by + hr * 1.15 < band.y, "%s: whole balloon %.2f..%.2f inside the band" % [nm, by - hr * 1.15, by + hr * 1.15])
					shot_y = by
				else:
					ok(not ball.visible, "%s: no balloon over land" % nm)
					ok(stance > h.ground() + 0.001, "%s: ring above the terrace (%.2f > %.2f)" % [nm, stance, h.ground()])
			else:
				ok(h.balloon == null or not h.balloon.visible, "%s: no marker, the body is the target" % nm)
				var body := h.pos.y + 0.8
				ok(body > band.x and body < band.y, "%s: body middle %.2f inside the band %.2f..%.2f" % [nm, body, band.x, band.y])
				ok(_near(stance, h.ground()), "%s: hit as standing on the terrace" % nm)
				shot_y = h.ground() + 0.95                          # a shot from someone on that terrace
			ok(m.shot_height_ok(h, shot_y), "%s: a shot at the marker height %.2f is let through" % [nm, shot_y])
			# and a real one: fired level from the island, through the marker
			var from := Vector3(e.x - d.x * 2.6, 0, e.z - d.y * 2.6)
			if c[0] != "below lip":
				from = Vector3(e.x - d.x * 4.4, 0, e.z - d.y * 4.4)
			var hit := _fire(m, shooter, h, from, shot_y, c[2])
			ok(hit, "%s: a real shot at %.2f hits" % [nm, shot_y])
			ok((h._mk_flash > 0.0) == (kind != ""), "%s: marker flash on hit = %s" % [nm, str(kind != "")])
			# the marker's edge is the hit circle's edge: a bullet grazing it inside hits, outside misses
			if kind != "":
				ok(_fire(m, shooter, h, from, shot_y, c[2], hr + 0.1 - 0.04), "%s: a shot grazing just inside the marker's edge hits" % nm)
				ok(not _fire(m, shooter, h, from, shot_y, c[2], hr + 0.1 + 0.04), "%s: a shot passing just outside the marker's edge misses" % nm)
			# and one clearly over the band misses
			var miss := _fire(m, shooter, h, from, band.y + 0.3, c[2])
			ok(not miss, "%s: a shot over the band (%.2f) misses" % [nm, band.y + 0.3])
	h.r = r0
	print("BALLOON CHECK DONE, failures: ", bad)
	main.get_tree().quit()
