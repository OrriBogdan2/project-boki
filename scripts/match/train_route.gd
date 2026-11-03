class_name TrainRoute
extends RefCounted
## The sky train's loop: a ring round the middle of the map ("center" and "r", Skyreach) or a winding
## closed "path" of points with its "stops" as indexes into it (the Riven Wilds, tools/make_riven.py).
## At each stop a short stone pier runs out from the islands on either side to the track, so you can
## just walk on; between stops, wherever the loop passes a bridge or a rim, the track dips under it.
## Split out of world.gd (a god file). Writes the piers into the world and sets W.train_route.

const GRID := 8            # tiles per cell of the lookup grid behind nearest()
const NEAR := 8.0          # m: nearest() finds the track from up to this far away

static func build(W: World, T: Dictionary, neck: Dictionary) -> void:
	var line := _centre_line(W, T)
	var n := line.size()
	var st_s := _stations(W, T, line)
	var names: Array = T.get("names", [])
	for si in st_s.size():
		var k := int(float(st_s[si]) / W.TRAIN_STEP) % n
		_piers(W, line[k], _normal(line, k), neck)
		if si < names.size():
			W.labels.append({"name": String(names[si]), "pos": Vector3(line[k].x, 0, line[k].y), "kind": "rail"})
	var y := _deck_heights(W, line, st_s)
	var pts := PackedVector3Array()
	pts.resize(n)
	for k in n:
		pts[k] = Vector3(line[k].x, y[k], line[k].y)
	W.train_route = {
		"pts": pts, "len": n * W.TRAIN_STEP, "stations": st_s, "names": names, "spec": T, "grid": _grid(line),
	}

## Where the track is a given arc length round the loop (wraps).
static func at(W: World, s: float) -> Vector3:
	var pts: PackedVector3Array = W.train_route["pts"]
	var n := pts.size()
	var f := fposmod(s, float(W.train_route["len"])) / W.TRAIN_STEP
	var k := int(f) % n
	return pts[k].lerp(pts[(k + 1) % n], f - floor(f))

## The stretch of track nearest a ground point: Vector3(arc length, distance, track point index), or a
## distance of INF when the track is more than NEAR away (or the map has no train).
static func nearest(W: World, p: Vector2) -> Vector3:
	if W.train_route.is_empty():
		return Vector3(0.0, INF, -1)
	var cells: Dictionary = W.train_route["grid"]
	var key := Vector2i(floori(p.x / GRID), floori(p.y / GRID))
	if not cells.has(key):
		return Vector3(0.0, INF, -1)
	var pts: PackedVector3Array = W.train_route["pts"]
	var best := INF
	var best_k := -1
	for k: int in cells[key]:
		var d := p.distance_squared_to(Vector2(pts[k].x, pts[k].z))
		if d < best:
			best = d
			best_k = k
	if best_k < 0 or sqrt(best) > NEAR:
		return Vector3(0.0, INF, -1)
	return Vector3(best_k * W.TRAIN_STEP, sqrt(best), best_k)

## The track's centre line, one point every TRAIN_STEP round the closed loop.
static func _centre_line(W: World, T: Dictionary) -> PackedVector2Array:
	var line := PackedVector2Array()
	if T.has("path"):
		var src := PackedVector2Array()
		for q in T["path"]:
			src.append(W._v2(q))
		var along := 0.0
		for seg in src.size():
			var a := src[seg]
			var b := src[(seg + 1) % src.size()]
			var seg_len := a.distance_to(b)
			while along < seg_len:
				line.append(a.lerp(b, along / seg_len))
				along += W.TRAIN_STEP
			along -= seg_len
		return line
	var c := W._v2(T.get("center", [W.w * 0.5, W.h * 0.5]))
	var R := float(T.get("r", 30.0))
	for k in int(ceil(TAU * R / W.TRAIN_STEP)):
		var ang := k * W.TRAIN_STEP / R
		line.append(c + Vector2(cos(ang), sin(ang)) * R)
	return line

## Each stop's arc length round the loop: a path's stops are indexes into its points, a ring's are
## bearings in degrees.
static func _stations(W: World, T: Dictionary, line: PackedVector2Array) -> Array:
	var out: Array = []
	if T.has("path"):
		var src: Array = T["path"]
		for i in T.get("stops", []):
			var q := W._v2(src[int(i)])
			var best := 0
			var best_d := INF
			for k in line.size():
				var d := line[k].distance_squared_to(q)
				if d < best_d:
					best_d = d
					best = k
			out.append(best * W.TRAIN_STEP)
		return out
	var R := float(T.get("r", 30.0))
	for a in T.get("stations", []):
		out.append(fposmod(deg_to_rad(float(a)), TAU) * R)
	return out

