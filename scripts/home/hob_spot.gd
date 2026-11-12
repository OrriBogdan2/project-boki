class_name HobSpot
extends RefCounted
## Hob's home spot on the farm (FarmHob): one fixed tile, kept in layout["hob"]["spot"] = [x, z], with a
## clear ring round it ("clear" in content/rules/farm_builder.json). No placed footprint tile and no place
## you interact with (HomeBuild._targets: doors, the stall, plots, signs...) comes inside the ring, so his
## talk prompt and the talk camera never share space with anything else. Build mode refuses a piece inside
## it (HomeBuild.cell_reason: REASON). The first look picks the free tile nearest his place by the market
## stall; when something ends up inside the ring anyway (an older save, a moved fixture) he walks to the
## nearest free tile, which becomes his spot.

const REASON := "Too close to Hob"


static func clear_m() -> float:
	return float(FarmBuilder.rules()["clear"]["m"])


## His home spot (a tile centre): the saved one while it stays clear, else the free tile nearest it (or nearest
## `wish` on the first look), saved. With no free tile anywhere he keeps the saved spot (or `wish`).
static func home(h, wish: Vector3) -> Vector3:
	var st := FarmBuilder.state()
	var saved := Vector3.INF
	if st.get("spot") is Array and (st["spot"] as Array).size() == 2:
		saved = Vector3(float(st["spot"][0]), 0, float(st["spot"][1]))
	var w: World = h.world
	var free := free_tiles(h)
	if saved != Vector3.INF and free[w.idx(int(floor(saved.x)), int(floor(saved.z)))] == 1:
		return saved
	var at := _nearest(w, free, saved if saved != Vector3.INF else wish)
	if at == Vector3.INF:
		return saved if saved != Vector3.INF else wish
	st["spot"] = [at.x, at.z]
	if saved != Vector3.INF:
		print("HobSpot: something is inside Hob's clear ring at %s; he moves to %s" % [saved, at])
	return at


## Is tile c inside the clear ring round `spot`? (The gap from the spot to the nearest edge of the tile.)
static func near_tile(spot: Vector3, c: Vector2i) -> bool:
	var gx := maxf(absf(c.x + 0.5 - spot.x) - 0.5, 0.0)
	var gz := maxf(absf(c.y + 0.5 - spot.z) - 0.5, 0.0)
	return Vector2(gx, gz).length() < clear_m()


## 1 per tile he may stand on: open ground (and all round it) you can walk to, with nothing placed and no
## place you interact with inside the clear ring.
static func free_tiles(h) -> PackedByteArray:
	var hb: HomeBuild = h.hb
	var w: World = h.world
	var seen := hb._reach([], [])
	var free := PackedByteArray()
	free.resize(w.w * w.h)
	for i in free.size():
		free[i] = 1 if seen[i] == 1 and _open_round(hb, w, i) else 0
	var r := clear_m()
	var n := int(ceil(r))
	for i in hb.occ:
		var c := Vector2i(i % w.w, i / w.w)
		for z in range(c.y - n, c.y + n + 1):
			for x in range(c.x - n, c.x + n + 1):
				if w.inb(x, z) and near_tile(Vector3(x + 0.5, 0, z + 0.5), c):
					free[w.idx(x, z)] = 0
	for p in hb._targets():
		for z in range(int(floor(p.z)) - n, int(floor(p.z)) + n + 1):
			for x in range(int(floor(p.x)) - n, int(floor(p.x)) + n + 1):
				if w.inb(x, z) and Vector2(x + 0.5 - p.x, z + 0.5 - p.z).length() < r:
					free[w.idx(x, z)] = 0
	return free


## The tile and its eight neighbours are bare open ground (nothing to clip into), not kept clear for a fixture.
static func _open_round(hb: HomeBuild, w: World, i: int) -> bool:
	var x := i % w.w
	var z := i / w.w
	if hb.reserved.has(i) or not hb._isle_ok(i):
		return false
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if not w.inb(x + dx, z + dz):
				return false
			var j := w.idx(x + dx, z + dz)
			if w.kind[j] != World.T_GROUND or w.bridge.has(j) or hb.wild_t.has(j):
				return false
	return true


## The free tile centre nearest `from` (ties: the lower tile index, so it is the same every time), or INF.
static func _nearest(w: World, free: PackedByteArray, from: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for i in free.size():
		if free[i] != 1:
			continue
		var t := Vector3(i % w.w + 0.5, 0, i / w.w + 0.5)
		var d := Vector2(t.x - from.x, t.z - from.z).length_squared()
		if d < best_d:
			best = t
			best_d = d
	return best
