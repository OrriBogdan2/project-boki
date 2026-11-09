extends RefCounted
## Draws a World's tile grid as clean, deliberate terrain. Only the look changes: walking, heights,
## ramps and which rims you can grab all still follow the tiles exactly.
##
## Every terrace edge is traced as a contour between tile centres (marching squares), so straight
## runs stay straight, one-tile staircases become clean diagonals and corners are rounded off instead
## of reading as stacked cubes. Each contour is extruded into a cliff with a profile that tells you
## what it is: a soft grassy bevel on terrace steps, a pale stone ledge that sticks out on rims you can
## grab, and a smooth dark slate face on the sheer ones. Under each island hangs a tapered, faceted
## rock cone instead of a slab, and stairs are drawn as carved stone flights with side walls.

const LEVEL := 0.8
const RIM := 1.5           # how far an island's outer cliff drops before the rock underneath tapers in
const ROWS := 6            # rows in every cliff profile (shared points must line up between cells)

# style codes, passed to the terrain shader in UV.x (0 = legacy meshes that pick by normal)
const S_TOP := 1.0
const S_ROCK := 2.0
const S_SHEER := 3.0
const S_UNDER := 4.0
const S_CAP := 5.0
const S_STONE := 6.0

enum { E_TERRACE, E_LIP, E_SHEER, E_COAST }

const PAD := 4
const AROUND8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
var W: Node
var w := 0
var h := 0
var pw := 0
var vals := PackedInt32Array()     # padded grid of levels, -1 for the void (and plank bridges)
var tops := PackedColorArray()     # per tile: the ground colour at its centre
var under := PackedFloat32Array()  # per tile: the height of the island's underside below it
var rn := FastNoiseLite.new()
var _s := {}
var _x := {}

## Spots along grassy rims where a fringe of grass can hang over the edge: [Vector3, outward Vector3, tile].
var rims: Array = []

var V := PackedVector3Array()
var N := PackedVector3Array()
var C := PackedColorArray()
var UV := PackedVector2Array()

func _init(world: Node) -> void:
	W = world
	w = W.w; h = W.h
	pw = w + PAD * 2
	rn.seed = int(W.rng.seed) + 77
	rn.frequency = 0.9

func v(x: int, z: int) -> int:
	return vals[(z + PAD) * pw + x + PAD]

## Builds the whole terrain mesh.
func build() -> ArrayMesh:
	await _emit(0)
	return _mesh(V, N, C, UV)

## The same terrain split into square chunks of `chunk` tiles, so the camera (and each shadow
## cascade) only draws the ground it can see: [[Vector2i chunk, ArrayMesh], ...]. Cells are traced
## row by row, so each chunk is a run of slices of the one big set of arrays.
func build_chunked(chunk: int) -> Array:
	await _emit(chunk)
	var by := {}
	await W._slice()
	for r in _ranges:
		var key: Vector2i = r[0]
		if int(r[2]) <= int(r[1]):
			continue
		if not by.has(key): by[key] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array()]
		var a: Array = by[key]
		a[0].append_array(V.slice(r[1], r[2])); a[1].append_array(N.slice(r[1], r[2]))
		a[2].append_array(C.slice(r[1], r[2])); a[3].append_array(UV.slice(r[1], r[2]))
	var out: Array = []
	for key in by:
		await W._slice()
		var a: Array = by[key]
		out.append([key, _mesh(a[0], a[1], a[2], a[3])])
	return out

var _ranges: Array = []     # [chunk, first vertex, end vertex] in the order they were traced

func _emit(chunk: int) -> void:
	_fill_grid()
	await W._slice()
	_fill_colors()
	await W._slice()
	_fill_under()
	_ranges.clear()
	for cz in range(-1, h):
		await W._slice()       # under the loading screen: a frame now and then (never waits in one-go builds)
		var cur := Vector2i(-99, -99)
		var start := V.size()
		for cx in range(-1, w):
			if chunk > 0:
				var key := Vector2i(clampi(cx, 0, w - 1) / chunk, clampi(cz, 0, h - 1) / chunk)
				if key != cur:
					if cur.x != -99: _ranges.append([cur, start, V.size()])
					cur = key; start = V.size()
			_cell(cx, cz)
		if chunk > 0 and cur.x != -99: _ranges.append([cur, start, V.size()])
	await W._slice()
	# each flight is drawn as one piece across its whole width (its steps run unbroken from one side
	# wall to the other), not tile by tile: per-tile steps restarted their stones, joints and landing
	# at every tile edge, so a 5-wide flight read as five one-block stairs side by side
	for F in PolishTools.stair_flights(W):
		await W._slice()
		var tiles: Array = F["tiles"]
		var lv0: int = W.level[W.idx(tiles[0].x, tiles[0].y)]
		if tiles.any(func(q): return W.kind[W.idx(q.x, q.y)] == W.T_VOID or W.level[W.idx(q.x, q.y)] != lv0):
			for q in tiles:
				var i: int = W.idx(q.x, q.y)
				if W.kind[i] == W.T_VOID: continue
				var s0 := V.size()
				_stairs(q.x, q.y, F["dir"], W.level[i] * LEVEL)
				if chunk > 0: _ranges.append([Vector2i(q.x / chunk, q.y / chunk), s0, V.size()])
			continue
		var org := _flight_origin(tiles, F["dir"])
		var mid: Vector2i = tiles[tiles.size() / 2]
		var s1 := V.size()
		_stairs(org.x, org.y, F["dir"], W.level[W.idx(org.x, org.y)] * LEVEL, tiles.size())
		if chunk > 0: _ranges.append([Vector2i(mid.x / chunk, mid.y / chunk), s1, V.size()])