## Unit vector across the track at point k (on a ring, toward or away from its centre).
static func _normal(line: PackedVector2Array, k: int) -> Vector2:
	var n := line.size()
	var f := line[(k + 1) % n] - line[(k - 1 + n) % n]
	return Vector2(-f.y, f.x).normalized()

## A stop's piers: from the nearest ground on either side of the track, up to the track's edge.
static func _piers(W: World, at: Vector2, dir: Vector2, neck: Dictionary) -> void:
	for side: float in [-1.0, 1.0]:
		var found := -1.0
		for k in 30:
			var q := at + dir * side * (1.7 + k * 0.5)
			if not W.inb(int(q.x), int(q.y)):
				continue
			var i := W.idx(int(q.x), int(q.y))
			if W.kind[i] == W.T_GROUND and not neck.has(i) and W.level[i] < 4:
				found = 1.7 + k * 0.5
				break
		if found < 0.0:
			continue
		var g0 := at + dir * side * found
		var gi := W.idx(int(g0.x), int(g0.y))
		var isle := W.island[gi]
		var lv := W.level[gi]
		var p0 := at + dir * side * (found + 2.0)
		var p1 := at + dir * side * 1.7
		for z in range(int(minf(p0.y, p1.y)) - 3, int(maxf(p0.y, p1.y)) + 4):
			for x in range(int(minf(p0.x, p1.x)) - 3, int(maxf(p0.x, p1.x)) + 4):
				if not W.inb(x, z):
					continue
				var pt := Vector2(x + 0.5, z + 0.5)
				if Geometry2D.get_closest_point_to_segment(pt, p0, p1).distance_to(pt) > 1.6:
					continue
				var i := W.idx(x, z)
				if W.kind[i] != W.T_VOID:
					continue
				W.kind[i] = W.T_GROUND
				W.island[i] = isle
				W.level[i] = lv
				W.depth[i] = -1.6
				neck[i] = true
				W.islands[isle]["cells"].append(Vector2i(x, z))

## The deck height round the loop: level with the ground at the stops, under anything in the way, and
## never changing faster than the dive over ~8 tiles.
static func _deck_heights(W: World, line: PackedVector2Array, st_s: Array) -> PackedFloat32Array:
	var n := line.size()
	var loop := n * W.TRAIN_STEP
	var want := PackedFloat32Array()
	want.resize(n)
	for k in n:
		var s := k * W.TRAIN_STEP
		var near_stop := false
		for ss in st_s:
			if absf(fposmod(s - float(ss) + loop * 0.5, loop) - loop * 0.5) < 5.0:
				near_stop = true
		want[k] = W.TRAIN_DIVE if not near_stop and _blocked(W, line[k]) else 0.0
	var slope := absf(W.TRAIN_DIVE) / 8.0 * W.TRAIN_STEP
	var y := want.duplicate()
	for _pass in 2:
		for k in range(1, n * 2):
			y[k % n] = minf(y[k % n], y[(k - 1) % n] + slope)
		for k in range(n * 2 - 2, -1, -1):
			y[k % n] = minf(y[k % n], y[(k + 1) % n] + slope)
	return y

## Ground (a bridge, a rim) within reach of the cars at this point of the track; high perches float
## well clear of them.
static func _blocked(W: World, q: Vector2) -> bool:
	for z in range(int(q.y - 3), int(q.y + 4)):
		for x in range(int(q.x - 3), int(q.x + 4)):
			if not W.inb(x, z) or W.kind[W.idx(x, z)] == W.T_VOID or W.level[W.idx(x, z)] >= 6:
				continue
			if Vector2(x + 0.5, z + 0.5).distance_to(q) < 2.9:
				return true
	return false

## Track point indexes per grid cell, for every cell within NEAR of a point.
static func _grid(line: PackedVector2Array) -> Dictionary:
	var cells := {}
	var reach := int(ceil(NEAR / GRID))
	for k in line.size():
		var c := Vector2i(floori(line[k].x / GRID), floori(line[k].y / GRID))
		for gz in range(c.y - reach, c.y + reach + 1):
			for gx in range(c.x - reach, c.x + reach + 1):
				var cell := Rect2(gx * GRID, gz * GRID, GRID, GRID)
				var closest := line[k].clamp(cell.position, cell.end)
				if closest.distance_to(line[k]) > NEAR:
					continue
				var key := Vector2i(gx, gz)
				if not cells.has(key):
					cells[key] = []
				(cells[key] as Array).append(k)
	return cells
