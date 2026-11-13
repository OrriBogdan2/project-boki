class_name GroundShapes
extends RefCounted
## The authored islands' shapes (the layouts in content/maps: circles, ellipses, rects, capsules and
## hand-drawn polygons) and their per-tile tests for World.generate_authored. island() runs on worker
## threads (BuildThreads), one island each: it only reads the layout, and the ground pass applies its
## results in the order a single pass had, so the tiles, terraces and depths come out the same.

const COAST_FREQ := 0.055      # coast noise frequency: broad, gentle coastlines

static func v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

## Normalised distance of a point from a shape: below 1 is inside.
static func shape_d(S: Dictionary, pt: Vector2) -> float:
	if S.has("circle"):
		return pt.distance_to(v2(S["circle"])) / maxf(0.5, float(S["r"]))
	if S.has("ellipse"):
		var c := v2(S["ellipse"])
		var q := (pt - c).rotated(-deg_to_rad(float(S.get("rot", 0.0))))
		return Vector2(q.x / float(S["rx"]), q.y / float(S["rz"])).length()
	if S.has("rect"):
		var r: Array = S["rect"]
		var c2 := Vector2((float(r[0]) + float(r[2])) * 0.5, (float(r[1]) + float(r[3])) * 0.5)
		var hx := maxf(0.5, (float(r[2]) - float(r[0])) * 0.5)
		var hz := maxf(0.5, (float(r[3]) - float(r[1])) * 0.5)
		return maxf(absf(pt.x - c2.x) / hx, absf(pt.y - c2.y) / hz)
	if S.has("capsule"):
		var cp: Array = S["capsule"]
		var a := Vector2(float(cp[0]), float(cp[1]))
		var b := Vector2(float(cp[2]), float(cp[3]))
		return Geometry2D.get_closest_point_to_segment(pt, a, b).distance_to(pt) / maxf(0.5, float(S["r"]))
	if S.has("poly"):
		# a hand-drawn outline: 1 on the line, falling to 0 six tiles inside (so the coast's wobble
		# and the underside's depth work the same as for the round shapes)
		var P := poly_pts(S)
		var dmin := 1e9
		for k in P.size():
			dmin = minf(dmin, Geometry2D.get_closest_point_to_segment(pt, P[k], P[(k + 1) % P.size()]).distance_to(pt))
		return 1.0 - minf(dmin, 6.0) / 6.0 if Geometry2D.is_point_in_polygon(pt, P) else 1.0 + dmin / 6.0
	return 99.0

static func poly_pts(S: Dictionary) -> PackedVector2Array:
	var P := PackedVector2Array()
	for q in S["poly"]:
		P.append(v2(q))
	return P

static func shape_box(S: Dictionary) -> Rect2:
	if S.has("circle"):
		var c := v2(S["circle"])
		var r := float(S["r"]) + 3.0
		return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	if S.has("ellipse"):
		var c2 := v2(S["ellipse"])
		var r2 := maxf(float(S["rx"]), float(S["rz"])) + 3.0
		return Rect2(c2 - Vector2(r2, r2), Vector2(r2, r2) * 2.0)
	if S.has("rect"):
		var r: Array = S["rect"]
		var at := Vector2(float(r[0]), float(r[1])) - Vector2(2, 2)
		return Rect2(at, Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1])) + Vector2(4, 4))
	if S.has("capsule"):
		var cp: Array = S["capsule"]
		var rr := float(S["r"]) + 2.0
		var a := Vector2(float(cp[0]), float(cp[1]))
		var b := Vector2(float(cp[2]), float(cp[3]))
		return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(rr, rr), (b - a).abs() + Vector2(rr, rr) * 2.0)
	if S.has("poly"):
		var P := poly_pts(S)
		var bb := Rect2(P[0], Vector2.ZERO)
		for q in P:
			bb = bb.expand(q)
		return bb.grow(3.0)
	return Rect2()

## One island's tiles: for every tile of its shapes' box (x0..x1 by z0..z1, `cols` to a row), the terrace
## level ("lv", -1 where no shape covers it) and the distance from the outline shape ("d0", for the
## underside's depth). {} for an island without shapes. `seed` seeds the coast noise (the layout's).
static func island(def: Dictionary, w: int, h: int, seed: int) -> Dictionary:
	# its own copy of the layout and its own noise: shared ones cost every thread an atomic refcount per read
	var D := def.duplicate(true)
	var shapes: Array = D.get("shapes", [])
	var nz := FastNoiseLite.new()
	nz.seed = seed
	nz.frequency = COAST_FREQ
	if shapes.is_empty():
		return {}
	var nk := float(D.get("noise", 0.12))
	var box := shape_box(shapes[0])
	for S in shapes:
		box = box.merge(shape_box(S))
	var x0 := maxi(1, int(box.position.x))
	var x1 := maxi(x0, mini(w - 1, int(box.end.x) + 1))
	var z0 := maxi(1, int(box.position.y))
	var z1 := maxi(z0, mini(h - 1, int(box.end.y) + 1))
	var cols := x1 - x0
	var lvs := PackedInt32Array()
	lvs.resize(cols * (z1 - z0))
	var d0s := PackedFloat32Array()
	d0s.resize(cols * (z1 - z0))
	for z in range(z0, z1):
		for x in range(x0, x1):
			var pt := Vector2(x + 0.5, z + 0.5)
			var lv := -1
			var d0 := 99.0
			for si in shapes.size():
				var S: Dictionary = shapes[si]
				var sd := shape_d(S, pt)
				# the outline gets a gentle natural coast; terraces inside are crisp, deliberate shapes
				var n := nz.get_noise_2d(x, z) * nk if si == 0 else 0.0
				if si == 0:
					d0 = sd
				if sd + n < 1.0:
					if S.get("cut", false):
						lv = -1
						break
					lv = maxi(lv, int(S.get("lv", 0)))
			var k := (z - z0) * cols + x - x0
			lvs[k] = lv
			d0s[k] = d0
	return {"x0": x0, "x1": x1, "z0": z0, "z1": z1, "cols": cols, "lv": lvs, "d0": d0s}
