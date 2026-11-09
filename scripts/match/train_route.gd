class_name TrainRoute
extends RefCounted
## The sky train's loop: a ring round the middle of the map. At each stop a short stone pier runs
## out from the islands on either side to the track, so you can just walk on; between stops, wherever
## the ring passes a bridge or a rim, the track dips under it.
## Split out of world.gd (a god file). Writes the piers into the world and sets W.train_route.
static func build(W: World, T: Dictionary, neck: Dictionary) -> void:
	var c := W._v2(T.get("center", [W.w * 0.5, W.h * 0.5]))
	var R := float(T.get("r", 30.0))
	var n := int(ceil(TAU * R / W.TRAIN_STEP))
	var stops: Array = T.get("stations", [])
	var names: Array = T.get("names", [])
	var st_s: Array = []
	for a in stops:
		var ang := deg_to_rad(float(a))
		st_s.append(fposmod(ang, TAU) * R)
		var dir := Vector2(cos(ang), sin(ang))
		# piers: from the nearest ground inside and outside the ring, up to the track's edge
		for side: float in [-1.0, 1.0]:
			var found := -1.0
			var r0 := R + side * 1.7
			for k in 30:
				var rr := r0 + side * k * 0.5
				var q := c + dir * rr
				if W.inb(int(q.x), int(q.y)) and W.kind[W.idx(int(q.x), int(q.y))] == W.T_GROUND and not neck.has(W.idx(int(q.x), int(q.y))) \
						and W.level[W.idx(int(q.x), int(q.y))] < 4:
					found = rr; break
			if found < 0.0:
				continue
			var g0 := c + dir * found
			var gi := W.idx(int(g0.x), int(g0.y))
			var owner := W.island[gi]; var lv := W.level[gi]
			var p0 := c + dir * (found - side * 2.0); var p1 := c + dir * r0
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
			var at := c + dir * R
			W.labels.append({"name": String(names[st_s.size() - 1]), "pos": Vector3(at.x, 0, at.y), "kind": "rail"})
	# the deck height round the loop: level with the ground at the stops, under anything in the way
	var want := PackedFloat32Array(); want.resize(n)
	for k in n:
		var s := k * W.TRAIN_STEP
		var ang := s / R
		var q := c + Vector2(cos(ang), sin(ang)) * R
		var near_stop := false
		for ss in st_s:
			var ds := absf(fposmod(s - float(ss) + TAU * R * 0.5, TAU * R) - TAU * R * 0.5)
			if ds < 5.0: near_stop = true
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
		var ang := k * W.TRAIN_STEP / R
		pts[k] = Vector3(c.x + cos(ang) * R, y[k], c.y + sin(ang) * R)
	W.train_route = {"pts": pts, "len": n * W.TRAIN_STEP, "stations": st_s, "names": names, "spec": T, "center": c, "r": R}

## Where the track is a given arc length round the loop (wraps).
static func at(W: World, s: float) -> Vector3:
	var pts: PackedVector3Array = W.train_route["pts"]
	var n := pts.size()
	var f := fposmod(s, float(W.train_route["len"])) / W.TRAIN_STEP
	var k := int(f) % n
	return pts[k].lerp(pts[(k + 1) % n], f - floor(f))
