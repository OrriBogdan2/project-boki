extends RefCounted
## Built stone walls, drawn as old hand-cut ruins that follow each wall run: chunky, irregular
## stones of mixed sizes with chiselled (bevelled) edges, laid in staggered courses over a dark
## mortar core; heavier quoins at corners and ends; a broken line of capstones on top, some chipped,
## tilted or fallen, under a pillowy cover of moss (or snow, ash, sand) that drips over the edges;
## rubble at the foot, and the whole wall darkening toward the ground (painted ambient occlusion).
## Curved walls (rings) follow a smoothed line instead of zigzagging tile to tile. Purely visual:
## the wall tiles still block exactly as before.
##
## Vertex colour alpha tells the wall shader what a face is: 1 stone, 0.5 cover, 0 mortar.

const COURSE := 0.4        # height of one course of stone
const THICK := 0.78        # wall thickness (a tile is 1)
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]

var W: Node
var rr := RandomNumberGenerator.new()
var nz := FastNoiseLite.new()
var chunks := {}     # Vector2i -> [verts, normals, colours]
var pos := {}        # tile index -> smoothed Vector3 (base of the wall)
var links := {}      # tile index -> Array of linked tile indices
var height := {}     # tile index -> courses
var style := "meadow"
var _base := 0.0     # ground height under the piece being built (for the painted AO)

func _init(world: Node) -> void:
	W = world
	rr.seed = int(W.rng.seed) + 211
	nz.seed = int(W.rng.seed) + 5
	nz.frequency = 0.18

func is_wall(x: int, z: int) -> bool:
	return W.inb(x, z) and W.walls.has(W.idx(x, z)) and W.kind[W.idx(x, z)] == W.T_BLOCK

## Mesh instances for every wall on the map, split into 24x24-tile chunks.
func build(mat: Material) -> Array:
	var ww: int = W.w
	for wi in W.walls:
		var i: int = wi
		if W.kind[i] != W.T_BLOCK:
			continue
		var x := i % ww; var z := i / ww
		var ls: Array = []
		for k in 8:
			var d: Vector2i = DIRS[k]
			if not is_wall(x + d.x, z + d.y):
				continue
			if k >= 4 and (is_wall(x + d.x, z) or is_wall(x, z + d.y)):
				continue     # a diagonal step already joined through a straight neighbour
			ls.append(W.idx(x + d.x, z + d.y))
		links[i] = ls
		pos[i] = Vector3(x + 0.5, W.level[i] * W.LEVEL, z + 0.5)
		# mostly full height, worn down a course or two here and there along a run
		var n := 5
		var wear := nz.get_noise_2d(x, z)
		if wear < -0.25: n = 4
		if wear < -0.5: n = 3
		if ls.size() != 2: n = maxi(n, 5)
		height[i] = n
	# smooth the line of each run: a tile with two neighbours moves toward their midpoint, so rings
	# curve and diagonal steps straighten (straight runs don't move)
	# (a square corner with straight arms on both sides is a built corner: it stays square)
	var fixed := {}
	for ik in pos:
		var i: int = ik
		var ls: Array = links[i]
		if ls.size() != 2:
			continue
		var da := Vector2i(int(ls[0]) % ww - i % ww, int(ls[0]) / ww - i / ww)
		var db := Vector2i(int(ls[1]) % ww - i % ww, int(ls[1]) / ww - i / ww)
		if da.x * db.x + da.y * db.y != 0 or absi(da.x) + absi(da.y) != 1 or absi(db.x) + absi(db.y) != 1:
			continue
		var x := i % ww; var z := i / ww
		if is_wall(x + da.x * 2, z + da.y * 2) and is_wall(x + db.x * 2, z + db.y * 2):
			fixed[i] = true
	for _it in 3:
		var nxt := {}
		for i in pos:
			var ls: Array = links[i]
			var p: Vector3 = pos[i]
			if ls.size() == 2 and not fixed.has(i):
				var m: Vector3 = (pos[ls[0]] + pos[ls[1]]) * 0.5
				p = Vector3(p.x * 0.5 + m.x * 0.5, p.y, p.z * 0.5 + m.z * 0.5)
			nxt[i] = p
		pos = nxt
	for i in pos:
		await W._slice()       # under the loading screen: a frame now and then
		var bio: Dictionary = W._bio(i)
		style = Flora.style_ok(W.style_at(i)) if W.has_method("style_at") else "meadow"
		var pal := _palette(bio)
		var stone: Color = pal[0]
		var cover: Color = pal[1]
		var ls: Array = links[i]
		var p: Vector3 = pos[i]
		var n: int = height[i]
		var key := Vector2i(int(p.x) / 24, int(p.z) / 24)
		# runs to each neighbour (each pair once)
		for j in ls:
			if j < i and links.has(j):
				continue
			_run(key, p, pos[j], n, int(height[j]), stone, cover)
		# a post at the joint: square to the run, larger at corners, junctions and ends
		var dirs: Array = []
		for j in ls:
			var d: Vector3 = pos[j] - p; d.y = 0.0
			dirs.append(d.normalized())
		var post := true
		var u := Vector3.RIGHT
		if dirs.size() == 2:
			var dd: float = (dirs[0] as Vector3).dot(dirs[1])
			if dd < -0.97:
				post = false      # a straight run: the stones carry straight through
			u = ((dirs[0] as Vector3) - (dirs[1] as Vector3)).normalized()
		elif dirs.size() == 1:
			u = dirs[0]
		elif dirs.size() > 2:
			u = dirs[0]
		if post:
			var half := THICK * (0.56 if dirs.size() == 2 else 0.6)
			var pn := n + (1 if dirs.size() <= 1 else 0)
			_post(key, p, u, half, pn, stone, cover)
	var out: Array = []
	for key in chunks:
		var ch: Array = chunks[key]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = ch[0]; arr[Mesh.ARRAY_NORMAL] = ch[1]; arr[Mesh.ARRAY_COLOR] = ch[2]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.name = "Walls_%d_%d" % [key.x, key.y]
		out.append(mi)
	return out