func _mesh(vv: PackedVector3Array, nn: PackedVector3Array, cc: PackedColorArray, uu: PackedVector2Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vv
	arr[Mesh.ARRAY_NORMAL] = nn
	arr[Mesh.ARRAY_COLOR] = cc
	arr[Mesh.ARRAY_TEX_UV] = uu
	var m := ArrayMesh.new()
	if vv.size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## A small texture of tile heights (R) and blockers (G), for the shader's soft contact shadows.
func height_texture() -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for z in h:
		for x in w:
			var lv := v(x, z)
			# b: 1 over the abyss, 0.5 on ground touching it (8 around), 0 elsewhere. The terrain shader tells an
			# abyss edge from a terrace lip by it (docs/EDGE_READ.md); the level in r can't, once filtered.
			var vb := 1.0 if lv < 0 else 0.0
			if lv >= 0:
				for d in AROUND8:
					if v(x + d.x, z + d.y) < 0:   # PAD keeps the map border in range (void)
						vb = 0.5
						break
			# rocks, trees and walls darken the ground at their feet (buildings and other set pieces
			# marked no_deco bring their own shadows)
			var i: int = W.idx(x, z)
			var blk := 1.0 if lv >= 0 and W.kind[i] == W.T_BLOCK and not W.no_deco.has(i) else 0.0
			img.set_pixel(x, z, Color(float(lv + 1) / 32.0, blk, vb))
	return ImageTexture.create_from_image(img)

# ------------------------------------------------------------------ grid data
func _fill_grid() -> void:
	vals.resize(pw * (h + PAD * 2)); vals.fill(-1)
	for z in h:
		for x in w:
			var i: int = z * w + x
			if W.kind[i] != W.T_VOID and not W.bridge.has(i):
				vals[(z + PAD) * pw + x + PAD] = int(W.level[i])

func _fill_colors() -> void:
	tops.resize(w * h)
	var tn := FastNoiseLite.new(); tn.seed = int(W.rng.seed) + 3; tn.frequency = 0.3
	var lip_paint := Color("dccb9c"); var sheer_paint := Color("7d7896")
	for z in h:
		for x in w:
			var i: int = z * w + x
			if v(x, z) < 0:
				continue
			var bio: Dictionary = W._bio(i)
			var cx := x + 0.5; var cz := z + 0.5
			var nv := tn.get_noise_2d(cx * 0.6, cz * 0.6) * 0.5 + 0.5
			var nv2 := tn.get_noise_2d(cx * 2.1 + 40.0, cz * 2.1) * 0.5 + 0.5
			var col: Color = Color(bio["top"]).lerp(bio["top2"], nv).lerp(Color(bio["top"]).lightened(0.08), nv2 * 0.35)
			col = col.lightened(0.03 * W.level[i])
			# paths and soil: blend the paint of this tile and its neighbours, so paths have soft edges.
			# (The rim paints that used to mark grabbable and sheer rims are drawn by the cliff now.)
			var pc := Color(0, 0, 0, 0); var wsum := 0.0
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var tx := x + dx; var tz := z + dz
					if tx < 0 or tz < 0 or tx >= w or tz >= h:
						continue
					var j: int = tz * w + tx
					if not W.paint.has(j):
						continue
					var p: Color = W.paint[j]
					if p == lip_paint or p == sheer_paint:
						continue
					var wt := 1.0 if dx == 0 and dz == 0 else (0.35 if dx == 0 or dz == 0 else 0.2)
					pc += p * wt; wsum += wt
			if wsum > 0.0:
				col = col.lerp(pc / wsum, clampf(wsum / 1.2, 0.0, 1.0) * (0.85 + nv2 * 0.15))
			tops[i] = col

## The underside of each island: a cone of rock that tapers in from the rim, deepest under the
## middle, as in a floating island.
func _fill_under() -> void:
	under.resize(w * h); under.fill(0.0)
	var d := PackedFloat32Array(); d.resize(w * h)
	var big := 1.0e6
	for i in w * h:
		d[i] = big if v(i % w, i / w) >= 0 else 0.0
	var dg := 1.4142
	# two-pass chamfer distance to the nearest void tile
	for z in h:
		for x in w:
			var i: int = z * w + x
			if d[i] == 0.0: continue
			var best: float = d[i]
			best = minf(best, (d[i - 1] if x > 0 else 0.0) + 1.0)
			best = minf(best, (d[i - w] if z > 0 else 0.0) + 1.0)
			best = minf(best, (d[i - w - 1] if x > 0 and z > 0 else 0.0) + dg)
			best = minf(best, (d[i - w + 1] if x < w - 1 and z > 0 else 0.0) + dg)
			d[i] = best
	for z in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i: int = z * w + x
			if d[i] == 0.0: continue
			var best: float = d[i]
			best = minf(best, (d[i + 1] if x < w - 1 else 0.0) + 1.0)
			best = minf(best, (d[i + w] if z < h - 1 else 0.0) + 1.0)
			best = minf(best, (d[i + w + 1] if x < w - 1 and z < h - 1 else 0.0) + dg)
			best = minf(best, (d[i + w - 1] if x > 0 and z < h - 1 else 0.0) + dg)
			d[i] = best
	# soften it, so diagonal coasts and thin necks don't alternate deep and shallow tile by tile
	for _pass in 2:
		var sm := d.duplicate()
		for z in range(1, h - 1):
			for x in range(1, w - 1):
				var i: int = z * w + x
				if d[i] <= 0.0: continue
				var sum := 0.0
				for o in [i - 1, i + 1, i - w, i + w, i - w - 1, i - w + 1, i + w - 1, i + w + 1]:
					sum += d[o]
				sm[i] = maxf(0.5, (d[i] * 2.0 + sum) / 10.0)
		d = sm
	var reach := {}
	for i in w * h:
		if d[i] > 0.0:
			var ii: int = W.island[i]
			reach[ii] = maxf(float(reach.get(ii, 1.0)), d[i] - 0.5)
	for i in w * h:
		if d[i] <= 0.0:
			continue
		var x := i % w; var z := i / w
		var R: float = maxf(1.5, float(reach.get(W.island[i], 1.5)))
		var dc := d[i] - 0.5
		var deep := clampf(3.0 + R * 0.7, 4.0, 15.0)
		var t := clampf(dc / R, 0.0, 1.0)
		var taper := deep * pow(t, 0.62)
		taper *= 1.0 + rn.get_noise_2d(x * 0.31 + 50.0, z * 0.31) * 0.28
		under[i] = v(x, z) * LEVEL - _rim(Vector2(x + 0.5, z + 0.5)) - taper

func _rim(p: Vector2) -> float:
	return RIM + rn.get_noise_2d(p.x * 0.45, p.y * 0.45) * 0.35

# ------------------------------------------------------------------ contours
## Smoothed "how inside" a tile is for threshold t: a 5x5 binomial blur of (level >= t), 0..1.
const BW := [1.0, 4.0, 6.0, 4.0, 1.0]
func _sv(x: int, z: int, t: int) -> float:
	var key := ((z + PAD) * pw + x + PAD) * 64 + t
	if _s.has(key):
		return _s[key]
	var n := 0.0
	for dz in 5:
		var row := 0.0
		for dx in 5:
			if v(x + dx - 2, z + dz - 2) >= t: row += BW[dx]
		n += row * BW[dz]
	n /= 256.0
	_s[key] = n
	return n

## Where the contour for threshold t crosses the edge between tile centres a (inside) and b (outside):
## {p: Vector2, n: outward Vector2, void: bool, style, rim: float, a: tile index}.
func _cross(ax: int, az: int, bx: int, bz: int, t: int) -> Dictionary:
	var vb := v(bx, bz)
	var te := 0 if vb < 0 else t     # a coastline is one line, whichever terrace meets it
	var ex := mini(ax, bx); var ez := mini(az, bz)
	var key := (((ez + PAD) * pw + ex + PAD) * 2 + (0 if az == bz else 1)) * 64 + te
	if _x.has(key):
		return _x[key]
	# where the blurred field crosses one half: straight runs stay put, shallow staircases line up
	# into straight slopes and corners round off (clamped, so the drawn edge never strays far)
	var sa := _sv(ax, az, te); var sb := _sv(bx, bz, te)
	var f := 0.5
	if sa > 0.5 and sb < 0.5:
		f = clampf((sa - 0.5) / (sa - sb), 0.15, 0.85)
	elif sa <= 0.5:
		f = 0.3
	else:
		f = 0.7
	var A := Vector2(ax + 0.5, az + 0.5); var B := Vector2(bx + 0.5, bz + 0.5)
	var p := A + (B - A) * f
	var g := Vector2(_sv(ax + 1, az, te) - _sv(ax - 1, az, te) + _sv(bx + 1, bz, te) - _sv(bx - 1, bz, te),
		_sv(ax, az + 1, te) - _sv(ax, az - 1, te) + _sv(bx, bz + 1, te) - _sv(bx, bz - 1, te))
	var n := -g
	var ab := (B - A)
	if n.length() < 0.01 or n.normalized().dot(ab) < 0.15:
		n = ab
	n = n.normalized()
	var ia := -1
	if ax >= 0 and az >= 0 and ax < w and az < h: ia = az * w + ax
	var style := E_TERRACE
	var rim := 0.0
	if vb < 0:
		style = E_COAST
		if ia >= 0 and W.sheer.has(ia): style = E_SHEER
		elif ia >= 0 and W.lip.has(ia): style = E_LIP
		rim = v(ax, az) * LEVEL - _rim(p)
	var ib := -1
	if bx >= 0 and bz >= 0 and bx < w and bz < h: ib = bz * w + bx
	var out := {"p": p, "n": n, "void": vb < 0, "style": style, "rim": rim, "a": ia, "b": ib, "ground": maxi(vb, 0) * LEVEL}
	_x[key] = out
	return out

const CX := [0, 1, 1, 0]
const CZ := [0, 0, 1, 1]

func _cell(cx: int, cz: int) -> void:
	var vs := [v(cx, cz), v(cx + 1, cz), v(cx + 1, cz + 1), v(cx, cz + 1)]
	if vs[0] == vs[1] and vs[1] == vs[2] and vs[2] == vs[3]:
		if vs[0] < 0:
			return
		var ps: Array = []; var cols: Array = []; var us: Array = []
		for k in 4:
			var tx: int = cx + CX[k]; var tz: int = cz + CZ[k]
			ps.append(Vector2(tx + 0.5, tz + 0.5))
			cols.append(tops[tz * w + tx])
			us.append(under[tz * w + tx])
		var y: float = vs[0] * LEVEL
		_tri3(Vector3(ps[0].x, y, ps[0].y), Vector3(ps[1].x, y, ps[1].y), Vector3(ps[2].x, y, ps[2].y), Vector3.UP, cols[0], cols[1], cols[2], S_TOP, true)
		_tri3(Vector3(ps[0].x, y, ps[0].y), Vector3(ps[2].x, y, ps[2].y), Vector3(ps[3].x, y, ps[3].y), Vector3.UP, cols[0], cols[2], cols[3], S_TOP, true)
		var bio: Dictionary = W._bio(cz * w + cx if cx >= 0 and cz >= 0 else 0)
		_under_tri([Vector3(ps[0].x, us[0], ps[0].y), Vector3(ps[1].x, us[1], ps[1].y), Vector3(ps[2].x, us[2], ps[2].y)], [vs[0], vs[1], vs[2]], bio)
		_under_tri([Vector3(ps[0].x, us[0], ps[0].y), Vector3(ps[2].x, us[2], ps[2].y), Vector3(ps[3].x, us[3], ps[3].y)], [vs[0], vs[2], vs[3]], bio)
		return
	var vmin: int = mini(mini(vs[0], vs[1]), mini(vs[2], vs[3]))
	var smin := 1 << 20
	var distinct: Array = []
	for k in 4:
		if vs[k] >= 0:
			smin = mini(smin, vs[k])
			if not distinct.has(vs[k]): distinct.append(vs[k])
	if distinct.is_empty():
		return
	distinct.sort()
	var bio: Dictionary = {}
	for k in 4:
		if vs[k] >= 0:
			bio = W._bio((cz + CZ[k]) * w + cx + CX[k]) if cx + CX[k] >= 0 and cz + CZ[k] >= 0 and cx + CX[k] < w and cz + CZ[k] < h else W.biome
			break
	for t in distinct:
		var poly := _walk(cx, cz, vs, t)
		# ground at this terrace's height (hidden wherever a higher terrace covers it)
		var y: float = t * LEVEL
		var pts: Array = poly[0]; var cols: Array = poly[1]
		for k in range(1, pts.size() - 1):
			_tri3(Vector3(pts[0].x, y, pts[0].y), Vector3(pts[k].x, y, pts[k].y), Vector3(pts[k + 1].x, y, pts[k + 1].y), Vector3.UP, cols[0], cols[k], cols[k + 1], S_TOP, true)
		if t > vmin:
			for seg in poly[2]:
				_wall(seg[0], seg[1], y, smin * LEVEL)
	# the island's underside
	if vmin < 0:
		var up := _walk(cx, cz, vs, 0)
		var pts: Array = up[0]; var info: Array = up[3]
		var p3: Array = []; var lv: Array = []
		for k in pts.size():
			var inf = info[k]
			if inf is Dictionary:
				p3.append(Vector3(pts[k].x, inf["rim"], pts[k].y)); lv.append(-1)
			else:
				var ti: int = inf
				p3.append(Vector3(pts[k].x, under[ti], pts[k].y)); lv.append(vals[(ti / w + PAD) * pw + ti % w + PAD])
		for k in range(1, p3.size() - 1):
			_under_tri([p3[0], p3[k], p3[k + 1]], [lv[0], lv[k], lv[k + 1]], bio)
	else:
		var us: Array = []
		for k in 4:
			var tx: int = cx + CX[k]; var tz: int = cz + CZ[k]
			us.append(Vector3(tx + 0.5, under[tz * w + tx], tz + 0.5))
		_under_tri([us[0], us[1], us[2]], [vs[0], vs[1], vs[2]], bio)
		_under_tri([us[0], us[2], us[3]], [vs[0], vs[2], vs[3]], bio)

## The part of a cell at or above threshold t: [points, colours, wall segments [[exit, entry]], info]
## where info is the tile index for a corner or the crossing dictionary for a contour point.
func _walk(cx: int, cz: int, vs: Array, t: int) -> Array:
	var pts: Array = []; var cols: Array = []; var info: Array = []
	var marks: Array = []      # [crossing, is_exit]
	for k in 4:
		var k2 := (k + 1) % 4
		var ax: int = cx + CX[k]; var az: int = cz + CZ[k]
		var bx: int = cx + CX[k2]; var bz: int = cz + CZ[k2]
		var ins: bool = vs[k] >= t
		var ins2: bool = vs[k2] >= t
		if ins:
			pts.append(Vector2(ax + 0.5, az + 0.5)); cols.append(tops[az * w + ax]); info.append(az * w + ax)
		if ins and not ins2:
			var X := _cross(ax, az, bx, bz, t)
			pts.append(X["p"]); cols.append(tops[az * w + ax]); info.append(X)
			marks.append([X, true])
		elif ins2 and not ins:
			var X2 := _cross(bx, bz, ax, az, t)
			pts.append(X2["p"]); cols.append(tops[bz * w + bx]); info.append(X2)
			marks.append([X2, false])
	var segs: Array = []
	var n := marks.size()
	for m in n:
		if marks[m][1]:
			for q in range(1, n + 1):
				var e: Array = marks[(m + q) % n]
				if not e[1]:
					segs.append([marks[m][0], e[0]])
					break
	return [pts, cols, segs, info]

# ------------------------------------------------------------------ cliffs
## One stretch of cliff between two contour points: the same row profile at both ends, so cliffs
## join up seamlessly from cell to cell. Where the ground below differs between the two ends, a
## plain skirt under the profile reaches down to the cell's lowest ground, so nothing shows through.
func _wall(P: Dictionary, Q: Dictionary, top: float, ground: float) -> void:
	var rp := _profile(P, top)
	var rq := _profile(Q, top)
	_note_rim(P, Q, top)
	var nref: Vector2 = (P["n"] + Q["n"])
	var n3 := Vector3(nref.x, 0, nref.y).normalized()
	for r in ROWS - 1:
		var a: Vector3 = rp[r][0]; var b: Vector3 = rq[r][0]
		var c: Vector3 = rq[r + 1][0]; var d: Vector3 = rp[r + 1][0]
		var st: float = rp[r][2]
		var fn := (b - a).cross(d - a)
		if fn.length_squared() < 1e-8:
			fn = (c - b).cross(d - b)
		if fn.length_squared() < 1e-8:
			fn = (c - a).cross(d - a)
		if fn.length_squared() < 1e-8:
			continue
		fn = fn.normalized()
		if fn.dot(n3) < 0.0:
			fn = -fn
		if st == S_SHEER:
			var np := Vector3(P["n"].x, 0.0, P["n"].y); var nq := Vector3(Q["n"].x, 0.0, Q["n"].y)
			_quad_n(a, b, c, d, np, nq, nq, np, rp[r][1], rq[r][1], rq[r + 1][1], rp[r + 1][1], st, fn)
		else:
			_quad_n(a, b, c, d, fn, fn, fn, fn, rp[r][1], rq[r][1], rq[r + 1][1], rp[r + 1][1], st, fn)
	if P["void"] and Q["void"]:
		return
	var bp: Vector3 = rp[ROWS - 1][0]; var bq: Vector3 = rq[ROWS - 1][0]
	var sk := minf(minf(bp.y, bq.y), ground)
	if bp.y - sk < 0.01 and bq.y - sk < 0.01:
		return
	var cl: Color = rp[ROWS - 1][1]
	_quad_n(bp, bq, Vector3(bq.x, sk, bq.z), Vector3(bp.x, sk, bp.z), n3, n3, n3, n3, cl, cl, cl, cl, S_ROCK, n3)

func _note_rim(P: Dictionary, Q: Dictionary, top: float) -> void:
	if int(P["style"]) in [E_LIP, E_SHEER] or int(Q["style"]) in [E_LIP, E_SHEER]:
		return
	for X in [P, Q]:
		var a: int = X["a"]; var b: int = X["b"]
		if a < 0 or absf(W.level[a] * LEVEL - top) > 0.01 or W.stairs.has(a) or (b >= 0 and W.stairs.has(b)) or W.kind[a] != W.T_GROUND:
			return
	var m: Vector2 = (P["p"] + Q["p"]) * 0.5
	var n: Vector2 = (P["n"] + Q["n"]).normalized()
	rims.append([Vector3(m.x, top, m.y), Vector3(n.x, 0, n.y), int(P["a"])])

## The cross-section of a cliff at one contour point: ROWS of [position, colour, style of the band
## below]. Depends only on the point and the terrace height, so neighbouring cells agree.
func _profile(X: Dictionary, top: float) -> Array:
	var p: Vector2 = X["p"]; var n: Vector2 = X["n"]
	var ia: int = X["a"]
	var bio: Dictionary = W._bio(ia) if ia >= 0 else W.biome
	var style: int = X["style"]
	var bottom: float = minf(X["rim"], top - 0.3) if X["void"] else float(X["ground"])
	var H := top - bottom
	var side: Color = bio["side"]
	var deep: Color = bio["deep"]
	var topc: Color = Color(bio["top2"]).lerp(bio["top"], 0.4)
	var jit := rn.get_noise_2d(p.x * 3.1 + 7.0, p.y * 3.1 - 3.0) * 0.13
	var jit2 := rn.get_noise_2d(p.x * 2.3 - 11.0, p.y * 2.3 + 5.0) * 0.08
	var rows: Array      # [out offset, y, colour, style of the band below this row]
	match style:
		E_LIP:
			# a ledge you can grab: a pale stone lip that sticks out over the rock
			var stone := Color("e9dcb6").lerp(side, 0.12)
			rows = [[0.0, top, stone.lightened(0.12), S_CAP], [0.17, top - 0.035, stone.lightened(0.1), S_CAP],
				[0.17, top - 0.25, stone.darkened(0.12), S_CAP], [0.02, top - 0.34, side.darkened(0.25), S_ROCK],
				[0.04 + jit, top - 0.34 - (H - 0.34) * 0.45, side.darkened(0.05), S_ROCK], [0.0, bottom, side.lerp(deep, 0.55), S_ROCK]]
		E_SHEER:
			# nothing to hold on to: smooth dark slate from top to bottom
			var slate := Color("5a5373").lerp(deep, 0.2)
			rows = [[0.0, top, slate.lightened(0.28), S_SHEER], [0.03, top - 0.03, slate.lightened(0.2), S_SHEER],
				[0.03, top - 0.09, slate.lightened(0.05), S_SHEER], [0.02, top - 0.12, slate, S_SHEER],
				[0.01, top - 0.12 - (H - 0.12) * 0.5, slate.lerp(deep, 0.3), S_SHEER], [0.0, bottom, deep.darkened(0.2), S_SHEER]]
		E_COAST:
			rows = [[0.0, top, topc.lightened(0.06), S_CAP], [0.08, top - 0.04, topc, S_CAP],
				[0.08, top - 0.17, topc.darkened(0.22), S_CAP], [0.0, top - 0.24, side.darkened(0.12), S_ROCK],
				[0.03 + jit, top - 0.24 - (H - 0.24) * 0.5, side, S_ROCK], [0.0, bottom, side.lerp(deep, 0.6), S_ROCK]]
		_:
			# a terrace step: a soft grassy bevel over a short face of earth and rock
			rows = [[0.0, top, topc.lightened(0.18), S_CAP], [0.06, top - 0.03, topc.lightened(0.1), S_CAP],
				[0.06, top - 0.13, topc.darkened(0.18), S_CAP], [0.0, top - 0.19, side.darkened(0.06), S_ROCK],
				[0.025 + jit2, top - 0.19 - (H - 0.19) * 0.5, side.darkened(0.2), S_ROCK], [0.0, bottom, side.darkened(0.5), S_ROCK]]
	var out: Array = []
	for r in rows:
		out.append([Vector3(p.x + n.x * float(r[0]), float(r[1]), p.y + n.y * float(r[0])), r[2], r[3]])
	return out

# ------------------------------------------------------------------ underside
func _under_tri(p: Array, _lv: Array, bio: Dictionary) -> void:
	var a: Vector3 = p[0]; var b: Vector3 = p[1]; var c: Vector3 = p[2]
	var fn := (b - a).cross(c - a)
	if fn.length_squared() < 1e-10:
		return
	fn = fn.normalized()
	if fn.y > 0.0: fn = -fn
	var side: Color = bio.get("side", Color("8b6d52"))
	var deep: Color = bio.get("deep", Color("3a3140"))
	var cols: Array = []
	for q in p:
		var y: float = (q as Vector3).y
		var k := clampf((-y - 0.5) / 14.0, 0.0, 1.0)
		cols.append(side.darkened(0.12).lerp(deep.darkened(0.15), sqrt(k)))
	_tri3(a, b, c, fn, cols[0], cols[1], cols[2], S_UNDER, false)

# ------------------------------------------------------------------ stairs
## The tile a flight's "across" coordinate starts from: _stairs maps s = 0..1 across tile (x, z) in
## a direction that depends on dir, so the flight's s = 0..span runs from this end tile on.
func _flight_origin(tiles: Array, dir: Vector2i) -> Vector2i:
	var across: Vector2
	match dir:
		Vector2i(1, 0): across = Vector2(0, 1)
		Vector2i(-1, 0): across = Vector2(0, -1)
		Vector2i(0, 1): across = Vector2(-1, 0)
		_: across = Vector2(1, 0)
	var best: Vector2i = tiles[0]
	for q in tiles:
		if Vector2(q).dot(across) < Vector2(best).dot(across): best = q
	return best

## A carved stone flight rising toward dir, `span` tiles wide starting at tile (x, z) (see
## _flight_origin), with stone side walls where the flight ends.
func _stairs(x: int, z: int, dir: Vector2i, y: float, span := 1) -> void:
	var i := z * w + x
	var bio: Dictionary = W._bio(i)
	var stone := Color("cdc4b2").lerp(Color(bio["side"]), 0.22).lerp(Color(bio["top"]), 0.08)
	var n := 4
	var to_world := func(u: float, s: float, hgt: float) -> Vector3:
		var fx: float; var fz: float
		match dir:
			Vector2i(1, 0): fx = u; fz = s
			Vector2i(-1, 0): fx = 1.0 - u; fz = 1.0 - s
			Vector2i(0, 1): fx = 1.0 - s; fz = u
			_: fx = s; fz = 1.0 - u
		return Vector3(x + fx, y + hgt, z + fz)
	var upv := Vector3(dir.x, 0, dir.y)
	var side_a := Vector3(-dir.y, 0, dir.x)
	# which ends of the flight need a side wall
	var cheeks: Array = []
	var L := float(span)
	for sv in [0.0, 1.0]:
		var sd: Vector3 = to_world.call(0.5, -0.5 if sv == 0.0 else L + 0.5, 0.0)
		var nx := int(floor(sd.x)); var nz := int(floor(sd.z))
		var j := nz * w + nx
		var same: bool = nx >= 0 and nz >= 0 and nx < w and nz < h and W.stairs.has(j) and W.stairs[j] == dir
		cheeks.append(not same)
	var s0 := 0.13 if cheeks[0] else 0.0
	var s1 := L - 0.13 if cheeks[1] else L
	if Flora.v2():
		_stairs_cut(x, z, dir, y, to_world, upv, side_a, cheeks, s0, s1, bio, L)
		return
	if span > 1:
		# the first art pass's flight is drawn a tile at a time
		var step := Vector2i(int(round((to_world.call(0.5, 1.5, 0.0) - to_world.call(0.5, 0.5, 0.0)).x)), int(round((to_world.call(0.5, 1.5, 0.0) - to_world.call(0.5, 0.5, 0.0)).z)))
		for k in span:
			_stairs(x + step.x * k, z + step.y * k, dir, y)
		return
	for k in n:
		var u0 := float(k) / n; var u1 := float(k + 1) / n
		var hgt := LEVEL * float(k + 1) / n
		var tread := stone.lightened(0.07 if k % 2 == 0 else 0.0)
		var nose := 0.035
		# tread, with a little nosing over the riser below
		_quad_n(to_world.call(u0 - nose, s0, hgt), to_world.call(u1, s0, hgt), to_world.call(u1, s1, hgt), to_world.call(u0 - nose, s1, hgt),
			Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, tread.lightened(0.05), tread, tread, tread.lightened(0.05), S_STONE, Vector3.UP)
		# the nosing's front lip and the riser, in shadow under it
		_quad_n(to_world.call(u0 - nose, s0, hgt - 0.05), to_world.call(u0 - nose, s1, hgt - 0.05), to_world.call(u0 - nose, s1, hgt), to_world.call(u0 - nose, s0, hgt),
			-upv, -upv, -upv, -upv, tread.darkened(0.05), tread.darkened(0.05), tread, tread, S_STONE, -upv)
		_quad_n(to_world.call(u0, s0, hgt - LEVEL / n), to_world.call(u0, s1, hgt - LEVEL / n), to_world.call(u0, s1, hgt - 0.05), to_world.call(u0, s0, hgt - 0.05),
			-upv, -upv, -upv, -upv, stone.darkened(0.38), stone.darkened(0.38), stone.darkened(0.24), stone.darkened(0.24), S_STONE, -upv)
	# side walls: a sloped stone parapet along each open end of the flight
	for q in 2:
		if not cheeks[q]:
			continue
		var sa: float = 0.0 if q == 0 else 0.87
		var sb: float = 0.13 if q == 0 else 1.0
		var outn: Vector3 = -side_a if q == 0 else side_a
		var cs := stone.darkened(0.08)
		var t0 := 0.32; var t1 := LEVEL + 0.12
		var lo := -0.05
		var A0: Vector3 = to_world.call(-0.02, sa, lo); var A1: Vector3 = to_world.call(1.0, sa, lo)
		var B0: Vector3 = to_world.call(-0.02, sb, lo); var B1: Vector3 = to_world.call(1.0, sb, lo)
		var TA0: Vector3 = to_world.call(-0.02, sa, t0); var TA1: Vector3 = to_world.call(1.0, sa, t1)
		var TB0: Vector3 = to_world.call(-0.02, sb, t0); var TB1: Vector3 = to_world.call(1.0, sb, t1)
		var cap := cs.lightened(0.16)
		var ramp := (TA1 - TA0).normalized().cross(outn).normalized()
		if ramp.y < 0.0: ramp = -ramp
		_quad_n(TA0, TA1, TB1, TB0, ramp, ramp, ramp, ramp, cap, cap, cap, cap, S_STONE, ramp)
		var outer := [A0, A1, TA1, TA0] if q == 0 else [B0, B1, TB1, TB0]
		var inner := [B0, B1, TB1, TB0] if q == 0 else [A0, A1, TA1, TA0]
		_quad_n(outer[0], outer[1], outer[2], outer[3], outn, outn, outn, outn, cs.darkened(0.3), cs.darkened(0.3), cs, cs, S_STONE, outn)
		_quad_n(inner[0], inner[1], inner[2], inner[3], -outn, -outn, -outn, -outn, cs.darkened(0.35), cs.darkened(0.35), cs.darkened(0.05), cs.darkened(0.05), S_STONE, -outn)
		_quad_n(A0, B0, TB0, TA0, -upv, -upv, -upv, -upv, cs.darkened(0.3), cs.darkened(0.3), cs.darkened(0.1), cs.darkened(0.1), S_STONE, -upv)

## The second art pass's flight: each step laid from two or three cut stones with chiselled, worn
## edges and dark joints, set a little unevenly, moss creeping in at the sides (snow, ash or petals
## by biome), and side walls built of chunky blocks with a bevelled coping.
func _stairs_cut(x: int, z: int, dir: Vector2i, y: float, to_world: Callable, upv: Vector3, side_a: Vector3, cheeks: Array, s0: float, s1: float, bio: Dictionary, L := 1.0) -> void:
	var n := 4
	var rr := RandomNumberGenerator.new(); rr.seed = hash(Vector2i(x, z))
	var st := Flora.style_ok(W.style_at(z * w + x))
	var stone := Color("a39a8a").lerp(Color(bio["side"]), 0.28).lerp(Color(bio["top"]), 0.06)
	var moss := Color(bio["top"]).lerp(Color("4f8a3a"), 0.4)
	match st:
		"frost": stone = Color("98a0b0").lerp(Color(bio["side"]), 0.2); moss = Color("eef4ff")
		"ember": stone = Color("857064").lerp(Color(bio["side"]), 0.2); moss = Color("4a3e3c")
		"storm": stone = Color("868ea0").lerp(Color(bio["side"]), 0.25); moss = Color(bio["top"]).lerp(Color("3f7a6a"), 0.45)
		"gloom": stone = Color("7e7590").lerp(Color(bio["side"]), 0.25); moss = Color(bio["top"]).lerp(Color("5a4a7a"), 0.35)
		"bloom": moss = Color(bio["top"]).lerp(Color("5f9a48"), 0.4)
	var joint := stone.darkened(0.6).lerp(Color("2a2430"), 0.3)
	for k in n:
		var u0 := float(k) / n; var u1 := float(k + 1) / n
		var hgt := LEVEL * float(k + 1) / n
		var nose := 0.04
		# the dark bed the stones sit in (shows as the joints between them) and the riser below
		_quad_n(to_world.call(u0 - 0.01, s0, hgt - 0.05), to_world.call(u1, s0, hgt - 0.05), to_world.call(u1, s1, hgt - 0.05), to_world.call(u0 - 0.01, s1, hgt - 0.05),
			Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, joint, joint, joint, joint, S_STONE, Vector3.UP)
		var rc := stone.darkened(0.42)
		_quad_n(to_world.call(u0, s0, hgt - LEVEL / n), to_world.call(u0, s1, hgt - LEVEL / n), to_world.call(u0, s1, hgt - 0.05), to_world.call(u0, s0, hgt - 0.05),
			-upv, -upv, -upv, -upv, rc.darkened(0.15), rc.darkened(0.15), rc, rc, S_STONE, -upv)
		# the stones of this step
		var cuts: Array = [s0]
		var at := s0 + rr.randf_range(0.25, 0.45)
		while at < s1 - 0.2:
			cuts.append(at); at += rr.randf_range(0.28, 0.5)
		cuts.append(s1)
		for q in cuts.size() - 1:
			var a0: float = float(cuts[q]) + (0.012 if q > 0 else 0.0)
			var a1: float = float(cuts[q + 1]) - (0.012 if q < cuts.size() - 2 else 0.0)
			var top := hgt + rr.randf_range(-0.015, 0.02)
			var c := stone.lightened(rr.randf_range(-0.05, 0.08))
			if rr.randf() < 0.15: c = c.lerp(Color("c8a882"), 0.15)
			var mo := [0.0, 0.0]     # moss on the stone's two ends (a0 side, a1 side)
			if q == 0 and cheeks[0]: mo[0] = rr.randf_range(0.4, 0.85)
			if q == cuts.size() - 2 and cheeks[1]: mo[1] = rr.randf_range(0.4, 0.85)
			if rr.randf() < 0.25: mo[rr.randi_range(0, 1)] = maxf(mo[0], rr.randf_range(0.3, 0.6))
			_step_stone(to_world, upv, u0 - nose + rr.randf_range(-0.01, 0.015), u1, a0, a1, hgt - 0.06, top, c, moss, mo, rr)
	# landings: a strip of flagstones at the foot and the head of the flight, so it reads as a laid
	# stairway set into the terrace rather than a chute cut into the cliff
	for land in [[-0.46, -0.03, 0.0], [1.0, 1.42, LEVEL]]:
		var la: float = land[0]; var lb: float = land[1]; var ly: float = land[2]
		var cuts2: Array = [0.0]
		var at2 := rr.randf_range(0.3, 0.55)
		while at2 < L - 0.2:
			cuts2.append(at2); at2 += rr.randf_range(0.35, 0.55)
		cuts2.append(L)
		for q in cuts2.size() - 1:
			var a0: float = float(cuts2[q]) + 0.015
			var a1: float = float(cuts2[q + 1]) - 0.015
			var c2 := stone.lightened(rr.randf_range(-0.02, 0.1))
			_step_stone(to_world, upv, la + rr.randf_range(0.0, 0.03), lb - rr.randf_range(0.0, 0.03), a0, a1, ly - 0.03, ly + 0.035 + rr.randf_range(-0.006, 0.006), c2, moss, [rr.randf_range(0.0, 0.4), rr.randf_range(0.0, 0.4)], rr)
	# newel blocks: a chunky squared stone where each side wall meets the bottom landing
	for q in 2:
		if not cheeks[q]:
			continue
		var na: float = -0.02 if q == 0 else L - 0.16
		var nb: float = 0.16 if q == 0 else L + 0.02
		var cs2 := stone.darkened(0.1)
		_block(to_world, upv, side_a, -0.3, 0.02, na, nb, -0.04, 0.56, cs2, rr)
		_block(to_world, upv, side_a, -0.33, 0.05, na - 0.025, nb + 0.025, 0.56, 0.64, cs2.lightened(0.16), rr)
	# side walls: a sloped parapet of two chunky blocks along each open end, with a coping on top
	for q in 2:
		if not cheeks[q]:
			continue
		var sa: float = 0.0 if q == 0 else L - 0.13
		var sb: float = 0.13 if q == 0 else L
		var outn: Vector3 = -side_a if q == 0 else side_a
		var cs := stone.darkened(0.06)
		for part in 2:
			var ua := -0.02 + part * 0.51
			var ub := 0.49 + part * 0.51
			var ta := lerpf(0.32, LEVEL + 0.12, (ua + 0.02) / 1.02)
			var tb := lerpf(0.32, LEVEL + 0.12, (ub + 0.02) / 1.02)
			var lo := -0.05
			var A0: Vector3 = to_world.call(ua, sa, lo); var A1: Vector3 = to_world.call(ub, sa, lo)
			var B0: Vector3 = to_world.call(ua, sb, lo); var B1: Vector3 = to_world.call(ub, sb, lo)
			var TA0: Vector3 = to_world.call(ua, sa, ta); var TA1: Vector3 = to_world.call(ub, sa, tb)
			var TB0: Vector3 = to_world.call(ua, sb, ta); var TB1: Vector3 = to_world.call(ub, sb, tb)
			var bc := cs.lightened(rr.randf_range(-0.04, 0.05))
			var outer := [A0, A1, TA1, TA0] if q == 0 else [B0, B1, TB1, TB0]
			var inner := [B0, B1, TB1, TB0] if q == 0 else [A0, A1, TA1, TA0]
			_quad_n(outer[0], outer[1], outer[2], outer[3], outn, outn, outn, outn, bc.darkened(0.42), bc.darkened(0.42), bc, bc, S_STONE, outn)
			_quad_n(inner[0], inner[1], inner[2], inner[3], -outn, -outn, -outn, -outn, bc.darkened(0.45), bc.darkened(0.45), bc.darkened(0.08), bc.darkened(0.08), S_STONE, -outn)
			_quad_n(A0, B0, TB0, TA0, -upv, -upv, -upv, -upv, bc.darkened(0.36), bc.darkened(0.36), bc.darkened(0.1), bc.darkened(0.1), S_STONE, -upv)
			# the coping: a bevelled cap a touch wider than the wall, mossy on top
			var e := 0.025
			var CA0: Vector3 = to_world.call(ua + 0.01, sa - e, ta); var CA1: Vector3 = to_world.call(ub - 0.01, sa - e, tb)
			var CB0: Vector3 = to_world.call(ua + 0.01, sb + e, ta); var CB1: Vector3 = to_world.call(ub - 0.01, sb + e, tb)
			var lift := Vector3(0, 0.07, 0)
			var bev := 0.03
			var cap := bc.lightened(0.14)
			var mtop: Color = cap.lerp(moss, rr.randf_range(0.35, 0.75)) if st != "ember" or rr.randf() < 0.5 else cap
			var ramp := (CA1 - CA0).normalized().cross(outn).normalized()
			if ramp.y < 0.0: ramp = -ramp
			var inA0: Vector3 = to_world.call(ua + 0.01 + bev, sa - e + bev, ta) + lift; var inA1: Vector3 = to_world.call(ub - 0.01 - bev, sa - e + bev, tb) + lift
			var inB0: Vector3 = to_world.call(ua + 0.01 + bev, sb + e - bev, ta) + lift; var inB1: Vector3 = to_world.call(ub - 0.01 - bev, sb + e - bev, tb) + lift
			_quad_n(inA0, inA1, inB1, inB0, ramp, ramp, ramp, ramp, mtop, mtop, mtop, mtop, S_STONE, ramp)
			var sideA := lift - Vector3(0, bev, 0)
			for ed in [[CA0, CA1, inA1, inA0, -outn if q == 1 else outn], [CB0, CB1, inB1, inB0, outn if q == 1 else -outn]]:
				var nn: Vector3 = ((ed[4] as Vector3) + ramp).normalized()
				_quad_n(ed[0], ed[1], (ed[1] as Vector3) + sideA, (ed[0] as Vector3) + sideA, ed[4], ed[4], ed[4], ed[4], cap.darkened(0.12), cap.darkened(0.12), cap, cap, S_STONE, ed[4])
				_quad_n((ed[0] as Vector3) + sideA, (ed[1] as Vector3) + sideA, ed[2], ed[3], nn, nn, nn, nn, cap.lightened(0.1), cap.lightened(0.1), cap.lightened(0.12), cap.lightened(0.12), S_STONE, nn)
			var fr0: Vector3 = to_world.call(ua + 0.01, sa - e, ta); var fr1: Vector3 = to_world.call(ua + 0.01, sb + e, ta)
			_quad_n(fr0, fr1, fr1 + sideA, fr0 + sideA, -upv, -upv, -upv, -upv, cap.darkened(0.2), cap.darkened(0.2), cap.darkened(0.08), cap.darkened(0.08), S_STONE, -upv)

## One cut stone of a step, from u0 (its nosing) to u1 and a0 to a1 across the flight, its top at
## `top` with chiselled edges (lighter bevels on the nosing and the ends), `mo` moss on each end.
func _step_stone(to_world: Callable, upv: Vector3, u0: float, u1: float, a0: float, a1: float, bot: float, top: float, c: Color, moss: Color, mo: Array, rr: RandomNumberGenerator) -> void:
	var b := 0.028
	var tl := c.lightened(0.06)
	var edge := c.lightened(0.16)
	var t0 := tl.lerp(moss, float(mo[0])); var t1 := tl.lerp(moss, float(mo[1]))
	var tilt := rr.randf_range(-0.012, 0.012)
	var ya := top + tilt; var yb := top - tilt
	# top, inset by the bevel on the nosing and both ends
	_quad_n(to_world.call(u0 + b, a0 + b, ya), to_world.call(u1, a0 + b, ya), to_world.call(u1, a1 - b, yb), to_world.call(u0 + b, a1 - b, yb),
		Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, t0, t0, t1, t1, S_STONE, Vector3.UP)
	# nosing bevel and the front face
	var fn := (-upv + Vector3.UP).normalized()
	var e0 := edge.lerp(moss, float(mo[0]) * 0.6); var e1 := edge.lerp(moss, float(mo[1]) * 0.6)
	_quad_n(to_world.call(u0, a0 + b, ya - b), to_world.call(u0, a1 - b, yb - b), to_world.call(u0 + b, a1 - b, yb), to_world.call(u0 + b, a0 + b, ya),
		fn, fn, fn, fn, e0, e1, e1, e0, S_STONE, fn)
	_quad_n(to_world.call(u0, a0 + b * 0.5, bot), to_world.call(u0, a1 - b * 0.5, bot), to_world.call(u0, a1 - b, yb - b), to_world.call(u0, a0 + b, ya - b),
		-upv, -upv, -upv, -upv, c.darkened(0.3), c.darkened(0.3), c.darkened(0.04), c.darkened(0.04), S_STONE, -upv)
	# the two ends (seen in the joints) with their bevels
	var sa := to_world.call(0.0, 0.0, 0.0) as Vector3
	var sd: Vector3 = (to_world.call(0.0, 1.0, 0.0) as Vector3) - sa
	sd.y = 0.0; sd = sd.normalized()
	for en in [[a0, b, -sd, ya, e0], [a1, -b, sd, yb, e1]]:
		var aa: float = en[0]; var bb: float = en[1]; var nn: Vector3 = en[2]; var yy: float = en[3]
		_quad_n(to_world.call(u0, aa, bot), to_world.call(u1, aa, bot), to_world.call(u1, aa, yy - b), to_world.call(u0, aa, yy - b),
			nn, nn, nn, nn, c.darkened(0.4), c.darkened(0.4), c.darkened(0.1), c.darkened(0.1), S_STONE, nn)
		var bn := (nn + Vector3.UP).normalized()
		_quad_n(to_world.call(u0 + b, aa, yy - b), to_world.call(u1, aa, yy - b), to_world.call(u1, aa + bb, yy), to_world.call(u0 + b, aa + bb, yy),
			bn, bn, bn, bn, (en[4] as Color).darkened(0.05), (en[4] as Color).darkened(0.05), en[4], en[4], S_STONE, bn)

## A squared stone block in flight coordinates (u along the climb, s across it), from height y0 to y1:
## four sides and a top with a light bevel tone, shaded darker toward the ground.
func _block(to_world: Callable, upv: Vector3, side_a: Vector3, u0: float, u1: float, s0: float, s1: float, y0: float, y1: float, c: Color, rr: RandomNumberGenerator) -> void:
	var cc := c.lightened(rr.randf_range(-0.03, 0.04))
	var top := cc.lightened(0.12)
	_quad_n(to_world.call(u0, s0, y1), to_world.call(u1, s0, y1), to_world.call(u1, s1, y1), to_world.call(u0, s1, y1),
		Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, top, top, top, top, S_STONE, Vector3.UP)
	for f in [[u0, s0, u0, s1, -upv], [u1, s0, u1, s1, upv], [u0, s0, u1, s0, -side_a], [u0, s1, u1, s1, side_a]]:
		var n: Vector3 = f[4]
		_quad_n(to_world.call(f[0], f[1], y0), to_world.call(f[2], f[3], y0), to_world.call(f[2], f[3], y1), to_world.call(f[0], f[1], y1),
			n, n, n, n, cc.darkened(0.4), cc.darkened(0.4), cc, cc, S_STONE, n)

# ------------------------------------------------------------------ emit
## One triangle; flips the winding so it faces along n (Godot's front faces are clockwise).
func _tri3(a: Vector3, b: Vector3, c: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color, st: float, _top: bool) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b; b = c; c = t
		var tc := cb; cb = cc; cc = tc
	V.append(a); V.append(b); V.append(c)
	N.append(n); N.append(n); N.append(n)
	C.append(ca); C.append(cb); C.append(cc)
	var u := Vector2(st, 0.0)
	UV.append(u); UV.append(u); UV.append(u)

func _quad_n(a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3,
		ca: Color, cb: Color, cc: Color, cd: Color, st: float, face: Vector3) -> void:
	var flip := (b - a).cross(c - a).dot(face) > 0.0
	if (b - a).cross(c - a).length_squared() < 1e-10:
		flip = (c - a).cross(d - a).dot(face) > 0.0
	var u := Vector2(st, 0.0)
	var tris := [[a, b, c, na, nb, nc, ca, cb, cc], [a, c, d, na, nc, nd, ca, cc, cd]]
	for t in tris:
		if flip:
			V.append(t[0]); V.append(t[2]); V.append(t[1])
			N.append(t[3]); N.append(t[5]); N.append(t[4])
			C.append(t[6]); C.append(t[8]); C.append(t[7])
		else:
			V.append(t[0]); V.append(t[1]); V.append(t[2])
			N.append(t[3]); N.append(t[4]); N.append(t[5])
			C.append(t[6]); C.append(t[7]); C.append(t[8])
		UV.append(u); UV.append(u); UV.append(u)
