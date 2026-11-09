class_name KeysDemo
extends RefCounted
## Screenshot tooling for the keys and the cover: --keys-demo=<what> with --match --no-drop --god
## --shot=path.png --shot-times=a,b (match seconds; the scene is set up at 1.0):
##   thicket   you at the edge of the biggest tall-grass patch in the bloom biome, nothing else about
##   chest     you beside a locked chest, no key (the padlock and the key count on the HUD); keys=2 gives you two
##   glint     you looking at a monster that carries a key, the glint over its head
##   shrub     you hiding inside a Shrubling; at 2.0 s you hit it, so ~2.4 s shows it bolting and you in the open

static var _what := "?"

static func what() -> String:
	if _what == "?":
		_what = ""
		for a in OS.get_cmdline_user_args():
			if String(a).begins_with("--keys-demo="):
				_what = String(a).substr(12)
	return _what

static func frame(m: Match) -> void:
	var w := what()
	if w == "":
		return
	Settings.v["tips"] = false          # (no tutorial cards over the shot)
	var P: Hunter = m.player
	if P == null or P.out or m.time < 1.0 or m.keys == null:
		return
	P.hp = P.max_hp
	if m.hud:
		m.hud.guide_hidden = true
	var parts := w.split(":")
	var K: KeyRun = m.keys
	if not m.has_meta("kdemo"):
		m.set_meta("kdemo", true)
		match parts[0]:
			"thicket": _thicket(m, P, K)
			"chest": _chest(m, P, int(parts[1]) if parts.size() > 1 else 0)
			"glint": _glint(m, P, K)
			"shrub": _shrub(m, P, K)
		return
	if parts[0] == "shrub" and m.time >= 2.0 and not m.has_meta("kdemo2"):
		m.set_meta("kdemo2", true)
		var s: Shrubling = m.get_meta("kdemo_s")
		s.hurt(1.0, P, {"src": "shot"})
	if parts[0] == "glint" and m.has_meta("kdemo_car"):
		var car: Mob = m.get_meta("kdemo_car")      # (held in place, so it poses beside you, not on you)
		if is_instance_valid(car) and not car.dead:
			car.pos = m.get_meta("kdemo_at")
			car.vel = Vector3.ZERO

static func _thicket(m: Match, P: Hunter, K: KeyRun) -> void:
	var W := m.world
	var best: Dictionary = {}
	for p in K.patches:
		if W.biome_at(p["c"].x, p["c"].y) != "bloom": continue
		if best.is_empty() or (p["tiles"] as Array).size() > (best["tiles"] as Array).size(): best = p
	if best.is_empty():
		return
	var c: Vector2 = best["c"]
	var spot := Vector3.INF
	for r in range(5, 14):
		for k in 24:
			var a := TAU * float(k) / 24.0
			var q := c + Vector2(cos(a), sin(a)) * float(r)
			if W.is_void(q.x, q.y) or W.is_block(q.x, q.y) or W.bush.has(W.idx(int(q.x), int(q.y))) \
					or W.island_of(q.x, q.y) != W.island_of(c.x, c.y):
				continue
			if spot == Vector3.INF or q.y > spot.z:
				spot = Vector3(q.x, 0, q.y)
		if spot != Vector3.INF:
			break
	spot.y = W.ground_at(spot.x, spot.z)
	P.teleport(spot)
	P.inp["aim"] = Vector3(c.x, spot.y, c.y)
	PolishTools.clear_mobs(m)
	print("KEYSDEMO thicket of %d tiles at (%.0f,%.0f), you at (%.0f,%.0f)" % [
			(best["tiles"] as Array).size(), c.x, c.y, spot.x, spot.z])

static func _chest(m: Match, P: Hunter, keys: int) -> void:
	var best: Dictionary = {}
	for c in m.chests:
		if c.get("free", false) or c.get("ride", false) or c["open"]: continue
		if best.is_empty() \
				or (c["pos"] as Vector3).distance_to(P.pos) < (best["pos"] as Vector3).distance_to(P.pos): best = c
	if best.is_empty():
		return
	P.teleport(best["pos"] + Vector3(0.1, 0, 3.2))
	m.set_meta("zoom_hold", 0.62)
	P.chest_keys = keys
	P.inp["aim"] = best["pos"]
	PolishTools.clear_mobs(m)
	print("KEYSDEMO chest at (%.0f,%.0f), keys %d" % [best["pos"].x, best["pos"].z, keys])

static func _glint(m: Match, P: Hunter, K: KeyRun) -> void:
	var car: Mob = null
	for mb in K.carriers:
		# a plain small one reads best
		if mb is Shrubling or mb.dead or mb.mass() > 1.0 or mb.rarity > 0: continue
		var q: Vector3 = mb.pos + Vector3(3.5, 0, 1.5)
		if absf(m.world.ground_at(mb.pos.x, mb.pos.z) - mb.pos.y) > 0.6 or m.world.is_block(q.x, q.z) \
				or m.world.is_void(q.x, q.z) \
				or m.world.island_of(q.x, q.z) != m.world.island_of(
						mb.pos.x, mb.pos.z) or m.world.biome_at(mb.pos.x, mb.pos.z) == "ember":
			continue      # (a carrier in the open, with room to stand in front of it)
		if car == null or mb.pos.distance_to(P.pos) < car.pos.distance_to(P.pos): car = mb
	if car == null:
		return
	P.teleport(car.pos + Vector3(3.5, 0, 1.5))
	m.set_meta("zoom_hold", 0.62)
	m.set_meta("kdemo_car", car)
	m.set_meta("kdemo_at", car.pos)
	P.inp["aim"] = car.pos
	for mb in m.mobs.duplicate():
		if mb != car and (mb as Mob).pos.distance_to(car.pos) < 9.0:
			m.mobs.erase(mb)
			mb.queue_free()
	print("KEYSDEMO carrier %s at (%.0f,%.0f)" % [car.mkind, car.pos.x, car.pos.z])

static func _shrub(m: Match, P: Hunter, K: KeyRun) -> void:
	if K.shrublings.is_empty():
		return
	var s: Shrubling = K.shrublings[0]
	m.set_meta("kdemo_s", s)
	for mb in m.mobs.duplicate():
		if mb != s and (mb as Mob).pos.distance_to(s.pos) < 20.0:
			# (just the bush and you in the shot)
			m.mobs.erase(mb)
			mb.queue_free()
	P.teleport(s.pos + Vector3(0.15, 0, 0.1))
	m.set_meta("zoom_hold", 0.62)
	P.inp["aim"] = s.pos + Vector3(-4.0, 0, 0)
	print("KEYSDEMO shrubling at (%.0f,%.0f)" % [s.pos.x, s.pos.z])