## Stone and cover colours for the biome: a warm grey stone leaning to the island's rock, and a
## cover of moss, snow, ash or sand.
func _palette(bio: Dictionary) -> Array:
	var stone := Color("a69d8e").lerp(Color(bio["side"]), 0.2).lerp(Color(bio["top"]), 0.06)
	var cover := Color(bio["top"]).lerp(Color(bio["leaf"]), 0.3).lightened(0.04)
	match style:
		"meadow":
			cover = Color(bio["top"]).lerp(Color("4f8a3a"), 0.45).lerp(Color(bio["leaf"]), 0.15)
		"bloom":
			cover = Color(bio["top"]).lerp(Color("5f9a48"), 0.4)
			stone = stone.lerp(Color("b8a69a"), 0.3)
		"frost":
			stone = Color("9aa2b0").lerp(Color(bio["side"]), 0.25)
			cover = Color("f2f6ff")
		"ember":
			stone = Color("8a7466").lerp(Color(bio["side"]), 0.2)
			cover = Color("8a7e78")     # pale ash
		"storm":
			stone = Color("8a92a0").lerp(Color(bio["side"]), 0.25)
			cover = Color(bio["top"]).lerp(Color("3f7a6a"), 0.45)
		"gloom":
			stone = Color("847a90").lerp(Color(bio["side"]), 0.25)
			cover = Color(bio["top"]).lerp(Color("5a4a7a"), 0.35)
	return [stone, cover]

