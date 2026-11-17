class_name HandLayout
extends RefCounted
## Builds the parts of a fully hand-made map (World.hand, see tools/make_hollowcrown.py) that the
## generator never touches: hand-placed cover, authored stair flights, and every listed spot.
## Moved out of world.gd to keep that file inside its budget (AGENTS.md).

static func block(w: World, x: int, z: int, ii: int, what: String, neck: Dictionary) -> void:
	if w.inb(x, z) and w.kind[w.idx(x, z)] == World.T_GROUND and w.island[w.idx(x, z)] == ii and not neck.has(w.idx(x, z)) and not w.authored_stairs.has(w.idx(x, z)):
		w.kind[w.idx(x, z)] = World.T_BLOCK
		w.props[w.idx(x, z)] = what

## A flight of stairs the layout placed: {at: [x, z] (the bottom row's middle), dir: n|s|e|w, w,
## from, to, run}. Row k climbs one terrace (run 1), or every other row does with a landing between
## (run 2). The rows replace whatever ground was there; the top row meets the plateau at `to`.
static func stamp_ramp(w: World, R: Dictionary, ii: int) -> void:
	var d: Vector2i = {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}[String(R.get("dir", "n"))]
	var side := Vector2i(-d.y, d.x)
	var wd := int(R.get("w", 4)); var run := maxi(1, int(R.get("run", 1)))
	var lv0 := int(R.get("from", 0)); var lv1 := int(R.get("to", lv0 + 1))
	var at := Vector2i(int(R["at"][0]), int(R["at"][1]))
	for k in (lv1 - lv0) * run:
		var stair := k % run == 0
		var lv := lv0 + k / run + (0 if stair else 1)
		for s in range(-(wd / 2), wd - wd / 2):
			var q := at + d * k + side * s
			if not w.inb(q.x, q.y) or w.kind[w.idx(q.x, q.y)] == World.T_VOID:
				continue
			var i := w.idx(q.x, q.y)
			w.level[i] = lv
			w.kind[i] = World.T_GROUND
			w.island[i] = ii if w.island[i] < 0 else w.island[i]
			if stair: w.authored_stairs[i] = d
			else: w.authored_stairs.erase(i)

## A hand-made layout's places, exactly where it lists them (World.hand): landings, chests, camps,
## wild Boki, breakables, weapons, the shrine, Warden posts and trap spots. Nothing is rolled here.
static func place_spots(w: World, defs: Array) -> void:
	w.shrine_spots.clear(); w.break_spots.clear(); w.weapon_spots.clear()
	w.heart_spot = Vector3.INF
	var at := func(p) -> Vector3:
		var x := int(p[0]); var z := int(p[1])
		if not w.inb(x, z) or w.kind[w.idx(x, z)] == World.T_VOID:
			return Vector3.INF
		if w.kind[w.idx(x, z)] == World.T_BLOCK and not w.walls.has(w.idx(x, z)):
			w.kind[w.idx(x, z)] = World.T_GROUND; w.props.erase(w.idx(x, z))
		return Vector3(x + 0.5, w.ground_at(x + 0.5, z + 0.5), z + 0.5)
	for ii in mini(defs.size(), w.islands.size()):
		var D: Dictionary = defs[ii]
		var poi := w._poi(ii)
		if String(D.get("role", "")) == "heart" and poi != Vector3.INF:
			w.heart_spot = poi
		if String(D.get("role", "")) == "nest" and poi != Vector3.INF:
			w.islands[ii]["nest"] = poi
		for p in D.get("landings", []):
			var q: Vector3 = at.call(p)
			if q != Vector3.INF: w.spawns.append(q)
		for c in D.get("camps", []):
			var q: Vector3 = at.call(c)
			if q != Vector3.INF: w.camp_spots.append({"pos": q, "island": ii, "kind": String(c[2]) if (c as Array).size() > 2 else "light"})
		for p in D.get("wild", []):
			var q: Vector3 = at.call(p)
			if q != Vector3.INF: w.wild_spots.append(q)
		for b in D.get("breakables", []):
			var q: Vector3 = at.call(b)
			if q != Vector3.INF: w.break_spots.append({"pos": q, "kind": String(b[2]) if (b as Array).size() > 2 else "crate"})
		for p in D.get("weapons", []):
			var q: Vector3 = at.call(p)
			if q != Vector3.INF: w.weapon_spots.append(q)
		if D.has("shrine"):
			var q: Vector3 = at.call(D["shrine"])
			if q != Vector3.INF: w.shrine_spots.append(q)
		for p in D.get("wardens", []):
			var q: Vector3 = at.call(p)
			if q != Vector3.INF: w.warden_posts.append({"pos": q, "island": ii})
		for p in D.get("traps", []):
			var q: Vector3 = at.call(p)
			if q != Vector3.INF: w.trap_spots.append({"pos": q, "island": ii})
		for a in D.get("areas", []):
			var q: Vector3 = at.call(a)
			if q != Vector3.INF:
				w.labels.append({"name": String(a[2]), "pos": q, "kind": "poi", "role": String(D.get("role", "")), "height": q.y})
	# the exits stand exactly where the layout puts them, in the order they open
	for ap in w.authored_portals:
		var q: Vector3 = at.call([(ap as Vector2).x, (ap as Vector2).y])
		if q != Vector3.INF: w.portal_spots.append(q)
