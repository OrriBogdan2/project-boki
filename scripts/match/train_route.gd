class_name TrainRoute
extends RefCounted
## The sky train's loop. A layout gives either a ring ("center", "r", stations as angles in degrees:
## Skyreach) or a closed winding "path" ([[x,z],...], stations as [x,z] points on it: the Hollow
## Crown). At each stop a short stone pier runs out from the islands on either side to the track, so
## you can just walk on; between stops, wherever the loop passes a bridge or a rim, the track dips
## under it. Split out of world.gd (a god file). Writes the piers into the world and sets W.train_route:
## {pts, len, stations (arc lengths), names, spec, near: {tile index: nearest sample}}.

const NEAR_R := 7.5      # m: tiles this close to the track know their nearest sample (near()); covers the
                         # rider/bot checks (~4 m) and the cliff-rock and landmark keep-outs (7 m)

## The loop as a closed polyline, resampled every TRAIN_STEP: Array[Vector2].
static func _line(W: World, T: Dictionary) -> Array:
	var out: Array = []
	if not T.has("path"):
		var c := W._v2(T.get("center", [W.w * 0.5, W.h * 0.5]))
		var R := float(T.get("r", 30.0))
		var n := int(ceil(TAU * R / W.TRAIN_STEP))
		for k in n:
			var ang := k * W.TRAIN_STEP / R
			out.append(c + Vector2(cos(ang), sin(ang)) * R)
		return out
	var P: Array = []
	for q in T["path"]: P.append(W._v2(q))
	var s := 0.0
	var want := 0.0
	for i in P.size():
		var a: Vector2 = P[i]
		var b: Vector2 = P[(i + 1) % P.size()]
		var L := a.distance_to(b)
		while want <= s + L and L > 0.0:
			out.append(a.lerp(b, (want - s) / L))
			want += W.TRAIN_STEP
		s += L
	return out

## Arc length of a station: a ring's angle, or the nearest sample to a path's point.
static func _station_s(W: World, T: Dictionary, line: Array, st) -> float:
	if not T.has("path"):
		return fposmod(deg_to_rad(float(st)), TAU) * float(T.get("r", 30.0))
	var p := W._v2(st)
	var best := 0
	var bd := INF
	for k in line.size():
		var d := p.distance_squared_to(line[k])
		if d < bd:
			bd = d
			best = k
	return best * W.TRAIN_STEP

## Unit sideways direction at sample k (left of travel).
static func _side(line: Array, k: int) -> Vector2:
	var n := line.size()
	var f: Vector2 = (line[(k + 1) % n] as Vector2) - (line[(k - 1 + n) % n] as Vector2)
	return Vector2(f.y, -f.x).normalized()

static func build(W: World, T: Dictionary, neck: Dictionary) -> void:
	var line := _line(W, T)
	var n := line.size()
	var names: Array = T.get("names", [])
	var st_s: Array = []
	var pier_below := int(T.get("pier_below", 4))     # terraces: a pier never runs onto ground this high (a plateau)
	for st in T.get("stations", []):
		var s0 := _station_s(W, T, line, st)
		st_s.append(s0)
		var k0 := int(round(s0 / W.TRAIN_STEP)) % n
		var on: Vector2 = line[k0]
		var dir := _side(line, k0)
		# piers: from the nearest ground on either side of the track, up to the track's edge
		for side: float in [-1.0, 1.0]:
			var found := -1.0
			for k in 30:
				var q := on + dir * side * (1.7 + k * 0.5)
				if W.inb(int(q.x), int(q.y)) and W.kind[W.idx(int(q.x), int(q.y))] == W.T_GROUND and not neck.has(W.idx(int(q.x), int(q.y))) \
						and W.level[W.idx(int(q.x), int(q.y))] < pier_below:
					found = 1.7 + k * 0.5
					break
			if found < 0.0:
				continue
			var g0 := on + dir * side * found
			var gi := W.idx(int(g0.x), int(g0.y))
			var owner := W.island[gi]; var lv := W.level[gi]
			var p0 := on + dir * side * (found - 2.0)
			var p1 := on + dir * side * 1.7
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
					W.kind[i] = W.T_GROUND; W.island[i] = owner; W.level[i] = lv; W.depth[i] = -1.6
					neck[i] = true
					W.islands[owner]["cells"].append(Vector2i(x, z))
		if names.size() > st_s.size() - 1:
			W.labels.append({"name": String(names[st_s.size() - 1]), "pos": Vector3(on.x, 0, on.y), "kind": "rail"})
	# the deck height round the loop: level with the ground at the stops, under anything in the way
	var loop := n * W.TRAIN_STEP
	var want := PackedFloat32Array(); want.resize(n)
	for k in n:
		var s := k * W.TRAIN_STEP
		var q: Vector2 = line[k]
		var near_stop := false
		for ss in st_s:
			if absf(fposmod(s - float(ss) + loop * 0.5, loop) - loop * 0.5) < 5.0: near_stop = true
		var blocked := false
		if not near_stop:
			for z in range(int(q.y - 3), int(q.y + 4)):
				for x in range(int(q.x - 3), int(q.x + 4)):
					# (high perches float well clear of the cars)
					if W.inb(x, z) and W.kind[W.idx(x, z)] != W.T_VOID and W.level[W.idx(x, z)] < 6 and Vector2(x + 0.5, z + 0.5).distance_to(q) < 2.9:
						blocked = true
		want[k] = W.TRAIN_DIVE if blocked else 0.0
	# ramps: the deck never changes height faster than the dive over ~8 tiles
	var slope := absf(W.TRAIN_DIVE) / 8.0 * W.TRAIN_STEP
	var y := want.duplicate()
	for _pass in 2:
		for k in range(1, n * 2):
			y[k % n] = minf(y[k % n], y[(k - 1) % n] + slope)
		for k in range(n * 2 - 2, -1, -1):
			y[k % n] = minf(y[k % n], y[(k + 1) % n] + slope)
	var pts := PackedVector3Array(); pts.resize(n)
	for k in n:
		pts[k] = Vector3(line[k].x, y[k], line[k].y)
	W.train_route = {"pts": pts, "len": loop, "stations": st_s, "names": names, "spec": T, "near": _near_table(W, line)}