## Coursed stone from a to b: courses both ends share run the whole way; the taller end's extra
## courses step down partway along, like a wall that has crumbled.
func _run(key: Vector2i, a: Vector3, b: Vector3, na: int, nb: int, stone: Color, cover: Color) -> void:
	var d := b - a; d.y = 0.0
	var length := d.length()
	if length < 0.01:
		return
	var u := d / length
	var v := Vector3(-u.z, 0, u.x)
	var base := minf(a.y, b.y)
	_base = base
	var hi := maxi(na, nb)
	var lo := mini(na, nb)
	# the mortar core: dark and set back, so every joint between stones reads as a deep seam
	var core := stone.darkened(0.45).lerp(Color("3a3440"), 0.25)
	core.a = 0.0
	# (it stops a course short of the top, so a gap or a broken stone up there shows stone below)
	_slab(key, (a + b) * 0.5 + Vector3(0, base - (a.y + b.y) * 0.5, 0), u, v, length * 0.5, THICK * 0.5 - 0.09, (lo - 1) * COURSE - 0.02, core)
	for k in hi:
		var s0 := 0.0; var s1 := length
		if k >= lo:
			# only the taller end reaches this course
			var reach := length * (0.55 - 0.18 * (k - lo))
			if na > nb: s1 = reach
			else: s0 = length - reach
			if s1 - s0 < 0.2:
				continue
		var cuts: Array = [s0]
		var off := s0 + (rr.randf_range(0.2, 0.45) if k % 2 == 0 else rr.randf_range(0.45, 0.75))
		while off < s1 - 0.22:
			cuts.append(off); off += rr.randf_range(0.32, 0.8) if k < hi - 1 else rr.randf_range(0.42, 0.7)
		cuts.append(s1)
		for q in cuts.size() - 1:
			var c0: float = cuts[q]; var c1: float = cuts[q + 1]
			var at := a + u * ((c0 + c1) * 0.5)
			at.y = base + k * COURSE
			var hu := (c1 - c0) * 0.5 - 0.022
			var col := _shade(stone, k)
			var cap := k == hi - 1 or (k == lo - 1 and _exposed(c0, c1, length, na, nb, lo))
			if cap:
				# the odd capstone is gone altogether, leaving a notch and a stone at the foot
				if k >= 3 and rr.randf() < 0.13:
					# a broken stump of a stone (no capstone), its pieces at the foot
					_stone(key, at, u, v, hu, THICK * 0.5 + 0.01, COURSE * rr.randf_range(0.35, 0.6), col.darkened(0.04), 0.05, 0.04, 0.05, 0.08)
					_rubble(key, at, u, v, 2, stone, cover)
					continue
				_capstone(key, at, u, v, hu, THICK * 0.5 + 0.035, col, cover)
			else:
				var out := rr.randf_range(-0.015, 0.04)
				var hh := COURSE - 0.03
				_stone(key, at + v * rr.randf_range(-0.02, 0.02), u, v, hu, THICK * 0.5 + out, hh, col, 0.055, 0.035, 0.03)
	# rubble along the foot, more where the wall has worn down
	var count := int(round(length * (0.5 + (5 - lo) * 0.45)))
	for _r in count:
		var t := rr.randf_range(0.1, 0.9)
		_rubble(key, a.lerp(b, t) + Vector3(0, base - a.lerp(b, t).y, 0), u, v, 1, stone, cover)

func _exposed(c0: float, c1: float, length: float, na: int, nb: int, lo: int) -> bool:
	# a stone on the lower common course is open to the sky where the taller end's next course stops
	if na == nb:
		return true
	var reach := length * 0.55
	var mid := (c0 + c1) * 0.5
	return mid > reach if na > nb else mid < length - reach

## A capstone: wider and chunkier than the coursing, its top chipped and tilted, usually under a
## pillow of cover that spills over the edges in drips.
func _capstone(key: Vector2i, at: Vector3, u: Vector3, v: Vector3, hu: float, hv: float, col: Color, cover: Color) -> void:
	var hh := COURSE - 0.03 + rr.randf_range(-0.06, 0.05)
	var chip := rr.randf_range(0.0, 0.16) if rr.randf() < 0.45 else 0.0
	var top := _stone(key, at, u, v, hu, hv + rr.randf_range(-0.02, 0.03), hh, col.lightened(0.04), 0.07, 0.045, 0.05, chip)
	var cov := 0.85
	match style:
		"frost": cov = 1.0
		"ember": cov = 0.55
		"storm", "gloom": cov = 0.75
	if rr.randf() > cov:
		return
	# the cover sits on the top face (which may tilt): a soft pillow a little smaller than the stone
	# on one side and lipping over the edge on the other
	var ch := 0.08 if style != "frost" else 0.12
	# a clump or two (snow: a drift) mounded on top, spilling a little over the edges
	var n := 1 if hu < 0.22 else (2 if rr.randf() < 0.7 else 3)
	if style == "frost": n = maxi(1, n - 1)
	for q in n:
		var t := (float(q) + 0.5) / n - 0.5
		var ru := hu / n * rr.randf_range(1.0, 1.35) + (0.04 if style == "frost" else 0.0)
		var rv := hv * rr.randf_range(0.75, 1.08)
		var c := Vector3(at.x, top - 0.02, at.z) + u * (t * hu * 2.0 + rr.randf_range(-0.04, 0.04)) + v * rr.randf_range(-0.05, 0.05)
		var cc := cover.lightened(rr.randf_range(-0.04, 0.07))
		cc.a = 0.5
		_pillow(key, c, u, v, ru, rv, ch * rr.randf_range(0.8, 1.3), cc)
	# drips of moss / snow down the long faces
	for sd in [-1.0, 1.0]:
		if rr.randf() < (0.75 if style == "frost" else 0.55):
			var w := rr.randf_range(0.08, 0.2)
			var dl := rr.randf_range(0.1, 0.28) * (1.4 if style == "frost" else 1.0)
			var at2: Vector3 = Vector3(at.x, top - dl - 0.02, at.z) + u * rr.randf_range(-hu * 0.6, hu * 0.6) + v * sd * (hv + 0.005)
			var dc := cover.darkened(0.08); dc.a = 0.5
			_stone(key, at2, u, v * sd, w, 0.025, dl + 0.02, dc, 0.02, 0.015, 0.0)

## Loose stones at the foot of the wall, tumbled every which way.
func _rubble(key: Vector2i, at: Vector3, u: Vector3, v: Vector3, n: int, stone: Color, cover: Color) -> void:
	for _k in n:
		var side := -1.0 if rr.randf() < 0.5 else 1.0
		var p := Vector3(at.x, _base, at.z) + v * side * rr.randf_range(THICK * 0.5 + 0.04, THICK * 0.5 + 0.38) + u * rr.randf_range(-0.3, 0.3)
		var s := rr.randf_range(0.07, 0.15)
		var a := rr.randf() * TAU
		var ru := Vector3(cos(a), 0, sin(a))
		var rv := Vector3(-ru.z, 0, ru.x)
		var c := _shade(stone, 0).darkened(rr.randf_range(0.0, 0.12))
		_stone(key, p - Vector3(0, 0.03, 0), ru, rv, s * rr.randf_range(1.0, 1.6), s, s * rr.randf_range(0.8, 1.3), c, s * 0.4, s * 0.35, s * 0.3)

## A square post (quoin stack) standing at a joint or at the end of a run.
func _post(key: Vector2i, p: Vector3, u: Vector3, half: float, n: int, stone: Color, cover: Color) -> void:
	var v := Vector3(-u.z, 0, u.x)
	_base = p.y
	var core := stone.darkened(0.45).lerp(Color("3a3440"), 0.25); core.a = 0.0
	_slab(key, p, u, v, half - 0.07, half - 0.07, (n - 1) * COURSE, core)
	for k in n:
		var at := p + Vector3(0, k * COURSE, 0)
		var col := _shade(stone, k).lightened(0.03)
		# quoins alternate long and short so the corner reads as interlocked blocks
		var lu := half + (0.05 if k % 2 == 0 else -0.01)
		var lv := half + (-0.01 if k % 2 == 0 else 0.05)
		if k == n - 1:
			_capstone(key, at, u, v, half + 0.05, half + 0.05, col, cover)
		else:
			_stone(key, at, u, v, lu, lv, COURSE - 0.03, col, 0.06, 0.04, 0.035)

func _shade(stone: Color, k: int) -> Color:
	var j := rr.randf_range(-0.07, 0.07)
	var c := stone.darkened(0.06 * (2 - mini(k, 2)))     # lower courses a touch darker
	c = c.lightened(j) if j > 0.0 else c.darkened(-j)
	# the odd stone warmer or cooler than its neighbours, as if cut from another bed
	var t := rr.randf()
	if t < 0.12: c = c.lerp(Color("c8a882"), 0.18)
	elif t < 0.22: c = c.lerp(Color("8a94a8"), 0.16)
	return c

func _ch(key: Vector2i) -> Array:
	if not chunks.has(key):
		chunks[key] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
	return chunks[key]