## Tile index -> nearest sample, for every tile within NEAR_R of the track (every other sample is plenty).
static func _near_table(W: World, line: Array) -> Dictionary:
	var best := {}
	var rr := int(ceil(NEAR_R))
	for k in range(0, line.size(), 2):
		var q: Vector2 = line[k]
		for z in range(int(q.y) - rr, int(q.y) + rr + 1):
			for x in range(int(q.x) - rr, int(q.x) + rr + 1):
				if not W.inb(x, z):
					continue
				var d := Vector2(x + 0.5, z + 0.5).distance_squared_to(q)
				if d > NEAR_R * NEAR_R:
					continue
				var i := W.idx(x, z)
				if not best.has(i) or d < float(best[i].y):
					best[i] = Vector2(k, d)
	var out := {}
	for i in best: out[i] = int(best[i].x)
	return out

## The track nearest a point: Vector3(arc length, signed sideways offset (+ = left of travel), 0), or
## Vector3.INF when the point is more than NEAR_R from it.
static func near(W: World, x: float, z: float) -> Vector3:
	if W.train_route.is_empty() or not W.inb(int(x), int(z)):
		return Vector3.INF
	var k0 = W.train_route["near"].get(W.idx(int(x), int(z)))
	if k0 == null:
		return Vector3.INF
	var pts: PackedVector3Array = W.train_route["pts"]
	var n := pts.size()
	var p := Vector2(x, z)
	var best := Vector3.INF
	for k in [int(k0) - 1, int(k0), int(k0) + 1]:
		var a := Vector2(pts[posmod(k, n)].x, pts[posmod(k, n)].z)
		var b := Vector2(pts[posmod(k + 1, n)].x, pts[posmod(k + 1, n)].z)
		var f := (b - a).normalized()
		var u := clampf((p - a).dot(f), 0.0, W.TRAIN_STEP)
		var off := (p - a).cross(f)       # (x right, z down: positive is left of travel seen from above)
		if best == Vector3.INF or (p - a - f * u).length() < absf(best.y) + 0.001:
			best = Vector3(fposmod(k * W.TRAIN_STEP + u, float(W.train_route["len"])), off, 0.0)
	return best

## Unit direction away from the track's centre line at a point (the side it's on), or ZERO when far.
static func off_dir(W: World, x: float, z: float) -> Vector2:
	var nr := near(W, x, z)
	if nr == Vector3.INF:
		return Vector2.ZERO
	var k := int(nr.x / W.TRAIN_STEP)
	var pts: PackedVector3Array = W.train_route["pts"]
	var a := pts[k % pts.size()]
	var b := pts[(k + 1) % pts.size()]
	var f := Vector2(b.x - a.x, b.z - a.z).normalized()
	return Vector2(f.y, -f.x) * (-1.0 if nr.y < 0.0 else 1.0)

## Where the track is a given arc length round the loop (wraps).
static func at(W: World, s: float) -> Vector3:
	var pts: PackedVector3Array = W.train_route["pts"]
	var n := pts.size()
	var f := fposmod(s, float(W.train_route["len"])) / W.TRAIN_STEP
	var k := int(f) % n
	return pts[k].lerp(pts[(k + 1) % n], f - floor(f))