## An irregular cut stone standing on c (its base centre), along u and v, about hh tall: a box whose
## corners are nudged by up to `jit` (and the top by `jy`), with every edge but the bottom ones
## chiselled by b. `chip` knocks one top corner down, like a broken stone. Faces are lit by their
## height above the ground (painted AO) and the chiselled top edges catch the light.
## Returns the height of its top face at the middle (for what sits on it).
func _stone(key: Vector2i, c: Vector3, u: Vector3, v: Vector3, hu: float, hv: float, hh: float, col: Color, b: float, jit: float, jy: float, chip := 0.0) -> float:
	var ch := _ch(key)
	b = minf(b, minf(minf(hu, hv), hh) * 0.45)
	var up := Vector3.UP
	var tilt_u := rr.randf_range(-jy, jy)
	var tilt_v := rr.randf_range(-jy, jy) * 0.6
	var chip_k := rr.randi_range(0, 3)
	# corners: index (sx, sy, sz) -> position
	var P := {}
	for sy in [0, 1]:
		for k in 4:
			var sx: float = [-1.0, 1.0, 1.0, -1.0][k]
			var sz: float = [-1.0, -1.0, 1.0, 1.0][k]
			var p := c + u * sx * (hu + rr.randf_range(-jit, jit) * 0.6) + v * sz * (hv + rr.randf_range(-jit, jit))
			if sy == 1:
				p += up * (hh + sx * tilt_u + sz * tilt_v + rr.randf_range(-jy, jy) * 0.5)
				if chip > 0.0 and k == chip_k:
					p -= up * chip
					p -= u * sx * chip * 0.3
			P[Vector3i(int(sx), sy, int(sz))] = p
	var cen := c + up * hh * 0.5
	# chamfered vertices: for each corner, the point on each of its faces
	var fx := {}; var fy := {}; var fz := {}
	for kk in P:
		var key3: Vector3i = kk
		var p: Vector3 = P[key3]
		var sx := float(key3.x); var sz := float(key3.z)
		var dn := up * b if key3.y == 1 else Vector3.ZERO
		fx[key3] = p - v * sz * b - dn
		fz[key3] = p - u * sx * b - dn
		fy[key3] = p - u * sx * b - v * sz * b
	var lo := col.darkened(0.12)
	var tc := col.lightened(0.1)
	var ec := col.lightened(0.2)
	# top
	_tri4(ch, [fy[Vector3i(-1, 1, -1)], fy[Vector3i(1, 1, -1)], fy[Vector3i(1, 1, 1)], fy[Vector3i(-1, 1, 1)]], cen, [tc, tc, tc, tc])
	for sx in [-1, 1]:
		# the u-facing ends
		_tri4(ch, [fx[Vector3i(sx, 0, -1)], fx[Vector3i(sx, 0, 1)], fx[Vector3i(sx, 1, 1)], fx[Vector3i(sx, 1, -1)]], cen, [lo, lo, col, col])
		# their top edge
		_tri4(ch, [fx[Vector3i(sx, 1, -1)], fx[Vector3i(sx, 1, 1)], fy[Vector3i(sx, 1, 1)], fy[Vector3i(sx, 1, -1)]], cen, [ec, ec, ec, ec])
	for sz in [-1, 1]:
		_tri4(ch, [fz[Vector3i(-1, 0, sz)], fz[Vector3i(1, 0, sz)], fz[Vector3i(1, 1, sz)], fz[Vector3i(-1, 1, sz)]], cen, [lo, lo, col, col])
		_tri4(ch, [fz[Vector3i(-1, 1, sz)], fz[Vector3i(1, 1, sz)], fy[Vector3i(1, 1, sz)], fy[Vector3i(-1, 1, sz)]], cen, [ec, ec, ec, ec])
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			# vertical edge bevel and the little corner facet at the top
			var vc := col.lightened(0.04)
			_tri4(ch, [fx[Vector3i(sx, 0, sz)], fz[Vector3i(sx, 0, sz)], fz[Vector3i(sx, 1, sz)], fx[Vector3i(sx, 1, sz)]], cen, [lo, lo, vc, vc])
			_tri3(ch, fx[Vector3i(sx, 1, sz)], fy[Vector3i(sx, 1, sz)], fz[Vector3i(sx, 1, sz)], cen, ec)
	var mid := Vector3.ZERO
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			mid += P[Vector3i(sx, 1, sz)]
	return mid.y * 0.25

## A soft mound (moss clump, snow drift, ash heap): a jittered elliptical dome on c, radii ru
## along u and rv along v, h tall, smooth-shaded, darker at its skirt.
func _pillow(key: Vector2i, c: Vector3, u: Vector3, v: Vector3, ru: float, rv: float, h: float, col: Color) -> void:
	var ch := _ch(key)
	var seg := 9
	var rings := [[1.0, 0.0], [0.86, 0.55], [0.5, 0.92]]
	var jit: Array = []
	for k in seg: jit.append(rr.randf_range(0.82, 1.12))
	var pts: Array = []
	var nrm: Array = []
	for ri in rings.size():
		var row: Array = []; var nrow: Array = []
		for k in seg:
			var a := TAU * k / seg
			var f: float = float(rings[ri][0]) * float(jit[k])
			var p := c + u * cos(a) * ru * f + v * sin(a) * rv * f + Vector3.UP * h * float(rings[ri][1]) - Vector3.UP * (0.03 if ri == 0 else 0.0)
			row.append(p)
			var out := (u * cos(a) / ru + v * sin(a) / rv).normalized()
			nrow.append((out * (1.0 - float(rings[ri][1]) * 0.85) + Vector3.UP * (0.35 + float(rings[ri][1]))).normalized())
		pts.append(row); nrm.append(nrow)
	var top := c + Vector3.UP * h
	var cs := [col.darkened(0.22), col.darkened(0.06), col.lightened(0.05)]
	for ri in rings.size() - 1:
		for k in seg:
			var k2 := (k + 1) % seg
			var quad := [pts[ri][k], pts[ri][k2], pts[ri + 1][k2], pts[ri + 1][k]]
			var nq := [nrm[ri][k], nrm[ri][k2], nrm[ri + 1][k2], nrm[ri + 1][k]]
			var cq := [cs[ri], cs[ri], cs[ri + 1], cs[ri + 1]]
			for t in [[0, 1, 2], [0, 2, 3]]:
				for qi in t:
					ch[0].append(quad[qi]); ch[1].append(nq[qi]); ch[2].append(_ao(cq[qi], (quad[qi] as Vector3).y))
	var last: int = rings.size() - 1
	for k in seg:
		var k2 := (k + 1) % seg
		for e in [[pts[last][k], nrm[last][k]], [pts[last][k2], nrm[last][k2]], [top, Vector3.UP]]:
			ch[0].append(e[0]); ch[1].append(e[1]); ch[2].append(_ao(col.lightened(0.07), (e[0] as Vector3).y))

## A plain box (the mortar core): sides only and a top.
func _slab(key: Vector2i, c: Vector3, u: Vector3, v: Vector3, hu: float, hv: float, hh: float, col: Color) -> void:
	if hh <= 0.0:
		return
	var ch := _ch(key)
	var p := [c - u * hu - v * hv, c + u * hu - v * hv, c + u * hu + v * hv, c - u * hu + v * hv]
	var up := Vector3.UP * hh
	var cen := c + up * 0.5
	_tri4(ch, [p[0] + up, p[1] + up, p[2] + up, p[3] + up], cen, [col, col, col, col])
	for k in 4:
		var a: Vector3 = p[k]; var bb: Vector3 = p[(k + 1) % 4]
		_tri4(ch, [a, bb, bb + up, a + up], cen, [col, col, col, col])

## A quad (two triangles), wound to face away from `cen`, flat-shaded, each corner darkened by its
## height above the ground (painted ambient occlusion at the foot of the wall).
func _tri4(ch: Array, q: Array, cen: Vector3, cols: Array) -> void:
	var n := ((q[1] as Vector3) - (q[0] as Vector3)).cross((q[2] as Vector3) - (q[0] as Vector3))
	if n.length_squared() < 1e-10:
		n = ((q[2] as Vector3) - (q[0] as Vector3)).cross((q[3] as Vector3) - (q[0] as Vector3))
	n = n.normalized()
	var mid := ((q[0] as Vector3) + (q[1] as Vector3) + (q[2] as Vector3) + (q[3] as Vector3)) * 0.25
	var order := [0, 1, 2, 3]
	if n.dot(mid - cen) < 0.0:
		n = -n
	else:
		order = [3, 2, 1, 0]
	for t in [[0, 1, 2], [0, 2, 3]]:
		for qi in t:
			var k: int = order[qi]
			var p: Vector3 = q[k]
			ch[0].append(p); ch[1].append(n); ch[2].append(_ao(cols[k], p.y))

func _tri3(ch: Array, a: Vector3, b: Vector3, c: Vector3, cen: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var pts := [a, b, c]
	if n.dot((a + b + c) / 3.0 - cen) < 0.0:
		n = -n
	else:
		pts = [c, b, a]
	for p in pts:
		ch[0].append(p); ch[1].append(n); ch[2].append(_ao(col, (p as Vector3).y))

func _ao(c: Color, y: float) -> Color:
	var k := clampf((y - _base) / 0.9, 0.0, 1.0)
	var f := lerpf(0.52, 1.0, k * (2.0 - k))
	return Color(c.r * f, c.g * f, c.b * f, c.a)
